extends Node2D

## Adaptador do Stonemaker para a campanha. Mantem a IA e o balanceamento
## no proprio Stonemaker; conecta apenas camera, HUD e progressao da sala.
signal derrotado(identificador: int)

const CENA_STONEMAKER: PackedScene = preload("res://cenas/bosses/stonemaker.tscn")
const DURACAO_TREMOR: float = 0.30

var jogador: Jogador
var sala: SalaMatriz
var boss: Stonemaker
var camera_arena: Camera2D
var barra: ProgressBar
var status: Label
var tremor_restante: float = 0.0
var intensidade_tremor: float = 0.0
var encerrado: bool = false
var total_clashes: int = 0


func configurar(alvo: Jogador, modulo: SalaMatriz) -> void:
	jogador = alvo
	sala = modulo


func _ready() -> void:
	if not is_instance_valid(jogador) or not is_instance_valid(sala):
		push_error("Stonemaker: encontro sem jogador ou sala configurados.")
		return

	_criar_camera()
	boss = CENA_STONEMAKER.instantiate() as Stonemaker
	if boss == null:
		push_error("Stonemaker: nao foi possivel instanciar a cena do chefe.")
		return

	# A sala tem as mesmas dimensoes da arena F6. Ajustar o Marker2D
	# Pontos/PosicaoBoss permite mudar o X sem alterar a IA.
	var marcador: Marker2D = sala.get_node("Pontos/PosicaoBoss") as Marker2D
	boss.configurar(jogador)
	boss.linha_do_chao = sala.to_global(Vector2(0.0, SalaMatriz.PISO_Y)).y
	boss.limite_esquerdo = sala.to_global(Vector2(85.0, 0.0)).x
	boss.limite_direito = sala.to_global(Vector2(1065.0, 0.0)).x
	add_child(boss)
	boss.global_position = Vector2(marcador.global_position.x, boss.linha_do_chao)
	boss.derrotado.connect(_ao_derrotar_boss)
	boss.vida_alterada.connect(_atualizar_barra)
	boss.impacto.connect(_sacudir_camera)
	boss.dash_clash.connect(_ao_dash_clash)

	_criar_hud()
	_atualizar_barra(boss.vida_atual, boss.vida_maxima)


func _criar_camera() -> void:
	camera_arena = Camera2D.new()
	camera_arena.name = "CameraStonemaker"
	add_child(camera_arena)
	camera_arena.global_position = sala.to_global(Vector2(576.0, 288.0))
	camera_arena.make_current()


func _criar_hud() -> void:
	var camada: CanvasLayer = CanvasLayer.new()
	camada.name = "HUDStonemaker"
	add_child(camada)

	barra = ProgressBar.new()
	barra.position = Vector2(316.0, 86.0)
	barra.size = Vector2(518.0, 22.0)
	barra.show_percentage = false
	camada.add_child(barra)

	status = Label.new()
	status.position = Vector2(20.0, 114.0)
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

	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		status.text = "PROCESSO ENCERRADO"
	elif encerrado or not is_instance_valid(boss):
		status.text = "STONEMAKER DERROTADO — GRAPPLING LIBERADO"
	else:
		status.text = "STONEMAKER | FASE %d | %s | DASH CLASHES: %d" % [
			boss.fase_atual, boss.texto_estado, total_clashes
			]


func _atualizar_barra(atual: int, maxima: int) -> void:
	if is_instance_valid(barra):
		barra.max_value = maxima
		barra.value = atual


func _sacudir_camera(intensidade: float) -> void:
	intensidade_tremor = intensidade
	tremor_restante = DURACAO_TREMOR


func _ao_dash_clash() -> void:
	total_clashes += 1


func _ao_derrotar_boss(identificador: int) -> void:
	if encerrado:
		return
	encerrado = true
	# SalaMatriz abre as portas e o Main libera o grapple.
	# Nao duplicar o desbloqueio neste adaptador.
	derrotado.emit(identificador)
