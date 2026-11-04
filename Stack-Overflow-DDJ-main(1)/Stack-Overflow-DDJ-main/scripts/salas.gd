extends Node2D

@export_enum("esq_baixo", "esq_medio", "esq_alta", "queda", "dir_baixo", "dir_medio", "dir_alta", "topo", "undefined") var tipo_entrada: String = "esq_baixo"
@export_enum("esq_baixo", "esq_medio", "esq_alta", "queda", "dir_baixo", "dir_medio", "dir_alta", "topo", "undefined") var proxima_entrada: String = "esq_baixo"

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


func _on_zona_morte_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
