extends InimigoBase

## Bomba de processos: fixa no teto/plataforma, ate tres filhos vivos.
const CENA_FILHO: PackedScene = preload("res://cenas/inimigos/child_process.tscn")

@export_category("Colmeia de processos")
@export_range(1, 6, 1) var maximo_filhos: int = 3
@export_range(1.5, 12.0, 0.25) var intervalo_spawn: float = 4.5
@export_range(80.0, 1000.0, 10.0) var alcance_ativacao: float = 630.0
@export_range(90.0, 520.0, 10.0) var alcance_fixacao: float = 425.0
var filhos: Array[InimigoBase] = []
var relogio: float = 2.0
var preso: bool = false


func _ready() -> void:
	fixo_no_cenario = true
	super._ready()
	call_deferred("_ancorar")


func _ancorar() -> void:
	# O Main atribui a posicao do marcador apos add_child, por isso o defer.
	if not is_inside_tree() or encerrado:
		return
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var melhor: Vector2 = Vector2.ZERO
	var melhor_distancia: float = INF
	for deslocamento in [0.0, -90.0, 90.0, -175.0, 175.0, -265.0, 265.0]:
		var origem_raio: Vector2 = global_position + Vector2(deslocamento, -8.0)
		var fim: Vector2 = origem_raio + Vector2(0, -alcance_fixacao)
		var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origem_raio, fim, 1)
		consulta.exclude = [get_rid()]
		var hit: Dictionary = espaco.intersect_ray(consulta)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		if normal.y < 0.6:
			continue
		var ponto: Vector2 = hit.get("position", origem_raio)
		var candidato: Vector2 = ponto + Vector2(0, 22)
		var teste: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		teste.shape = $CollisionShape2D.shape
		teste.transform = Transform2D(0.0, candidato)
		teste.collision_mask = 1
		teste.exclude = [get_rid()]
		if not espaco.intersect_shape(teste, 1).is_empty():
			continue
		var distancia: float = global_position.distance_to(candidato)
		if distancia < melhor_distancia:
			melhor_distancia = distancia
			melhor = candidato
	if melhor_distancia == INF:
		# Raycasts ascendentes podem ignorar plataformas one-way. Inspeciona
		# retangulos manuais de StaticBody2D, inclusive plataformas atravessaveis.
		var cenario: Node = get_parent().get_parent() if get_parent().get_parent() != null else get_parent()
		for col in cenario.find_children("*", "CollisionShape2D", true, false):
			var forma: CollisionShape2D = col as CollisionShape2D
			if forma == null or not (forma.get_parent() is StaticBody2D):
				continue
			var retangulo: RectangleShape2D = forma.shape as RectangleShape2D
			if retangulo == null:
				continue
			var centro: Vector2 = forma.global_position
			var metade: Vector2 = retangulo.size * 0.5
			var baixo: float = centro.y + metade.y
			if baixo >= global_position.y - 25.0 or global_position.y - baixo > alcance_fixacao:
				continue
			var x: float = clampf(global_position.x, centro.x - metade.x + 22.0, centro.x + metade.x - 22.0)
			if x < centro.x - metade.x + 15.0 or x > centro.x + metade.x - 15.0:
				continue
			var candidato: Vector2 = Vector2(x, baixo + 22.0)
			var teste: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			teste.shape = $CollisionShape2D.shape
			teste.transform = Transform2D(0.0, candidato)
			teste.collision_mask = 1
			teste.exclude = [get_rid()]
			if get_world_2d().direct_space_state.intersect_shape(teste, 1).is_empty():
				var distancia: float = global_position.distance_to(candidato)
				if distancia < melhor_distancia:
					melhor_distancia = distancia
					melhor = candidato
	if melhor_distancia < INF:
		global_position = melhor
		preso = true
	else:
		# Nao gera uma colmeia no chao em salas sem teto alcancavel.
		queue_free()


func _pensar(delta: float) -> void:
	velocity = Vector2.ZERO
	if not preso or not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	if global_position.distance_to(jogador.global_position) > alcance_ativacao:
		return
	for i in range(filhos.size() - 1, -1, -1):
		if not is_instance_valid(filhos[i]) or filhos[i].is_queued_for_deletion():
			filhos.remove_at(i)
	if filhos.size() >= maximo_filhos:
		return
	relogio -= delta
	if relogio <= 0.0:
		call_deferred("_criar_filho")
		relogio = intervalo_spawn


func _criar_filho() -> void:
	if encerrado or not is_inside_tree() or filhos.size() >= maximo_filhos:
		return
	var processo: InimigoBase = CENA_FILHO.instantiate() as InimigoBase
	processo.configurar(jogador)
	var pai: Node = get_parent()
	pai.add_child(processo)
	processo.global_position = global_position + Vector2(randf_range(-14.0, 14.0), 35)
	filhos.append(processo)


func _iniciar_ataque() -> void:
	pass


func _executar_ataque() -> void:
	pass


func _morrer() -> void:
	# Filhos vivos sao destruídos com a colmeia; nao geram drops.
	for filho in filhos:
		if is_instance_valid(filho):
			filho.queue_free()
	filhos.clear()
	super._morrer()


func _draw() -> void:
	if preso:
		draw_line(Vector2(0, -23), Vector2(0, -15), Color(0.73, 0.38, 1), 5.0)
