extends PlayerState

var dashPower = 12

func state_process(delta: float) -> void:
	# dust sprite
	#var dash = parent.sprite.get_node("DashDust")
	#dash.visible = true
	#dash.flip_h = parent.sprite.flip_h
	#dash.offset.x = abs(dash.offset.x)*sign(-1+int(dash.flip_h)*2)
	
	dashPower = 6 if parent.water else 12
	
	
	# how much power the player has from the peelout
	var speedCalc = parent.spindashPower*60
	
	# increase spindashPower gradually
	parent.spindashPower = min(parent.spindashPower+delta*24,dashPower)
	parent.peelOutCharge = speedCalc
	
	# animation based on speed
	if speedCalc < 6*60:
		parent.animator.play("walk")
	elif parent.peelOutCharge < dashPower*60 or (parent.water and parent.peelOutCharge <= dashPower*60):
		parent.animator.play("run")
	elif !parent.water:
		parent.animator.play("peelOut")


	# release
	if parent.inputs[parent.INPUTS.YINPUT] >= 0 and parent.ground:
		# Lock camera
		parent.get_camera().lock((parent.spindashPower+4.0)/60.0)
		
		# Release
		parent.movement.x = speedCalc*parent.get_direction_multiplier()
		parent.sfx[32].play()
		parent.sfx[31].stop()
		parent.peelOutCharge = 0.0
		parent.set_state(parent.STATES.NORMAL)


func state_physics_process(delta: float) -> void:
	# Gravity
	if !parent.ground:
		parent.movement.y += parent.get_physics().gravity / GlobalFunctions.div_by_delta(delta)
