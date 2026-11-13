extends Node2D

## Teste isolado: F6 em cenas/testes/arena_wall_jump.tscn.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_TORRETA: PackedScene = preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")
const CENA_TERMINAL: PackedScene = preload("res://cenas/descanso/terminal_breakpoint.tscn")

var jogador: Jogador
var torre: InimigoBase
var informacao: Label


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.position = Vector2(120, 540)
	# O Wall Slide/Jump funciona antes de liberar pulo duplo ou dash.
	jogador.pulo_duplo_liberado = false
	jogador.dash_component.dash_desbloqueado = false

	var terminal: Area2D = CENA_TERMINAL.instantiate() as Area2D
	add_child(terminal)
	terminal.position = Vector2(140, 600)
	terminal.descansou.connect(_descansar)

	informacao = Label.new()
	informacao.position = Vector2(24, 24)
	informacao.add_theme_font_size_override("font_size", 17)
	add_child(informacao)
	_criar_torreta()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if not is_instance_valid(jogador):
		informacao.text = "PROCESSO ENCERRADO - R para reiniciar"
		return
	informacao.text = "TESTE WALL SLIDE/JUMP | A/D: parede | W/Espaco: pular | J/clique: atacar | E: descanso | R: reiniciar\nHP %d/%d | WALL %s | Torreta %s" % [
		jogador.vida_atual, jogador.vida_maxima,
		"SIM" if jogador.is_on_wall() else "NAO",
		"ATIVA" if is_instance_valid(torre) else "DESTRUIDA"
	]


func _criar_torreta() -> void:
	torre = CENA_TORRETA.instantiate() as InimigoBase
	torre.configurar(jogador)
	add_child(torre)
	# O fixador procura a parede a direita e ajusta automaticamente a posicao.
	torre.global_position = Vector2(540, 315)


func _descansar() -> void:
	if not is_instance_valid(jogador):
		return
	jogador.descansar()
	if is_instance_valid(torre):
		torre.queue_free()
	call_deferred("_criar_torreta")
