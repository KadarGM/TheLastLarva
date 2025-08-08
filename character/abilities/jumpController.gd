extends Node
class_name JumpController

@export_group("Jump Settings")
@export var jump_enabled: bool = true
@export var jump_velocity: float = -450.0
@export var jump_release_multiplier: float = 0.5

@export_group("Multi Jump")
@export var double_jump_enabled: bool = false
@export var double_jump_multiplier: float = 0.9
@export var triple_jump_enabled: bool = false
@export var triple_jump_multiplier: float = 0.8
@export var triple_jump_stamina_cost: float = 300.0

var owner_body: CharacterBody2D
var state_machine: CallableStateMachine

var jump_count: int = 0
var can_double_jump: bool = true
var can_triple_jump: bool = false
var is_jump_held: bool = false
var is_double_jump_held: bool = false
var is_triple_jump_held: bool = false

func setup(body: CharacterBody2D, sm: CallableStateMachine):
	owner_body = body
	state_machine = sm

func reset_jump_state():
	jump_count = 0
	can_double_jump = true
	can_triple_jump = false

func handle_ground_jump():
	if not jump_enabled:
		return false
	
	if owner_body.is_on_floor():
		owner_body.velocity.y = jump_velocity
		is_jump_held = true
		can_double_jump = true
		can_triple_jump = false
		jump_count = 1
		return true
	return false

func handle_air_jump(stamina_current: float) -> Dictionary:
	if can_double_jump and jump_count == 1 and double_jump_enabled:
		owner_body.velocity.y = jump_velocity * double_jump_multiplier
		can_double_jump = false
		is_double_jump_held = true
		jump_count = 2
		can_triple_jump = true
		return {"success": true, "type": "double", "stamina_cost": 0}
	elif can_triple_jump and jump_count == 2 and triple_jump_enabled:
		if stamina_current >= triple_jump_stamina_cost:
			owner_body.velocity.y = jump_velocity * triple_jump_multiplier
			can_triple_jump = false
			is_triple_jump_held = true
			jump_count = 3
			return {"success": true, "type": "triple", "stamina_cost": triple_jump_stamina_cost}
	return {"success": false}

func handle_jump_release():
	if is_jump_held and owner_body.velocity.y < 0:
		owner_body.velocity.y *= jump_release_multiplier
		is_jump_held = false
	elif is_double_jump_held and owner_body.velocity.y < 0:
		owner_body.velocity.y *= jump_release_multiplier
		is_double_jump_held = false
	elif is_triple_jump_held and owner_body.velocity.y < 0:
		owner_body.velocity.y *= jump_release_multiplier
		is_triple_jump_held = false

func on_landed():
	reset_jump_state()

func on_wall_jump():
	jump_count = 0
	can_double_jump = true
	can_triple_jump = true
