extends Control
class_name BaseController

@export var character: CharacterManager
var input: ControllerInput = ControllerInput.new()

func setup(_char: CharacterManager) -> void:
	character = _char

func get_input() -> ControllerInput:
	return input

func _physics_process(_delta: float) -> void:
	update_input()

func update_input() -> void:
	pass
