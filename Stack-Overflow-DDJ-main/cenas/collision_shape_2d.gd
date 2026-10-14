extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Verifica se o objeto que entrou na área foi o jogador
	if body.name == "Player":
		# Reinicia a cena atual (como o jogo roda na Main, ele volta ao início)
		get_tree().reload_current_scene()
