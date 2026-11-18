class_name ControladorExceptionHandler
extends Node2D

## Arena reutilizavel. Na V13 funciona em cena de teste; na V14 sera
## instanciada numa sala procedural e recebera o jogador da campanha.
## O altar so pode recompensar uma vez na mesma run.
signal desafio_ativado
signal desafio_concluido(patch_id: StringName)
signal desafio_falhou

enum Estado { PRONTO, COMBATE, RECOMPENSA, CONCLUIDO, FALHOU }

const ALTAR: Vector2 = Vector2(576, 544)
const DISTANCIA_INTERACAO: float = 105.0
# Por padrao sao 3 ondas com 3 processos. Para testar 2x4, altere
# total_ondas=2 e inimigos_por_onda=4 neste script (campanha instancia por codigo).
const SPAWN_X_3: Array[float] = [300.0, 576.0, 852.0]
const SPAWN_X_4: Array[float] = [250.0, 465.0, 685.0, 900.0]
const CENAS: Dictionary = {
	"syntax_error": preload("res://cenas/inimigos/inimigo_syntax_error.tscn"),
	"memory_leak": preload("res://cenas/inimigos/inimigo_memory_leak.tscn"),
	"segmentation_fault": preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn"),
	"null_pointer": preload("res://cenas/inimigos/inimigo_null_pointer.tscn"),
	"fork_bomb": preload("res://cenas/inimigos/inimigo_fork_bomb.tscn"),
	"race_condition": preload("res://cenas/inimigos/inimigo_race_condition.tscn"),
	"deadlock": preload("res://cenas/inimigos/inimigo_deadlock.tscn"),
	"out_of_bounds": preload("res://cenas/inimigos/inimigo_out_of_bounds.tscn")
}
const LEVES: Array[String] = ["syntax_error", "memory_leak"]
const MEDIOS: Array[String] = ["null_pointer", "segmentation_fault", "race_condition"]
const ESPECIAIS: Array[String] = ["deadlock", "out_of_bounds", "fork_bomb"]

@export_category("Exception Handler")
@export var permitir_fork_bomb: bool = false
@export_range(2, 3, 1) var total_ondas: int = 3
@export_range(3, 4, 1) var inimigos_por_onda: int = 3
@export_range(0.5, 3.0, 0.1) var intervalo_entre_ondas: float = 1.5
@export_range(80.0, 200.0, 5.0) var distancia_ativacao: float = 105.0

var jogador: Jogador
var estado: Estado = Estado.PRONTO
var onda_atual: int = 0
var espera_proxima_onda: float = -1.0
var inimigos_raiz: Array[InimigoBase] = []
var ultimo_patch: StringName = &""
var conteudo: Node2D
var plataformas: Node2D
var bloqueios: Node2D
var entidades: Node2D
var efeitos: Node2D
var interface: CanvasLayer
var status: Label
var instrucao: Label
var painel_recompensa: PanelContainer
var rotulo_opcoes: Label
var botoes: Array[Button] = []
var opcoes: Array[StringName] = []
var selecionado: int = 0
var inventario: EquipamentosAtivos
var inventario_processava: bool = true


func configurar(alvo: Jogador, fork_liberada: bool = false) -> void:
	jogador = alvo
	permitir_fork_bomb = fork_liberada
	if is_instance_valid(jogador) and not jogador.morreu.is_connected(_ao_jogador_morrer):
		jogador.morreu.connect(_ao_jogador_morrer)


func _ready() -> void:
	# O controlador e a interface recebem F/W/S mesmo com o jogo pausado.
	# Todas as entidades de combate ficam sob um no explicitamente PAUSABLE.
	process_mode = Node.PROCESS_MODE_ALWAYS
	conteudo = Node2D.new()
	conteudo.name = "ElementosDaArena"
	conteudo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(conteudo)
	plataformas = _grupo("PlataformasTemporarias")
	bloqueios = _grupo("PortasTemporarias")
	entidades = _grupo("EntidadesDesafio")
	efeitos = _grupo("EfeitosDeEntrada")
	_criar_interface()
	queue_redraw()


func _grupo(nome: String) -> Node2D:
	var no: Node2D = Node2D.new()
	no.name = nome
	conteudo.add_child(no)
	return no


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida") and estado == Estado.FALHOU:
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	if get_tree().paused:
		return
	if not is_instance_valid(jogador):
		return
	if estado == Estado.PRONTO:
		instrucao.text = "EXCEPTION HANDLER  |  Aproxime-se do altar e aperte F" if _perto_do_altar() else "Encontre o altar para iniciar o desafio"
	elif estado == Estado.COMBATE:
		# Protecao contra inimigos que saem da cena sem emitir 'derrotado'
		# (por exemplo, Fork Bomb sem superficie valida para fixacao).
		_verificar_fim_da_onda()
		if espera_proxima_onda >= 0.0:
			espera_proxima_onda -= delta
			if espera_proxima_onda <= 0.0:
				espera_proxima_onda = -1.0
				_iniciar_onda()


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_pressed() or (evento is InputEventKey and (evento as InputEventKey).echo):
		return
	if estado == Estado.PRONTO and not get_tree().paused:
		if evento.is_action_pressed("coletar_item") and _perto_do_altar():
			ativar_desafio()
			get_viewport().set_input_as_handled()
	elif estado == Estado.RECOMPENSA:
		if not is_instance_valid(jogador) or not is_instance_valid(jogador.patches):
			return
		var menu_build: CanvasLayer = jogador.patches.menu
		# Com BUILD aberto, as teclas nao podem alterar a recompensa por tras.
		if is_instance_valid(menu_build) and menu_build.visible:
			return
		if evento.is_action_pressed("ui_up") or evento.is_action_pressed("ui_left"):
			_selecionar((selecionado - 1 + opcoes.size()) % maxi(1, opcoes.size()))
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("ui_down") or evento.is_action_pressed("ui_right"):
			_selecionar((selecionado + 1) % maxi(1, opcoes.size()))
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("coletar_item"):
			_confirmar_patch()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("ui_cancel"):
			# ESC consulta a build, sem abandonar a escolha obrigatoria.
			if is_instance_valid(menu_build):
				menu_build.call("abrir_durante_recompensa")
			get_viewport().set_input_as_handled()


func _perto_do_altar() -> bool:
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return false
	return (jogador.global_position + Vector2(20, 20)).distance_to(to_global(ALTAR)) <= minf(DISTANCIA_INTERACAO, distancia_ativacao)


func ativar_desafio() -> void:
	if estado != Estado.PRONTO or not is_instance_valid(jogador) or get_tree().paused:
		return
	estado = Estado.COMBATE
	desafio_ativado.emit()
	_erguer_portas()
	_criar_plataformas()
	status.text = "EXCEPTION HANDLER  |  INICIANDO ..."
	instrucao.text = "Portas bloqueadas. Sobreviva a %d ondas, sem descanso nem drops." % total_ondas
	espera_proxima_onda = 0.9
	queue_redraw()


func _criar_plataformas() -> void:
	# Estas plataformas so existem durante as ondas e auxiliam o combate
	# contra inimigos aereos. One-way: o jogador consegue subir por baixo.
	_plataforma(Vector2(310, 460), Vector2(240, 16))
	_plataforma(Vector2(842, 460), Vector2(240, 16))
	_plataforma(Vector2(576, 328), Vector2(210, 16))


func _plataforma(posicao: Vector2, tamanho: Vector2) -> void:
	var corpo: StaticBody2D = StaticBody2D.new()
	corpo.position = posicao
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	plataformas.add_child(corpo)
	var col: CollisionShape2D = CollisionShape2D.new()
	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = tamanho
	col.shape = forma
	col.one_way_collision = true
	corpo.add_child(col)
	var visual: ColorRect = ColorRect.new()
	visual.position = -tamanho * 0.5
	visual.size = tamanho
	visual.color = Color(0.32, 0.65, 0.73, 0.96)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(visual)


func _erguer_portas() -> void:
	for x in [55.0, 1097.0]:
		var corpo: StaticBody2D = StaticBody2D.new()
		corpo.position = Vector2(x, 327)
		corpo.collision_layer = 1
		corpo.collision_mask = 0
		bloqueios.add_child(corpo)
		var col: CollisionShape2D = CollisionShape2D.new()
		var forma: RectangleShape2D = RectangleShape2D.new()
		forma.size = Vector2(20, 546)
		col.shape = forma
		corpo.add_child(col)
		var visual: ColorRect = ColorRect.new()
		visual.position = Vector2(-10, -273)
		visual.size = Vector2(20, 546)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.color = Color(0.86, 0.23, 0.37, 0.85)
		corpo.add_child(visual)


func _iniciar_onda() -> void:
	if estado != Estado.COMBATE or not is_instance_valid(jogador):
		return
	if onda_atual >= total_ondas:
		_abrir_recompensa()
		return
	onda_atual += 1
	inimigos_raiz.clear()
	var tipos: Array[String] = _sortear_onda(onda_atual)
	for indice in range(tipos.size()):
		_criar_inimigo(tipos[indice], indice)
	status.text = "EXCEPTION HANDLER  |  ONDA %d/%d" % [onda_atual, total_ondas]
	instrucao.text = "Derrote os %d processos. Nenhum deles gera equipamentos." % tipos.size()
	# A criacao pode ser recusada por scripts de ancoragem; a verificacao
	# automatica garante que a arena nao fique travada nesse caso.
	queue_redraw()


func _sortear_onda(numero: int) -> Array[String]:
	## Escolhas aleatorias, com escalada: leves -> medios -> um especial.
	## Evita duplicar um tipo na mesma onda enquanto houver alternativas.
	var escolhidos: Array[String] = []
	for i in range(inimigos_por_onda):
		var grupo: Array[String] = LEVES
		if numero == total_ondas and i == inimigos_por_onda - 1:
			grupo = ESPECIAIS.duplicate()
			if not permitir_fork_bomb:
				grupo.erase("fork_bomb")
		elif numero == 1:
			grupo = LEVES if i < 2 else MEDIOS
		elif numero == total_ondas:
			grupo = MEDIOS
		else:
			grupo = LEVES if i == 0 else MEDIOS
		var disponiveis: Array[String] = grupo.duplicate()
		for anterior in escolhidos:
			disponiveis.erase(anterior)
		if disponiveis.is_empty():
			disponiveis = grupo.duplicate()
		escolhidos.append(_sorte(disponiveis))
	escolhidos.shuffle()
	return escolhidos


func _sorte(opcoes_validas: Array[String]) -> String:
	return opcoes_validas[randi_range(0, opcoes_validas.size() - 1)]


func _criar_inimigo(tipo: String, indice: int) -> void:
	var cena: PackedScene = CENAS.get(tipo) as PackedScene
	if cena == null:
		push_warning("Inimigo de desafio desconhecido: " + tipo)
		return
	var inimigo: InimigoBase = cena.instantiate() as InimigoBase
	if inimigo == null:
		return
	# Posicoes distintas para 3 ou 4 inimigos por onda.
	var posicoes: Array[float] = SPAWN_X_4 if inimigos_por_onda == 4 else SPAWN_X_3
	var spawn_x: float = posicoes[indice % posicoes.size()]
	inimigo.configurar(jogador)
	# Sem drops, inclusive ao matar Fork Bomb; seus filhos ja nao dropam.
	inimigo.chance_drop_percentual = 0
	# Posicao inicial ANTES de entrar na arvore, evitando a ancoragem
	# incorreta de inimigos fixos.
	if tipo == "segmentation_fault":
		# Excecao importante: a torreta precisa chegar junto da parede
		# para o raycast de ancoragem encontrar uma face horizontal.
		inimigo.position = Vector2(91.0 if spawn_x < 576.0 else 1061.0, 376.0)
		_sinalizar_lancamento(Vector2(576, 474), inimigo.position)
	elif tipo == "fork_bomb" or tipo == "out_of_bounds":
		inimigo.position = Vector2(spawn_x, 402.0)
		_sinalizar_lancamento(Vector2(576, 474), inimigo.position)
	else:
		inimigo.position = Vector2(spawn_x, 468.0)
	entidades.add_child(inimigo)
	inimigos_raiz.append(inimigo)
	inimigo.derrotado.connect(_ao_inimigo_derrotado.bind(inimigo))
	if tipo != "segmentation_fault" and tipo != "fork_bomb" and tipo != "out_of_bounds":
		# Impulso lateral curto para simular lancamento do altar.
		inimigo.aplicar_empurrao(to_global(ALTAR + Vector2(0, -70)), 425.0, 0.36)


func _sinalizar_lancamento(inicio: Vector2, destino: Vector2) -> void:
	var linha: Line2D = Line2D.new()
	linha.points = PackedVector2Array([inicio, destino])
	linha.width = 3.0
	linha.default_color = Color(0.62, 0.96, 0.92, 0.85)
	efeitos.add_child(linha)
	var efeito: Tween = create_tween()
	efeito.tween_property(linha, "modulate:a", 0.0, 0.32)
	efeito.tween_callback(linha.queue_free)


func _ao_inimigo_derrotado(_pos: Vector2, _item: StringName, _drop: bool, _inimigo: InimigoBase) -> void:
	if estado != Estado.COMBATE:
		return
	_verificar_fim_da_onda()


func _verificar_fim_da_onda() -> void:
	if estado != Estado.COMBATE or espera_proxima_onda >= 0.0 or onda_atual == 0:
		return
	for i in range(inimigos_raiz.size() - 1, -1, -1):
		var inimigo: InimigoBase = inimigos_raiz[i]
		if not is_instance_valid(inimigo):
			inimigos_raiz.remove_at(i)
		elif inimigo.is_queued_for_deletion() or inimigo.encerrado:
			# Algumas criaturas de teto desistem do spawn quando nao ha
			# apoio valido. Nao deixa a onda com apenas um oponente.
			var falha_ancoragem: bool = not inimigo.encerrado
			inimigos_raiz.remove_at(i)
			if falha_ancoragem:
				print("[EXCEPTION] Spawn sem apoio: substituindo por Syntax Error")
				_criar_inimigo("syntax_error", i % inimigos_por_onda)
	if not inimigos_raiz.is_empty():
		return
	# Limpa clones, Child Processes, correntes e projeteis que sobraram.
	for nodo in entidades.get_children():
		nodo.queue_free()
	inimigos_raiz.clear()
	espera_proxima_onda = intervalo_entre_ondas
	instrucao.text = "ONDA %d CONCLUIDA! Proxima execucao em breve..." % onda_atual


func _abrir_recompensa() -> void:
	if estado != Estado.COMBATE or not is_instance_valid(jogador) or not is_instance_valid(jogador.patches):
		return
	# Reposiciona seguranca em cena, remove projeteis e abre saidas.
	for nodo in entidades.get_children():
		nodo.queue_free()
	for nodo in bloqueios.get_children():
		nodo.queue_free()
	for nodo in plataformas.get_children():
		nodo.queue_free()
	estado = Estado.RECOMPENSA
	status.text = "EXCEPTION HANDLED  |  RECOMPENSA"
	instrucao.text = "Escolha um Patch para concluir o desafio"
	opcoes = jogador.patches.opcoes_recompensa(3)
	if opcoes.is_empty():
		# So ocorre quando todos os Patches instalados chegaram ao nivel 5.
		_concluir_sem_recompensa()
		return
	selecionado = 0
	_montar_opcoes()
	painel_recompensa.visible = true
	inventario = jogador.get_node_or_null("EquipamentosAtivos") as EquipamentosAtivos
	if inventario != null:
		inventario_processava = inventario.is_physics_processing()
		inventario.set_physics_process(false)
	get_tree().paused = true
	queue_redraw()


func _montar_opcoes() -> void:
	for botao in botoes:
		if is_instance_valid(botao):
			botao.queue_free()
	botoes.clear()
	for i in range(opcoes.size()):
		var id: StringName = opcoes[i]
		var atual: int = jogador.patches.nivel(id)
		var alvo: int = atual + 1
		var botao: Button = Button.new()
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.custom_minimum_size = Vector2(0, 111)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.focus_mode = Control.FOCUS_NONE  # Enter/Espaco nao confirmam.
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.text = "%s   %s  Lv.%d -> Lv.%d\n%s" % [
			"NOVO" if atual == 0 else "UPGRADE", jogador.patches.nome_patch(id), atual, alvo,
			jogador.patches.descricao_nivel(id, alvo)
		]
		botao.pressed.connect(_selecionar.bind(i))
		rotulo_opcoes.get_parent().add_child(botao)
		botoes.append(botao)
	_selecionar(0)


func _selecionar(indice: int) -> void:
	if estado != Estado.RECOMPENSA or indice < 0 or indice >= opcoes.size():
		return
	selecionado = indice
	for i in range(botoes.size()):
		botoes[i].modulate = Color(0.61, 1.0, 0.85) if i == selecionado else Color(0.74, 0.83, 0.91)
	rotulo_opcoes.text = "[W/S ou clique] Selecionar  |  [F] Confirmar  |  [ESC] Consultar BUILD"


func _confirmar_patch() -> void:
	if estado != Estado.RECOMPENSA or selecionado < 0 or selecionado >= opcoes.size():
		return
	var escolhido: StringName = opcoes[selecionado]
	if not jogador.patches.instalar_patch(escolhido):
		# Se outro sistema alterou a build durante o menu, revalida.
		opcoes = jogador.patches.opcoes_recompensa(3)
		if opcoes.is_empty():
			_concluir_sem_recompensa()
		else:
			_montar_opcoes()
		return
	ultimo_patch = escolhido
	_encerrar_menu_recompensa()
	estado = Estado.CONCLUIDO
	status.text = "EXCEPTION HANDLED  |  PATCH INSTALADO"
	instrucao.text = "%s Lv.%d instalado. Altar esgotado nesta run." % [jogador.patches.nome_patch(escolhido), jogador.patches.nivel(escolhido)]
	desafio_concluido.emit(escolhido)
	queue_redraw()


func _concluir_sem_recompensa() -> void:
	_encerrar_menu_recompensa()
	estado = Estado.CONCLUIDO
	status.text = "EXCEPTION HANDLED  |  BUILD MAXIMIZADA"
	instrucao.text = "Todos os Patches da build ja atingiram Lv.5."
	desafio_concluido.emit(&"")
	queue_redraw()


func _encerrar_menu_recompensa() -> void:
	painel_recompensa.visible = false
	get_tree().paused = false
	if is_instance_valid(inventario):
		inventario.aguardar_soltar_f = true
		inventario.set_physics_process(inventario_processava)
	inventario = null


func _ao_jogador_morrer() -> void:
	if estado == Estado.CONCLUIDO or estado == Estado.FALHOU:
		return
	estado = Estado.FALHOU
	get_tree().paused = false
	painel_recompensa.visible = false
	status.text = "PROCESSO ENCERRADO  |  R PARA REINICIAR"
	instrucao.text = "O desafio falhou. A run terminou."
	desafio_falhou.emit()


func restaurar_concluido() -> void:
	## Entrada para persistencia externa da V14.
	if estado != Estado.PRONTO:
		return
	estado = Estado.CONCLUIDO
	status.text = "EXCEPTION HANDLED  |  JA CONCLUIDO"
	instrucao.text = "Este altar ja foi utilizado nesta run."
	queue_redraw()


func _criar_interface() -> void:
	interface = CanvasLayer.new()
	interface.name = "InterfaceExceptionHandler"
	interface.layer = 18
	interface.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(interface)
	var raiz: Control = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.add_child(raiz)
	status = Label.new()
	status.position = Vector2(350, 94)
	status.size = Vector2(470, 30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 21)
	status.add_theme_color_override("font_color", Color(0.61, 0.97, 0.91))
	status.text = "EXCEPTION HANDLER  |  AGUARDANDO"
	raiz.add_child(status)
	instrucao = Label.new()
	instrucao.position = Vector2(255, 132)
	instrucao.size = Vector2(650, 30)
	instrucao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instrucao.add_theme_font_size_override("font_size", 14)
	instrucao.text = "Aproxime-se do altar e aperte F."
	raiz.add_child(instrucao)
	painel_recompensa = PanelContainer.new()
	painel_recompensa.anchor_left = 0.14
	painel_recompensa.anchor_top = 0.13
	painel_recompensa.anchor_right = 0.86
	painel_recompensa.anchor_bottom = 0.88
	painel_recompensa.mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo: StyleBoxFlat = StyleBoxFlat.new()
	fundo.bg_color = Color(0.045, 0.075, 0.125, 0.98)
	fundo.border_color = Color(0.25, 0.75, 0.73)
	fundo.set_border_width_all(2)
	fundo.set_corner_radius_all(9)
	painel_recompensa.add_theme_stylebox_override("panel", fundo)
	raiz.add_child(painel_recompensa)
	var margem: MarginContainer = MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 17)
	painel_recompensa.add_child(margem)
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 13)
	margem.add_child(coluna)
	var titulo: Label = Label.new()
	titulo.text = "EXCEPTION HANDLED  //  SELECIONE UM PATCH"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 21)
	titulo.add_theme_color_override("font_color", Color(0.61, 0.97, 0.91))
	coluna.add_child(titulo)
	var descricao: Label = Label.new()
	descricao.text = "%d processos compilados. Escolha UM Patch para sua run." % (total_ondas * inimigos_por_onda)
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(descricao)
	rotulo_opcoes = Label.new()
	rotulo_opcoes.text = "W/S ou mouse para selecionar; F para confirmar"
	rotulo_opcoes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(rotulo_opcoes)
	painel_recompensa.visible = false


func _draw() -> void:
	# Altar pixel-like; a colmeia, o jogador e o cenario continuam 2D.
	var base: Color = Color(0.23, 0.77, 0.76) if estado != Estado.FALHOU else Color(0.48, 0.17, 0.22)
	draw_rect(Rect2(ALTAR + Vector2(-23, -9), Vector2(46, 61)), Color(0.04, 0.13, 0.21), true)
	draw_rect(Rect2(ALTAR + Vector2(-23, -9), Vector2(46, 61)), base, false, 3)
	draw_rect(Rect2(ALTAR + Vector2(-11, -19), Vector2(22, 27)), base, true)
	draw_line(ALTAR + Vector2(-9, -25), ALTAR + Vector2(0, -40), Color(0.56, 1, 0.95), 3)
	draw_line(ALTAR + Vector2(0, -40), ALTAR + Vector2(9, -25), Color(0.56, 1, 0.95), 3)
