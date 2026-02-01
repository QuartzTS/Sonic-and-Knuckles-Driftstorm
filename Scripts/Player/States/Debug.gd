extends PlayerState

# More is yet to come..
var objects: Array[PackedScene] = [
	preload("res://Entities/Items/Ring.tscn"),
	preload("res://Entities/Items/Monitor.tscn"),
	preload("res://Entities/Items/Checkpoint.tscn"),
	preload("res://Entities/Hazards/Spikes.tscn"),
	preload("res://Entities/Backgrounds/GHZWaterfall.tscn"),
	preload("res://Entities/Enemies/BuzzBomber.tscn"),
	preload("res://Entities/Enemies/Chomper.tscn"),
	preload("res://Entities/Enemies/MotoBug.tscn"),
	preload("res://Entities/Enemies/Orbinaut.tscn"),
	preload("res://Entities/Gimmicks/Bridge.tscn"),
	preload("res://Entities/Gimmicks/CNZBarrel.tscn"),
	preload("res://Entities/Gimmicks/CNZTrampolineBarrel.tscn"),
	preload("res://Entities/Gimmicks/ConveyorBelt.tscn"),
	preload("res://Entities/Gimmicks/fan.tscn"),
	preload("res://Entities/Gimmicks/HangingBar.tscn"),
	preload("res://Entities/Gimmicks/HorizontalBar.tscn"),
	preload("res://Entities/Gimmicks/Shutter.tscn"),
	preload("res://Entities/Gimmicks/SpeedBooster.tscn"),
	preload("res://Entities/Gimmicks/Spring.tscn"),
	preload("res://Entities/Gimmicks/Teleporter.tscn"),
	preload("res://Entities/Gimmicks/Trampoline.tscn"),
	preload("res://Entities/Gimmicks/VerticalBar.tscn"),
	preload("res://Entities/Hazards/Saw.tscn"),
	preload("res://Entities/Items/SpecialStageRing.tscn"),
	preload("res://Entities/MainObjects/Capsule.tscn"),
	preload("res://Entities/MainObjects/GoalPost.tscn"),
	preload("res://Entities/Misc/Animal.tscn"),
	preload("res://Entities/Obstacles/BreakableBlock.tscn"),
	preload("res://Entities/Obstacles/BreakableWall.tscn"),
	preload("res://Entities/Obstacles/Bumper.tscn"),
	preload("res://Entities/Obstacles/Platform.tscn"),
	preload("res://Entities/Obstacles/SwingingPlatform.tscn")
]
var object_cursor: int = 0
var object_preview: Node = null
var moved: bool = false
var move_speed: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	invulnerability = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug_mode"):
		parent.set_state(parent.STATES.NORMAL)
	if object_preview != null:
		object_preview.process_mode = Node.PROCESS_MODE_DISABLED
		object_preview.global_position = parent.global_position
	if parent.inputs[parent.INPUTS.ACTION2] == 1 or parent.inputs[parent.INPUTS.ACTION3] == 1:
		#if parent.inputs[parent.INPUTS.ACTION2] == 1:
			#object_cursor = wrapi(object_cursor+1,0,objects.size())
		#elif parent.inputs[parent.INPUTS.ACTION3] == 1:
		#var assign_property = ""
		#var dict = ["item", "type", "boostDirection", "springDirection"]
		#for property in dict:
			#if object_preview.get(property) != null:
				#assign_property = property
		#if assign_property != "":
			#object_preview.set(assign_property,object_preview.get(assign_property)+parent.inputs[parent.INPUTS.ACTION2]-parent.inputs[parent.INPUTS.ACTION3])
		#else:
		# or (object_preview.has_method("debug_change_property") and !object_preview.debug_change_property()):
		#if object_preview.has_method("debug_change_property"):
			#object_preview.debug_change_property()
			#print(object_cursor)
			#await Global.cycle_object
		await get_tree().process_frame
		object_cursor = wrapi(object_cursor+parent.inputs[parent.INPUTS.ACTION2]-parent.inputs[parent.INPUTS.ACTION3],0,objects.size())
		var new_object_preview: Node = objects[object_cursor].instantiate()
		object_preview.queue_free()
		object_preview = new_object_preview
		parent.add_child(object_preview)
		print(object_cursor)
	if parent.inputs[parent.INPUTS.ACTION] == 1 and object_preview != null:
		var object_spawn: Node = object_preview.duplicate()
		parent.get_parent().add_child(object_spawn)
		object_spawn.global_position = parent.global_position
		object_spawn.process_mode = Node.PROCESS_MODE_INHERIT

func _physics_process(delta: float) -> void:
	moved = parent.inputs[parent.INPUTS.XINPUT] or parent.inputs[parent.INPUTS.YINPUT]
	move_speed = (move_speed + 1)*int(moved)
	parent.movement = (move_speed*parent.acc/GlobalFunctions.div_by_delta(delta)*Vector2(
		parent.inputs[parent.INPUTS.XINPUT],
		parent.inputs[parent.INPUTS.YINPUT]
	)).clamp(Vector2(-16*60,-16*60),Vector2(16*60,16*60))
	#movement.x = move_toward(movement.x,top*inputs[INPUTS.XINPUT],acc/GlobalFunctions.div_by_delta(delta))
	#parent.movement = move_toward(1,2,4)

func state_activated() -> void:
	parent.allowTranslate = true
	parent.get_node("HitBox").disabled = true
	parent.spriteController.visible = false
	parent.animator.process_mode = PROCESS_MODE_DISABLED
	parent.movement = Vector2.ZERO
	parent.z_index = 100
	parent.water = false
	parent.switch_physics()
	await get_tree().process_frame
	object_preview = objects[object_cursor].instantiate()
	parent.add_child(object_preview)

func state_exit() -> void:
	parent.allowTranslate = false
	parent.get_node("HitBox").disabled = false
	parent.spriteController.visible = true
	parent.animator.process_mode = PROCESS_MODE_INHERIT
	parent.movement = Vector2.ZERO
	move_speed = 0.0
	parent.z_index = parent.defaultZIndex
	object_preview.queue_free()
