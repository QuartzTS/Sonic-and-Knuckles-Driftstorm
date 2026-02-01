extends Node2D

@export var level_id: Global.LEVELS = Global.LEVELS.BZ1
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

@onready var player: PlayerChar = $Player ## Reference for player node, for no reason lol /j

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
			var input_arr = Array(dict[key].split(",",false,6))
			if input_arr.size() < 7:
				input_arr.resize(7)
			for i in input_arr.size():
				input_arr[i] = type_convert(input_arr[i],TYPE_INT)
			attract_reel_inputs_arr.append(input_arr)

func _ready():
	if setDefaultLeft:
		Global.hardBorderLeft = defaultLeftBoundry
	if setDefaultRight:
		Global.hardBorderRight = defaultRightBoundry
	if setDefaultTop:
		Global.hardBorderTop = defaultTopBoundry
	if setDefaultBottom:
		Global.hardBorderBottom = defaultBottomBoundry
	level_reset_data(false)
	Global.discord_rpc_customize(Global.level_paths[level_id].label, "Attract Reel Mode" if Global.attract_reel else "Just playing a lil..")
	set_process(Global.attract_reel)

# Attract reel mechanics (coded by yours truly lol)
func _process(_delta: float) -> void:
	# First, set player control variable to -1
	# I made it behave like normal during attract reel mode while also being controlled by code only (check Player.gd)
	player.playerControl = -1
	Main.sceneCanPause = false # Of course we shouldn't pause during attract reels lol
	if Global.timerActive:
		# Here is the movement code for each level.. but I think there SHOULD be a better method..
		#match (Global.attractReelID):
			#Global.LEVELS.BZ1:
				#player.inputs[player.INPUTS.XINPUT] = 1
				#if Global.levelTime >= 1 and Global.levelTime < 23:
					#player.inputs[player.INPUTS.ACTION] = 1
				#elif Global.levelTime >= 23 and Global.levelTime < 28.5:
					#player.inputs[player.INPUTS.ACTION] = 0
					#player.inputs[player.INPUTS.XINPUT] = -1
				#elif Global.levelTime >= 28.5:
					#player.inputs[player.INPUTS.XINPUT] = 1
			#Global.LEVELS.BZ2:
				#player.inputs[player.INPUTS.YINPUT] = -1
		for i in attract_reel_intervals.size():
			
				#var input_arr = Array(attract_reel_inputs.values()[arr].split(","))
				#for i in input_arr.size():
					#input_arr[i] = int(input_arr[i])
				#var i
				#for j in attract_reel_inputs_arr[arr]:
					#if j != 0:
						#i = typeof(j)
				#print(attract_reel_inputs_arr[i],type_string(typeof(attract_reel_inputs_arr[i])),attract_reel_intervals.values()[i])
				#print(attract_reel_inputs_arr)
				#player.inputs = attract_reel_inputs_arr[i] if attract_reel_intervals.size() == attract_reel_inputs_arr.size() and Global.levelTime >= attract_reel_intervals.values()[i].x and Global.levelTime < attract_reel_intervals.values()[i].y else [0,0,0,0,0,0,0]
				if Global.levelTime >= attract_reel_intervals.values()[i].x and Global.levelTime < attract_reel_intervals.values()[i].y:
					player.inputs = attract_reel_inputs_arr[i]
				#elif attract_reel_intervals.values()[i].y < attract_reel_intervals.values()[i+1].x:
					#player.inputs = [0,0,0,0,0,0,0]
		# Return to the starting scene after 30 secs or when the pause button is pressed
		if (Global.levelTime >= 30 or Input.is_action_just_pressed("gm_pause")) and Global.attract_reel:
			Global.attract_reel_id = (Global.attract_reel_id + 1) % Global.level_paths.size() as Global.LEVELS
			#if Input.is_action_just_pressed("gm_pause"):
				## Reset the next attract reel to the first level only if the pause button is pressed
				## Comment this when testing attract reels to be able to quickly go to the next one with a press of a button
				#Global.attractReelID = 0 as Global.LEVELS
			#Global.attract_reel = false
			#player.inputs = [0,0,0,0,0,0,0]
			#Global.music.stop()
			#Global.effectTheme.stop()
			#Global.soundChannel.stop()
			#Global.bossMusic.stop()
			#Main.set_volume(0)
			get_tree().paused = true
			#Main.change_scene(Global.startScene,"FadeOut")
			#await Main.scene_faded
			## Reset the values when moving to the start scene..
			## Previous values shouldn't be carried over to the next attract reels nor even to the main game
			#Global.reset_game_values()
			#get_tree().paused = false
			Main.reset_game()
			


# used for stage starts, also used for returning from special stages
func level_reset_data(playCard = true):
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
	
	# set next zone
	if nextZone != null:
		Global.nextZone = nextZone
	
	Main.sceneCanPause = true
	# set animals
	Global.animals = [animal1,animal2]
	Global.level_id = level_id
	# if global hud and play card, run hud ready script
	if playCard and is_instance_valid(Global.hud):
		$HUD._ready()
