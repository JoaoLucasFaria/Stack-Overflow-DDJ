extends Node2D

## F6: teste isolado do interrupt() no Woodbreaker.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_BOSS: PackedScene = preload("res://cenas/bosses/woodbreaker.tscn")
var jogador: Jogador
var boss: BossBase
var texto: Label


func _ready() -> void:
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.global_position = Vector2(120, 555)
	jogador.vida_maxima = 50
	jogador.vida_atual = 50
	jogador.desbloquear_pulo_duplo()
	jogador.desbloquear_dash()
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	inventario.equipar(&"deadlock")  # item interrupt() no Q
	inventario.aviso.connect(func(m: String) -> void: print("[INTERRUPT TESTE] ", m))
	boss = CENA_BOSS.instantiate() as BossBase
	boss.configurar(jogador)
	add_child(boss)
	boss.global_position = Vector2(740, 600)
	texto = Label.new()
	texto.position = Vector2(20, 18)
	texto.add_theme_font_size_override("font_size", 16)
	add_child(texto)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if not is_instance_valid(boss):
		texto.text = "Boss derrotado. R reinicia a arena."
		return
	texto.text = "V9 INTERRUPT() | Q: pausa 1s, sem dano, recarga 40s | P: causar 13 de dano p/ testar fase | R: reiniciar\nWOODBREAKER: %d HP | Fase %d | interrupcao %.2fs | protecao fase %.2fs" % [boss.vida_atual, boss.fase_atual, boss.interrupcao_restante, boss.protecao_fase_restante]


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		if is_instance_valid(boss):
			boss.receber_dano(13)
