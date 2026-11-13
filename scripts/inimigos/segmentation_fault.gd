extends InimigoBase

## Torreta fixa: o marcador deve ficar ao lado de uma parede (nao dentro dela).
## O script identifica a parede mais proxima e posiciona a torre na sua face.
const CENA_PROJETIL: PackedScene = preload("res://cenas/inimigos/projetil_corrompido.tscn")

@export_category("Torreta de Parede")
@export_range(20.0, 120.0, 1.0) var alcance_fixacao: float = 64.0
@export_range(1.0, 20.0, 1.0) var afastamento_parede: float = 3.0
@export_range(50.0, 1200.0, 10.0) var alcance_disparo: float = 520.0

const MEIA_LARGURA: float = 15.0
const RAIO_PROJETIL: float = 8.0
var normal_da_parede: Vector2 = Vector2.ZERO


func _ready() -> void:
	fixo_no_cenario = true
	super._ready()
	# O Main posiciona o inimigo *depois* de add_child(). Aguarde isso ocorrer.
	call_deferred("_fixar_na_parede")


func _fixar_na_parede() -> void:
	if not is_inside_tree():
		return
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var melhor_distancia: float = INF
	var melhor_hit: Dictionary = {}

	for sentido in [-1.0, 1.0]:
		var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, global_position + Vector2(sentido * alcance_fixacao, 0.0), 1
		)
		consulta.exclude = [get_rid()]
		if is_instance_valid(jogador):
			consulta.exclude.append(jogador.get_rid())
		var hit: Dictionary = espaco.intersect_ray(consulta)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.get("normal", Vector2.ZERO)
		if absf(normal.x) < 0.7:
			continue
		var distancia: float = global_position.distance_to(hit.get("position", global_position))
		if distancia < melhor_distancia:
			melhor_distancia = distancia
			melhor_hit = hit

	if melhor_hit.is_empty():
		# Compatibilidade com marcadores antigos no chao: fica fixo, mas sem snap.
		# Para montar de verdade, coloque o marcador ate 64 px da face da parede.
		return

	normal_da_parede = melhor_hit.get("normal", Vector2.ZERO)
	global_position = melhor_hit.get("position", global_position) + normal_da_parede * (MEIA_LARGURA + afastamento_parede)


func _pensar(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _alvo_visivel(alcance_disparo) and tempo_ate_ataque <= 0.0:
		_iniciar_ataque()


func _origem_projetil() -> Vector2:
	var saida: Vector2 = normal_da_parede
	if saida == Vector2.ZERO and is_instance_valid(jogador):
		saida = (jogador.global_position + Vector2(20.0, 20.0) - global_position).normalized()
	if saida == Vector2.ZERO:
		saida = Vector2.RIGHT
	# Inclui o raio do tiro, evitando que ele ja nasca dentro da parede.
	return global_position + saida * (MEIA_LARGURA + RAIO_PROJETIL + afastamento_parede + 2.0)


func _alvo_visivel(distancia: float) -> bool:
	if not _alvo_proximo(distancia):
		return false
	var origem_tiro: Vector2 = _origem_projetil()
	# O centro do jogador, nao a origem do Node2D no canto superior esquerdo.
	var destino: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
	var vetor: Vector2 = destino - origem_tiro
	if vetor.length_squared() < 0.01:
		return false
	# Evita disparar para tras da parede a que esta fixado.
	if normal_da_parede != Vector2.ZERO and vetor.dot(normal_da_parede) < 0.0:
		return false
	var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origem_tiro, destino, 1)
	consulta.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(consulta)
	# Se a primeira coisa atingida for a parede/plataforma, nao desperdice tiro.
	return hit.is_empty() or hit.get("collider") == jogador


func _executar_ataque() -> void:
	if not _alvo_visivel(alcance_disparo + 60.0):
		return
	var tiro: Area2D = CENA_PROJETIL.instantiate() as Area2D
	get_parent().add_child(tiro)
	tiro.global_position = _origem_projetil()
	if tiro.has_method("configurar"):
		var destino: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
		tiro.call("configurar", (destino - tiro.global_position).normalized(), dano)


func _alvo_proximo(distancia: float) -> bool:
	return (
		is_instance_valid(jogador)
		and jogador.vida_atual > 0
		and global_position.distance_to(jogador.global_position + Vector2(20.0, 20.0)) <= distancia
	)
