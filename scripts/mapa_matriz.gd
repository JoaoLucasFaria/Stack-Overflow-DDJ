class_name MapaMatriz
extends RefCounted

## Gerador de GRAFO / matriz, sem criar nenhuma plataforma na Godot.
## Cada cena da pool é um módulo completo, editado manualmente.
## Máscaras: esquerda=1, direita=2, cima=4, baixo=8.
const DIRECOES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ESQUERDA: int = 1
const DIREITA: int = 2
const CIMA: int = 4
const BAIXO: int = 8

## Para criar uma sala nova: herde sala_base.tscn, configure mascara_saidas
## no Inspector e adicione o caminho somente na lista da máscara correta.
const MODELOS: Dictionary = {
	1: [
		"res://cenas/salas/sala_01.tscn",
	],
	2: [
		"res://cenas/salas/sala_02.tscn",
	],
	3: [
		"res://cenas/salas/sala_03.tscn",
		"res://cenas/salas/corredor_aberto.tscn",
		"res://cenas/salas/corredor_degraus.tscn",
		"res://cenas/salas/sala_armadilha_horizontal.tscn",
	],
	4: [
		"res://cenas/salas/sala_04.tscn",
	],
	5: [
		"res://cenas/salas/sala_05.tscn",
		"res://cenas/salas/curva_esquerda_cima.tscn",
	],
	6: [
		"res://cenas/salas/sala_06.tscn",
		"res://cenas/salas/curva_direita_cima.tscn",
	],
	7: [
		"res://cenas/salas/sala_07.tscn",
	],
	8: [
		"res://cenas/salas/sala_08.tscn",
	],
	9: [
		"res://cenas/salas/sala_09.tscn",
	],
	10: [
		"res://cenas/salas/sala_10.tscn",
	],
	11: [
		"res://cenas/salas/sala_11.tscn",
	],
	12: [
		"res://cenas/salas/sala_12.tscn",
		"res://cenas/salas/poco_vertical.tscn",
	],
	13: [
		"res://cenas/salas/sala_13.tscn",
	],
	14: [
		"res://cenas/salas/sala_14.tscn",
	],
	15: [
		"res://cenas/salas/sala_15.tscn",
	],
}
const ESPECIAIS: Dictionary = {
	"inicio": "res://cenas/salas/sala_inicio.tscn",
	"bloqueio_pulo": "res://cenas/salas/sala_pulo_duplo.tscn",
	"bloqueio_dash": "res://cenas/salas/sala_abismo_dash.tscn",
	"boss1": "res://cenas/salas/sala_boss_1.tscn",
	"boss2": "res://cenas/salas/sala_boss_2.tscn",
	"boss3": "res://cenas/salas/sala_boss_3.tscn",
	"final": "res://cenas/salas/sala_altar_final.tscn"
}

var salas: Dictionary = {}
var visitadas: Dictionary = {}
var gerador: RandomNumberGenerator = RandomNumberGenerator.new()
var semente: int = 0


static func mascara_das_conexoes(conexoes: Dictionary) -> int:
	var mascara: int = 0
	if conexoes.has(Vector2i.LEFT):
		mascara |= ESQUERDA
	if conexoes.has(Vector2i.RIGHT):
		mascara |= DIREITA
	if conexoes.has(Vector2i.UP):
		mascara |= CIMA
	if conexoes.has(Vector2i.DOWN):
		mascara |= BAIXO
	return mascara


func gerar(quantidade_ramos: int = 12, semente_fixa: int = 0) -> void:
	salas.clear()
	visitadas.clear()
	if semente_fixa == 0:
		gerador.randomize()
	else:
		gerador.seed = semente_fixa
	semente = gerador.seed

	# Progressão principal invariável; só as ramificações e as salas comuns variam.
	var principal: Array[Dictionary] = [
		{"p": Vector2i(0, 0), "tipo": "inicio"},
		{"p": Vector2i(-1, 0), "tipo": "normal"},
		{"p": Vector2i(-2, 0), "tipo": "normal"},
		{"p": Vector2i(-3, 0), "tipo": "boss1"},
		{"p": Vector2i(0, -1), "tipo": "normal"},
		{"p": Vector2i(1, -1), "tipo": "normal"},
		{"p": Vector2i(2, -1), "tipo": "bloqueio_pulo"},
		{"p": Vector2i(3, -1), "tipo": "boss2"},
		{"p": Vector2i(3, -2), "tipo": "normal"},
		{"p": Vector2i(4, -2), "tipo": "bloqueio_dash"},
		{"p": Vector2i(5, -2), "tipo": "boss3"},
		{"p": Vector2i(6, -2), "tipo": "final"}
	]
	for dado in principal:
		_adicionar(dado["p"], dado["tipo"])

	var trilhas: Array[Array] = [
		[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 0)],
		[Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(3, -1)],
		[Vector2i(3, -1), Vector2i(3, -2), Vector2i(4, -2), Vector2i(5, -2), Vector2i(6, -2)]
	]
	for trilha in trilhas:
		for indice in range(trilha.size() - 1):
			_ligar(trilha[indice], trilha[indice + 1])

	# Ramos opcionais SOMENTE de salas comuns. Nunca conectamos duas
	# células só porque são adjacentes: todas as arestas são explícitas.
	var tentativas: int = 0
	var criadas: int = 0
	while criadas < quantidade_ramos and tentativas < 900:
		tentativas += 1
		var candidatos: Array = salas.keys()
		var origem: Vector2i = candidatos[gerador.randi_range(0, candidatos.size() - 1)]
		if salas[origem]["tipo"] != "normal":
			continue
		var delta: Vector2i = DIRECOES[gerador.randi_range(0, DIRECOES.size() - 1)]
		var destino: Vector2i = origem + delta
		if salas.has(destino) or destino.x < -6 or destino.x > 8 or destino.y < -5 or destino.y > 4:
			continue
		_adicionar(destino, "normal")
		_ligar(origem, destino)
		criadas += 1

	for posicao in salas:
		var info: Dictionary = salas[posicao]
		var tipo: String = info["tipo"]
		var mascara: int = mascara_das_conexoes(info["conexoes"])
		info["mascara"] = mascara
		if tipo == "normal":
			var possibilidades: Array = MODELOS.get(mascara, [])
			if possibilidades.is_empty():
				push_error("Sem sala manual para a máscara %d" % mascara)
				continue
			info["modelo"] = possibilidades[gerador.randi_range(0, possibilidades.size() - 1)]
		else:
			info["modelo"] = ESPECIAIS.get(tipo, "")


func _adicionar(posicao: Vector2i, tipo: String) -> void:
	salas[posicao] = {"tipo": tipo, "modelo": "", "conexoes": {}, "mascara": 0}


func _ligar(origem: Vector2i, destino: Vector2i) -> void:
	var direcao: Vector2i = destino - origem
	assert(direcao in DIRECOES, "Conexão não ortogonal")
	var saidas_a: Dictionary = salas[origem]["conexoes"]
	var saidas_b: Dictionary = salas[destino]["conexoes"]
	saidas_a[direcao] = destino
	saidas_b[-direcao] = origem


func obter(posicao: Vector2i) -> Dictionary:
	return salas.get(posicao, {})


func existe(posicao: Vector2i) -> bool:
	return salas.has(posicao)


func vizinho(posicao: Vector2i, direcao: Vector2i) -> Vector2i:
	var saidas: Dictionary = salas[posicao]["conexoes"]
	return saidas.get(direcao, posicao)


func visitar(posicao: Vector2i) -> void:
	visitadas[posicao] = true


func alcancaveis(pulo: bool, dash: bool, grapple: bool) -> Dictionary:
	var inicio: Vector2i = Vector2i.ZERO
	var vistos: Dictionary = {inicio: true}
	var fila: Array[Vector2i] = [inicio]
	while not fila.is_empty():
		var posicao: Vector2i = fila.pop_front()
		var saidas: Dictionary = salas[posicao]["conexoes"]
		for direcao in saidas:
			var destino: Vector2i = saidas[direcao]
			if vistos.has(destino) or not pode_atravessar(posicao, destino, pulo, dash, grapple):
				continue
			vistos[destino] = true
			fila.append(destino)
	return vistos


func pode_atravessar(origem: Vector2i, destino: Vector2i, pulo: bool, dash: bool, grapple: bool) -> bool:
	if not salas.has(origem) or not salas.has(destino):
		return false
	var saidas: Dictionary = salas[origem]["conexoes"]
	if not saidas.values().has(destino):
		return false
	var tipo_origem: String = salas[origem]["tipo"]
	var tipo_destino: String = salas[destino]["tipo"]
	if tipo_origem == "bloqueio_pulo" and destino.x > origem.x and not pulo:
		return false
	if tipo_origem == "bloqueio_dash" and destino.x > origem.x and not dash:
		return false
	if tipo_destino == "boss2" and not pulo:
		return false
	if tipo_destino == "boss3" and not dash:
		return false
	if tipo_destino == "final" and not grapple:
		return false
	return true
