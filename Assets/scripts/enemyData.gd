extends Resource
class_name EnemyData

@export_group("Sprites")
@export var body: Texture2D
@export var sword: Texture2D
@export var leg: Texture2D
@export var feet: Texture2D
@export var arm: Texture2D
@export var hand: Texture2D
@export var head: Texture2D
@export var eye_b: Texture2D
@export var eye_f: Texture2D
@export var feller_1: Texture2D
@export var feller_2: Texture2D
@export var mandible_f: Texture2D
@export var mandible_b: Texture2D

@export_group("Colors")
@export var body_color: Color
@export var head_color: Color
@export var mandibles_color: Color
@export var weapon_color: Color

@export_group("Health")
@export var health_max: int = 1000

@export_group("Basic Movement")
@export var speed: float = 600.0
@export var jump_velocity: float = -450.0

@export_group("Wall Movement")
@export var wall_ray_cast_length: float = 100.0

@export_group("Combat Basic")
@export var hide_weapon_time: float = 1.4
@export var attack_cooldown: float = 0.95
@export var attack_area_radius: float = 150.0
@export var damage_delay: float = 0.2
@export var invulnerability_after_damage: float = 0.5

@export_group("Combat Damage")
@export var attack_1_dmg: int = 30
@export var attack_2_dmg: int = 30
@export var attack_3_dmg: int = 40

@export_group("Knockback")
@export var knockback_force: float = 150.0
@export var knockback_force_multiplier: float = 1.1
@export var knockback_duration: float = 0.1
@export var knockback_friction: float = 30.0
@export var knockback_vertical_multiplier: float = 0.3
@export var knockback_force_horizontal_multiplier: float = 3.0
@export var damage_knockback_force: float = 300.0

@export_group("Raycasts")
@export var ground_check_ray_length: float = 100.0

@export_group("Patrol Behavior")
@export var patrol_state_min_time: float = 1.0
@export var patrol_state_max_time: float = 4.0
@export var patrol_idle_chance: float = 0.3
@export var detection_range: float = 600.0
@export var position_tolerance: float = 50.0
