extends CharacterBody2D


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body: Node2D = $Body

const SPEED = 400.0
const JUMP_VELOCITY = -400.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_fliped = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		print(direction)
		animation_player.play("Walk")
		velocity.x = direction * SPEED
	else:
		animation_player.play("Idle")
		velocity.x = move_toward(velocity.x, 0, SPEED)

	flip_body(direction)
	move_and_slide()

func flip_body(direction) -> void:
	
	if direction == -1.0:
		scale.x = -1.0
	else:
		scale.x = 1.0
