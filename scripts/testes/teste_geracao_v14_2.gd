extends SceneTree

## Teste sem tela: godot --headless --path <pasta> --script res://scripts/testes/teste_geracao_v14_2.gd
## Executa 30 seeds fixas e verifica se cada uma preserva progressao,
## tres desafios opcionais por trecho e modelos de sala compativeis.

func _initialize() -> void:
	call_deferred("_verificar")


func _verificar() -> void:
	var erros: int = 0
	for seed in range(1, 31):
		var mapa: MapaMatriz = MapaMatriz.new()
		mapa.gerar(23, seed, 10, 11, 7, 4, 5, 3)
		if not _validar_mapa(mapa, seed):
			erros += 1
	if erros == 0:
		print("[V14.2] OK: 30 sementes sem erros de distribuicao/máscara/progressao.")
	else:
		push_error("[V14.2] FALHA em %d de 30 sementes." % erros)
	quit(0 if erros == 0 else 1)


func _validar_mapa(mapa: MapaMatriz, seed: int) -> bool:
	var sem_habilidade: Dictionary = mapa.alcancaveis(false, false, false)
	var com_pulo: Dictionary = mapa.alcancaveis(true, false, false)
	var com_dash: Dictionary = mapa.alcancaveis(true, true, false)
	var tudo: Dictionary = mapa.alcancaveis(true, true, true)
	var oeste: Dictionary = mapa._salas_da_trilha_oeste()
	var depois_boss2: Dictionary = mapa._salas_apos_boss2()
	var distancias: Dictionary = mapa._distancias_da_sala(Vector2i.ZERO)
	var quantidades: Array[int] = [0, 0, 0]
	var tudo_certo: bool = tudo.size() == mapa.salas.size()
	if not tudo_certo:
		push_error("Seed %d: salas desconectadas." % seed)

	for posicao in mapa.salas.keys():
		var sala: Dictionary = mapa.salas[posicao]
		var tipo: String = sala["tipo"]
		var mascara: int = MapaMatriz.mascara_das_conexoes(sala["conexoes"])
		if mascara != sala["mascara"] or not ResourceLoader.exists(String(sala["modelo"])):
			push_error("Seed %d: mascara/modelo invalido em %s (%s)." % [seed, str(posicao), tipo])
			tudo_certo = false
		if tipo != "exception":
			continue
		if mascara != 3 or int(distancias.get(posicao, 0)) < 3:
			push_error("Seed %d: Exception sem mascara lateral ou muito perto do inicio em %s." % [seed, str(posicao)])
			tudo_certo = false
		if oeste.has(posicao):
			quantidades[0] += 1
		elif com_pulo.has(posicao) and not sem_habilidade.has(posicao) and not depois_boss2.has(posicao):
			quantidades[1] += 1
		elif com_dash.has(posicao) and not com_pulo.has(posicao):
			quantidades[2] += 1
		else:
			push_error("Seed %d: Exception fora dos trechos previstos em %s." % [seed, str(posicao)])
			tudo_certo = false

	if quantidades != [3, 3, 3]:
		push_error("Seed %d: Exception por trecho %s (esperado [3, 3, 3])." % [seed, str(quantidades)])
		tudo_certo = false
	if mapa.obter(Vector2i(-1, 0)).get("tipo", "") != "normal":
		push_error("Seed %d: primeira sala a esquerda nao eh comum." % seed)
		tudo_certo = false
	for coord in mapa.salas.keys():
		var tipo: String = mapa.salas[coord]["tipo"]
		if tipo == "boss2" and sem_habilidade.has(coord):
			tudo_certo = false
		if tipo == "boss3" and com_pulo.has(coord):
			tudo_certo = false
	return tudo_certo
