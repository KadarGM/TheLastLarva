extends Node
class_name StateMachine

@export var character: BaseCharacter
@export var initial_state: String
var current_state: State
var states: Dictionary = {}

func setup(_char: BaseCharacter) -> void:
	character = _char

	for child in get_children():
		if child is State:
			child.setup(character)
			states[child.name] = child
	
	if initial_state:
		change_state(initial_state)

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func change_state(state_name: String) -> void:
	if not states.has(state_name):
		return

	var new_state = states[state_name]
	if current_state == new_state:
		return

	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter()
