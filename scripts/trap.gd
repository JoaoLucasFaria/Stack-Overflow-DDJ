extends StaticBody2D

const CENA_PROJETIL: PackedScene = preload("res://cenas/TrapProjectileType1.tscn")

@export var projectile_direction: Vector2 = Vector2.RIGHT
@export_range(0.1, 30.0, 0.1) var shoot_interval: float = 2.0

@onready var spawn_point: Marker2D = $Marker2D
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.stop()
	timer.wait_time = shoot_interval
	timer.timeout.connect(_atirar)
	timer.start()


func _atirar() -> void:
	var projetil: Area2D = CENA_PROJETIL.instantiate() as Area2D
	if projetil == null:
		push_error("A cena do projétil deve ter raiz Area2D.")
		return

	# Projéteis pertencem à sala, nunca ao Main: são limpos na transição.
	get_parent().add_child(projetil)
	projetil.global_position = spawn_point.global_position
	if projetil.has_method("set_direction"):
		projetil.set_direction(projectile_direction)
