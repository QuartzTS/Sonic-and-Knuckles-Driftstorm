class_name Cutscene extends Node2D


#enum CUTSCENE_TYPE {
	#INTRO,
	#ACT_TRANSITION,
	#ENDING
#}

#@export var cutscene_type: CUTSCENE_TYPE

var sequence_list: Array[Callable]
var sequence_index: int = 0

func _physics_process(_delta: float) -> void:
	while sequence_index < sequence_list.size():
		sequence_list[sequence_index].call()

func play_cutscene_sequence(...callback_arr: Array) -> void:
	sequence_list = callback_arr

func cycle_sequence_list():
	pass
