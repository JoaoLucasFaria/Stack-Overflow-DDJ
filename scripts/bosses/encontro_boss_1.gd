extends Node2D

## Controlador de campanha para a luta aprovada na arena de testes.
## Sinais sao encaminhados pela SalaMatriz ao Main (progressao permanente).
signal derrotado(identificador: int)

const CENA_BOSS: PackedScene = preload("res://cenas/bosses/boss_1.tscn")
const CENA_SEGFAULT: PackedScene = preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")
const DURACAO_TREMOR: float = 0.65
const VELOCIDADE_MAX_QUEDA: float = 720.0

var jogador: Jogador
var sala: SalaMatriz
var boss: GuardiaoBoss1
var ataque_jogador: Node
var camera_arena: Camera2D
var tremor_restante: float = 0.0
var queda_forcada: bool = false
var encerrado: bool = false
var torretas_fase_2: Array[InimigoBase] = []
var hud: CanvasLayer
var barra: ProgressBar
var status: Label


func configurar(alvo: Jogador, modulo: SalaMatriz) -> void:
	jogador = alvo
	sala = modulo


func _ready() -> void:
	if not is_instance_valid(jogador) or not is_instance_valid(sala):
		push_error("Boss 1: encontro sem jogador/sala configurados.")
		return
	_criar_pilares_e_espinhos()
	_criar_camera()
	ataque_jogador = jogador.get_node_or_null("AtaqueBasico")

	boss = CENA_BOSS.instantiate() as GuardiaoBoss1
	boss.configurar(jogador)
	add_child(boss)
	# Posicoes independentes e editaveis pelo Lustosa no Inspector da sala.
	boss.global_position = sala.get_node("Pontos/PosicaoBoss").global_position
	var marcador_nucleo: Marker2D = sala.get_node("Pontos/PosicaoNucleo") as Marker2D
	boss.get_node("Nucleo").global_position = marcador_nucleo.global_position
	boss.derrotado.connect(_ao_derrotar_boss)
	boss.nucleo_atingido.connect(_ao_nucleo_atingido)
	boss.fase_alterada.connect(_ao_mudar_fase)
	boss.vida_alterada.connect(_atualizar_barra)
	_criar_hud()
	_atualizar_barra(boss.vida_atual, boss.vida_maxima)


func _criar_pilares_e_espinhos() -> void:
	# Sao criados somente durante a luta, dentro do modulo. Ao sair da sala,
	# toda a estrutura e removida junto com ela.
	_criar_bloco("PilarEsquerdo", Vector2(390, 26), Vector2(26, 494), Color(0.26, 0.55, 0.66))
	_criar_bloco("PilarDireito", Vector2(600, 26), Vector2(26, 494), Color(0.26, 0.55, 0.66))
	_criar_espinhos("EspinhosEsquerda", Vector2(376, 26), false)
	_criar_espinhos("EspinhosDireita", Vector2(626, 26), true)


func _criar_bloco(nome: String, inicio: Vector2, tamanho: Vector2, cor: Color) -> void:
	var bloco: StaticBody2D = StaticBody2D.new()
	bloco.name = nome
	bloco.position = inicio
	bloco.collision_layer = 1
	bloco.collision_mask = 0
	add_child(bloco)
	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = tamanho
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.position = tamanho * 0.5
	colisao.shape = forma
	bloco.add_child(colisao)
	var visual: ColorRect = ColorRect.new()
	visual.size = tamanho
	visual.color = cor
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloco.add_child(visual)


func _criar_espinhos(nome: String, inicio: Vector2, face_direita: bool) -> void:
	var espinhos: Area2D = Area2D.new()
	espinhos.name = nome
	espinhos.position = inicio
	espinhos.collision_layer = 0
	espinhos.collision_mask = 1
	add_child(espinhos)
	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = Vector2(14, 494)
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.position = Vector2(7, 247)
	colisao.shape = forma
	espinhos.add_child(colisao)
	for y in range(0, 494, 25):
		var tri: Polygon2D = Polygon2D.new()
		if face_direita:
			tri.polygon = PackedVector2Array([Vector2(0, y), Vector2(14, y + 12), Vector2(0, y + 24)])
		else:
			tri.polygon = PackedVector2Array([Vector2(14, y), Vector2(0, y + 12), Vector2(14, y + 24)])
		tri.color = Color(0.95, 0.20, 0.26)
		espinhos.add_child(tri)
	espinhos.set_meta("impulso_x", 440.0 if face_direita else -440.0)
	espinhos.add_to_group("espinhos_boss_1")


func _criar_camera() -> void:
	camera_arena = Camera2D.new()
	camera_arena.position = Vector2(576, 324)
	add_child(camera_arena)
	camera_arena.make_current()


func _criar_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	barra = ProgressBar.new()
	barra.position = Vector2(310, 28)
	barra.size = Vector2(520, 20)
	barra.show_percentage = false
	hud.add_child(barra)
	status = Label.new()
	status.position = Vector2(310, 53)
	status.add_theme_font_size_override("font_size", 15)
	hud.add_child(status)


func _atualizar_barra(atual: int, maxima: int) -> void:
	if is_instance_valid(barra):
		barra.max_value = maxima
		barra.value = atual


func _process(delta: float) -> void:
	if tremor_restante > 0.0:
		tremor_restante = maxf(0.0, tremor_restante - delta)
		var intensidade: float = 8.0 * (tremor_restante / DURACAO_TREMOR)
		camera_arena.offset = Vector2(randf_range(-intensidade, intensidade), randf_range(-intensidade, intensidade))
	elif is_instance_valid(camera_arena):
		camera_arena.offset = Vector2.ZERO
	if not is_instance_valid(status):
		return
	if encerrado or not is_instance_valid(boss):
		status.text = "GUARDIAO 1 DERROTADO — PULO DUPLO LIBERADO"
	elif queda_forcada:
		status.text = "IMPACTO NO NUCLEO! RETORNE A BASE"
	elif boss.estado == GuardiaoBoss1.Estado.EXPOSTO:
		status.text = "ESCUDO ABERTO — ATAQUE O CORPO!"
	else:
		status.text = "GUARDIAO 1 | FASE %d | NUCLEO %d/%d (W + J)" % [
			boss.fase_atual,
			boss.golpes_nucleo_para_abrir - boss.golpes_nucleo_restantes,
			boss.golpes_nucleo_para_abrir
		]


func _physics_process(delta: float) -> void:
	if encerrado or not is_instance_valid(jogador):
		return
	if queda_forcada:
		jogador.velocity.x = 0.0
		jogador.velocity.y = minf(jogador.velocity.y + jogador.get_gravity().y * delta, VELOCIDADE_MAX_QUEDA)
		jogador.move_and_slide()
		if jogador.is_on_floor():
			queda_forcada = false
			jogador.velocity = Vector2.ZERO
			jogador.tempo_iframes = 0.65
			jogador.set_physics_process(true)
			if is_instance_valid(ataque_jogador):
				ataque_jogador.set_physics_process(true)
			_pausar_torretas(false)
		return
	for espinhos in get_tree().get_nodes_in_group("espinhos_boss_1"):
		if not is_instance_valid(espinhos) or not is_ancestor_of(espinhos):
			continue
		for corpo in espinhos.get_overlapping_bodies():
			if corpo == jogador:
				jogador.receber_dano(1, espinhos.global_position)
				jogador.velocity.x = float(espinhos.get_meta("impulso_x"))
				jogador.tempo_knockback = maxf(jogador.tempo_knockback, 0.2)
				jogador.tempo_trava_wall_jump = maxf(jogador.tempo_trava_wall_jump, 0.3)


func _ao_nucleo_atingido(_restantes: int, _rompeu: bool) -> void:
	if not is_instance_valid(jogador) or queda_forcada:
		return
	queda_forcada = true
	tremor_restante = DURACAO_TREMOR
	jogador.set_physics_process(false)
	if is_instance_valid(ataque_jogador):
		ataque_jogador.set_physics_process(false)
	jogador.velocity = Vector2(0, 65)
	jogador.tempo_iframes = 99.0
	_pausar_torretas(true)
	_limpar_projeteis_torretas()


func _ao_mudar_fase(fase: int) -> void:
	if fase != 2 or encerrado or not torretas_fase_2.is_empty():
		return
	_criar_torreta(Vector2(434, 146), 1.2)
	_criar_torreta(Vector2(582, 216), 1.6)


func _criar_torreta(posicao: Vector2, primeiro_tiro: float) -> void:
	if not is_instance_valid(jogador):
		return
	var torre: InimigoBase = CENA_SEGFAULT.instantiate() as InimigoBase
	torre.position = posicao
	torre.configurar(jogador)
	# Torretas exclusivas desta luta mantem o alcance e a cadencia originais.
	torre.intervalo_ataque = 1.2
	torre.set("alcance_disparo", 520.0)
	add_child(torre)
	torre.tempo_ate_ataque = primeiro_tiro
	torretas_fase_2.append(torre)


func _pausar_torretas(pausar: bool) -> void:
	for torre in torretas_fase_2:
		if is_instance_valid(torre):
			torre.set_physics_process(not pausar)


func _limpar_projeteis_torretas() -> void:
	for filho in get_children():
		if filho is Area2D and filho.scene_file_path == "res://cenas/inimigos/projetil_corrompido.tscn":
			filho.queue_free()


func _remover_torretas() -> void:
	for torre in torretas_fase_2:
		if is_instance_valid(torre):
			torre.queue_free()
	torretas_fase_2.clear()
	_limpar_projeteis_torretas()


func _ao_derrotar_boss(identificador: int) -> void:
	encerrado = true
	_remover_torretas()
	_restaurar_controles()
	derrotado.emit(identificador)


func _restaurar_controles() -> void:
	queda_forcada = false
	if is_instance_valid(jogador) and jogador.vida_atual > 0:
		jogador.set_physics_process(true)
		jogador.tempo_iframes = minf(jogador.tempo_iframes, 0.65)
		if is_instance_valid(ataque_jogador):
			ataque_jogador.set_physics_process(true)


func _exit_tree() -> void:
	# Sair da sala durante a queda nao pode deixar os controles desligados.
	_restaurar_controles()
