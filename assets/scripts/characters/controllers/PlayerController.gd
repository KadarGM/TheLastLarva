extends BaseController
class_name PlayerController

var previous_jump_state: bool = false
var previous_attack_state: bool = false
var previous_dash_state: bool = false
var previous_charge_jump_state: bool = false

func update_input() -> void:
	input.move_direction.x = Input.get_axis("A_left", "D_right")
	input.move_direction.y = 0
	
	var current_jump = Input.is_action_pressed("W_jump")
	input.jump = current_jump
	input.jump_pressed = current_jump and not previous_jump_state
	input.jump_released = not current_jump and previous_jump_state
	previous_jump_state = current_jump
	
	var current_attack = Input.is_action_pressed("L_attack")
	input.attack = current_attack
	input.attack_pressed = current_attack and not previous_attack_state
	previous_attack_state = current_attack
	
	var current_dash = Input.is_action_pressed("J_dash")
	input.dash = current_dash
	input.dash_pressed = current_dash and not previous_dash_state
	previous_dash_state = current_dash
	
	var current_charge_jump = Input.is_action_pressed("S_charge_jump") and Input.is_action_pressed("J_dash")
	input.charge_jump = current_charge_jump
	input.charge_jump_pressed = current_charge_jump and not previous_charge_jump_state
	previous_charge_jump_state = current_charge_jump
