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


func gerar(quantidade_ramos: int = 23, semente_fixa: int = 0, salas_ate_boss1: int = 7, salas_ate_boss2: int = 11, salas_entre_boss2_boss3: int = 7) -> void:
	salas.clear()
	visitadas.clear()
	if semente_fixa == 0:
		gerador.randomize()
	else:
		gerador.seed = semente_fixa
	semente = gerador.seed

	# Cada distancia conta as TRANSICOES desde o ponto indicado.
	# Mantemos a orientacao das cenas especiais, cujas saidas sao fixas:
	# inicio (esquerda/cima), boss1 (direita), boss2 (esquerda/cima),
	# bloqueios (esquerda/direita), boss3 (esquerda/direita), final (esquerda).
	salas_ate_boss1 = maxi(3, salas_ate_boss1)
	salas_ate_boss2 = maxi(4, salas_ate_boss2)
	salas_entre_boss2_boss3 = maxi(3, salas_entre_boss2_boss3)
	quantidade_ramos = maxi(0, quantidade_ramos)

	var inicio: Vector2i = Vector2i.ZERO
	_adicionar(inicio, "inicio")

	# TRILHA 1: oeste, saindo do inicio em direcao ao Ice Age Sid.
	# A cena do boss1 possui apenas a saida para a direita.
	for passo in range(1, salas_ate_boss1 + 1):
		var posicao: Vector2i = Vector2i(-passo, 0)
		var tipo: String = "boss1" if passo == salas_ate_boss1 else "normal"
		_adicionar(posicao, tipo)
		_ligar(posicao + Vector2i.RIGHT, posicao)

	# TRILHA 2: sobe pelo inicio e segue a leste ate Woodbreaker.
	# O bloqueio de pulo duplo deve ficar em trecho HORIZONTAL interior.
	var subida: Vector2i = Vector2i(0, -1)
	_adicionar(subida, "normal")
	_ligar(inicio, subida)
	var passo_pulo: int = clampi(roundi(float(salas_ate_boss2) * 0.6), 2, salas_ate_boss2 - 1)
	for passo in range(2, salas_ate_boss2 + 1):
		var posicao: Vector2i = Vector2i(passo - 1, -1)
		var tipo: String = "normal"
		if passo == salas_ate_boss2:
			tipo = "boss2"
		elif passo == passo_pulo:
			tipo = "bloqueio_pulo"
		_adicionar(posicao, tipo)
		_ligar(posicao + Vector2i.LEFT, posicao)

	# TRILHA 3: sobe a partir de Woodbreaker e segue a leste.
	# O bloqueio do dash tambem exige entrada/saida horizontal.
	var coluna_boss2: int = salas_ate_boss2 - 1
	var subida_final: Vector2i = Vector2i(coluna_boss2, -2)
	_adicionar(subida_final, "normal")
	_ligar(Vector2i(coluna_boss2, -1), subida_final)
	var passo_dash: int = clampi(roundi(float(salas_entre_boss2_boss3) * 0.6), 2, salas_entre_boss2_boss3 - 1)
	for passo in range(2, salas_entre_boss2_boss3 + 1):
		var posicao: Vector2i = Vector2i(coluna_boss2 + passo - 1, -2)
		var tipo: String = "normal"
		if passo == salas_entre_boss2_boss3:
			tipo = "boss3"
		elif passo == passo_dash:
			tipo = "bloqueio_dash"
		_adicionar(posicao, tipo)
		_ligar(posicao + Vector2i.LEFT, posicao)

	# O altar final permanece depois de Stonemaker.
	var posicao_boss3: Vector2i = Vector2i(coluna_boss2 + salas_entre_boss2_boss3 - 1, -2)
	var posicao_final: Vector2i = posicao_boss3 + Vector2i.RIGHT
	_adicionar(posicao_final, "final")
	_ligar(posicao_boss3, posicao_final)

	# Ramos opcionais sao sempre folhas anexadas a salas normais.
	# Nao criamos arestas automaticas entre celulas adjacentes, para
	# evitar atalhos que contornem os bloqueios das habilidades.
	var limite_esquerdo: int = -salas_ate_boss1 - 4
	var limite_direito: int = posicao_final.x + 4
	var limite_superior: int = -7
	var limite_inferior: int = 5
	var tentativas: int = 0
	var criadas: int = 0
	var max_tentativas: int = maxi(1200, quantidade_ramos * 100)
	while criadas < quantidade_ramos and tentativas < max_tentativas:
		tentativas += 1
		var candidatos: Array = salas.keys()
		var origem: Vector2i = candidatos[gerador.randi_range(0, candidatos.size() - 1)]
		if salas[origem]["tipo"] != "normal":
			continue
		var delta: Vector2i = DIRECOES[gerador.randi_range(0, DIRECOES.size() - 1)]
		var destino: Vector2i = origem + delta
		if salas.has(destino) or destino.x < limite_esquerdo or destino.x > limite_direito or destino.y < limite_superior or destino.y > limite_inferior:
			continue
		_adicionar(destino, "normal")
		_ligar(origem, destino)
		criadas += 1
	if criadas < quantidade_ramos:
		push_warning("Mapa: apenas %d/%d salas extras puderam ser geradas." % [criadas, quantidade_ramos])

	# Escolha de modelos manuais compatíveis com a mascara de cada celula.
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
