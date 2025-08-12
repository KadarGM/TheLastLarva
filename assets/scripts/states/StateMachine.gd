extends Control
class_name StateMachine

@export var initial_state: State
var current_state: State
var states: Dictionary = {}

signal state_changed(old_state: State, new_state: State)

func _ready():
	for child in get_children():
		if child is State:
			states[child.name] = child
	
	if initial_state:
		current_state = initial_state
		current_state.enter()

func physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func process_input() -> void:
	if current_state:
		current_state.process_input()

func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("State " + state_name + " does not exist")
		return
	
	var new_state = states[state_name]
	
	if current_state == new_state:
		return
	
	var old_state = current_state
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()
	
	state_changed.emit(old_state, current_state)

func get_current_state_name() -> String:
	if current_state:
		return current_state.name
	return ""
