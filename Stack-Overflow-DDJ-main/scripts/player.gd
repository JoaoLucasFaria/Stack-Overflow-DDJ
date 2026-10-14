extends CharacterBody2D

@export var SPEED = 300.0
@export_range(-1000.0, 0.0, 10.0) var JUMP_VELOCITY: float = -600.0

func _physics_process(delta: float) -> void:
	# Adiciona a gravidade.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Lida com o pulo.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Pega a direção do movimento (-1 para esquerda, 1 para direita).
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
