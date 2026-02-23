extends StaticBody2D
@export var pieces = Vector2(2,2)
var Piece = preload("res://Entities/Misc/BlockPiece.tscn")
@export var sound = preload("res://Audio/SFX/Gimmicks/Collapse.wav")
enum BREAK_STATE {BREAKABLE, DRILLDIVE_ONLY, UNBREAKABLE}
@export var break_state: BREAK_STATE = BREAK_STATE.BREAKABLE
@export var score = true
#@export var pushable = true

func physics_collision(body, hitVector):
	if hitVector == Vector2.DOWN and body.get_collision_layer_value(20):
		if break_state == BREAK_STATE.BREAKABLE or (break_state == BREAK_STATE.DRILLDIVE_ONLY and body.get_collision_layer_value(24)):
			# disable collision
			$CollisionShape2D.disabled = true
			$Sprite2D.visible = false
			Global.play_sound(sound)
			# set player variables
			body.ground = false
			if !body.get_collision_layer_value(24):
				body.movement.y = -3*60
			if score:
				Global.add_score(global_position,Global.SCORE_COMBO[min(Global.SCORE_COMBO.size()-1,body.enemyCounter)])
			body.enemyCounter += 1
			
			# generate pieces of the block to scatter, use i and j to determine the velocity of each one
			# and set the settings for each piece to match up with the $Sprite2D node
			for i in range(pieces.x):
				for j in range (pieces.y):
					var piece = Piece.instantiate()
					
					piece.velocity = Vector2(
					(pieces.y-j)*lerp(-1,1,i/(pieces.x-1)),
					-pieces.y+j)*60
					
					var spriteWidth = $Sprite2D.texture.get_width()
					var spriteHeight = $Sprite2D.texture.get_height()
					if $Sprite2D.region_enabled:
						spriteWidth = $Sprite2D.region_rect.size.x
						spriteHeight = $Sprite2D.region_rect.size.y
					
					piece.global_position = global_position+Vector2(
					spriteWidth/4*lerp(-1,1,i/(pieces.x-1)),
					spriteHeight/4*lerp(-1,1,j/(pieces.y-1))
					)
					piece.texture = $Sprite2D.texture
					piece.z_index = z_index
					piece.region_rect = Rect2(
					Vector2((spriteWidth/pieces.x)*i,(spriteHeight/pieces.y)*j),
					Vector2(spriteWidth/pieces.x,spriteHeight/pieces.y))
					get_parent().add_child(piece)
					
			return true

		else:
			body.ground = true
			body.movement.y = 0

	# Just an experiment for a pushable block
	#if pushable and body.ground and hitVector.x != 0 and (sign(body.pushingWall) == sign(hitVector.x) or (\
	#body.currentState == PlayerChar.STATES.SPINDASH and body.direction == hitVector.x)):
		#global_position.x += 0.25*60*get_physics_process_delta_time()*hitVector.x
		#body.movement.x += 0.5*60*hitVector.x
