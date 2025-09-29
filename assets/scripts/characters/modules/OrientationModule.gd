extends Node

@export var sprite: Sprite2D

func _input(_event: InputEvent) -> void:
	var h_input = Input.get_axis("left", "right")
	char_orientation(sprite,h_input)

func char_orientation(spr, input) -> void:
	if input != 0 and spr:
		spr.scale.x = -sign(input) * abs(spr.scale.x)
