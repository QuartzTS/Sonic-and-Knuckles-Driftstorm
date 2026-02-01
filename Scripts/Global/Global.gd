extends Node

## player pointers (0 is usually player 1)
var players: Array[PlayerChar] = []
## hud object reference
var hud = null
## checkpoint memory
var checkPoints: Array = []
## reference for the current checkpoint
var currentCheckPoint: int = -1
## the current level time when touching a Checkpoint or special ring
var checkPointTime: float = 0

## Saved position when accessing a special stage
var bonus_stage_saved_position: Vector2 = Vector2.ZERO
## Ring count when accessing a special stage
var bonus_stage_saved_rings: int = 0
## Time when accessing a special stage
var bonus_stage_saved_time: float = 0.0

## the starting room, this is loaded on game resets, you may want to change this
var startScene: String = "res://Scene/Presentation/Title.tscn"
## Path to the current level, for returning from special stages.
var currentZone: String = ""
## Path to the first level in the game (set in "reset_game_values")
var nextZone: String = "res://Scene/Zones/BaseZone.tscn"
# use this to store the current state of the room, changing scene will clear everythin
var stageInstanceMemory = null
var stageLoadMemory = null

# score instace for add_score()
var Score = preload("res://Entities/Misc/Score.tscn")
# order for score combo
const SCORE_COMBO = [1,2,3,4,4,4,4,4,4,4,4,4,4,4,4,5]

# timerActive sets if the stage timer should be going
var timerActive = false
var gameOver = false

# stage clear is used to identify the current state of the stage clear sequence
# this is reference in
# res://Scripts/Misc/HUD.gd
# res://Scripts/Objects/GoalPost.gd
var stageClearPhase = 0

# TODO: There's not much point in having seperate music, bossMusic, and effectThemes,
# These seperate sound banks can never play at the same time, so should be unified.
# life having its own bank is fine as the position of the previous track needs to be recalled.
# Music
var musicParent = null
var music = null
var bossMusic = null
var effectTheme = null
var drowning = null
var life = null
# TODO: Normal Level theme, boss theme, and Super theme could be here too.
## song themes to play for things like invincibility and speed shoes
var themes = [
	preload("res://Audio/Soundtrack/1. SWD_Invincible.ogg"),
	preload("res://Audio/Soundtrack/2. SWD_SpeedUp.ogg"),
	preload("res://Audio/Soundtrack/4. SWD_StageClear.ogg")]
# index for current theme
var currentTheme = 0

# Sound, used for play_sound (used for a global sound, use this if multiple nodes use the same sound)
var soundChannel = AudioStreamPlayer.new()

# Gameplay values
## Current Score.
var score = 0
## The current Life Count of the player
var lives = 3
## Not actually implimented.
var continues = 0
## Chaos emeralds use bitwise flag operations, the equivelent for 7 emeralds would be 128
var emeralds = 0
## emerald bit flags
enum EMERALD {RED = 1, BLUE = 2, GREEN = 4, YELLOW = 8, CYAN = 16, SILVER = 32, PURPLE = 64}
## ID of the upcoming special stage.
var specialStageID = 0
## the timer that counts down while the level isn't completed or in a special ring
var levelTime: float = 0
## global timer, used as reference for animations
var globalTimer: float = 0
## Time limit in levels
const maxTime: int = 60*10
## Additional score that rewards players for not taking damage
var cool_value: int = 10000


## water level of the current level, setting this to null will disable the water
var waterLevel = null
## used by other nodes to change the water level
var setWaterLevel = 0
## How fast to move the water to different levels
var waterScrollSpeed = 64

## Characters (if you want more you should add one here, see the player script too for more settings)
enum CHARACTERS {NONE,SONIC,TAILS,KNUCKLES,AMY}
var PlayerChar1 = CHARACTERS.SONIC
var PlayerChar2 = CHARACTERS.KNUCKLES


## Enum for levels (Documenting the enum elements is gonna be preferred)
enum LEVELS {
	BZ1, ## Base Zone Act 1
	BZ2, ## Base Zone Act 2
	EHZ ## Emerald Hill Zone
	}
## A dictionary that references levels with their labels and paths
var level_paths: Dictionary[LEVELS, Dictionary] = {
	LEVELS.BZ1: {path = "res://Scene/Zones/BaseZone.tscn", label = "Base Zone Act 1"}, ## Base Zone Act 1
	LEVELS.BZ2: {path = "res://Scene/Zones/BaseZoneAct2.tscn", label = "Base Zone Act 2"}, ## Base Zone Act 2
	LEVELS.EHZ: {path = "res://Scene/Zones/emerald_hill_zone.tscn", label = "Emerald Hill Zone"} ## Emerald Hill Zone
}
## ID of levels
var level_id: LEVELS = LEVELS.BZ1
## Same as level_id, but for attract reel mode only
var attract_reel_id: LEVELS = level_id
## Variable for attract reel mode
var attract_reel: bool = false

## Level settings
var hardBorderLeft = -100000000
var hardBorderRight = 100000000
var hardBorderTop = -100000000
var hardBorderBottom = 100000000

## Animal spawn type reference, see the level script for more information on the types
var animals = [0,1]

## Emited when a stage gets started
signal stage_started
## Emitted when a stage ends
signal stage_ended

## Emitted when the camera shakes
signal screen_shake
## Emitted when cycling through values of properties for certain objects in debug mode
signal cycle_property
## Emitted when all variations of te object are previewed in debug mode
signal cycle_object

## Memory of interacted objects from the current zone saved zone.
var nodeMemory = []

# Game settings
var zoom_size = 2
var smooth_rotation = 0
enum TIME_TRACKING_MODES { STANDARD, SONIC_CD }
var time_tracking: TIME_TRACKING_MODES = TIME_TRACKING_MODES.STANDARD
var time_limit = 1
var extended_camera = 0
var discord_rpc = 0

# Hazard type references
enum HAZARDS {NORMAL, FIRE, ELEC, WATER}

# Layers references
enum LAYERS {LOW, HIGH}


func _ready():
	# set sound settings
	add_child(soundChannel)
	soundChannel.bus = "SFX"
	# load game data
	load_settings()
	get_tree().paused = false
	

func _process(delta):
	# do a check for certain variables, if it's all clear then count the level timer up
	if stageClearPhase == 0 and !gameOver and !get_tree().paused and timerActive:
		levelTime += delta
	# count global timer if game isn't paused
	if !get_tree().paused:
		globalTimer += delta


# use this to play a sound globally, use load("res:..") or a preloaded sound
func play_sound(sound = null):
	if sound != null:
		soundChannel.stream = sound
		soundChannel.play()

# add a score object, see res://Scripts/Misc/Score.gd for reference
func add_score(position = Vector2.ZERO,value = 0):
	var scoreObj = Score.instantiate()
	scoreObj.scoreID = value
	scoreObj.global_position = position
	add_child(scoreObj)

# use a check function to see if a score increase would go above 50,000
func check_score_life(scoreAdd = 0):
	if fmod(score,50000) > fmod(score+scoreAdd,50000):
		life.play()
		lives += 1
		effectTheme.volume_db = -100
		music.volume_db = -100
		bossMusic.volume_db = -100

# use this to set the stage clear theme, only runs if stageClearPhase isn't 0
func stage_clear():
	if stageClearPhase == 0:
		currentTheme = 2
		music.stream = themes[currentTheme]
		music.play()
		effectTheme.stop()
		bossMusic.stop()

func emit_stage_start():
	stage_started.emit()

func emit_stage_end():
	stage_ended.emit()

func emit_screen_shake():
	screen_shake.emit()

func emit_cycle_property():
	cycle_property.emit()

func emit_cycle_object():
	cycle_object.emit()

# save data settings
func save_settings():
	var file = ConfigFile.new()
	# save settings
	file.set_value("Volume","SFX",AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	file.set_value("Volume","Music",AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	
	file.set_value("Resolution","Zoom",zoom_size)
	file.set_value("Gameplay","SmoothRotation",smooth_rotation)
	file.set_value("Resolution","FullScreen",((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN)))
	file.set_value("HUD","TimeTracking",time_tracking)
	file.set_value("Gameplay","ExtendedCamera",extended_camera)
	file.set_value("HUD","TimeLimit",time_limit)
	file.set_value("Activity","DiscordRPC",discord_rpc)

	# save config and close
	file.save("user://Settings.cfg")

# load settings
func load_settings():
	var file = ConfigFile.new()
	var err = file.load("user://Settings.cfg")
	if err != OK:
		return false # Return false as an error
	
	if file.has_section_key("Volume","SFX"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),file.get_value("Volume","SFX"))
		# Set bus mute state
		AudioServer.set_bus_mute(
		AudioServer.get_bus_index("SFX"), # Auidio bus to mute
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) <= -40.0 # True if < -40.0
		)
	
	if file.has_section_key("Volume","Music"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),file.get_value("Volume","Music"))
		# Set bus mute state
		AudioServer.set_bus_mute(
		AudioServer.get_bus_index("Music"), # Auidio bus to mute
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) <= -40.0 # True if < -40.0
		)
	
	if file.has_section_key("Resolution","Zoom"):
		zoom_size = file.get_value("Resolution","Zoom")
		var window = get_window()
		var newSize = Vector2i((get_viewport().get_visible_rect().size*zoom_size).round())
		window.set_position(window.get_position()+(window.size-newSize)/2)
		window.set_size(newSize)
	
	if file.has_section_key("Gameplay","SmoothRotation"):
		smooth_rotation = file.get_value("Gameplay","SmoothRotation")
	
	if file.has_section_key("Gameplay","ExtendedCamera"):
		extended_camera = file.get_value("Gameplay","ExtendedCamera")
	
	if file.has_section_key("HUD","TimeLimit"):
		time_limit = file.get_value("HUD","TimeLimit")

	if file.has_section_key("Resolution","FullScreen"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (file.get_value("Resolution","FullScreen")) else Window.MODE_WINDOWED

	if file.has_section_key("HUD","TimeTracking"):
		time_tracking = file.get_value("HUD","TimeTracking")
		if time_tracking < 0 or time_tracking >= TIME_TRACKING_MODES.size():
			time_tracking = TIME_TRACKING_MODES.STANDARD
	
	if file.has_section_key("Activity","DiscordRPC"):
		discord_rpc = file.get_value("Activity","DiscordRPC")

## Setting up Rich Presence
func discord_rpc_setup():
	if discord_rpc:
		DiscordRPC.app_id = 1428888019750096896
		#DiscordRPC.state = "Testing..."
		DiscordRPC.refresh()
	
## Customizing activity data, used when entering the next scene
func discord_rpc_customize(game_state: String, game_details: String, _large_image_key: String = "", _large_image_text: String = "", _small_image_key: String = "", _small_image_text: String = "", _start_timestamp: int = int(Time.get_unix_time_from_system()), _end_timestamp: int = 0):
	DiscordRPC.state = game_state
	DiscordRPC.details = game_details
	if discord_rpc:
		DiscordRPC.refresh()


## Useful for checking triggers that require specifically the first player to be on a gimmick	
func get_first_player_gimmick():
	return players[0].get_active_gimmick()

## Useful for gimmicks that can activate if any player is attached that don't need data about
## the specific player
func is_any_player_on_gimmick(gimmick):
	for player in players:
		if player.get_active_gimmick() == gimmick:
			return true
	return false

## Useful for gimmicks that need to potentially iterate through all attached players
func get_players_on_gimmick(gimmick):
	var players_on_gimmick = []
	for player in players:
		if player.get_active_gimmick() == gimmick:
			players_on_gimmick.append(player)
	return players_on_gimmick

## Simple check to see if the player is the first char
func is_player_first(player : PlayerChar):
	if players[0] == player:
		return true
	return false

## Gets the index of the player selected
## @param player Which player you are checking
## @retval 0-N index of the player with 0 being player 1 and higher numbers
##             being later players
## @retval -1 if the player isn't in the inbox. That should be impossible unless
##            you make an orphaned player for some reason.
func get_player_index(player : PlayerChar):
	return players.find(player)
