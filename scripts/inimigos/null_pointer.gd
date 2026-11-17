extends InimigoBase

## Teleporte curto telegrafado, sem atravessar as salas nem cair no vazio.
var tempo_teleporte: float = 2.8
var aviso_teleporte: float = 0.0


func _pensar(delta: float) -> void:
	tempo_teleporte -= delta
	if aviso_teleporte > 0.0:
		velocity.x = 0.0
		aviso_teleporte -= delta
		visual.modulate = Color(0.7, 0.4, 1.0)
		if aviso_teleporte <= 0.0:
			_teleportar_perto_do_jogador()
		return
	if _alvo_proximo(300.0) and tempo_teleporte <= 0.0:
		aviso_teleporte = 0.40
		tempo_teleporte = 3.8
		velocity.x = 0.0
		return
	_patrulhar_ou_perseguir()


func _teleportar_perto_do_jogador() -> void:
	if not _alvo_proximo(350.0):
		return
	# O destino fica na MESMA altura e só é usado se houver chão e espaço.
	var sentido: float = -1.0 if jogador.global_position.x > global_position.x else 1.0
	var candidato: Vector2 = Vector2(clampf(jogador.global_position.x + sentido * 80.0, 65.0, 1087.0), global_position.y)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(candidato + Vector2(0, 10), candidato + Vector2(0, 58), 1)
	query.exclude = [get_rid()]
	if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return
	var parametro: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	parametro.shape = $CollisionShape2D.shape
	parametro.transform = Transform2D(0.0, candidato)
	parametro.collision_mask = 1
	parametro.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(parametro, 2).is_empty():
		return
	global_position = candidato
	velocity = Vector2.ZERO
