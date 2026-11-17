class_name HUDMatriz
extends CanvasLayer
const CENA_HUD_VISUAL = preload("res://cenas/hud.tscn")
var hud_visual_instancia: CanvasLayer

## Sinais da selecao de viagem; quem troca a sala e o Main.
signal teleporte_confirmado(destino: Vector2i)
signal teleporte_cancelado

## HUD limpa. M abre o mapa; F3 revela informações técnicas.
## O mapa mostra só salas exploradas. Não há instruções de portas na tela.
var rotulo_estado: Label
var rotulo_atalho_mapa: Label
var rotulo_mapa: Label
var rotulo_debug: Label
var rotulo_mensagem: Label
var rotulo_dica: Label
var painel_mapa: PanelContainer
var rolagem_mapa: ScrollContainer
var painel_fim: PanelContainer
var painel_debug: PanelContainer
var mapa_visivel: bool = false
var debug_visivel: bool = false

## O mesmo painel do minimapa e reutilizado no modo de viagem.
var teleporte_ativo: bool = false
var destinos_teleporte: Array[Vector2i] = []
var destino_selecionado: Vector2i = Vector2i.ZERO
var origem_teleporte: Vector2i = Vector2i.ZERO
var grade_teleporte: GridContainer
var botoes_teleporte: Dictionary = {}
var titulo_mapa: Label
var ajuda_mapa: Label
var fonte_mapa: SystemFont


func _ready() -> void:
	# Quando o mundo pausa durante a escolha, o HUD deve receber clique e teclado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_visual_instancia = CENA_HUD_VISUAL.instantiate() as CanvasLayer
	add_child(hud_visual_instancia)
	rotulo_estado = _rotulo(Vector2(18, 10), Vector2(735, 28), 17)
	rotulo_atalho_mapa = _rotulo(Vector2(980, 10), Vector2(150, 28), 17)
	rotulo_atalho_mapa.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rotulo_atalho_mapa.text = "[M] Mapa"
	rotulo_mensagem = _rotulo(Vector2(180, 60), Vector2(795, 42), 19)
	rotulo_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_mensagem.add_theme_color_override("font_color", Color("f4df9d"))
	rotulo_dica = _rotulo(Vector2(24, 565), Vector2(900, 28), 16)
	rotulo_dica.add_theme_color_override("font_color", Color("b0ebd5"))

	painel_mapa = PanelContainer.new()
	painel_mapa.position = Vector2(800, 10)
	painel_mapa.custom_minimum_size = Vector2.ZERO
	painel_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_mapa.visible = false
	add_child(painel_mapa)
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_mapa.add_child(coluna)
	var titulo: Label = Label.new()
	titulo.text = "MAPA DE MEMÓRIA [M]"
	titulo.add_theme_font_size_override("font_size", 15)
	coluna.add_child(titulo)
	titulo_mapa = titulo
	rolagem_mapa = ScrollContainer.new()
	rolagem_mapa.custom_minimum_size = Vector2.ZERO
	rolagem_mapa.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rolagem_mapa.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	coluna.add_child(rolagem_mapa)
	# ScrollContainer recebe um unico conteudo, que alterna a visualizacao.
	var conteudo_mapa: VBoxContainer = VBoxContainer.new()
	rolagem_mapa.add_child(conteudo_mapa)
	rotulo_mapa = Label.new()
	rotulo_mapa.add_theme_font_size_override("font_size", 12)
	fonte_mapa = SystemFont.new()
	fonte_mapa.font_names = PackedStringArray(["Consolas", "Liberation Mono", "monospace"])
	rotulo_mapa.add_theme_font_override("font", fonte_mapa)
	conteudo_mapa.add_child(rotulo_mapa)
	grade_teleporte = GridContainer.new()
	grade_teleporte.add_theme_constant_override("h_separation", 3)
	grade_teleporte.add_theme_constant_override("v_separation", 3)
	grade_teleporte.visible = false
	conteudo_mapa.add_child(grade_teleporte)
	ajuda_mapa = Label.new()
	ajuda_mapa.visible = false
	ajuda_mapa.add_theme_font_size_override("font_size", 14)
	ajuda_mapa.add_theme_color_override("font_color", Color("a9ecd9"))
	coluna.add_child(ajuda_mapa)

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
	painel_mapa.visible = mapa_visivel


func alternar_debug() -> void:
	debug_visivel = not debug_visivel
	painel_debug.visible = debug_visivel



func abrir_mapa_teleporte(mapa: MapaMatriz, origem: Vector2i, derrotados: Dictionary, destinos: Array[Vector2i]) -> void:
	if teleporte_ativo or destinos.is_empty():
		return
	teleporte_ativo = true
	mapa_visivel = true
	origem_teleporte = origem
	destinos_teleporte = destinos.duplicate()
	destino_selecionado = origem if destinos_teleporte.has(origem) else destinos_teleporte[0]
	# Reaproveita o painel / ScrollContainer do mapa comum.
	painel_mapa.visible = true
	painel_mapa.mouse_filter = Control.MOUSE_FILTER_STOP
	painel_mapa.position = Vector2(185, 90)
	painel_mapa.custom_minimum_size = Vector2(770, 0)
	rolagem_mapa.custom_minimum_size = Vector2(742, 335)
	titulo_mapa.text = "REDE BREAKPOINT  /  VIAGEM RAPIDA"
	rotulo_mapa.visible = false
	grade_teleporte.visible = true
	ajuda_mapa.visible = true
	_desenhar_destinos_teleporte(mapa, derrotados)
	_atualizar_selecao_teleporte()


func fechar_mapa_teleporte() -> void:
	if not teleporte_ativo:
		return
	teleporte_ativo = false
	mapa_visivel = false
	painel_mapa.visible = false
	painel_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_mapa.position = Vector2(688, 10)
	painel_mapa.custom_minimum_size = Vector2(448, 0)
	rolagem_mapa.custom_minimum_size = Vector2(425, 225)
	titulo_mapa.text = "MAPA DE MEMÓRIA [M]"
	rotulo_mapa.visible = true
	grade_teleporte.visible = false
	ajuda_mapa.visible = false
	destinos_teleporte.clear()
	botoes_teleporte.clear()


func _desenhar_destinos_teleporte(mapa: MapaMatriz, derrotados: Dictionary) -> void:
	for filho in grade_teleporte.get_children():
		grade_teleporte.remove_child(filho)
		filho.queue_free()
	botoes_teleporte.clear()
	var min_x: int = origem_teleporte.x
	var max_x: int = origem_teleporte.x
	var min_y: int = origem_teleporte.y
	var max_y: int = origem_teleporte.y
	for pos in mapa.visitadas.keys():
		min_x = mini(min_x, pos.x)
		max_x = maxi(max_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_y = maxi(max_y, pos.y)
	grade_teleporte.columns = max_x - min_x + 3
	for y in range(min_y - 1, max_y + 2):
		for x in range(min_x - 1, max_x + 2):
			var posicao: Vector2i = Vector2i(x, y)
			var conhecido: bool = mapa.visitadas.has(posicao)
			if destinos_teleporte.has(posicao):
				var botao: Button = Button.new()
				botao.text = "B"
				botao.custom_minimum_size = Vector2(33, 30)
				botao.focus_mode = Control.FOCUS_NONE
				botao.add_theme_font_override("font", fonte_mapa)
				botao.add_theme_font_size_override("font_size", 15)
				botao.tooltip_text = "BREAKPOINT %s%s" % [str(posicao), " - atual" if posicao == origem_teleporte else ""]
				botao.pressed.connect(_ao_clicar_breakpoint.bind(posicao))
				grade_teleporte.add_child(botao)
				botoes_teleporte[posicao] = botao
			else:
				var simbolo: String = "·"
				if conhecido:
					var tipo: String = String(mapa.obter(posicao).get("tipo", "normal"))
					if tipo.begins_with("boss"):
						var numero: int = tipo.substr(4).to_int()
						simbolo = "✓" if derrotados.has(numero) else str(numero)
					elif tipo == "bloqueio_pulo":
						simbolo = "J"
					elif tipo == "bloqueio_dash":
						simbolo = "D"
					elif tipo == "final":
						simbolo = "F"
					elif tipo == "exception":
						simbolo = "P"
					else:
						simbolo = "■"
				var celula: Label = Label.new()
				celula.text = simbolo
				celula.custom_minimum_size = Vector2(33, 30)
				celula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				celula.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				celula.add_theme_font_override("font", fonte_mapa)
				celula.add_theme_font_size_override("font_size", 14)
				celula.add_theme_color_override("font_color", Color("9cacb8") if conhecido else Color("465762"))
				grade_teleporte.add_child(celula)


func _ao_clicar_breakpoint(destino: Vector2i) -> void:
	if not teleporte_ativo or not destinos_teleporte.has(destino):
		return
	destino_selecionado = destino
	_atualizar_selecao_teleporte()


func _atualizar_selecao_teleporte() -> void:
	for coord in botoes_teleporte:
		var botao: Button = botoes_teleporte[coord]
		var escolhido: bool = coord == destino_selecionado
		var estilo: StyleBoxFlat = StyleBoxFlat.new()
		if escolhido:
			estilo.bg_color = Color("28765c")
			estilo.border_color = Color("a1ffce")
			estilo.set_border_width_all(2)
		else:
			estilo.bg_color = Color("213e55")
			estilo.border_color = Color("4c9bbe")
			estilo.set_border_width_all(1)
		botao.add_theme_stylebox_override("normal", estilo)
		botao.add_theme_stylebox_override("hover", estilo)
		botao.add_theme_color_override("font_color", Color.WHITE)
		botao.add_theme_color_override("font_hover_color", Color.WHITE)
	var sufixo: String = " (voce esta aqui)" if destino_selecionado == origem_teleporte else ""
	ajuda_mapa.text = "Destino: B %s%s\nWASD/setas: escolher B  |  Clique: selecionar  |  F: viajar  |  Esc: cancelar" % [str(destino_selecionado), sufixo]
	if botoes_teleporte.has(destino_selecionado):
		rolagem_mapa.call_deferred("ensure_control_visible", botoes_teleporte[destino_selecionado])


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

	if not is_instance_valid(jogador):
		rotulo_estado.text = "PROCESSO ENCERRADO     R: reiniciar"
		rotulo_atalho_mapa.visible = false
		if is_instance_valid(hud_visual_instancia):
			hud_visual_instancia.visible = false
		return

	rotulo_estado.text = ""
	rotulo_atalho_mapa.visible = true

	if is_instance_valid(hud_visual_instancia):
		hud_visual_instancia.visible = true
		hud_visual_instancia.call("atualizar_barras", jogador)

		var texto_hab: String = "Nenhuma"

		if jogador.grapple_liberado:
			texto_hab = "GRAPPLE"
		elif jogador.dash_component.dash_desbloqueado:
			texto_hab = "MALLOC (Dash)"
		elif jogador.pulo_duplo_liberado:
			texto_hab = "PULO DUPLO"

		hud_visual_instancia.call("atualizar_habilidade", texto_hab)
	if debug_visivel:
		rotulo_debug.text = "DEBUG [F3] | Sala %s | Seed %d | Chefes %s\nSetas mover | Espaço pular | J/clique atacar | G descansar | F boss teste | O +25 STACK | R reiniciar" % [str(posicao), mapa.semente, str(derrotados.keys())]
	if not mapa_visivel:
		return
	# A grade antiga era fixa (-6..8, -5..4). Um mapa maior precisa
	# ampliar o enquadramento conforme o jogador descobre novas salas.
	var min_x: int = posicao.x
	var max_x: int = posicao.x
	var min_y: int = posicao.y
	var max_y: int = posicao.y
	for coordenada in mapa.visitadas.keys():
		min_x = mini(min_x, coordenada.x)
		max_x = maxi(max_x, coordenada.x)
		min_y = mini(min_y, coordenada.y)
		max_y = maxi(max_y, coordenada.y)
	var linhas: PackedStringArray = []
	for y in range(min_y - 1, max_y + 2):
		var linha: String = ""
		for x in range(min_x - 1, max_x + 2):
			var c: Vector2i = Vector2i(x, y)
			var simbolo: String = "·"
			if c == posicao:
				simbolo = "@"
			elif mapa.visitadas.has(c):
				var tipo: String = mapa.obter(c).get("tipo", "normal")
				if tipo.begins_with("boss"):
					var numero: int = tipo.substr(4).to_int()
					simbolo = "✓" if derrotados.has(numero) else str(numero)
				elif tipo == "inicio":
					simbolo = "S"
				elif tipo == "breakpoint":
					simbolo = "B"
				elif tipo == "bloqueio_pulo":
					simbolo = "J"
				elif tipo == "bloqueio_dash":
					simbolo = "D"
				elif tipo == "final":
					simbolo = "F"
				elif tipo == "exception":
					simbolo = "P"
				else:
					simbolo = "■"
			linha += simbolo + " "
		linhas.append(linha)
	rotulo_mapa.text = "\n".join(linhas) + "\n@ Você | P Patch | B Breakpoint | J Pulo | D Dash | F Final"
	# Ajustar tamanho conforme o mapa descoberto.
	if not teleporte_ativo:
		var tamanho_texto: Vector2 = rotulo_mapa.get_combined_minimum_size()
		rolagem_mapa.custom_minimum_size = Vector2(
			minf(tamanho_texto.x + 12.0, 425.0),
			minf(tamanho_texto.y + 12.0, 225.0)
			)
		painel_mapa.reset_size()
	# Se o mapa ultrapassar a largura visível, acompanhe o jogador.
	# As medidas são aproximadas e o ScrollContainer limita o deslocamento.
	rolagem_mapa.scroll_horizontal = maxi(0, (posicao.x - min_x + 1) * 14 - 190)
	rolagem_mapa.scroll_vertical = maxi(0, (posicao.y - min_y + 1) * 15 - 95)
