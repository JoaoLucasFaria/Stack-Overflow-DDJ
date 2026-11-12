extends Node2D

## Mundo persistente em matriz. Um único Jogador atravessa passagens físicas;
## somente o módulo atual é instanciado. Chefes e habilidades são permanentes.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_HUD = preload("res://scripts/hud_matriz.gd")
const CENA_MAPA = preload("res://scripts/mapa_matriz.gd")
const CENA_DROP: PackedScene = preload("res://cenas/inimigos/drop_provisorio.tscn")
const CENAS_INIMIGOS: Dictionary = {
	"syntax_error": preload("res://cenas/inimigos/inimigo_syntax_error.tscn"),
	"null_pointer": preload("res://cenas/inimigos/inimigo_null_pointer.tscn"),
	"memory_leak": preload("res://cenas/inimigos/inimigo_memory_leak.tscn"),
	"segmentation_fault": preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn")
}

@export_category("Matriz procedural")
@export_range(0, 40, 1) var quantidade_salas_extras: int = 12
## Semente zero cria um mapa diferente a cada partida.
@export var semente_fixa: int = 0

var mapa: MapaMatriz
var coordenada_atual: Vector2i = Vector2i.ZERO
var sala_atual: SalaMatriz
var jogador: Jogador
var hud: HUDMatriz
var chefes_derrotados: Dictionary = {}
## Coordenada -> {nome do Marker2D: true}. Persistem até descansar no BREAKPOINT.
var inimigos_derrotados: Dictionary = {}
var mensagem: String = ""
var tempo_mensagem: float = 0.0
var em_transicao: bool = false
## Bloqueia uma segunda transição logo após a entrada em um módulo.
## O disparo real exige também atravessar o limite físico da sala.
const TEMPO_PROTECAO_ENTRADA: float = 0.30
const MARGEM_RECUPERACAO: float = 115.0
var protecao_entrada_restante: float = 0.0
var posicao_segura_atual: Vector2 = Vector2(100, 540)
var partida_terminou: bool = false


func _ready() -> void:
	mapa = CENA_MAPA.new() as MapaMatriz
	mapa.gerar(quantidade_salas_extras, semente_fixa)
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.pulo_duplo_liberado = false
	jogador.dash_component.dash_desbloqueado = false
	jogador.grapple_liberado = false
	jogador.morreu.connect(_ao_morrer)
	hud = CENA_HUD.new() as HUDMatriz
	add_child(hud)
	_entrar_sala(Vector2i.ZERO, Vector2i.ZERO)
	_aviso("Encontre Ice Age Sid. Explore atravessando as passagens.", 3.8)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("alternar_mapa"):
		hud.alternar_mapa()
	if Input.is_action_just_pressed("alternar_debug"):
		hud.alternar_debug()
	# Simula consumo de stack enquanto itens ativos ainda não existem.
	if hud.debug_visivel and Input.is_action_just_pressed("overflow_teste") and is_instance_valid(jogador):
		jogador.adicionar_overflow(25.0)
	if tempo_mensagem > 0.0:
		tempo_mensagem -= delta
		if tempo_mensagem <= 0.0:
			mensagem = ""
	_atualizar_dica()
	hud.atualizar(mapa, coordenada_atual, jogador, chefes_derrotados, mensagem)


func _physics_process(delta: float) -> void:
	if partida_terminou or em_transicao or sala_atual == null or not is_instance_valid(jogador):
		return
	if protecao_entrada_restante > 0.0:
		protecao_entrada_restante = maxf(0.0, protecao_entrada_restante - delta)
		return

	# ÚNICO ponto responsável pelas trocas de sala. Os gatilhos antigos
	# detectavam sobreposição perto da porta e podiam disparar duas vezes.
	var direcao: Vector2i = sala_atual.direcao_de_passagem_confirmada(jogador)
	if direcao != Vector2i.ZERO:
		_ao_atravessar_saida(direcao)
		return

	# Recuperação excepcional: se alguma física/colisão empurrar o jogador
	# para fora do módulo sem atravessar uma saída válida, evitar softlock.
	var colisao: CollisionShape2D = jogador.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if colisao == null:
		return
	var centro: Vector2 = sala_atual.to_local(colisao.global_position)
	if centro.x < -MARGEM_RECUPERACAO or centro.x > SalaMatriz.LARGURA + MARGEM_RECUPERACAO or centro.y < -MARGEM_RECUPERACAO or centro.y > SalaMatriz.ALTURA + MARGEM_RECUPERACAO:
		_recuperar_posicao_segura()


func _recuperar_posicao_segura() -> void:
	if not is_instance_valid(jogador):
		return
	jogador.preparar_para_nova_sala()
	jogador.global_position = posicao_segura_atual
	protecao_entrada_restante = TEMPO_PROTECAO_ENTRADA
	push_warning("Jogador recuperado após sair dos limites do módulo sem conexão válida.")



func _atualizar_dica() -> void:
	if partida_terminou or sala_atual == null or not is_instance_valid(jogador):
		hud.definir_dica("")
		return
	var tipo: String = sala_atual.dados.get("tipo", "normal")
	if tipo == "final":
		if sala_atual.grapple_realizado:
			hud.definir_dica("Aproxime-se do altar luminoso para encerrar o loop.")
		else:
			hud.definir_dica("G: conecte-se ao ponto de ancoragem azul.")
	elif tipo.begins_with("boss"):
		var numero: int = tipo.substr(4).to_int()
		if not chefes_derrotados.has(numero):
			hud.definir_dica("Guardião provisório: ataque com J ou clique (F ainda funciona).")
		else:
			hud.definir_dica("")
	else:
		hud.definir_dica("")


func _ao_atravessar_saida(direcao: Vector2i) -> void:
	if em_transicao or partida_terminou or sala_atual == null:
		return
	if not is_instance_valid(jogador):
		return
	var destino: Vector2i = mapa.vizinho(coordenada_atual, direcao)
	if destino == coordenada_atual:
		return
	if not mapa.pode_atravessar(
		coordenada_atual, destino,
		jogador.pulo_duplo_liberado,
		jogador.dash_component.dash_desbloqueado,
		jogador.grapple_liberado
	):
		# Requisitos lógicos são proteção extra; a geometria deve continuar
		# sendo o bloqueio principal. Reposicione antes da borda para não travar.
		_aviso("Caminho ainda inacessível.", 2.0)
		jogador.preparar_para_nova_sala()
		jogador.global_position = sala_atual.spawn_para_entrada(-direcao)
		posicao_segura_atual = jogador.global_position
		protecao_entrada_restante = TEMPO_PROTECAO_ENTRADA
		return
	em_transicao = true
	# A troca acontece após o frame físico, evitando remover colisões no meio da simulação.
	call_deferred("_entrar_sala", destino, direcao)


func _entrar_sala(destino: Vector2i, direcao: Vector2i) -> void:
	if not is_instance_valid(jogador):
		em_transicao = false
		return
	var info: Dictionary = mapa.obter(destino)
	if info.is_empty():
		push_error("A coordenada não tem sala no mapa: " + str(destino))
		em_transicao = false
		return
	var caminho: String = info.get("modelo", "")
	var recurso: PackedScene = load(caminho) as PackedScene
	if recurso == null:
		push_error("Sala manual não encontrada: " + caminho)
		em_transicao = false
		return
	var nova: SalaMatriz = recurso.instantiate() as SalaMatriz
	if nova == null or nova.mascara_saidas != int(info.get("mascara", 0)):
		push_error("Cena incompatível com a matriz: " + caminho)
		if nova != null:
			nova.free()
		em_transicao = false
		return
	nova.configurar(destino, info, jogador, chefes_derrotados)
	if sala_atual != null:
		remove_child(sala_atual)
		sala_atual.queue_free()
	sala_atual = nova
	coordenada_atual = destino
	add_child(sala_atual)
	move_child(jogador, get_child_count() - 1)
	jogador.preparar_para_nova_sala()
	jogador.global_position = sala_atual.spawn_para_entrada(direcao)
	posicao_segura_atual = jogador.global_position
	# Ignora qualquer sobreposição residual do quadro de física anterior.
	protecao_entrada_restante = TEMPO_PROTECAO_ENTRADA
	sala_atual.boss_derrotado.connect(_ao_derrotar_boss)
	sala_atual.altar_ativado.connect(_ao_vencer)
	_povoar_sala()
	_conectar_terminais()
	mapa.visitar(destino)
	em_transicao = false
	print("[MAPA] ", destino, " / ", info["tipo"], " / ", info["modelo"])


func _ao_derrotar_boss(identificador: int) -> void:
	if chefes_derrotados.has(identificador):
		return
	chefes_derrotados[identificador] = true
	match identificador:
		1:
			jogador.desbloquear_pulo_duplo()
			_aviso("ICE AGE SID derrotado: pulo duplo liberado!", 5.0)
		2:
			jogador.desbloquear_dash()
			_aviso("WOODBREAKER derrotado: malloc() / dash liberado!", 5.0)
		3:
			jogador.desbloquear_grapple()
			_aviso("STONEMAKER derrotado: grapple final liberado!", 5.0)


func _ao_morrer() -> void:
	partida_terminou = true
	_aviso("Processo encerrado. Pressione R para reiniciar.", 999.0)
	hud.mostrar_morte()


func _ao_vencer() -> void:
	if partida_terminou:
		return
	partida_terminou = true
	if is_instance_valid(jogador):
		jogador.set_physics_process(false)
	_aviso("return();  Loop infinito encerrado!", 999.0)
	hud.mostrar_vitoria()


func _aviso(texto: String, segundos: float) -> void:
	mensagem = texto
	tempo_mensagem = segundos


func _povoar_sala() -> void:
	## Somente marcadores manuais das cenas participam do spawn.
	if sala_atual == null:
		return
	var grupo: Node = sala_atual.get_node_or_null("Conteudo/SpawnsInimigos")
	if grupo == null:
		return
	var mortos: Dictionary = inimigos_derrotados.get(coordenada_atual, {})
	for ponto in grupo.get_children():
		var marcador: PontoSpawnInimigo = ponto as PontoSpawnInimigo
		if marcador == null or mortos.has(marcador.name):
			continue
		var cena: PackedScene = CENAS_INIMIGOS.get(marcador.tipo_inimigo) as PackedScene
		if cena == null:
			push_warning("Tipo de inimigo desconhecido: " + marcador.tipo_inimigo)
			continue
		var inimigo: InimigoBase = cena.instantiate() as InimigoBase
		inimigo.configurar(jogador)
		inimigo.position = marcador.position
		# O ponto é filho de Conteudo/SpawnsInimigos (ambos sem deslocamento).
		# Adicioná-lo sob o mesmo Conteudo preserva a posição local do módulo.
		sala_atual.get_node("Conteudo").add_child(inimigo)
		inimigo.global_position = marcador.global_position
		inimigo.derrotado.connect(_ao_inimigo_derrotado.bind(coordenada_atual, String(marcador.name)))


func _ao_inimigo_derrotado(posicao: Vector2, item_id: StringName, caiu: bool, sala: Vector2i, id_spawn: String) -> void:
	var mortos: Dictionary = inimigos_derrotados.get(sala, {})
	mortos[id_spawn] = true
	inimigos_derrotados[sala] = mortos
	if not caiu or sala != coordenada_atual or sala_atual == null:
		return
	var recompensa: Area2D = CENA_DROP.instantiate() as Area2D
	recompensa.call("configurar", item_id)
	sala_atual.get_node("Conteudo").add_child(recompensa)
	recompensa.global_position = posicao + Vector2(0, -25)
	recompensa.connect("coletado", _ao_coletar_drop)


func _ao_coletar_drop(item_id: StringName) -> void:
	## Futuro: encaminhar ao inventário de dois slots criado pelo Torugo.
	_aviso("Fragmento recuperado: %s (item ainda não equipável)." % String(item_id).replace("_", " "), 3.0)


func _conectar_terminais() -> void:
	if sala_atual == null:
		return
	for terminal in get_tree().get_nodes_in_group("terminais_breakpoint"):
		# Grupo ligado só no nó do módulo atual, não nos nós antigos em queue_free().
		var callback: Callable = Callable(self, "_ao_descansar")
		if sala_atual.is_ancestor_of(terminal) and terminal.has_signal("descansou") and not terminal.is_connected("descansou", callback):
			terminal.connect("descansou", callback)


func _ao_descansar() -> void:
	if partida_terminou or not is_instance_valid(jogador):
		return
	jogador.descansar()
	# Reaparecem nas salas ao retornar; chefes derrotados não reaparecem.
	inimigos_derrotados.clear()
	if sala_atual != null:
		for inimigo in get_tree().get_nodes_in_group("inimigos"):
			if sala_atual.is_ancestor_of(inimigo):
				inimigo.queue_free()
		for drop in sala_atual.get_node("Conteudo").get_children():
			if drop is Area2D and drop.is_in_group("drops_provisorios"):
				drop.queue_free()
		# Recria depois que os anteriores forem removidos.
		call_deferred("_povoar_sala")
	_aviso("BREAKPOINT: HP e STACK restaurados. Inimigos reiniciados.", 4.0)
