extends Area2D

signal jogador_entrou

var ativada: bool = false

func _ready() -> void:
	monitoring = false
	call_deferred("_ativar_porta")

func _ativar_porta() -> void:
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		monitoring = true

func _on_body_entered(body: Node2D) -> void:
	if ativada:
		return
		
	if body is CharacterBody2D:
		ativada = true
		# Adia a chamada do sinal para o próximo frame, evitando conflito na física
		call_deferred("_emitir_sinal")

func _emitir_sinal() -> void:
	emit_signal("jogador_entrou")
