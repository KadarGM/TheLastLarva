extends Node
class_name CallableStateMachine

signal state_changed(old_state, new_state)

@export var initial_state: CharacterData.State = CharacterData.State.IDLE

var current_state: CharacterData.State
var previous_state: CharacterData.State

func _ready():
	current_state = initial_state
	previous_state = initial_state

func transition_to(new_state: CharacterData.State) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)

func is_state(state: CharacterData.State) -> bool:
	return current_state == state

func is_any_state(states: Array) -> bool:
	return current_state in states

func get_state_name() -> String:
	return CharacterData.State.keys()[current_state]

func get_previous_state_name() -> String:
	return CharacterData.State.keys()[previous_state]
