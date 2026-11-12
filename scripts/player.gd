class_name Jogador
extends CharacterBody2D

## Movimentação básica. Mantemos os nomes exportados para preservar ajustes nas cenas.
@export_category("Movimentação")
@export var SPEED: float = 300.0
@export_range(-1000.0, 0.0, 10.0) var JUMP_VELOCITY: float = -600.0
@export_range(1, 10, 1) var MAX_JUMPS: int = 2
@export var jump_release_delay: float = 0.1

@export_category("Dano e Knockback")
@export var duracao_iframes: float = 0.8
@export var forca_knockback_x: float = 300.0
@export var forca_knockback_y: float = -220.0
@export var duracao_knockback: float = 0.18

var tempo_iframes: float = 0.0
var tempo_knockback: float = 0.0

@export_category("Vida")
@export_range(1, 999, 1) var vida_maxima: int = 10

signal vida_alterada(atual: int, maxima: int)
signal morreu
signal overflow_alterado(atual: float, maximo: float)

var vida_atual: int = 10
@export_category("Stack Overflow (interface para Frente A)")
@export_range(1.0, 1000.0, 1.0) var overflow_maximo: float = 100.0
var overflow_atual: float = 0.0
var jumps_remaining: int = 2
var jump_release_timer: float = 0.0
var jump_released: bool = false
var direcao_olhar: int = 1

## Progressão desta partida; o Main concede as habilidades pelos chefes.
var pulo_duplo_liberado: bool = false
var grapple_liberado: bool = false

@onready var dash_component: DashComponent = $DashComponent


func _ready() -> void:
	add_to_group("jogador")
	vida_atual = vida_maxima
	jumps_remaining = quantidade_pulos_disponiveis()
	vida_alterada.emit(vida_atual, vida_maxima)
	overflow_alterado.emit(overflow_atual, overflow_maximo)


func _physics_process(delta: float) -> void:
	tempo_iframes = maxf(0.0, tempo_iframes - delta)
	tempo_knockback = maxf(0.0, tempo_knockback - delta)

	# Feedback visual durante a invencibilidade
	$ColorRect.modulate = Color(
	1.0, 1.0, 1.0,
	0.45 if tempo_iframes > 0.0 else 1.0
)

	# Durante o knockback, o jogador não controla o movimento.
	if tempo_knockback > 0.0:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	
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
		jumps_remaining = quantidade_pulos_disponiveis()

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


func quantidade_pulos_disponiveis() -> int:
	return maxi(2, MAX_JUMPS) if pulo_duplo_liberado else 1


func desbloquear_pulo_duplo() -> void:
	pulo_duplo_liberado = true
	jumps_remaining = quantidade_pulos_disponiveis()


func desbloquear_dash() -> void:
	dash_component.dash_desbloqueado = true


func desbloquear_grapple() -> void:
	grapple_liberado = true


func receber_dano(dano: int, origem_dano: Vector2 = Vector2.ZERO) -> void:
	if dano <= 0 or vida_atual <= 0:
		return

	# Invencibilidade por i-frames ou dash
	if tempo_iframes > 0.0 or dash_component.e_invencivel:
		return

	vida_atual = maxi(vida_atual - dano, 0)
	vida_alterada.emit(vida_atual, vida_maxima)

	# Ativa invencibilidade e knockback
	tempo_iframes = duracao_iframes
	tempo_knockback = duracao_knockback

	# Empurra o jogador para longe da origem do dano
	var lado: float = -float(direcao_olhar)

	if origem_dano != Vector2.ZERO:
		lado = 1.0 if global_position.x >= origem_dano.x else -1.0

	velocity.x = lado * forca_knockback_x
	velocity.y = forca_knockback_y

	if vida_atual <= 0:
		morrer()

func morrer() -> void:
	print("O personagem morreu!")
	morreu.emit()
	queue_free()


func preparar_para_nova_sala() -> void:
	## Mantém a vida e os desbloqueios. Reinicia apenas estados transitórios.
	velocity = Vector2.ZERO
	jumps_remaining = quantidade_pulos_disponiveis()
	jump_release_timer = 0.0
	jump_released = false
	dash_component.cancelar_dash()


func adicionar_overflow(quantidade: float) -> void:
	## Contrato para habilidades ativas que o Torugo implementará.
	overflow_atual = clampf(overflow_atual + quantidade, 0.0, overflow_maximo)
	overflow_alterado.emit(overflow_atual, overflow_maximo)


func zerar_overflow() -> void:
	overflow_atual = 0.0
	overflow_alterado.emit(overflow_atual, overflow_maximo)


func descansar() -> void:
	## Descanso não altera o mapa nem remove habilidades permanentes.
	if vida_atual <= 0:
		return
	vida_atual = vida_maxima
	vida_alterada.emit(vida_atual, vida_maxima)
	zerar_overflow()
