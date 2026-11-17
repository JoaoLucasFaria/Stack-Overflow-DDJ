extends Node2D

## Laboratorio permanente de itens: os tipos sao lidos do proprio inventario.
## Qualquer item novo adicionado a EquipamentosAtivos.CENAS aparece aqui
## automaticamente, sem precisar editar esta lista.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_DROP: PackedScene = preload("res://cenas/inimigos/drop_provisorio.tscn")
const CENA_TERMINAL: PackedScene = preload("res://cenas/descanso/terminal_breakpoint.tscn")
const CENA_MEMORY: PackedScene = preload("res://cenas/inimigos/inimigo_memory_leak.tscn")
const CENA_SEGFAULT: PackedScene = preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")

@export var colunas_itens: int = 7
@export var espacamento_horizontal: float = 141.0
@export var espacamento_vertical: float = 66.0
var jogador: Jogador
var instrucoes: Label


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.position = Vector2(70.0, 544.0)
	jogador.vida_maxima = 30
	jogador.vida_atual = 30
	jogador.desbloquear_pulo_duplo()
	jogador.desbloquear_dash()
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	inventario.aviso.connect(func(texto: String) -> void: print("[LAB ITENS] ", texto))
	_criar_mostruario_itens()
	var terminal: Area2D = CENA_TERMINAL.instantiate() as Area2D
	add_child(terminal)
	terminal.global_position = Vector2(95.0, 573.0)
	terminal.descansou.connect(_ao_descansar)
	instrucoes = Label.new()
	instrucoes.position = Vector2(18, 14)
	instrucoes.add_theme_font_size_override("font_size", 15)
	add_child(instrucoes)
	_criar_inimigos()


func _criar_mostruario_itens() -> void:
	var itens: Array = EquipamentosAtivos.CENAS.keys()
	itens.sort()
	var colunas: int = maxi(1, colunas_itens)
	for i in range(itens.size()):
		var drop: Area2D = CENA_DROP.instantiate() as Area2D
		drop.call("configurar", itens[i])
		add_child(drop)
		var coluna: int = i % colunas
		var linha: int = floori(float(i) / float(colunas))
		# A primeira fileira fica imediatamente sobre o andar superior.
		# Novos itens criam outra fileira acima, mantendo todos acessiveis.
		drop.global_position = Vector2(152.0 + coluna * espacamento_horizontal, 338.0 - linha * espacamento_vertical)
		drop.coletado.connect(_ao_coletar)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		instrucoes.text = "PROCESSO ENCERRADO - R para recomecar"
		return
	instrucoes.text = "LAB DE EQUIPAMENTOS  |  CIMA: TODOS OS ITENS  |  BAIXO: BREAKPOINT + MEMORY LEAK + SEGFAULT\nF: coletar/confirmar  |  TAB: trocar slot  |  ESC: cancelar  |  Q/E: usar  |  W+J: atacar acima  |  G: curar  |  R: reiniciar"


func _ao_coletar(item_id: StringName) -> void:
	if not is_instance_valid(jogador):
		return
	var controle: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	print("[LAB ITENS] ", controle.equipar(item_id))


func _criar_inimigos() -> void:
	for cena in [CENA_MEMORY, CENA_SEGFAULT]:
		var inimigo: InimigoBase = cena.instantiate() as InimigoBase
		inimigo.configurar(jogador)
		add_child(inimigo)
		inimigo.global_position = Vector2(635.0, 555.0) if cena == CENA_MEMORY else Vector2(990.0, 557.0)
		inimigo.chance_drop_percentual = 0 # O laboratorio ja exibe todos os drops.
		inimigo.derrotado.connect(_ao_inimigo_derrotado)


func _ao_inimigo_derrotado(_posicao: Vector2, _id: StringName, _caiu: bool) -> void:
	pass


func _ao_descansar() -> void:
	if not is_instance_valid(jogador):
		return
	jogador.descansar()
	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		if is_instance_valid(inimigo):
			inimigo.queue_free()
	# No laboratorio, o mostruario se reabastece a cada descanso.
	for drop in get_tree().get_nodes_in_group("drops_provisorios"):
		if is_instance_valid(drop):
			drop.queue_free()
	call_deferred("_criar_inimigos")
	call_deferred("_criar_mostruario_itens")
