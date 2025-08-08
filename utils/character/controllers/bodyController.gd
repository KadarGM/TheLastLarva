@tool 
extends Node2D

@export var character: CharacterManager

@onready var body: Sprite2D = $body
@onready var sword_body: Sprite2D = $body/swordBody
@onready var sword_body_2: Sprite2D = $body/swordBody2
@onready var leg_f: Sprite2D = $body/legF
@onready var feet_f: Sprite2D = $body/legF/feetF
@onready var leg_b: Sprite2D = $body/legB
@onready var feet_b: Sprite2D = $body/legB/feetB
@onready var arm_f_1: Sprite2D = $body/armF_1
@onready var hand_f_1: Sprite2D = $body/armF_1/handF_1
@onready var sword_f: Sprite2D = $body/armF_1/handF_1/swordF
@onready var arm_b_1: Sprite2D = $body/armB_1
@onready var hand_b_1: Sprite2D = $body/armB_1/handB_1
@onready var sword_b: Sprite2D = $body/armB_1/handB_1/swordB
@onready var arm_f_2: Sprite2D = $body/armF_2
@onready var hand_f_2: Sprite2D = $body/armF_2/handF_2
@onready var arm_b_2: Sprite2D = $body/armB_2
@onready var hand_b_2: Sprite2D = $body/armB_2/handB_2
@onready var head: Sprite2D = $body/head
@onready var eye_b: Sprite2D = $body/head/EyeB
@onready var eye_f: Sprite2D = $body/head/EyeF
@onready var feller_b_1: Sprite2D = $body/head/fellerB_1
@onready var feller_b_2: Sprite2D = $body/head/fellerB_1/fellerB_2
@onready var feller_f_1: Sprite2D = $body/head/fellerF_1
@onready var feller_f_2: Sprite2D = $body/head/fellerF_1/fellerF_2
@onready var mandible_b: Sprite2D = $body/head/mandibleB
@onready var mandible_f: Sprite2D = $body/head/mandibleF

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if character and character.character_data:
			_set_sprites(character.character_data)
			_set_colors(character.character_data)
			pass
		else:
			return

func _set_sprites(data) -> void:
	body.texture = data.body
	sword_body.texture = data.sword
	sword_body_2.texture = data.sword
	leg_f.texture = data.leg
	feet_f.texture = data.feet
	leg_b.texture = data.leg
	feet_b.texture = data.feet
	arm_f_1.texture = data.arm
	hand_f_1.texture = data.hand
	sword_f.texture = data.sword
	arm_b_1.texture = data.arm
	hand_b_1.texture = data.hand
	sword_b.texture = data.sword
	arm_f_2.texture = data.arm
	hand_f_2.texture = data.hand
	arm_b_2.texture = data.arm
	hand_b_2.texture = data.hand
	head.texture = data.head
	eye_b.texture = data.eye_b
	eye_f.texture = data.eye_f
	feller_b_1.texture = data.feller_1
	feller_b_2.texture = data.feller_2
	feller_f_1.texture = data.feller_1
	feller_f_2.texture = data.feller_2
	mandible_b.texture = data.mandible_b
	mandible_f.texture = data.mandible_f

func _set_colors(data) -> void:
	body.self_modulate = data.body_color
	head.self_modulate = data.head_color
	mandible_f.self_modulate = data.mandibles_color
	mandible_b.self_modulate = data.mandibles_color
	sword_body.self_modulate = data.weapon_color
	sword_body_2.self_modulate = data.weapon_color
	sword_f.self_modulate = data.weapon_color
	sword_b.self_modulate = data.weapon_color
