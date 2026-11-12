extends Node2D

## Cena isolada: abra cenas/testes/arena_inimigos.tscn e use F6.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_TERMINAL: PackedScene = preload("res://cenas/descanso/terminal_breakpoint.tscn")
const CENA_DROP: PackedScene = preload("res://cenas/inimigos/drop_provisorio.tscn")
const TIPOS: Array[PackedScene] = [
	preload("res://cenas/inimigos/inimigo_syntax_error.tscn"),
	preload("res://cenas/inimigos/inimigo_null_pointer.tscn"),
	preload("res://cenas/inimigos/inimigo_memory_leak.tscn"),
	preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")
]
var jogador: Jogador
var rotulo: Label


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.position = Vector2(75, 540)
	jogador.pulo_duplo_liberado = true
	jogador.desbloquear_dash()
	var terminal: Area2D = CENA_TERMINAL.instantiate() as Area2D
	add_child(terminal)
	terminal.position = Vector2(165, 600)
	terminal.connect("descansou", _ao_descansar)
	rotulo = Label.new()
	rotulo.position = Vector2(30, 26)
	rotulo.add_theme_font_size_override("font_size", 18)
	add_child(rotulo)
	_criar_inimigos()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if not is_instance_valid(jogador):
		rotulo.text = "PROCESSO ENCERRADO — pressione R para reiniciar"
		return
	if Input.is_action_just_pressed("overflow_teste"):
		jogador.adicionar_overflow(25.0)
	rotulo.text = "TESTE | J / clique: atacar | E: BREAKPOINT | O: +25 STACK | R: reiniciar\nHP %d/%d | STACK %.0f/%.0f | Drops: 35%% por inimigo (ajuste na cena)" % [jogador.vida_atual, jogador.vida_maxima, jogador.overflow_atual, jogador.overflow_maximo]


func _criar_inimigos() -> void:
	for indice in TIPOS.size():
		var inimigo: InimigoBase = TIPOS[indice].instantiate() as InimigoBase
		inimigo.configurar(jogador)
		add_child(inimigo)
		inimigo.position = Vector2(345 + indice * 215, 568)
		inimigo.derrotado.connect(_ao_derrotado)


func _ao_derrotado(posicao: Vector2, item_id: StringName, caiu: bool) -> void:
	if not caiu:
		return
	var drop: Area2D = CENA_DROP.instantiate() as Area2D
	drop.call("configurar", item_id)
	add_child(drop)
	drop.global_position = posicao + Vector2(0, -30)


func _ao_descansar() -> void:
	jogador.descansar()
	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		inimigo.queue_free()
	for drop in get_tree().get_nodes_in_group("drops_provisorios"):
		drop.queue_free()
	call_deferred("_criar_inimigos")
