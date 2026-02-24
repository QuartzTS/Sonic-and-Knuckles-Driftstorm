class_name MainGameScene
extends Node2D

# this gets emited when the scene fades, used to load in level details and data to hide it from the player
signal scene_faded
## And this one gets emitted when an animated cutscene ends
signal video_finished

## was paused enables menu control when the player pauses manually so they don't get stuck (get_tree().paused may want to be used by other intances)
var wasPaused = false
## determines if the current scene can pause
var sceneCanPause = false

func _ready():
	# initialize game data using global reset (it's better then assigning variables twice)
	reset_values()

func _input(event):
	# Pausing
	if event.is_action_pressed("gm_pause") and sceneCanPause:
		# check if the game wasn't paused and the tree isn't paused either
		if !wasPaused and !get_tree().paused:
			# Do the pause
			wasPaused = true
			get_tree().paused = true
			$GUI/Pause.visible = true
		# else if the scene was paused manually and the game was paused, check that the gui menu isn't visible and unpause
		# Note: the gui menu has some settings to unpause itself so we don't want to override that while the user is in the settings
		elif wasPaused and get_tree().paused and !$GUI/Pause.visible:
			# Do the unpause
			wasPaused = false
			get_tree().paused = false
	# reset game if F2 is pressed (this button can be changed in project settings)
	if event.is_action_pressed("ui_reset"):
		reset_game()

## Reset Game
func reset_game():
	# remove the was paused check
	wasPaused = false
	sceneCanPause = false
	change_scene(Global.startScene)
	# reset game values
	reset_values()
	# unpause scene (if it was)
	get_tree().paused = false
	

## Function for playing pre-rendered animated videos, mostly within cutscenes (cuz that's just a game design choice bruh..)
func play_video(video: VideoStream) -> void:
	if !$GUI/VideoPlayer.is_playimg():
		$GUI/VideoPlayer.show()
		$GUI/VideoPlayer.stream = video
		$GUI/VideoPlayer.play()
		await $GUI/VideoPlayer.finished
		emit_signal("video_finished")
		$GUI/VideoPlayer.hide()

## New Scene Change function. Args: Scene path, fade animation, time of transition, reset data
func change_scene(scene: String, fade_anim: String = "FadeOut", do_fade_in: bool = true, length: float = 1.0, reset_data: bool = true) -> void:
	$GUI/Fader.speed_scale = 1.0/float(length)
	# if fadeOut isn't blank, play the fade out animation and then wait, otherwise skip this
	if fade_anim != "":
		$GUI/Fader.queue(fade_anim)
		await $GUI/Fader.animation_finished
	# error prevention
	emit_signal("scene_faded")
	await get_tree().process_frame
	get_tree().paused = false
	$GUI/Pause.hide()
	MusicController.stop_all_music_themes()
	get_tree().change_scene_to_file(scene)
	# reset data level data, if reset data is true
	if reset_data:
		clear_dynamic_level_variables()
	else:
		Global.players.clear()
		Global.checkPoints.clear()
	# play fade in animation back if it's true
	if do_fade_in:
		fade_in(fade_anim)

## Same as 'change_scene', except that it uses the ID of the levels instead of the scene path,
## which makes it more specific to levels than other scenes like the title screen or data select etc..
## What's funny is that I've only added this function to make it set the global 'level_id' and 'force_act_2' variables while changing the scene just to use it
## instead of setting em in the script that calls the changing scene function,
## especially the 'level_id' one cuz I made Zone.gd check it to setup the current act,
## which can't even be determined because Zone.gd has two level ids for each act, and I can't set any of them without checking the current act, ironically lol..
func change_scene_by_level_id(level_id: Global.LEVELS, fade_anim: String = "FadeOut", do_fade_in: bool = true, length: float = 1.0, reset_data: bool = true) -> void:
	$GUI/Fader.speed_scale = 1.0/float(length)
	# if fadeOut isn't blank, play the fade out animation and then wait, otherwise skip this
	if fade_anim != "":
		$GUI/Fader.queue(fade_anim)
		await $GUI/Fader.animation_finished
	# error prevention
	emit_signal("scene_faded")
	await get_tree().process_frame
	get_tree().paused = false
	$GUI/Pause.hide()
	MusicController.stop_all_music_themes()
	Global.currentZone = Global.get_level_path(level_id)
	Global.nextZone = Global.get_level_path((level_id+1) % Global.LEVELS.size())
	Global.level_id = level_id
	Global.force_act_2 = Global.get_level_act_number(level_id) == 2
	get_tree().change_scene_to_file(Global.currentZone)
	# reset data level data, if reset data is true
	if reset_data:
		clear_dynamic_level_variables()
	else:
		Global.players.clear()
		Global.checkPoints.clear()
	if do_fade_in:
		fade_in(fade_anim)

## Plays a fade-out animation (don't forget to fade in right after that..)
#func fade_out(fade_anim: String = "", length: float = 1.0) -> void:
	#$GUI/Fader.speed_scale = 1.0/float(length)
	## if fadeOut isn't blank, play the fade out animation and then wait, otherwise skip this
	#if fade_anim != "":
		#$GUI/Fader.queue(fade_anim)
		#await $GUI/Fader.animation_finished
	## error prevention
	#emit_signal("scene_faded")
	#await get_tree().process_frame
	#get_tree().paused = false
	#$GUI/Pause.hide()
	##MusicController.stop_all_music_themes()

## Plays a fade_in animation (fading in without fading out would be funny ngl)
func fade_in(fade_anim: String, length: float = 1.0) -> void:
	$GUI/Fader.speed_scale = 1.0/float(length)
	$GUI/Fader.play_backwards(fade_anim)




## Clear dynamic variable when loading a level. Only use this when not loading from a special/bonus stage.
func clear_dynamic_level_variables():
	Global.players.clear()
	Global.checkPoints.clear()
	Global.waterLevel = null
	Global.gameOver = false
	if Global.is_in_any_stage_clear_phase():
		Global.currentCheckPoint = -1
		Global.levelTime = 0
		Global.timerActive = false
	
	Global.debug_object_cursor = 0
	Global.bonus_stage_saved_position = Vector2.ZERO
	Global.bonus_stage_saved_rings = 0
	Global.bonus_stage_saved_time = 0.0
	
	Global.reset_stage_clear_phase()
	Global.nodeMemory.clear()
	if Global.nextZone == Global.startScene:
		Global.score = 0
	if Global.get_level_path((Global.level_id+1) % Global.LEVELS.size()) != Global.currentZone and \
	Global.get_level_path((Global.level_id+1) % Global.LEVELS.size()) == Global.nextZone:
		Global.cool_value = 10000

## reset values, self explanatory, put any variables to their defaults in here
func reset_values():
	Global.PlayerChar1 = Global.CHARACTERS.SONIC
	Global.PlayerChar2 = Global.CHARACTERS.KNUCKLES
	Global.lives = 3
	Global.score = 0
	Global.continues = 0
	Global.levelTime = 0
	Global.emeralds = 0
	Global.specialStageID = 0
	Global.checkPoints.clear()
	Global.checkPointTime = 0
	Global.currentCheckPoint = -1
	Global.animals = [Animal.ANIMAL_TYPE.BIRD, Animal.ANIMAL_TYPE.SQUIRREL]
	Global.nodeMemory.clear()
	Global.nextZone = "res://Scene/Zones/BaseZone.tscn"
