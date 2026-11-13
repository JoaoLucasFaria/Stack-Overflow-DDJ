extends Node2D

## Independente do sistema futuro de equipamentos. Ataque permanente do jogador.
@export_range(1, 50, 1) var dano: int = 1
@export var alcance_horizontal: float = 100.0
@export var altura_ataque: float = 72.0
@export_range(0.05, 5.0, 0.05) var cooldown: float = 0.38
@export var alcance_vertical: float = 100.0

var ataque_para_cima: bool = false
var jogador: Jogador
var recarga: float = 0.0
var flash_ataque: float = 0.0
var sentido_flash: float = 1.0


func _ready() -> void:
	jogador = get_parent() as Jogador


func _physics_process(delta: float) -> void:
	recarga = maxf(0.0, recarga - delta)
	var estava_desenhando: bool = flash_ataque > 0.0
	flash_ataque = maxf(0.0, flash_ataque - delta)
	if Input.is_action_just_pressed("ataque_basico") and recarga <= 0.0:
		_atacar()
	if estava_desenhando or flash_ataque > 0.0:
		queue_redraw()


func _atacar() -> void:
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0 or jogador.dash_component.esta_dashing:
		return

	recarga = cooldown
	flash_ataque = 0.12
	sentido_flash = float(jogador.direcao_olhar)

	# W pressionado: ataque vertical.
	ataque_para_cima = Input.is_action_pressed("ui_up")

	queue_redraw()

	var forma: RectangleShape2D = RectangleShape2D.new()
	var centro: Vector2

	if ataque_para_cima:
		forma.size = Vector2(altura_ataque, alcance_vertical)

		# Hitbox acima da cabeça do jogador.
		centro = jogador.global_position + Vector2(
			20.0,
			4.0 - alcance_vertical * 0.5
		)
	else:
		forma.size = Vector2(alcance_horizontal, altura_ataque)

		# Hitbox horizontal original.
		centro = jogador.global_position + Vector2(
			20.0 + sentido_flash * (20.0 + alcance_horizontal * 0.5),
			20.0
		)

	var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, centro)
	consulta.collide_with_bodies = true
	consulta.collision_mask = 2
	consulta.exclude = [jogador.get_rid()]

	var atingidos: Dictionary = {}

	for resultado in get_world_2d().direct_space_state.intersect_shape(consulta, 24):
		var alvo: Object = resultado.get("collider")

		if alvo != null and alvo.has_method("receber_dano") and not atingidos.has(alvo):
			atingidos[alvo] = true
			alvo.call("receber_dano", dano)


func _draw() -> void:
	if flash_ataque <= 0.0:
		return

	var cor: Color = Color(0.45, 0.92, 1.0, 0.35)

	if ataque_para_cima:
		# Desenha o ataque acima do jogador.
		draw_rect(
			Rect2(
				20.0 - altura_ataque * 0.5,
				4.0 - alcance_vertical,
				altura_ataque,
				alcance_vertical
			),
			cor
		)
	else:
		# Desenha o ataque horizontal original.
		var inicio_x: float = 40.0 if sentido_flash > 0.0 else -alcance_horizontal

		draw_rect(
			Rect2(
				inicio_x,
				20.0 - altura_ataque * 0.5,
				alcance_horizontal,
				altura_ataque
			),
			cor
		)
