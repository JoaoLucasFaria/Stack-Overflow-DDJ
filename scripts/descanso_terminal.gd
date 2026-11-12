extends Area2D

## BREAKPOINT: descanso voluntário via E, sem botão nas passagens das salas.
signal descansou
var jogador_proximo: bool = false


func _ready() -> void:
	add_to_group("terminais_breakpoint")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	$Mensagem.visible = false


func _process(_delta: float) -> void:
	if jogador_proximo and Input.is_action_just_pressed("descansar"):
		descansou.emit()


func _ao_entrar(corpo: Node2D) -> void:
	if corpo.is_in_group("jogador"):
		jogador_proximo = true
		$Mensagem.visible = true


func _ao_sair(corpo: Node2D) -> void:
	if corpo.is_in_group("jogador"):
		jogador_proximo = false
		$Mensagem.visible = false
