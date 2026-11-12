extends Area2D

@export var velocidade: float = 245.0
@export var duracao: float = 3.5
var direcao: Vector2 = Vector2.LEFT
var dano: int = 1


func configurar(nova_direcao: Vector2, novo_dano: int) -> void:
	direcao = nova_direcao.normalized() if not nova_direcao.is_zero_approx() else Vector2.LEFT
	dano = novo_dano


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_ao_tocar_corpo)


func _physics_process(delta: float) -> void:
	global_position += direcao * velocidade * delta
	duracao -= delta
	if duracao <= 0.0:
		queue_free()


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if corpo.has_method("receber_dano"):
		corpo.call("receber_dano", dano)
	queue_free()
