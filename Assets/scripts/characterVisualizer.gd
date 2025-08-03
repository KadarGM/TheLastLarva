@tool
extends Node2D

@export var character: BaseCharacter

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
		if character and character.character_data and character.character_data.body:
			_set_sprites()
			_set_colors()

func _set_sprites() -> void:
	var data = character.character_data
	
	if body:
		body.texture = data.body
	if sword_body:
		sword_body.texture = data.sword
	if sword_body_2:
		sword_body_2.texture = data.sword
	if leg_f:
		leg_f.texture = data.leg
	if feet_f:
		feet_f.texture = data.feet
	if leg_b:
		leg_b.texture = data.leg
	if feet_b:
		feet_b.texture = data.feet
	if arm_f_1:
		arm_f_1.texture = data.arm
	if hand_f_1:
		hand_f_1.texture = data.hand
	if sword_f:
		sword_f.texture = data.sword
	if arm_b_1:
		arm_b_1.texture = data.arm
	if hand_b_1:
		hand_b_1.texture = data.hand
	if sword_b:
		sword_b.texture = data.sword
	if arm_f_2:
		arm_f_2.texture = data.arm
	if hand_f_2:
		hand_f_2.texture = data.hand
	if arm_b_2:
		arm_b_2.texture = data.arm
	if hand_b_2:
		hand_b_2.texture = data.hand
	if head:
		head.texture = data.head
	if eye_b:
		eye_b.texture = data.eye_b
	if eye_f:
		eye_f.texture = data.eye_f
	if feller_b_1:
		feller_b_1.texture = data.feller_1
	if feller_b_2:
		feller_b_2.texture = data.feller_2
	if feller_f_1:
		feller_f_1.texture = data.feller_1
	if feller_f_2:
		feller_f_2.texture = data.feller_2
	if mandible_b:
		mandible_b.texture = data.mandible_b
	if mandible_f:
		mandible_f.texture = data.mandible_f

func _set_colors() -> void:
	var data = character.character_data
	
	if body:
		body.self_modulate = data.body_color
	if head:
		head.self_modulate = data.head_color
	if mandible_f:
		mandible_f.self_modulate = data.mandibles_color
	if mandible_b:
		mandible_b.self_modulate = data.mandibles_color
	if sword_body:
		sword_body.self_modulate = data.weapon_color
	if sword_body_2:
		sword_body_2.self_modulate = data.weapon_color
	if sword_f:
		sword_f.self_modulate = data.weapon_color
	if sword_b:
		sword_b.self_modulate = data.weapon_color
