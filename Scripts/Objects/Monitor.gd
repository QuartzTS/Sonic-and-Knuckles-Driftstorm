@tool
extends Node2D

var physics = false
var grv = 0.21875
var yspeed = 0
var playerTouch = null
var isActive = true
@export_enum("Ring", "Speed Shoes", "Invincibility", "Shield", "Elec Shield", "Fire Shield",
"Bubble Shield", "Super", "Blue Ring", "Boost", "1up", "Robotnik") var item = 0
@onready var monitor_body = $MonitorBody
@onready var item_icon = $MonitorBody/Item
var lock_x_pos = false
var prev_pos = Vector2.ZERO


var Explosion = preload("res://Entities/Misc/BadnickSmoke.tscn")


func _ready():
	# set frame
	$MonitorBody/Item.frame = item+2
	if !Engine.is_editor_hint():
		# Life Icon (life icons are a special case)
		if item == 10:
			$MonitorBody/Item.frame = item+1+Global.PlayerChar1
		if item == 11:
			$MonitorBody/Item.frame = item+6
		if Global.nodeMemory.has(get_path()):
			set_destroyed()
		# Connect the monitor bounce function to the global screen shake signal.
		# Now whenever the camera shakes (like when Knuckles drilldives, for example), the monitor will automatically bounce..
		Global.screen_shake.connect(Callable(self,"monitor_bounce"))


#func debug_change_property():
	#item += int(Input.is_action_just_pressed("gm_action2"))-int(Input.is_action_just_pressed("gm_action3"))
	#item_icon.frame = item+2
	#if item == 10:
		#$MonitorBody/Item.frame = item+1+Global.PlayerChar1
	#if item == 11:
		#$MonitorBody/Item.frame = item+6
	#if item == -1 or item == 12:
		#Global.emit_cycle_object()


func _process(_delta):
	# update for editor
	if Engine.is_editor_hint():
		$MonitorBody/Item.frame = item+2
		if item == 11:
			$MonitorBody/Item.frame = item+6
	elif item_icon != null: # Check if the icon still exists
		# Change the icon when character switching
		if item == 10:
			item_icon.frame = item+1+Global.PlayerChar1
		# If lockXPos set to true after monitor destruction, reset the x global position to the previously stored value, to avoid being
		# moved by the new moving parent, which is gonna be a platform, most of the time. (Was that even needed, tho?)
		if lock_x_pos: 
			item_icon.global_position.x = prev_pos.x 


func destroy():
	# skip if not activated
	if !isActive:
		return false
	# create explosion
	var explosion = Explosion.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = monitor_body.global_position
	# deactivate
	isActive = false
	monitor_bounce() # Bounce the monitor as a reaction for getting hit
	# set item to have a high Z index so it overlays a lot
	item_icon.z_index += 1000
	prev_pos = item_icon.global_position # Set previous position of the icon before removing it
	# Remove the item icon node from the monitor body node. Previously, the item icon was inheriting the position of its monitor body
	# parent, but we don't want that anymore..
	monitor_body.remove_child(item_icon)
	# Make the item icon a child to the monitor node itself. At least it's not gonna be inheriting the position of the monitor body node..
	add_child(item_icon)
	if item_icon.global_position != prev_pos and $Animator.current_animation != "DestroyMonitor":
		item_icon.global_position = prev_pos # Reset the item icon position to the stored position after adding it as a child to a different node
	# play destruction animation
	$Animator.play("DestroyMonitor")
	$SFX/Destroy.play()
	Global.nodeMemory.append(get_path()) # Save the monitor destruction state to the node memory, so that it self-destructs when the player respawns
	# Set swap cooldown to the length of monitor destruction animation so that no character switching occurs before playerTouch obtains the item
	playerTouch.swap_cooldown = $Animator.current_animation_length
	# Now make a tween so that we can change the global position of the icon outside of the influence of the monitor body, and without using an animation player.
	# But was that even needed anyway? I don't know..
	await create_tween().tween_property(item_icon,"global_position",item_icon.global_position-Vector2(0,32),$Animator.current_animation_length).set_ease(Tween.EASE_OUT).finished
	lock_x_pos = true # Set that to true after finishing tweening, so that the item icon x global position remains constant (Was that even-)
	# wait for animation to finish
	await $Animator.animation_finished
	# enable effect
	match (item):
		0: # Rings
			playerTouch.rings += 10
			$SFX/Ring.play()
		1: # Speed Shoes
			if !playerTouch.get("isSuper"):
				playerTouch.shoeTime = 20
				playerTouch.switch_physics()
				if playerTouch.get("partner") != null and !playerTouch.partner.get("isSuper"): # Hey.. can't we give that powerup to the partner as well?
					playerTouch.partner.shoeTime = 20
					playerTouch.partner.switch_physics()
				Global.currentTheme = 1
				Global.effectTheme.stream = Global.themes[Global.currentTheme]
				Global.effectTheme.play()
		2: # Invincibility
			if !playerTouch.get("isSuper"):
				playerTouch.supTime = 20
				playerTouch.shieldSprite.visible = false # turn off barrier for stars
				playerTouch.get_node("InvincibilityBarrier").visible = true
				Global.currentTheme = 0
				Global.effectTheme.stream = Global.themes[Global.currentTheme]
				Global.effectTheme.play()
		3: # Shield
			playerTouch.set_shield(playerTouch.SHIELDS.NORMAL)
		4: # Elec
			playerTouch.set_shield(playerTouch.SHIELDS.ELEC)
		5: # Fire
			playerTouch.set_shield(playerTouch.SHIELDS.FIRE)
		6: # Bubble
			playerTouch.set_shield(playerTouch.SHIELDS.BUBBLE)
		7: # Super
			playerTouch.rings += 50
			if !playerTouch.get("isSuper"):
				playerTouch.set_state(playerTouch.STATES.SUPER)
				if playerTouch.get("partner") != null: # Turn the partner super as well, cuz why not lol..
					playerTouch.partner.rings += 50
					if !playerTouch.partner.get("isSuper"):
						playerTouch.partner.set_state(playerTouch.partner.STATES.SUPER)
		10: # 1up
			Global.life.play()
			Global.lives += 1
			Global.effectTheme.volume_db = -100
			Global.music.volume_db = -100
		11:
			playerTouch.hit_player()
	# At this point I'm just depending on tweens, bruh.. That's soooo sad..
	# Well, this is gonna be just temporary till we make a custom animation for icon disappearence.
	await create_tween().tween_property(item_icon,"modulate",Color.TRANSPARENT,0.5).finished
	item_icon.queue_free() # Free the icon from memory


func set_destroyed():
	# deactivate
	isActive = false
	physics = false
	$Animator.play("DestroyMonitor")


func _physics_process(delta):
	# if physics are on make em fall
	if !Engine.is_editor_hint() and physics:
		var collide = monitor_body.move_and_collide(Vector2(0,yspeed*delta))
		yspeed += grv/GlobalFunctions.div_by_delta(delta)
		if collide and yspeed > 0:
			physics = false

# physics collision check, see physics object
# Actually, nevermind.. I moved the function to the monitor body script, see that instead..
#func physics_collision(body, hitVector):
	## Monitor head bouncing
	#if hitVector.y < 0:
		#monitor_bounce()
		#if body.movement.y < 0:
			#body.movement.y *= -1
	## check that player has the rolling layer bit set
	#elif body.get_collision_layer_value(20):
		## Bounce from below
		#if hitVector.x != 0:
			## check conditions for interaction (and the player is the first player)
			#if body.movement.y >= 0 and body.movement.x != 0 and (body.playerControl == 1 or body.playerControl == -1):
				#playerTouch = body
				#destroy()
			#else:
				## Stop horizontal movement
				#body.movement.x = 0
		## check if player is not an ai or spindashing or drilldiving
		## if true then destroy
		#if (body.playerControl == 1 or body.playerControl == -1) and body.currentState != body.STATES.SPINDASH and !body.get_collision_layer_value(24):
			#body.movement.y = -abs(body.movement.y)
			#if body.currentState == body.STATES.ROLL:
				#body.movement.y = 0
			#body.ground = false
			#playerTouch = body
			#destroy()
		## Drilldive
		#elif body.get_collision_layer_value(24):
			#body.ground = false
			#playerTouch = body
			#destroy()
		#else:
			#body.ground = true
			#body.movement.y = 0
	#return true


# Store the code for monitor bouncing in a function so that it's called easily whenever the camera shakes
func monitor_bounce() -> void:
	# First, Check if on-screen, so that off-screen monitors don't fall on the ground
	if $MonitorBody/VisibleOnScreenNotifier2D.is_on_screen():
		yspeed = -1.5*60
		physics = true

# Insta-Shield and drilldive dust particles should break the monitor instantly
func _on_DamageArea_area_entered(area):
	if isActive:
		if area.get("parent") != null and area.get_collision_layer_value(20):
			playerTouch = area.parent
			area.parent.movement.y *= -1
		elif area.get_collision_layer_value(24):
			playerTouch = Global.players[0]
		destroy()
