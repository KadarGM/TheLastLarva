extends CharacterBody2D

@export var max_health: int = 200000
@export var move_speed: float = 200.0

var current_health: int
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration: float = 0.3

func _ready() -> void:
	current_health = max_health

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 8)
	else:
		velocity.x = 0
	
	move_and_slide()

func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(0, current_health)
	print(name, " took ", amount, " damage! Health: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force
	knockback_timer = knockback_duration

func die() -> void:
	print(name, " died!")
	queue_free()
