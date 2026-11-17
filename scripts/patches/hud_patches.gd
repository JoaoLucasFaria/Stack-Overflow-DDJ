extends CanvasLayer

## HUD compacta independente da HUD do Lustosa e dos equipamentos Q/E.
## Quatro slots exibidos no canto inferior esquerdo, sem capturar o mouse.
var gerenciador
var painel: PanelContainer
var rotulo: Label


func _ready() -> void:
	layer = 2
	var raiz: Control = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	painel = PanelContainer.new()
	painel.anchor_left = 0.0
	painel.anchor_right = 0.0
	painel.anchor_top = 1.0
	painel.anchor_bottom = 1.0
	painel.offset_left = 14.0
	painel.offset_right = 310.0
	painel.offset_top = -149.0
	painel.offset_bottom = -12.0
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo: StyleBoxFlat = StyleBoxFlat.new()
	fundo.bg_color = Color(0.055, 0.095, 0.135, 0.70)
	fundo.corner_radius_top_left = 5
	fundo.corner_radius_top_right = 5
	fundo.corner_radius_bottom_left = 5
	fundo.corner_radius_bottom_right = 5
	painel.add_theme_stylebox_override("panel", fundo)
	raiz.add_child(painel)
	var margem: MarginContainer = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 9)
	margem.add_theme_constant_override("margin_right", 9)
	margem.add_theme_constant_override("margin_top", 6)
	margem.add_theme_constant_override("margin_bottom", 6)
	painel.add_child(margem)
	rotulo = Label.new()
	rotulo.add_theme_font_size_override("font_size", 13)
	rotulo.add_theme_color_override("font_color", Color(0.81, 0.94, 0.97))
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(rotulo)
	if is_instance_valid(gerenciador):
		gerenciador.patches_alterados.connect(atualizar)
		atualizar()


func atualizar() -> void:
	if not is_instance_valid(gerenciador) or rotulo == null:
		return
	var linhas: PackedStringArray = ["PATCHES  %d/4  |  ESC: BUILD" % gerenciador.slots_ocupados()]
	for id in gerenciador.niveis.keys():
		linhas.append("• %s  Lv.%d" % [String(gerenciador.nome_patch(id)), gerenciador.nivel(id)])
	for _i in range(4 - gerenciador.slots_ocupados()):
		linhas.append("• [slot livre]")
	rotulo.text = "\n".join(linhas)
