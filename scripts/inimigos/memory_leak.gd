extends InimigoBase

## Memory Leak: cresce com o tempo e ganha vida e dano conforme o tamanho.
## Estado e HP restante persistem por sala ate o proximo BREAKPOINT.
@export_category("Crescimento")
@export var escala_maxima: float = 4.0
@export var segundos_para_crescer: float = 14.0
@export_range(0, 100, 1) var vida_extra_no_maximo: int = 5
@export_range(0, 20, 1) var dano_extra_no_maximo: int = 2

var tempo_vivo: float = 0.0
var vida_maxima_base: int = 0
var dano_base: int = 0
var tamanho_base: Vector2 = Vector2(30.0, 30.0)


func _ready() -> void:
	super._ready()
	vida_maxima_base = vida_maxima
	dano_base = dano

	# Nao compartilhar o formato de colisao com outros inimigos/cenas.
	var forma_original: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	if forma_original == null:
		push_error("Memory Leak precisa de um RectangleShape2D.")
		return
	tamanho_base = forma_original.size
	var forma_propria: RectangleShape2D = forma_original.duplicate() as RectangleShape2D
	$CollisionShape2D.shape = forma_propria
	# A Area2D de dano por contato precisa crescer junto com o corpo.
	if is_instance_valid(colisao_contato):
		colisao_contato.shape = forma_propria
	_atualizar_crescimento()


func _physics_process(delta: float) -> void:
	if not encerrado:
		# Continua crescendo ate quando esta preparando um ataque.
		tempo_vivo += delta
		_atualizar_crescimento()
	super._physics_process(delta)


func _pensar(_delta: float) -> void:
	_patrulhar_ou_perseguir()


func _atualizar_crescimento() -> void:
	var fracao: float = clampf(tempo_vivo / maxf(0.1, segundos_para_crescer), 0.0, 1.0)
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
		# O crescimento acrescenta HP, mas nao apaga o dano ja recebido.
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
	# Restaurar HP depois de calcular a vida maxima do tamanho salvo.
	vida_atual = clampi(int(estado.get("vida_atual", vida_maxima)), 1, vida_maxima)
