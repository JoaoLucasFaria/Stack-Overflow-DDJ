class_name HUDSuperior
extends CanvasLayer

## V15: barra superior separada da area jogavel (72px).
## Na campanha, evita duplicar as antigas HUDs de HP/STACK e Q/E.
## Nao mostra Patches: ficam apenas no menu BUILD (ESC).
const ALTURA: float = 72.0
const FUNDO: Color = Color(0.045, 0.075, 0.115, 1.0)
const BORDA: Color = Color(0.20, 0.65, 0.68, 1.0)
const TEXTO: Color = Color(0.86, 0.94, 0.97)
const APAGADO: Color = Color(0.48, 0.56, 0.62)

var jogador: Jogador
var inventario: EquipamentosAtivos
var barra_vida: ProgressBar
var barra_stack: ProgressBar
var texto_vida: Label
var texto_stack: Label
var nome_q: Label
var nome_e: Label
var recarga_q: Label
var recarga_e: Label
var habilidade_pulo: Label
var habilidade_dash: Label
var habilidade_grapple: Label
var estilo_stack_normal: StyleBoxFlat
var estilo_stack_alerta: StyleBoxFlat
var ultimo_alerta: bool = false


func configurar(alvo: Jogador, itens: EquipamentosAtivos) -> void:
	jogador = alvo
	inventario = itens
	atualizar()


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo: ColorRect = ColorRect.new()
	fundo.color = FUNDO
	fundo.position = Vector2.ZERO
	fundo.size = Vector2(1152, ALTURA)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var linha: ColorRect = ColorRect.new()
	linha.color = BORDA
	linha.position = Vector2(0, ALTURA - 2)
	linha.size = Vector2(1152, 2)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(linha)

	_criar_rotulo("HP", Vector2(16, 12), Vector2(34, 20), 15, TEXTO)
	_criar_rotulo("STACK", Vector2(16, 40), Vector2(58, 20), 13, TEXTO)
	barra_vida = _criar_barra(Vector2(75, 11), Vector2(158, 19), Color(0.94, 0.29, 0.32))
	barra_stack = _criar_barra(Vector2(75, 39), Vector2(158, 19), Color(0.95, 0.64, 0.23))
	estilo_stack_normal = _estilo(Color(0.95, 0.64, 0.23), 4)
	estilo_stack_alerta = _estilo(Color(0.96, 0.24, 0.30), 4)
	barra_stack.add_theme_stylebox_override("fill", estilo_stack_normal)
	texto_vida = _criar_rotulo("", Vector2(75, 10), Vector2(158, 20), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	texto_stack = _criar_rotulo("", Vector2(75, 38), Vector2(158, 20), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	_criar_quadro(Vector2(250, 9), Vector2(239, 54))
	_criar_quadro(Vector2(497, 9), Vector2(239, 54))
	_criar_rotulo("Q", Vector2(260, 17), Vector2(24, 20), 19, Color(0.51, 0.91, 0.87))
	_criar_rotulo("E", Vector2(507, 17), Vector2(24, 20), 19, Color(0.51, 0.91, 0.87))
	nome_q = _criar_rotulo("", Vector2(289, 13), Vector2(193, 23), 13, TEXTO)
	nome_e = _criar_rotulo("", Vector2(536, 13), Vector2(193, 23), 13, TEXTO)
	recarga_q = _criar_rotulo("", Vector2(289, 39), Vector2(185, 18), 12, Color(0.62, 0.94, 0.75))
	recarga_e = _criar_rotulo("", Vector2(536, 39), Vector2(185, 18), 12, Color(0.62, 0.94, 0.75))

	_criar_quadro(Vector2(753, 9), Vector2(123, 54))
	_criar_quadro(Vector2(884, 9), Vector2(123, 54))
	_criar_quadro(Vector2(1015, 9), Vector2(123, 54))
	_criar_rotulo("ESPAÇO ×2", Vector2(758, 13), Vector2(113, 17), 11, APAGADO, HORIZONTAL_ALIGNMENT_CENTER)
	_criar_rotulo("SHIFT / X", Vector2(889, 13), Vector2(113, 17), 11, APAGADO, HORIZONTAL_ALIGNMENT_CENTER)
	_criar_rotulo("G", Vector2(1020, 13), Vector2(113, 17), 11, APAGADO, HORIZONTAL_ALIGNMENT_CENTER)
	habilidade_pulo = _criar_rotulo("PULO DUPLO", Vector2(758, 35), Vector2(113, 21), 13, APAGADO, HORIZONTAL_ALIGNMENT_CENTER)
	habilidade_dash = _criar_rotulo("DASH", Vector2(889, 35), Vector2(113, 21), 13, APAGADO, HORIZONTAL_ALIGNMENT_CENTER)
	habilidade_grapple = _criar_rotulo("GRAPPLE", Vector2(1020, 35), Vector2(113, 21), 13, APAGADO, HORIZONTAL_ALIGNMENT_CENTER)


func _process(_delta: float) -> void:
	atualizar()


func atualizar() -> void:
	if not is_instance_valid(jogador) or not is_instance_valid(barra_vida):
		return
	barra_vida.max_value = maxf(float(jogador.vida_maxima), 1.0)
	barra_vida.value = jogador.vida_atual
	texto_vida.text = "%d/%d" % [jogador.vida_atual, jogador.vida_maxima]
	barra_stack.max_value = maxf(jogador.overflow_maximo, 1.0)
	barra_stack.value = jogador.overflow_atual
	texto_stack.text = "%d/%d" % [roundi(jogador.overflow_atual), roundi(jogador.overflow_maximo)]
	var alerta: bool = jogador.overflow_atual >= jogador.overflow_maximo or jogador.esta_travado_por_overflow()
	if alerta != ultimo_alerta:
		ultimo_alerta = alerta
		barra_stack.add_theme_stylebox_override("fill", estilo_stack_alerta if alerta else estilo_stack_normal)

	if is_instance_valid(inventario):
		nome_q.text = inventario.nome_slot(0)
		nome_e.text = inventario.nome_slot(1)
		_atualizar_recarga(recarga_q, 0, alerta)
		_atualizar_recarga(recarga_e, 1, alerta)

	_marcar_habilidade(habilidade_pulo, jogador.pulo_duplo_liberado)
	_marcar_habilidade(habilidade_dash, jogador.dash_component.dash_desbloqueado)
	_marcar_habilidade(habilidade_grapple, jogador.grapple_liberado)


func _atualizar_recarga(rotulo: Label, slot: int, travado: bool) -> void:
	if inventario.slots[slot] == &"":
		rotulo.text = "VAZIO"
		rotulo.add_theme_color_override("font_color", APAGADO)
	elif travado:
		rotulo.text = "OVERFLOW!"
		rotulo.add_theme_color_override("font_color", Color(0.98, 0.37, 0.41))
	else:
		var tempo: float = inventario.recarga_slot(slot)
		rotulo.text = "%.1f s" % tempo if tempo > 0.0 else "PRONTO"
		rotulo.add_theme_color_override("font_color", Color(0.98, 0.76, 0.43) if tempo > 0.0 else Color(0.62, 0.94, 0.75))


func _marcar_habilidade(rotulo: Label, liberada: bool) -> void:
	rotulo.add_theme_color_override("font_color", Color(0.58, 0.97, 0.84) if liberada else APAGADO)


func _criar_quadro(posicao: Vector2, tamanho: Vector2) -> void:
	var quadro: PanelContainer = PanelContainer.new()
	quadro.position = posicao
	quadro.size = tamanho
	quadro.custom_minimum_size = tamanho
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quadro.add_theme_stylebox_override("panel", _estilo(Color(0.09, 0.17, 0.22), 5, Color(0.25, 0.49, 0.56)))
	add_child(quadro)


func _criar_barra(posicao: Vector2, tamanho: Vector2, cor: Color) -> ProgressBar:
	var barra: ProgressBar = ProgressBar.new()
	barra.position = posicao
	barra.size = tamanho
	barra.custom_minimum_size = tamanho
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_theme_stylebox_override("background", _estilo(Color(0.12, 0.20, 0.25), 4))
	barra.add_theme_stylebox_override("fill", _estilo(cor, 4))
	add_child(barra)
	return barra


func _estilo(cor: Color, arredondamento: int, contorno: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(arredondamento)
	if contorno.a > 0.0:
		estilo.border_color = contorno
		estilo.set_border_width_all(1)
	return estilo


func _criar_rotulo(texto: String, posicao: Vector2, tamanho: Vector2, fonte: int, cor: Color, alinhamento: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var rotulo: Label = Label.new()
	rotulo.text = texto
	rotulo.position = posicao
	rotulo.size = tamanho
	rotulo.custom_minimum_size = tamanho
	rotulo.clip_text = true
	rotulo.horizontal_alignment = alinhamento
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", fonte)
	rotulo.add_theme_color_override("font_color", cor)
	add_child(rotulo)
	return rotulo
