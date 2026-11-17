class_name Stonemaker
extends BossBase

## Boss 3: duelista de lança. Protótipo isolado para testar a luta antes
## de integrar à campanha. Pulo duplo + dash SIM, grapple NÃO.
const CENA_LANCA: PackedScene = preload("res://cenas/bosses/lanca_energia_stonemaker.tscn")

enum Estado { PERSEGUINDO, AVISANDO, EXECUTANDO, RECUPERANDO, ATORDOADO }
enum Ataque { ESTOCADA, DANCA_LAMINAS, INVESTIDA, CACADA_AEREA, LANCA_RETORNANTE, QUEDA_CELESTIAL, CORTE_CRUZADO, FINTA }

signal impacto(intensidade: float)
signal dash_clash

@export_category("Vida e dano")
@export_range(15, 150, 1) var hp_stonemaker: int = 43
@export_range(1, 5, 1) var dano_comum: int = 1
@export_range(1, 5, 1) var dano_pesado: int = 3
@export_range(1, 5, 1) var dano_contato: int = 1

@export_category("Movimentacao")
@export var velocidade_fase_1: float = 200.0
@export var velocidade_fase_2: float = 275.0
@export var velocidade_fase_3: float = 320.0
@export var velocidade_investida_fase_1: float = 680.0
@export var velocidade_investida_fase_2: float = 820.0
@export var velocidade_investida_fase_3: float = 875.0
@export var limite_esquerdo: float = 85.0
@export var limite_direito: float = 1065.0
@export var linha_do_chao: float = 600.0

@export_category("Ritmo")
@export_range(0.2, 1.5, 0.05) var aviso_fase_1: float = 0.58
@export_range(0.2, 1.5, 0.05) var aviso_fase_2: float = 0.47
@export_range(0.2, 1.5, 0.05) var aviso_fase_3: float = 0.4
@export_range(0.1, 2.0, 0.05) var recuperacao_fase_1: float = 0.8
@export_range(0.1, 2.0, 0.05) var recuperacao_fase_2: float = 0.57
@export_range(0.1, 2.0, 0.05) var recuperacao_fase_3: float = 0.43
@export_range(0.5, 2.0, 0.05) var atordoamento_dash_clash: float = 4.0
@export_range(0.1, 0.9, 0.05) var limiar_terceira_fase: float = 0.30

var estado: int = Estado.PERSEGUINDO
var ataque_atual: int = Ataque.ESTOCADA
var ultimo_ataque: int = -1
var direcao: int = -1
var temporizador: float = 1.15
var duracao_aviso: float = 0.58
var tempo_contato: float = 0.0
var tempo_flash: float = 0.0
var tempo_hit_visual: float = 0.0
var area_hit_visual: Rect2 = Rect2()
var texto_estado: String = "OBSERVANDO O ALVO..."
var ataques_restantes_na_sequencia: int = 0
var etapa_ataque: int = 0
var progresso_movimento: float = 0.0
var duracao_movimento: float = 0.48
var origem_movimento: Vector2 = Vector2.ZERO
var destino_movimento: Vector2 = Vector2.ZERO
var alvo_x_travado: float = 0.0
var cooldown_golpe_movimento: float = 0.0
var ameacas: Array[Area2D] = []

@onready var corpo_visual: ColorRect = $CorpoVisual
@onready var arma_visual: Node2D = $Lanca
@onready var rotulo: Label = $Rotulo
@onready var area_dano_contato: Area2D = $AreaDanoContato


func _ready() -> void:
	identificador = 3
	nome_exibicao = "STONEMAKER"
	vida_maxima = hp_stonemaker
	limiar_segunda_fase = 0.65
	super._ready()
	global_position.y = linha_do_chao
	_atualizar_visual()


func _physics_process(delta: float) -> void:
	if encerrado or not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	if _processar_interrupcao(delta):
		return
	delta = _tempo_com_lentidao(delta)
	temporizador -= delta
	tempo_contato = maxf(0.0, tempo_contato - delta)
	tempo_flash = maxf(0.0, tempo_flash - delta)
	tempo_hit_visual = maxf(0.0, tempo_hit_visual - delta)
	cooldown_golpe_movimento = maxf(0.0, cooldown_golpe_movimento - delta)

	match estado:
		Estado.PERSEGUINDO:
			_perseguir(delta)
		Estado.AVISANDO:
			if temporizador <= 0.0:
				_executar_ataque()
		Estado.EXECUTANDO:
			_processar_ataque(delta)
		Estado.RECUPERANDO:
			if temporizador <= 0.0:
				estado = Estado.PERSEGUINDO
				temporizador = 0.17 if fase_atual == 3 else 0.28
				texto_estado = "PERSEGUINDO..."
		Estado.ATORDOADO:
			if temporizador <= 0.0:
				_iniciar_recuperacao(0.30)

	# O corpo é atravessável, mas possui uma Area2D própria para dano de contato.
	# O Jogador controla os seus i-frames, inclusive durante o dash.
	if estado != Estado.ATORDOADO and tempo_contato <= 0.0 and area_dano_contato.overlaps_body(jogador):
		jogador.receber_dano(dano_contato, global_position)
		tempo_contato = 0.60

	_atualizar_visual()
	queue_redraw()


func _cancelar_ataque_para_interrupcao() -> void:
	for ameaca in ameacas:
		if is_instance_valid(ameaca):
			ameaca.queue_free()
	ameacas.clear()
	ataques_restantes_na_sequencia = 0
	estado = Estado.PERSEGUINDO
	temporizador = 0.0
	global_position.y = linha_do_chao
	global_position.x = clampf(global_position.x, limite_esquerdo, limite_direito)
	texto_estado = "INTERRUPT() - 1s SEM ATAQUE"


func _perseguir(delta: float) -> void:
	global_position.y = linha_do_chao
	var dist_x: float = jogador.global_position.x + 20.0 - global_position.x
	if absf(dist_x) > 118.0:
		direcao = 1 if dist_x > 0.0 else -1
		var velocidade: float = velocidade_fase_1
		if fase_atual == 2:
			velocidade = velocidade_fase_2
		elif fase_atual == 3:
			velocidade = velocidade_fase_3
		global_position.x = clampf(global_position.x + float(direcao) * velocidade * delta, limite_esquerdo, limite_direito)
	if temporizador <= 0.0:
		ataques_restantes_na_sequencia = fase_atual
		_preparar_ataque()


func _escolher_ataque() -> int:
	var distancia: float = absf(jogador.global_position.x + 20.0 - global_position.x)
	var jogador_alto: bool = jogador.global_position.y < linha_do_chao - 145.0
	var candidatos: Array[int] = []
	if distancia > 390.0:
		candidatos = [Ataque.INVESTIDA, Ataque.CACADA_AEREA, Ataque.LANCA_RETORNANTE, Ataque.CORTE_CRUZADO]
	elif distancia < 170.0:
		candidatos = [Ataque.ESTOCADA, Ataque.DANCA_LAMINAS, Ataque.FINTA, Ataque.QUEDA_CELESTIAL]
	else:
		candidatos = [Ataque.ESTOCADA, Ataque.DANCA_LAMINAS, Ataque.INVESTIDA, Ataque.CACADA_AEREA, Ataque.LANCA_RETORNANTE, Ataque.QUEDA_CELESTIAL, Ataque.CORTE_CRUZADO, Ataque.FINTA]
	if jogador_alto:
		candidatos.append(Ataque.CACADA_AEREA)
		candidatos.append(Ataque.QUEDA_CELESTIAL)
	candidatos.erase(ultimo_ataque)
	if candidatos.is_empty():
		return Ataque.ESTOCADA
	return candidatos[randi_range(0, candidatos.size() - 1)]


func _preparar_ataque(encadeado: bool = false) -> void:
	ataque_atual = _escolher_ataque()
	ultimo_ataque = ataque_atual
	direcao = 1 if jogador.global_position.x + 20.0 >= global_position.x else -1
	estado = Estado.AVISANDO
	duracao_aviso = aviso_fase_1
	if fase_atual == 2:
		duracao_aviso = aviso_fase_2
	elif fase_atual == 3:
		duracao_aviso = aviso_fase_3
	if encadeado:
		duracao_aviso *= 0.88
	if ataque_atual == Ataque.FINTA:
		duracao_aviso = maxf(duracao_aviso, 0.55)
	if ataque_atual == Ataque.CORTE_CRUZADO:
		duracao_aviso = maxf(duracao_aviso, 0.45)
	if ataque_atual == Ataque.LANCA_RETORNANTE:
		duracao_aviso = maxf(duracao_aviso, 1.0)
	temporizador = duracao_aviso
	etapa_ataque = 0
	match ataque_atual:
		Ataque.ESTOCADA:
			texto_estado = "AVISO: ESTOCADA RELAMPAGO"
		Ataque.DANCA_LAMINAS:
			texto_estado = "AVISO: DANCA DAS LAMINAS"
		Ataque.INVESTIDA:
			texto_estado = "AVISO: INVESTIDA | DASH CLASH!"
		Ataque.CACADA_AEREA:
			texto_estado = "AVISO: CACADA AEREA"
		Ataque.LANCA_RETORNANTE:
			texto_estado = "AVISO: LANCA RETORNANTE"
		Ataque.QUEDA_CELESTIAL:
			texto_estado = "AVISO: QUEDA CELESTIAL"
		Ataque.CORTE_CRUZADO:
			texto_estado = "AVISO: CORTE CRUZADO"
		Ataque.FINTA:
			texto_estado = "FINTA: POSTURA DIFERENTE!"
	if ataque_atual == Ataque.QUEDA_CELESTIAL:
		alvo_x_travado = clampf(jogador.global_position.x + 20.0, limite_esquerdo, limite_direito)


func _executar_ataque() -> void:
	estado = Estado.EXECUTANDO
	match ataque_atual:
		Ataque.ESTOCADA:
			_estocada(false)
			_finalizar_ataque()
		Ataque.DANCA_LAMINAS:
			_danca_passo()
			etapa_ataque = 1
			temporizador = 0.28 if fase_atual == 1 else 0.23
		Ataque.INVESTIDA:
			temporizador = 0.72
			texto_estado = "INVESTIDA! INTERCEPTE COM DASH!"
		Ataque.CACADA_AEREA:
			global_position = Vector2(limite_esquerdo if direcao > 0 else limite_direito, 168.0)
			origem_movimento = global_position
			destino_movimento = Vector2(clampf(jogador.global_position.x + 20.0, limite_esquerdo, limite_direito), linha_do_chao)
			progresso_movimento = 0.0
			duracao_movimento = 0.55 if fase_atual == 1 else 0.44
			texto_estado = "CACADA AEREA!"
		Ataque.LANCA_RETORNANTE:
			_arremessar_lanca()
			temporizador = 0.27
			texto_estado = "LANCA: CUIDADO COM A VOLTA!"
		Ataque.QUEDA_CELESTIAL:
			global_position = Vector2(alvo_x_travado, 105.0)
			origem_movimento = global_position
			destino_movimento = Vector2(alvo_x_travado, linha_do_chao)
			progresso_movimento = 0.0
			duracao_movimento = 0.43 if fase_atual == 1 else 0.34
			texto_estado = "QUEDA CELESTIAL!"
		Ataque.CORTE_CRUZADO:
			_preparar_corte_cruzado(0)
			texto_estado = "CORTE CRUZADO!"
		Ataque.FINTA:
			temporizador = 0.43
			texto_estado = "ABERTURA? CUIDADO COM A FINTA!"


func _processar_ataque(delta: float) -> void:
	match ataque_atual:
		Ataque.DANCA_LAMINAS:
			if temporizador <= 0.0:
				_danca_passo()
				etapa_ataque += 1
				if etapa_ataque >= 3:
					_finalizar_ataque()
				else:
					temporizador = 0.28 if fase_atual == 1 else 0.23
		Ataque.INVESTIDA:
			var velocidade: float = velocidade_investida_fase_1
			if fase_atual == 2:
				velocidade = velocidade_investida_fase_2
			elif fase_atual == 3:
				velocidade = velocidade_investida_fase_3
			global_position.x += float(direcao) * velocidade * delta
			if _tentar_dash_clash():
				return
			_dano_em_movimento(dano_pesado)
			var encontrou_parede: bool = global_position.x <= limite_esquerdo or global_position.x >= limite_direito
			global_position.x = clampf(global_position.x, limite_esquerdo, limite_direito)
			if encontrou_parede or temporizador <= 0.0:
				_finalizar_ataque()
		Ataque.CACADA_AEREA, Ataque.QUEDA_CELESTIAL:
			progresso_movimento = minf(1.0, progresso_movimento + delta / duracao_movimento)
			global_position = origem_movimento.lerp(destino_movimento, progresso_movimento)
			_dano_em_movimento(dano_pesado)
			if progresso_movimento >= 1.0:
				impacto.emit(6.0 if ataque_atual == Ataque.QUEDA_CELESTIAL else 3.0)
				_finalizar_ataque()
		Ataque.LANCA_RETORNANTE:
			if temporizador <= 0.0:
				_finalizar_ataque()
		Ataque.CORTE_CRUZADO:
			progresso_movimento = minf(1.0, progresso_movimento + delta / duracao_movimento)
			global_position = origem_movimento.lerp(destino_movimento, progresso_movimento)
			_dano_em_movimento(dano_pesado)
			if progresso_movimento >= 1.0:
				if etapa_ataque == 0:
					_preparar_corte_cruzado(1)
				else:
					_finalizar_ataque()
		Ataque.FINTA:
			if temporizador <= 0.0:
				if jogador.global_position.distance_to(global_position) < 185.0:
					texto_estado = "CONTRAESTOCADA!"
					_estocada(true)
				_finalizar_ataque()


func _danca_passo() -> void:
	var area: Rect2
	match etapa_ataque:
		0:
			area = Rect2(global_position + Vector2(35.0 if direcao > 0 else -189.0, -92.0), Vector2(154.0, 77.0))
			texto_estado = "DANCA: ESTOCADA!"
		1:
			area = Rect2(global_position + Vector2(-56.0, -197.0), Vector2(112.0, 190.0))
			texto_estado = "DANCA: CORTE ASCENDENTE!"
		_:
			area = Rect2(global_position + Vector2(8.0 if direcao > 0 else -160.0, -168.0), Vector2(152.0, 168.0))
			texto_estado = "DANCA: FINALIZACAO!"
	_causar_dano_em_area(area, dano_comum)


func _estocada(pesada: bool) -> void:
	var inicio_x: float = 36.0 if direcao > 0 else -218.0
	var area: Rect2 = Rect2(global_position + Vector2(inicio_x, -99.0), Vector2(182.0, 75.0))
	_causar_dano_em_area(area, dano_pesado if pesada else dano_comum)


func _arremessar_lanca() -> void:
	var lanca: Area2D = CENA_LANCA.instantiate() as Area2D
	lanca.call("configurar", self, direcao, dano_comum, 730.0 if fase_atual == 1 else 880.0)
	var pai: Node2D = get_parent() as Node2D
	var altura_alvo: float = jogador.global_position.y + 20.0
	altura_alvo = clampf(altura_alvo, 42.0, linha_do_chao - 18.0)
	lanca.position = pai.to_local(
		Vector2(global_position.x + float(direcao) * 57.0, altura_alvo))
	lanca.scale.x = float(direcao)
	pai.add_child(lanca)
	ameacas.append(lanca)

func _preparar_corte_cruzado(etapa: int) -> void:
	etapa_ataque = etapa
	origem_movimento = Vector2(limite_esquerdo if etapa == 0 else limite_direito, 150.0)
	destino_movimento = Vector2(limite_direito if etapa == 0 else limite_esquerdo, 550.0)
	global_position = origem_movimento
	direcao = 1 if etapa == 0 else -1
	progresso_movimento = 0.0
	duracao_movimento = 0.58 if fase_atual == 1 else (0.46 if fase_atual == 2 else 0.37)


func _tentar_dash_clash() -> bool:
	if not jogador.dash_component.esta_dashing:
		return false
	if jogador.dash_component.direcao_dash != -direcao:
		return false
	var delta_x: float = jogador.global_position.x + 20.0 - global_position.x
	var delta_y: float = jogador.global_position.y + 20.0 - (global_position.y - 47.0)
	if absf(delta_x) > 83.0 or absf(delta_y) > 65.0:
		return false
	# Impede um clash ao atingir as costas do chefe.
	if delta_x * float(direcao) < -18.0:
		return false
	estado = Estado.ATORDOADO
	ataques_restantes_na_sequencia = 0
	temporizador = atordoamento_dash_clash
	global_position.y = linha_do_chao
	texto_estado = "DASH CLASH PERFEITO! ATAQUE!"
	impacto.emit(9.0)
	dash_clash.emit()
	return true


func _dano_em_movimento(dano: int) -> void:
	if cooldown_golpe_movimento > 0.0:
		return
	var area: Rect2 = Rect2(global_position + Vector2(-40.0, -112.0), Vector2(80.0, 112.0))
	var corpo: Rect2 = Rect2(jogador.global_position, Vector2(40.0, 40.0))
	if area.intersects(corpo):
		jogador.receber_dano(dano, global_position)
		cooldown_golpe_movimento = 0.55


func _causar_dano_em_area(area: Rect2, dano: int) -> void:
	area_hit_visual = area
	tempo_hit_visual = 0.18
	var corpo: Rect2 = Rect2(jogador.global_position, Vector2(40.0, 40.0))
	if area.intersects(corpo):
		jogador.receber_dano(dano, global_position)


func _finalizar_ataque() -> void:
	global_position.y = linha_do_chao
	global_position.x = clampf(global_position.x, limite_esquerdo, limite_direito)
	ataques_restantes_na_sequencia -= 1
	if ataques_restantes_na_sequencia > 0:
		_preparar_ataque(true)
	else:
		_iniciar_recuperacao()


func _iniciar_recuperacao(tempo_especial: float = -1.0) -> void:
	estado = Estado.RECUPERANDO
	global_position.y = linha_do_chao
	var t: float = recuperacao_fase_1
	if fase_atual == 2:
		t = recuperacao_fase_2
	elif fase_atual == 3:
		t = recuperacao_fase_3
	temporizador = tempo_especial if tempo_especial >= 0.0 else t
	texto_estado = "ABERTURA: ATAQUE AGORA!"


func _ao_receber_dano(_quantidade: int) -> void:
	tempo_flash = 0.12
	if fase_atual < 3 and vida_atual > 0 and float(vida_atual) <= float(vida_maxima) * limiar_terceira_fase:
		fase_atual = 3
		bloquear_interrupt_na_transicao(0.9)
		texto_estado = "FASE 3: SOBRECARGA CRITICA!"
		impacto.emit(11.0)
		fase_alterada.emit(3)


func _ao_segunda_fase() -> void:
	texto_estado = "FASE 2: EXECUCAO PERFEITA!"
	impacto.emit(8.0)


func _ao_derrota() -> void:
	for ameaca in ameacas:
		if is_instance_valid(ameaca):
			ameaca.queue_free()
	ameacas.clear()
	impacto.emit(8.0)


func _atualizar_visual() -> void:
	if corpo_visual == null:
		return
	if tempo_flash > 0.0:
		corpo_visual.color = Color(1.0, 0.86, 0.80)
	elif fase_atual == 1:
		corpo_visual.color = Color(0.64, 0.55, 0.30)
	elif fase_atual == 2:
		corpo_visual.color = Color(0.76, 0.47, 0.25)
	else:
		corpo_visual.color = Color(0.78, 0.27, 0.49)
	arma_visual.scale.x = float(direcao)
	rotulo.text = "STONEMAKER | %d/%d | FASE %d" % [vida_atual, vida_maxima, fase_atual]


func _draw() -> void:
	if estado == Estado.AVISANDO:
		var cor_aviso: Color = Color(1.0, 0.21, 0.16, 0.32)
		match ataque_atual:
			Ataque.ESTOCADA, Ataque.DANCA_LAMINAS, Ataque.FINTA:
				var x: float = 35.0 if direcao > 0 else -218.0
				draw_rect(Rect2(x, -112.0, 183.0, 108.0), Color(0.96, 0.41, 0.22, 0.28) if ataque_atual == Ataque.FINTA else cor_aviso, true)
			Ataque.INVESTIDA:
				var borda: float = limite_direito - global_position.x if direcao > 0 else global_position.x - limite_esquerdo
				var inicio_x: float = 0.0 if direcao > 0 else -borda
				draw_rect(Rect2(inicio_x, -100.0, borda, 100.0), Color(1.0, 0.80, 0.20, 0.26), true)
			Ataque.CACADA_AEREA:
				var origem_aviso: Vector2 = Vector2(limite_esquerdo if direcao > 0 else limite_direito, 168.0) - global_position
				var destino_aviso: Vector2 = Vector2(clampf(jogador.global_position.x + 20.0, limite_esquerdo, limite_direito), linha_do_chao) - global_position
				draw_line(origem_aviso, destino_aviso, Color(1.0, 0.28, 0.18, 0.48), 9.0)
			Ataque.LANCA_RETORNANTE:
				var altura_alvo: float = jogador.global_position.y + 20.0
				altura_alvo = clampf(altura_alvo, 42.0, linha_do_chao - 18.0)
				var altura_local: float = altura_alvo - global_position.y
				draw_rect(
				Rect2(-510.0, altura_local - 13.0, 1020.0, 26.0),
				Color(0.32, 0.86, 1.0, 0.20),
				true
				)
			Ataque.QUEDA_CELESTIAL:
				var centro: float = alvo_x_travado - global_position.x
				draw_rect(Rect2(centro - 42.0, -530.0, 84.0, 530.0), Color(1.0, 0.35, 0.12, 0.20), true)
			Ataque.CORTE_CRUZADO:
				draw_line(Vector2(limite_esquerdo, 140.0) - global_position, Vector2(limite_direito, 550.0) - global_position, Color(1.0, 0.19, 0.32, 0.45), 13.0)
				draw_line(Vector2(limite_direito, 140.0) - global_position, Vector2(limite_esquerdo, 550.0) - global_position, Color(1.0, 0.19, 0.32, 0.45), 13.0)
	if estado == Estado.ATORDOADO:
		draw_arc(Vector2(0.0, -124.0), 37.0, 0.0, TAU, 22, Color(0.45, 1.0, 0.63, 0.84), 5.0)
	if tempo_hit_visual > 0.0:
		draw_rect(Rect2(area_hit_visual.position - global_position, area_hit_visual.size), Color(1.0, 0.78, 0.16, 0.42), true)
