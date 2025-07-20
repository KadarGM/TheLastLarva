extends Resource
class_name CharacterData

@export_group("Movement")
@export var speed: float = 600.0
@export var jump_velocity: float = -400.0
@export var jump_release_multiplier: float = 0.5

@export_group("Dash")
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.2
@export var dash_cooldown_time: float = 0.7

@export_group("Wall Movement")
@export var wall_jump_force: float = 300.0
@export var wall_slide_gravity_multiplier: float = 0.5
@export var wall_jump_control_delay: float = 0.2

@export_group("Big Jump")
@export var big_jump_charge_time: float = 0.5
@export var big_jump_multiplier: float = 2.0
@export var big_jump_stamina_cost: float = 200.0
@export var big_jump_dash_multiplier: float = 3.0

@export_group("Air Time & Stun")
@export var stun_after_land_treshold: float = 0.2
@export var stun_time: float = 0.5
@export var landing_multiplier: float = 5.0

@export_group("Combat")
@export var hide_weapon_time: float = 2.0
@export var big_attack_stamina_cost: float = 150.0

@export_group("Double Jump")
@export var double_jump_multiplier: float = 0.8

@export_group("Health & Stamina")
@export var health_max: int = 100
@export var stamina_max: float = 1000.0
@export var stamina_cost: float = 300.0
@export var stamina_regen_rate: float = 1.0
@export var stamina_regen_delay: float = 1.0

var health_current: int = health_max
var stamina_current: float = stamina_max
