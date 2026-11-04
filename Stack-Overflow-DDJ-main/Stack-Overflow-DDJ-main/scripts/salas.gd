extends Node2D

@export_enum("esq_baixo", "esq_medio", "esq_alta", "queda", "dir_baixo", "dir_medio", "dir_alta", "topo", "undefined") var tipo_entrada: String = "esq_baixo"
@export_enum("esq_baixo", "esq_medio", "esq_alta", "queda", "dir_baixo", "dir_medio", "dir_alta", "topo", "undefined") var proxima_entrada: String = "esq_baixo"

@export var limite_esquerdo: int = 0
@export var limite_topo: int = -100
@export var limite_direito: int = 2566
@export var limite_baixo: int = 650

# O Godot pode expor isto automaticamente para o main.gd ler de forma segura:
func get_tipo_entrada() -> String:
	return tipo_entrada

func get_proxima_entrada
() -> String:
	return proxima_entrada
	

func configurar_spawn(direcao: String) -> void:
	call_deferred("_executar_spawn", direcao)

func _executar_spawn(direcao: String) -> void:
	var player = get_node_or_null("player")
	if player == null:
		player = get_node_or_null("Player")
	
	if player == null:
		return
		
	if direcao == "direita":
		var spawn_esq = get_node_or_null("SpawnEsquerda")
		if spawn_esq != null:
			player.global_position = spawn_esq.global_position
	elif direcao == "esquerda":
		var spawn_dir = get_node_or_null("SpawnDireita")
		if spawn_dir != null:
			player.global_position = spawn_dir.global_position
	if player.has_method("atualizar_limites_camera"):
		player.atualizar_limites_camera(limite_esquerdo, limite_topo, limite_direito, limite_baixo)