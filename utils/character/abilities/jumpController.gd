extends Control
class_name JumpController

@export var owner_body: CharacterManager
@export var state_machine: CallableStateMachine

var has_double_jump: bool = false
var has_triple_jump: bool = false
var jump_count: int = 0
var is_jump_held: bool = false
var is_double_jump_held: bool = false
var is_triple_jump_held: bool = false

func setup(body: CharacterBody2D, sm: CallableStateMachine):
	owner_body = body
	state_machine = sm

func reset_jump_state():
	jump_count = 0
	has_double_jump = true
	has_triple_jump = false

func handle_ground_jump():
	if not owner_body.character_data.can_jump:
		return false
	
	if owner_body.is_on_floor():
		owner_body.velocity.y = owner_body.character_data.jump_velocity
		is_jump_held = true
		has_double_jump = true
		has_triple_jump = false
		jump_count = 1
		return true
	return false

func handle_air_jump(stamina_current: float) -> Dictionary:
	if has_double_jump and jump_count == 1 and owner_body.character_data.can_double_jump:
		owner_body.velocity.y = owner_body.character_data.jump_velocity * owner_body.character_data.double_jump_multiplier
		has_double_jump = false
		is_double_jump_held = true
		jump_count = 2
		has_triple_jump = true
		return {"success": true, "type": "double", "stamina_cost": 0}
	elif has_triple_jump and jump_count == 2 and owner_body.character_data.can_triple_jump:
		if stamina_current >= owner_body.character_data.triple_jump_stamina_cost:
			owner_body.velocity.y = owner_body.character_data.jump_velocity * owner_body.character_data.triple_jump_multiplier
			has_triple_jump = false
			is_triple_jump_held = true
			jump_count = 3
			return {"success": true, "type": "triple", "stamina_cost": owner_body.character_data.triple_jump_stamina_cost}
	return {"success": false}

func handle_jump_release():
	if is_jump_held and owner_body.velocity.y < 0:
		owner_body.velocity.y *= owner_body.character_data.jump_release_multiplier
		is_jump_held = false
	elif is_double_jump_held and owner_body.velocity.y < 0:
		owner_body.velocity.y *= owner_body.character_data.jump_release_multiplier
		is_double_jump_held = false
	elif is_triple_jump_held and owner_body.velocity.y < 0:
		owner_body.velocity.y *= owner_body.character_data.jump_release_multiplier
		is_triple_jump_held = false

func on_landed():
	reset_jump_state()

func on_wall_jump():
	jump_count = 0
	has_double_jump = true
	has_triple_jump = true
