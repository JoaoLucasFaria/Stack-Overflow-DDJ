extends Node2D

## Controla geração, histórico, portas e jogador persistente.
## Os mapas continuam editáveis e executáveis individualmente no Godot.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const SALA_INICIAL: String = "res://cenas/sala_padrao.tscn"

@export_category("Geração de salas")
@export var lista_cenas: Array[String] = [
	"res://cenas/sala_padrao.tscn",
	"res://cenas/sala_plataforma.tscn",
	"res://cenas/sala_queda.tscn",
	"res://cenas/sala_topo_1.tscn",
	"res://cenas/sala_esq_alta.tscn",
	"res://cenas/sala_esq_alta_trapfall.tscn",
]
@export_file("*.tscn") var cena_chefe: String = "res://cenas/sala_chefe.tscn"
@export_range(1, 100, 1) var limite_salas_para_chefe: int = 4

var sala_atual: Sala = null
var jogador: Jogador = null
var historico_salas: Array[String] = []
var indice_historico: int = -1

var _entradas_por_caminho: Dictionary = {}
var _em_transicao: bool = false


func _ready() -> void:
	randomize()
	jogador = CENA_JOGADOR.instantiate() as Jogador
	if jogador == null:
		push_error("O jogador precisa utilizar o script Jogador.")
		return
	add_child(jogador)

	if _trocar_sala(SALA_INICIAL, "direita"):
		historico_salas.append(SALA_INICIAL)
		indice_historico = 0


func avancar_para_nova_sala() -> void:
	if _em_transicao or sala_atual == null:
		return

	var proximo_indice: int = indice_historico + 1
	var nova_sala: bool = proximo_indice >= historico_salas.size()
	var caminho: String

	if nova_sala:
		caminho = _sortear_proxima_sala()
	else:
		caminho = historico_salas[proximo_indice]

	if caminho.is_empty() or not _trocar_sala(caminho, "direita"):
		return

	if nova_sala:
		historico_salas.append(caminho)
	indice_historico = proximo_indice


func voltar_para_sala_anterior() -> void:
	if _em_transicao or indice_historico <= 0:
		return

	var indice_anterior: int = indice_historico - 1
	if _trocar_sala(historico_salas[indice_anterior], "esquerda"):
		indice_historico = indice_anterior


func _sortear_proxima_sala() -> String:
	var entrada_necessaria: String = sala_atual.get_proxima_entrada()

	# O chefe só entra quando sua porta é compatível com a sala atual.
	if historico_salas.size() >= limite_salas_para_chefe:
		if _tipo_entrada(cena_chefe) == entrada_necessaria:
			return cena_chefe

	var compativeis: Array[String] = []
	var sem_repetir: Array[String] = []
	var ultima_sala: String = historico_salas.back()
	for caminho in lista_cenas:
		if _tipo_entrada(caminho) != entrada_necessaria:
			continue
		compativeis.append(caminho)
		if caminho != ultima_sala:
			sem_repetir.append(caminho)

	# Se a única sala compatível for a atual, repetir é melhor que quebrar o mapa.
	if not sem_repetir.is_empty():
		return sem_repetir.pick_random()
	if not compativeis.is_empty():
		return compativeis.pick_random()

	push_error("Nenhuma sala com entrada '" + entrada_necessaria + "' foi encontrada.")
	return ""


func _tipo_entrada(caminho: String) -> String:
	if _entradas_por_caminho.has(caminho):
		return _entradas_por_caminho[caminho]

	var recurso: PackedScene = load(caminho) as PackedScene
	if recurso == null:
		push_error("Cena não encontrada: " + caminho)
		return ""

	var instancia: Sala = recurso.instantiate() as Sala
	if instancia == null:
		push_error("A cena não usa scripts/salas.gd: " + caminho)
		return ""

	var tipo: String = instancia.get_tipo_entrada()
	instancia.free()
	_entradas_por_caminho[caminho] = tipo
	return tipo


func _trocar_sala(caminho: String, direcao_chegada: String) -> bool:
	if _em_transicao:
		return false
	_em_transicao = true

	var recurso: PackedScene = load(caminho) as PackedScene
	if recurso == null:
		push_error("Não foi possível carregar: " + caminho)
		_em_transicao = false
		return false

	var nova_sala: Sala = recurso.instantiate() as Sala
	if nova_sala == null:
		push_error("A cena precisa ter uma raiz Sala: " + caminho)
		_em_transicao = false
		return false

	# Cada sala conserva o Player no editor e pode ser testada isoladamente.
	# No jogo completo, removemos esse duplicado para manter um único jogador.
	var jogador_da_sala: Node = nova_sala.get_node_or_null("Player")
	if jogador_da_sala != null:
		nova_sala.remove_child(jogador_da_sala)
		jogador_da_sala.free()

	if sala_atual != null:
		remove_child(sala_atual)
		sala_atual.queue_free()

	sala_atual = nova_sala
	add_child(sala_atual)
	# O jogador fica acima das formas visuais e do cenário da sala.
	move_child(jogador, get_child_count() - 1)
	jogador.preparar_para_nova_sala()
	sala_atual.configurar_spawn(direcao_chegada, jogador)
	_conectar_portas(sala_atual)

	print("Sala carregada: ", caminho)
	_em_transicao = false
	return true


func _conectar_portas(sala: Sala) -> void:
	for filho in sala.get_children():
		if not filho.has_signal("jogador_entrou"):
			continue
		if String(filho.name).begins_with("PortaSaida"):
			filho.connect("jogador_entrou", Callable(self, "_on_porta_saida_ativada"))
		elif String(filho.name).begins_with("PortaEntrada"):
			filho.connect("jogador_entrou", Callable(self, "_on_porta_entrada_ativada"))


func _on_porta_saida_ativada() -> void:
	avancar_para_nova_sala()


func _on_porta_entrada_ativada() -> void:
	voltar_para_sala_anterior()
