extends StaticBody2D

const PROJECTILE_SCENE = preload("res://cenas/TrapProjectileType1.tscn")

@export var projectile_direction: Vector2 = Vector2.RIGHT

@onready var spawn_point: Marker2D = $Marker2D
@onready var timer: Timer = $Timer
@export var shoot_interval: float = 2.0


func _ready() -> void:
	timer.wait_time = shoot_interval
	timer.timeout.connect(_shoot)
	timer.start()


func _shoot() -> void:
	var projectile = PROJECTILE_SCENE.instantiate()

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_point.global_position

	if projectile.has_method("set_direction"):
		projectile.set_direction(projectile_direction)
