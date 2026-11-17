extends Area2D

## Projetil exclusivo do Boss 1: ignora corpos do cenario e so acerta
## o jogador. Nao altera o comportamento dos inimigos comuns.
@export var velocidade: float = 300.0
@export var duracao: float = 4.2

var direcao: Vector2 = Vector2.LEFT
var dano: int = 1


func configurar(nova_direcao: Vector2, novo_dano: int) -> void:
	direcao = nova_direcao.normalized() if not nova_direcao.is_zero_approx() else Vector2.LEFT
	dano = novo_dano


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_ao_tocar_corpo)


func _physics_process(delta: float) -> void:
	global_position += direcao * velocidade * delta
	duracao -= delta
	if duracao <= 0.0:
		queue_free()


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if corpo is Jogador:
		corpo.receber_dano(dano, global_position)
		queue_free()
	# Paredes e plataformas nao interrompem estes disparos.
