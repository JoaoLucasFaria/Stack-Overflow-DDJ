extends Node2D

## Fortalece o PROXIMO ataque basico, horizontal ou vertical.
## Toda logica do bonus pertence a este item, nao ao script do jogador.
@export var custo_overflow: float = 20.0
@export var recarga_segundos: float = 5.0
@export var acompanha_jogador: bool = true
@export_range(1, 20, 1) var dano_adicional: int = 2
@export var alcance_adicional: float = 95.0

var controle: EquipamentosAtivos


func ativar(_alvo: Jogador, inventario: EquipamentosAtivos) -> bool:
	if is_instance_valid(inventario.golpe_preparado):
		inventario.aviso.emit("Golpe Syntax Error ja esta preparado.")
		return false
	controle = inventario
	inventario.golpe_preparado = self
	position = Vector2(20.0, 20.0)
	queue_redraw()
	return true


func consumir() -> Dictionary:
	if controle == null or controle.golpe_preparado != self:
		return {}
	controle.golpe_preparado = null
	controle.equipamentos_alterados.emit()
	var bonus: Dictionary = {"dano_extra": dano_adicional, "alcance_extra": alcance_adicional, "aprimorado": true}
	queue_free()
	return bonus


func _draw() -> void:
	draw_arc(Vector2.ZERO, 30.0, -PI * 0.8, PI * 0.8, 18, Color(1.0, 0.42, 0.25, 0.95), 4.0)
