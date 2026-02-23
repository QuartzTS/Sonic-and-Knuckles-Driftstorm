extends CanvasLayer

# player instance
@export var focusPlayer = 0

# counter elements pointers
@onready var scoreText = $Counters/Text/ScoreNumber
@onready var timeText = $Counters/Text/TimeNumbers
@onready var ringText = $Counters/Text/RingCount
@onready var lifeText = $LifeCounter/Icon/LifeText

# play level card, if true will play the level card animator and use the zone name and zone text with the act
@export var playLevelCard = true
@export var zoneName = "Base"
@export var zone = "Zone"
#@export var act = 1

# used for flashing UI elements (rings, time)
var flashTimer = 0


# isStageEnding is used for level completion, stop loop recursions
var isStageEnding = false

# level clear bonuses (check _on_CounterCount_timeout)
var timeBonus = 0
var ringBonus = 0
var coolBonus = 0

# gameOver is used to initialize the game over animation sequence, note: this is for animation, if you want to use the game over status it's in global
var gameOver = false
signal gameover_signal

# used for the score countdown
var accumulatedDelta = 0.0

# signal that gets emited once the stage tally is over
signal tally_clear

# character name strings, used for "[player] has cleared", this matches the players character ID so you'll want to add the characters name in here matching the ID if you want more characters
# see Global.PlayerChar1
var characterNames = ["sonic","tails","knuckles","amy"]

func _ready():
	# create a new stream for the tick sound (so the original stream
	# will remain unchanged, as it's also used by the switch gimmick),
	# and set loop parameters, but don't enable looping yet
	$LevelClear/Counter.stream = $LevelClear/Counter.stream.duplicate()
	$LevelClear/Counter.stream.loop_end = roundi($LevelClear/Counter.stream.mix_rate / (60.0 / 4))
	
	# stop timer from counting during stage start up and set global hud to self
	Global.timerActive = false
	Global.hud = self
	# Set character Icon
	$LifeCounter/Icon.frame = Global.PlayerChar1-1
	initialize_hud()


func initialize_hud() -> void:
	var act = Global.get_level_act_number()
	# play level card routine if level card is true
	if playLevelCard and !Global.play_intro:
		# set level card
		$LevelCard.visible = true
		# set level name strings
		$LevelCard/Banner/LevelName.text = zoneName
		$LevelCard/Banner/Zone.text = zone
		# set act graphic
		if act != 0:
			$LevelCard/Banner/Act.visible = true
			$LevelCard/Banner/Act.frame = act-1
		else:
			$LevelCard/Banner/Act.visible = false
		if $LevelCard/Cover.visible:
			# make sure level card isn't paused so it can keep playing
			$LevelCard/CardPlayer.process_mode = PROCESS_MODE_ALWAYS
			# temporarily let music play during pauses
			if Global.musicParent != null:
				Global.musicParent.process_mode = PROCESS_MODE_ALWAYS
			# pause game while card is playing
			get_tree().paused = true
		# play card animations
		$LevelCard/CardPlayer.play("Start")
		$LevelCard/CardMover.play("Slider")
		# wait for card to finish it's entrance animation, then play the end
		await $LevelCard/CardPlayer.animation_finished
		$LevelCard/CardPlayer.play("End")
		# unpause the game and set previous pause mode nodes to stop on pause
		get_tree().paused = false
		Global.musicParent.process_mode = PROCESS_MODE_PAUSABLE
		$LevelCard/CardPlayer.process_mode = PROCESS_MODE_PAUSABLE
		# emit stage start signal
		Global.emit_stage_start()
		# wait for title card animator to finish ending before starting the level timer
		await $LevelCard/CardPlayer.animation_finished
	else:
		get_tree().paused = true
		await get_tree().process_frame # delay unpausing for one frame so the player doesn't die immediately
		await get_tree().process_frame # second one needed for player 2
		# emit the stage start signal and start the stage
		Global.emit_stage_start()
		get_tree().paused = false
		$LevelCard/Cover.hide()
	Global.timerActive = true
	# set the act clear frame
	if act != 0:
		$LevelClear/Act.visible = true
		$LevelClear/Act.frame = act-1
	else:
		$LevelClear/Act.visible = false
		$LevelClear/Through.text += " zone"


func _process(delta):
	# Change the life counter icon when character switching
	$LifeCounter/Icon.frame = Global.PlayerChar1-1
	# set score string to match global score with leading 0s
	scoreText.text = "%6d" % Global.score
	
	# clamp time so that it won't go to 10 minutes
	var hud_time = min(Global.levelTime,Global.maxTime-0.001)
	var hud_time_minutes:int = int(hud_time) / 60
	var hud_time_seconds:int = int(hud_time) % 60
	# set time text, format it to have a leading 0 so that it's always 2 digits
	match Global.time_tracking:
		Global.TIME_TRACKING_MODES.STANDARD:
			timeText.text = "%2d:%02d" % [hud_time_minutes,hud_time_seconds]
		Global.TIME_TRACKING_MODES.SONIC_CD:
			var hud_time_hundredths:int = int(hud_time * 100) % 100
			timeText.text = "%2d'%02d\"%02d" % [hud_time_minutes,hud_time_seconds,hud_time_hundredths]
	
	# check that there's player, if there is then track the focus players ring count
	if Global.players:
		ringText.text = "%3d" % Global.players[0].rings
	
	# track lives with leading 0s
	lifeText.text = "%2d" % Global.lives
	
	# Water Overlay
	
	# cehck that this level has water
	if Global.waterLevel != null:
		# get current camera
		var cam = GlobalFunctions.getCurrentCamera2D()
		if cam != null:
			# if camera exists place the water's y position based on the screen position as the water is a UI overlay
			$Water/WaterOverlay.position.y = clamp(Global.waterLevel-cam.get_screen_center_position().y+(get_viewport().get_visible_rect().size.y/2),0,get_viewport().get_visible_rect().size.y)
		# scale water level to match the visible screen
		$Water/WaterOverlay.scale.y = clamp(Global.waterLevel-$Water/WaterOverlay.position.y,0,get_viewport().size.y)
		$Water/WaterOverlay.visible = true
		
		# Water Overlay Elec flash
		if Global.players:
			# loop through players
			for i in Global.players:
				# check if in water and has elec or fire shield
				if i.water:
					match (i.shield):
						i.SHIELDS.ELEC:
							# reset shield do flash
							i.set_shield(i.SHIELDS.NONE)
							$Water/WaterOverlay/ElecFlash.visible = true
							# destroy all enemies in near player and below water
							for j in get_tree().get_nodes_in_group("Enemy"):
								if j.global_position.y >= Global.waterLevel and i.global_position.distance_to(j.global_position) <= 256:
									if j.has_method("destroy"):
										Global.add_score(j.global_position,Global.SCORE_COMBO[0])
										j.destroy()
							# disable flash after a frame
							await get_tree().process_frame
							$Water/WaterOverlay/ElecFlash.visible = false
						i.SHIELDS.FIRE:
							# clear shield
							i.set_shield(i.SHIELDS.NONE)
	else:
		# disable water overlay
		$Water/WaterOverlay.visible = false
	
	
	# HUD flashing text
	if flashTimer < 0:
		flashTimer = 0.1
		if Global.players:
			# if ring count at zero, flash rings
			if Global.players[0].rings <= 0:
				$Counters/Text/Rings.visible = !$Counters/Text/Rings.visible
			else:
				$Counters/Text/Rings.visible = false
		# if minutes up to 9 then flash time
		if Global.levelTime >= 60*9 and Global.levelTime < Global.maxTime:
			$Counters/Text/Time.visible = !$Counters/Text/Time.visible
		elif Global.levelTime >= Global.maxTime:
			$Counters/Text/Time.visible = true
		else:
			$Counters/Text/Time.visible = false
	elif !get_tree().paused:
		flashTimer -= delta
	
	# stage clear handling
	if Global.stageClearPhase >= 2:
		# initialize stage clear sequence
		if !isStageEnding:
			isStageEnding = true
			Global.discord_rpc_customize("Act Clear", "Just finished this level..")
			# reset air in case we are under water
			_reset_air()
			# Change character name in case of character switching
			$LevelClear/Passed.text = $LevelClear/Passed.text.replace(characterNames[Global.PlayerChar2-1],characterNames[Global.PlayerChar1-1])
			# show level clear elements
			$LevelClear.visible = true
			$LevelClear/Tally/ScoreNumber.text = scoreText.text
			$LevelClear/Animator.play("LevelClear")
			
			# set bonuses
			ringBonus = floor(Global.players[0].rings)*100
			$LevelClear/Tally/RingNumbers.text = "%6d" % ringBonus
			timeBonus = 0
			# bonus time table
			var bonusTable = [
			[60*5,500],
			[60*4,1000],
			[60*3,2000],
			[60*2,3000],
			[60*1.5,4000],
			[60,5000],
			[45,10000],
			[30,50000],
			]
			# loop through the bonus table, if current time is less then the first value then set it to that bonus
			# you'll want to make sure the order of the table goes down in time and up in score otherwise it could cause some weirdness
			for i in bonusTable:
				if Global.levelTime < i[0]:
					timeBonus = i[1]
			# set bonus text for time
			$LevelClear/Tally/TimeNumbers.text = "%6d" % timeBonus
			coolBonus = max(Global.cool_value,0)
			$LevelClear/Tally/CoolNumber.text = "%6d" % coolBonus
			# wait for counter wait time to count down
			$LevelClear/CounterWait.start(6)
			await $LevelClear/CounterWait.timeout
			# start the level counter tally (see _on_CounterCount_timeout)
			$LevelClear/CounterCount.start()
			# initially the tick sound isn't looped, so let's make it loop
			$LevelClear/Counter.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			$LevelClear/Counter.play()
			if $LevelClear/CounterWait.is_stopped() and (Input.is_action_just_pressed("gm_pause") or Input.is_action_just_pressed("gm_action")):
				var total_points = ringBonus+timeBonus+coolBonus
				Global.score += total_points
				Global.check_score_life(total_points)
				timeBonus = 0
				ringBonus = 0
				coolBonus = 0
				total_points = 0
			await self.tally_clear
			# wait 2 seconds (reuse timer)
			$LevelClear/CounterWait.start(2)
			await $LevelClear/CounterWait.timeout
			var act = Global.get_level_act_number()
			var next_act = Global.get_level_act_number((Global.level_id+1) % Global.LEVELS.size())
			if !Global.act_transition and !Global.force_act_2 and Global.currentZone == Global.nextZone and next_act == act+1:
				#Global.level_id = (Global.level_id + 1) as Global.LEVELS
				$LevelClear/Animator.play_backwards("LevelClear")
				await $LevelClear/Animator.animation_finished
				Main.clear_dynamic_level_variables()
				isStageEnding = false
				$LevelCard/Cover.hide()
				Global.act_transition = true
			elif Global.level_id+1 != Global.LEVELS.size():
				Main.change_scene_by_level_id((Global.level_id+1) % Global.LEVELS.size())
			else:
				Main.change_scene(Global.startScene)
			Global.emit_stage_end()
	
	# game over sequence
	elif Global.gameOver and !gameOver:
		# set game over to true so this doesn't loop
		gameOver = true
		# determine if the game over is a time over (game over and time over sequences are the same but game says time)
		if Global.levelTime >= Global.maxTime and Global.time_limit:
			$GameOver/Game.frame = 1
		# play game over animation and play music
		$GameOver/GameOver.play("GameOver")
		$GameOver/GameOverMusic.play()
		# stop normal music tracks
		Global.music.stop()
		Global.effectTheme.stop()
		Global.bossMusic.stop()
		Global.life.stop()
		# wait for animation to finish or action to be pressed
		await self.gameover_signal
		# reset game
		if Global.lives <= 0:
			Main.reset_game()
		# reset level (if time over and lives aren't out)
		elif Global.time_limit:
			Main.change_scene_by_level_id(Global.level_id)
			await Main.scene_faded
			Global.levelTime = 0
			Global.timerActive = false

func _reset_air():
	for i in Global.players:
		i.airTimer = i.defaultAirTime

func hide_hud() -> void:
	if visible:
		$HideHUD.play("HideHUD")
		await $HideHUD.animation_finished
		visible = false

func show_hud() -> void:
	if !visible:
		$HideHUD.play_backwards("HideHUD")
		visible = true

func _add_score(subtractFrom,delta):
	# Normally we add 100 points per frame at 60 FPS, but player's framerate may
	# be different. To accommodate for that, we count the number of points based
	# on time passed since the previous frame.
	accumulatedDelta += delta
	var standardDelta = 1.0 / 60.0
	var points = floor(accumulatedDelta / standardDelta) * 100
	if (points > subtractFrom):
		points = subtractFrom
	accumulatedDelta -= points / 100 * standardDelta
	# check if adding score would hit the life bonus
	Global.check_score_life(points)
	subtractFrom -= points
	Global.score += points
	return subtractFrom

# counter count down
func _on_CounterCount_timeout(delta):
	# reset air in case we are under water
	_reset_air()
	# decrease bonuses in order, if time bonus not 0 then count time down, then do the same for rings
	# if you add other bonuses (like perfect bonus) you'll want to add it to the end of the sequence before the end
	if timeBonus > 0:
		timeBonus = _add_score(timeBonus,delta)
	elif ringBonus > 0:
		ringBonus = _add_score(ringBonus,delta)
	elif coolBonus > 0:
		coolBonus = _add_score(coolBonus,delta)
	else:
		# Don't stop the tick sound abruptly, just disable looping,
		# so it stops by itself after it plays until the end once
		$LevelClear/Counter.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		# stop counter timer and play score sound
		$LevelClear/CounterCount.stop()
		$LevelClear/Score.play()
		# emit tally clear signal
		emit_signal("tally_clear")
	# set the level clear strings to the bonuses
	$LevelClear/Tally/ScoreNumber.text = scoreText.text
	$LevelClear/Tally/TimeNumbers.text = "%6d" % timeBonus
	$LevelClear/Tally/RingNumbers.text = "%6d" % ringBonus
	$LevelClear/Tally/CoolNumber.text = "%6d" % coolBonus


func _input(event: InputEvent) -> void:
	if isStageEnding and $LevelClear/CounterWait.is_stopped() and (Input.is_action_just_pressed("gm_pause") or Input.is_action_just_pressed("gm_action")):
		var total_points = ringBonus+timeBonus+coolBonus
		Global.score += total_points
		Global.check_score_life(total_points)
		timeBonus = 0
		ringBonus = 0
		coolBonus = 0
		total_points = 0
	if gameOver and (event.is_action_pressed("gm_pause") or event.is_action_pressed("gm_action")):
		emit_signal("gameover_signal")
	


func _on_game_over_animation_finished(_anim_name: StringName) -> void:
	emit_signal("gameover_signal")
