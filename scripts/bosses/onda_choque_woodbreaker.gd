extends Area2D

## Onda curta que corre rente ao chao e pode ser evitada com salto.
var direcao: int = 1
var velocidade: float = 425.0
var dano: int = 1
var duracao: float = 3.0


func configurar(nova_direcao: int, nova_velocidade: float, novo_dano: int) -> void:
	direcao = 1 if nova_direcao >= 0 else -1
	velocidade = nova_velocidade
	dano = novo_dano


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var formato: RectangleShape2D = RectangleShape2D.new()
	formato.size = Vector2(34.0, 54.0)
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = formato
	add_child(hitbox)
	var visual: ColorRect = ColorRect.new()
	visual.position = Vector2(-17.0, -27.0)
	visual.size = Vector2(34.0, 54.0)
	visual.color = Color(0.9, 0.35, 0.24, 0.78)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	body_entered.connect(_ao_tocar_corpo)


func _physics_process(delta: float) -> void:
	global_position.x += float(direcao) * velocidade * delta
	duracao -= delta
	if duracao <= 0.0 or global_position.x < -40.0 or global_position.x > 1192.0:
		queue_free()


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if corpo is Jogador:
		(corpo as Jogador).receber_dano(dano, global_position)
