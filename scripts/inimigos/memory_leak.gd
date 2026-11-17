extends InimigoBase

## Memory Leak: persegue, cresce e armazena crescimento/HP entre visitas.
## O novo ataque e um salto curto seguido de duas ondas como as do Woodbreaker.
const CENA_ONDA: PackedScene = preload("res://cenas/inimigos/onda_memory_leak.tscn")

enum EstadoAtaque { PERSEGUINDO, SALTANDO, RECUPERANDO }

@export_category("Crescimento")
@export var escala_maxima: float = 4.0
@export var segundos_para_crescer: float = 14.0
@export_range(0, 100, 1) var vida_extra_no_maximo: int = 5
@export_range(0, 20, 1) var dano_extra_no_maximo: int = 2

@export_category("Salto e ondas")
@export_range(50.0, 350.0, 5.0) var impulso_salto: float = 165.0
@export_range(0.1, 2.0, 0.05) var recuperacao_apos_salto: float = 0.45
@export_range(8.0, 54.0, 1.0) var altura_onda_inicial: float = 18.0
@export_range(12.0, 34.0, 1.0) var largura_onda_inicial: float = 20.0
## Maximo = dimensoes da onda de choque do Woodbreaker: 34 x 54.
@export_range(18.0, 54.0, 1.0) var altura_onda_maxima: float = 54.0
@export_range(20.0, 34.0, 1.0) var largura_onda_maxima: float = 34.0
@export_range(50.0, 1200.0, 10.0) var alcance_onda_inicial: float = 165.0
@export_range(50.0, 1200.0, 10.0) var alcance_onda_maximo: float = 1150.0
@export_range(100.0, 500.0, 5.0) var velocidade_onda_inicial: float = 285.0
@export_range(100.0, 500.0, 5.0) var velocidade_onda_maxima: float = 425.0

var tempo_vivo: float = 0.0
var vida_maxima_base: int = 0
var dano_base: int = 0
var tamanho_base: Vector2 = Vector2(30.0, 30.0)
var estado_ataque: EstadoAtaque = EstadoAtaque.PERSEGUINDO
var tempo_no_salto: float = 0.0
var tempo_recuperacao: float = 0.0


func _ready() -> void:
	super._ready()
	vida_maxima_base = vida_maxima
	dano_base = dano

	# Nao compartilhar a forma de colisao com outras instancias.
	var forma_original: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if forma_original == null:
		push_error("Memory Leak precisa de um RectangleShape2D.")
		return
	tamanho_base = forma_original.size
	var forma_propria: RectangleShape2D = forma_original.duplicate() as RectangleShape2D
	$CollisionShape2D.shape = forma_propria
	if is_instance_valid(colisao_contato):
		colisao_contato.shape = forma_propria
	_atualizar_crescimento()


func _physics_process(delta: float) -> void:
	if not encerrado:
		# O crescimento continua mesmo durante aviso, salto ou recuperacao.
		tempo_vivo += delta
		_atualizar_crescimento()
	super._physics_process(delta)


func _pensar(delta: float) -> void:
	match estado_ataque:
		EstadoAtaque.SALTANDO:
			velocity.x = 0.0
			tempo_no_salto += delta
			# Usa o contato com o piso real, nao um cronometro ficticio.
			# O tempo minimo impede disparar as ondas no mesmo frame do pulo.
			if tempo_no_salto > 0.12 and is_on_floor():
				_lancar_ondas()
				estado_ataque = EstadoAtaque.RECUPERANDO
				tempo_recuperacao = recuperacao_apos_salto
				velocity = Vector2.ZERO
		EstadoAtaque.RECUPERANDO:
			velocity.x = 0.0
			tempo_recuperacao -= delta
			if tempo_recuperacao <= 0.0:
				estado_ataque = EstadoAtaque.PERSEGUINDO
		EstadoAtaque.PERSEGUINDO:
			# Preserva a patrulha/perseguicao original. Apenas o golpe mudou.
			_patrulhar_ou_perseguir()


func _iniciar_ataque() -> void:
	if preparando_ataque or tempo_ate_ataque > 0.0 or estado_ataque != EstadoAtaque.PERSEGUINDO:
		return
	if not is_on_floor():
		return
	preparando_ataque = true
	tempo_aviso = 0.36
	tempo_ate_ataque = intervalo_ataque
	velocity.x = 0.0


func _executar_ataque() -> void:
	# Super executa esta funcao ao final do aviso amarelo do ataque.
	if encerrado or not is_on_floor():
		return
	estado_ataque = EstadoAtaque.SALTANDO
	tempo_no_salto = 0.0
	velocity.x = 0.0
	velocity.y = -impulso_salto


func interromper_ataques(duracao: float = 1.0) -> bool:
	if not super.interromper_ataques(duracao):
		return false
	# Cancela o salto/ondas pendentes e preserva o crescimento acumulado.
	estado_ataque = EstadoAtaque.RECUPERANDO
	tempo_recuperacao = 0.25
	return true


func _fracao_crescimento() -> float:
	return clampf(tempo_vivo / maxf(0.1, segundos_para_crescer), 0.0, 1.0)


func _lancar_ondas() -> void:
	var fracao: float = _fracao_crescimento()
	var altura: float = lerpf(altura_onda_inicial, altura_onda_maxima, fracao)
	var largura: float = lerpf(largura_onda_inicial, largura_onda_maxima, fracao)
	var alcance: float = lerpf(alcance_onda_inicial, alcance_onda_maximo, fracao)
	var velocidade_onda: float = lerpf(velocidade_onda_inicial, velocidade_onda_maxima, fracao)
	var forma: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if forma == null:
		return
	var chao: float = global_position.y + forma.size.y * 0.5
	for lado in [-1, 1]:
		var onda: Area2D = CENA_ONDA.instantiate() as Area2D
		onda.call("configurar", lado, velocidade_onda, dano, Vector2(largura, altura), alcance)
		get_parent().add_child(onda)
		onda.global_position = Vector2(
			global_position.x + float(lado) * (forma.size.x * 0.5 + largura * 0.5 + 3.0),
			chao - altura * 0.5
		)


func _atualizar_crescimento() -> void:
	var fracao: float = _fracao_crescimento()
	var escala: float = lerpf(1.0, maxf(1.0, escala_maxima), fracao)
	var tamanho: Vector2 = tamanho_base * escala

	var forma: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if forma != null:
		forma.size = tamanho
	$Visual.offset_left = -tamanho.x * 0.5
	$Visual.offset_top = -tamanho.y * 0.5
	$Visual.offset_right = tamanho.x * 0.5
	$Visual.offset_bottom = tamanho.y * 0.5

	var nova_vida_maxima: int = vida_maxima_base + roundi(fracao * vida_extra_no_maximo)
	if nova_vida_maxima != vida_maxima:
		# Crescer acrescenta HP, mas nao apaga o dano recebido.
		var diferenca: int = nova_vida_maxima - vida_maxima
		vida_maxima = nova_vida_maxima
		vida_atual = clampi(vida_atual + diferenca, 1, vida_maxima)

	dano = dano_base + roundi(fracao * dano_extra_no_maximo)


func exportar_estado_persistente() -> Dictionary:
	return {
		"tempo_vivo": tempo_vivo,
		"vida_atual": vida_atual
	}


func restaurar_estado_persistente(estado: Dictionary) -> void:
	tempo_vivo = maxf(0.0, float(estado.get("tempo_vivo", 0.0)))
	_atualizar_crescimento()
	vida_atual = clampi(int(estado.get("vida_atual", vida_maxima)), 1, vida_maxima)
