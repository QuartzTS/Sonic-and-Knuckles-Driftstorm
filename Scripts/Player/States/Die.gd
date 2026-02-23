extends PlayerState

func _ready():
	invulnerability = true # ironic

func _physics_process(delta):
	# gravity
	parent.movement.y += parent.grv/GlobalFunctions.div_by_delta(delta)
	# do allowTranslate to avoid collision
	parent.allowTranslate = true
	
	# check if main player
	if parent.playerControl == 1 or parent.playerControl == -1:
		# check if speed above certain threshold
		if parent.movement.y > 1000 and Global.lives > 0 and !Global.gameOver:
			parent.movement = Vector2.ZERO
			Global.lives -= 1
			# check if lives are remaining or death was a time over
			if Global.lives > 0:
				if Global.levelTime >= Global.maxTime and Global.time_limit:
					Global.gameOver = true
					# reset checkpoint time
					Global.checkPointTime = 0
				# Immediately return to the starting scene when somehow dying in attract reel mode
				elif parent.playerControl == -1 and Global.attract_reel:
					Global.attract_reel_id = (Global.attract_reel_id + 1) % Global.LEVELS.size() as Global.LEVELS
					Global.attract_reel = false
					Global.music.stop()
					Global.effectTheme.stop()
					Global.soundChannel.stop()
					Global.bossMusic.stop()
					Main.set_volume(0)
					Main.change_scene(Global.startScene)
					await Main.scene_faded
					Main.reset_game_values()
				else:
					Main.change_scene_by_level_id(Global.level_id)
					parent.process_mode = PROCESS_MODE_PAUSABLE
			else:
				Global.gameOver = true
				# reset checkpoint time
				Global.checkPointTime = 0
	# if not run respawn code
	elif parent.movement.y > 1000:
		parent.respawn()

# This, in case the player somehow gets out of this state (and goes to the debug state, for example..)
func state_exit():
	parent.allowTranslate = false
	parent.z_index = parent.defaultZIndex
	parent.collision_layer = parent.defaultLayer
	parent.collision_mask = parent.defaultMask
	Main.sceneCanPause = true
