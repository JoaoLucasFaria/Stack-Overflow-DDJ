extends StaticBody2D

## Alvo elevado. Ataques ao nucleo ABREM o escudo, mas nao tiram HP.
## A derrota exige atacar o corpo do boss durante a janela de exposicao.


func receber_dano(quantidade: int) -> void:
	if quantidade <= 0:
		return
	var chefe: Node = get_parent()
	if chefe != null and chefe.has_method("atingir_nucleo"):
		chefe.call("atingir_nucleo")
