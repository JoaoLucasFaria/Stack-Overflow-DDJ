extends Node2D

## Encontro de campanha do Woodbreaker. Mantem a logica de combate no
## proprio boss; esta classe apenas integra camera, HUD e progressao.
signal derrotado(identificador: int)

const CENA_WOODBREAKER: PackedScene = preload("res://cenas/bosses/woodbreaker.tscn")
const DURACAO_TREMOR: float = 0.32

var jogador: Jogador
var sala: SalaMatriz
var boss: Woodbreaker
var camera_arena: Camera2D
var barra: ProgressBar
var status: Label
var tremor_restante: float = 0.0
var intensidade_tremor: float = 0.0
var encerrado: bool = false


func configurar(alvo: Jogador, modulo: SalaMatriz) -> void:
	jogador = alvo
	sala = modulo


func _ready() -> void:
	if not is_instance_valid(jogador) or not is_instance_valid(sala):
		push_error("Woodbreaker: encontro sem jogador/sala configurados.")
		return

	_criar_camera()
	boss = CENA_WOODBREAKER.instantiate() as Woodbreaker
	if boss == null:
		push_error("Woodbreaker: cena do chefe nao encontrada.")
		return
	# A geometria tem as mesmas dimensoes da arena de F6. A posicao do
	# boss fica editavel pelo Marker2D da sala; o chao continua em y=600.
	var posicao: Marker2D = sala.get_node("Pontos/PosicaoBoss") as Marker2D
	boss.configurar(jogador)
	boss.linha_do_chao = sala.to_global(Vector2(0.0, SalaMatriz.PISO_Y)).y
	boss.limite_esquerdo = sala.to_global(Vector2(100.0, 0.0)).x
	boss.limite_direito = sala.to_global(Vector2(1050.0, 0.0)).x
	add_child(boss)
	boss.global_position = Vector2(posicao.global_position.x, boss.linha_do_chao)
	boss.derrotado.connect(_ao_derrotar_boss)
	boss.vida_alterada.connect(_atualizar_barra)
	boss.impacto.connect(_sacudir_camera)
	_criar_hud()
	_atualizar_barra(boss.vida_atual, boss.vida_maxima)


func _criar_camera() -> void:
	camera_arena = Camera2D.new()
	camera_arena.name = "CameraWoodbreaker"
	add_child(camera_arena)
	camera_arena.global_position = sala.to_global(Vector2(576.0, 288.0))
	camera_arena.make_current()


func _criar_hud() -> void:
	var camada: CanvasLayer = CanvasLayer.new()
	camada.name = "HUDWoodbreaker"
	add_child(camada)
	barra = ProgressBar.new()
	barra.position = Vector2(310.0, 86.0)
	barra.size = Vector2(520.0, 20.0)
	barra.show_percentage = false
	camada.add_child(barra)
	status = Label.new()
	status.position = Vector2(310.0, 114.0)
	status.add_theme_font_size_override("font_size", 15)
	camada.add_child(status)


func _process(delta: float) -> void:
	if is_instance_valid(camera_arena):
		if tremor_restante > 0.0:
			tremor_restante = maxf(0.0, tremor_restante - delta)
			var forca: float = intensidade_tremor * minf(tremor_restante / DURACAO_TREMOR, 1.0)
			camera_arena.offset = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
		else:
			camera_arena.offset = Vector2.ZERO

	if not is_instance_valid(status):
		return
	if encerrado or not is_instance_valid(boss):
		status.text = "WOODBREAKER DERROTADO — DASH LIBERADO"
	elif jogador.vida_atual <= 0:
		status.text = "PROCESSO ENCERRADO"
	else:
		status.text = "WOODBREAKER | FASE %d | %s" % [boss.fase_atual, boss.texto_estado]


func _atualizar_barra(atual: int, maxima: int) -> void:
	if is_instance_valid(barra):
		barra.max_value = maxima
		barra.value = atual


func _sacudir_camera(intensidade: float) -> void:
	intensidade_tremor = intensidade
	tremor_restante = DURACAO_TREMOR


func _ao_derrotar_boss(identificador: int) -> void:
	if encerrado:
		return
	encerrado = true
	# A SalaMatriz abre as portas e reativa as plataformas de saida.
	# O Main concede o dash; o encontro nao duplica a recompensa.
	derrotado.emit(identificador)
