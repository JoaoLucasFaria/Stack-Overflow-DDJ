extends Node2D

## Arena de testes isolada: F6 nesta cena, sem alterar Main e a matriz.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_WOODBREAKER: PackedScene = preload("res://cenas/bosses/woodbreaker.tscn")

var jogador: Jogador
var boss: Woodbreaker
var camera_arena: Camera2D
var info: Label
var barra: ProgressBar
var venceu: bool = false
var tremor_restante: float = 0.0
var intensidade_tremor: float = 0.0


func _ready() -> void:
	_criar_cenario()
	_criar_camera()
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.global_position = Vector2(140.0, 540.0)
	# Simula a progressão real: Boss 1 já derrotado, Boss 2 ainda vivo.
	jogador.desbloquear_pulo_duplo()
	jogador.dash_component.dash_desbloqueado = false
	jogador.morreu.connect(_ao_morrer)

	boss = CENA_WOODBREAKER.instantiate() as Woodbreaker
	boss.configurar(jogador)
	add_child(boss)
	boss.global_position = Vector2(825.0, 600.0)
	boss.derrotado.connect(_ao_derrotar)
	boss.vida_alterada.connect(_atualizar_barra)
	boss.impacto.connect(_sacudir_camera)
	_criar_hud()
	_atualizar_barra(boss.vida_atual, boss.vida_maxima)


func _criar_cenario() -> void:
	var fundo: ColorRect = ColorRect.new()
	fundo.size = Vector2(1152.0, 648.0)
	fundo.color = Color(0.075, 0.09, 0.13)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_criar_bloco("Piso", Vector2(0, 600), Vector2(1152, 48), Color(0.31, 0.36, 0.46))
	_criar_bloco("Teto", Vector2(0, 0), Vector2(1152, 26), Color(0.22, 0.29, 0.33))
	_criar_bloco("ParedeEsquerda", Vector2(0, 0), Vector2(26, 648), Color(0.22, 0.29, 0.33))
	_criar_bloco("ParedeDireita", Vector2(1126, 0), Vector2(26, 648), Color(0.22, 0.29, 0.33))


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
	camera_arena.name = "CameraArena"
	camera_arena.position = Vector2(576.0, 324.0)
	add_child(camera_arena)
	camera_arena.make_current()


func _criar_hud() -> void:
	var camada: CanvasLayer = CanvasLayer.new()
	add_child(camada)
	var titulo: Label = Label.new()
	titulo.position = Vector2(20.0, 11.0)
	titulo.text = "BOSS 2 | WOODBREAKER - Pulo duplo SIM / Dash NAO"
	titulo.add_theme_font_size_override("font_size", 18)
	camada.add_child(titulo)
	barra = ProgressBar.new()
	barra.position = Vector2(310.0, 48.0)
	barra.size = Vector2(520.0, 22.0)
	barra.show_percentage = false
	camada.add_child(barra)
	info = Label.new()
	info.position = Vector2(20.0, 83.0)
	info.add_theme_font_size_override("font_size", 16)
	camada.add_child(info)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if tremor_restante > 0.0:
		tremor_restante = maxf(0.0, tremor_restante - delta)
		var forca: float = intensidade_tremor * minf(tremor_restante / 0.32, 1.0)
		camera_arena.offset = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
	else:
		camera_arena.offset = Vector2.ZERO

	if not is_instance_valid(jogador):
		info.text = "PROCESSO ENCERRADO | R para tentar de novo"
		return
	if venceu:
		info.text = "WOODBREAKER DERROTADO! DASH DESBLOQUEADO! | R para repetir"
		return
	if is_instance_valid(boss):
		info.text = "HP %d/%d | BOSS %d/%d (fase %d) | %s\nA/D: mover | ESPACO: pulo duplo | J/clique: atacar | R: reiniciar" % [
			jogador.vida_atual, jogador.vida_maxima,
			boss.vida_atual, boss.vida_maxima, boss.fase_atual,
			boss.texto_estado
		]


func _atualizar_barra(atual: int, maxima: int) -> void:
	if barra != null:
		barra.max_value = maxima
		barra.value = atual


func _sacudir_camera(intensidade: float) -> void:
	intensidade_tremor = intensidade
	tremor_restante = 0.32


func _ao_derrotar(_identificador: int) -> void:
	venceu = true
	if is_instance_valid(jogador):
		jogador.desbloquear_dash()


func _ao_morrer() -> void:
	if is_instance_valid(boss):
		boss.set_physics_process(false)
