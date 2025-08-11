extends Control
class_name CallableStateMachine

signal state_changed(old_state, new_state)

enum State {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	TRIPLE_JUMPING,
	WALL_SLIDING,
	WALL_WALKING,
	WALL_JUMPING,
	DASHING,
	CHARGING_JUMP,
	BIG_JUMPING,
	STUNNED,
	ATTACKING,
	BIG_ATTACK,
	BIG_ATTACK_LANDING,
	DASH_ATTACK,
	KNOCKBACK,
	DEATH,
	CHASING
}

@export var initial_state: State = State.IDLE

var current_state: State
var previous_state: State

func _ready():
	current_state = initial_state
	previous_state = initial_state

func transition_to(new_state: State) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)

func is_state(state: State) -> bool:
	return current_state == state

func is_any_state(states: Array) -> bool:
	return current_state in states

func get_state_name() -> String:
	return State.keys()[current_state]

func get_previous_state_name() -> String:
	return State.keys()[previous_state]
