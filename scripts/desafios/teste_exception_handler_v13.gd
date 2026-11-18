extends Node2D

## F6: executa o desafio isolado, sem alterar a campanha procedural.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
@onready var desafio: ControladorExceptionHandler = $ExceptionHandler
var jogador: Jogador


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.global_position = Vector2(155, 548)
	# Simula o trecho depois do Guardiao 1: Fork Bomb pode ser sorteada.
	jogador.desbloquear_pulo_duplo()
	jogador.desbloquear_dash()
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	inventario.equipar(&"segmentation_fault")
	inventario.slot_para_substituir = 1
	inventario.equipar(&"syntax_error")
	desafio.configurar(jogador, true)
	desafio.desafio_concluido.connect(_ao_recompensa)


func _ao_recompensa(id: StringName) -> void:
	print("[V13] Desafio concluido. Patch: ", id)
