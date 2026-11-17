extends InimigoBase

## Duas execucoes concorrentes compartilham um HP; so atacam em conjunto.
const CENA_ECO: PackedScene = preload("res://cenas/inimigos/race_echo.tscn")
enum Estado { PROCURANDO, AVISO, DIVIDIDOS, ABERTURA }

@export var tempo_divididos: float = 2.7
@export var tempo_abertura: float = 1.25
@export var altura_eco: float = 110.0
var estado: Estado = Estado.PROCURANDO
var relogio: float = 0.8
var eco: CharacterBody2D
var tempo_animacao: float = 0.0


func _pensar(delta: float) -> void:
	var alvo: Node2D = _alvo_da_ia()
	if not is_instance_valid(alvo):
		velocity.x = 0.0
		return
	if estado == Estado.PROCURANDO:
		_patrulhar_ou_perseguir()
		if global_position.distance_to(alvo.global_position) < 245.0:
			estado = Estado.AVISO
			relogio = 0.42
	elif estado == Estado.AVISO:
		velocity.x = 0.0
		relogio -= delta
		if relogio <= 0.0:
			_dividir()
	elif estado == Estado.DIVIDIDOS:
		tempo_animacao += delta
		relogio -= delta
		var diferenca: float = alvo.global_position.x - global_position.x
		direcao = signf(diferenca) if absf(diferenca) > 10.0 else direcao
		velocity.x = direcao * velocidade * 1.25 if _pode_caminhar(direcao) else 0.0
		# O clone gerencia sua propria perseguicao e investida em race_echo.gd.
		if relogio <= 0.0:
			_reunir()
	elif estado == Estado.ABERTURA:
		velocity.x = 0.0
		relogio -= delta
		if relogio <= 0.0:
			estado = Estado.PROCURANDO
			relogio = 0.0


func _iniciar_ataque() -> void:
	# O golpe coordenado ocorre pela perseguicao e pelo contato do eco.
	pass


func _dividir() -> void:
	estado = Estado.DIVIDIDOS
	relogio = tempo_divididos
	tempo_animacao = 0.0
	if not is_instance_valid(eco):
		call_deferred("_criar_eco")


func _criar_eco() -> void:
	if encerrado or not is_inside_tree() or estado != Estado.DIVIDIDOS or is_instance_valid(eco):
		return
	eco = CENA_ECO.instantiate() as CharacterBody2D
	eco.set("fonte", self)
	get_parent().add_child(eco)
	eco.global_position = global_position + Vector2(0, -65)


func _reunir() -> void:
	if is_instance_valid(eco):
		eco.queue_free()
		eco = null
	estado = Estado.ABERTURA
	relogio = tempo_abertura


func interromper_ataques(duracao: float = 1.0) -> bool:
	if not super.interromper_ataques(duracao):
		return false
	_reunir()
	return true


func _morrer() -> void:
	if is_instance_valid(eco):
		eco.queue_free()
	super._morrer()
