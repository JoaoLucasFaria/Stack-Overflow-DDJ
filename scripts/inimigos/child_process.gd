extends InimigoBase

## Filho fraco de Fork Bomb. Nao gera itens nem cria novos processos.
func _ready() -> void:
	chance_drop_percentual = 0
	super._ready()


func _pensar(_delta: float) -> void:
	# Sempre persegue, sem patrulha; 1HP e dano por contato.
	var alvo: Node2D = _alvo_da_ia()
	if not is_instance_valid(alvo) or (alvo == jogador and jogador.vida_atual <= 0):
		velocity.x = 0.0
		return
	var dist: float = alvo.global_position.x - global_position.x
	if alvo != jogador and absf(dist) < 20.0 and alvo.has_method("receber_impacto"):
		alvo.call("receber_impacto")
	direcao = signf(dist) if absf(dist) > 3.0 else direcao
	velocity.x = direcao * velocidade if _pode_caminhar(direcao) else 0.0


func _iniciar_ataque() -> void:
	pass
