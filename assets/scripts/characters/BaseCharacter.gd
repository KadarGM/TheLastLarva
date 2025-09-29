extends CharacterBody2D
class_name BaseCharacter

@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D
@export var state_machine: StateMachine
@export var character_data: CharacterData

func _ready() -> void:
	state_machine.setup(self)

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	move_and_slide()
