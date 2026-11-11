class_name DashComponent
extends Node

## Habilidade malloc: dash horizontal com invencibilidade opcional.
## A movimentação física é aplicada apenas pelo Jogador; este nó gerencia estado.
@export_category("Estado de Desbloqueio")
@export var dash_desbloqueado: bool = true

@export_category("Configurações do Dash")
@export_range(1.0, 2000.0, 1.0) var velocidade_dash: float = 600.0
@export_range(0.01, 5.0, 0.01) var tempo_duracao_dash: float = 0.2
@export_range(0.0, 5.0, 0.01) var tempo_cooldown_dash: float = 0.5

@export_category("Invencibilidade")
@export var dar_invencibilidade: bool = true

signal dash_iniciado
signal dash_finalizado

var esta_dashing: bool = false
var e_invencivel: bool = false
var ja_usou_dash_no_ar: bool = false
var tempo_dash_atual: float = 0.0
var tempo_cooldown_atual: float = 0.0
var direcao_dash: int = 1


func atualizar(delta: float, no_chao: bool, direcao_olhar: int) -> void:
	if no_chao:
		ja_usou_dash_no_ar = false

	if tempo_cooldown_atual > 0.0:
		tempo_cooldown_atual = maxf(0.0, tempo_cooldown_atual - delta)

	if esta_dashing:
		tempo_dash_atual -= delta
		if tempo_dash_atual <= 0.0:
			_finalizar_dash()
		return

	if not dash_desbloqueado or tempo_cooldown_atual > 0.0:
		return
	if not Input.is_action_just_pressed("dash"):
		return
	if not no_chao and ja_usou_dash_no_ar:
		return

	if not no_chao:
		ja_usou_dash_no_ar = true
	iniciar_dash(direcao_olhar)


func iniciar_dash(direcao: int) -> void:
	if esta_dashing or not dash_desbloqueado:
		return
	direcao_dash = -1 if direcao < 0 else 1
	esta_dashing = true
	e_invencivel = dar_invencibilidade
	tempo_dash_atual = tempo_duracao_dash
	dash_iniciado.emit()


func obter_velocidade_dash() -> Vector2:
	return Vector2(float(direcao_dash) * velocidade_dash, 0.0)


func _finalizar_dash() -> void:
	cancelar_dash()
	tempo_cooldown_atual = tempo_cooldown_dash
	dash_finalizado.emit()


func cancelar_dash() -> void:
	## Chamado também quando o jogador atravessa uma porta.
	esta_dashing = false
	e_invencivel = false
	tempo_dash_atual = 0.0
