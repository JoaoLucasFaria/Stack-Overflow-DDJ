extends Node2D

@export var lista_cenas: Array[String] = [
	"res://cenas/sala_padrao.tscn",
	"res://cenas/sala_plataforma.tscn",
	"res://cenas/sala_queda.tscn",
	"res://cenas/sala_topo_1.tscn",
	"res://cenas/sala_esq_alta.tscn"
]

@export var cena_chefe: String = "res://cenas/sala_chefe.tscn"
@export var limite_salas_para_chefe: int = 50

var sala_atual: Node = null
var historico_salas: Array[String] = []
var indice_historico: int = -1
var direcao_chegada: String = "direita"

# Guarda o requisito que a sala ATUAL exige para a PRÓXIMA sala
var proxima_entrada_requerida: String = "esq_baixo" # Valor inicial padrão

func _ready() -> void:
	randomize()
	
	# Define obrigatoriamente a sala padrão como a primeira cena do jogo
	var caminho_inicial = "res://cenas/sala_padrao.tscn"
	
	historico_salas.append(caminho_inicial)
	indice_historico = 0
	
	direcao_chegada = "direita"
	carregar_sala(caminho_inicial)

func avancar_para_nova_sala() -> void:
	var caminho_sala = ""
	
	if indice_historico == historico_salas.size() - 1:
		if historico_salas.size() >= limite_salas_para_chefe:
			caminho_sala = cena_chefe
			print("Chegou na sala do chefe!")
		else:
			var cenas_compativeis: Array[String] = []
			
			var ultima_sala = ""
			if historico_salas.size() > 0:
				ultima_sala = historico_salas[historico_salas.size() - 1]
			
			# Lê o que a sala atual estipula como "proxima_entrada"
			if sala_atual != null:
				if sala_atual.has_method("get_proxima_entrada"):
					proxima_entrada_requerida = sala_atual.get_proxima_entrada()
				elif "proxima_entrada" in sala_atual:
					proxima_entrada_requerida = sala_atual.proxima_entrada
			
			print("--------------------------------------------------")
			print("Próxima entrada exigida pela sala atual: ", proxima_entrada_requerida)
			
			# Percorre todas as cenas para verificar a compatibilidade
			for caminho in lista_cenas:
				# Evita repetir a mesma sala consecutivamente
				if caminho == ultima_sala:
					print("-> Ignorada (é a última sala): ", caminho)
					continue
				
				var temp_cena = load(caminho).instantiate()
				
				var aceita: bool = true
				var tipo_entrada_candidata = ""
				
				# Obtém o tipo_entrada da sala candidata
				if temp_cena.has_method("get_tipo_entrada"):
					tipo_entrada_candidata = temp_cena.get_tipo_entrada()
				elif "tipo_entrada" in temp_cena:
					tipo_entrada_candidata = temp_cena.tipo_entrada
				
				print("Testando sala: ", caminho, " | Tem Entrada: [", tipo_entrada_candidata, "] vs Exigido: [", proxima_entrada_requerida, "]")
				
				# Validação estrita
				if tipo_entrada_candidata != "":
					if tipo_entrada_candidata != proxima_entrada_requerida:
						aceita = false
				else:
					aceita = false
				
				temp_cena.queue_free()
				
				if aceita:
					print("   -> ACEITE! Adicionada aos compatíveis.")
					cenas_compativeis.append(caminho)
				else:
					print("   -> REJEITADA por incompatibilidade.")
			
			print("Cenas compatíveis encontradas: ", cenas_compativeis)
			
			# Fallback caso nenhuma sala cumpra a regra estrita
			if cenas_compativeis.size() == 0:
				print("AVISO: Nenhuma sala compatível encontrada! Usando fallback.")
				for caminho in lista_cenas:
					if caminho != ultima_sala:
						cenas_compativeis.append(caminho)
			
			var indice_aleatorio_escolha = randi() % cenas_compativeis.size()
			caminho_sala = cenas_compativeis[indice_aleatorio_escolha]
			print(">>> SALA ESCOLHIDA PARA AVANÇAR: ", caminho_sala)
			print("--------------------------------------------------")
			
		historico_salas.append(caminho_sala)
		indice_historico += 1
	else:
		indice_historico += 1
		caminho_sala = historico_salas[indice_historico]
		
	direcao_chegada = "direita"
	carregar_sala(caminho_sala)

func voltar_para_sala_anterior() -> void:
	if indice_historico > 0:
		indice_historico -= 1
		var caminho_sala = historico_salas[indice_historico]
		direcao_chegada = "esquerda"
		carregar_sala(caminho_sala)
		print("Voltando para a sala anterior: ", caminho_sala)
	else:
		print("Você está na primeira sala da masmorra, não dá para voltar mais!")

func carregar_sala(caminho: String) -> void:
	if sala_atual != null:
		sala_atual.queue_free()
	
	var cena_sala = load(caminho)
	sala_atual = cena_sala.instantiate()
	
	# Atualiza o requisito da sala recém-carregada
	if sala_atual.has_method("get_proxima_entrada"):
		proxima_entrada_requerida = sala_atual.get_proxima_entrada()
	elif "proxima_entrada" in sala_atual:
		proxima_entrada_requerida = sala_atual.proxima_entrada
	else:
		proxima_entrada_requerida = "esq_baixo" # Padrão de segurança
	
	if sala_atual.has_method("configurar_spawn"):
		sala_atual.configurar_spawn(direcao_chegada)
	
	add_child(sala_atual)
	
	var porta_saida = sala_atual.get_node_or_null("PortaSaida")
	if porta_saida != null:
		porta_saida.connect("jogador_entrou", Callable(self, "_on_porta_saida_ativada"))
		
	var porta_entrada = sala_atual.get_node_or_null("PortaEntrada")
	if porta_entrada != null:
		porta_entrada.connect("jogador_entrou", Callable(self, "_on_porta_entrada_ativada"))

func _on_porta_saida_ativada() -> void:
	avancar_para_nova_sala()

func _on_porta_entrada_ativada() -> void:
	voltar_para_sala_anterior()
