extends InimigoBase

## Criatura de teto: somente faces INFERIORES de tetos/plataformas.
## Apos a investida, lanca uma teia visivel e percorre o fio ate outro apoio.
## Nao se teleporta, nao gruda em paredes e ignora correntes do Deadlock.
enum Estado { RASTEJANDO, AVISANDO, INVESTINDO, VULNERAVEL, TECENDO, PUXANDO }

@export_category("Movimentacao")
@export var velocidade_rastejo: float = 78.0
@export var velocidade_investida: float = 600.0
@export var velocidade_teia: float = 610.0
@export var alcance_fixacao: float = 750.0
@export var alcance_deteccao_investida: float = 820.0
@export var tolerancia_horizontal_investida: float = 230.0
@export var janela_vulneravel: float = 0.62
@export var aviso_investida: float = 0.42
@export var aviso_teia: float = 0.35
@export var intervalo_proxima_investida: float = 0.65

var estado: Estado = Estado.VULNERAVEL
var relogio: float = 0.35
var sentido_rastejo: float = 1.0
var direcao_investida: Vector2 = Vector2.DOWN
var tempo_investida: float = 0.0
var ponto_teia: Vector2 = Vector2.ZERO
var ponto_teia_valido: bool = false
var apoio_atual: StaticBody2D
var apoio_destino: StaticBody2D
var limite_esquerdo: float = 0.0
var limite_direito: float = 0.0
var teto_y: float = 0.0
var limites_destino: Vector2 = Vector2.ZERO
var teto_destino_y: float = 0.0
var recarga_investida: float = 0.0


func _ready() -> void:
	fixo_no_cenario = true
	chance_drop_percentual = 0  # Item especifico ainda nao foi definido.
	super._ready()
	call_deferred("_buscar_apoio")


func _forma_livre(posicao: Vector2) -> bool:
	var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	consulta.shape = $CollisionShape2D.shape
	consulta.transform = Transform2D(0.0, posicao)
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _buscar_apoio() -> void:
	if encerrado or not is_inside_tree():
		return
	# Usamos a geometria REAL das plataformas manuais: nenhuma ancoragem
	# em superficies verticais ou nos corpos temporarios do Deadlock.
	var cenario: Node = get_parent().get_parent() if get_parent().get_parent() != null else get_parent()
	var melhor_pontuacao: float = INF
	var melhor: Vector2 = Vector2.ZERO
	var melhor_apoio: StaticBody2D
	var melhor_limites: Vector2
	var melhor_teto: float = 0.0
	var referencia: Vector2 = jogador.global_position + Vector2(20, 20) if is_instance_valid(jogador) else global_position
	for col in cenario.find_children("*", "CollisionShape2D", true, false):
		var forma: CollisionShape2D = col as CollisionShape2D
		if forma == null or not (forma.get_parent() is StaticBody2D):
			continue
		var corpo: StaticBody2D = forma.get_parent() as StaticBody2D
		if corpo.is_in_group("barreiras_deadlock") or (corpo.collision_layer & 1) == 0:
			continue
		var retangulo: RectangleShape2D = forma.shape as RectangleShape2D
		if retangulo == null or retangulo.size.x < 90.0:
			continue
		if absf(forma.global_rotation) > 0.05:
			continue # Nunca usar parede ou superficie inclinada.
		var centro: Vector2 = forma.global_position
		var metade: Vector2 = retangulo.size * 0.5
		var baixo: float = centro.y + metade.y
		var y: float = baixo + 14.0 + 4.0  # Centro a 4px da face inferior.
		# Nao usar a face inferior do piso principal como 'teto'.
		if y > referencia.y + 8.0:
			continue
		var esquerda: float = centro.x - metade.x + 21.0
		var direita: float = centro.x + metade.x - 21.0
		if direita <= esquerda:
			continue
		for tentativa_x in [global_position.x, referencia.x, global_position.x - 180.0, global_position.x + 180.0, referencia.x - 125.0, referencia.x + 125.0, esquerda, direita]:
			var x: float = clampf(float(tentativa_x), esquerda, direita)
			var candidato: Vector2 = Vector2(x, y)
			var distancia: float = global_position.distance_to(candidato)
			if distancia > alcance_fixacao or (ponto_teia_valido and distancia < 65.0):
				continue
			if not _forma_livre(candidato):
				continue
			# A linha deve ser percorrivel: nenhum salto atraves de plataforma.
			var raio: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, candidato, 1)
			raio.exclude = [get_rid(), jogador.get_rid()] if is_instance_valid(jogador) else [get_rid()]
			if not get_world_2d().direct_space_state.intersect_ray(raio).is_empty():
				continue
			var pontuacao: float = absf(x - referencia.x) * 0.5 + distancia * 0.28
			if is_instance_valid(apoio_atual) and apoio_atual == corpo and distancia < 70.0:
				pontuacao += 150.0
			if pontuacao < melhor_pontuacao:
				melhor_pontuacao = pontuacao
				melhor = candidato
				melhor_apoio = corpo
				melhor_limites = Vector2(esquerda, direita)
				melhor_teto = y
	if melhor_pontuacao == INF:
		# Nao move o corpo magicamente para outro lugar. Tenta de novo.
		estado = Estado.VULNERAVEL
		relogio = 0.55
		ponto_teia_valido = false
		return
	ponto_teia = melhor
	ponto_teia_valido = true
	apoio_destino = melhor_apoio
	limites_destino = melhor_limites
	teto_destino_y = melhor_teto
	estado = Estado.TECENDO
	relogio = aviso_teia
	queue_redraw()


func _visada_livre(alvo: Vector2) -> bool:
	# Raycasts contra o cenario (camada 1), inclusive plataformas.
	# Se existir teto/plataforma entre a criatura e o jogador, o ataque
	# nem entra no aviso. O mesmo teste ocorre antes de disparar.
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for deslocamento_x in [-9.0, 0.0, 9.0]:
		var ajuste: Vector2 = Vector2(deslocamento_x, 0.0)
		var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position + ajuste, alvo + ajuste, 1)
		consulta.exclude = [get_rid(), jogador.get_rid()]
		if not espaco.intersect_ray(consulta).is_empty():
			return false
	return true


func _pode_investir() -> bool:
	var alvo: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
	return (
		absf(alvo.x - global_position.x) <= tolerancia_horizontal_investida
		and global_position.distance_to(alvo) <= alcance_deteccao_investida
		and _visada_livre(alvo)
	)


func _pensar(delta: float) -> void:
	velocity = Vector2.ZERO
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	recarga_investida = maxf(0.0, recarga_investida - delta)
	match estado:
		Estado.RASTEJANDO:
			if not is_instance_valid(apoio_atual):
				_buscar_apoio()
				return
			var dx: float = sentido_rastejo * velocidade_rastejo * delta
			var proximo_x: float = global_position.x + dx
			if proximo_x < limite_esquerdo or proximo_x > limite_direito:
				sentido_rastejo *= -1.0
			else:
				var batida: KinematicCollision2D = move_and_collide(Vector2(dx, 0))
				if batida != null:
					sentido_rastejo *= -1.0
			if recarga_investida <= 0.0 and _pode_investir():
				estado = Estado.AVISANDO
				relogio = aviso_investida
		Estado.AVISANDO:
			relogio -= delta
			if relogio <= 0.0:
				# O jogador pode ter mudado de andar durante o aviso.
				if not _pode_investir():
					estado = Estado.RASTEJANDO
					recarga_investida = 0.35
				else:
					var alvo: Vector2 = jogador.global_position + Vector2(20, 20)
					direcao_investida = (alvo - global_position).normalized()
					estado = Estado.INVESTINDO
					# Mantem a investida tempo bastante para cruzar a distancia
					# do teto ate o jogador, sem ficar voando apos alcançá-lo.
					tempo_investida = clampf(global_position.distance_to(alvo) / velocidade_investida + 0.12, 0.22, 1.25)
		Estado.INVESTINDO:
			tempo_investida -= delta
			var batida: KinematicCollision2D = move_and_collide(direcao_investida * velocidade_investida * delta)
			if tempo_investida <= 0.0 or batida != null:
				estado = Estado.VULNERAVEL
				relogio = janela_vulneravel
				recarga_investida = intervalo_proxima_investida
		Estado.VULNERAVEL:
			relogio -= delta
			if relogio <= 0.0:
				_buscar_apoio()
		Estado.TECENDO:
			relogio -= delta
			if relogio <= 0.0:
				estado = Estado.PUXANDO
		Estado.PUXANDO:
			var diferenca: Vector2 = ponto_teia - global_position
			var restante: float = diferenca.length()
			if restante <= 4.0:
				_terminar_teia()
			else:
				var movimento: Vector2 = diferenca.normalized() * minf(restante, velocidade_teia * delta)
				var batida: KinematicCollision2D = move_and_collide(movimento)
				if batida != null:
					# Se o caminho foi obstruido, nao teleporta atraves do obstaculo.
					estado = Estado.VULNERAVEL
					relogio = 0.45
					ponto_teia_valido = false
				elif global_position.distance_to(ponto_teia) <= 4.0:
					_terminar_teia()
	queue_redraw()


func _terminar_teia() -> void:
	ponto_teia_valido = false
	apoio_atual = apoio_destino
	limite_esquerdo = limites_destino.x
	limite_direito = limites_destino.y
	teto_y = teto_destino_y
	estado = Estado.RASTEJANDO
	recarga_investida = intervalo_proxima_investida


func _iniciar_ataque() -> void:
	pass


func interromper_ataques(duracao: float = 1.0) -> bool:
	if not super.interromper_ataques(duracao):
		return false
	estado = Estado.VULNERAVEL
	relogio = maxf(relogio, janela_vulneravel)
	ponto_teia_valido = false
	return true


func _draw() -> void:
	if estado == Estado.AVISANDO:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 24, Color(1, 0.25, 0.34, 0.9), 3.0)
	elif ponto_teia_valido and (estado == Estado.TECENDO or estado == Estado.PUXANDO):
		# Fio ate o destino, visivel antes e DURANTE o deslocamento.
		draw_line(Vector2.ZERO, to_local(ponto_teia), Color(0.67, 0.92, 1.0, 0.92), 2.5)
		draw_arc(to_local(ponto_teia), 8.0, 0.0, TAU, 14, Color(0.67, 0.92, 1.0, 0.9), 2.0)
