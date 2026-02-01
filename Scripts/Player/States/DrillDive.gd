extends PlayerState

var flat_ground: bool = false ## This is set to true when flat ground is detected, just like the 'landed' variable in Glide.gd
var dust_velocity: float = 1.0 ## Velocity of dust clouds
const DUST_PARTICLES_NUM: int = 6 ## Maximum number of dust particles to spawn

# This code here allows gliding while drilldiving, and jumping/spindashing when landing
# Also sorry, most of the code in this entire script is copied from Air.gd, lol.
func _process(delta: float) -> void:
	if parent.inputs[parent.INPUTS.ACTION] == 1 and !flat_ground:
		# set initial movement
		parent.movement = Vector2(parent.direction*4*60,max(parent.movement.y,0))
		parent.set_state(parent.STATES.GLIDE,parent.currentHitbox.GLIDE)
	# Jump and Spindash cancel
	if (parent.inputs[parent.INPUTS.ACTION] == 1 or parent.inputs[parent.INPUTS.ACTION2] == 1) and parent.ground and flat_ground:
		parent.movement.x = 0
		if parent.inputs[parent.INPUTS.YINPUT] > 0:
			parent.animator.play("spinDash")
			parent.sfx[2].play()
			parent.sfx[2].pitch_scale = 1
			parent.spindashPower = 0
			parent.animator.play("spinDash")
			parent.set_state(parent.STATES.SPINDASH)
			parent.cameraDragLerp = 1
		else:
			# reset animations
			parent.action_jump(delta)
			parent.set_state(parent.STATES.JUMP)

func _physics_process(delta: float) -> void:
	# air movement
	if parent.inputs[parent.INPUTS.XINPUT] != 0 and parent.airControl and !parent.ground and \
	parent.movement.x*parent.inputs[parent.INPUTS.XINPUT] < parent.top and abs(parent.movement.x) < parent.top:
		parent.movement.x = clamp(parent.movement.x+parent.air/GlobalFunctions.div_by_delta(delta)*parent.inputs[parent.INPUTS.XINPUT],-parent.top,parent.top)
		
	# Air drag
	if parent.movement.y < 0 and parent.movement.y > -parent.releaseJmp*60:
		parent.movement.x -= ((parent.movement.x / 0.125) / 256)*60*delta
	
	
	if parent.inputs[parent.INPUTS.XINPUT] != 0:
		parent.direction = parent.inputs[parent.INPUTS.XINPUT]
	
	
	# Gravity
	parent.movement.y += parent.grv/GlobalFunctions.div_by_delta(delta)
	
	# Reset state if on ground
	if parent.ground:
		# Restore Air Control when landing
		# (Needed if Rolling control lock is enabled in Roll.gd)
		parent.airControl = true
		# Do most of the landing code only when the ground is flat
		if is_equal_approx(parent.angle,parent.gravityAngle) and !flat_ground:
			flat_ground = true
			if parent.movement.y >= 12*60: # Only make the dramatic effects if the Y speed didn't decrease
				parent.sfx[34].play()
				parent.sfx[33].stop()
				parent.shake_camera(delta, Vector2(0,4), 2)
				# Spawn a dust cloud, and then do some calculations on dust_velocity for the next iteration.
				# Funnily enough, this takes 6 lines without the for loop.. meanwhile here, it took 5.. 
				# Idk if there's a better way, tho..
				for i: int in range(DUST_PARTICLES_NUM):
					spawn_drill_dive_dust(dust_velocity) # Dust spawned
					if i % 2 != 0:
						dust_velocity += 0.5*sign(dust_velocity) # Add 0.5 to the positive value of dust velocity when i eventually becomes an odd number
					dust_velocity *= -1 # Multiply it by -1 every iteration
			# set facing direction
			parent.sprite.flip_h = parent.direction < 0
			parent.movement = Vector2.ZERO
			parent.animator.play("land")
			if !parent.sfx[34].is_playing():
				parent.sfx[27].play() # Play the normal landing sound if we're not dramatic enough lol..
			await parent.animator.animation_finished
			# Ensure that Knuckles is still in this state during the landing animation before transitioning back to normal.
			# If we didn't do that, some weird stuff would occur, cuz we're gonna be forced to the normal state even if we're gliding, for example lol.
			if parent.currentState == parent.STATES.DRILLDIVE:
				parent.set_state(parent.STATES.NORMAL)
		# Double check cuz why not bru-
		if parent.currentState == parent.STATES.DRILLDIVE and !flat_ground:
			parent.set_state(parent.STATES.NORMAL)

func state_activated() -> void:
	parent.reflective = true # Why not reflect projectiles while drilldiving? :)

func state_exit() -> void:
	# Reset the reflective flag, the flat_ground flag and the dust_velocity variable so that they can get reused later..
	parent.reflective = false
	flat_ground = false
	dust_velocity = 1.0


## A seperate function for spawning one moving dust cloud based on given velocity, kinda like the ones Mighty makes in Sonic Mania (Plus).
func spawn_drill_dive_dust(initial_velocity: float) -> void:
	var dust = parent.MovingParticle.instantiate() # Man.. did I really need to make a different kind of particle for this?
	dust.get_child(0).play("DrillDiveDust")
	dust.z_index = 6
	dust.global_position = parent.global_position+(Vector2.DOWN*10)
	dust.collide = true # Set collide to true so that the clouds destroy enemies and monitors
	dust.velocity.x = initial_velocity*60 # Set the velocity to the initial velocity
	#dust.velo = Vector2(initial_velocity,0)
	parent.get_parent().add_child(dust)
