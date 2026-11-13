class_name GuardiaoBoss1
extends BossBase

## Boss 1: torreta corrompida presa na parede interna do poco.
## O nucleo exige 3 escaladas; cada golpe derruba o jogador.
## Ao abrir o escudo, o jogador escala de novo para acertar o corpo.
const CENA_PROJETIL: PackedScene = preload("res://cenas/bosses/projetil_boss_1.tscn")

enum Estado { ESPERA, AVISO, RECUPERACAO, EXPOSTO, IMPACTO }
enum Ataque { RAJADA_DIRECIONADA, CORTINA_NO_POCO, LASER_RASTEIRO }

@export_category("Escudo e fase")
@export_range(2.0, 20.0, 0.5) var segundos_escudo_aberto: float = 11.0
@export_range(1, 6, 1) var golpes_nucleo_para_abrir: int = 3
@export_range(0.3, 3.0, 0.05) var segundos_impacto: float = 1.35
@export_range(0.2, 3.0, 0.05) var aviso_ataque: float = 0.72
@export_range(0.2, 3.0, 0.05) var recuperacao_ataque: float = 0.82
@export_range(1, 10, 1) var dano_ataques: int = 1

@export_category("Bullet hell")
@export_range(0.4, 5.0, 0.05) var intervalo_rajada_ambiente_fase_1: float = 2.75
@export_range(0.4, 5.0, 0.05) var intervalo_rajada_ambiente_fase_2: float = 1.90
@export_range(1, 8, 1) var tiros_ambiente_fase_1: int = 1
@export_range(1, 8, 1) var tiros_ambiente_fase_2: int = 1
@export_range(1, 9, 1) var tiros_rajada_fase_1: int = 2
@export_range(1, 9, 1) var tiros_rajada_fase_2: int = 3

@export_category("Laser rasteiro")
## Coordenadas globais da arena de teste (1152x648). O laser nao depende
## da posicao manual do chefe: mover o boss nao altera este ataque.
@export_range(0.1, 1.5, 0.05) var duracao_laser: float = 0.42
@export_range(10.0, 50.0, 1.0) var altura_laser: float = 28.0
@export var centro_laser: Vector2 = Vector2(576.0, 580.0)
@export_range(100.0, 1152.0, 1.0) var largura_laser: float = 1080.0

signal nucleo_atingido(restantes: int, rompeu_escudo: bool)

var estado: int = Estado.ESPERA
var ataque_preparado: int = Ataque.RAJADA_DIRECIONADA
var temporizador: float = 1.15
var proximo_ataque: int = 0
var tempo_flash: float = 0.0
var mensagem: String = "ESCUDO ATIVO"
var golpes_nucleo_restantes: int = 3
var tempo_rajada_ambiente: float = 1.1
var numero_rajada_ambiente: int = 0
var tiros_agendados: Array[Dictionary] = []
var projeteis_ativos: Array[Area2D] = []
var laser_area: Area2D
var laser_visual: ColorRect
var tempo_laser_ativo: float = 0.0

@onready var visual: ColorRect = $Visual
@onready var rotulo: Label = $Rotulo
@onready var nucleo: StaticBody2D = $Nucleo
@onready var nucleo_visual: ColorRect = $Nucleo/Visual
@onready var nucleo_indicacao: Label = $Nucleo/Indicacao


func _ready() -> void:
	super._ready()
	_criar_laser_rasteiro()
	golpes_nucleo_restantes = golpes_nucleo_para_abrir
	_atualizar_cores()
	_atualizar_rotulo()


func _physics_process(delta: float) -> void:
	if encerrado or not is_instance_valid(jogador):
		return

	tempo_flash = maxf(0.0, tempo_flash - delta)
	_atualizar_laser_rasteiro(delta)

	# Nao atiramos enquanto o jogo obriga o jogador a cair e nem durante
	# a janela aberta do escudo. As torretas menores seguem independentes.
	if estado != Estado.IMPACTO and estado != Estado.EXPOSTO:
		tempo_rajada_ambiente -= delta
		if tempo_rajada_ambiente <= 0.0:
			_disparar_rajada_ambiente()
			tempo_rajada_ambiente = intervalo_rajada_ambiente_fase_1 if fase_atual == 1 else intervalo_rajada_ambiente_fase_2
		_processar_tiros_agendados(delta)

	temporizador -= delta
	if temporizador <= 0.0:
		match estado:
			Estado.ESPERA:
				_preparar_ataque()
			Estado.AVISO:
				_executar_ataque()
			Estado.RECUPERACAO:
				estado = Estado.ESPERA
				temporizador = 0.35 if fase_atual == 1 else 0.20
				mensagem = "ESCUDO ATIVO"
			Estado.EXPOSTO:
				_rearmar_escudo()
			Estado.IMPACTO:
				_finalizar_impacto()

	# Mantem somente referencias vivas: evita acumular projeteis expirados.
	if projeteis_ativos.size() > 64:
		var vivos: Array[Area2D] = []
		for projetil in projeteis_ativos:
			if is_instance_valid(projetil) and not projetil.is_queued_for_deletion():
				vivos.append(projetil)
		projeteis_ativos = vivos

	_atualizar_cores()
	_atualizar_rotulo()
	queue_redraw()


func _esta_vulneravel() -> bool:
	return estado == Estado.EXPOSTO


func atingir_nucleo() -> void:
	if encerrado or estado == Estado.EXPOSTO or estado == Estado.IMPACTO:
		return
	golpes_nucleo_restantes = maxi(0, golpes_nucleo_restantes - 1)
	estado = Estado.IMPACTO
	temporizador = segundos_impacto
	tiros_agendados.clear()
	_limpar_projeteis()
	_parar_laser_rasteiro()
	nucleo.collision_layer = 0
	var rompeu: bool = golpes_nucleo_restantes == 0
	mensagem = "IMPACTO! NUCLEO %d/%d" % [golpes_nucleo_para_abrir - golpes_nucleo_restantes, golpes_nucleo_para_abrir]
	_atualizar_cores()
	_atualizar_rotulo()
	nucleo_atingido.emit(golpes_nucleo_restantes, rompeu)


func _finalizar_impacto() -> void:
	if golpes_nucleo_restantes == 0:
		estado = Estado.EXPOSTO
		temporizador = segundos_escudo_aberto
		mensagem = "ESCUDO CAIU! ESCALE E ATAQUE A TORRE!"
		nucleo.collision_layer = 0
	else:
		estado = Estado.ESPERA
		temporizador = 0.9
		nucleo.collision_layer = 2
		mensagem = "CAMADAS RESTANTES: %d - ESCALE!" % golpes_nucleo_restantes
	# Deixa espaco para o jogador recomecar a escalada.
	tempo_rajada_ambiente = 1.8 if fase_atual == 1 else 1.3


func _rearmar_escudo() -> void:
	estado = Estado.ESPERA
	temporizador = 1.0
	golpes_nucleo_restantes = golpes_nucleo_para_abrir
	nucleo.collision_layer = 2
	mensagem = "ESCUDO RESTAURADO - ESCALE!"


func _preparar_ataque() -> void:
	ataque_preparado = proximo_ataque % 3
	proximo_ataque += 1
	estado = Estado.AVISO
	temporizador = aviso_ataque if fase_atual == 1 else aviso_ataque * 0.8
	match ataque_preparado:
		Ataque.RAJADA_DIRECIONADA:
			mensagem = "AVISO: RAJADA DIRECIONADA"
		Ataque.CORTINA_NO_POCO:
			mensagem = "AVISO: CORTINA NO POCO"
		Ataque.LASER_RASTEIRO:
			mensagem = "AVISO: LASER NO CHAO - PULE!"


func _executar_ataque() -> void:
	match ataque_preparado:
		Ataque.RAJADA_DIRECIONADA:
			_atirar_no_jogador()
		Ataque.CORTINA_NO_POCO:
			_agendar_cortina()
		Ataque.LASER_RASTEIRO:
			_ativar_laser_rasteiro()
	estado = Estado.RECUPERACAO
	temporizador = recuperacao_ataque if fase_atual == 1 else recuperacao_ataque * 0.7
	mensagem = "RECUPERANDO..."


func _criar_projetil(origem: Vector2, direcao: Vector2, velocidade: float, escala: Vector2, cor: Color) -> void:
	if not is_inside_tree() or direcao.length_squared() < 0.001:
		return
	var tiro: Area2D = CENA_PROJETIL.instantiate() as Area2D
	get_parent().add_child(tiro)
	projeteis_ativos.append(tiro)
	tiro.global_position = origem
	tiro.call("configurar", direcao, dano_ataques)
	tiro.set("velocidade", velocidade)
	tiro.scale = escala
	var v: ColorRect = tiro.get_node_or_null("Visual") as ColorRect
	if v != null:
		v.color = cor


func _limpar_projeteis() -> void:
	for projetil in projeteis_ativos:
		if is_instance_valid(projetil):
			projetil.queue_free()
	projeteis_ativos.clear()


func _atirar_no_jogador() -> void:
	# Projetil do boss ignora as paredes e mira no centro do jogador.
	var origem: Vector2 = global_position + Vector2(-57.0, -3.0)
	var alvo: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
	var direcao: Vector2 = (alvo - origem).normalized()
	var quantidade: int = tiros_rajada_fase_1 if fase_atual == 1 else tiros_rajada_fase_2
	for i in range(quantidade):
		var desvio: float = (float(i) - (float(quantidade) - 1.0) * 0.5) * 0.19
		_criar_projetil(origem, direcao.rotated(desvio), 300.0 if fase_atual == 1 else 365.0,
			Vector2(1.0, 1.0), Color(1.0, 0.32, 0.39))


func _disparar_rajada_ambiente() -> void:
	# Corredor interno: rajadas de ambos os lados, alturas alternadas.
	# Sao disparos pequenos e espacados para deixar caminho de esquiva.
	var alturas: Array[float] = [185.0, 270.0, 355.0, 440.0, 495.0]
	var quantidade: int = tiros_ambiente_fase_1 if fase_atual == 1 else tiros_ambiente_fase_2
	for i in range(quantidade):
		var indice: int = (numero_rajada_ambiente + i * 2) % alturas.size()
		var lado_direito: bool = (numero_rajada_ambiente + i) % 2 == 0
		var origem: Vector2 = Vector2(582.0 if lado_direito else 436.0, alturas[indice])
		var direcao: Vector2 = Vector2(-1.0 if lado_direito else 1.0, 0.0)
		_criar_projetil(origem, direcao, 255.0 if fase_atual == 1 else 315.0,
			Vector2(0.95, 0.95), Color(0.95, 0.45, 0.85))
	numero_rajada_ambiente += 1


func _agendar_cortina() -> void:
	var alturas: Array[float] = [250.0, 405.0]
	if fase_atual == 2:
		alturas = [200.0, 335.0, 470.0]
	for i in range(alturas.size()):
		var vem_da_direita: bool = i % 2 == 0
		tiros_agendados.append({
			"tempo": 0.21 * float(i),
			"origem": Vector2(582.0 if vem_da_direita else 437.0, alturas[i]),
			"direcao": Vector2(-1.0 if vem_da_direita else 1.0, 0.0)
		})


func _processar_tiros_agendados(delta: float) -> void:
	for i in range(tiros_agendados.size() - 1, -1, -1):
		var tiro: Dictionary = tiros_agendados[i]
		tiro["tempo"] = float(tiro["tempo"]) - delta
		if float(tiro["tempo"]) <= 0.0:
			_criar_projetil(tiro["origem"], tiro["direcao"], 310.0 if fase_atual == 1 else 365.0,
				Vector2(1.15, 1.15), Color(0.98, 0.72, 0.25))
			tiros_agendados.remove_at(i)
		else:
			tiros_agendados[i] = tiro


func _criar_laser_rasteiro() -> void:
	# Area fica diretamente na arena (nao segue a posicao manual do boss).
	laser_area = Area2D.new()
	laser_area.name = "LaserRasteiroBoss1"
	laser_area.collision_layer = 0
	laser_area.collision_mask = 1  # Somente jogador.
	laser_area.monitoring = true
	get_parent().add_child(laser_area)
	laser_area.global_position = centro_laser

	var retangulo: RectangleShape2D = RectangleShape2D.new()
	retangulo.size = Vector2(largura_laser, altura_laser)
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.shape = retangulo
	laser_area.add_child(colisao)

	laser_visual = ColorRect.new()
	laser_visual.name = "FaixaLaser"
	laser_visual.position = -retangulo.size * 0.5
	laser_visual.size = retangulo.size
	laser_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	laser_visual.visible = false
	laser_visual.z_index = 4
	laser_area.add_child(laser_visual)


func _atualizar_laser_rasteiro(delta: float) -> void:
	if not is_instance_valid(laser_area) or not is_instance_valid(laser_visual):
		return

	# Durante o golpe do nucleo, a queda forçada e a exposicao do escudo,
	# o laser nao pode causar dano nem bloquear uma janela de contra-ataque.
	if estado == Estado.IMPACTO or estado == Estado.EXPOSTO:
		_parar_laser_rasteiro()
		return

	if tempo_laser_ativo > 0.0:
		tempo_laser_ativo = maxf(0.0, tempo_laser_ativo - delta)
		laser_visual.visible = true
		laser_visual.color = Color(1.0, 0.18, 0.08, 0.85)
		for corpo in laser_area.get_overlapping_bodies():
			if corpo is Jogador:
				corpo.receber_dano(dano_ataques, Vector2(corpo.global_position.x, centro_laser.y))
		if tempo_laser_ativo <= 0.0:
			_parar_laser_rasteiro()
		return

	# Faixa amarela/vermelha avisa ANTES de ativar. Ainda nao causa dano.
	var avisando: bool = estado == Estado.AVISO and ataque_preparado == Ataque.LASER_RASTEIRO
	laser_visual.visible = avisando
	if avisando:
		laser_visual.color = Color(1.0, 0.48, 0.08, 0.28)


func _ativar_laser_rasteiro() -> void:
	tempo_laser_ativo = duracao_laser
	if is_instance_valid(laser_visual):
		laser_visual.visible = true
		laser_visual.color = Color(1.0, 0.18, 0.08, 0.85)


func _parar_laser_rasteiro() -> void:
	tempo_laser_ativo = 0.0
	if is_instance_valid(laser_visual):
		laser_visual.visible = false


func _ao_golpe_bloqueado() -> void:
	if estado != Estado.EXPOSTO:
		mensagem = "BLOQUEADO: ACERTE O NUCLEO 3 VEZES!"


func _ao_receber_dano(_quantidade: int) -> void:
	tempo_flash = 0.13


func _ao_segunda_fase() -> void:
	mensagem = "FASE 2: ERROS MULTIPLICADOS!"
	tempo_rajada_ambiente = 1.3


func _ao_derrota() -> void:
	_parar_laser_rasteiro()
	if is_instance_valid(laser_area):
		laser_area.queue_free()
	_limpar_projeteis()
	tiros_agendados.clear()
	nucleo.collision_layer = 0
	mensagem = "GUARDIAO ELIMINADO"


func _atualizar_cores() -> void:
	if tempo_flash > 0.0:
		visual.color = Color.WHITE
	elif estado == Estado.EXPOSTO:
		visual.color = Color(0.24, 0.86, 0.66) if fase_atual == 1 else Color(0.68, 0.45, 0.93)
	else:
		visual.color = Color(0.94, 0.63, 0.23) if fase_atual == 1 else Color(0.95, 0.28, 0.50)

	if estado == Estado.EXPOSTO:
		nucleo_visual.color = Color(0.37, 0.43, 0.48)
	elif estado == Estado.IMPACTO:
		nucleo_visual.color = Color.WHITE
	elif golpes_nucleo_restantes == 1:
		nucleo_visual.color = Color(1.0, 0.37, 0.28)
	elif golpes_nucleo_restantes == 2:
		nucleo_visual.color = Color(1.0, 0.61, 0.24)
	else:
		nucleo_visual.color = Color(1.0, 0.83, 0.19)


func _atualizar_rotulo() -> void:
	rotulo.text = "%s | FASE %d\n%s" % [nome_exibicao, fase_atual, mensagem]
	nucleo_indicacao.text = "NUCLEO %d/%d [W + J]" % [golpes_nucleo_para_abrir - golpes_nucleo_restantes, golpes_nucleo_para_abrir]


func _draw() -> void:
	if encerrado or estado != Estado.AVISO:
		return
	match ataque_preparado:
		Ataque.RAJADA_DIRECIONADA:
			if is_instance_valid(jogador):
				draw_line(Vector2(-57.0, -3.0), to_local(jogador.global_position + Vector2(20.0, 20.0)),
					Color(1.0, 0.35, 0.36, 0.55), 3.0)
		Ataque.CORTINA_NO_POCO:
			var alturas: Array[float] = [250.0, 405.0]
			if fase_atual == 2:
				alturas = [200.0, 335.0, 470.0]
			for altura in alturas:
				draw_line(to_local(Vector2(421.0, altura)), to_local(Vector2(597.0, altura)),
					Color(1.0, 0.63, 0.23, 0.4), 3.0)
		Ataque.LASER_RASTEIRO:
			pass  # O proprio ColorRect do laser desenha o aviso no chao.
