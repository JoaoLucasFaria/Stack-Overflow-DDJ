extends Area2D

@export var speed: float = 300.0
@export var dano: int = 3

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("receber_dano"):
		body.receber_dano(dano)

	#queue_free()
