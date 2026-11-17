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
## O Interrupt nunca cancela uma mudanca de fase ou sua recuperacao.
var interrupcao_restante: float = 0.0
var protecao_fase_restante: float = 0.0
var lentidao_mutex_restante: float = 0.0
var fator_lentidao_mutex: float = 0.7


func configurar(alvo: Jogador) -> void:
	jogador = alvo


func _ready() -> void:
	# O ataque basico consulta apenas corpos da camada 2.
	# O jogador atravessa o boss, evitando empurroes fisicos.
	collision_layer = 2
	collision_mask = 0
	vida_atual = vida_maxima
	vida_alterada.emit(vida_atual, vida_maxima)
	add_to_group("chefes")
	fase_alterada.connect(_quando_fase_muda)


func _quando_fase_muda(_fase: int) -> void:
	bloquear_interrupt_na_transicao(0.9)


func bloquear_interrupt_na_transicao(duracao: float = 0.9) -> void:
	interrupcao_restante = 0.0
	protecao_fase_restante = maxf(protecao_fase_restante, duracao)


func aplicar_lentidao_mutex(duracao: float = 1.2) -> void:
	if not encerrado:
		lentidao_mutex_restante = maxf(lentidao_mutex_restante, duracao)


func _tempo_com_lentidao(delta: float) -> float:
	if lentidao_mutex_restante > 0.0:
		lentidao_mutex_restante = maxf(0.0, lentidao_mutex_restante - delta)
		return delta * fator_lentidao_mutex
	return delta


func _processar_interrupcao(delta: float) -> bool:
	protecao_fase_restante = maxf(0.0, protecao_fase_restante - delta)
	if interrupcao_restante > 0.0:
		interrupcao_restante = maxf(0.0, interrupcao_restante - delta)
		return true
	return false


func interromper_ataques(duracao: float = 1.0) -> bool:
	if encerrado or protecao_fase_restante > 0.0 or not _pode_ser_interrompido():
		return false
	interrupcao_restante = maxf(interrupcao_restante, duracao)
	_cancelar_ataque_para_interrupcao()
	return true


func _pode_ser_interrompido() -> bool:
	return true


func _cancelar_ataque_para_interrupcao() -> void:
	pass


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
