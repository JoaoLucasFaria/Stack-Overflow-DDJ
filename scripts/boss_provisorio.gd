class_name BossProvisorio
extends Node2D

## Placeholder de integração da FRENTE B; será substituído por chefes reais.
## F (3 vezes) perto do chefe simula sua derrota e concede habilidade.
signal derrotado(identificador: int)

var identificador: int = 1
const NOMES: Dictionary = {1: "ICE AGE SID", 2: "WOODBREAKER", 3: "STONEMAKER"}
var vida: int = 3
var jogador: Jogador = null
var encerrado: bool = false
var tempo_proximo_golpe: float = 0.0
var rotulo: Label


func configurar(boss_id: int, alvo: Jogador) -> void:
	identificador = boss_id
	jogador = alvo


func _ready() -> void:
	var corpo: ColorRect = ColorRect.new()
	corpo.color = Color(0.8, 0.22, 0.25, 0.96)
	corpo.position = Vector2(-55, -90)
	corpo.size = Vector2(110, 90)
	add_child(corpo)
	rotulo = Label.new()
	rotulo.position = Vector2(-150, -135)
	rotulo.custom_minimum_size = Vector2(300, 30)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_color_override("font_color", Color.WHITE)
	rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(rotulo)
	_atualizar_rotulo()


func _process(delta: float) -> void:
	if encerrado or not is_instance_valid(jogador):
		return
	tempo_proximo_golpe = maxf(0.0, tempo_proximo_golpe - delta)
	if Input.is_action_just_pressed("ataque_teste") and tempo_proximo_golpe <= 0.0:
		if jogador.global_position.distance_to(global_position) <= 155.0:
			vida -= 1
			tempo_proximo_golpe = 0.16
			_atualizar_rotulo()
			if vida <= 0:
				encerrado = true
				derrotado.emit(identificador)
				queue_free()


func _atualizar_rotulo() -> void:
	if rotulo != null:
		rotulo.text = "%s (protótipo) | F para atacar (%d/3)" % [NOMES.get(identificador, "GUARDIÃO"), vida]
