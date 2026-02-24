## This script is for zones that manage stuff for each act, like boundaries, music, attract reels etc.. and it can even manage cutscenes.
## All these features make it a good replacement for attaching a Level.gd script for each act in a zone scene.
## The drawback, tho, is that I had to define the variables that do the same thing for each act, which is kinda annoying..
## Btw, I ain't gonna remove Level.gd, I'll leave it be used for scenes with one act.
class_name Zone extends Node2D

#region Act 1 Variables
@export_group("Act 1", "act1_")
## Level ID of the first act
@export var act1_level_id: Global.LEVELS
## The music that plays during the first act
@export var act1_music: AudioStreamOggVorbis = preload("res://Audio/Soundtrack/6. SWD_TLZa1.ogg")
## The alternate music that the level can fade to
@export var act1_music_alt: AudioStream = null
## The music that plays during a bossfight in the first act
@export var act1_boss_music: AudioStreamOggVorbis = preload("res://Audio/Soundtrack/5. SWD_Boss.ogg")

## One of the animals that spawn in the first act
@export var act1_animal1: Animal.ANIMAL_TYPE = Animal.ANIMAL_TYPE.BIRD
## The other animal that spawns in the first act
@export var act1_animal2: Animal.ANIMAL_TYPE = Animal.ANIMAL_TYPE.SQUIRREL

## Boundries of the first act
@export var act1_set_default_left: bool = true
@export var act1_default_left_boundry: float = -100000000
@export var act1_set_default_top: bool = true
@export var act1_default_top_boundry: float = -100000000

@export var act1_set_default_right: bool = true
@export var act1_default_right_boundry: float = 100000000
@export var act1_set_default_bottom: bool = true
@export var act1_default_bottom_boundry: float = 100000000

## An exported variable that references the Marker2D that determines the spawn position of the player in the first act
@export var act1_spawn_marker: Marker2D

## A dictionary that stores the time intervals for the first act in a Vector2 format, where x is the startpoint and y is the endpoint
@export var act1_attract_reel_intervals: Dictionary[String,Vector2]
## An array to store input arrays made by the act1_attract_reel_inputs setter, idk why I did this to myself, bruh..
var act1_attract_reel_inputs_arr: Array[Array]
## A dictionary that stores botted player inputs in a string format, like "0,0,0,0,0,0,0",
## then the entered string gets processed and the resulted array is appended to act1_attract_reel_inputs_arr
## (I really need to think of a better way)
@export var act1_attract_reel_inputs: Dictionary[String,String]:
	set(dict):
		for key in dict:
			var input_arr: Array[int] = Array(dict[key].split(",",false,6))
			if input_arr.size() < 7:
				input_arr.resize(7)
			#for i in input_arr.size():
				#input_arr[i] = type_convert(input_arr[i],TYPE_INT)
			act1_attract_reel_inputs_arr.append(input_arr)
#endregion

#region Act 2 Variables
@export_group("Act 2", "act2_")
## Level ID of the second act
@export var act2_level_id: Global.LEVELS
## The music that plays during the second act
@export var act2_music: AudioStreamOggVorbis = preload("res://Audio/Soundtrack/6. SWD_TLZa1.ogg")
## The alternate music that the level can fade to
@export var act2_music_alt: AudioStream = null
## The music that plays during a bossfight in the second act
@export var act2_boss_music: AudioStreamOggVorbis = preload("res://Audio/Soundtrack/5. SWD_Boss.ogg")

## One of the animals that spawn in the second act
@export var act2_animal1: Animal.ANIMAL_TYPE = Animal.ANIMAL_TYPE.BIRD
## The other animal that spawns in the second act
@export var act2_animal2: Animal.ANIMAL_TYPE = Animal.ANIMAL_TYPE.SQUIRREL

## Boundries for the second act
@export var act2_set_default_left: bool = true
@export var act2_default_left_boundry: float = -100000000
@export var act2_set_default_top: bool = true
@export var act2_default_top_boundry: float = -100000000

@export var act2_set_default_right: bool = true
@export var act2_default_right_boundry: float = 100000000
@export var act2_set_default_bottom: bool = true
@export var act2_default_bottom_boundry: float = 100000000

## An exported variable that references the Marker2D that determines the spawn position of the player in the second act
@export var act2_spawn_marker: Marker2D

## A dictionary that stores the time intervals for the second act in a Vector2 format, where x is the startpoint and y is the endpoint
@export var act2_attract_reel_intervals: Dictionary[String,Vector2]
## An array to store input arrays made by the act2_attract_reel_inputs setter, idk why I did this to myself, bruh..
var act2_attract_reel_inputs_arr: Array[Array]
## A dictionary that stores botted player inputs in a string format, like "0,0,0,0,0,0,0",
## then the entered string gets processed and the resulted array is appended to act2_attract_reel_inputs_arr
## (I really need to think of a better way)
@export var act2_attract_reel_inputs: Dictionary[String,String]:
	set(dict):
		for key in dict:
			var input_arr: Array[int] = Array(dict[key].split(",",false,6))
			if input_arr.size() < 7:
				input_arr.resize(7)
			#for i in input_arr.size():
				#input_arr[i] = type_convert(input_arr[i],TYPE_INT)
			act2_attract_reel_inputs_arr.append(input_arr)
#endregion

#region Cutscene Variables
@export_group("Cutscenes")
## The cutscene that plays before the zone begins
@export var intro_cutscene: Cutscene
## The cutscene that plays during act transitions between acts 1 and 2
@export var act_transition_cutscene: Cutscene
## The cutscene that plays at the end of a zone
@export var ending_cutscene: Cutscene
#endregion

## A reference for the first player
var player: PlayerChar
## A variable that is set to the number of the active act
var current_level_act_number: int


# Setup the zone (this only works when first loading the zone or at restarts)
func _ready() -> void:
	# Make sure that the player variable stores the first player
	player = Global.players[0]
	# Set the number of the current act variable to the act number of the current level (whut?)
	# This is made possible because of the change_scene_by_level_id function in Main,
	# and that's just because I made it assign the global level_id variable to the id of the destination level
	current_level_act_number = Global.get_level_act_number()
	# Call the function that has the number of the current act
	Callable(self, "act%d_setup" % current_level_act_number).call()
	
	# Cutscene and act transition setups
	if current_level_act_number == 1:
		# Play da intro cutscene if it exists (coming soon..)
		if intro_cutscene and Global.play_intro:
			Global.stage_started.connect(Callable(intro_cutscene, "play_cutscene_sequence"))
			Global.cutscene_finished.connect(Callable(Global.hud, "initialize_hud"))
		# Make the act transition cutscene play after ending the first act if it exists, and then do the act transition after that
		if act_transition_cutscene:
			Global.stage_ended.connect(Callable(act_transition_cutscene, "play_cutscene_sequence"))
			Global.cutscene_finished.connect(Callable(self, "act2_setup"))
		# If the cutscene doesn't exist, then directly transition to act 2
		else:
			# Call the act2_setup function exclusively after ending act 1 to do the act transition
			Global.stage_ended.connect(Callable(self, "act2_setup"))
	# Make the ending cutscene play after finishing act 2 if it exists
	elif ending_cutscene:
		Global.stage_ended.connect(Callable(ending_cutscene, "play_cutscene_sequence"))
	
	# Make sure that either of the markers exists
	assert(act1_spawn_marker or act2_spawn_marker, "Don't forget to put da spawn marker(s)..")

func _process(_delta: float) -> void:
	# Attract reel mechanics (coded by yours truly lol)
	if Global.attract_reel:
		# First, set player control variable to -1
		# I made it behave like normal during attract reel mode while also being controlled by code only (check Player.gd)
		player.playerControl = -1
		Main.sceneCanPause = false # Of course we shouldn't pause during attract reels lol
		if Global.timerActive:
			Callable(self, "act%d_attract_reel" % current_level_act_number).call()
		# Return to the starting scene after 30 secs or when the pause button is pressed
		if Global.levelTime >= 30 or Input.is_action_just_pressed("gm_pause"):
			Global.attract_reel_id = (Global.attract_reel_id+1) % Global.LEVELS.size() as Global.LEVELS
			#if Input.is_action_just_pressed("gm_pause"):
				## Reset the next attract reel to the first level only if the pause button is pressed
				## Comment this when testing attract reels to be able to quickly go to the next one with a press of a button
				#Global.attract_reel_id = Global.LEVELS.BZ1
			get_tree().paused = true
			# Reset the values when moving to the start scene..
			# Previous values shouldn't be carried over to the next attract reels nor even to the main game
			Main.reset_game()

## Function for setting up act 1
func act1_setup() -> void:
	current_level_act_number = act1_level_id
	if act1_spawn_marker and player and Global.currentCheckPoint == -1:
		player.global_position = act1_spawn_marker.global_position
		player.get_camera().global_position = act1_spawn_marker.global_position
		if player.get_partner() != null:
			player.get_partner().global_position = act1_spawn_marker.global_position-Vector2(24,0)
		act1_spawn_marker.queue_free()
		act2_spawn_marker.queue_free()
	# music handling
	MusicController.reset_music_themes()
	if act1_music != null:
		MusicController.set_level_music(act1_music, act1_music_alt)
	
	#if Global.bossMusic != null and act1_boss_music != null:
		#Global.bossMusic.stream = act1_boss_music
	
	if act1_set_default_left:
		Global.hardBorderLeft = act1_default_left_boundry
	if act1_set_default_right:
		Global.hardBorderRight = act1_default_right_boundry
	if act1_set_default_top:
		Global.hardBorderTop = act1_default_top_boundry
	if act1_set_default_bottom:
		Global.hardBorderBottom = act1_default_bottom_boundry
	
	# set animals
	Global.animals = [act1_animal1,act1_animal2]
	
	Main.sceneCanPause = true
	Global.discord_rpc_customize(Global.get_level_label(), "Attract Reel Mode" if Global.attract_reel else "Just playing a lil..")
	Global.act_transition = false
	Global.force_act_2 = false

## Function for setting up act 2 (notice that it's a bit different from the act1_setup function)
func act2_setup() -> void:
	current_level_act_number = act2_level_id
	if act2_spawn_marker and player and !Global.act_transition and Global.currentCheckPoint == -1:
		player.global_position = act2_spawn_marker.global_position
		player.get_camera().global_position = act2_spawn_marker.global_position
		if player.get_partner() != null:
			player.get_partner().global_position = act2_spawn_marker.global_position-Vector2(24,0)
		act1_spawn_marker.queue_free()
		act2_spawn_marker.queue_free()
	# music handling
	MusicController.reset_music_themes()
	if act2_music != null:
		MusicController.set_level_music(act2_music, act2_music_alt)
	
	#if Global.bossMusic != null and act2_boss_music != null:
		#Global.bossMusic.stream = act2_boss_music
	
	if act2_set_default_left and !Global.act_transition:
		Global.hardBorderLeft = act2_default_left_boundry
	if act2_set_default_right:
		Global.hardBorderRight = act2_default_right_boundry
	if act2_set_default_top:
		Global.hardBorderTop = act2_default_top_boundry
	if act2_set_default_bottom:
		Global.hardBorderBottom = act2_default_bottom_boundry
	
	# set animals
	Global.animals = [act2_animal1,act2_animal2]
	
	if Global.act_transition:
		Global.hud.initialize_hud()
	
	Main.sceneCanPause = true
	Global.discord_rpc_customize(Global.get_level_label(), "Attract Reel Mode" if Global.attract_reel else "Just playing a lil..")
	Global.act_transition = false
	Global.force_act_2 = false

## Here is the movement code for act 1 attract reels
func act1_attract_reel() -> void:
	for i in act1_attract_reel_intervals.size():
		if Global.levelTime >= act1_attract_reel_intervals.values()[i].x and Global.levelTime < act1_attract_reel_intervals.values()[i].y:
			player.inputs = act1_attract_reel_inputs_arr[i]

## And here is the movement code for act 2 attract reels
func act2_attract_reel() -> void:
	for i in act2_attract_reel_intervals.size():
		if Global.levelTime >= act2_attract_reel_intervals.values()[i].x and Global.levelTime < act2_attract_reel_intervals.values()[i].y:
			player.inputs = act2_attract_reel_inputs_arr[i]
