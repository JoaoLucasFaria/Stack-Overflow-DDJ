extends Area2D

signal jogador_entrou

## Evita reabrir a porta durante o spawn da sala recém-carregada.
@export_range(0.0, 3.0, 0.05) var atraso_ativacao: float = 0.2

var ativada: bool = false


func _ready() -> void:
	monitoring = false
	_ativar_apos_spawn()


func _ativar_apos_spawn() -> void:
	await get_tree().create_timer(atraso_ativacao).timeout
	if is_inside_tree():
		monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if ativada or not body.is_in_group("jogador"):
		return
	ativada = true
	# Trocas de cenas não devem ocorrer durante a atualização de colisões.
	call_deferred("_emitir_sinal")


func _emitir_sinal() -> void:
	jogador_entrou.emit()
