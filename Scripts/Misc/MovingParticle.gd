# Script for particles that move, duh..
# This might seem kinda niche, but needed for stuff like Knuckles' drill dive dust clouds,
# especially since normal particles can't move AT ALL (which is pretty annoying, to be honest..)

extends CharacterBody2D


## Destroys enemies and monitors that collide with it when true
var collide: bool = true

## The damage area is referenced here so that the properties can be easily changed externally
@onready var damage_area: Area2D = $DamageArea


# Set collision and mask values to true if the collide property is true
#func _ready() -> void:
	#damage_area.set_collision_layer_value(24,collide)
	#damage_area.set_collision_mask_value(24,collide)

func _physics_process(_delta: float) -> void:
	move_and_slide() # Moves.. (For real, what else to expect? Just move and slide xd..)
	
	#print(damage_area.get_collision_layer_value(24))
	await get_child(0).animation_finished
	queue_free() # Free the particle after animation is finished


# Just testing how the movement would be without inheriting from the CharacterBody2D class..
# I think making a particle class will be ENTIRELY better than this mess..

#var velo = 1
#var direction = Vector2.RIGHT
#
#func _physics_process(delta: float) -> void:
	#translate(velo*delta*60)
	#if abs(velo) > Vector2.ZERO:
		#velo += delta*sign(velo)
	#await get_child(0).animation_finished
	#queue_free()
