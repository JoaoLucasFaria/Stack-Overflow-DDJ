@tool
extends Area2D

@export_enum("Cima", "Baixo", "Esquerda", "Direita") var direcao: int = 0:
	set(valor):
		direcao = valor
		if is_inside_tree():
			queue_redraw()

@export_range(1, 40, 1) var quantidade: int = 6:
	set(valor):
		quantidade = valor
		if is_inside_tree():
			queue_redraw()

@export_range(1, 10, 1) var dano: int = 1

const PASSO: float = 25.0
const ESPESSURA: float = 14.0
const COR: Color = Color(0.95, 0.20, 0.26)


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	collision_layer = 0
	collision_mask = 1

	var colisao := CollisionShape2D.new()
	var forma := RectangleShape2D.new()

	if direcao <= 1:
		forma.size = Vector2(quantidade * PASSO, ESPESSURA)
	else:
		forma.size = Vector2(ESPESSURA, quantidade * PASSO)

	colisao.shape = forma
	colisao.position = forma.size / 2.0
	add_child(colisao)


func _draw() -> void:
	for i in range(quantidade):
		var inicio: float = i * PASSO
		var pontos: PackedVector2Array

		match direcao:
			0: # Cima
				pontos = PackedVector2Array([
					Vector2(inicio, 14),
					Vector2(inicio + 12, 0),
					Vector2(inicio + 24, 14)
				])
			1: # Baixo
				pontos = PackedVector2Array([
					Vector2(inicio, 0),
					Vector2(inicio + 12, 14),
					Vector2(inicio + 24, 0)
				])
			2: # Esquerda
				pontos = PackedVector2Array([
					Vector2(14, inicio),
					Vector2(0, inicio + 12),
					Vector2(14, inicio + 24)
				])
			3: # Direita
				pontos = PackedVector2Array([
					Vector2(0, inicio),
					Vector2(14, inicio + 12),
					Vector2(0, inicio + 24)
				])

		draw_colored_polygon(pontos, COR)


func _physics_process(_delta: float) -> void:
	for corpo in get_overlapping_bodies():
		if corpo is Jogador:
			corpo.receber_dano(dano, global_position)
