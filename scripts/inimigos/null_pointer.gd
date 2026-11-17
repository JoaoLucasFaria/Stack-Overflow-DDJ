extends InimigoBase

## Null Pointer: inimigo aereo, parado entre teletransportes.
## Mantem uma distancia radial fixa do jogador e prioriza pontos livres
## com mais altura sobre o chao, para incentivar pulo + ataque para cima.
const CENA_ONDA: PackedScene = preload("res://cenas/inimigos/onda_wifi_null_pointer.tscn")

enum Estado { AGUARDANDO, AVISO_TELEPORTE, AVISO_DISPARO, RECUPERANDO }

@export_category("Teleporte aereo")
@export_range(100.0, 300.0, 5.0) var distancia_teleporte: float = 165.0
@export_range(100.0, 1500.0, 10.0) var distancia_ativacao: float = 740.0
@export_range(0.1, 1.5, 0.05) var aviso_antes_teleporte: float = 0.38
@export_range(0.1, 1.5, 0.05) var aviso_antes_onda: float = 0.48
@export_range(0.1, 3.0, 0.05) var pausa_apos_onda: float = 0.72

@export_category("Onda de sinal")
@export_range(100.0, 700.0, 10.0) var velocidade_onda: float = 330.0
@export_range(100.0, 900.0, 10.0) var alcance_onda: float = 470.0

var estado: Estado = Estado.AGUARDANDO
var temporizador: float = 0.20
var ultimo_lado: int = 1


func _ready() -> void:
	# O InimigoBase nao aplica gravidade nem move_and_slide em inimigos fixos.
	fixo_no_cenario = true
	super._ready()
	# O Main posiciona o inimigo no marcador apos add_child().
	# O primeiro teleporte so acontece depois que o marcador foi aplicado.
	call_deferred("_flutuar_ao_nascer")


func _flutuar_ao_nascer() -> void:
	# Mantem a aparencia aerea mesmo antes de detectar o jogador.
	# O Main so posiciona este inimigo no marcador depois do _ready().
	if not is_inside_tree() or encerrado:
		return
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for elevacao in [110.0, 85.0, 60.0, 35.0]:
		var candidato: Vector2 = global_position + Vector2(0.0, -elevacao)
		if candidato.y < 43.0:
			continue
		var teste: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		teste.shape = $CollisionShape2D.shape
		teste.transform = Transform2D(0.0, candidato)
		teste.collision_mask = 1
		if is_instance_valid(jogador):
			teste.exclude = [get_rid(), jogador.get_rid()]
		else:
			teste.exclude = [get_rid()]
		if espaco.intersect_shape(teste, 1).is_empty():
			global_position = candidato
			return


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if encerrado:
		return
	match estado:
		Estado.AVISO_TELEPORTE:
			visual.color = Color(0.98, 0.56, 0.94)
		Estado.AVISO_DISPARO:
			visual.color = Color(0.42, 0.96, 1.0)
		Estado.RECUPERANDO:
			visual.color = Color(0.57, 0.35, 0.77)
		_:
			visual.color = Color(0.68, 0.37, 0.93)
	queue_redraw()


func _pensar(delta: float) -> void:
	velocity = Vector2.ZERO
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	if estado == Estado.AGUARDANDO:
		if global_position.distance_to(_centro_jogador()) > distancia_ativacao:
			return
		temporizador -= delta
		if temporizador <= 0.0:
			estado = Estado.AVISO_TELEPORTE
			temporizador = aviso_antes_teleporte
		return

	temporizador -= delta
	if temporizador > 0.0:
		return
	match estado:
		Estado.AVISO_TELEPORTE:
			if _teleportar_para_ponto_alto():
				estado = Estado.AVISO_DISPARO
				temporizador = aviso_antes_onda
			else:
				# Nunca teleporta para dentro de piso, teto ou parede.
				estado = Estado.AGUARDANDO
				temporizador = 0.35
		Estado.AVISO_DISPARO:
			_disparar_onda_wifi()
			estado = Estado.RECUPERANDO
			temporizador = pausa_apos_onda
		Estado.RECUPERANDO:
			estado = Estado.AVISO_TELEPORTE
			temporizador = aviso_antes_teleporte


func _centro_jogador() -> Vector2:
	# O personagem e desenhado a partir de seu canto superior esquerdo.
	return jogador.global_position + Vector2(20.0, 20.0)


func _teleportar_para_ponto_alto() -> bool:
	var centro: Vector2 = _centro_jogador()
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var forma: Shape2D = $CollisionShape2D.shape
	if forma == null:
		return false

	var melhor: Vector2 = Vector2.ZERO
	var maior_distancia_chao: float = -1.0
	var lado_escolhido: int = ultimo_lado
	# Mesmo raio do jogador em TODOS os candidatos; prioriza ar alto.
	# Testa ambos os lados, inclusive alternativas para salas apertadas.
	for angulo_graus in [-78.0, -70.0, -62.0, -54.0, -46.0, -38.0, -28.0, -15.0, 0.0, 15.0]:
		var angulo: float = deg_to_rad(angulo_graus)
		for lado in [-1, 1]:
			var candidato: Vector2 = centro + Vector2(
				cos(angulo) * distancia_teleporte * float(lado),
				sin(angulo) * distancia_teleporte
			)
			# Margem interna da sala; evitar teleporte no contorno/portas.
			if candidato.x < 42.0 or candidato.x > 1110.0 or candidato.y < 43.0 or candidato.y > 560.0:
				continue
			var consulta: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			consulta.shape = forma
			consulta.transform = Transform2D(0.0, candidato)
			consulta.collision_mask = 1
			consulta.exclude = [get_rid(), jogador.get_rid()]
			if not espaco.intersect_shape(consulta, 1).is_empty():
				continue
			var raio: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				candidato + Vector2(0.0, 18.0),
				candidato + Vector2(0.0, 650.0),
				1
			)
			raio.exclude = [get_rid(), jogador.get_rid()]
			var solo: Dictionary = espaco.intersect_ray(raio)
			# Sem piso embaixo, nao e um bom alvo para combate com pulo.
			if solo.is_empty():
				continue
			var normal_chao: Vector2 = solo.get("normal", Vector2.ZERO)
			if normal_chao.y > -0.5:
				continue
			var ponto_chao: Vector2 = solo.get("position", candidato)
			var altura_livre: float = ponto_chao.y - candidato.y
			# Se empatar, alternar de lado para cada teleporte ser relevante.
			if altura_livre > maior_distancia_chao + 0.5 or (absf(altura_livre - maior_distancia_chao) <= 0.5 and lado != ultimo_lado):
				maior_distancia_chao = altura_livre
				melhor = candidato
				lado_escolhido = lado

	if maior_distancia_chao < 0.0:
		return false
	global_position = melhor
	velocity = Vector2.ZERO
	ultimo_lado = lado_escolhido
	return true


func _disparar_onda_wifi() -> void:
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	var direcao_tiro: Vector2 = (_centro_jogador() - global_position).normalized()
	if direcao_tiro.is_zero_approx():
		direcao_tiro = Vector2.DOWN
	var onda: Area2D = CENA_ONDA.instantiate() as Area2D
	onda.call("configurar", direcao_tiro, velocidade_onda, dano, alcance_onda)
	get_parent().add_child(onda)
	onda.global_position = global_position + direcao_tiro * 23.0


func _draw() -> void:
	# Contorno de aviso: roxo para teleporte, ciano para disparo.
	if estado == Estado.AVISO_TELEPORTE:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(1.0, 0.40, 0.98, 0.8), 2.5, true)
	elif estado == Estado.AVISO_DISPARO:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(0.38, 0.95, 1.0, 0.9), 2.5, true)
