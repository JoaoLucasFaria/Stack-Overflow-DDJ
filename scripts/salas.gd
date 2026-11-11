class_name Sala
extends Node2D

## As salas mantêm os valores originais de entrada/saída.
## O Main verifica a compatibilidade antes de sortear a próxima sala.
@export_enum("esq_baixo", "esq_medio", "esq_alta", "queda", "dir_baixo", "dir_medio", "dir_alta", "topo", "undefined") var tipo_entrada: String = "esq_baixo"
@export_enum("esq_baixo", "esq_medio", "esq_alta", "queda", "dir_baixo", "dir_medio", "dir_alta", "topo", "undefined") var proxima_entrada: String = "esq_baixo"


func get_tipo_entrada() -> String:
	return tipo_entrada


func get_proxima_entrada() -> String:
	return proxima_entrada


func obter_spawn(direcao_chegada: String) -> Vector2:
	var nome_marcador: String = "SpawnDireita" if direcao_chegada == "esquerda" else "SpawnEsquerda"
	var marcador: Marker2D = get_node_or_null(nome_marcador) as Marker2D
	if marcador != null:
		return marcador.global_position

	# Fallback seguro para cenas em desenvolvimento sem marcador.
	var jogador_da_sala: Node2D = get_node_or_null("Player") as Node2D
	if jogador_da_sala != null:
		return jogador_da_sala.global_position
	push_warning("Sala sem marcador de spawn: " + name + " / " + nome_marcador)
	return global_position


func configurar_spawn(direcao: String, jogador: CharacterBody2D = null) -> void:
	## Aceita jogador externo (Main) e também funciona ao executar a sala sozinha.
	var alvo: CharacterBody2D = jogador
	if alvo == null:
		alvo = get_node_or_null("Player") as CharacterBody2D
	if alvo != null:
		alvo.global_position = obter_spawn(direcao)
