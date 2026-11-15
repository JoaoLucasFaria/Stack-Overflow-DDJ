extends Node2D

## Arena de teste do boss final: F6, sem alterar a campanha.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_STONEMAKER: PackedScene = preload("res://cenas/bosses/stonemaker.tscn")

var jogador: Jogador
var boss: Stonemaker
var camera_arena: Camera2D
var info: Label
var barra: ProgressBar
var avisos: Label
var venceu: bool = false
var tremor_restante: float = 0.0
var intensidade_tremor: float = 0.0
var clashes: int = 0


func _ready() -> void:
	_criar_cenario()
	_criar_camera()
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.global_position = Vector2(150.0, 548.0)
	# Boss 3: boss 1 e boss 2 derrotados; grapple apenas como recompensa.
	jogador.desbloquear_pulo_duplo()
	jogador.desbloquear_dash()
	jogador.grapple_liberado = false
	jogador.morreu.connect(_ao_morrer)

	boss = CENA_STONEMAKER.instantiate() as Stonemaker
	boss.configurar(jogador)
	add_child(boss)
	boss.global_position = Vector2(810.0, 600.0)
	boss.derrotado.connect(_ao_derrotar)
	boss.vida_alterada.connect(_atualizar_barra)
	boss.impacto.connect(_sacudir_camera)
	boss.dash_clash.connect(_registrar_clash)
	_criar_hud()
	_atualizar_barra(boss.vida_atual, boss.vida_maxima)


func _criar_cenario() -> void:
	var fundo: ColorRect = ColorRect.new()
	fundo.size = Vector2(1152.0, 648.0)
	fundo.color = Color(0.060, 0.075, 0.13)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_criar_bloco("Piso", Vector2(0, 600), Vector2(1152, 48), Color(0.27, 0.32, 0.44))
	_criar_bloco("Teto", Vector2(0, 0), Vector2(1152, 25), Color(0.22, 0.28, 0.37))
	_criar_bloco("ParedeEsquerda", Vector2(0, 0), Vector2(26, 648), Color(0.22, 0.28, 0.37))
	_criar_bloco("ParedeDireita", Vector2(1126, 0), Vector2(26, 648), Color(0.22, 0.28, 0.37))
	for x in [150.0, 450.0, 750.0, 1050.0]:
		var faixa: ColorRect = ColorRect.new()
		faixa.position = Vector2(x, 27.0)
		faixa.size = Vector2(4.0, 573.0)
		faixa.color = Color(0.25, 0.38, 0.43, 0.15)
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(faixa)


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


func _criar_camera() -> void:
	camera_arena = Camera2D.new()
	camera_arena.position = Vector2(576.0, 324.0)
	add_child(camera_arena)
	camera_arena.make_current()


func _criar_hud() -> void:
	var camada: CanvasLayer = CanvasLayer.new()
	add_child(camada)
	var titulo: Label = Label.new()
	titulo.position = Vector2(20.0, 9.0)
	titulo.text = "BOSS 3 | STONEMAKER - PULO DUPLO + DASH / SEM GRAPPLE"
	titulo.add_theme_font_size_override("font_size", 18)
	camada.add_child(titulo)
	barra = ProgressBar.new()
	barra.position = Vector2(316.0, 45.0)
	barra.size = Vector2(518.0, 22.0)
	barra.show_percentage = false
	camada.add_child(barra)
	info = Label.new()
	info.position = Vector2(20.0, 76.0)
	info.add_theme_font_size_override("font_size", 16)
	camada.add_child(info)
	avisos = Label.new()
	avisos.position = Vector2(20.0, 125.0)
	avisos.add_theme_font_size_override("font_size", 15)
	avisos.text = "DASH CLASH: use Shift/X em direcao oposta a INVESTIDA na hora da colisao."
	camada.add_child(avisos)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if tremor_restante > 0.0:
		tremor_restante = maxf(0.0, tremor_restante - delta)
		var forca: float = intensidade_tremor * minf(tremor_restante / 0.30, 1.0)
		camera_arena.offset = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
	else:
		camera_arena.offset = Vector2.ZERO
	if venceu:
		info.text = "STONEMAKER DERROTADO! GRAPPLING LIBERADO! | R para repetir | Clashes: %d" % clashes
		return
	if not is_instance_valid(jogador):
		info.text = "RUN ENCERRADA | R para reiniciar"
		return
	if is_instance_valid(boss):
		info.text = "JOGADOR %d/%d | BOSS %d/%d | FASE %d | CLASHES %d\n%s\nA/D mover | Espaco pulo duplo | Shift/X dash | J atacar | R reiniciar" % [
			jogador.vida_atual, jogador.vida_maxima, boss.vida_atual, boss.vida_maxima,
			boss.fase_atual, clashes, boss.texto_estado
		]


func _atualizar_barra(atual: int, maxima: int) -> void:
	if barra != null:
		barra.max_value = maxima
		barra.value = atual


func _sacudir_camera(intensidade: float) -> void:
	intensidade_tremor = intensidade
	tremor_restante = 0.30


func _registrar_clash() -> void:
	clashes += 1


func _ao_derrotar(_identificador: int) -> void:
	venceu = true
	if is_instance_valid(jogador):
		jogador.desbloquear_grapple()


func _ao_morrer() -> void:
	if is_instance_valid(boss):
		boss.set_physics_process(false)
