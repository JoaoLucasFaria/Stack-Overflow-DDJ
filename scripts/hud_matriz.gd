class_name HUDMatriz
extends CanvasLayer

## HUD limpa. M abre o mapa; F3 revela informações técnicas.
## O mapa mostra só salas exploradas. Não há instruções de portas na tela.
var rotulo_estado: Label
var rotulo_mapa: Label
var rotulo_debug: Label
var rotulo_mensagem: Label
var rotulo_dica: Label
var painel_mapa: PanelContainer
var painel_fim: PanelContainer
var painel_debug: PanelContainer
var mapa_visivel: bool = false
var debug_visivel: bool = false


func _ready() -> void:
	rotulo_estado = _rotulo(Vector2(18, 10), Vector2(735, 28), 17)
	rotulo_mensagem = _rotulo(Vector2(180, 60), Vector2(795, 42), 19)
	rotulo_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_mensagem.add_theme_color_override("font_color", Color("f4df9d"))
	rotulo_dica = _rotulo(Vector2(24, 565), Vector2(900, 28), 16)
	rotulo_dica.add_theme_color_override("font_color", Color("b0ebd5"))

	painel_mapa = PanelContainer.new()
	painel_mapa.position = Vector2(810, 10)
	painel_mapa.custom_minimum_size = Vector2(325, 0)
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
	rotulo_mapa = Label.new()
	rotulo_mapa.add_theme_font_size_override("font_size", 15)
	var fonte: SystemFont = SystemFont.new()
	fonte.font_names = PackedStringArray(["Consolas", "Liberation Mono", "monospace"])
	rotulo_mapa.add_theme_font_override("font", fonte)
	coluna.add_child(rotulo_mapa)

	painel_debug = PanelContainer.new()
	painel_debug.position = Vector2(15, 94)
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
	mapa_visivel = not mapa_visivel
	painel_mapa.visible = mapa_visivel


func alternar_debug() -> void:
	debug_visivel = not debug_visivel
	painel_debug.visible = debug_visivel


func atualizar(mapa: MapaMatriz, posicao: Vector2i, jogador: Jogador, derrotados: Dictionary, mensagem: String) -> void:
	rotulo_mensagem.text = mensagem
	if not is_instance_valid(jogador):
		rotulo_estado.text = "PROCESSO ENCERRADO     R: reiniciar"
		return
	var habilidades: String = ""
	if jogador.pulo_duplo_liberado:
		habilidades += "  •  2× PULO"
	if jogador.dash_component.dash_desbloqueado:
		habilidades += "  •  MALLOC"
	if jogador.grapple_liberado:
		habilidades += "  •  GRAPPLE"
	rotulo_estado.text = "HP %d/%d%s     [M] Mapa" % [jogador.vida_atual, jogador.vida_maxima, habilidades]
	if debug_visivel:
		rotulo_debug.text = "DEBUG [F3] | Sala %s | Seed %d | Chefes %s\nSetas mover | Espaço pular | Shift/X dash | F boss teste | G grapple | R reiniciar" % [str(posicao), mapa.semente, str(derrotados.keys())]
	if not mapa_visivel:
		return
	var linhas: PackedStringArray = []
	for y in range(-5, 5):
		var linha: String = ""
		for x in range(-6, 9):
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
				elif tipo == "bloqueio_pulo":
					simbolo = "J"
				elif tipo == "bloqueio_dash":
					simbolo = "D"
				elif tipo == "final":
					simbolo = "F"
				else:
					simbolo = "■"
			linha += simbolo + " "
		linhas.append(linha)
	rotulo_mapa.text = "\n".join(linhas) + "\n@ Você | J Pulo | D Dash | F Final"
