class_name HUDMatriz
extends CanvasLayer
const CENA_HUD_VISUAL = preload("res://cenas/hud.tscn")
const CENA_MAPA_EXPLORACAO = preload("res://scripts/ui/mapa_exploracao.gd")
var hud_visual_instancia: CanvasLayer
var camada_mapa_exploracao: CanvasLayer
var mapa_exploracao: MapaExploracao

## Sinais da selecao de viagem; quem troca a sala e o Main.
signal teleporte_confirmado(destino: Vector2i)
signal teleporte_cancelado

## HUD limpa. M abre o mapa; F3 revela informações técnicas.
## O mapa mostra só salas exploradas. Não há instruções de portas na tela.
var rotulo_estado: Label
var rotulo_atalho_mapa: Label
var rotulo_debug: Label
var rotulo_mensagem: Label
var rotulo_dica: Label
var painel_fim: PanelContainer
var painel_debug: PanelContainer
var usar_hud_superior: bool = false
var mapa_visivel: bool = false
var debug_visivel: bool = false

## O mesmo mapa interativo desenha exploracao e teleporte.
var teleporte_ativo: bool = false
var destinos_teleporte: Array[Vector2i] = []
var destino_selecionado: Vector2i = Vector2i.ZERO
var origem_teleporte: Vector2i = Vector2i.ZERO


func _ready() -> void:
	# Quando o mundo pausa durante a escolha, o HUD deve receber clique e teclado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_visual_instancia = CENA_HUD_VISUAL.instantiate() as CanvasLayer
	add_child(hud_visual_instancia)
	rotulo_estado = _rotulo(Vector2(18, 10), Vector2(735, 28), 17)
	rotulo_atalho_mapa = _rotulo(Vector2(980, 10), Vector2(150, 28), 17)
	rotulo_atalho_mapa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rotulo_atalho_mapa.text = "[M] Mapa"
	rotulo_atalho_mapa.visible = not usar_hud_superior
	if usar_hud_superior:
		hud_visual_instancia.hide()
	rotulo_mensagem = _rotulo(Vector2(180, 117 if usar_hud_superior else 60), Vector2(795, 42), 19)
	rotulo_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_mensagem.add_theme_color_override("font_color", Color("f4df9d"))
	rotulo_dica = _rotulo(Vector2(24, 675 if usar_hud_superior else 565), Vector2(900, 28), 16)
	rotulo_dica.add_theme_color_override("font_color", Color("b0ebd5"))

	# O mapa M e a viagem entre BREAKPOINTS compartilham o mesmo desenho.
	camada_mapa_exploracao = CanvasLayer.new()
	camada_mapa_exploracao.layer = 22
	camada_mapa_exploracao.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada_mapa_exploracao)
	mapa_exploracao = CENA_MAPA_EXPLORACAO.new() as MapaExploracao
	camada_mapa_exploracao.add_child(mapa_exploracao)
	mapa_exploracao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mapa_exploracao.destino_clicado.connect(_ao_clicar_breakpoint)

	painel_debug = PanelContainer.new()
	# Abaixo da HUD Q/E, para F3 nao tampar os equipamentos.
	painel_debug.position = Vector2(15, 242)
	painel_debug.custom_minimum_size = Vector2(690, 0)
	painel_debug.visible = false
	painel_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painel_debug)
	rotulo_debug = Label.new()
	rotulo_debug.add_theme_font_size_override("font_size", 13)
	painel_debug.add_child(rotulo_debug)

	painel_fim = PanelContainer.new()
	painel_fim.position = Vector2(265, 196)
	painel_fim.custom_minimum_size = Vector2(622, 246)
	painel_fim.visible = false
	add_child(painel_fim)
	var coluna_fim: VBoxContainer = VBoxContainer.new()
	coluna_fim.name = "ConteudoFim"
	coluna_fim.alignment = BoxContainer.ALIGNMENT_CENTER
	painel_fim.add_child(coluna_fim)
	var titulo_fim: Label = Label.new()
	titulo_fim.name = "Titulo"
	titulo_fim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_fim.add_theme_font_size_override("font_size", 33)
	coluna_fim.add_child(titulo_fim)
	var subtitulo: Label = Label.new()
	subtitulo.name = "Subtitulo"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 20)
	coluna_fim.add_child(subtitulo)


func _rotulo(posicao: Vector2, dimensoes: Vector2, tamanho: int) -> Label:
	var label: Label = Label.new()
	label.position = posicao
	label.custom_minimum_size = dimensoes
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(label)
	return label


func definir_dica(texto: String) -> void:
	rotulo_dica.text = texto


func mostrar_vitoria() -> void:
	painel_fim.visible = true
	var titulo: Label = painel_fim.get_node("ConteudoFim/Titulo") as Label
	var subtitulo: Label = painel_fim.get_node("ConteudoFim/Subtitulo") as Label
	titulo.text = "VITÓRIA!"
	subtitulo.text = "return();  LOOP ENCERRADO\nEXIT CODE: 0\nR = nova partida"
	rotulo_dica.text = ""


func mostrar_morte() -> void:
	painel_fim.visible = true
	var titulo: Label = painel_fim.get_node("ConteudoFim/Titulo") as Label
	var subtitulo: Label = painel_fim.get_node("ConteudoFim/Subtitulo") as Label
	titulo.text = "PROCESSO ENCERRADO"
	subtitulo.text = "STACK OVERFLOW\nR = reiniciar"
	rotulo_dica.text = ""


func alternar_mapa() -> void:
	if teleporte_ativo:
		return
	mapa_visivel = not mapa_visivel
	if mapa_visivel:
		mapa_exploracao.abrir()
	else:
		mapa_exploracao.fechar()


func _process(_delta: float) -> void:
	# Se outro menu pausar o jogo (BUILD ou recompensa), o mapa livre
	# fecha automaticamente para nao esconder a escolha obrigatoria.
	if mapa_visivel and not teleporte_ativo and get_tree().paused:
		alternar_mapa()


func alternar_debug() -> void:
	debug_visivel = not debug_visivel
	painel_debug.visible = debug_visivel



func abrir_mapa_teleporte(mapa: MapaMatriz, origem: Vector2i, derrotados: Dictionary, destinos: Array[Vector2i]) -> void:
	if teleporte_ativo or destinos.is_empty():
		return
	if mapa_visivel:
		mapa_exploracao.fechar()
	teleporte_ativo = true
	mapa_visivel = true
	origem_teleporte = origem
	destinos_teleporte = destinos.duplicate()
	destino_selecionado = origem if destinos_teleporte.has(origem) else destinos_teleporte[0]
	mapa_exploracao.abrir_teleporte(mapa, origem, derrotados, destinos_teleporte, destino_selecionado)


func fechar_mapa_teleporte() -> void:
	if not teleporte_ativo:
		return
	teleporte_ativo = false
	mapa_visivel = false
	mapa_exploracao.fechar()
	destinos_teleporte.clear()


func _ao_clicar_breakpoint(destino: Vector2i) -> void:
	if not teleporte_ativo or not destinos_teleporte.has(destino):
		return
	destino_selecionado = destino
	_atualizar_selecao_teleporte()


func _atualizar_selecao_teleporte() -> void:
	mapa_exploracao.marcar_destino(destino_selecionado)


func _selecionar_proximo_breakpoint(direcao: Vector2i) -> void:
	var melhor: Vector2i = destino_selecionado
	var pontuacao: float = INF
	for candidato in destinos_teleporte:
		var deslocamento: Vector2i = candidato - destino_selecionado
		var avanco: int = deslocamento.x * direcao.x + deslocamento.y * direcao.y
		if avanco <= 0:
			continue
		var lateral: int = absi(deslocamento.y) if direcao.x != 0 else absi(deslocamento.x)
		var score: float = float(lateral * 3 + avanco)
		if score < pontuacao:
			pontuacao = score
			melhor = candidato
	if melhor != destino_selecionado:
		destino_selecionado = melhor
		_atualizar_selecao_teleporte()


func _input(evento: InputEvent) -> void:
	if not teleporte_ativo or not (evento is InputEventKey):
		return
	var tecla: InputEventKey = evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if evento.is_action_pressed("ui_left"):
		_selecionar_proximo_breakpoint(Vector2i.LEFT)
	elif evento.is_action_pressed("ui_right"):
		_selecionar_proximo_breakpoint(Vector2i.RIGHT)
	elif evento.is_action_pressed("ui_up"):
		_selecionar_proximo_breakpoint(Vector2i.UP)
	elif evento.is_action_pressed("ui_down"):
		_selecionar_proximo_breakpoint(Vector2i.DOWN)
	elif evento.is_action_pressed("coletar_item"):
		teleporte_confirmado.emit(destino_selecionado)
	elif evento.is_action_pressed("ui_cancel"):
		teleporte_cancelado.emit()
	else:
		return
	get_viewport().set_input_as_handled()

func atualizar(mapa: MapaMatriz, posicao: Vector2i, jogador: Jogador, derrotados: Dictionary, mensagem: String) -> void:
	rotulo_mensagem.text = mensagem
	mapa_exploracao.definir_dados(mapa, posicao, derrotados)

	if not is_instance_valid(jogador):
		rotulo_estado.text = "PROCESSO ENCERRADO     R: reiniciar"
		rotulo_atalho_mapa.visible = false
		if is_instance_valid(hud_visual_instancia):
			hud_visual_instancia.visible = false
		return

	rotulo_estado.text = ""
	rotulo_atalho_mapa.visible = not usar_hud_superior

	if is_instance_valid(hud_visual_instancia):
		hud_visual_instancia.visible = not usar_hud_superior
		if not usar_hud_superior:
			hud_visual_instancia.call("atualizar_barras", jogador)

		var texto_hab: String = "Nenhuma"

		if jogador.grapple_liberado:
			texto_hab = "GRAPPLE"
		elif jogador.dash_component.dash_desbloqueado:
			texto_hab = "MALLOC (Dash)"
		elif jogador.pulo_duplo_liberado:
			texto_hab = "PULO DUPLO"

		if not usar_hud_superior:
			hud_visual_instancia.call("atualizar_habilidade", texto_hab)
	if debug_visivel:
		rotulo_debug.text = "DEBUG [F3] | Sala %s | Seed %d | Chefes %s\nSetas mover | Espaço pular | J/clique atacar | G descansar | F boss teste | O +25 STACK | R reiniciar" % [str(posicao), mapa.semente, str(derrotados.keys())]
	# O mapa livre e desenhado por mapa_exploracao.gd.
	# No teleporte, o mesmo mapa interativo destaca os BREAKPOINTS.
