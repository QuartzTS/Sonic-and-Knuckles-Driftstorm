extends Node

## player pointers (0 is usually player 1)
var players: Array[PlayerChar] = []
## hud object reference
var hud = null

## checkpoint memory
var checkPoints: Array = []
## reference for the current checkpoint
var currentCheckPoint: int = -1
## the current level time when touching a Checkpoint
var checkPointTime: float = 0

## Special Stage/Bonus Stage room preservation
## Saved position when touching a special ring
var bonus_stage_saved_position: Vector2 = Vector2.ZERO
## Ring count when touching a special ring
var bonus_stage_saved_rings: int = 0
## Saved time when touching a special ring
var bonus_stage_saved_time: float = 0
## Memory of interacted objects from the current saved zone.
var nodeMemory = []
## TODO: Seperate memory for the special rings, they should not come back after dying.

## the starting room, this is loaded on game resets, you may want to change this
var startScene: String = "res://Scene/Presentation/Title.tscn"
## Path to the current level, for returning from special stages.
var currentZone: String = ""
## Path to the first level in the game (set in "reset_values")
var nextZone: String = ""

# order for score combo
const SCORE_COMBO = [1,2,3,4,4,4,4,4,4,4,4,4,4,4,4,5]

# timerActive sets if the stage timer should be going
var timerActive = false
var gameOver = false

# stage clear is used to identify the current state of the stage clear sequence
# this is referenced in
# res://Scripts/Global/Main.gd
# res://Scripts/Misc/HUD.gd
# res://Scripts/Objects/Capsule.gd
# res://Scripts/Objects/GoalPost.gd
# res://Scripts/Player/Player.gd
enum STAGE_CLEAR_PHASES { NOT_STARTED, STARTED, GOALPOST_SPIN_END, SCORE_TALLY }
var _stage_clear_phase: STAGE_CLEAR_PHASES = STAGE_CLEAR_PHASES.NOT_STARTED:
	get = get_stage_clear_phase, set = set_stage_clear_phase
func get_stage_clear_phase() -> STAGE_CLEAR_PHASES:
	return _stage_clear_phase
func set_stage_clear_phase(value: STAGE_CLEAR_PHASES) -> void:
	_stage_clear_phase = value
func is_in_any_stage_clear_phase() -> bool:
	return get_stage_clear_phase() != STAGE_CLEAR_PHASES.NOT_STARTED
func reset_stage_clear_phase() -> void:
	set_stage_clear_phase(Global.STAGE_CLEAR_PHASES.NOT_STARTED)


# Sound, used for play_sound (used for a global sound, use this if multiple nodes use the same sound)
var soundChannel = AudioStreamPlayer.new()

# Gameplay values
var score: int = 0
var lives = 3
## Not actually implimented.
var continues = 0
# emerald bit flags
enum EMERALDS {
	RED    = 1 << 0,
	BLUE   = 1 << 1,
	GREEN  = 1 << 2,
	YELLOW = 1 << 3,
	CYAN   = 1 << 4,
	SILVER = 1 << 5,
	PURPLE = 1 << 6,
	ALL = (1 << 7) - 1
}
# emeralds use bitwise flag operations, the equivalent for 7 emeralds would be 127
var emeralds: int = (func() -> int:
	# make sure EMERALDS.ALL holds a correct value
	assert(EMERALDS.ALL == (1 << EMERALDS.size() - 1) - 1)
	return 0
).call()
var specialStageID = 0
var level = null # reference to the currently active level
var levelTime = 0 # the timer that counts down while the level isn't completed or in a special ring
var globalTimer = 0 # global timer, used as reference for animations
const maxTime: int = 60*10
## Additional score that rewards players for not taking damage
var cool_value: int = 10000
## Object cursor for debug mode
var debug_object_cursor: int = 0


## water level of the current level, setting this to null will disable the water
var waterLevel = null
## used by other nodes to change the water level
var setWaterLevel = 0
## How fast to move the water to different levels
var waterScrollSpeed = 64

# characters (if you want more you should add one here, see the player script too for more settings)
enum CHARACTERS {NONE,SONIC,TAILS,KNUCKLES,AMY,SHADOW}

var _player_shaders := [
	preload("res://Shaders/PlayerPalette.tres"), # NONE should never come into play
	preload("res://Shaders/PlayerPalettes/SonicPalette.tres"),
	preload("res://Shaders/PlayerPalettes/TailsPalette.tres"),
	preload("res://Shaders/PlayerPalettes/KnucklesPalette.tres"),
	preload("res://Shaders/PlayerPalettes/AmyPalette.tres"),
	preload("res://Shaders/PlayerPalettes/ShadowPalette.tres"),
]

func get_material_for_character(character: CHARACTERS) -> Material:
	return _player_shaders[character]

## Which multiplayer mode is in use alters some aspects of how the second (and on if that's ever
## implemented) works. Note that this is separate from concepts like split screen and it does not
## inherently set up a competitive 
##
## This is also a work in progress, not all intended features are currently implemented.
##
## NORMAL - Additional players are partner characters. They can't collect monitors. Rings they
##          collect are given to player 1. They don't die on hit. If the second controller is idle
##          for an extended period of time, Partner automation will take over. This is the normal
##          'little brother mode' multiplayer that you have in single player mode from the Genesis
##          games.
##  PEERS - Additional players are their own players. They can collect monitors. They get their
##          own rings. They take damage normally. They never get taken over by automation. They
##          have their own score count.
##          the main difference between this mode and VERSUS mode is that partner actions (and
##          Tails being able to carry a player around is the only one of these) work in this mode.
##          Also, when an act is finished, both players pass at the same time.
## VERSUS - Same as PEERS, but partner actions are disabled. When a Sign Post victory condition is
##          passed, the level does not immediately end and score is not tallied. Instead the final
##          time and ring bonus are stored for use in a results screen.
enum MULTIMODE {NORMAL = 0, PEERS = 1, VERSUS = 2}
var multiplayer_mode = MULTIMODE.NORMAL

# autofill the array with capitalized names from enum CHARACTERS
var character_names: Array = \
	CHARACTERS.keys().map(func(char_name: String): return char_name.capitalize())

var PlayerChar1: CHARACTERS = CHARACTERS.SONIC
var PlayerChar2: CHARACTERS = CHARACTERS.KNUCKLES


## Enum for levels (Documenting the enum elements is gonna be preferred)
enum LEVELS {
	BZ1, ## Base Zone Act 1
	BZ2, ## Base Zone Act 2
	EHZ ## Emerald Hill Zone
	}
## A dictionary that references levels with their labels, paths and act number
var level_info: Dictionary[LEVELS, Dictionary] = {
	LEVELS.BZ1: {path = "res://Scene/Zones/BaseZone.tscn", label = "Base Zone Act 1", act = 1}, ## Base Zone Act 1
	LEVELS.BZ2: {path = "res://Scene/Zones/BaseZone.tscn", label = "Base Zone Act 2", act = 2}, ## Base Zone Act 2
	LEVELS.EHZ: {path = "res://Scene/Zones/emerald_hill_zone.tscn", label = "Emerald Hill Zone", act = 0} ## Emerald Hill Zone
}
## ID of levels
var level_id: LEVELS = LEVELS.BZ1
## Same as level_id, but for attract reel mode only
var attract_reel_id: LEVELS = level_id
## Boolean variable for attract reel mode
var attract_reel: bool = false
## Plays an act 1 intro cutscene if true (Coming soon..)
var play_intro: bool = false
## Plays an act trantition if true
var act_transition: bool = false
## Skips act transition if act 1 is finished by a goalpost or a capsule spawned by debug mode (Also coming soon..)
var force_act_2: bool = false
## Emitted whenever a cutscene is finished (Also coming soon..)
signal cutscene_finished

## Level settings
var hardBorderLeft = -100000000
var hardBorderRight = 100000000
var hardBorderTop = -100000000
var hardBorderBottom = 100000000


## Animal spawn type reference, see the level script for more information on the types
var animals: Array[Animal.ANIMAL_TYPE] = [Animal.ANIMAL_TYPE.BIRD, Animal.ANIMAL_TYPE.SQUIRREL]

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

# Game settings
var zoom_size = 2.0
var smooth_rotation = 0
enum TIME_TRACKING_MODES { STANDARD, SONIC_CD }
var time_tracking: TIME_TRACKING_MODES = TIME_TRACKING_MODES.STANDARD
var time_limit = 1
var extended_camera = 0
var discord_rpc = 0

## Hazard type references
enum HAZARDS {NORMAL, FIRE, ELEC, WATER}

# Layers references
enum LAYERS {LOW, HIGH}


func _ready():
	# set sound settings
	add_child(soundChannel)
	soundChannel.bus = "SFX"
	# load game data
	load_settings()

func _process(delta):
	# do a check for certain variables, if it's all clear then count the level timer up
	if !is_in_any_stage_clear_phase() and !gameOver and !get_tree().paused and timerActive:
		levelTime += delta
	# count global timer if game isn't paused
	if !get_tree().paused:
		globalTimer += delta
	


## use this to play a sound globally, use load("res:..") or a preloaded sound
func play_sound(sound = null) -> void:
	if sound != null:
		soundChannel.stream = sound
		soundChannel.play()


## use a check function to see if a score increase would go above 50,000
func check_score_life(score_add: int = 0) -> void:
	if score / 50000 < (score + score_add) / 50000:
		MusicController.play_music_theme(MusicController.MusicTheme._1UP)
		lives += 1


func emit_stage_start() -> void:
	stage_started.emit()

func emit_stage_end() -> void:
	stage_ended.emit()

func emit_cutscene_finished() -> void:
	cutscene_finished.emit()

func emit_screen_shake() -> void:
	screen_shake.emit()

func emit_cycle_property() -> void:
	cycle_property.emit()

func emit_cycle_object() -> void:
	cycle_object.emit()

## Gets the level scene file path
func get_level_path(id: LEVELS = level_id) -> String:
	return level_info[id].path

## Gets the level name
func get_level_label(id: LEVELS = level_id) -> String:
	return level_info[id].label

## Gets the level act number
func get_level_act_number(id: LEVELS = level_id) -> int:
	return level_info[id].act

## use this to set the stage clear theme, only runs if stage clear phase is NONE
func stage_clear() -> void:
	if !is_in_any_stage_clear_phase():
		MusicController.stop_music_theme(MusicController.MusicTheme.LEVEL_THEME)
		MusicController.play_music_theme(MusicController.MusicTheme.STAGE_CLEAR)


## save data settings
func save_settings() -> void:
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


## load settings
func load_settings() -> void:
	var file = ConfigFile.new()
	var err = file.load("user://Settings.cfg")
	if err != OK:
		return
	
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
		resize_window(zoom_size)
	
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



func resize_window(new_zoom_size):
	var window = get_window()
	var new_size = Vector2i((get_viewport().get_visible_rect().size*new_zoom_size).round())
	window.set_position(window.get_position()+(window.size-new_size)/2)
	window.set_size(new_size)
	zoom_size = new_zoom_size
	
	
func get_zoom_size() -> float:
	return zoom_size


## Gets the main player.
func get_first_player() -> PlayerChar:
	return players[0]


## Useful for checking triggers that require specifically the first player to be on a gimmick	
func get_first_player_gimmick() -> ConnectableGimmick:
	return players[0].get_active_gimmick()


## Useful for gimmicks that can activate if any player is attached that don't need data about
## the specific player. A simple boolean of whether or not there is a player on a given
## ConnectableGimmick.
func is_any_player_on_gimmick(gimmick: ConnectableGimmick) -> bool:
	for player in players:
		if player.get_active_gimmick() == gimmick:
			return true
	return false


## Useful for gimmicks that need to potentially iterate through all attached players
func get_players_on_gimmick(gimmick) -> Array[PlayerChar]:
	var players_on_gimmick: Array[PlayerChar] = []
	for player in players:
		if player.get_active_gimmick() == gimmick:
			players_on_gimmick.append(player)
	return players_on_gimmick


## Simple check to see if the player is the first char
func is_player_first(player : PlayerChar) -> bool:
	if players[0] == player:
		return true
	return false


## Gets the index of the player selected
## @param player Which player you are checking
## @retval 0-N index of the player with 0 being player 1 and higher numbers
##             being later players
## @retval -1 if the player isn't in the inbox. That should be impossible unless
##            you make an orphaned player for some reason.
func get_player_index(player : PlayerChar) -> int:
	return players.find(player)


## get the current active camera
func getCurrentCamera2D() -> Camera2D:
	var viewport = get_viewport()
	if not viewport:
		return null
	var camerasGroupName = "__cameras_%d" % viewport.get_viewport_rid().get_id()
	var cameras = get_tree().get_nodes_in_group(camerasGroupName)
	for camera in cameras:
		if camera is Camera2D and camera.enabled:
			return camera
	return null


## the original game logic runs at 60 fps, this function is meant to be used to help calculate this,
## usually a division by the normal delta will cause the game to freak out at different FPS speeds
func div_by_delta(delta) -> float:
	return 0.016667*(0.016667/delta)


## get window size resolution as a vector2
func get_screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size
	
	
## Sets the current level (used as part of a level ready script usually)
func set_level(new_level: Level) -> void:
	self.level = new_level


## Gets the current level (useful for always knowing where the active level root is)
func get_level() -> Level:
	return self.level


## Gets the name of a character
func get_character_name(which: CHARACTERS) -> String:
	return character_names[which]


## Gets the current multiplayer mode	
func get_multimode() -> MULTIMODE:
	return multiplayer_mode


## Sets the multiplayer mode to the requested value
func set_multimode(new_multimode: MULTIMODE) -> void:
	self.multiplayer_mode = new_multimode


## Cycles the multiplayer mode
func cycle_multimode() -> void:
	self.multiplayer_mode = (self.multiplayer_mode + 1) % MULTIMODE.size() as MULTIMODE
