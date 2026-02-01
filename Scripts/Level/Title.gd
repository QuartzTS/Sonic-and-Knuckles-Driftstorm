extends Node2D

@export var music = preload("res://Audio/Soundtrack/9. SWD_TitleScreen.ogg")
@export var speed = 0
@export var nextScene: String = "res://Scene/Presentation/CharacterSelect.tscn"
var titleEnd = false

func _ready():
	if Global.music != null:
		if music != null:
			Global.music.stream = music
			Global.music.play()
			Global.music.stream_paused = false
		else:
			Global.music.stop()
			Global.music.stream = null
	Global.discord_rpc_customize("Title screen", "Are you ready?")

func _process(delta):
	# animate cogs
	$Logo/BackCog.rotate(delta*speed)
	$Logo/BigCog.rotate(-delta*2*speed)
	$Logo/BigCog/CogCircle.rotate(delta*2*speed)
	$Logo/Sonic/Cog.rotate(-delta*1.5*speed)
	# Play an attract reel after music finishes
	if $CanvasLayer/Labels.visible:
		await Global.music.finished
		if !titleEnd:
			titleEnd = true
			Global.attract_reel = true
			Main.change_scene(Global.level_paths[Global.attract_reel_id].path)
	

func _input(event):
	# end title on start press
	if event.is_action_pressed("gm_pause") and $CanvasLayer/Labels.visible and !titleEnd:
		titleEnd = true
		if Global.music.get_playback_position() < 14.0:
			Global.music.seek(14.0)
		Main.change_scene(nextScene)
		$Celebrations.emitting = true
	# This is just for attract reel quick testing.. cuz fr, who likes waiting for 15 seconds lol
	elif event.is_action_pressed("gm_action") and $CanvasLayer/Labels.visible and !titleEnd:
		titleEnd = true
		Global.attract_reel = true
		Main.change_scene(Global.level_paths[Global.attract_reel_id].path)
		
