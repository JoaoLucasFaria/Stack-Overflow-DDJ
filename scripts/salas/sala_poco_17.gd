extends "res://scripts/sala_matriz.gd"

## Sala 17: substitui o bloqueio_dash e aplica dano ao cair no poço.
## O bloqueio lógico da porta direita continua exigindo dash no gerador.
@export_range(1, 10, 1) var dano_queda: int = 2

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(jogador) or dados.get("tipo", "") != "bloqueio_dash":
		return
	if jogador.global_position.y <= global_position.y + ALTURA + 45.0:
		return
	# Dano ambiental inevitavel: nao e golpe de inimigo nem e bloqueado por
	# i-frames/dash. O retorno acontece na borda pela qual o jogador entrou.
	jogador.preparar_para_nova_sala()
	jogador.global_position = ponto_retorno_abismo
	jogador.vida_atual = maxi(0, jogador.vida_atual - dano_queda)
	jogador.vida_alterada.emit(jogador.vida_atual, jogador.vida_maxima)
	if jogador.vida_atual <= 0:
		jogador.morrer()
		return
	jogador.tempo_iframes = maxf(jogador.tempo_iframes, 0.9)
