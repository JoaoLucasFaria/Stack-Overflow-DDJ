class_name InimigoBase
extends CharacterBody2D

## Inimigo comum: física, vida, ataque telegrafado e drop.
## Cada variação implementa _pensar(delta) em um script separado.
signal derrotado(posicao_global: Vector2, item_id: StringName, caiu_item: bool)

@export_category("Combate")
@export_range(1, 100, 1) var vida_maxima: int = 3
@export_range(0, 20, 1) var dano: int = 1
@export_range(0, 100, 1) var chance_drop_percentual: int = 35
@export var item_id: StringName = &"syntax_error"
@export var nome_visivel: String = "Syntax Error"

@export_category("Movimentação")
@export_range(0, 500, 1) var velocidade: float = 80.0
@export var distancia_deteccao: float = 270.0
@export var alcance_ataque: float = 52.0
@export_range(0.1, 5.0, 0.1) var intervalo_ataque: float = 1.5

var area_contato: Area2D
var colisao_contato: CollisionShape2D
var vida_atual: int
var jogador: Jogador
var origem: Vector2
var direcao: float = -1.0
var tempo_ate_ataque: float = 0.0
var tempo_aviso: float = 0.0
var preparando_ataque: bool = false
var encerrado: bool = false
var tempo_flash: float = 0.0
## Usado por inimigos fixos (ex.: torretas); nao altera os terrestres.
var fixo_no_cenario: bool = false
## Recuo sem dano, acionado por equipamentos defensivos.
var tempo_empurrao: float = 0.0
var velocidade_empurrao: float = 0.0
## Controle nao letal de equipamentos. O tempo diminui por fisica.
var interrupcao_restante: float = 0.0
var isca_atual: Node2D


@onready var visual: ColorRect = $Visual
@onready var rotulo: Label = $Nome


func configurar(alvo: Jogador) -> void:
	jogador = alvo


func _ready() -> void:
	add_to_group("inimigos")
	vida_atual = vida_maxima
	origem = global_position
	collision_layer = 2
	collision_mask = 1
	if not is_instance_valid(jogador):
		jogador = get_tree().get_first_node_in_group("jogador") as Jogador
	rotulo.text = nome_visivel
# 	Impede que inimigo e jogador se empurrem fisicamente
	if is_instance_valid(jogador):
		add_collision_exception_with(jogador)
		jogador.add_collision_exception_with(self)
	_criar_area_contato()


func _physics_process(delta: float) -> void:
	if encerrado:
		return
	if interrupcao_restante > 0.0:
		interrupcao_restante = maxf(0.0, interrupcao_restante - delta)
		preparando_ataque = false
		if fixo_no_cenario:
			velocity = Vector2.ZERO
		else:
			velocity.x = 0.0
			if not is_on_floor():
				velocity += get_gravity() * delta
			move_and_slide()
		return
	if fixo_no_cenario:
		velocity = Vector2.ZERO
	elif not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	tempo_ate_ataque = maxf(0.0, tempo_ate_ataque - delta)
	tempo_flash = maxf(0.0, tempo_flash - delta)
	if tempo_empurrao > 0.0 and not fixo_no_cenario:
		# Durante o empurrao, suspende a IA por alguns frames e usa a
		# propria fisica do inimigo para respeitar paredes e plataformas.
		tempo_empurrao = maxf(0.0, tempo_empurrao - delta)
		velocity.x = velocidade_empurrao
	elif preparando_ataque:
		velocity.x = 0.0
		tempo_aviso -= delta
		if tempo_aviso <= 0.0:
			preparando_ataque = false
			_executar_ataque()
	else:
		_pensar(delta)
	if not fixo_no_cenario:
		move_and_slide()
	visual.modulate = Color(1.0, 0.65, 0.65) if tempo_flash > 0.0 else (Color(1.0, 0.85, 0.55) if preparando_ataque else Color.WHITE)


func aplicar_empurrao(origem: Vector2, forca: float = 480.0, duracao: float = 0.22) -> void:
	## Afasta sem modificar HP. Inimigos fixos, como torretas, nao saem do lugar.
	if encerrado or fixo_no_cenario or duracao <= 0.0:
		return
	var lado: float = 1.0 if global_position.x >= origem.x else -1.0
	velocidade_empurrao = lado * absf(forca)
	tempo_empurrao = duracao
	preparando_ataque = false
	tempo_aviso = 0.0


func interromper_ataques(duracao: float = 1.0) -> bool:
	if encerrado or duracao <= 0.0:
		return false
	interrupcao_restante = maxf(interrupcao_restante, duracao)
	preparando_ataque = false
	tempo_aviso = 0.0
	return true


func definir_isca(isca: Node2D) -> void:
	isca_atual = isca


func _alvo_da_ia() -> Node2D:
	if is_instance_valid(isca_atual) and not isca_atual.is_queued_for_deletion():
		if global_position.distance_to(isca_atual.global_position) < 360.0:
			return isca_atual
	for nodo in get_tree().get_nodes_in_group("iscas_fork"):
		var isca: Node2D = nodo as Node2D
		if isca != null and not isca.is_queued_for_deletion() and global_position.distance_to(isca.global_position) < 350.0:
			isca_atual = isca
			return isca
	return jogador


func _pensar(_delta: float) -> void:
	_patrulhar_ou_perseguir()


func _alvo_proximo(distancia: float) -> bool:
	var alvo: Node2D = _alvo_da_ia()
	if not is_instance_valid(alvo):
		return false
	if alvo == jogador and jogador.vida_atual <= 0:
		return false
	return absf(alvo.global_position.y - global_position.y) <= 100.0 and global_position.distance_to(alvo.global_position) <= distancia


func _pode_caminhar(sentido: float) -> bool:
	if not is_on_floor():
		return true
	var origem_raio: Vector2 = global_position + Vector2(sentido * 20.0, 8.0)
	var fim_raio: Vector2 = origem_raio + Vector2(0, 60)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origem_raio, fim_raio, 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _patrulhar_ou_perseguir() -> void:
	if _alvo_proximo(distancia_deteccao):
		var diferenca: float = _alvo_da_ia().global_position.x - global_position.x
		if absf(diferenca) <= alcance_ataque and tempo_ate_ataque <= 0.0:
			_iniciar_ataque()
			return
		if absf(diferenca) > alcance_ataque * 0.8:
			direcao = signf(diferenca)
	else:
		if absf(global_position.x - origem.x) > 130.0:
			direcao = -1.0 if global_position.x > origem.x else 1.0
	if _pode_caminhar(direcao):
		velocity.x = direcao * velocidade
	else:
		velocity.x = 0.0
		if not _alvo_proximo(distancia_deteccao):
			direcao *= -1.0


func _iniciar_ataque() -> void:
	if preparando_ataque or tempo_ate_ataque > 0.0:
		return
	preparando_ataque = true
	tempo_aviso = 0.32
	tempo_ate_ataque = intervalo_ataque
	velocity.x = 0.0


func _executar_ataque() -> void:
	if _alvo_proximo(alcance_ataque + 18.0):
		var alvo: Node2D = _alvo_da_ia()
		if alvo != jogador and alvo.has_method("receber_impacto"):
			alvo.call("receber_impacto")
		elif is_instance_valid(jogador):
			jogador.receber_dano(dano, global_position)


func receber_dano(quantidade: int) -> void:
	if encerrado or quantidade <= 0:
		return
	vida_atual = maxi(0, vida_atual - quantidade)
	tempo_flash = 0.17
	if vida_atual == 0:
		_morrer()


func _morrer() -> void:
	encerrado = true
	# Child Process invocado nao concede cura nem limpeza infinita de STACK.
	if nome_visivel != "Child Process" and is_instance_valid(jogador) and is_instance_valid(jogador.patches):
		jogador.patches.registrar_abate_comum()
	var caiu: bool = randi_range(1, 100) <= chance_drop_percentual
	derrotado.emit(global_position, item_id, caiu)
	queue_free()


func _criar_area_contato() -> void:
	area_contato = Area2D.new()
	area_contato.name = "Contato"
	area_contato.collision_layer = 0
	area_contato.collision_mask = 1
	area_contato.monitoring = true

	add_child(area_contato)

	colisao_contato = CollisionShape2D.new()
	colisao_contato.shape = $CollisionShape2D.shape

	area_contato.add_child(colisao_contato)

	# Detecta quando um corpo entra na área.
	area_contato.body_entered.connect(_ao_encostar_no_jogador)


func _verificar_dano_contato() -> void:
	# Mantém a área sincronizada com inimigos que crescem.
	if colisao_contato.shape != $CollisionShape2D.shape:
		colisao_contato.shape = $CollisionShape2D.shape

	for corpo in area_contato.get_overlapping_bodies():
		if corpo is Jogador:
			corpo.receber_dano(dano, global_position)

func _ao_encostar_no_jogador(corpo: Node2D) -> void:
	if encerrado:
		return

	if corpo is Jogador:
		corpo.receber_dano(dano, global_position)
