extends Node2D

## Independente do sistema futuro de equipamentos. Ataque permanente do jogador.
@export_range(1, 50, 1) var dano: int = 1
@export var alcance_horizontal: float = 100.0
@export var altura_ataque: float = 72.0
@export_range(0.05, 5.0, 0.05) var cooldown: float = 0.38
@export var alcance_vertical: float = 100.0
@export_range(0.0, 100.0, 1.0) var stack_reduzido_por_acerto: float = 10.0

var ataque_para_cima: bool = false
var jogador: Jogador
var recarga: float = 0.0
var flash_ataque: float = 0.0
var sentido_flash: float = 1.0
var largura_flash: float = 0.0
var altura_flash: float = 0.0
var aprimorado_flash: bool = false


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
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0 or jogador.dash_component.esta_dashing or jogador.esta_travado_por_overflow():
		return

	recarga = cooldown
	flash_ataque = 0.12
	sentido_flash = float(jogador.direcao_olhar)

	# A cena Syntax Error altera apenas este golpe; nao muda os valores base.
	var modificadores: Dictionary = {}
	var equipamentos: EquipamentosAtivos = jogador.get_node_or_null("EquipamentosAtivos") as EquipamentosAtivos
	if equipamentos != null:
		modificadores = equipamentos.consumir_modificador_ataque()
	var dano_golpe: int = dano + int(modificadores.get("dano_extra", 0))
	var alcance_extra: float = float(modificadores.get("alcance_extra", 0.0))
	var alcance_horizontal_golpe: float = alcance_horizontal + alcance_extra
	var alcance_vertical_golpe: float = alcance_vertical + alcance_extra
	var aprimorado: bool = bool(modificadores.get("aprimorado", false))

	# W pressionado: ataque vertical.
	ataque_para_cima = Input.is_action_pressed("ui_up")
	largura_flash = alcance_horizontal_golpe
	altura_flash = alcance_vertical_golpe
	aprimorado_flash = aprimorado

	queue_redraw()

	var forma: RectangleShape2D = RectangleShape2D.new()
	var centro: Vector2

	if ataque_para_cima:
		forma.size = Vector2(altura_ataque, alcance_vertical_golpe)

		# Hitbox acima da cabeça do jogador.
		centro = jogador.global_position + Vector2(
			20.0,
			4.0 - alcance_vertical_golpe * 0.5
		)
	else:
		forma.size = Vector2(alcance_horizontal_golpe, altura_ataque)

		# Hitbox horizontal original.
		centro = jogador.global_position + Vector2(
			20.0 + sentido_flash * (20.0 + alcance_horizontal_golpe * 0.5),
			20.0
		)

	var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, centro)
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = true  # Correntes Deadlock sao zonas atravessaveis de 1 HP.
	consulta.collision_mask = 2
	consulta.exclude = [jogador.get_rid()]

	var atingidos: Dictionary = {}

	for resultado in get_world_2d().direct_space_state.intersect_shape(consulta, 24):
		var alvo: Object = resultado.get("collider")

		if alvo != null and alvo.has_method("receber_dano"):
			# Race Condition possui uma copia com HP compartilhado; um golpe
			# que encontra as duas hitboxes deve registrar um unico acerto.
			var alvo_unico: Object = alvo.call("alvo_compartilhado") if alvo.has_method("alvo_compartilhado") else alvo
			if atingidos.has(alvo_unico):
				continue
			atingidos[alvo_unico] = true
			# Nao recupera STACK se o golpe for bloqueado pelo escudo do
			# Boss 1. Apenas dano realmente aplicado conta como acerto.
			# O nucleo do Boss 1 recebe golpes, mas nao possui vida_atual.
			# Nao converta null para int; STACK diminui somente com dano real.
			var vida_antes: Variant = alvo_unico.get("vida_atual") if is_instance_valid(alvo_unico) else null
			alvo.call("receber_dano", dano_golpe)
			if vida_antes != null and is_instance_valid(alvo_unico):
				var vida_depois: Variant = alvo_unico.get("vida_atual")
				if vida_depois != null and vida_depois < vida_antes and (alvo_unico is InimigoBase or alvo_unico is BossBase):
					jogador.reduzir_overflow(stack_reduzido_por_acerto)


func _draw() -> void:
	if flash_ataque <= 0.0:
		return

	var cor: Color = Color(1.0, 0.45, 0.18, 0.55) if aprimorado_flash else Color(0.45, 0.92, 1.0, 0.35)

	if ataque_para_cima:
		# Desenha o ataque acima do jogador.
		draw_rect(
			Rect2(
				20.0 - altura_ataque * 0.5,
				4.0 - altura_flash,
				altura_ataque,
				altura_flash
			),
			cor
		)
	else:
		# Desenha o ataque horizontal original.
		var inicio_x: float = 40.0 if sentido_flash > 0.0 else -largura_flash

		draw_rect(
			Rect2(
				inicio_x,
				20.0 - altura_ataque * 0.5,
				largura_flash,
				altura_ataque
			),
			cor
		)
