# Bruh.. was this thing even needed? I made it cuz since I've made the monitor node a regular Node2D and this 'MonitorBody' thing existed as a CharacterBody2D,
# it became the node that other nodes collide with.. I just wanted to put the monitor body and collision inside a
# seperate node that is a child of the monitor node itself and make the item icon a child to the monitor body till it gets reparented to the monitor node itself,
# so that the icon doesn't inherit its position from other nodes..
# And yes, ALL THAT JUST FOR THE ICON (man, this is stupid..)

extends CharacterBody2D

@onready var parent = get_parent()


# This function exists here because as I said before, this node is what other nodes collide with, and not the parent node, like the drilldive dust clouds, for example.
# It just calls the destroy() function from the parent node. (Yeah, I'm too lazy to move the parent destroy() function, and worried as well lol..)
func destroy():
	parent.destroy()


# Again, this is the node other nodes collide with, and not the parent node.. (This function is called from PhysicsObject.gd, btw..)
func physics_collision(body, hitVector):
	# Does anybody even need that? I put that here to fix the bug where monitors are destroyed after the nearby player lands on the ground with moonwalking,
	# but the bug still exists and idk why it even happens..
	#await get_tree().process_frame
	# Monitor head bouncing
	if hitVector.y < 0:
		parent.monitor_bounce()
		if body.movement.y < 0:
			body.movement.y *= -1
	# check that player has the rolling layer bit set
	elif body.get_collision_layer_value(20):
		# check conditions for interaction (and the player is the first player)
		if hitVector.x != 0:
			if body.movement.x != 0 and (body.playerControl == 1 or body.playerControl == -1):
				body.movement.y *= -1
				parent.playerTouch = body
				destroy()
			#else:
				## Stop horizontal movement
				#body.movement.x = 0
				#body.movement.y = -abs(body.movement.y)
		# check if player is not an ai or spindashing or drilldiving
		# if true then destroy
		elif body.movement.y != 0 and !body.ground and (body.playerControl == 1 or body.playerControl == -1):
			if body.currentState != body.STATES.SPINDASH and !body.get_collision_layer_value(24):
				body.movement.y = -abs(body.movement.y)
				if body.currentState == body.STATES.ROLL:
					body.movement.y = 0
				body.ground = false
				parent.playerTouch = body
				destroy()
			# Drilldive
			elif body.get_collision_layer_value(24):
				body.ground = false
				parent.playerTouch = body
				destroy()
		else:
			body.ground = true
			body.movement.y = 0
	return true
