extends Node
class_name State

var character: BaseCharacter

func setup(_char: BaseCharacter):
	character = _char

func enter():
	pass

func exit():
	pass

func update(_delta: float):
	pass

func change_state(state_name: String):
	character.state_machine.change_state(state_name)

func char_orientation(sprite, input) -> void:
	if not input == 0:
		sprite.scale.x = -input
