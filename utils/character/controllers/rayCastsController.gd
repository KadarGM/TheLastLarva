extends Control
class_name RayCastsController

@export_category("Setup")
@export var ground_check_ray_length: float = 100.0
@export var near_ground_ray_length: float = 100.0
@export var ceiling_ray_length: float = 200.0
@export var wall_ray_cast_length: float = 100.0

@export_category("Rays")
@export var ground_check_ray: RayCast2D
@export var ground_check_ray_2: RayCast2D
@export var ground_check_ray_3: RayCast2D
@export var near_ground_ray: RayCast2D
@export var near_ground_ray_2: RayCast2D
@export var near_ground_ray_3: RayCast2D
@export var left_wall_ray: RayCast2D
@export var right_wall_ray: RayCast2D
@export var ceiling_ray: RayCast2D
@export var ceiling_ray_2: RayCast2D
@export var ceiling_ray_3: RayCast2D

func setup_raycasts() -> void:
	ground_check_ray.target_position = Vector2(0, ground_check_ray_length)
	ground_check_ray.enabled = true
	ground_check_ray_2.target_position = Vector2(0, ground_check_ray_length)
	ground_check_ray_2.enabled = true
	ground_check_ray_3.target_position = Vector2(0, ground_check_ray_length)
	ground_check_ray_3.enabled = true
	
	near_ground_ray.target_position = Vector2(0, near_ground_ray_length)
	near_ground_ray.enabled = true
	near_ground_ray_2.target_position = Vector2(0, near_ground_ray_length)
	near_ground_ray_2.enabled = true
	near_ground_ray_3.target_position = Vector2(0, near_ground_ray_length)
	near_ground_ray_3.enabled = true
	
	left_wall_ray.target_position = Vector2(-wall_ray_cast_length, 0)
	left_wall_ray.enabled = true
	right_wall_ray.target_position = Vector2(wall_ray_cast_length, 0)
	right_wall_ray.enabled = true
	
	ceiling_ray.target_position = Vector2(0, -ceiling_ray_length)
	ceiling_ray.enabled = true
	ceiling_ray_2.target_position = Vector2(0, -ceiling_ray_length)
	ceiling_ray_2.enabled = true
	ceiling_ray_3.target_position = Vector2(0, -ceiling_ray_length)
	ceiling_ray_3.enabled = true
