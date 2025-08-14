extends Resource
class_name ControllerInput

var move_direction: Vector2 = Vector2.ZERO
var jump: bool = false
var jump_pressed: bool = false
var jump_released: bool = false
var attack: bool = false
var attack_pressed: bool = false
var dash: bool = false
var dash_pressed: bool = false
var charge_jump: bool = false
var charge_jump_pressed: bool = false

func reset() -> void:
	move_direction = Vector2.ZERO
	jump = false
	jump_pressed = false
	jump_released = false
	attack = false
	attack_pressed = false
	dash = false
	dash_pressed = false
	charge_jump = false
	charge_jump_pressed = false

func clone() -> ControllerInput:
	var new_input = ControllerInput.new()
	new_input.move_direction = move_direction
	new_input.jump = jump
	new_input.jump_pressed = jump_pressed
	new_input.jump_released = jump_released
	new_input.attack = attack
	new_input.attack_pressed = attack_pressed
	new_input.dash = dash
	new_input.dash_pressed = dash_pressed
	new_input.charge_jump = charge_jump
	new_input.charge_jump_pressed = charge_jump_pressed
	return new_input
