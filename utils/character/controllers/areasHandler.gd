extends Control
class_name AreasHandler

@export var character_manager: CharacterManager

@export var big_attack_area: Area2D
@export var big_attack_area_2: Area2D
@export var damage_area: Area2D
@export var attack_area: Area2D

func _physics_process(_delta: float) -> void:
	attack_area_flip()

func attack_area_flip() -> void:
	if attack_area:
		attack_area.scale.x = character_manager.body_node.scale.x
