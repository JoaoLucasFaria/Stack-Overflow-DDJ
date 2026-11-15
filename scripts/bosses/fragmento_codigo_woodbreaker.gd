extends Area2D

## Fragmento com posicao de queda avisada ANTES de soltar do teto.
const CODIGOS: Array[String] = ["NULL", "ERR", "0xDEAD", "{ }", "</>", "SEGFAULT"]
var linha_do_chao: float = 600.0
var aviso_restante: float = 1.0
var velocidade: float = 670.0
var dano: int = 1
var caindo: bool = false
var marca: ColorRect
var colisao: CollisionShape2D


func configurar(x: float, y_piso: float, tempo_aviso: float, vel: float, dano_recebido: int) -> void:
	global_position = Vector2(x, -30.0)
	linha_do_chao = y_piso
	aviso_restante = tempo_aviso
	velocidade = vel
	dano = dano_recebido


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = Vector2(48.0, 48.0)
	colisao = CollisionShape2D.new()
	colisao.shape = forma
	colisao.disabled = true
	add_child(colisao)
	var corpo: ColorRect = ColorRect.new()
	corpo.position = Vector2(-24.0, -24.0)
	corpo.size = Vector2(48.0, 48.0)
	corpo.color = Color(0.74, 0.20, 0.31)
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corpo)
	var label: Label = Label.new()
	label.text = CODIGOS.pick_random()
	label.position = Vector2(-32.0, -12.0)
	label.size = Vector2(64.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	add_child(label)
	marca = ColorRect.new()
	marca.position = Vector2(global_position.x - 29.0, linha_do_chao - 10.0)
	marca.size = Vector2(58.0, 10.0)
	marca.color = Color(1.0, 0.14, 0.2, 0.70)
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(marca)
	body_entered.connect(_ao_tocar_corpo)


func _physics_process(delta: float) -> void:
	if not caindo:
		aviso_restante -= delta
		if is_instance_valid(marca):
			marca.modulate.a = 0.6 if int(Time.get_ticks_msec() / 160) % 2 == 0 else 1.0
		if aviso_restante <= 0.0:
			caindo = true
			colisao.set_deferred("disabled", false)
			if is_instance_valid(marca):
				marca.queue_free()
		return
	global_position.y += velocidade * delta
	if global_position.y >= linha_do_chao - 24.0:
		queue_free()


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if caindo and corpo is Jogador:
		(corpo as Jogador).receber_dano(dano, global_position)


func _exit_tree() -> void:
	if is_instance_valid(marca):
		marca.queue_free()
