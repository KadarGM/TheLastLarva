extends Node

@export var animation_player: AnimationPlayer
@export var state_machine: StateMachine

func _process(_delta: float) -> void:
	update_animation()

func update_animation() -> void:
	var full_string = str(state_machine.current_state)
	var state_part = full_string.split(":")[0]
	var animation_name = state_part.replace("State", "")
	animation_player.play(animation_name)
