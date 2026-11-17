extends Node2D

## F6: teste manual dos novos inimigos e dos tres novos itens.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_DROP: PackedScene = preload("res://cenas/inimigos/drop_provisorio.tscn")
const CENAS: Array[PackedScene] = [
	preload("res://cenas/inimigos/inimigo_fork_bomb.tscn"),
	preload("res://cenas/inimigos/inimigo_race_condition.tscn"),
	preload("res://cenas/inimigos/inimigo_deadlock.tscn"),
	preload("res://cenas/inimigos/inimigo_out_of_bounds.tscn")
]
const ITENS: Array[StringName] = [&"fork_bomb", &"race_condition", &"deadlock"]
var jogador: Jogador
var titulo: Label


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.global_position = Vector2(64, 550)
	jogador.vida_maxima = 50
	jogador.vida_atual = 50
	jogador.desbloquear_pulo_duplo()
	jogador.desbloquear_dash()
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	inventario.aviso.connect(func(m: String) -> void: print("[V9] ", m))
	for i in range(ITENS.size()):
		var drop: Area2D = CENA_DROP.instantiate() as Area2D
		drop.call("configurar", ITENS[i])
		add_child(drop)
		drop.global_position = Vector2(115 + i * 72, 563)
		drop.coletado.connect(_ao_coletar)
	titulo = Label.new()
	titulo.position = Vector2(15, 18)
	titulo.add_theme_font_size_override("font_size", 14)
	add_child(titulo)
	_criar_inimigos()


func _criar_inimigos() -> void:
	for i in range(CENAS.size()):
		var inimigo: InimigoBase = CENAS[i].instantiate() as InimigoBase
		inimigo.configurar(jogador)
		add_child(inimigo)
		inimigo.global_position = Vector2(265 + i * 250, 550)
		inimigo.derrotado.connect(_ao_derrotado)


func _ao_derrotado(posicao: Vector2, item_id: StringName, caiu: bool) -> void:
	if not caiu:
		return
	var drop: Area2D = CENA_DROP.instantiate() as Area2D
	drop.call("configurar", item_id)
	add_child(drop)
	drop.global_position = posicao + Vector2(0, -25)
	drop.coletado.connect(_ao_coletar)


func _ao_coletar(item_id: StringName) -> void:
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	print("[V9] ", inventario.equipar(item_id))


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if is_instance_valid(jogador):
		titulo.text = "V9: FORK BOMB / RACE CONDITION / DEADLOCK / OUT OF BOUNDS\nF: coletar + confirmar  |  TAB: trocar slot  |  Q/E: usar  |  W+J: atacar acima  |  R: reiniciar\nDerrube a colmeia; o clone investe e compartilha HP; atravesse correntes lentas ou quebre-as. Teste interrupt() nos chefes."
