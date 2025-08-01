@tool
extends Node2D

@export var larva: CharacterBody2D

@onready var body: Sprite2D = $"../Body/body"
@onready var sword_body: Sprite2D = $"../Body/body/swordBody"
@onready var sword_body_2: Sprite2D = $"../Body/body/swordBody2"
@onready var leg_f: Sprite2D = $"../Body/body/legF"
@onready var feet_f: Sprite2D = $"../Body/body/legF/feetF"
@onready var leg_b: Sprite2D = $"../Body/body/legB"
@onready var feet_b: Sprite2D = $"../Body/body/legB/feetB"
@onready var arm_f_1: Sprite2D = $"../Body/body/armF_1"
@onready var hand_f_1: Sprite2D = $"../Body/body/armF_1/handF_1"
@onready var sword_f: Sprite2D = $"../Body/body/armF_1/handF_1/swordF"
@onready var arm_b_1: Sprite2D = $"../Body/body/armB_1"
@onready var hand_b_1: Sprite2D = $"../Body/body/armB_1/handB_1"
@onready var sword_b: Sprite2D = $"../Body/body/armB_1/handB_1/swordB"
@onready var arm_f_2: Sprite2D = $"../Body/body/armF_2"
@onready var hand_f_2: Sprite2D = $"../Body/body/armF_2/handF_2"
@onready var arm_b_2: Sprite2D = $"../Body/body/armB_2"
@onready var hand_b_2: Sprite2D = $"../Body/body/armB_2/handB_2"
@onready var head: Sprite2D = $"../Body/body/head"
@onready var eye_b: Sprite2D = $"../Body/body/head/EyeB"
@onready var eye_f: Sprite2D = $"../Body/body/head/EyeF"
@onready var feller_b_1: Sprite2D = $"../Body/body/head/fellerB_1"
@onready var feller_b_2: Sprite2D = $"../Body/body/head/fellerB_1/fellerB_2"
@onready var feller_f_1: Sprite2D = $"../Body/body/head/fellerF_1"
@onready var feller_f_2: Sprite2D = $"../Body/body/head/fellerF_1/fellerF_2"
@onready var mandible_b: Sprite2D = $"../Body/body/head/mandibleB"
@onready var mandible_f: Sprite2D = $"../Body/body/head/mandibleF"

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if larva.character_data.body:
			_set_sprites()
			_set_colors()
		else:
			print("resource is not fonded")

func _set_sprites() -> void:
	body.texture = larva.character_data.body
	sword_body.texture = larva.character_data.sword
	sword_body_2.texture = larva.character_data.sword
	leg_f.texture = larva.character_data.leg
	feet_f.texture = larva.character_data.feet
	leg_b.texture = larva.character_data.leg
	feet_b.texture = larva.character_data.feet
	arm_f_1.texture = larva.character_data.arm
	hand_f_1.texture = larva.character_data.hand
	sword_f.texture = larva.character_data.sword
	arm_b_1.texture = larva.character_data.arm
	hand_b_1.texture = larva.character_data.hand
	sword_b.texture = larva.character_data.sword
	arm_f_2.texture = larva.character_data.arm
	hand_f_2.texture = larva.character_data.hand
	arm_b_2.texture = larva.character_data.arm
	hand_b_2.texture = larva.character_data.hand
	head.texture = larva.character_data.head
	eye_b.texture = larva.character_data.eye_b
	eye_f.texture = larva.character_data.eye_f
	feller_b_1.texture = larva.character_data.feller_1
	feller_b_2.texture = larva.character_data.feller_2
	feller_f_1.texture = larva.character_data.feller_1
	feller_f_2.texture = larva.character_data.feller_2
	mandible_b.texture = larva.character_data.mandible_b
	mandible_f.texture = larva.character_data.mandible_f

func _set_colors() -> void:
	body.self_modulate = larva.character_data.body_color
	head.self_modulate = larva.character_data.head_color
	mandible_f.self_modulate = larva.character_data.mandibles_color
	mandible_b.self_modulate = larva.character_data.mandibles_color
	sword_body.self_modulate = larva.character_data.weapon_color
	sword_body_2.self_modulate = larva.character_data.weapon_color
	sword_f.self_modulate = larva.character_data.weapon_color
	sword_b.self_modulate = larva.character_data.weapon_color
