class_name BossBase
extends StaticBody2D

## Contrato compartilhado pelos tres chefes. A arena decide o que fazer
## quando recebe o sinal derrotado (por exemplo, desbloquear habilidade).
signal derrotado(identificador: int)
signal vida_alterada(atual: int, maxima: int)
signal fase_alterada(fase: int)

@export_category("Identidade e vida")
@export_range(1, 3, 1) var identificador: int = 1
@export var nome_exibicao: String = "GUARDIAO 1"
@export_range(1, 200, 1) var vida_maxima: int = 18
@export_range(0.1, 0.9, 0.05) var limiar_segunda_fase: float = 0.5

var vida_atual: int = 0
var fase_atual: int = 1
var encerrado: bool = false
var jogador: Jogador


func configurar(alvo: Jogador) -> void:
	jogador = alvo


func _ready() -> void:
	# O ataque basico consulta apenas corpos da camada 2.
	# O jogador atravessa o boss, evitando empurroes fisicos.
	collision_layer = 2
	collision_mask = 0
	vida_atual = vida_maxima
	vida_alterada.emit(vida_atual, vida_maxima)


func receber_dano(quantidade: int) -> void:
	if encerrado or quantidade <= 0:
		return
	if not _esta_vulneravel():
		_ao_golpe_bloqueado()
		return

	vida_atual = maxi(vida_atual - quantidade, 0)
	_ao_receber_dano(quantidade)
	vida_alterada.emit(vida_atual, vida_maxima)

	if vida_atual <= 0:
		encerrado = true
		_ao_derrota()
		derrotado.emit(identificador)
		queue_free()
		return

	if fase_atual == 1 and float(vida_atual) <= float(vida_maxima) * limiar_segunda_fase:
		fase_atual = 2
		_ao_segunda_fase()
		fase_alterada.emit(fase_atual)


func _esta_vulneravel() -> bool:
	return true


func _ao_golpe_bloqueado() -> void:
	pass


func _ao_receber_dano(_quantidade: int) -> void:
	pass


func _ao_segunda_fase() -> void:
	pass


func _ao_derrota() -> void:
	pass
