extends CanvasLayer

@onready var barra_vida = $MarginContainer/VBoxContainer/BarraVida
@onready var barra_sobrecarga = $MarginContainer/VBoxContainer/BarraSobrecarga
@onready var texto_habilidade = $MarginContainer/VBoxContainer/Habilidades/HabAtual

# Ouve o sinal do jogador e ajusta a vida


# Ouve o sinal do jogador e ajusta a sobrecarga
func _on_overflow_alterado(atual: float, maximo: float) -> void:
	barra_sobrecarga.max_value = maximo
	barra_sobrecarga.value = atual

func atualizar_habilidade(nome_hab: String) -> void:
	texto_habilidade.text = "Habilidade: " + nome_hab
	
func _on_vida_alterada(atual: int, maxima: int) -> void:
	print("SINAL RECEBIDO NA HUD! Vida atual: ", atual, " Max: ", maxima)
	barra_vida.max_value = maxima
	barra_vida.value = atual

func _on_player_vida_alterada(atual: int, maxima: int) -> void:
	pass # Replace with function body.


func _on_player_overflow_alterado(atual: float, maximo: float) -> void:
	pass # Replace with function body.

func atualizar_barras(jogador) -> void:
	if not is_instance_valid(jogador):
		return
	barra_vida.max_value = jogador.vida_maxima
	barra_vida.value = jogador.vida_atual
	
	barra_sobrecarga.max_value = jogador.overflow_maximo
	barra_sobrecarga.value = jogador.overflow_atual
