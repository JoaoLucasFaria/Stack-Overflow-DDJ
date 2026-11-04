
extends CharacterBody2D

@export var SPEED = 300.0
@export_range(-1000.0, 0.0, 10.0) var JUMP_VELOCITY: float = -600.0
@export var vida_maxima: int = 10
@export var MAX_JUMPS: int = 2

var vida_atual: int = 10
var jumps_remaining: int = 2

var jump_release_timer: float = 0.0
var jump_release_delay: float = 0.1
var jump_released: bool = false

func _ready() -> void:
	vida_atual = vida_maxima
	jumps_remaining = MAX_JUMPS

func receber_dano(dano: int) -> void:
	vida_atual -= dano
	vida_atual = max(vida_atual, 0)

	print("Vida atual: ", vida_atual)

	if vida_atual <= 0:
		morrer()

func morrer() -> void:
	print("O personagem morreu!")
	queue_free()

func _physics_process(delta: float) -> void:
	# Adiciona a gravidade.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reinicia os pulos ao tocar no chão.
	if is_on_floor():
		jumps_remaining = MAX_JUMPS

	# Lida com o pulo e a recursividade.
	if Input.is_action_just_pressed("ui_accept") and jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
		jump_released = false

		print("Pulos restantes: ", jumps_remaining)

	# Detecta quando o espaço é solto.
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		jump_release_timer = jump_release_delay
		jump_released = true

	# Controla a altura do pulo.
	if jump_released:
		jump_release_timer -= delta

		if jump_release_timer <= 0:
			velocity.y *= 0.0
			jump_released = false

	# Pega a direção do movimento.
	var direction := Input.get_axis("ui_left", "ui_right")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func atualizar_limites_camera(esq: int, cima: int, dir: int, baixo: int) -> void:
	var camera = get_node_or_null("Camera2D")
	if camera != null:
		camera.limit_left = esq
		camera.limit_top = cima
		camera.limit_right = dir
		camera.limit_bottom = baixo
