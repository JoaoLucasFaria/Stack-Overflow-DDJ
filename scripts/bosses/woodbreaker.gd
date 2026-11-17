class_name Woodbreaker
extends BossBase

## Boss 2 - prototipo de combate isolado.
## Ataques pesados, telegráficos, para ser enfrentado COM pulo duplo e SEM dash.
const CENA_ONDA: PackedScene = preload("res://cenas/bosses/onda_choque_woodbreaker.tscn")
const CENA_FRAGMENTO: PackedScene = preload("res://cenas/bosses/fragmento_codigo_woodbreaker.tscn")

enum Estado { PERSEGUINDO, AVISANDO, EXECUTANDO, RECUPERANDO }
enum Ataque { MARRETADA, SALTO_ESMAGADOR, INVESTIDA, COMBO, CHUVA_CODIGO }

signal impacto(intensidade: float)

@export_category("Vida e dano")
@export_range(10, 120, 1) var hp_woodbreaker: int = 40
@export_range(1, 5, 1) var dano_golpe: int = 3
@export_range(1, 5, 1) var dano_onda: int = 2
@export_range(1, 5, 1) var dano_fragmento: int = 2
@export_range(1, 5, 1) var dano_contato: int = 1

@export_category("Movimentacao")
@export_range(20.0, 260.0, 5.0) var velocidade_fase_1: float = 110.0
@export_range(20.0, 320.0, 5.0) var velocidade_fase_2: float = 135.0
@export_range(80.0, 450.0, 5.0) var alcance_iniciar_ataque: float = 255.0
@export var limite_esquerdo: float = 100.0
@export var limite_direito: float = 1050.0
@export var linha_do_chao: float = 600.0

@export_category("Ritmo")
@export_range(0.3, 3.0, 0.05) var tempo_aviso_fase_1: float = 0.90
@export_range(0.3, 3.0, 0.05) var tempo_aviso_fase_2: float = 0.67
@export_range(0.3, 3.0, 0.05) var tempo_recuperacao_fase_1: float = 1.10
@export_range(0.3, 3.0, 0.05) var tempo_recuperacao_fase_2: float = 0.75
@export_range(1.0, 4.0, 0.05) var tempo_recuperacao_parede: float = 1.7

@export_category("Ondas de choque")
@export_range(150.0, 850.0, 10.0) var velocidade_onda: float = 425.0
@export_range(0.3, 1.5, 0.05) var intervalo_entre_ondas: float = 0.6

@export_category("Chuva de codigo")
@export_range(2, 6, 1) var fragmentos_fase_1: int = 5
@export_range(3, 7, 1) var fragmentos_fase_2: int = 7
@export_range(300.0, 1100.0, 10.0) var velocidade_fragmento: float = 680.0

var estado: int = Estado.PERSEGUINDO
var ataque_atual: int = Ataque.MARRETADA
var indice_ataque: int = 0
var direcao: int = -1
var temporizador: float = 1.2
var duracao_aviso: float = 1.0
var golpes_restantes: int = 0
var ondas_restantes: int = 0
var tempo_contato: float = 0.0
var tempo_flash: float = 0.0
var tempo_area_golpe: float = 0.0
var texto_estado: String = "APROXIMANDO..."
var ultima_area_golpe: Rect2 = Rect2()
var ameacas: Array[Area2D] = []

@onready var visual: ColorRect = $Visual
@onready var martelo: Node2D = $Martelo
@onready var rotulo: Label = $Rotulo
@onready var area_dano_contato: Area2D = $AreaDanoContato


func _ready() -> void:
	identificador = 2
	nome_exibicao = "WOODBREAKER"
	vida_maxima = hp_woodbreaker
	super._ready()
	global_position.y = linha_do_chao
	_atualizar_visual()


func _physics_process(delta: float) -> void:
	if encerrado or not is_instance_valid(jogador):
		return
	if jogador.vida_atual <= 0:
		return
	if _processar_interrupcao(delta):
		return
	delta = _tempo_com_lentidao(delta)

	temporizador -= delta
	tempo_contato = maxf(0.0, tempo_contato - delta)
	tempo_flash = maxf(0.0, tempo_flash - delta)
	tempo_area_golpe = maxf(0.0, tempo_area_golpe - delta)

	match estado:
		Estado.PERSEGUINDO:
			global_position.y = linha_do_chao
			var distancia_x: float = jogador.global_position.x + 20.0 - global_position.x
			if absf(distancia_x) > 120.0:
				direcao = 1 if distancia_x > 0.0 else -1
				var velocidade: float = velocidade_fase_1 if fase_atual == 1 else velocidade_fase_2
				global_position.x += float(direcao) * velocidade * delta
				global_position.x = clampf(global_position.x, limite_esquerdo, limite_direito)
			if temporizador <= 0.0 and absf(distancia_x) <= alcance_iniciar_ataque:
				_preparar_ataque()
		Estado.AVISANDO:
			if ataque_atual == Ataque.SALTO_ESMAGADOR:
				var progresso: float = clampf(1.0 - temporizador / duracao_aviso, 0.0, 1.0)
				global_position.y = linha_do_chao - 105.0 * sin(progresso * PI)
			if temporizador <= 0.0:
				global_position.y = linha_do_chao
				_executar_ataque()
		Estado.EXECUTANDO:
			_processar_ataque_longo(delta)
		Estado.RECUPERANDO:
			global_position.y = linha_do_chao
			if temporizador <= 0.0:
				estado = Estado.PERSEGUINDO
				temporizador = 0.35 if fase_atual == 1 else 0.22
				texto_estado = "APROXIMANDO..."

	# AreaDanoContato usa a CollisionShape2D do Woodbreaker, sem estimar
	# retangulos por coordenadas. O dano funciona mesmo durante recuperacao.
	# Os i-frames continuam sendo controlados por Jogador.receber_dano().
	if tempo_contato <= 0.0 and area_dano_contato.overlaps_body(jogador):
		jogador.receber_dano(dano_contato, global_position)
		tempo_contato = 0.65

	_atualizar_visual()
	queue_redraw()


func _cancelar_ataque_para_interrupcao() -> void:
	# Interrompe inclusive a sequencia em execucao, sem resetar a fase.
	for ameaca in ameacas:
		if is_instance_valid(ameaca):
			ameaca.queue_free()
	ameacas.clear()
	golpes_restantes = 0
	ondas_restantes = 0
	estado = Estado.PERSEGUINDO
	temporizador = 0.0
	global_position.y = linha_do_chao
	texto_estado = "INTERRUPT() - 1s SEM ATAQUE"


func _preparar_ataque() -> void:
	# Rotacao previsível no protótipo: permite testar todos os cinco golpes.
	ataque_atual = indice_ataque % 5
	indice_ataque += 1
	if ataque_atual == Ataque.INVESTIDA and absf(jogador.global_position.x - global_position.x) < 115.0:
		ataque_atual = Ataque.MARRETADA
	# Travar direção durante o aviso e durante o ataque.
	direcao = 1 if jogador.global_position.x + 20.0 >= global_position.x else -1
	estado = Estado.AVISANDO
	duracao_aviso = tempo_aviso_fase_1 if fase_atual == 1 else tempo_aviso_fase_2
	if ataque_atual == Ataque.CHUVA_CODIGO:
		duracao_aviso = maxf(duracao_aviso, 1.0)
	temporizador = duracao_aviso
	match ataque_atual:
		Ataque.MARRETADA:
			texto_estado = "AVISO: MARRETADA FRONTAL"
		Ataque.SALTO_ESMAGADOR:
			texto_estado = "AVISO: SALTO ESMAGADOR - PULO DUPLO!"
		Ataque.INVESTIDA:
			texto_estado = "AVISO: INVESTIDA!"
		Ataque.COMBO:
			texto_estado = "AVISO: COMBO DE MARRETADAS"
		Ataque.CHUVA_CODIGO:
			texto_estado = "AVISO: CODIGO CORROMPIDO CAINDO!"
			_criar_aviso_fragmentos()


func _executar_ataque() -> void:
	match ataque_atual:
		Ataque.MARRETADA:
			_martelada()
			_iniciar_recuperacao()
		Ataque.SALTO_ESMAGADOR:
			impacto.emit(8.0)
			_lancar_ondas()
			ondas_restantes = 1 if fase_atual == 1 else 2
			estado = Estado.EXECUTANDO
			temporizador = intervalo_entre_ondas
			texto_estado = "ONDAS DE CHOQUE!"
		Ataque.INVESTIDA:
			estado = Estado.EXECUTANDO
			temporizador = 1.45 if fase_atual == 1 else 1.7
			texto_estado = "INVESTIDA PESADA!"
		Ataque.COMBO:
			_martelada()
			golpes_restantes = 1 if fase_atual == 1 else 2
			estado = Estado.EXECUTANDO
			temporizador = 0.62 if fase_atual == 1 else 0.48
			texto_estado = "COMBO: MAIS UMA MARRETADA!"
		Ataque.CHUVA_CODIGO:
			impacto.emit(10.0)
			_iniciar_recuperacao(1.65 if fase_atual == 1 else 1.20)


func _processar_ataque_longo(delta: float) -> void:
	match ataque_atual:
		Ataque.SALTO_ESMAGADOR:
			if temporizador <= 0.0:
				_lancar_ondas()
				ondas_restantes -= 1
				if ondas_restantes <= 0:
					_iniciar_recuperacao()
				else:
					temporizador = intervalo_entre_ondas
		Ataque.INVESTIDA:
			var velocidade_investida: float = 440.0 if fase_atual == 1 else 535.0
			global_position.x += float(direcao) * velocidade_investida * delta
			var acertou_parede: bool = global_position.x <= limite_esquerdo or global_position.x >= limite_direito
			global_position.x = clampf(global_position.x, limite_esquerdo, limite_direito)
			_causar_dano_em_area(Rect2(global_position + Vector2(-60.0, -145.0), Vector2(120.0, 145.0)), dano_golpe)
			if acertou_parede:
				impacto.emit(12.0)
				texto_estado = "ATORDOADO NA PAREDE!"
				_iniciar_recuperacao(tempo_recuperacao_parede)
			elif temporizador <= 0.0:
				_iniciar_recuperacao()
		Ataque.COMBO:
			if temporizador <= 0.0:
				_martelada()
				golpes_restantes -= 1
				if golpes_restantes <= 0:
					_iniciar_recuperacao()
				else:
					temporizador = 0.62 if fase_atual == 1 else 0.48


func _martelada() -> void:
	var centro_x: float = global_position.x + float(direcao) * 126.0
	var area: Rect2 = Rect2(Vector2(centro_x - 80.0, linha_do_chao - 105.0), Vector2(160.0, 105.0))
	ultima_area_golpe = area
	tempo_area_golpe = 0.22
	_causar_dano_em_area(area, dano_golpe)
	impacto.emit(5.0)


func _causar_dano_em_area(area: Rect2, dano: int) -> void:
	if not is_instance_valid(jogador):
		return
	var corpo: Rect2 = Rect2(jogador.global_position, Vector2(40.0, 40.0))
	if area.intersects(corpo):
		jogador.receber_dano(dano, global_position)


func _lancar_ondas() -> void:
	for lado in [-1, 1]:
		var onda: Area2D = CENA_ONDA.instantiate() as Area2D
		get_parent().add_child(onda)
		onda.global_position = Vector2(global_position.x + float(lado) * 67.0, linha_do_chao - 29.0)
		onda.call("configurar", lado, velocidade_onda + (45.0 if fase_atual == 2 else 0.0), dano_onda)
		ameacas.append(onda)


func _criar_aviso_fragmentos() -> void:
	# Duas faixas seguras vizinhas perto do jogador. Os outros fragmentos
	# sao sorteados sem repeticao, para a chuva ser justa SEM dash.
	var faixas: Array[float] = [140.0, 286.0, 432.0, 578.0, 724.0, 870.0, 1016.0]
	var indice_seguro: int = 0
	var melhor_distancia: float = INF
	for i in range(faixas.size()):
		var distancia: float = absf(faixas[i] - jogador.global_position.x - 20.0)
		if distancia < melhor_distancia:
			melhor_distancia = distancia
			indice_seguro = i
	var outro_seguro: int = indice_seguro + 1 if indice_seguro < faixas.size() - 1 else indice_seguro - 1
	var candidatas: Array[float] = []
	for i in range(faixas.size()):
		if i != indice_seguro and i != outro_seguro:
			candidatas.append(faixas[i])
	candidatas.shuffle()
	var quantidade: int = mini(fragmentos_fase_1 if fase_atual == 1 else fragmentos_fase_2, candidatas.size())
	for i in range(quantidade):
		var fragmento: Area2D = CENA_FRAGMENTO.instantiate() as Area2D
		# Configurar ANTES do add_child: _ready() cria a marca na posicao correta.
		fragmento.call("configurar", candidatas[i], linha_do_chao, duracao_aviso, velocidade_fragmento + (90.0 if fase_atual == 2 else 0.0), dano_fragmento)
		get_parent().add_child(fragmento)
		ameacas.append(fragmento)


func _iniciar_recuperacao(duracao_personalizada: float = -1.0) -> void:
	estado = Estado.RECUPERANDO
	global_position.y = linha_do_chao
	temporizador = duracao_personalizada if duracao_personalizada > 0.0 else (tempo_recuperacao_fase_1 if fase_atual == 1 else tempo_recuperacao_fase_2)
	if not texto_estado.begins_with("ATORDOADO"):
		texto_estado = "RECUPERANDO... ATAQUE AGORA!"


func _ao_receber_dano(_quantidade: int) -> void:
	tempo_flash = 0.12


func _ao_segunda_fase() -> void:
	texto_estado = "FASE 2: OVERCLOCK!"
	impacto.emit(13.0)


func _ao_derrota() -> void:
	for perigo in ameacas:
		if is_instance_valid(perigo):
			perigo.queue_free()
	ameacas.clear()
	impacto.emit(8.0)


func _atualizar_visual() -> void:
	if visual == null:
		return
	visual.color = Color(0.98, 0.48, 0.32) if tempo_flash > 0.0 else (Color(0.67, 0.30, 0.25) if fase_atual == 2 else Color(0.44, 0.35, 0.41))
	martelo.scale.x = float(direcao)
	rotulo.text = "WOODBREAKER | %d/%d HP | FASE %d" % [vida_atual, vida_maxima, fase_atual]


func _draw() -> void:
	if estado == Estado.AVISANDO and ataque_atual != Ataque.CHUVA_CODIGO:
		if ataque_atual == Ataque.MARRETADA or ataque_atual == Ataque.COMBO:
			var x: float = 46.0 if direcao > 0 else -205.0
			draw_rect(Rect2(x, -105.0, 160.0, 105.0), Color(1.0, 0.18, 0.13, 0.33), true)
		elif ataque_atual == Ataque.INVESTIDA:
			var x: float = 60.0 if direcao > 0 else -460.0
			draw_rect(Rect2(x, -88.0, 400.0, 88.0), Color(1.0, 0.18, 0.13, 0.22), true)
		elif ataque_atual == Ataque.SALTO_ESMAGADOR:
			draw_rect(Rect2(-75.0, -12.0, 150.0, 12.0), Color(1.0, 0.68, 0.15, 0.8), true)
	if estado == Estado.EXECUTANDO and ataque_atual == Ataque.COMBO and temporizador < 0.24:
		var x_combo: float = 46.0 if direcao > 0 else -205.0
		draw_rect(Rect2(x_combo, -105.0, 160.0, 105.0), Color(1.0, 0.18, 0.13, 0.33), true)
	if tempo_area_golpe > 0.0:
		draw_rect(Rect2(ultima_area_golpe.position - global_position, ultima_area_golpe.size), Color(1.0, 0.70, 0.18, 0.45), true)
