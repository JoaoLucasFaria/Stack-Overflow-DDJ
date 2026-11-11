class_name Jogador
extends CharacterBody2D

## Movimentação básica. Mantemos os nomes exportados para preservar ajustes nas cenas.
@export_category("Movimentação")
@export var SPEED: float = 300.0
@export_range(-1000.0, 0.0, 10.0) var JUMP_VELOCITY: float = -600.0
@export_range(1, 10, 1) var MAX_JUMPS: int = 2
@export var jump_release_delay: float = 0.1

@export_category("Vida")
@export_range(1, 999, 1) var vida_maxima: int = 10

signal vida_alterada(atual: int, maxima: int)
signal morreu

var vida_atual: int = 10
var jumps_remaining: int = 2
var jump_release_timer: float = 0.0
var jump_released: bool = false
var direcao_olhar: int = 1

@onready var dash_component: DashComponent = $DashComponent


func _ready() -> void:
	add_to_group("jogador")
	vida_atual = vida_maxima
	jumps_remaining = MAX_JUMPS
	vida_alterada.emit(vida_atual, vida_maxima)


func _physics_process(delta: float) -> void:
	var no_chao: bool = is_on_floor()
	var direcao: float = Input.get_axis("ui_left", "ui_right")

	if not is_zero_approx(direcao):
		direcao_olhar = -1 if direcao < 0.0 else 1

	# Um único lugar controla o movimento físico (inclusive durante o dash).
	dash_component.atualizar(delta, no_chao, direcao_olhar)
	if dash_component.esta_dashing:
		velocity = dash_component.obter_velocidade_dash()
		move_and_slide()
		return

	if not no_chao:
		velocity += get_gravity() * delta
	else:
		jumps_remaining = MAX_JUMPS

	if Input.is_action_just_pressed("ui_accept") and jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
		jump_released = false
		jump_release_timer = 0.0

	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		jump_released = true
		jump_release_timer = jump_release_delay

	if jump_released:
		jump_release_timer -= delta
		if jump_release_timer <= 0.0:
			# Soltar o pulo corta a subida depois do atraso configurado.
			velocity.y = 0.0 if velocity.y < 0.0 else velocity.y
			jump_released = false

	if not is_zero_approx(direcao):
		velocity.x = direcao * SPEED
	else:
		# Preserva a desaceleração do protótipo original.
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()


func receber_dano(dano: int) -> void:
	if dano <= 0 or vida_atual <= 0:
		return
	if dash_component.e_invencivel:
		return

	vida_atual = maxi(vida_atual - dano, 0)
	vida_alterada.emit(vida_atual, vida_maxima)
	print("Vida atual: ", vida_atual)
	if vida_atual == 0:
		morrer()


func morrer() -> void:
	print("O personagem morreu!")
	morreu.emit()
	queue_free()


func preparar_para_nova_sala() -> void:
	## Mantém a vida e os desbloqueios. Reinicia apenas estados transitórios.
	velocity = Vector2.ZERO
	jumps_remaining = MAX_JUMPS
	jump_release_timer = 0.0
	jump_released = false
	dash_component.cancelar_dash()
