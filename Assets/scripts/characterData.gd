extends Resource
class_name CharacterData

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

@export_group("Health & Stamina")
@export var health_max: int = 1000
@export var stamina_max: float = 1000.0
@export var stamina_regen_rate: float = 1.0
@export var stamina_regen_delay: float = 1.0

@export_subgroup("Stamina Costs")
@export var dash_stamina_cost: float = 300.0
@export var big_jump_stamina_cost: float = 200.0
@export var big_attack_stamina_cost: float = 500.0
@export var attack_stamina_cost: float = 150.0
@export var double_jump_stamina_cost: float = 0.0
@export var triple_jump_stamina_cost: float = 300.0
@export var damage_stamina_cost: float = 200.0

@export_group("Movement")
@export var speed: float = 600.0
@export var jump_velocity: float = -450.0
@export var jump_release_multiplier: float = 0.5

@export_group("Dash")
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.2
@export var dash_cooldown_time: float = 0.7

@export_group("Wall Movement")
@export var wall_jump_force: float = 250.0
@export var wall_slide_gravity_multiplier: float = 0.5
@export var wall_jump_control_delay: float = 0.15
@export var wall_ray_cast_length: float = 100.0
@export var wall_jump_away_multiplier: float = 0.5
@export var wall_slide_initial_velocity_divisor: float = 1000.0

@export_group("Air Movement")
@export var air_movement_friction: float = 0.1
@export var big_attack_air_friction: float = 0.1

@export_group("Air Time & Stun")
@export var stun_after_land_treshold: float = 0.8
@export var stun_time: float = 0.5
@export var landing_multiplier: float = 2.0
@export var air_time_initial: float = 0.01

@export_group("Big Jump")
@export var big_jump_charge_time: float = 3.0
@export var big_jump_multiplier: float = 2.0
@export var big_jump_dash_multiplier: float = 3.0
@export var big_jump_horizontal_speed: float = 1500.0
@export var big_jump_vertical_speed: float = 1500.0
@export var big_jump_duration: float = 1.0
@export var big_jump_stamina_drain_rate: float = 1000.0

@export_group("Combat")
@export var hide_weapon_time: float = 1.4
@export var big_attack_distance_treshold: float = 200.0
@export var attack_cooldown: float = 0.35
@export var attack_movement_force: float = 1800.0
@export var attack_movement_friction: float = 180.0
@export var attack_movement_multiplier: float = 1.3
@export var attack_area_radius: float = 150.0
@export var damage_delay: float = 0.2

@export_group("Combat Movement Multipliers")
@export var ground_attack_force_multiplier: float = 0.25
@export var air_attack_force_multiplier: float = 0.08
@export var ground_friction_multiplier: float = 0.8
@export var air_friction_multiplier: float = 0.4
@export var enemy_nearby_friction_multiplier: float = 2.0

@export_group("Combat dmg")
@export var attack_1_dmg: int = 30
@export var attack_2_dmg: int = 30
@export var attack_3_dmg: int = 40
@export var big_attack_dmg: int = 80

@export_group("Knockback")
@export var knockback_force: float = 150.0
@export var knockback_force_multiplier: float = 1.1
@export var knockback_reaction_multiplier: float = 0.3
@export var knockback_duration: float = 0.1
@export var knockback_friction: float = 30.0
@export var knockback_vertical_multiplier: float = 0.3
@export var knockback_reaction_force_multiplier: float = 2.0
@export var knockback_reaction_jump_multiplier: float = 0.5
@export var knockback_force_horizontal_multiplier: float = 3.0
@export_subgroup("Damage Received")
@export var damage_knockback_force: float = 300.0

@export_group("Multi Jump")
@export var double_jump_multiplier: float = 0.9
@export var triple_jump_multiplier: float = 0.8

@export_group("Raycasts")
@export var ground_check_ray_length: float = 100.0
@export var near_ground_ray_length: float = 100.0
@export var ceiling_ray_length: float = 200.0
