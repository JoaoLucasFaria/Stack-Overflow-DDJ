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
## Sala 17 e o BLOQUEIO DE DASH, nao entra no sorteio normal.
## Sala 22 e reservada em extremidade opcional apos pulo duplo.
## As salas originais permanecem no catalogo: nenhuma foi removida.
const MODELOS: Dictionary = {
	1: ["res://cenas/salas/sala_01.tscn"],
	2: ["res://cenas/salas/sala_02.tscn"],
	3: [
		"res://cenas/salas/sala_03.tscn",
		"res://cenas/salas/corredor_aberto.tscn",
		"res://cenas/salas/corredor_degraus.tscn",
		"res://cenas/salas/sala_armadilha_horizontal.tscn",
		"res://cenas/salas/sala_21.tscn",
	],
	4: ["res://cenas/salas/sala_04.tscn"],
	5: ["res://cenas/salas/sala_05.tscn", "res://cenas/salas/curva_esquerda_cima.tscn"],
	6: ["res://cenas/salas/sala_06.tscn", "res://cenas/salas/curva_direita_cima.tscn"],
	7: [
		"res://cenas/salas/sala_07.tscn",
		"res://cenas/salas/sala_18.tscn",
		"res://cenas/salas/sala_19.tscn",
	],
	8: ["res://cenas/salas/sala_08.tscn"],
	9: ["res://cenas/salas/sala_09.tscn"],
	10: ["res://cenas/salas/sala_10.tscn"],
	11: ["res://cenas/salas/sala_11.tscn"],
	12: ["res://cenas/salas/sala_12.tscn", "res://cenas/salas/poco_vertical.tscn"],
	13: ["res://cenas/salas/sala_13.tscn"],
	14: ["res://cenas/salas/sala_14.tscn"],
	15: ["res://cenas/salas/sala_15.tscn", "res://cenas/salas/sala_24.tscn"],
}
const ESPECIAIS: Dictionary = {
	"inicio": "res://cenas/salas/sala_inicio.tscn",
	"bloqueio_pulo": "res://cenas/salas/sala_pulo_duplo.tscn",
	"bloqueio_dash": "res://cenas/salas/sala_17.tscn",
	"boss1": "res://cenas/salas/sala_boss_1.tscn",
	"boss2": "res://cenas/salas/sala_boss_2.tscn",
	"boss3": "res://cenas/salas/sala_boss_3.tscn",
	"final": "res://cenas/salas/sala_altar_final.tscn",
	"exception": "res://cenas/salas/sala_exception_handler.tscn",
	"breakpoint": "res://cenas/salas/sala_breakpoint.tscn"
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


func gerar(quantidade_ramos: int = 23, semente_fixa: int = 0, salas_ate_boss1: int = 10, salas_ate_boss2: int = 11, salas_entre_boss2_boss3: int = 7, quantidade_breakpoints: int = 4, distancia_minima_breakpoints: int = 5, exceptions_por_trecho: int = 3) -> void:
	salas.clear()
	visitadas.clear()
	if semente_fixa == 0:
		gerador.randomize()
	else:
		gerador.seed = semente_fixa
	semente = gerador.seed

	# Uma transicao = uma aresta entre duas salas. O inicio, os chefes, os
	# bloqueios e o altar mantem as mascaras exigidas por suas cenas manuais.
	salas_ate_boss1 = maxi(4, salas_ate_boss1)
	salas_ate_boss2 = maxi(4, salas_ate_boss2)
	salas_entre_boss2_boss3 = maxi(4, salas_entre_boss2_boss3)
	quantidade_ramos = maxi(0, quantidade_ramos)
	var passo_pulo: int = clampi(roundi(float(salas_ate_boss2) * 0.6), 2, salas_ate_boss2 - 1)
	var passo_dash: int = clampi(roundi(float(salas_entre_boss2_boss3) * 0.6), 2, salas_entre_boss2_boss3 - 1)

	# A cada partida escolhemos novas curvas. Nao fazemos ligacoes automaticas
	# entre salas apenas adjacentes: isso poderia furar os bloqueios de progressao.
	var gerou_trilhas: bool = false
	for _tentativa in range(50):
		salas.clear()
		_adicionar(Vector2i.ZERO, "inicio")
		var trilha1: Array[Vector2i] = _sortear_trilha(Vector2i.ZERO, salas_ate_boss1, Vector2i.LEFT, Vector2i.LEFT, 0, 0)
		if trilha1.is_empty():
			continue
		_adicionar_trilha(trilha1, "boss1")

		var trilha2: Array[Vector2i] = _sortear_trilha(Vector2i.ZERO, salas_ate_boss2, Vector2i.UP, Vector2i.RIGHT, passo_pulo, 1)
		if trilha2.is_empty():
			continue
		_adicionar_trilha(trilha2, "boss2", passo_pulo, "bloqueio_pulo")

		var trilha3: Array[Vector2i] = _sortear_trilha(trilha2[-1], salas_entre_boss2_boss3, Vector2i.UP, Vector2i.RIGHT, passo_dash, 2)
		if trilha3.is_empty():
			continue
		# O boss 3 deve ter uma saida livre a direita para o altar final.
		var posicao_final: Vector2i = trilha3[-1] + Vector2i.RIGHT
		if salas.has(posicao_final) or trilha3.has(posicao_final):
			continue
		_adicionar_trilha(trilha3, "boss3", passo_dash, "bloqueio_dash")
		_adicionar(posicao_final, "final")
		_ligar(trilha3[-1], posicao_final)
		gerou_trilhas = true
		break


	if not gerou_trilhas:
		# Fallback conservador para casos extremos de tamanhos/colisoes.
		# Evita entregar mapa incompleto mesmo quando o caminho aleatorio falhar.
		push_warning("Mapa: sem rota curva valida apos 50 tentativas; usando rota linear segura.")
		_gerar_trilhas_retas(salas_ate_boss1, salas_ate_boss2, salas_entre_boss2_boss3, passo_pulo, passo_dash)

	# Ramos extras: so anexamos em salas normais (sem conectar novamente
	# celulas vizinhas por acidente). As coordenadas dos bosses sao variaveis.
	var limite_esquerdo: int = 0
	var limite_direito: int = 0
	var limite_superior: int = 0
	var limite_inferior: int = 0
	for posicao in salas:
		limite_esquerdo = mini(limite_esquerdo, posicao.x)
		limite_direito = maxi(limite_direito, posicao.x)
		limite_superior = mini(limite_superior, posicao.y)
		limite_inferior = maxi(limite_inferior, posicao.y)
	limite_esquerdo -= 5
	limite_direito += 5
	limite_superior -= 5
	limite_inferior += 5
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

	# V14.2: gera salas opcionais de Patches POR REGIAO, sem substituir
	# o caminho dos chefes nem criar ligacoes que contornem bloqueios.
	_distribuir_exceptions(exceptions_por_trecho)

	# Um Data Cache especial em ponta de ramo somente apos o pulo duplo.
	# O grafico e decidido antes de escolher modelos; nao revela esse bau antes da hora.
	_reservar_cache_pos_pulo_duplo()

	# Descansos nunca substituem o modulo reservado para o baú.
	_distribuir_breakpoints(quantidade_breakpoints, distancia_minima_breakpoints)

	# Modelos compativeis com todas as conexoes sorteadas.
	for posicao in salas:
		var info: Dictionary = salas[posicao]
		var tipo: String = info["tipo"]
		var mascara: int = mascara_das_conexoes(info["conexoes"])
		info["mascara"] = mascara
		if tipo == "normal":
			var fixo: String = String(info.get("modelo_fixo", ""))
			if not fixo.is_empty():
				info["modelo"] = fixo
				continue
			var possibilidades: Array = MODELOS.get(mascara, [])
			if possibilidades.is_empty():
				push_error("Sem sala manual para a mascara %d" % mascara)
				continue
			info["modelo"] = possibilidades[gerador.randi_range(0, possibilidades.size() - 1)]
		else:
			info["modelo"] = ESPECIAIS.get(tipo, "")

	# Curadoria PR19: a pool continua procedural, mas nao deixa as cenas
	# recem-curadas dependerem apenas de sorteios de baixa probabilidade.
	# So substituimos modelos normais com a MESMA mascara de conexoes.
	_priorizar_modelos_curados()
	_diagnosticar_modelos_curados()


# -----------------------------------------------------------------------------
# Curadoria PR19 - presenca de modelos novos quando a mascara permite
# -----------------------------------------------------------------------------
func _priorizar_modelos_curados() -> void:
	var distancias: Dictionary = _distancias_da_sala(Vector2i.ZERO)
	var corredores: Array[Vector2i] = [] # mascara 3: L/R (sala 21)
	var cruzamentos_t: Array[Vector2i] = [] # mascara 7: L/R/U (salas 18 e 19)
	var cruzamentos_4: Array[Vector2i] = [] # mascara 15 (sala 24)

	for posicao in salas.keys():
		var info: Dictionary = salas[posicao]
		# Nunca troca Boss, Exception, BREAKPOINT, bloqueios ou o cache 22.
		if info["tipo"] != "normal" or not String(info.get("modelo_fixo", "")).is_empty():
			continue
		match int(info["mascara"]):
			3:
				corredores.append(posicao)
			7:
				cruzamentos_t.append(posicao)
			15:
				cruzamentos_4.append(posicao)

	# Proximo ao inicio = mais facil de encontrar durante os testes.
	# O resto do mapa continua sorteado pela pool normal.
	if not corredores.is_empty():
		var pos_corredor: Vector2i = _candidato_mais_proximo(corredores, distancias)
		salas[pos_corredor]["modelo"] = "res://cenas/salas/sala_21.tscn"

	# As cenas 18 e 19 compartilham a mascara 7; com dois locais
	# elegiveis ambas aparecem. Com um local, alterna entre elas por run.
	var ordem: Array[String] = [
		"res://cenas/salas/sala_18.tscn",
		"res://cenas/salas/sala_19.tscn"
	]
	if gerador.randi_range(0, 1) == 1:
		ordem.reverse()
	for caminho in ordem:
		if cruzamentos_t.is_empty():
			break
		var pos_t: Vector2i = _candidato_mais_proximo(cruzamentos_t, distancias)
		salas[pos_t]["modelo"] = caminho
		cruzamentos_t.erase(pos_t)

	# A sala 24 so pode existir quando houver de fato quatro conexoes.
	# Nao cria arestas artificiais nem atalhos que furem a progressao.
	if not cruzamentos_4.is_empty():
		var pos_cruzamento: Vector2i = _candidato_mais_proximo(cruzamentos_4, distancias)
		salas[pos_cruzamento]["modelo"] = "res://cenas/salas/sala_24.tscn"


func _candidato_mais_proximo(candidatos: Array[Vector2i], distancias: Dictionary) -> Vector2i:
	var escolhido: Vector2i = candidatos[0]
	for posicao in candidatos:
		if int(distancias.get(posicao, 999999)) < int(distancias.get(escolhido, 999999)):
			escolhido = posicao
	return escolhido


func _diagnosticar_modelos_curados() -> void:
	# Mostra o que realmente foi sorteado NA RUN, sem revelar no mapa
	# visual do jogador salas ainda nao exploradas.
	var nomes: Array[String] = ["17", "18", "19", "21", "22", "24"]
	var contagens: Dictionary = {}
	for nome in nomes:
		contagens[nome] = 0
	var elegiveis: Dictionary = {3: 0, 7: 0, 15: 0}
	var distancias: Dictionary = _distancias_da_sala(Vector2i.ZERO)
	for posicao in salas.keys():
		var info: Dictionary = salas[posicao]
		if info["tipo"] == "normal" and elegiveis.has(int(info["mascara"])):
			elegiveis[int(info["mascara"])] += 1
		var caminho: String = String(info.get("modelo", ""))
		for nome in nomes:
			if caminho.ends_with("/sala_%s.tscn" % nome):
				contagens[nome] += 1
				print("[SALAS NOVAS] sala_%s em %s (distancia %d, tipo %s)" % [nome, str(posicao), int(distancias.get(posicao, -1)), String(info["tipo"])])
	print("[SALAS NOVAS] Totais na run: 17=%d | 18=%d | 19=%d | 21=%d | 22=%d | 24=%d" % [contagens["17"], contagens["18"], contagens["19"], contagens["21"], contagens["22"], contagens["24"]])
	print("[SALAS NOVAS] Modelos normais compativeis: mascara 3=%d, mascara 7=%d, mascara 15=%d" % [elegiveis[3], elegiveis[7], elegiveis[15]])
	if int(elegiveis[15]) == 0:
		print("[SALAS NOVAS] sala_24 indisponivel nesta run: nenhuma sala normal com 4 conexoes.")
	if int(elegiveis[7]) == 0:
		print("[SALAS NOVAS] salas_18/19 indisponiveis nesta run: nenhuma sala normal com mascara 7.")


# -----------------------------------------------------------------------------
# V14.2 - Ramificacoes opcionais de Exception Handler
# -----------------------------------------------------------------------------
func _distribuir_exceptions(quantidade_por_trecho: int) -> void:
	## Setores: 0 = Oeste/Boss1; 1 = apos pulo/Boss2;
	## 2 = apos dash/Boss3. Cada desafio e opcional e tem pelo
	## menos uma sala comum ANTES e uma DEPOIS do altar.
	quantidade_por_trecho = clampi(quantidade_por_trecho, 0, 5)
	if quantidade_por_trecho == 0:
		return
	for regiao in range(3):
		var total: int = 0
		for _indice in range(quantidade_por_trecho):
			# Recalcula: as salas comuns dos ramos anteriores podem servir
			# como ancoras alternativas quando o setor fica apertado.
			var candidatos: Array[Vector2i] = _candidatos_exception(regiao)
			_embaralhar_coordenadas(candidatos)
			var encontrou: bool = false
			for tentativa in range(2):
				for ancora in candidatos:
					# Evita concentrar todas as arenas em um mesmo ponto.
					if tentativa == 0 and _tem_ramo_exception(ancora):
						continue
					if _tentar_criar_ramo_exception(ancora):
						total += 1
						encontrou = true
						break
				if encontrou:
					break
			if not encontrou:
				break
		if total < quantidade_por_trecho:
			push_warning("Exception Handler: trecho %d ficou com %d/%d arenas. Seed: %d." % [regiao + 1, total, quantidade_por_trecho, semente])
		print("[EXCEPTION] Trecho %d: %d/%d arenas opcionais" % [regiao + 1, total, quantidade_por_trecho])


func _candidatos_exception(regiao: int) -> Array[Vector2i]:
	var oeste: Dictionary = _salas_da_trilha_oeste()
	var sem_habilidades: Dictionary = alcancaveis(false, false, false)
	var com_pulo: Dictionary = alcancaveis(true, false, false)
	var com_dash: Dictionary = alcancaveis(true, true, false)
	var depois_boss2: Dictionary = _salas_apos_boss2()
	var distancia_inicio: Dictionary = _distancias_da_sala(Vector2i.ZERO)
	var candidatos: Array[Vector2i] = []
	for posicao in salas.keys():
		if salas[posicao]["tipo"] != "normal":
			continue
		var elegivel: bool = false
		match regiao:
			0:
				# Apenas a rota OESTE do Boss 1; nunca encostado no spawn.
				elegivel = oeste.has(posicao) and int(distancia_inicio.get(posicao, 0)) >= 2
			1:
				# Acessivel somente depois de adquirir o pulo duplo.
				elegivel = com_pulo.has(posicao) and not sem_habilidades.has(posicao) and not depois_boss2.has(posicao)
			2:
				# Acessivel somente depois de adquirir o dash.
				elegivel = com_dash.has(posicao) and not com_pulo.has(posicao)
		if elegivel:
			candidatos.append(posicao)
	return candidatos


func _salas_da_trilha_oeste() -> Dictionary:
	## O mapa eh uma arvore; isolando a aresta do inicio para a esquerda,
	## encontramos a regiao do Boss 1 sem confundir com o outro caminho.
	var primeiro: Vector2i = salas[Vector2i.ZERO]["conexoes"].get(Vector2i.LEFT, Vector2i.ZERO)
	if primeiro == Vector2i.ZERO:
		return {}
	var encontradas: Dictionary = {primeiro: true}
	var fila: Array[Vector2i] = [primeiro]
	var indice: int = 0
	while indice < fila.size():
		var posicao: Vector2i = fila[indice]
		indice += 1
		for proximo in salas[posicao]["conexoes"].values():
			if proximo == Vector2i.ZERO or encontradas.has(proximo):
				continue
			encontradas[proximo] = true
			fila.append(proximo)
	return encontradas


func _salas_apos_boss2() -> Dictionary:
	## Evita que os Patches destinados ao Boss 2 sejam sorteados
	## depois da arena desse chefe (que bloqueia a passagem ate a derrota).
	var boss2: Vector2i = Vector2i.ZERO
	var achou: bool = false
	for posicao in salas.keys():
		if salas[posicao]["tipo"] == "boss2":
			boss2 = posicao
			achou = true
			break
	if not achou:
		return {}
	var saida: Vector2i = salas[boss2]["conexoes"].get(Vector2i.UP, boss2)
	if saida == boss2:
		return {}
	var encontradas: Dictionary = {saida: true}
	var fila: Array[Vector2i] = [saida]
	var indice: int = 0
	while indice < fila.size():
		var atual: Vector2i = fila[indice]
		indice += 1
		for proximo in salas[atual]["conexoes"].values():
			if proximo == boss2 or encontradas.has(proximo):
				continue
			encontradas[proximo] = true
			fila.append(proximo)
	return encontradas


func _tem_ramo_exception(ancora: Vector2i) -> bool:
	## Os ramos novos carregam uma marca de origem: evita aglomera-los.
	for sala in salas.values():
		if sala.get("origem_exception", Vector2i(99999, 99999)) == ancora:
			return true
	return false


func _embaralhar_coordenadas(valores: Array[Vector2i]) -> void:
	for i in range(valores.size() - 1, 0, -1):
		var j: int = gerador.randi_range(0, i)
		var auxiliar: Vector2i = valores[i]
		valores[i] = valores[j]
		valores[j] = auxiliar


func _tentar_criar_ramo_exception(ancora: Vector2i) -> bool:
	var visitados: Dictionary = {ancora: true}
	var anteriores: Array[Vector2i] = []
	var rota: Array[Vector2i] = _buscar_rota_exception(ancora, anteriores, visitados)
	if rota.is_empty():
		return false
	var anterior: Vector2i = ancora
	for i in range(rota.size()):
		var destino: Vector2i = rota[i]
		# Penultima sala: corredor horizontal reservado ao altar.
		_adicionar(destino, "exception" if i == rota.size() - 2 else "normal")
		salas[destino]["origem_exception"] = ancora
		_ligar(anterior, destino)
		anterior = destino
	return true


func _buscar_rota_exception(posicao: Vector2i, comuns: Array[Vector2i], usados: Dictionary) -> Array[Vector2i]:
	## Procura um corredor horizontal com duas saidas para o altar.
	## Se o terreno estiver cheio, faz ate quatro salas comuns de desvio,
	## sempre usando somente coordenadas vazias, sem criar atalhos.
	if not comuns.is_empty():
		var horizontais: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
		_embaralhar_coordenadas(horizontais)
		for horizontal in horizontais:
			var altar: Vector2i = posicao + horizontal
			var ponta: Vector2i = altar + horizontal
			if salas.has(altar) or salas.has(ponta) or usados.has(altar) or usados.has(ponta):
				continue
			var encontrada: Array[Vector2i] = comuns.duplicate()
			encontrada.append(altar)
			encontrada.append(ponta)
			return encontrada
	if comuns.size() >= 4:
		return []
	var direcoes: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	_embaralhar_coordenadas(direcoes)
	for direcao in direcoes:
		var seguinte: Vector2i = posicao + direcao
		if salas.has(seguinte) or usados.has(seguinte):
			continue
		comuns.append(seguinte)
		usados[seguinte] = true
		var tentativa: Array[Vector2i] = _buscar_rota_exception(seguinte, comuns, usados)
		comuns.pop_back()
		usados.erase(seguinte)
		if not tentativa.is_empty():
			return tentativa
	return []


func _distancias_da_sala(origem: Vector2i) -> Dictionary:
	## BFS no grafo real (numero de transicoes), nao distancia em X/Y.
	var distancias: Dictionary = {origem: 0}
	var fila: Array[Vector2i] = [origem]
	var indice: int = 0
	while indice < fila.size():
		var atual: Vector2i = fila[indice]
		indice += 1
		for vizinho in salas[atual]["conexoes"].values():
			var proximo: Vector2i = vizinho
			if distancias.has(proximo):
				continue
			distancias[proximo] = int(distancias[atual]) + 1
			fila.append(proximo)
	return distancias



# Cache opcional da sala 22. Escolhe apenas a regiao que se torna acessivel
# apos o salto duplo, antes do boss 2. Nunca no corredor obrigatorio.
# Ponta L=1 implica que o novo modulo fica a DIREITA da sala de origem.
func _reservar_cache_pos_pulo_duplo() -> void:
	var antes_pulo: Dictionary = alcancaveis(false, false, false)
	var depois_pulo: Dictionary = alcancaveis(true, false, false)
	var depois_boss2: Dictionary = _salas_apos_boss2()
	var candidatos_ponta: Array[Vector2i] = []
	var candidatos_ancora: Array[Vector2i] = []
	var candidatos_desvio: Array[Vector2i] = []
	for posicao in salas.keys():
		var info: Dictionary = salas[posicao]
		if info["tipo"] != "normal" or info.has("origem_exception"):
			continue
		if not depois_pulo.has(posicao) or antes_pulo.has(posicao) or depois_boss2.has(posicao):
			continue
		var conexoes: Dictionary = info["conexoes"]
		if mascara_das_conexoes(conexoes) == ESQUERDA:
			candidatos_ponta.append(posicao)
		if not salas.has(posicao + Vector2i.RIGHT) and not conexoes.has(Vector2i.RIGHT):
			candidatos_ancora.append(posicao)
		else:
			candidatos_desvio.append(posicao)
	_embaralhar_coordenadas(candidatos_ponta)
	_embaralhar_coordenadas(candidatos_ancora)
	_embaralhar_coordenadas(candidatos_desvio)
	var destino: Vector2i = Vector2i.ZERO
	if not candidatos_ponta.is_empty():
		destino = candidatos_ponta[0]
	elif not candidatos_ancora.is_empty():
		var origem: Vector2i = candidatos_ancora[0]
		destino = origem + Vector2i.RIGHT
		_adicionar(destino, "normal")
		_ligar(origem, destino)
	else:
		# Fallback: desvio em dois passos, sem diagonal no grafo.
		for ancora in candidatos_desvio:
			for direcao in [Vector2i.UP, Vector2i.DOWN]:
				var intermediaria: Vector2i = ancora + direcao
				var ponta: Vector2i = intermediaria + Vector2i.RIGHT
				if salas.has(intermediaria) or salas.has(ponta):
					continue
				_adicionar(intermediaria, "normal")
				_ligar(ancora, intermediaria)
				_adicionar(ponta, "normal")
				_ligar(intermediaria, ponta)
				destino = ponta
				break
			if destino != Vector2i.ZERO:
				break
		if destino == Vector2i.ZERO:
			push_warning("Sala 22 nao pôde ser posicionada depois do pulo duplo. Seed: %d" % semente)
			return
	salas[destino]["modelo_fixo"] = "res://cenas/salas/sala_22.tscn"
	salas[destino]["reservada_bau"] = true
	print("[CACHE] Sala 22 em ponta pos-pulo: ", destino)

func _distribuir_breakpoints(quantidade: int, distancia_minima: int) -> void:
	## O terminal inicial ja existe. Estes sao os BREAKPOINTS adicionais.
	quantidade = maxi(0, quantidade)
	distancia_minima = maxi(1, distancia_minima)
	if quantidade == 0:
		return

	var candidatos: Array[Vector2i] = []
	for posicao in salas:
		var info: Dictionary = salas[posicao]
		if info["tipo"] != "normal" or bool(info.get("reservada_bau", false)):
			continue
		# Preferimos salas de travessia, mas pontas sem saida podem
		# ser usadas se necessario para manter a distancia e a quantidade.
		var conexoes: Dictionary = info["conexoes"]
		if conexoes.is_empty():
			continue
		var adjacente_boss: bool = false
		for vizinho in conexoes.values():
			if String(salas[vizinho]["tipo"]).begins_with("boss"):
				adjacente_boss = true
				break
		if not adjacente_boss:
			candidatos.append(posicao)
	if candidatos.is_empty():
		push_warning("Mapa: nenhuma sala elegivel para BREAKPOINT adicional.")
		return

	var cache: Dictionary = {Vector2i.ZERO: _distancias_da_sala(Vector2i.ZERO)}
	var melhor_conjunto: Array[Vector2i] = []
	# Variamos a ordem e o desempate para evitar que a selecao gulosa
	# fique presa numa ramificacao e nao encontre todos os terminais.
	for _tentativa in range(60):
		var escolhidos: Array[Vector2i] = []
		var pontos_existentes: Array[Vector2i] = [Vector2i.ZERO]
		while escolhidos.size() < quantidade:
			var melhor_pontuacao: float = -INF
			var proximo_ponto: Vector2i = Vector2i.ZERO
			var encontrou: bool = false
			for candidato in candidatos:
				if escolhidos.has(candidato):
					continue
				var menor_distancia: int = 999999
				for ponto in pontos_existentes:
					if not cache.has(ponto):
						cache[ponto] = _distancias_da_sala(ponto)
					var distancias: Dictionary = cache[ponto]
					menor_distancia = mini(menor_distancia, int(distancias.get(candidato, 999999)))
				if menor_distancia < distancia_minima:
					continue
				# Privilegia intervalos de ~5 a 8 salas, mas permite mais
				# distancia quando o formato do mundo exigir.
				var pontuacao: float = -absf(float(menor_distancia - (distancia_minima + 2)))
				if salas[candidato]["conexoes"].size() >= 2:
					pontuacao += 1.5 # Passagens sao melhores que becos sem saida.
				pontuacao += gerador.randf_range(-2.5, 2.5)
				if pontuacao > melhor_pontuacao:
					melhor_pontuacao = pontuacao
					proximo_ponto = candidato
					encontrou = true
			if not encontrou:
				break
			escolhidos.append(proximo_ponto)
			pontos_existentes.append(proximo_ponto)
		if escolhidos.size() > melhor_conjunto.size():
			melhor_conjunto = escolhidos.duplicate()
		if melhor_conjunto.size() == quantidade:
			break

	for posicao in melhor_conjunto:
		salas[posicao]["tipo"] = "breakpoint"
	if melhor_conjunto.size() < quantidade:
		push_warning("Mapa: distribuidos %d de %d BREAKPOINTS adicionais; nao foi possivel respeitar a distancia minima %d em todos." % [melhor_conjunto.size(), quantidade, distancia_minima])


func _adicionar_trilha(trilha: Array[Vector2i], tipo_boss: String, indice_bloqueio: int = -1, tipo_bloqueio: String = "") -> void:
	for i in range(1, trilha.size()):
		var tipo: String = "normal"
		if i == trilha.size() - 1:
			tipo = tipo_boss
		elif i == indice_bloqueio:
			tipo = tipo_bloqueio
		_adicionar(trilha[i], tipo)
		_ligar(trilha[i - 1], trilha[i])


func _sortear_trilha(origem: Vector2i, passos: int, entrada: Vector2i, chegada: Vector2i, indice_bloqueio: int, regiao: int) -> Array[Vector2i]:
	var caminho: Array[Vector2i] = [origem]
	var usados: Dictionary = {}
	usados[origem] = true
	var expansoes: Dictionary = {"valor": 0}
	var subidas_minimas: int = 0
	if regiao == 0 and passos >= 6:
		subidas_minimas = 2
	elif regiao == 1 and passos >= 8:
		subidas_minimas = 2  # Inclui a primeira subida obrigatoria.
	elif regiao == 2 and passos >= 7:
		subidas_minimas = 2
	if _buscar_trilha(caminho, usados, expansoes, passos, 1, entrada, chegada, indice_bloqueio, regiao, Vector2i.ZERO, 0, 0, subidas_minimas):
		return caminho
	return []


func _buscar_trilha(caminho: Array[Vector2i], usados: Dictionary, expansoes: Dictionary, passos: int, passo: int, entrada: Vector2i, chegada: Vector2i, indice_bloqueio: int, regiao: int, anterior: Vector2i, repeticoes: int, verticais: int, verticais_minimas: int) -> bool:
	expansoes["valor"] = int(expansoes["valor"]) + 1
	if int(expansoes["valor"]) > 15000:
		return false
	if passo > passos:
		return verticais >= verticais_minimas

	var opcoes: Array[Vector2i] = []
	if passo == 1:
		opcoes.append(entrada)
	elif passo == passos:
		opcoes.append(chegada)
	elif indice_bloqueio > 0 and (passo == indice_bloqueio or passo == indice_bloqueio + 1):
		# A cena do bloqueio tem entrada esquerda e saida direita.
		opcoes.append(Vector2i.RIGHT)
	else:
		for direcao in DIRECOES:
			opcoes.append(direcao)
		for i in range(opcoes.size() - 1, 0, -1):
			var sorteado: int = gerador.randi_range(0, i)
			var auxiliar: Vector2i = opcoes[i]
			opcoes[i] = opcoes[sorteado]
			opcoes[sorteado] = auxiliar

	var origem: Vector2i = caminho[0]
	for direcao in opcoes:
		var proxima: Vector2i = caminho[-1] + direcao
		if usados.has(proxima) or salas.has(proxima):
			continue
		# Trilhas ocupam setores distintos para nao se cruzarem.
		match regiao:
			0: # Oeste da sala inicial, com pequenas mudancas de altitude.
				if proxima.x >= 0 or proxima.x < -passos - 3 or absi(proxima.y) > 4:
					continue
			1: # Acima e a leste da sala inicial.
				if proxima.x < 0 or proxima.x > passos + 3 or proxima.y > -1 or proxima.y < -6:
					continue
			2: # Acima e a leste do Boss 2.
				if proxima.x < origem.x or proxima.x > origem.x + passos + 3 or proxima.y > origem.y - 1 or proxima.y < origem.y - 6:
					continue

		var novas_repeticoes: int = repeticoes + 1 if direcao == anterior else 1
		if novas_repeticoes > 3:
			continue
		var novos_verticais: int = verticais + (1 if direcao.y != 0 else 0)
		if novos_verticais + (passos - passo) < verticais_minimas:
			continue
		# O Boss 2 precisa ter espaco livre acima para a saida da trilha 3.
		if regiao == 1 and passo == passos:
			var acima: Vector2i = proxima + Vector2i.UP
			if usados.has(acima) or salas.has(acima):
				continue
		caminho.append(proxima)
		usados[proxima] = true
		if _buscar_trilha(caminho, usados, expansoes, passos, passo + 1, entrada, chegada, indice_bloqueio, regiao, direcao, novas_repeticoes, novos_verticais, verticais_minimas):
			return true
		caminho.pop_back()
		usados.erase(proxima)
	return false


func _gerar_trilhas_retas(n1: int, n2: int, n3: int, passo_pulo: int, passo_dash: int) -> void:
	salas.clear()
	_adicionar(Vector2i.ZERO, "inicio")
	for i in range(1, n1 + 1):
		var p: Vector2i = Vector2i(-i, 0)
		_adicionar(p, "boss1" if i == n1 else "normal")
		_ligar(p + Vector2i.RIGHT, p)
	var acima: Vector2i = Vector2i(0, -1)
	_adicionar(acima, "normal")
	_ligar(Vector2i.ZERO, acima)
	for i in range(2, n2 + 1):
		var p: Vector2i = Vector2i(i - 1, -1)
		_adicionar(p, "boss2" if i == n2 else ("bloqueio_pulo" if i == passo_pulo else "normal"))
		_ligar(p + Vector2i.LEFT, p)
	var coluna: int = n2 - 1
	var proxima: Vector2i = Vector2i(coluna, -2)
	_adicionar(proxima, "normal")
	_ligar(Vector2i(coluna, -1), proxima)
	for i in range(2, n3 + 1):
		var p: Vector2i = Vector2i(coluna + i - 1, -2)
		_adicionar(p, "boss3" if i == n3 else ("bloqueio_dash" if i == passo_dash else "normal"))
		_ligar(p + Vector2i.LEFT, p)
	var final: Vector2i = Vector2i(coluna + n3, -2)
	_adicionar(final, "final")
	_ligar(final + Vector2i.LEFT, final)

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
