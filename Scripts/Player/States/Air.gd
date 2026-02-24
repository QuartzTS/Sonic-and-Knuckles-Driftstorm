extends PlayerState


@export var isJump = false

var lockDir = false


func _ready():
	super()
	if isJump: # we only want to connect it once so only apply this to the jump variation
		parent.connect("enemy_bounced",Callable(self,"bounce"))


# reset drop dash timer and gripping when this state is set
func state_activated():
	parent.poleGrabID = null
	# disable water run splash
	parent.action_water_run_handle()


# Super
func state_process(_delta: float) -> void:
	if parent.playerControl != 0 and parent.inputs[parent.INPUTS.SUPER] == 1 and !parent.isSuper and isJump and parent.rings >= 50 and Global.emeralds >= Global.EMERALDS.ALL:
		parent.set_state(parent.STATES.SUPER)


func state_physics_process(delta: float) -> void:
	var physics: PlayerPhysics = parent.get_physics()
	var top_speed: float = physics.top_speed
	var air_accel: float = physics.air_acceleration
	var release_jump: float = physics.release_jump
	var animator: PlayerCharAnimationPlayer = parent.get_avatar().get_animator()

	# air movement
	if parent.inputs[parent.INPUTS.XINPUT] != 0 and parent.airControl and parent.movement.x*parent.inputs[parent.INPUTS.XINPUT] < top_speed and \
		abs(parent.movement.x) < top_speed:
		parent.movement.x = clamp(parent.movement.x+air_accel/GlobalFunctions.div_by_delta(delta)*parent.inputs[parent.INPUTS.XINPUT],-top_speed,top_speed)
				
	# Air drag
	if parent.movement.y < 0 and parent.movement.y > -release_jump * 60:
		parent.movement.x -= ((parent.movement.x / 0.125) / 256)*60*delta
	
	# Run the freefall animation (or queue if the spring animation is playing)
	if animator.has_animation("freefall"):
		if parent.movement.y >= 2*60 and animator.current_animation != "roll" and (parent.lastActiveAnimation != "freefall" or \
		(animator.current_animation == "freefall" and parent.lastActiveAnimation == "freefall")) and !isJump:
			animator.play("freefall")
		if animator.current_animation == "spring" or animator.current_animation == "springScrew":
			animator.queue("freefall")
	
	
	# Mechanics if jumping
	if isJump:
		# Cut vertical movement if jump released
		if !parent.any_action_held_or_pressed() and parent.movement.y < -release_jump*60:
			parent.movement.y = -release_jump*60
		
	# Change parent direction
	# Check that lock direction isn't on
	if !lockDir and parent.inputs[parent.INPUTS.XINPUT] != 0:
		parent.set_direction_signed(parent.inputs[parent.INPUTS.XINPUT])
	
	# Gravity
	parent.movement.y += parent.get_physics().gravity / GlobalFunctions.div_by_delta(delta)
	
	# Reset state if on ground
	if parent.ground:
		#Restore Air Control when landing
		#(Needed if Rolling control lock is enabled in Roll.gd)
		parent.airControl = true
		# Check bounce reaction first (this kinda feels like character specific code, but maybe not)
		if !bounce():
			# reset animations (this is for shared animations like the corkscrews)
			animator.play("RESET")
			# return to normal state
			parent.set_state(parent.STATES.NORMAL)
		else:
			parent.emit_player_bounce()
	


func state_exit():
	if parent.ground:
		parent.movement.y = min(parent.movement.y,0)
	parent.poleGrabID = null
	parent.enemyCounter = 0
	lockDir = false


# bounce handling
func bounce():
	# check if bounce reaction is set
	if parent.bounceReaction != 0 and parent.animator.current_animation == "roll":
		# set bounce movement
		if parent.shield == parent.SHIELDS.BUBBLE:
			parent.movement.y = -parent.bounceReaction*60
		parent.bounceReaction = 0
		parent.abilityUsed = false
		return true
	# if no bounce then return false to continue with landing routine
	return false
