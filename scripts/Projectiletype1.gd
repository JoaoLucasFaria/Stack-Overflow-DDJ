extends Area2D

@export var speed: float = 300.0
@export var dano: int = 3
@export_range(0.1, 30.0, 0.1) var tempo_de_vida: float = 6.0

var direction: Vector2 = Vector2.RIGHT
var tempo_restante: float = 0.0


func _ready() -> void:
	tempo_restante = tempo_de_vida
	body_entered.connect(_on_body_entered)


func set_direction(new_direction: Vector2) -> void:
	if not new_direction.is_zero_approx():
		direction = new_direction.normalized()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	tempo_restante -= delta
	if tempo_restante <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("receber_dano"):
		body.call("receber_dano", dano)
		# Mesmo que o dash bloqueie o dano, o projétil é consumido ao atingir.
		queue_free()
