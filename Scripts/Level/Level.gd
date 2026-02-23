extends Node2D

@export var level_id: Global.LEVELS = Global.LEVELS.BZ1
var act: int
@export var music = preload("res://Audio/Soundtrack/6. SWD_TLZa1.ogg")
@export var bossMusic = preload("res://Audio/Soundtrack/5. SWD_Boss.ogg")
@export var nextZone: String = "res://Scene/Zones/BaseZone.tscn"

@export_enum("Bird", "Squirrel", "Rabbit", "Chicken", "Penguin", "Seal", "Pig", "Eagle", "Mouse", "Monkey", "Turtle", "Bear")var animal1 = 0
@export_enum("Bird", "Squirrel", "Rabbit", "Chicken", "Penguin", "Seal", "Pig", "Eagle", "Mouse", "Monkey", "Turtle", "Bear")var animal2 = 1

# Boundries
@export var setDefaultLeft = true
@export var defaultLeftBoundry  = -100000000
@export var setDefaultTop = true
@export var defaultTopBoundry  = -100000000

@export var setDefaultRight = true
@export var defaultRightBoundry = 100000000
@export var setDefaultBottom = true
@export var defaultBottomBoundry = 100000000

@export var player: PlayerChar ## Reference for player node, for no reason lol /j
@export var spawn_position: Vector2

## A dictionary that stores the time intervals in a Vector2 format, where x is the startpoint and y is the endpoint
@export var attract_reel_intervals: Dictionary[String,Vector2]
## An array to store input arrays made by the attract_reel_inputs setter, idk why I did this to myself, bruh..
var attract_reel_inputs_arr: Array[Array]
## A dictionary that stores botted player inputs in a string format, like "0,0,0,0,0,0,0",
## then the entered string gets processed and the resulted array is appended to attract_reel_inputs_arr
## (I need to think of a better way)
@export var attract_reel_inputs: Dictionary[String,String]:
	set(dict):
		for key in dict:
			var input_arr: Array[int] = Array(dict[key].split(",",false,6))
			if input_arr.size() < 7:
				input_arr.resize(7)
			#for i in input_arr.size():
				#input_arr[i] = type_convert(input_arr[i],TYPE_INT)
			attract_reel_inputs_arr.append(input_arr)

func _ready():
	act = Global.get_level_act_number(level_id)
	if (act != 2 and !Global.force_act_2) or (act == 2 and Global.force_act_2):
		level_reset_data(false)
		
	Global.stage_ended.connect(Callable(self,"level_reset_data"))
	set_process(Global.attract_reel) # Only call _process if attract reel is on

# Attract reel mechanics (coded by yours truly lol)
func _process(_delta: float) -> void:
	# First, set player control variable to -1
	# I made it behave like normal during attract reel mode while also being controlled by code only (check Player.gd)
	player.playerControl = -1
	Main.sceneCanPause = false # Of course we shouldn't pause during attract reels lol
	if Global.timerActive:
		# Here is the movement code
		for i in attract_reel_intervals.size():
			if Global.levelTime >= attract_reel_intervals.values()[i].x and Global.levelTime < attract_reel_intervals.values()[i].y:
				player.inputs = attract_reel_inputs_arr[i]
		# Return to the starting scene after 30 secs or when the pause button is pressed
		if (Global.levelTime >= 30 or Input.is_action_just_pressed("gm_pause")) and Global.attract_reel:
			Global.attract_reel_id = (Global.attract_reel_id+1) % Global.LEVELS.size() as Global.LEVELS
			#if Input.is_action_just_pressed("gm_pause"):
				## Reset the next attract reel to the first level only if the pause button is pressed
				## Comment this when testing attract reels to be able to quickly go to the next one with a press of a button
				#Global.attract_reel_id = Global.LEVELS.BZ1
			get_tree().paused = true
			# Reset the values when moving to the start scene..
			# Previous values shouldn't be carried over to the next attract reels nor even to the main game
			Main.reset_game()
			


# used for stage starts, act transitions (sorta..) and returning from special stages
func level_reset_data(playCard = true):
	if Global.players and player and ((act != 2 and !Global.force_act_2) or (act == 2 and Global.force_act_2)) and !Global.act_transition and Global.currentCheckPoint == -1:
		player.global_position = spawn_position
		player.camera.global_position = spawn_position
		if player.partner:
			player.partner.global_position = spawn_position-Vector2(24,0)
			player.partner.camera.global_position = spawn_position
	# music handling
	Global.bossMusic.stop()
	if Global.music != null:
		if music != null:
			Global.music.stream = music
			Global.music.play()
			Global.music.stream_paused = false
		else:
			Global.music.stop()
			Global.music.stream = null
	
	if Global.bossMusic != null and bossMusic != null:
		Global.bossMusic.stream = bossMusic
	
	if setDefaultLeft and ((act != 2 and !Global.force_act_2) or (act == 2 and Global.force_act_2)) and !Global.act_transition:
		Global.hardBorderLeft = defaultLeftBoundry
	if setDefaultRight:
		Global.hardBorderRight = defaultRightBoundry
	if setDefaultTop:
		Global.hardBorderTop = defaultTopBoundry
	if setDefaultBottom:
		Global.hardBorderBottom = defaultBottomBoundry
	
	Global.currentZone = Global.get_level_path(level_id)
	# set next zone
	if nextZone != null:
		Global.nextZone = nextZone
	
	Main.sceneCanPause = true
	# set animals
	Global.animals = [animal1,animal2]
	Global.level_id = level_id
	Global.discord_rpc_customize(Global.get_level_label(level_id), "Attract Reel Mode" if Global.attract_reel else "Just playing a lil..")
	# if global hud and play card, run hud ready script
	if playCard and is_instance_valid(Global.hud):
		Global.hud.initialize_hud()
	Global.act_transition = false
	Global.force_act_2 = false
