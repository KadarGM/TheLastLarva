extends Resource
class_name CharacterData

@export_group("Movement")
@export var speed: float = 600.0
@export var jump_velocity: float = -450.0
@export var jump_release_multiplier: float = 0.5

@export_group("Dash")
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.2
@export var dash_cooldown_time: float = 0.7

@export_group("Wall Movement")
@export var wall_jump_force: float = 200.0
@export var wall_slide_gravity_multiplier: float = 0.8
@export var wall_jump_control_delay: float = 0.2
@export var wall_ray_cast_length: float = 100.0

@export_group("Big Jump")
@export var big_jump_charge_time: float = 3.0
@export var big_jump_multiplier: float = 2.0
@export var big_jump_stamina_cost: float = 200.0
@export var big_jump_dash_multiplier: float = 3.0
@export var big_jump_horizontal_speed: float = 1500.0
@export var big_jump_vertical_speed: float = 1500.0
@export var big_jump_duration: float = 1.0
@export var big_jump_stamina_drain_rate: float = 1000.0

@export_group("Air Time & Stun")
@export var stun_after_land_treshold: float = 0.8
@export var stun_time: float = 0.5
@export var landing_multiplier: float = 2.0

@export_group("Combat")
@export var hide_weapon_time: float = 2.0
@export var big_attack_stamina_cost: float = 150.0
@export var big_attack_distance_treshold: float = 200.0
@export var attack_cooldown: float = 0.5

@export_group("Multi Jump")
@export var double_jump_multiplier: float = 0.8
@export var triple_jump_multiplier: float = 0.6

@export_group("Health & Stamina")
@export var health_max: int = 100
@export var stamina_max: float = 1000.0
@export var stamina_cost: float = 300.0
@export var stamina_regen_rate: float = 1.0
@export var stamina_regen_delay: float = 1.0

@export_group("Raycasts")
@export var ground_check_ray_length: float = 200.0
@export var near_ground_ray_length: float = 100.0
@export var ceiling_ray_length: float = 200.0

var health_current: int = health_max
var stamina_current: float = stamina_max
