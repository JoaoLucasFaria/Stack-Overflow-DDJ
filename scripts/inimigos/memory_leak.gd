extends InimigoBase

## Cresce devagar enquanto não for derrotado: hitbox e visual acompanham.
@export var escala_maxima: float = 1.6
@export var segundos_para_crescer: float = 14.0
var tempo_vivo: float = 0.0


func _ready() -> void:
	super._ready()
	# Duplicar o recurso impede crescimento simultâneo de outras instâncias.
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()


func _pensar(delta: float) -> void:
	tempo_vivo += delta
	var t: float = clampf(tempo_vivo / maxf(0.1, segundos_para_crescer), 0.0, 1.0)
	var escala: float = lerpf(1.0, escala_maxima, t)
	var lado: float = 30.0 * escala
	var forma: RectangleShape2D = $CollisionShape2D.shape as RectangleShape2D
	forma.size = Vector2(lado, lado)
	$Visual.offset_left = -lado * 0.5
	$Visual.offset_top = -lado * 0.5
	$Visual.offset_right = lado * 0.5
	$Visual.offset_bottom = lado * 0.5
	_patrulhar_ou_perseguir()
