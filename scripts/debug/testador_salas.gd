extends "res://scripts/main.gd"

## Cena de teste isolado. Reutiliza o Main para instanciar o jogador,
## HUD, equipamento e os inimigos REAIS, sem alterar a campanha.
## Abra cenas/debug/testador_salas.tscn, escolha a sala no Inspector e use F6.
@export_category("Teste isolado de salas")
@export var cena_da_sala: PackedScene = preload("res://cenas/salas/sala_17.tscn")
@export_enum("Inicio", "Pela esquerda", "Pela direita", "Pelo topo", "Por baixo") var entrada_na_sala: String = "Inicio"
@export_range(0, 3, 1) var habilidades_liberadas: int = 0
@export_enum("Automatico", "Normal", "Bloqueio de dash", "Bloqueio de pulo", "Boss 1", "Boss 2", "Boss 3", "Exception Handler", "Final") var tipo_da_sala: String = "Automatico"


func _ready() -> void:
	# Inicializacao real da campanha (jogador, camera, HUD, inventario etc.).
	super._ready()
	if not OS.is_debug_build():
		push_warning("Testador de salas: use a execucao de debug (F6 no editor).")
		return
	if cena_da_sala == null:
		push_error("Testador: selecione uma cena em 'Cena da Sala' no Inspector.")
		return

	var teste: SalaMatriz = cena_da_sala.instantiate() as SalaMatriz
	if teste == null:
		push_error("Testador: a cena precisa herdar de SalaMatriz.")
		return
	var mascara: int = teste.mascara_saidas
	teste.free()

	# O gerador da campanha utiliza as conexoes para validar a mascara.
	# Um grafo-local de uma unica sala permite testar qualquer modelo,
	# independentemente da seed e da existencia de vizinhos no mapa.
	var conexoes: Dictionary = {}
	if (mascara & MapaMatriz.ESQUERDA) != 0:
		conexoes[Vector2i.LEFT] = Vector2i.ZERO
	if (mascara & MapaMatriz.DIREITA) != 0:
		conexoes[Vector2i.RIGHT] = Vector2i.ZERO
	if (mascara & MapaMatriz.CIMA) != 0:
		conexoes[Vector2i.UP] = Vector2i.ZERO
	if (mascara & MapaMatriz.BAIXO) != 0:
		conexoes[Vector2i.DOWN] = Vector2i.ZERO

	var info: Dictionary = mapa.obter(Vector2i.ZERO)
	info["tipo"] = _tipo_efetivo()
	info["modelo"] = cena_da_sala.resource_path
	info["mascara"] = mascara
	info["conexoes"] = conexoes
	mapa.salas[Vector2i.ZERO] = info

	# Entra pelo sistema real, que configura a cena ANTES do _ready,
	# faz spawn do jogador e povoa a sala com os inimigos originais.
	_entrar_sala(Vector2i.ZERO, _direcao_da_entrada())

	if habilidades_liberadas >= 1 and not jogador.pulo_duplo_liberado:
		jogador.desbloquear_pulo_duplo()
	if habilidades_liberadas >= 2 and not jogador.dash_component.dash_desbloqueado:
		jogador.desbloquear_dash()
	if habilidades_liberadas >= 3 and not jogador.grapple_liberado:
		jogador.desbloquear_grapple()

	_aviso("[DEBUG] %s | Entrada: %s | Poderes: %d" % [cena_da_sala.resource_path.get_file(), entrada_na_sala, habilidades_liberadas], 5.0)
	print("[TESTADOR] Sala: ", cena_da_sala.resource_path, " | mascara: ", mascara, " | entrada: ", entrada_na_sala)


func _tipo_efetivo() -> String:
	match tipo_da_sala:
		"Normal": return "normal"
		"Bloqueio de dash": return "bloqueio_dash"
		"Bloqueio de pulo": return "bloqueio_pulo"
		"Boss 1": return "boss1"
		"Boss 2": return "boss2"
		"Boss 3": return "boss3"
		"Exception Handler": return "exception"
		"Final": return "final"
	var arquivo: String = cena_da_sala.resource_path.get_file()
	if arquivo == "sala_17.tscn" or arquivo == "sala_abismo_dash.tscn":
		return "bloqueio_dash"
	if arquivo == "sala_pulo_duplo.tscn":
		return "bloqueio_pulo"
	if arquivo == "sala_boss_1.tscn":
		return "boss1"
	if arquivo == "sala_boss_2.tscn":
		return "boss2"
	if arquivo == "sala_boss_3.tscn":
		return "boss3"
	if arquivo == "sala_exception_handler.tscn":
		return "exception"
	if arquivo == "sala_altar_final.tscn":
		return "final"
	return "normal"


func _direcao_da_entrada() -> Vector2i:
	match entrada_na_sala:
		"Pela esquerda": return Vector2i.RIGHT
		"Pela direita": return Vector2i.LEFT
		"Pelo topo": return Vector2i.DOWN
		"Por baixo": return Vector2i.UP
	return Vector2i.ZERO


func _ao_atravessar_saida(direcao: Vector2i) -> void:
	# Em teste isolado nao ha sala vizinha. Verifica a saida e retorna
	# ao ponto de entrada para que o jogador continue testando.
	if not is_instance_valid(jogador) or not is_instance_valid(sala_atual):
		return
	print("[TESTADOR] Transicao detectada: ", direcao)
	jogador.preparar_para_nova_sala()
	jogador.global_position = sala_atual.spawn_para_entrada(_direcao_da_entrada())
	posicao_segura_atual = jogador.global_position
	protecao_entrada_restante = TEMPO_PROTECAO_ENTRADA
