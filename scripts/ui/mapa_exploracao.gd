class_name MapaExploracao
extends Control

signal destino_clicado(destino: Vector2i)

## V15.1: Mapa de Memoria em tela cheia, sem pausar a partida.
## Usa APENAS conexoes do grafo real; celulas vizinhas nao implicam passagem.
## Visibilidade restrita a salas visitadas. Saidas desconhecidas sao pontas curtas.
const PASSO: float = 94.0
const TAMANHO_SALA: Vector2 = Vector2(58.0, 46.0)
const ZOOM_MIN: float = 0.30
const ZOOM_MAX: float = 2.8
const COR_FUNDO: Color = Color(0.027, 0.047, 0.073, 0.985)
const COR_GRID: Color = Color(0.10, 0.17, 0.22, 0.45)
const COR_LIGACAO: Color = Color(0.29, 0.68, 0.72)
const COR_DESCONHECIDO: Color = Color(0.46, 0.51, 0.58)
const COR_TEXTO: Color = Color(0.83, 0.93, 0.96)

var mapa: MapaMatriz
var atual: Vector2i = Vector2i.ZERO
var chefes_derrotados: Dictionary = {}
var zoom: float = 1.0
var arraste: Vector2 = Vector2.ZERO
var centro_mapa: Vector2 = Vector2.ZERO
var arrastando: bool = false
var qtd_visitadas: int = -1
var qtd_chefes: int = -1
var modo_teleporte: bool = false
var destinos_teleporte: Array[Vector2i] = []
var destino_marcado: Vector2i = Vector2i.ZERO
var deslocamento_mouse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	visible = false
	resized.connect(queue_redraw)


func definir_dados(novo_mapa: MapaMatriz, nova_posicao: Vector2i, derrotados: Dictionary) -> void:
	var mudou: bool = mapa != novo_mapa or atual != nova_posicao
	mapa = novo_mapa
	atual = nova_posicao
	if is_instance_valid(mapa):
		mudou = mudou or qtd_visitadas != mapa.visitadas.size()
		qtd_visitadas = mapa.visitadas.size()
	mudou = mudou or qtd_chefes != derrotados.size()
	qtd_chefes = derrotados.size()
	chefes_derrotados = derrotados
	if mudou and visible:
		queue_redraw()


func abrir() -> void:
	modo_teleporte = false
	destinos_teleporte.clear()
	visible = true
	add_to_group("mapa_exploracao_aberto")
	centralizar()


func abrir_teleporte(novo_mapa: MapaMatriz, origem: Vector2i, derrotados: Dictionary, destinos: Array[Vector2i], escolhido: Vector2i) -> void:
	definir_dados(novo_mapa, origem, derrotados)
	modo_teleporte = true
	destinos_teleporte = destinos.duplicate()
	destino_marcado = escolhido
	remove_from_group("mapa_exploracao_aberto")
	visible = true
	centralizar()


func marcar_destino(destino: Vector2i) -> void:
	if not modo_teleporte or not destinos_teleporte.has(destino):
		return
	destino_marcado = destino
	# Quando WASD escolhe um B fora da tela, traga-o para a area visivel
	# sem alterar o nivel de zoom nem recentralizar todo o mapa.
	var ponto: Vector2 = _posicao_da_sala(destino)
	arraste += Vector2(
		clampf(ponto.x, 48.0, maxf(48.0, size.x - 48.0)) - ponto.x,
		clampf(ponto.y, 105.0, maxf(105.0, size.y - 85.0)) - ponto.y
	)
	queue_redraw()


func fechar() -> void:
	visible = false
	arrastando = false
	modo_teleporte = false
	destinos_teleporte.clear()
	remove_from_group("mapa_exploracao_aberto")


func centralizar() -> void:
	if not is_instance_valid(mapa):
		return
	var minimo: Vector2i = atual
	var maximo: Vector2i = atual
	for chave in mapa.visitadas.keys():
		var celula: Vector2i = chave
		minimo.x = mini(minimo.x, celula.x)
		minimo.y = mini(minimo.y, celula.y)
		maximo.x = maxi(maximo.x, celula.x)
		maximo.y = maxi(maximo.y, celula.y)
	centro_mapa = (Vector2(minimo) + Vector2(maximo)) * 0.5
	var largura: float = float(maximo.x - minimo.x + 1) * PASSO
	var altura: float = float(maximo.y - minimo.y + 1) * PASSO
	var disponivel_x: float = maxf(size.x - 136.0, 120.0)
	var disponivel_y: float = maxf(size.y - 200.0, 100.0)
	zoom = clampf(minf(1.30, minf(disponivel_x / largura, disponivel_y / altura)), ZOOM_MIN, ZOOM_MAX)
	arraste = Vector2.ZERO
	queue_redraw()


func _centro_area() -> Vector2:
	return Vector2(size.x * 0.5, (84.0 + size.y - 74.0) * 0.5)


func _posicao_da_sala(celula: Vector2i) -> Vector2:
	return _centro_area() + (Vector2(celula) - centro_mapa) * PASSO * zoom + arraste


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var botao: InputEventMouseButton = evento as InputEventMouseButton
		if botao.button_index == MOUSE_BUTTON_WHEEL_UP and botao.pressed:
			_zoom_no_mouse(1.15, botao.position)
			accept_event()
		elif botao.button_index == MOUSE_BUTTON_WHEEL_DOWN and botao.pressed:
			_zoom_no_mouse(1.0 / 1.15, botao.position)
			accept_event()
		elif botao.button_index == MOUSE_BUTTON_LEFT or botao.button_index == MOUSE_BUTTON_MIDDLE:
			if botao.pressed:
				arrastando = true
				deslocamento_mouse = 0.0
			else:
				if arrastando and modo_teleporte and botao.button_index == MOUSE_BUTTON_LEFT and deslocamento_mouse < 10.0:
					_selecionar_com_mouse(botao.position)
				arrastando = false
			accept_event()
		elif botao.button_index == MOUSE_BUTTON_RIGHT and botao.pressed:
			centralizar()
			accept_event()
	elif evento is InputEventMouseMotion and arrastando:
		var movimento: InputEventMouseMotion = evento as InputEventMouseMotion
		deslocamento_mouse += movimento.relative.length()
		arraste += movimento.relative
		queue_redraw()
		accept_event()


func _selecionar_com_mouse(local: Vector2) -> void:
	if not modo_teleporte or not is_instance_valid(mapa):
		return
	for destino in destinos_teleporte:
		if not mapa.visitadas.has(destino):
			continue
		var centro: Vector2 = _posicao_da_sala(destino)
		var ret: Rect2 = Rect2(centro - TAMANHO_SALA * zoom * 0.5, TAMANHO_SALA * zoom).grow(8.0)
		if ret.has_point(local):
			marcar_destino(destino)
			destino_clicado.emit(destino)
			return


func _zoom_no_mouse(fator: float, pos_mouse: Vector2) -> void:
	var anterior: float = zoom
	zoom = clampf(zoom * fator, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(anterior, zoom):
		return
	# A sala sob o cursor permanece no mesmo ponto da tela ao dar zoom.
	arraste = pos_mouse - _centro_area() - (pos_mouse - _centro_area() - arraste) * (zoom / anterior)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)
	var fonte: Font = get_theme_default_font()
	if fonte == null:
		return

	# Grade discreta ao fundo, sem revelar salas que ainda nao foram visitadas.
	var espacamento: float = 48.0
	for x in range(0, int(size.x / espacamento) + 1):
		draw_line(Vector2(x * espacamento, 78), Vector2(x * espacamento, size.y - 61), COR_GRID, 1.0)
	for y in range(2, int(size.y / espacamento) + 1):
		draw_line(Vector2(0, y * espacamento), Vector2(size.x, y * espacamento), COR_GRID, 1.0)

	# Passagens atras dos modulos: liga somente arestas existentes no grafo.
	if is_instance_valid(mapa):
		for chave in mapa.visitadas.keys():
			var origem: Vector2i = chave
			var conexoes: Dictionary = mapa.obter(origem).get("conexoes", {})
			for direcao in conexoes.keys():
				var delta: Vector2i = direcao
				var destino: Vector2i = conexoes[delta]
				var conhecida: bool = mapa.visitadas.has(destino)
				if conhecida and (destino.x < origem.x or destino.y < origem.y):
					continue # Desenha cada ligacao visitada apenas uma vez.
				var inicio: Vector2 = _posicao_da_sala(origem)
				var vetor: Vector2 = Vector2(delta)
				var meio_tamanho: Vector2 = TAMANHO_SALA * zoom * 0.5
				var borda: Vector2 = inicio + Vector2(vetor.x * meio_tamanho.x, vetor.y * meio_tamanho.y)
				if conhecida:
					var ponta_final: Vector2 = _posicao_da_sala(destino) - Vector2(vetor.x * meio_tamanho.x, vetor.y * meio_tamanho.y)
					draw_line(borda, ponta_final, COR_LIGACAO, maxf(2.0, 5.0 * zoom), true)
				else:
					# Mostra a direcao da saida, mas nao desenha a sala desconhecida.
					var final_curto: Vector2 = borda + vetor * 21.0 * zoom
					draw_line(borda, final_curto, COR_DESCONHECIDO, maxf(2.0, 4.0 * zoom), true)
					draw_circle(final_curto, maxf(2.0, 3.0 * zoom), COR_DESCONHECIDO)

		for chave in mapa.visitadas.keys():
			var pos: Vector2i = chave
			_desenhar_sala(fonte, pos)

	# Cabecalho e rodape cobrindo a grade para leitura consistente.
	draw_rect(Rect2(0, 0, size.x, 79), Color(0.055, 0.105, 0.15, 1.0))
	draw_line(Vector2(0, 78), Vector2(size.x, 78), Color(0.25, 0.71, 0.71), 2.0)
	draw_rect(Rect2(0, size.y - 62, size.x, 62), Color(0.055, 0.105, 0.15, 1.0))
	draw_line(Vector2(0, size.y - 62), Vector2(size.x, size.y - 62), Color(0.20, 0.45, 0.50), 1.0)
	if modo_teleporte:
		_escrever(fonte, "REDE BREAKPOINT // VIAGEM RAPIDA", Vector2(25, 37), 26, COR_TEXTO)
		_escrever(fonte, "WASD/setas: selecionar   Clique: escolher   F: viajar   ESC: cancelar", Vector2(25, 63), 14, Color(0.55, 0.83, 0.83))
		_escrever(fonte, "Destino: %s     Arrastar: mouse esquerdo     Zoom: rodinha     Direita: centralizar" % str(destino_marcado), Vector2(24, size.y - 34), 14, COR_TEXTO)
		_escrever(fonte, "Borda dourada: selecionado    Verde: disponivel    @: voce    Linhas: conexoes reais", Vector2(24, size.y - 12), 12, Color(0.56, 0.74, 0.79))
	else:
		_escrever(fonte, "MAPA DE MEMORIA", Vector2(25, 37), 26, COR_TEXTO)
		_escrever(fonte, "[M / ESC] Fechar     Arrastar: mouse esquerdo     Zoom: rodinha     Centralizar: botao direito", Vector2(25, 63), 14, Color(0.55, 0.83, 0.83))
		_escrever(fonte, "@ Voce     S Inicio     P Patch     B Breakpoint     1/2/3 Chefe     J Pulo     D Dash     F Final", Vector2(24, size.y - 34), 14, COR_TEXTO)
		_escrever(fonte, "Linhas = passagens conectadas     Pontas cinzas = saidas nao exploradas", Vector2(24, size.y - 12), 12, Color(0.56, 0.74, 0.79))
	_escrever(fonte, "%.0f%%" % (zoom * 100.0), Vector2(size.x - 84, 38), 18, COR_TEXTO)


func _desenhar_sala(fonte: Font, pos: Vector2i) -> void:
	var info: Dictionary = mapa.obter(pos)
	var tipo: String = String(info.get("tipo", "normal"))
	var centro: Vector2 = _posicao_da_sala(pos)
	var tamanho: Vector2 = TAMANHO_SALA * zoom
	var ret: Rect2 = Rect2(centro - tamanho * 0.5, tamanho)
	var cor_fundo: Color = Color(0.10, 0.24, 0.32)
	var cor_borda: Color = Color(0.30, 0.58, 0.66)
	var simbolo: String = "·"
	if tipo == "inicio":
		simbolo = "S"
		cor_fundo = Color(0.12, 0.31, 0.36)
	elif tipo == "exception":
		simbolo = "P"
		cor_fundo = Color(0.11, 0.36, 0.30)
		cor_borda = Color(0.36, 0.85, 0.69)
	elif tipo == "breakpoint":
		simbolo = "B"
		cor_fundo = Color(0.32, 0.26, 0.13)
		cor_borda = Color(0.87, 0.69, 0.37)
	elif tipo.begins_with("boss"):
		var n: int = tipo.substr(4).to_int()
		simbolo = "X" if chefes_derrotados.has(n) else str(n)
		cor_fundo = Color(0.34, 0.14, 0.20)
		cor_borda = Color(0.93, 0.40, 0.48)
	elif tipo == "bloqueio_pulo":
		simbolo = "J"
	elif tipo == "bloqueio_dash":
		simbolo = "D"
	elif tipo == "final":
		simbolo = "F"
		cor_fundo = Color(0.32, 0.23, 0.38)
		cor_borda = Color(0.74, 0.49, 0.89)
	if pos == atual:
		cor_borda = Color(0.59, 1.0, 0.90)
		draw_rect(ret.grow(5.0 * zoom), Color(0.25, 0.74, 0.67, 0.30))
		simbolo = "@"
	if modo_teleporte and destinos_teleporte.has(pos):
		cor_borda = Color(0.48, 1.0, 0.72)
		draw_rect(ret.grow(4.0 * zoom), Color(0.18, 0.74, 0.43, 0.22))
		if pos == destino_marcado:
			cor_borda = Color(1.0, 0.84, 0.38)
			draw_rect(ret.grow(7.0 * zoom), Color(0.98, 0.74, 0.22, 0.35))
	draw_rect(ret, cor_fundo, true)
	draw_rect(ret, cor_borda, false, maxf(1.5, 2.0 * zoom))
	var fonte_tamanho: int = maxi(11, roundi(20.0 * zoom))
	var local_texto: Vector2 = centro + Vector2(-tamanho.x * 0.5, float(fonte_tamanho) * 0.34)
	draw_string(fonte, local_texto, simbolo, HORIZONTAL_ALIGNMENT_CENTER, tamanho.x, fonte_tamanho, COR_TEXTO)
	# Pequenos conectores nas quatro bordas deixam a direcao das saidas evidente.
	var ligacoes: Dictionary = info.get("conexoes", {})
	for direcao in ligacoes.keys():
		var d: Vector2i = direcao
		var centro_saida: Vector2 = centro + Vector2(d.x * tamanho.x * 0.5, d.y * tamanho.y * 0.5)
		var barra: Vector2 = Vector2(7.0 * zoom, 7.0 * zoom)
		draw_rect(Rect2(centro_saida - barra * 0.5, barra), Color(0.71, 0.94, 0.91))


func _escrever(fonte: Font, texto: String, posicao: Vector2, tamanho: int, cor: Color) -> void:
	draw_string(fonte, posicao, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho, cor)
