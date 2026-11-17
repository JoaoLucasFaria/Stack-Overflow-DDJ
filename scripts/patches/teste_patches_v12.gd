extends Node2D

## Arena isolada da campanha: permite instalar qualquer Patch e evolui-lo
## sem consumir salas de desafio. Aperte F6 nesta cena no editor.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_SYNTAX: PackedScene = preload("res://cenas/inimigos/inimigo_syntax_error.tscn")
const CENA_SEGFAULT: PackedScene = preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")

var jogador: Jogador
var seletor: OptionButton
var status: Label
var aviso: Label
var inimigos: Array[Node2D] = []


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.position = Vector2(170, 535)
	jogador.desbloquear_pulo_duplo()
	jogador.desbloquear_dash()
	var itens: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	itens.equipar(&"segmentation_fault")
	itens.slot_para_substituir = 1
	itens.equipar(&"syntax_error")
	jogador.patches.evento_patch.connect(_mostrar_aviso)
	_criar_ui()
	_criar_inimigos()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if is_instance_valid(jogador):
		_atualizar_status()


func _criar_ui() -> void:
	var camada: CanvasLayer = CanvasLayer.new()
	camada.layer = 4
	add_child(camada)
	var painel: PanelContainer = PanelContainer.new()
	painel.position = Vector2(760, 48)
	painel.custom_minimum_size = Vector2(365, 0)
	camada.add_child(painel)
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 7)
	painel.add_child(coluna)
	var titulo: Label = Label.new()
	titulo.text = "LAB V12  |  PATCHES PASSIVOS"
	titulo.add_theme_font_size_override("font_size", 16)
	coluna.add_child(titulo)
	var explicacao: Label = Label.new()
	explicacao.text = "Escolha qualquer Patch e instale-o.\nRepetir sobe de nivel (max. 5).\nA build aceita so 4 tipos diferentes."
	explicacao.add_theme_font_size_override("font_size", 13)
	coluna.add_child(explicacao)
	seletor = OptionButton.new()
	seletor.custom_minimum_size = Vector2(345, 34)
	for id in GerenciadorPatches.ORDEM:
		seletor.add_item(String(GerenciadorPatches.NOMES[id]))
	coluna.add_child(seletor)
	var aplicar: Button = Button.new()
	aplicar.text = "INSTALAR / MELHORAR PATCH"
	aplicar.pressed.connect(_instalar_selecionado)
	coluna.add_child(aplicar)
	var restaurar: Button = Button.new()
	restaurar.text = "Recuperar HP (sem remover Patches)"
	restaurar.pressed.connect(_curar_jogador)
	coluna.add_child(restaurar)
	var ferir: Button = Button.new()
	ferir.text = "Testar dano recebido: -1 HP"
	ferir.pressed.connect(_simular_dano)
	coluna.add_child(ferir)
	var stack: Button = Button.new()
	stack.text = "Adicionar 25 STACK"
	stack.pressed.connect(_adicionar_stack)
	coluna.add_child(stack)
	var reviver: Button = Button.new()
	reviver.text = "Recriar inimigos de teste"
	reviver.pressed.connect(_recriar_inimigos)
	coluna.add_child(reviver)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	coluna.add_child(status)
	aviso = Label.new()
	aviso.add_theme_font_size_override("font_size", 13)
	aviso.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75))
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(aviso)
	var instrucoes: Label = Label.new()
	instrucoes.text = "W + J: ataque para cima | Q/E: equipamentos\nR: reiniciar arena | Patches somem ao morrer"
	instrucoes.add_theme_font_size_override("font_size", 12)
	coluna.add_child(instrucoes)


func _instalar_selecionado() -> void:
	if not is_instance_valid(jogador) or seletor.selected < 0:
		return
	var id: StringName = GerenciadorPatches.ORDEM[seletor.selected]
	if not jogador.patches.instalar_patch(id):
		_mostrar_aviso("Sem slot livre, Patch invalido ou nivel maximo.")


func _atualizar_status() -> void:
	if status == null:
		return
	status.text = "HP %d/%d   STACK %.0f/%.0f\nSlots: %d/4   Opcoes de altar: %d" % [
		jogador.vida_atual, jogador.vida_maxima,
		jogador.overflow_atual, jogador.overflow_maximo,
		jogador.patches.slots_ocupados(),
		mini(3, 12 - _contar_niveis_maximos()) if jogador.patches.slots_ocupados() < 4 else mini(3, jogador.patches.slots_ocupados() - _contar_niveis_maximos())
	]


func _contar_niveis_maximos() -> int:
	var completos: int = 0
	for id in jogador.patches.niveis.keys():
		if jogador.patches.nivel(id) >= GerenciadorPatches.MAX_NIVEL:
			completos += 1
	return completos


func _curar_jogador() -> void:
	if is_instance_valid(jogador):
		jogador.descansar()


func _adicionar_stack() -> void:
	if is_instance_valid(jogador):
		jogador.adicionar_overflow(25.0)


func _mostrar_aviso(texto: String) -> void:
	if is_instance_valid(aviso):
		aviso.text = texto


func _simular_dano() -> void:
	if is_instance_valid(jogador):
		jogador.receber_dano(1, jogador.global_position + Vector2(100, 0))


func _criar_inimigos() -> void:
	for dados in [
		{"cena": CENA_SYNTAX, "pos": Vector2(470, 565)},
		{"cena": CENA_SEGFAULT, "pos": Vector2(680, 565)}
	]:
		var cena: PackedScene = dados["cena"] as PackedScene
		var inimigo: InimigoBase = cena.instantiate() as InimigoBase
		inimigo.configurar(jogador)
		inimigo.chance_drop_percentual = 0
		add_child(inimigo)
		inimigo.global_position = dados["pos"]
		inimigos.append(inimigo)


func _recriar_inimigos() -> void:
	for inimigo in inimigos:
		if is_instance_valid(inimigo):
			inimigo.queue_free()
	inimigos.clear()
	call_deferred("_criar_inimigos")
