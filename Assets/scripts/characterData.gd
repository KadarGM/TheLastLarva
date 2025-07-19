extends Resource
class_name CharacterData

@export_group("Movement")
@export var speed: float = 600.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 2000.0

@export_group("Dash")
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.2
@export var dash_cooldown_time: float = 0.5

@export_group("Wall Movement")
@export var wall_jump_force: float = 800.0
@export var wall_slide_gravity_multiplier: float = 0.8
@export var wall_jump_control_delay: float = 0.2

@export_group("Big Jump")
@export var big_jump_charge_time: float = 3.0
@export var big_jump_multiplier: float = 1.5

@export_group("Air Time & Stun")
@export var stun_after_land_treshold: float = 2.0
@export var stun_time: float = 0.5
@export var landing_multiplier: float = 10.0

@export_group("Combat")
@export var hide_weapon_time: float = 2.0

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

var air_time: float = 0.0
var effective_air_time: float = 0.0
var is_charging_big_jump: bool = false
var big_jump_charged: bool = false
var was_on_floor: bool = true
var is_stunned: bool = false
var can_attack: bool = true
var hide_weapon: bool = true
var can_dash: bool = true
var can_double_jump: bool = true
var used_wall_jump_combo: bool = false
var is_wall_sliding: bool = false
var can_wall_jump: bool = true
var is_wall_jumping: bool = false
