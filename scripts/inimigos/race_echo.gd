extends CharacterBody2D

## Copia agressiva, com investida propria. HP e dano recebidos sempre
## apontam para a instancia principal da Race Condition.
enum Estado { PERSEGUINDO, AVISANDO, INVESTINDO, RECUPERANDO }
@export var velocidade_perseguicao: float = 245.0
@export var velocidade_investida: float = 600.0
@export var alcance_disparo: float = 230.0
@export var tempo_aviso: float = 0.22
@export var duracao_investida: float = 0.34
@export var tempo_recuperacao: float = 0.26
@export var intervalo_investidas: float = 0.55
var fonte: InimigoBase
var dano: int = 1
var tempo_contato: float = 0.0
var recarga: float = 0.25
var estado: Estado = Estado.PERSEGUINDO
var relogio: float = 0.0
var direcao_golpe: Vector2 = Vector2.LEFT
var vida_atual: int:
	get:
		return fonte.vida_atual if is_instance_valid(fonte) else 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1  # Respeita pisos e plataformas, mas nao correntes.
	$Visual.color = Color(0.25, 0.82, 1.0, 0.82)
	# Como os demais inimigos, nao empurra o jogador fisicamente.
	# O dano continua vindo da verificacao de contato abaixo.
	if is_instance_valid(fonte) and is_instance_valid(fonte.jogador):
		add_collision_exception_with(fonte.jogador)
		fonte.jogador.add_collision_exception_with(self)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(fonte) or fonte.encerrado or fonte.is_queued_for_deletion():
		queue_free()
		return
	var jogador: Jogador = fonte.jogador
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	tempo_contato = maxf(0.0, tempo_contato - delta)
	recarga = maxf(0.0, recarga - delta)
	var alvo: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
	match estado:
		Estado.PERSEGUINDO:
			# Busca o jogador, nao um ponto fixo acima/depois dele.
			# Mover com colisao impede que a copia passe por plataformas.
			var vetor: Vector2 = alvo - global_position
			if vetor.length() > 4.0:
				move_and_collide(vetor.normalized() * minf(vetor.length(), velocidade_perseguicao * delta))
			if recarga <= 0.0 and global_position.distance_to(alvo) <= alcance_disparo:
				estado = Estado.AVISANDO
				relogio = tempo_aviso
		Estado.AVISANDO:
			relogio -= delta
			if relogio <= 0.0:
				# Travar a direcao somente quando o golpe comeca, nao antes.
				var rumo: Vector2 = alvo - global_position
				direcao_golpe = rumo.normalized() if rumo.length_squared() > 1.0 else Vector2.DOWN
				estado = Estado.INVESTINDO
				relogio = duracao_investida
		Estado.INVESTINDO:
			relogio -= delta
			var colisao: KinematicCollision2D = move_and_collide(direcao_golpe * velocidade_investida * delta)
			if colisao != null or relogio <= 0.0:
				estado = Estado.RECUPERANDO
				relogio = tempo_recuperacao
				recarga = intervalo_investidas
		Estado.RECUPERANDO:
			relogio -= delta
			if relogio <= 0.0:
				estado = Estado.PERSEGUINDO
	# Dano por contato no corpo (nenhum projetil adicional).
	# A mesma regra e usada no resto da arena.
	if tempo_contato <= 0.0 and global_position.distance_to(alvo) < 36.0:
		jogador.receber_dano(dano, global_position)
		tempo_contato = 0.7
	$Visual.modulate = Color(1.0, 0.65, 0.65) if estado == Estado.AVISANDO else Color.WHITE


func receber_dano(quantidade: int) -> void:
	if is_instance_valid(fonte) and not fonte.encerrado:
		fonte.receber_dano(quantidade)


func alvo_compartilhado() -> Object:
	return fonte
