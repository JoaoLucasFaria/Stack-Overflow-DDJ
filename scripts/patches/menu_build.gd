extends CanvasLayer

## Menu da build atual, aberto com ESC. O jogo pausa enquanto estiver visivel.
## Como pertence ao GerenciadorPatches do jogador, funciona na campanha
## e nas arenas de teste, sem alterar as cenas existentes.
var gerenciador
const MAX_SLOTS: int = 4
const MAX_NIVEL: int = 5

var inventario
var processava_inventario: bool = false
var pausa_antes_do_menu: bool = false
var permitir_abertura_pausada: bool = false
var texto_resumo: Label
var coluna_equipamentos: VBoxContainer
var coluna_patches: VBoxContainer


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_criar_interface()
	visible = false


func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla: InputEventKey = evento as InputEventKey
	if not tecla.pressed or tecla.echo or not evento.is_action_pressed("ui_cancel"):
		return
	if visible:
		fechar()
		get_viewport().set_input_as_handled()
		return
	# ESC tambem cancela a coleta de equipamentos e o mapa de teleporte.
	# Nesses casos, o jogo ja esta pausado e o menu nao pode abrir.
	if get_tree().paused or not is_instance_valid(gerenciador):
		return
	var jogador = gerenciador.jogador
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	var itens = jogador.get_node_or_null("EquipamentosAtivos")
	if itens != null and itens.coleta_aberta:
		return
	abrir()
	get_viewport().set_input_as_handled()


## Usado apenas pela escolha obrigatoria do Exception Handler.
## O BUILD pode abrir mesmo com a partida pausada pela recompensa.
func abrir_durante_recompensa() -> void:
	permitir_abertura_pausada = true
	abrir()
	permitir_abertura_pausada = false


func abrir() -> void:
	if visible or not is_instance_valid(gerenciador):
		return
	if get_tree().paused and not permitir_abertura_pausada:
		return
	var jogador = gerenciador.jogador
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	pausa_antes_do_menu = get_tree().paused
	inventario = jogador.get_node_or_null("EquipamentosAtivos")
	# EquipamentosAtivos processa em PROCESS_MODE_ALWAYS para permitir a
	# confirmacao da coleta; evita usar Q/E enquanto inspeciona a build.
	if inventario != null:
		processava_inventario = inventario.is_physics_processing()
		inventario.set_physics_process(false)
	_atualizar_conteudo()
	visible = true
	get_tree().paused = true


func fechar() -> void:
	if not visible:
		return
	visible = false
	# Se o BUILD foi aberto sobre uma recompensa, retorna a essa pausa.
	get_tree().paused = pausa_antes_do_menu
	if is_instance_valid(inventario):
		inventario.set_physics_process(processava_inventario)
	inventario = null


func _criar_interface() -> void:
	var raiz: Control = Control.new()
	raiz.anchor_right = 1.0
	raiz.anchor_bottom = 1.0
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	var sombra: ColorRect = ColorRect.new()
	sombra.color = Color(0.015, 0.025, 0.045, 0.90)
	sombra.anchor_right = 1.0
	sombra.anchor_bottom = 1.0
	sombra.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(sombra)

	var painel: PanelContainer = PanelContainer.new()
	painel.anchor_left = 0.055
	painel.anchor_top = 0.075
	painel.anchor_right = 0.945
	painel.anchor_bottom = 0.925
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.055, 0.092, 0.14, 0.98)
	estilo.border_color = Color(0.23, 0.68, 0.77)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(11)
	painel.add_theme_stylebox_override("panel", estilo)
	raiz.add_child(painel)

	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 22)
	for lado in ["top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 17)
	painel.add_child(margem)

	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)

	var topo: HBoxContainer = HBoxContainer.new()
	coluna.add_child(topo)
	var titulo: Label = _rotulo("BUILD // PROCESSO ATUAL", 23, Color(0.58, 0.95, 0.94))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	var fechar_botao: Button = Button.new()
	fechar_botao.text = "Fechar  [ESC]"
	fechar_botao.pressed.connect(fechar)
	topo.add_child(fechar_botao)

	texto_resumo = _rotulo("", 14, Color(0.83, 0.92, 0.96))
	coluna.add_child(texto_resumo)
	coluna.add_child(HSeparator.new())

	var rolagem: ScrollContainer = ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	coluna.add_child(rolagem)

	var conteudo: HBoxContainer = HBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", 16)
	rolagem.add_child(conteudo)

	coluna_equipamentos = VBoxContainer.new()
	coluna_equipamentos.custom_minimum_size.x = 320.0
	coluna_equipamentos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna_equipamentos.size_flags_stretch_ratio = 0.9
	coluna_equipamentos.add_theme_constant_override("separation", 9)
	conteudo.add_child(coluna_equipamentos)

	coluna_patches = VBoxContainer.new()
	coluna_patches.custom_minimum_size.x = 420.0
	coluna_patches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna_patches.size_flags_stretch_ratio = 1.2
	coluna_patches.add_theme_constant_override("separation", 9)
	conteudo.add_child(coluna_patches)

	var rodape: Label = _rotulo("ESC: fechar BUILD   |   Os Patches permanecem ate a morte da run.", 12, Color(0.56, 0.77, 0.83))
	coluna.add_child(rodape)


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo: Label = Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo


func _secao(pai: VBoxContainer, titulo: String) -> void:
	pai.add_child(_rotulo(titulo, 17, Color(0.49, 0.87, 0.93)))


func _cartao(pai: VBoxContainer, titulo: String, detalhe: String, descricao: String, cor: Color) -> void:
	var cartao: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.085, 0.145, 0.195, 0.94)
	estilo.border_color = Color(0.15, 0.29, 0.35)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	cartao.add_theme_stylebox_override("panel", estilo)
	pai.add_child(cartao)

	var margem: MarginContainer = MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 11)
	margem.add_theme_constant_override("margin_right", 11)
	margem.add_theme_constant_override("margin_top", 8)
	margem.add_theme_constant_override("margin_bottom", 8)
	cartao.add_child(margem)
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	margem.add_child(coluna)
	coluna.add_child(_rotulo(titulo, 15, cor))
	if not detalhe.is_empty():
		coluna.add_child(_rotulo(detalhe, 12, Color(0.56, 0.83, 0.82)))
	if not descricao.is_empty():
		coluna.add_child(_rotulo(descricao, 13, Color(0.86, 0.91, 0.94)))


func _limpar(pai: VBoxContainer) -> void:
	for controle in pai.get_children():
		controle.free()


func _atualizar_conteudo() -> void:
	var jogador = gerenciador.jogador
	if not is_instance_valid(jogador):
		return
	var custo_stack: float = gerenciador.multiplicador_stack_equipamento() * 100.0
	texto_resumo.text = "HP %d/%d    |    STACK %.0f/%.0f    |    PATCHES %d/%d    |    Custo Q/E: %.0f%%" % [
		jogador.vida_atual, jogador.vida_maxima, jogador.overflow_atual,
		jogador.overflow_maximo, gerenciador.slots_ocupados(), MAX_SLOTS,
		custo_stack
	]
	_limpar(coluna_equipamentos)
	_limpar(coluna_patches)

	_secao(coluna_equipamentos, "EQUIPAMENTOS // Q + E")
	for indice in range(2):
		var tecla: String = "Q" if indice == 0 else "E"
		var id: StringName = &""
		if inventario != null and indice < inventario.slots.size():
			id = inventario.slots[indice]
		if id == &"":
			_cartao(coluna_equipamentos, "[%s] SLOT LIVRE" % tecla, "Nenhum equipamento", "Colete drops com F para equipar.", Color(0.57, 0.69, 0.75))
			continue
		var constantes: Dictionary = inventario.get_script().get_script_constant_map()
		var nomes: Dictionary = constantes.get("NOMES", {})
		var efeitos: Dictionary = constantes.get("EFEITOS", {})
		var titulo: String = String(nomes.get(id, String(id)))
		var efeito: String = String(efeitos.get(id, "Sem descricao registrada."))
		var recarga: float = float(inventario.recargas.get(id, 0.0))
		var situacao: String = "PRONTO" if recarga <= 0.0 else "Recarga restante: %.1f s" % recarga
		_cartao(coluna_equipamentos, "[%s] %s" % [tecla, titulo], situacao, efeito, Color(0.91, 0.81, 0.49))

	_secao(coluna_equipamentos, "HABILIDADES // PROGRESSAO")
	var dash: bool = is_instance_valid(jogador.dash_component) and jogador.dash_component.dash_desbloqueado
	var habilidades: String = "Wall Jump: disponivel desde o inicio.\n"
	habilidades += "Pulo duplo: %s\n" % ("DESBLOQUEADO" if jogador.pulo_duplo_liberado else "bloqueado")
	habilidades += "Dash (malloc): %s\n" % ("DESBLOQUEADO" if dash else "bloqueado")
	habilidades += "Grapple: %s" % ("DESBLOQUEADO" if jogador.grapple_liberado else "bloqueado")
	_cartao(coluna_equipamentos, "Habilidades da run", "Concedidas pelos chefes", habilidades, Color(0.56, 0.89, 0.94))

	_secao(coluna_patches, "PATCHES // EFEITOS NO NIVEL ATUAL")
	for id in gerenciador.niveis.keys():
		var patch_id: StringName = StringName(id)
		var lvl: int = gerenciador.nivel(patch_id)
		var titulo: String = String(gerenciador.nome_patch(patch_id))
		var info: String = gerenciador.descricao_nivel(patch_id, lvl)
		var estado: String = _estado_patch(patch_id)
		if not estado.is_empty():
			info += "\nEstado atual: " + estado
		_cartao(coluna_patches, titulo, "NIVEL %d / %d" % [lvl, MAX_NIVEL], info, Color(0.57, 0.98, 0.77))
	for _i in range(MAX_SLOTS - gerenciador.slots_ocupados()):
		_cartao(coluna_patches, "SLOT DE PATCH LIVRE", "Disponivel nesta run", "Conclua um Exception Handler para instalar um novo Patch.", Color(0.57, 0.69, 0.75))


func _estado_patch(id: StringName) -> String:
	match id:
		&"try_catch":
			if gerenciador.tempo_try_catch <= 0.0:
				return "protecao pronta"
			return "%.1f s para recarregar" % gerenciador.tempo_try_catch
		&"watchdog":
			var necessario: int = maxi(2, 7 - gerenciador.nivel(id))
			return "%d/%d abates para proxima cura" % [gerenciador.abates_watchdog, necessario]
		&"memory_cache":
			return "buff ativo por %.1f s" % gerenciador.tempo_memory_cache if gerenciador.tempo_memory_cache > 0.0 else "aguardando dano recebido"
		&"parallel_execution":
			return "golpe adicional preparado" if gerenciador.paralelo_preparado else "aguardando uso de Q/E"
	return ""
