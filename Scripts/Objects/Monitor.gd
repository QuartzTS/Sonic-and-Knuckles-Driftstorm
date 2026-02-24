@tool
extends Node2D

static var _orig_texture: Texture2D = null

static var _1up_textures: Array[Texture2D] = []

static var _orig_vframes: int
static var _orig_hframes: int

var physics = false
var grv = 0.21875
var yspeed = 0
var playerTouch: PlayerChar = null
var isActive = true
@onready var monitor_body = $MonitorBody
@onready var item_icon = $MonitorBody/Item
var lock_x_pos = false
var prev_pos = Vector2.ZERO


var Explosion = preload("res://Entities/Misc/BadnickSmoke.tscn")

enum ITEMS {
	# when adding new item types, please make sure
	# 1up is the last item in the list
	RING, SPEED_SHOES, INVINCIBILITY, SHIELD, ELEC_SHIELD, FIRE_SHIELD,
	BUBBLE_SHIELD, SUPER, _1UP, ROBOTNIK, HYPER_RING
}
@export var item: ITEMS = ITEMS.RING:
	set(value):
		item = value
		if _orig_texture != null:
			_set_item_frame()

func _set_item_frame():
	if item == ITEMS._1UP:
		$MonitorBody/Item.hframes = 1
		$MonitorBody/Item.vframes = 1
		$MonitorBody/Item.frame = 0
		$MonitorBody/Item.texture = _1up_textures[0 if Engine.is_editor_hint() else Global.PlayerChar1]
		if !Engine.is_editor_hint():
			$MonitorBody/Item.material = Global.get_material_for_character(Global.PlayerChar1)
	else:
		$MonitorBody/Item.vframes = _orig_vframes
		$MonitorBody/Item.hframes = _orig_hframes
		$MonitorBody/Item.frame = item - int(item > ITEMS._1UP) # skip 1up
		$MonitorBody/Item.texture = _orig_texture

func _ready():
	var in_editor: bool = Engine.is_editor_hint()
	if _orig_texture == null:
		# back up the original texture and the number of frames in it
		_orig_texture = $MonitorBody/Item.texture as Texture2D
		_orig_vframes = $MonitorBody/Item.vframes
		_orig_hframes = $MonitorBody/Item.hframes
		# resize the 1up textures array
		var char_names: Array = Global.CHARACTERS.keys()
		var num_characters: int = char_names.size()
		_1up_textures.resize(1 if in_editor else num_characters)
		# replace "NONE" with the name of the 1'st character from the list,
		# for development purposes (e.g. when we implement a new game mode
		# and PlayerChar1 is not set, so Godot won't throw a ton of errors)
		char_names[0] = char_names[1]
		# load textures for character-specific frames
		# (if we are in the editor, only load the icon for the 1'st character
		# from the list, as the other icons won't be shown in the editor anyway)
		for i: int in (1 if in_editor else num_characters):
			_1up_textures[i] = load("res://Graphics/Items/monitor_icon_%s.png" % char_names[i].to_lower()) as Texture2D

	# when in the editor, frame 0 in the monitor sprite sheet overlaps the item icon
	# with static, which is why we need to set the 1'st frame for the monitor sprite,
	# so the item icon could be seen through the transparent part of that frame
	if in_editor:
		$Monitor.play("", 0.0)
		$Monitor.set_frame_and_progress(1, 0.0)
		set_physics_process(false)

	# set item frame
	_set_item_frame()
	#Outside of Editor mode, if the monitor was already broken, set as destroyed.
	if !in_editor and Global.nodeMemory.has(get_path()):
		set_destroyed()

#func debug_change_property():
	#item += int(Input.is_action_just_pressed("gm_action2"))-int(Input.is_action_just_pressed("gm_action3"))
	#item_icon.frame = item+2
	#if item == 10:
		#$MonitorBody/Item.frame = item+1+Global.PlayerChar1
	#if item == 11:
		#$MonitorBody/Item.frame = item+6
	#if item == -1 or item == 12:
		#Global.emit_cycle_object()

# func _process(_delta):
# 	if item_icon != null: # Check if the icon still exists
# 		# Change the icon when character switching
# 		if item == 10:
# 			item_icon.frame = item+1+Global.PlayerChar1
# 		# If lockXPos set to true after monitor destruction, reset the x global position to the previously stored value, to avoid being
# 		# moved by the new moving parent, which is gonna be a platform, most of the time. (Was that even needed, tho?)
# 		if item_icon != null and lock_x_pos: 
# 			item_icon.global_position.x = prev_pos.x 

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
	Global.nodeMemory.append(get_path())
	
	# set item to have a high Z index so it overlays a lot
	item_icon.z_index += 1000
	prev_pos = item_icon.global_position # Set previous position of the icon before removing it
	# Remove the item icon node from the monitor body node. Previously, the item icon was inheriting the position of its monitor body
	# parent, but we don't want that anymore..
	monitor_body.remove_child(item_icon)
	# Make the item icon a child to the monitor node itself. At least it's not gonna be inheriting the position of the monitor body node..
	add_child(item_icon)
	if item_icon.global_position != prev_pos and $Monitor.current_animation != "DestroyMonitor":
		item_icon.global_position = prev_pos # Reset the item icon position to the stored position after adding it as a child to a different node
	# play destruction animation
	$Monitor.play("DestroyMonitor")
	$SFX/Destroy.play()
	Global.nodeMemory.append(get_path()) # Save the monitor destruction state to the node memory, so that it self-destructs when the player respawns
	# Set swap cooldown to the length of monitor destruction animation so that no character switching occurs before playerTouch obtains the item
	playerTouch.swap_cooldown = $Monitor.current_animation_length
	# Now make a tween so that we can change the global position of the icon outside of the influence of the monitor body, and without using an animation player.
	# But was that even needed anyway? I don't know..
	await create_tween().tween_property(item_icon,"global_position",item_icon.global_position-Vector2(0,32),$Monitor.current_animation_length).set_ease(Tween.EASE_OUT).finished
	lock_x_pos = true # Set that to true after finishing tweening, so that the item icon x global position remains constant (Was that even-)
	# wait for animation to finish
	await $Monitor.animation_finished
	# enable effect
	match (item):
		ITEMS.RING:
			playerTouch.give_ring(10)
		ITEMS.SPEED_SHOES:
			if !playerTouch.get("isSuper"):
				playerTouch.shoeTime = 20
				playerTouch.switch_physics()
				if playerTouch.get_partner() != null and !playerTouch.get_partner().get("isSuper"): # Hey.. can't we give that powerup to the partner as well?
					var partner = playerTouch.get_partner()
					partner.shoeTime = 20
					partner.switch_physics()
				MusicController.play_music_theme(MusicController.MusicTheme.SPEED_UP)
		ITEMS.INVINCIBILITY:
			if !playerTouch.get("isSuper"):
				playerTouch.supTime = 20
				playerTouch.shieldSprite.visible = false # turn off barrier for stars
				playerTouch.get_node("InvincibilityBarrier").visible = true
				MusicController.play_music_theme(MusicController.MusicTheme.INVINCIBLE)
		ITEMS.SHIELD:
			playerTouch.set_shield(playerTouch.SHIELDS.NORMAL)
		ITEMS.ELEC_SHIELD:
			playerTouch.set_shield(playerTouch.SHIELDS.ELEC)
		ITEMS.FIRE_SHIELD:
			playerTouch.set_shield(playerTouch.SHIELDS.FIRE)
		ITEMS.BUBBLE_SHIELD:
			playerTouch.set_shield(playerTouch.SHIELDS.BUBBLE)
		ITEMS.SUPER:
			playerTouch.rings += 50
			if !playerTouch.get("isSuper"):
				playerTouch.set_state(PlayerChar.STATES.SUPER)
				if playerTouch.get_partner() != null: # Turn the partner super as well, cuz why not lol..
					var partner = playerTouch.get_partner()
					partner.rings += 50
					if !partner.get("isSuper"):
						partner.set_state(PlayerChar.STATES.SUPER)
		ITEMS._1UP:
			MusicController.play_music_theme(MusicController.MusicTheme._1UP)
			Global.lives += 1
		ITEMS.ROBOTNIK:
			playerTouch.hit_player(playerTouch.global_position, Global.HAZARDS.NORMAL, 9, true)
		ITEMS.HYPER_RING:
			playerTouch.hyper_ring = true
	# At this point I'm just depending on tweens, bruh.. That's soooo sad..
	# Well, this is gonna be just temporary till we make a custom animation for icon disappearence.
	await create_tween().tween_property(item_icon,"modulate",Color.TRANSPARENT,0.5).finished
	item_icon.queue_free() # Free the icon from memory

func set_destroyed():
	# deactivate
	isActive = false
	physics = false
	$Monitor.play("DestroyMonitor")

func _physics_process(delta):
	# if physics are on make em fall
	if physics:
		var collide = monitor_body.move_and_collide(Vector2(0.0,yspeed*delta))
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
