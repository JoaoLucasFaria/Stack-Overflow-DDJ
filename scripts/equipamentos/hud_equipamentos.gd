extends CanvasLayer

## HUD independente da HUDMatriz (nao altera o minimapa nem a UI do Lustosa).
var inventario: EquipamentosAtivos
var titulo: Label
var slot_um: Label
var slot_dois: Label
var status: Label


func _ready() -> void:
    layer = 3
    var fundo: PanelContainer = PanelContainer.new()
    fundo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    fundo.anchor_left = 1.0
    fundo.anchor_top = 1.0
    fundo.anchor_right = 1.0
    fundo.anchor_bottom = 1.0
    fundo.offset_left = -424.0
    fundo.offset_right = -12.0
    fundo.offset_top = -130.0
    fundo.offset_bottom = -10.0
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fundo)
    var coluna: VBoxContainer = VBoxContainer.new()
    coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fundo.add_child(coluna)
    titulo = _criar_label(coluna, 14)
    slot_um = _criar_label(coluna, 13)
    slot_dois = _criar_label(coluna, 13)
    status = _criar_label(coluna, 12)


func _criar_label(pai: VBoxContainer, tamanho: int) -> Label:
    var l: Label = Label.new()
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_size_override("font_size", tamanho)
    l.autowrap_mode = TextServer.AUTOWRAP_OFF
    pai.add_child(l)
    return l


func _process(_delta: float) -> void:
    if not is_instance_valid(inventario):
        return
    titulo.text = "EQUIPAMENTOS  |  F coletar"
    slot_um.text = "[Q] %s  %s" % [inventario.nome_slot(0), _recarga(0)]
    slot_dois.text = "[E] %s  %s" % [inventario.nome_slot(1), _recarga(1)]
    var escudo: String = "ESCUDO " if is_instance_valid(inventario.escudo_ativo) else ""
    var bonus: String = "GOLPE+ " if is_instance_valid(inventario.golpe_preparado) else ""
    var alerta: String = "OVERFLOW! TRAVADO" if inventario.jogador.esta_travado_por_overflow() else ("OVERFLOW MAX! Q/E BLOQUEADOS" if inventario.jogador.overflow_atual >= inventario.jogador.overflow_maximo else "")
    status.text = "STACK %.0f/%.0f  %s%s%s" % [inventario.jogador.overflow_atual, inventario.jogador.overflow_maximo, escudo, bonus, alerta]


func _recarga(indice: int) -> String:
    var tempo: float = inventario.recarga_slot(indice)
    return "(%.1fs)" % tempo if tempo > 0.0 else "(pronto)"
