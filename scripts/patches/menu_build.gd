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
var coluna_utilitarios: VBoxContainer
var painel_refactor: PanelContainer
var lista_refactor: VBoxContainer
var patch_para_remover: StringName = &""
var alternativas_refactor: Array[StringName] = []


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

	# V15.2: ESC fecha o mapa de exploracao antes de abrir o BUILD.
	var mapa_aberto: Node = get_tree().get_first_node_in_group("mapa_exploracao_aberto")

	if mapa_aberto != null:
		var hud_matriz: HUDMatriz = mapa_aberto.get_parent().get_parent() as HUDMatriz

		if hud_matriz != null:
			hud_matriz.alternar_mapa()
			get_viewport().set_input_as_handled()
			return

	if visible and painel_refactor != null and painel_refactor.visible:
		_cancelar_refactor()
		get_viewport().set_input_as_handled()
		return

	# Se o BUILD ja estiver aberto, ESC fecha normalmente.
	if visible:
		fechar()
		get_viewport().set_input_as_handled()
		return

	# Nao abrir BUILD durante coleta ou teleporte.
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
	if painel_refactor != null:
		painel_refactor.visible = false
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

	painel_refactor = PanelContainer.new()
	painel_refactor.anchor_left = 0.24
	painel_refactor.anchor_top = 0.15
	painel_refactor.anchor_right = 0.76
	painel_refactor.anchor_bottom = 0.85
	painel_refactor.mouse_filter = Control.MOUSE_FILTER_STOP
	var estilo_refactor: StyleBoxFlat = StyleBoxFlat.new()
	estilo_refactor.bg_color = Color(0.035, 0.11, 0.15, 1.0)
	estilo_refactor.border_color = Color(0.48, 0.88, 0.72)
	estilo_refactor.set_border_width_all(3)
	painel_refactor.add_theme_stylebox_override("panel", estilo_refactor)
	raiz.add_child(painel_refactor)
	var margem_ref: MarginContainer = MarginContainer.new()
	margem_ref.add_theme_constant_override("margin_left", 16)
	margem_ref.add_theme_constant_override("margin_right", 16)
	margem_ref.add_theme_constant_override("margin_top", 16)
	margem_ref.add_theme_constant_override("margin_bottom", 16)
	painel_refactor.add_child(margem_ref)
	lista_refactor = VBoxContainer.new()
	lista_refactor.add_theme_constant_override("separation", 10)
	margem_ref.add_child(lista_refactor)
	painel_refactor.visible = false

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
	coluna_utilitarios = VBoxContainer.new()
	coluna_utilitarios.add_theme_constant_override("separation", 7)
	coluna_equipamentos.add_child(coluna_utilitarios)

	var utilitarios: InventarioUtilitarios = jogador.utilitarios
	var ids_possuidos: Array[StringName] = []
	for id in [InventarioUtilitarios.REVIVE, InventarioUtilitarios.REROLL, InventarioUtilitarios.TELEPORTE, InventarioUtilitarios.REFACTOR]:
		if utilitarios.quantidade(id) > 0:
			ids_possuidos.append(id)

	# Sem utilitarios: nao exibe nem a secao nem os cartoes com x0.
	if not ids_possuidos.is_empty():
		_secao(coluna_utilitarios, "UTILITARIOS // DATA CACHES")
		for id in ids_possuidos:
			_cartao(
				coluna_utilitarios,
				String(InventarioUtilitarios.NOMES[id]),
				"x%d" % utilitarios.quantidade(id),
				String(InventarioUtilitarios.DESCRICOES[id]),
				Color(0.57, 0.88, 0.74)
			)

		if utilitarios.quantidade(InventarioUtilitarios.TELEPORTE) > 0:
			var botao_tp: Button = Button.new()
			botao_tp.text = "[TELEPORTE] Escolher BREAKPOINT no mapa"
			botao_tp.disabled = pausa_antes_do_menu
			botao_tp.pressed.connect(_usar_teleporte)
			coluna_utilitarios.add_child(botao_tp)

		if utilitarios.quantidade(InventarioUtilitarios.REFACTOR) > 0:
			var botao_refactor: Button = Button.new()
			botao_refactor.text = "[REFACTOR] Substituir um Patch"
			botao_refactor.disabled = pausa_antes_do_menu or gerenciador.slots_ocupados() == 0
			botao_refactor.pressed.connect(_iniciar_refactor)
			coluna_utilitarios.add_child(botao_refactor)

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


func _usar_teleporte() -> void:
	if not visible or pausa_antes_do_menu:
		return

	var jogador_atual = gerenciador.jogador
	if not is_instance_valid(jogador_atual):
		return
	if jogador_atual.utilitarios.quantidade(InventarioUtilitarios.TELEPORTE) <= 0:
		return

	# Usar a MESMA rotina do terminal BREAKPOINT, em vez de passar
	# pela validacao antiga do item que exigia dois terminais descobertos.
	var main: Node = get_tree().get_first_node_in_group("main_campanha")
	if not is_instance_valid(main) or not main.has_method("_ao_abrir_mapa_teleporte"):
		push_warning("[TP] Abra a campanha com F5 para usar o Teleporte.")
		return
	if not main.has_method("_breakpoints_descobertos"):
		push_warning("[TP] A campanha nao encontrou a lista de BREAKPOINTS visitados.")
		return

	var destinos: Array = main.call("_breakpoints_descobertos")
	if destinos.is_empty():
		push_warning("[TP] Ainda nao existe BREAKPOINT visitado nesta run.")
		return

	# O mapa usa a CanvasLayer 22. Esconder o BUILD (layer 25)
	# primeiro e abrir o mapa depois do processamento deste clique.
	fechar()
	call_deferred("_abrir_tp_apos_fechar_build", main)


func _abrir_tp_apos_fechar_build(main: Node) -> void:
	if not is_instance_valid(main):
		return

	var hud_campanha: HUDMatriz = main.get("hud") as HUDMatriz
	if not is_instance_valid(hud_campanha):
		push_warning("[TP] HUD do mapa nao encontrada na campanha.")
		return

	# A selecao usa exatamente o mapa, teclado e confirmacao dos
	# terminais. A flag informa ao Main que esta viagem gasta o item.
	main.set("teleporte_item_ativo", true)
	main.call("_ao_abrir_mapa_teleporte")

	if not hud_campanha.teleporte_ativo:
		main.set("teleporte_item_ativo", false)
		push_warning("[TP] Nao foi possivel abrir o mapa. Verifique se ha transicao em andamento no Output.")
		return
	print("[TP] Mapa de BREAKPOINTS aberto pelo item fast.travel().")


func _iniciar_refactor() -> void:
	if not visible or painel_refactor.visible or pausa_antes_do_menu:
		return
	patch_para_remover = &""
	alternativas_refactor.clear()
	painel_refactor.visible = true
	_desenhar_refactor()

func _cancelar_refactor() -> void:
	painel_refactor.visible = false
	alternativas_refactor.clear()
	patch_para_remover = &""

func _desenhar_refactor() -> void:
	_limpar(lista_refactor)
	var titulo: Label = _rotulo("patch.refactor() | ESC para cancelar", 21, Color(0.54, 0.97, 0.84))
	lista_refactor.add_child(titulo)
	if patch_para_remover == &"":
		lista_refactor.add_child(_rotulo("Selecione o Patch instalado que deseja remover:", 14, Color.WHITE))
		for id in gerenciador.niveis.keys():
			var patch_id: StringName = StringName(id)
			var botao: Button = Button.new()
			botao.text = "%s  LV.%d" % [gerenciador.nome_patch(patch_id), gerenciador.nivel(patch_id)]
			botao.pressed.connect(_selecionar_removido.bind(patch_id))
			lista_refactor.add_child(botao)
	else:
		lista_refactor.add_child(_rotulo("Substituir %s por (todos LV.1):" % gerenciador.nome_patch(patch_para_remover), 15, Color.WHITE))
		for id in alternativas_refactor:
			var botao: Button = Button.new()
			botao.text = "%s | %s" % [gerenciador.nome_patch(id), String(GerenciadorPatches.DESCRICOES[id])]
			botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			botao.custom_minimum_size.y = 65
			botao.pressed.connect(_confirmar_refactor.bind(id))
			lista_refactor.add_child(botao)
	var cancelar: Button = Button.new()
	cancelar.text = "Cancelar (nao gastar item)"
	cancelar.pressed.connect(_cancelar_refactor)
	lista_refactor.add_child(cancelar)

func _selecionar_removido(id: StringName) -> void:
	patch_para_remover = id
	alternativas_refactor = gerenciador.candidatos_refactor(id)
	_desenhar_refactor()

func _confirmar_refactor(novo: StringName) -> void:
	var utilitarios: InventarioUtilitarios = gerenciador.jogador.utilitarios
	if utilitarios.quantidade(InventarioUtilitarios.REFACTOR) <= 0 or not alternativas_refactor.has(novo):
		return
	if not gerenciador.refatorar_patch(patch_para_remover, novo):
		return
	utilitarios.consumir(InventarioUtilitarios.REFACTOR)
	_cancelar_refactor()
	_atualizar_conteudo()


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
