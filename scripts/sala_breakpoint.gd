extends SalaMatriz

## UMA unica cena funciona com todas as mascaras da matriz.
## O Main informa a mascara antes de adicionar a cena ao mundo.
## Lustosa pode editar as plataformas, o terminal e a decoracao na cena.
## Conserve os nos Contorno/Bloqueio* (ou atualize os nomes aqui).

func _ready() -> void:
	_configurar_aberturas()
	super._ready()


func _configurar_aberturas() -> void:
	_definir_passagem("BloqueioEsquerda", (mascara_saidas & MapaMatriz.ESQUERDA) != 0)
	_definir_passagem("BloqueioDireita", (mascara_saidas & MapaMatriz.DIREITA) != 0)
	_definir_passagem("BloqueioCima", (mascara_saidas & MapaMatriz.CIMA) != 0)
	_definir_passagem("BloqueioBaixo", (mascara_saidas & MapaMatriz.BAIXO) != 0)


func _definir_passagem(nome: String, aberta: bool) -> void:
	var bloqueio: StaticBody2D = get_node("Contorno/" + nome) as StaticBody2D
	if bloqueio == null:
		push_error("BREAKPOINT: contorno ausente: " + nome)
		return
	bloqueio.visible = not aberta
	bloqueio.collision_layer = 0 if aberta else 1
