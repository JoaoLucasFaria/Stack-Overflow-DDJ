extends InimigoBase

## Controlador nao letal de espaco: flutua, foge ao aproximar o jogador e
## cria ate duas correntes translúcidas que lentificam sem bloquear.
const CENA_BARREIRA = preload("res://scripts/inimigos/barreira_deadlock.gd")
enum Estado { ESPERANDO, AVISANDO }

@export_category("Movimentacao flutuante")
@export var velocidade_fuga: float = 68.0
@export var velocidade_aproximacao: float = 56.0
@export var distancia_minima: float = 165.0
@export var distancia_maxima: float = 380.0
@export var altura_preferida: float = 90.0
@export_category("Correntes de lentidao")
@export var alcance_ativacao: float = 900.0
@export var tempo_aviso_barreira: float = 0.58
@export var duracao_barreira: float = 7.0
@export var intervalo_barreira: float = 2.15
@export_range(1, 5, 1) var maximo_barreiras_ativas: int = 2
@export var distancia_barreira_jogador: float = 72.0
@export var altura_barreira: float = 135.0
var estado: Estado = Estado.ESPERANDO
var relogio: float = 0.8
var inicio_barreira: Vector2
var fim_barreira: Vector2
var barreiras_ativas: Array[Area2D] = []


func _ready() -> void:
	fixo_no_cenario = true
	super._ready()
	call_deferred("_elevar")


func _elevar() -> void:
	if not is_inside_tree():
		return
	var candidato: Vector2 = global_position + Vector2(0, -75)
	if _posicao_livre(candidato):
		global_position = candidato


func _posicao_livre(posicao: Vector2) -> bool:
	var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	consulta.shape = $CollisionShape2D.shape
	consulta.transform = Transform2D(0.0, posicao)
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _limpar_barreiras_inativas() -> void:
	for i in range(barreiras_ativas.size() - 1, -1, -1):
		var corrente: Area2D = barreiras_ativas[i]
		if not is_instance_valid(corrente) or corrente.is_queued_for_deletion():
			barreiras_ativas.remove_at(i)


func _pensar(delta: float) -> void:
	velocity = Vector2.ZERO
	_limpar_barreiras_inativas()
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	_mover_mantendo_distancia(delta)
	if global_position.distance_to(jogador.global_position + Vector2(20, 20)) > alcance_ativacao:
		return
	relogio -= delta
	match estado:
		Estado.ESPERANDO:
			if relogio <= 0.0:
				if barreiras_ativas.size() >= maximo_barreiras_ativas:
					relogio = 0.3
				elif _projetar_barreira():
					estado = Estado.AVISANDO
					relogio = tempo_aviso_barreira
				else:
					relogio = 0.5
		Estado.AVISANDO:
			if relogio <= 0.0:
				call_deferred("_erguer_barreira")
				estado = Estado.ESPERANDO
				relogio = intervalo_barreira
	queue_redraw()


func _mover_mantendo_distancia(delta: float) -> void:
	var centro: Vector2 = jogador.global_position + Vector2(20, 20)
	var diferenca: Vector2 = global_position - centro
	var distancia: float = diferenca.length()
	var movimento: Vector2 = Vector2.ZERO
	var rapidez: float = 0.0
	if distancia < distancia_minima:
		movimento = diferenca.normalized() if distancia > 0.01 else Vector2.LEFT
		rapidez = velocidade_fuga
	elif distancia > distancia_maxima:
		movimento = -diferenca.normalized()
		rapidez = velocidade_aproximacao
	else:
		var destino_y: float = centro.y - altura_preferida
		if absf(destino_y - global_position.y) > 18.0:
			movimento = Vector2(0, signf(destino_y - global_position.y))
			rapidez = velocidade_aproximacao * 0.35
	if rapidez > 0.0:
		move_and_collide(movimento * rapidez * delta)


func _projetar_barreira() -> bool:
	# Coloca a corrente a frente da direcao de movimento atual.
	# Os dois primeiros pontos priorizam o trajeto do jogador; o terceiro
	# cobre o retorno por tras e impede uma disposicao sempre igual.
	var centro: Vector2 = jogador.global_position + Vector2(20, 20)
	var lado: float = float(jogador.direcao_olhar)
	if absf(jogador.velocity.x) > 20.0:
		lado = signf(jogador.velocity.x)
	for sentido in [lado, -lado]:
		for afastamento in [distancia_barreira_jogador, distancia_barreira_jogador + 35.0]:
			var meio: Vector2 = Vector2(
				centro.x + sentido * afastamento,
				centro.y - altura_barreira * 0.5 + 15.0
			)
			var forma: RectangleShape2D = RectangleShape2D.new()
			forma.size = Vector2(26.0, altura_barreira)
			var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			consulta.shape = forma
			consulta.transform = Transform2D(0.0, meio)
			consulta.collision_mask = 1
			consulta.exclude = [get_rid()]
			if not get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty():
				continue
			# Evita duplicar uma corrente exatamente no mesmo ponto.
			var ocupada: bool = false
			for corrente in barreiras_ativas:
				if is_instance_valid(corrente) and corrente.global_position.distance_to(meio) < 56.0:
					ocupada = true
					break
			if ocupada:
				continue
			inicio_barreira = meio + Vector2(0, -altura_barreira * 0.5)
			fim_barreira = meio + Vector2(0, altura_barreira * 0.5)
			return true
	return false


func _erguer_barreira() -> void:
	if encerrado or not is_inside_tree():
		return
	_limpar_barreiras_inativas()
	if barreiras_ativas.size() >= maximo_barreiras_ativas:
		return
	var corrente: Area2D = CENA_BARREIRA.new() as Area2D
	get_parent().add_child(corrente)
	corrente.call("configurar", inicio_barreira, fim_barreira, duracao_barreira)
	barreiras_ativas.append(corrente)


func _iniciar_ataque() -> void:
	pass


func interromper_ataques(duracao: float = 1.0) -> bool:
	if not super.interromper_ataques(duracao):
		return false
	_destruir_barreiras()
	estado = Estado.ESPERANDO
	relogio = maxf(relogio, intervalo_barreira)
	return true


func _destruir_barreiras() -> void:
	for corrente in barreiras_ativas:
		if is_instance_valid(corrente):
			corrente.queue_free()
	barreiras_ativas.clear()


func _morrer() -> void:
	_destruir_barreiras()
	super._morrer()


func _draw() -> void:
	if estado == Estado.AVISANDO:
		draw_line(to_local(inicio_barreira), to_local(fim_barreira), Color(1.0, 0.67, 0.24, 0.5), 5.0)
