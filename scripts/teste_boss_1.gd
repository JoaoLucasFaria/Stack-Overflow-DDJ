extends Node2D

## F6 nesta cena. O mundo principal permanece com seus bosses provisorios.
## Arena exclusivamente para testar Wall Slide/Wall Jump e o Boss 1.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_BOSS: PackedScene = preload("res://cenas/bosses/boss_1.tscn")
const CENA_SEGFAULT: PackedScene = preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")

var jogador: Jogador
var boss: GuardiaoBoss1
var hud: CanvasLayer
var info: Label
var barra: ProgressBar
var venceu: bool = false
var camera_arena: Camera2D
var tremor_restante: float = 0.0
var queda_forcada: bool = false
var ataque_jogador: Node
var torretas_fase_2: Array[InimigoBase] = []
const DURACAO_TREMOR: float = 0.65
const VELOCIDADE_MAX_QUEDA: float = 720.0


func _ready() -> void:
	_criar_cenario()
	_criar_camera()
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.global_position = Vector2(110, 540)
	jogador.pulo_duplo_liberado = false
	jogador.dash_component.dash_desbloqueado = false
	jogador.morreu.connect(_ao_morrer)
	ataque_jogador = jogador.get_node_or_null("AtaqueBasico")

	boss = CENA_BOSS.instantiate() as GuardiaoBoss1
	boss.configurar(jogador)
	add_child(boss)
	# A torreta principal fica grudada na face INTERNA da parede direita,
	# elevada: nem um pulo simples nem golpes do chao alcancam o corpo.
	boss.global_position = Vector2(1080, 555)
	boss.derrotado.connect(_ao_derrotado)
	boss.nucleo_atingido.connect(_ao_nucleo_atingido)
	boss.fase_alterada.connect(_ao_fase_alterada)
	boss.vida_alterada.connect(_atualizar_vida_boss)
	_criar_hud()
	_atualizar_vida_boss(boss.vida_atual, boss.vida_maxima)


func _criar_cenario() -> void:
	var fundo: ColorRect = ColorRect.new()
	fundo.size = Vector2(1152, 648)
	fundo.color = Color(0.065, 0.105, 0.18)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# Piso e limites da sala.
	_criar_bloco("Piso", Vector2(0, 600), Vector2(1152, 48), Color(0.28, 0.4, 0.51))
	_criar_bloco("ParedeEsquerda", Vector2(0, 0), Vector2(26, 648), Color(0.24, 0.33, 0.46))
	_criar_bloco("ParedeDireita", Vector2(1126, 0), Vector2(26, 648), Color(0.24, 0.33, 0.46))
	_criar_bloco("Teto", Vector2(0, 0), Vector2(1152, 26), Color(0.24, 0.33, 0.46))

	# Paredes chegam ao teto, sem plataformas superiores exploraveis.
	# Abertura inferior (y=520 a 600) permite entrar pelo vao central.
	_criar_bloco("PilarEsquerdo", Vector2(390, 26), Vector2(26, 494), Color(0.26, 0.55, 0.66))
	_criar_bloco("PilarDireito", Vector2(600, 26), Vector2(26, 494), Color(0.26, 0.55, 0.66))
	# Espinhos do LADO DE FORA: forcam a subida pelo corredor central.
	_criar_espinhos_externos("EspinhosEsquerda", Vector2(376, 26), false)
	_criar_espinhos_externos("EspinhosDireita", Vector2(626, 26), true)


func _criar_camera() -> void:
	camera_arena = Camera2D.new()
	camera_arena.name = "CameraArena"
	camera_arena.position = Vector2(576, 324)
	add_child(camera_arena)
	camera_arena.make_current()


func _criar_espinhos_externos(nome: String, inicio: Vector2, face_direita: bool) -> void:
	var espinhos: Area2D = Area2D.new()
	espinhos.name = nome
	espinhos.position = inicio
	espinhos.collision_layer = 0
	espinhos.collision_mask = 1
	add_child(espinhos)
	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = Vector2(14.0, 494.0)
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.position = Vector2(7, 247)
	colisao.shape = forma
	espinhos.add_child(colisao)
	# Triangulos visiveis na face externa do pilar.
	for y in range(0, 494, 25):
		var tri: Polygon2D = Polygon2D.new()
		if face_direita:
			tri.polygon = PackedVector2Array([Vector2(0, y), Vector2(14, y + 12), Vector2(0, y + 24)])
		else:
			tri.polygon = PackedVector2Array([Vector2(14, y), Vector2(0, y + 12), Vector2(14, y + 24)])
		tri.color = Color(0.95, 0.2, 0.26)
		espinhos.add_child(tri)
	# Aplicamos uma repulsao continua, inclusive durante os i-frames:
	# nao permite escalar a face externa aproveitando a invencibilidade.
	espinhos.set_meta("impulso_x", 440.0 if face_direita else -440.0)
	espinhos.add_to_group("espinhos_boss_1")


func _ao_nucleo_atingido(_restantes: int, _rompeu: bool) -> void:
	if not is_instance_valid(jogador) or queda_forcada:
		return
	queda_forcada = true
	tremor_restante = DURACAO_TREMOR
	# Suspende o controle e o ataque, mas mantem a fisica do corpo ativa
	# pela arena para o jogador realmente CAIR ate o chao.
	jogador.set_physics_process(false)
	if is_instance_valid(ataque_jogador):
		ataque_jogador.set_physics_process(false)
	jogador.velocity = Vector2(0.0, 65.0)
	# Nenhum dano injusto durante a queda obrigatoria.
	jogador.tempo_iframes = 99.0
	_pausar_torretas(true)
	_limpar_projeteis_torretas()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(jogador) or venceu:
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
	# Mesmo invencivel, o jogador e repelido dos espinhos de fora.
	for espinhos in get_tree().get_nodes_in_group("espinhos_boss_1"):
		if not (espinhos is Area2D):
			continue
		for corpo in espinhos.get_overlapping_bodies():
			if corpo == jogador:
				jogador.receber_dano(1, espinhos.global_position)
				jogador.velocity.x = float(espinhos.get_meta("impulso_x"))
				jogador.tempo_knockback = maxf(jogador.tempo_knockback, 0.2)
				jogador.tempo_trava_wall_jump = maxf(jogador.tempo_trava_wall_jump, 0.3)


func _criar_bloco(nome: String, inicio: Vector2, tamanho: Vector2, cor: Color) -> void:
	var bloco: StaticBody2D = StaticBody2D.new()
	bloco.name = nome
	bloco.position = inicio
	bloco.collision_layer = 1
	bloco.collision_mask = 0
	add_child(bloco)
	var formato: RectangleShape2D = RectangleShape2D.new()
	formato.size = tamanho
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.position = tamanho * 0.5
	colisao.shape = formato
	bloco.add_child(colisao)
	var visual: ColorRect = ColorRect.new()
	visual.size = tamanho
	visual.color = cor
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloco.add_child(visual)


func _criar_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var titulo: Label = Label.new()
	titulo.position = Vector2(20, 10)
	titulo.text = "BOSS 1 | Torreta na parede: 3 acertos no nucleo + escale e ataque o corpo!"
	titulo.add_theme_font_size_override("font_size", 17)
	hud.add_child(titulo)

	barra = ProgressBar.new()
	barra.position = Vector2(310, 48)
	barra.size = Vector2(520, 22)
	barra.max_value = boss.vida_maxima
	barra.show_percentage = false
	hud.add_child(barra)

	info = Label.new()
	info.position = Vector2(20, 81)
	info.add_theme_font_size_override("font_size", 16)
	hud.add_child(info)


func _process(delta: float) -> void:
	if tremor_restante > 0.0:
		tremor_restante = maxf(0.0, tremor_restante - delta)
		var intensidade: float = 8.0 * (tremor_restante / DURACAO_TREMOR)
		camera_arena.offset = Vector2(randf_range(-intensidade, intensidade), randf_range(-intensidade, intensidade))
	else:
		camera_arena.offset = Vector2.ZERO
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return

	if not is_instance_valid(jogador):
		info.text = "PROCESSO ENCERRADO | R para reiniciar"
		return

	if venceu:
		info.text = "BOSS 1 DERROTADO! PULO DUPLO DESBLOQUEADO! | R para recomecar"
		return

	if is_instance_valid(boss):
		var status: String = "ESCUDO ABERTO: suba e ataque o corpo na parede!" if boss.estado == GuardiaoBoss1.Estado.EXPOSTO else "NUCLEO: %d/%d acertos | escale pelo meio!" % [boss.golpes_nucleo_para_abrir - boss.golpes_nucleo_restantes, boss.golpes_nucleo_para_abrir]
		if queda_forcada:
			status = "TERREMOTO! Retornando a base..."
		info.text = "HP %d/%d | Boss %d/%d (fase %d) | %s\nA/D: mover | ESPACO: pular/wall jump | W + J/clique: bater para cima | R: reiniciar" % [
			jogador.vida_atual, jogador.vida_maxima,
			boss.vida_atual, boss.vida_maxima, boss.fase_atual, status
		]


func _atualizar_vida_boss(atual: int, maxima: int) -> void:
	if barra != null:
		barra.max_value = maxima
		barra.value = atual


func _ao_derrotado(_identificador: int) -> void:
	_remover_torretas()
	venceu = true
	if is_instance_valid(jogador):
		jogador.desbloquear_pulo_duplo()


func _ao_morrer() -> void:
	_pausar_torretas(true)
	if is_instance_valid(boss):
		boss.set_physics_process(false)


func _ao_fase_alterada(fase: int) -> void:
	if fase != 2 or venceu or not torretas_fase_2.is_empty():
		return
	# Duas torretas comuns nos pontos altos, em faces internas opostas.
	# Seu tiro normal respeita a geometria; so os tiros do Boss atravessam.
	_criar_torreta_fase_2(Vector2(434, 146), 1.2)
	_criar_torreta_fase_2(Vector2(582, 216), 1.6)


func _criar_torreta_fase_2(posicao: Vector2, tempo_primeiro_tiro: float) -> void:
	if not is_instance_valid(jogador):
		return
	var inimigo: InimigoBase = CENA_SEGFAULT.instantiate() as InimigoBase
	inimigo.position = posicao
	inimigo.configurar(jogador)
	# Intervalos curtos, mas com aviso antes de atirar.
	inimigo.intervalo_ataque = 1.2
	add_child(inimigo)
	inimigo.tempo_ate_ataque = tempo_primeiro_tiro
	torretas_fase_2.append(inimigo)


func _pausar_torretas(pausado: bool) -> void:
	for torre in torretas_fase_2:
		if is_instance_valid(torre):
			torre.set_physics_process(not pausado)


func _limpar_projeteis_torretas() -> void:
	# Projeteis dos mobs que ja estavam a caminho no tremor.
	for filho in get_children():
		if filho is Area2D and filho.scene_file_path == "res://cenas/inimigos/projetil_corrompido.tscn":
			filho.queue_free()


func _remover_torretas() -> void:
	for torre in torretas_fase_2:
		if is_instance_valid(torre):
			torre.queue_free()
	torretas_fase_2.clear()
	_limpar_projeteis_torretas()
