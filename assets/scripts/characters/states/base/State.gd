extends Control
class_name State

@export var character: CharacterManager
var state_machine: StateMachine

func _ready():
	await owner.ready
	character = owner as CharacterManager
	state_machine = get_parent() as StateMachine

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(_delta: float) -> void:
	pass

func process_input() -> void:
	pass

func handle_animation() -> void:
	pass
