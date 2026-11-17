extends Area2D

## Onda bilateral do Memory Leak. Cresce de uma onda pequena ate o
## retangulo de 34 x 54 da onda do Woodbreaker, com alcance proporcional.
var direcao: int = 1
var velocidade: float = 285.0
var dano: int = 1
var tamanho: Vector2 = Vector2(20.0, 18.0)
var distancia_maxima: float = 165.0
var distancia_percorrida: float = 0.0


func configurar(nova_direcao: int, nova_velocidade: float, novo_dano: int, novo_tamanho: Vector2, novo_alcance: float) -> void:
	direcao = 1 if nova_direcao >= 0 else -1
	velocidade = nova_velocidade
	dano = novo_dano
	tamanho = novo_tamanho
	distancia_maxima = novo_alcance


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true

	var forma: RectangleShape2D = RectangleShape2D.new()
	forma.size = tamanho
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.shape = forma
	add_child(colisao)

	var brilho: ColorRect = ColorRect.new()
	brilho.position = -tamanho * 0.5
	brilho.size = tamanho
	brilho.color = Color(0.25, 0.93, 0.49, 0.74)
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brilho)
	body_entered.connect(_ao_tocar_corpo)


func _physics_process(delta: float) -> void:
	var deslocamento: float = velocidade * delta
	global_position.x += float(direcao) * deslocamento
	distancia_percorrida += deslocamento
	if distancia_percorrida >= distancia_maxima or global_position.x < -40.0 or global_position.x > 1192.0:
		queue_free()


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if corpo is Jogador:
		(corpo as Jogador).receber_dano(dano, global_position)
		queue_free()
