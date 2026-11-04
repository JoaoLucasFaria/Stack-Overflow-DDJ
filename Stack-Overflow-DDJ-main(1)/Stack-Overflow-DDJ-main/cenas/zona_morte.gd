extends Area2D

func _ready() -> void:
	# Conecta o sinal de colisão automaticamente via código
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if body.has_method("receber_dano"):
			body.receber_dano(999)
