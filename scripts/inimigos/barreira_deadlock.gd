extends Area2D

## Corrente de lentidao nao solida: pode ser atravessada, nao causa dano.
## Camada 2 permite que o ataque basico a destrua com 1 golpe.
## Mascara 1 detecta somente o jogador; os inimigos nunca colidem com ela.
@export_range(0.1, 1.0, 0.05) var fator_velocidade_jogador: float = 0.45
@export var duracao_efeito_apos_sair: float = 0.16
var vida_atual: int = 1
var tempo_restante: float = 7.0
var comprimento: float = 120.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	monitoring = true
	monitorable = true
	add_to_group("barreiras_deadlock")


func configurar(a: Vector2, b: Vector2, duracao: float) -> void:
	tempo_restante = duracao
	var vetor: Vector2 = b - a
	global_position = (a + b) * 0.5
	rotation = vetor.angle()
	comprimento = maxf(vetor.length(), 24.0)
	var tamanho: Vector2 = Vector2(comprimento, 26.0)
	var colisao: CollisionShape2D = CollisionShape2D.new()
	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = tamanho
	colisao.shape = forma
	add_child(colisao)
	var visual: ColorRect = ColorRect.new()
	visual.position = -tamanho * 0.5
	visual.size = tamanho
	visual.color = Color(1.0, 0.58, 0.13, 0.32)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	queue_redraw()


func receber_dano(quantidade: int) -> void:
	if quantidade <= 0 or is_queued_for_deletion():
		return
	vida_atual = maxi(0, vida_atual - quantidade)
	if vida_atual == 0:
		queue_free()


func _physics_process(delta: float) -> void:
	tempo_restante -= delta
	if tempo_restante <= 0.0:
		queue_free()
		return
	# Nao muda SPEED diretamente: o jogador calcula o fator na fisica dele.
	# Atualizar continuamente evita conflito quando duas correntes se sobrepoem.
	for corpo in get_overlapping_bodies():
		if corpo is Jogador:
			corpo.aplicar_lentidao_deadlock(fator_velocidade_jogador, duracao_efeito_apos_sair)


func _draw() -> void:
	var inicio: float = -comprimento * 0.5
	var fim: float = comprimento * 0.5
	draw_line(Vector2(inicio, 0), Vector2(fim, 0), Color(1.0, 0.78, 0.28, 0.62), 2.0)
	for i in range(0, int(comprimento), 16):
		var x: float = inicio + float(i)
		draw_arc(Vector2(x, 0), 5.0, 0.0, TAU, 8, Color(1.0, 0.84, 0.48, 0.48), 1.5)
