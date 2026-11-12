extends InimigoBase

## Atirador fixo (não persegue). Dispara apenas se o jogador estiver à vista.
const CENA_PROJETIL: PackedScene = preload("res://cenas/inimigos/projetil_corrompido.tscn")


func _pensar(_delta: float) -> void:
	velocity.x = 0.0
	if _alvo_proximo(520.0) and tempo_ate_ataque <= 0.0:
		_iniciar_ataque()


func _executar_ataque() -> void:
	if not _alvo_proximo(580.0):
		return
	var tiro: Area2D = CENA_PROJETIL.instantiate() as Area2D
	get_parent().add_child(tiro)
	tiro.global_position = global_position + Vector2(0, -5)
	if tiro.has_method("configurar"):
		tiro.call("configurar", (jogador.global_position - tiro.global_position).normalized(), dano)
		
func _alvo_proximo(distancia: float) -> bool:
	if not is_instance_valid(jogador):
		return false

	if jogador.vida_atual <= 0:
		return false

	return global_position.distance_to(
		jogador.global_position
	) <= distancia
