extends CharacterBody2D

@export var max_health: float = 200000.0
@export var move_speed: float = 200.0
@export var dmg: float = 30.0

var current_health: int
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration: float = 0.3
var knockback_friction: float = 800.0

func _ready() -> void:
	current_health = max_health

func _physics_process(delta: float) -> void:
	handle_knockback(delta)
	handle_gravity(delta)
	handle_normal_movement()
	move_and_slide()

func handle_knockback(delta: float) -> void:
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		
		if knockback_timer <= 0 or knockback_velocity.length() < 20:
			knockback_velocity = Vector2.ZERO
			knockback_timer = 0.0

func handle_gravity(delta: float) -> void:
	if knockback_timer > 0:
		return
		
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_normal_movement() -> void:
	if knockback_timer > 0:
		return
		
	velocity.x = 0

func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(0, current_health)
	print(name, " took ", amount, " damage! Health: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force
	knockback_timer = knockback_duration
	print(name, " knocked back with force: ", force)

func die() -> void:
	print(name, " died!")
	queue_free()
