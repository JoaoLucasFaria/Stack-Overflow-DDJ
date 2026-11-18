extends Node2D

## Mundo persistente em matriz. Um único Jogador atravessa passagens físicas;
## somente o módulo atual é instanciado. Chefes e habilidades são permanentes.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_HUD = preload("res://scripts/hud_matriz.gd")
const CENA_MAPA = preload("res://scripts/mapa_matriz.gd")
const CENA_DROP: PackedScene = preload("res://cenas/inimigos/drop_provisorio.tscn")
const CENA_EXCEPTION_HANDLER = preload("res://scripts/desafios/controlador_exception_handler.gd")
const CENA_HUD_SUPERIOR = preload("res://scripts/ui/hud_superior.gd")
const CENAS_INIMIGOS: Dictionary = {
	"syntax_error": preload("res://cenas/inimigos/inimigo_syntax_error.tscn"),
	"null_pointer": preload("res://cenas/inimigos/inimigo_null_pointer.tscn"),
	"memory_leak": preload("res://cenas/inimigos/inimigo_memory_leak.tscn"),
	"segmentation_fault": preload("res://cenas/inimigos/inimigo_segmentation_fault.tscn"),
	"fork_bomb": preload("res://cenas/inimigos/inimigo_fork_bomb.tscn"),
	"race_condition": preload("res://cenas/inimigos/inimigo_race_condition.tscn"),
	"deadlock": preload("res://cenas/inimigos/inimigo_deadlock.tscn"),
	"out_of_bounds": preload("res://cenas/inimigos/inimigo_out_of_bounds.tscn")
}

@export_category("Matriz procedural")
@export_range(6, 18, 1) var salas_ate_boss1: int = 10
@export_range(4, 18, 1) var salas_ate_boss2: int = 11
@export_range(3, 15, 1) var salas_entre_boss2_boss3: int = 7
@export_range(0, 50, 1) var quantidade_salas_extras: int = 23
@export_category("Exception Handlers")
@export_range(0, 5, 1) var exceptions_por_trecho: int = 3
@export_category("BREAKPOINTS")
@export_range(0, 12, 1) var breakpoints_adicionais: int = 4
@export_range(2, 15, 1) var distancia_minima_breakpoints: int = 5
## Semente zero cria um mapa diferente a cada partida.
@export var semente_fixa: int = 0

var mapa: MapaMatriz
var coordenada_atual: Vector2i = Vector2i.ZERO
var sala_atual: SalaMatriz
var jogador: Jogador
var hud: HUDMatriz
var hud_superior: HUDSuperior
var camera_principal: Camera2D
var chefes_derrotados: Dictionary = {}
## Coordenadas dos Exception Handlers concluidos nesta run.
## Nao sao reiniciados ao descansar no BREAKPOINT.
var desafios_exception_concluidos: Dictionary = {}
## Coordenada -> {nome do Marker2D: true}. Persistem até descansar no BREAKPOINT.
var inimigos_derrotados: Dictionary = {}
## Coordenada -> {nome do marcador: tipo sorteado}. Mantem a escolha ate descansar.
var tipos_inimigos_sorteados: Dictionary = {}
## Coordenada -> {nome do marcador: estado do Memory Leak}. Limpo no BREAKPOINT.
var estados_inimigos: Dictionary = {}
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
var teleporte_item_ativo: bool = false


func _ready() -> void:
	add_to_group("main_campanha")
	# O mundo mantem 1152x648, desenhado abaixo da HUD de 72px.
	# A camera fixa evita perder o enquadramento ao sair das arenas de boss.
	camera_principal = Camera2D.new()
	camera_principal.name = "CameraCampanha"
	camera_principal.position = Vector2(576.0, 288.0)
	add_child(camera_principal)
	camera_principal.make_current()
	mapa = CENA_MAPA.new() as MapaMatriz
	mapa.gerar(
		quantidade_salas_extras,
		semente_fixa,
		salas_ate_boss1,
		salas_ate_boss2,
		salas_entre_boss2_boss3,
		breakpoints_adicionais,
		distancia_minima_breakpoints,
		exceptions_por_trecho
	)
	jogador = CENA_JOGADOR.instantiate() as Jogador
	add_child(jogador)
	jogador.pulo_duplo_liberado = false
	jogador.dash_component.dash_desbloqueado = false
	jogador.grapple_liberado = false
	jogador.morreu.connect(_ao_morrer)
	jogador.utilitarios.aviso.connect(func(texto: String): _aviso(texto, 3.2))
	jogador.overflow_estourou.connect(_ao_overflow_estourou)
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	inventario.aviso.connect(_ao_aviso_equipamento)
	hud = CENA_HUD.new() as HUDMatriz
	hud.usar_hud_superior = true
	add_child(hud)
	hud.teleporte_confirmado.connect(_ao_teleporte_confirmado)
	hud.teleporte_cancelado.connect(_ao_teleporte_cancelado)
	# Os indicadores antigos continuam nas arenas de teste, mas sao
	# ocultados na campanha para nao duplicar HP/STACK e Q/E.
	if is_instance_valid(inventario.hud):
		inventario.hud.hide()
	hud_superior = CENA_HUD_SUPERIOR.new() as HUDSuperior
	add_child(hud_superior)
	hud_superior.configurar(jogador, inventario)
	_entrar_sala(Vector2i.ZERO, Vector2i.ZERO)
	_aviso("Encontre o Guardiao 1. Explore atravessando as passagens.", 3.8)


## Atalho exclusivo de debug para testar salas sem derrotar os Bosses.
## Asterisco (*) — inclusive no teclado numerico — desbloqueia
## uma habilidade por toque, respeitando a ordem da campanha.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or partida_terminou or not is_instance_valid(jogador):
		return
	if not event is InputEventKey:
		return
	var tecla: InputEventKey = event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	var eh_asterisco: bool = (tecla.keycode == KEY_KP_MULTIPLY
		or tecla.keycode == KEY_ASTERISK
		or tecla.unicode == KEY_ASTERISK)
	if not eh_asterisco:
		return

	var aviso_debug: String = ""
	if not jogador.pulo_duplo_liberado:
		jogador.desbloquear_pulo_duplo()
		aviso_debug = "[DEBUG] Pulo duplo desbloqueado!"
	elif not jogador.dash_component.dash_desbloqueado:
		jogador.desbloquear_dash()
		aviso_debug = "[DEBUG] Dash desbloqueado!"
	elif not jogador.grapple_liberado:
		jogador.desbloquear_grapple()
		aviso_debug = "[DEBUG] Grapple desbloqueado!"
	else:
		aviso_debug = "[DEBUG] Todas as habilidades ja estao desbloqueadas."

	_aviso(aviso_debug, 3.0)
	print(aviso_debug)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reiniciar_partida"):
		get_tree().reload_current_scene()
		return
	if partida_terminou or not is_instance_valid(jogador):
		return
	if Input.is_action_just_pressed("alternar_mapa"):
		hud.alternar_mapa()
	if Input.is_action_just_pressed("alternar_debug"):
		hud.alternar_debug()
	# Com F3 ativo, O continua disponivel para diagnosticar a barra de STACK.
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
			if numero == 1:
				hud.definir_dica("Guardiao 1: escale, acerte o nucleo 3 vezes e ataque o corpo!")
			elif numero == 2:
				hud.definir_dica("WOODBREAKER: desvie dos impactos usando o pulo duplo!")
			else:
				hud.definir_dica("STONEMAKER: use o dash no sentido contrario a investida para causar um Dash Clash!")
		else:
			hud.definir_dica("")
	else:
		hud.definir_dica("")


func _ao_atravessar_saida(direcao: Vector2i) -> void:
	if em_transicao or partida_terminou or sala_atual == null:
		return
	if not is_instance_valid(jogador):
		return
	# Trava logica adicional: mesmo se atravessar a colisao da porta, nao
	# permite abandonar a batalha antes de derrotar o guardiao.
	if sala_atual.saidas_boss_bloqueadas:
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
	# Sala especial unica: a geometria das bordas se adapta a mascara sorteada.
	if nova != null and String(info.get("tipo", "")) == "breakpoint":
		nova.mascara_saidas = int(info.get("mascara", 0))
	if nova == null or nova.mascara_saidas != int(info.get("mascara", 0)):
		push_error("Cena incompatível com a matriz: " + caminho)
		if nova != null:
			nova.free()
		em_transicao = false
		return
	nova.configurar(destino, info, jogador, chefes_derrotados)
	if sala_atual != null:
		_salvar_estado_inimigos_da_sala()
		remove_child(sala_atual)
		sala_atual.queue_free()
	# Retoma sempre a camera da campanha ao trocar de sala.
	# Se a nova sala tiver boss, a camera da arena assume em _ready().
	camera_principal.make_current()
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
	_instalar_exception_handler()
	_sinalizar_portas_boss()
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
			_aviso("GUARDIAO 1 derrotado: pulo duplo liberado!", 5.0)
		2:
			jogador.desbloquear_dash()
			_aviso("WOODBREAKER derrotado: malloc() / dash liberado!", 5.0)
		3:
			jogador.desbloquear_grapple()
			_aviso("STONEMAKER derrotado: grapple final liberado!", 5.0)
	# A SalaMatriz adiciona o terminal de modo diferido apos a derrota.
	# Conectamos seu sinal em seguida, fora da consulta fisica.
	call_deferred("_conectar_terminais")


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


func _salvar_estado_inimigos_da_sala() -> void:
	if sala_atual == null:
		return
	var estados_sala: Dictionary = estados_inimigos.get(coordenada_atual, {})
	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		if not is_instance_valid(inimigo) or inimigo.is_queued_for_deletion():
			continue
		if not sala_atual.is_ancestor_of(inimigo):
			continue
		if not inimigo.has_method("exportar_estado_persistente"):
			continue
		var id_spawn: String = String(inimigo.get_meta("id_spawn", ""))
		if id_spawn.is_empty():
			continue
		estados_sala[id_spawn] = inimigo.call("exportar_estado_persistente")
	if not estados_sala.is_empty():
		estados_inimigos[coordenada_atual] = estados_sala


func _povoar_sala() -> void:
	## Somente marcadores manuais das cenas participam do spawn.
	## Exception Handler controla seus proprios inimigos.
	if sala_atual == null or sala_atual.dados.get("tipo", "") == "exception":
		return
	var grupo: Node = sala_atual.get_node_or_null("Conteudo/SpawnsInimigos")
	if grupo == null:
		return
	# Fork Bomb somente em setores que exigem o pulo duplo para acesso.
	# Mesmo apos derrotar Boss1, nao aparece em salas da regiao inicial.
	var zona_pos_boss1: bool = jogador.pulo_duplo_liberado and not mapa.alcancaveis(false, false, false).has(coordenada_atual)
	var mortos: Dictionary = inimigos_derrotados.get(coordenada_atual, {})
	var escolhas: Dictionary = tipos_inimigos_sorteados.get(coordenada_atual, {})
	var estados_sala: Dictionary = estados_inimigos.get(coordenada_atual, {})
	for ponto in grupo.get_children():
		var marcador: PontoSpawnInimigo = ponto as PontoSpawnInimigo
		if marcador == null or mortos.has(marcador.name):
			continue
		var tipo_escolhido: String = String(escolhas.get(marcador.name, ""))
		if tipo_escolhido.is_empty():
			tipo_escolhido = marcador.sortear_tipo(zona_pos_boss1)
			escolhas[marcador.name] = tipo_escolhido
		# Mesmo com estado de sala restaurado, o Fork Bomb exige duplo pulo.
		if tipo_escolhido == "fork_bomb" and not zona_pos_boss1:
			tipo_escolhido = "syntax_error"
		var cena: PackedScene = CENAS_INIMIGOS.get(tipo_escolhido) as PackedScene
		if cena == null:
			push_warning("Tipo de inimigo desconhecido: " + tipo_escolhido)
			continue
		var inimigo: InimigoBase = cena.instantiate() as InimigoBase
		inimigo.configurar(jogador)
		var id_spawn: String = String(marcador.name)
		inimigo.set_meta("id_spawn", id_spawn)
		inimigo.position = marcador.position
		# O ponto é filho de Conteudo/SpawnsInimigos (ambos sem deslocamento).
		# Adicioná-lo sob o mesmo Conteudo preserva a posição local do módulo.
		sala_atual.get_node("Conteudo").add_child(inimigo)
		inimigo.global_position = marcador.global_position
		if estados_sala.has(id_spawn) and inimigo.has_method("restaurar_estado_persistente"):
			inimigo.call("restaurar_estado_persistente", estados_sala[id_spawn])
		inimigo.derrotado.connect(_ao_inimigo_derrotado.bind(coordenada_atual, id_spawn))
	tipos_inimigos_sorteados[coordenada_atual] = escolhas


func _ao_inimigo_derrotado(posicao: Vector2, item_id: StringName, caiu: bool, sala: Vector2i, id_spawn: String) -> void:
	var mortos: Dictionary = inimigos_derrotados.get(sala, {})
	mortos[id_spawn] = true
	inimigos_derrotados[sala] = mortos
	var estados_sala: Dictionary = estados_inimigos.get(sala, {})
	estados_sala.erase(id_spawn)
	if not estados_sala.is_empty():
		estados_inimigos[sala] = estados_sala
	else:
		estados_inimigos.erase(sala)
	if not caiu or sala != coordenada_atual or sala_atual == null:
		return
	var recompensa: Area2D = CENA_DROP.instantiate() as Area2D
	recompensa.call("configurar", item_id)
	sala_atual.get_node("Conteudo").add_child(recompensa)
	recompensa.global_position = posicao + Vector2(0, -25)
	recompensa.connect("coletado", _ao_coletar_drop)


func _ao_coletar_drop(item_id: StringName) -> void:
	if not is_instance_valid(jogador):
		return
	var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
	_aviso(inventario.equipar(item_id), 3.0)


func _ao_aviso_equipamento(texto: String) -> void:
	_aviso(texto, 2.8)


func _ao_overflow_estourou() -> void:
	_aviso("STACK OVERFLOW! -1 HP e 0,5 s de travamento. Acerte ataques basicos para reduzir STACK.", 3.2)


func _conectar_terminais() -> void:
	if sala_atual == null:
		return
	for terminal in get_tree().get_nodes_in_group("terminais_breakpoint"):
		# Grupo ligado só no nó do módulo atual, não nos nós antigos em queue_free().
		var callback: Callable = Callable(self, "_ao_descansar")
		if not sala_atual.is_ancestor_of(terminal):
			continue
		if terminal.has_signal("descansou") and not terminal.is_connected("descansou", callback):
			terminal.connect("descansou", callback)
		var callback_tp: Callable = Callable(self, "_ao_abrir_mapa_teleporte")
		if terminal.has_signal("teleporte_solicitado") and not terminal.is_connected("teleporte_solicitado", callback_tp):
			terminal.connect("teleporte_solicitado", callback_tp)



func _breakpoints_descobertos() -> Array[Vector2i]:
	## Somente coordenadas realmente visitadas nesta run (nao revela o mapa).
	var destinos: Array[Vector2i] = []
	for coord in mapa.visitadas.keys():
		var posicao: Vector2i = coord
		var info: Dictionary = mapa.obter(posicao)
		var tipo: String = String(info.get("tipo", ""))
		if tipo == "inicio" or tipo == "breakpoint":
			destinos.append(posicao)
		elif tipo.begins_with("boss") and chefes_derrotados.has(tipo.substr(4).to_int()):
			destinos.append(posicao)
	return destinos


func abrir_teleporte_item() -> void:
	if not is_instance_valid(jogador) or jogador.utilitarios.quantidade(InventarioUtilitarios.TELEPORTE) <= 0: 
		return
		if partida_terminou or em_transicao or hud.teleporte_ativo:
			return
			if _breakpoints_descobertos().is_empty():
				_aviso("Nenhum BREAKPOINT descoberto para teleportar.", 3.0)
				return
				teleporte_item_ativo = true
				_ao_abrir_mapa_teleporte()


func _ao_abrir_mapa_teleporte() -> void:
	if partida_terminou or em_transicao or not is_instance_valid(jogador) or hud.teleporte_ativo:
		return
	var destinos: Array[Vector2i] = _breakpoints_descobertos()
	if destinos.is_empty():
		_aviso("Nenhum BREAKPOINT conhecido para viajar.", 2.5)
		return
	hud.abrir_mapa_teleporte(mapa, coordenada_atual, chefes_derrotados, destinos)
	# EquipamentosAtivos processa mesmo durante pause para permitir a HUD
	# de coleta; nao deve coletar/usar itens durante a viagem.
	var inventario: EquipamentosAtivos = jogador.get_node_or_null("EquipamentosAtivos") as EquipamentosAtivos
	if inventario != null:
		inventario.set_physics_process(false)
	get_tree().paused = true


func _finalizar_mapa_teleporte() -> void:
	hud.fechar_mapa_teleporte()
	get_tree().paused = false
	if is_instance_valid(jogador):
		var inventario: EquipamentosAtivos = jogador.get_node_or_null("EquipamentosAtivos") as EquipamentosAtivos
		if inventario != null:
			# Nao coleta um drop por acidente no mesmo F da confirmacao.
			inventario.aguardar_soltar_f = true
			inventario.set_physics_process(true)


func _ao_teleporte_cancelado() -> void:
	teleporte_item_ativo = false
	_finalizar_mapa_teleporte()


func _ao_teleporte_confirmado(destino: Vector2i) -> void:
	# Revalida destino no Main: o HUD so controla a selecao visual.
	if partida_terminou or em_transicao or not _breakpoints_descobertos().has(destino):
		teleporte_item_ativo = false
		_finalizar_mapa_teleporte()
		return
	_finalizar_mapa_teleporte()
	if destino == coordenada_atual:
		teleporte_item_ativo = false
		_aviso("Voce ja esta neste BREAKPOINT.", 2.0)
		return
	em_transicao = true
	# Usa a mesma troca segura das portas, preservando estados da sala.
	call_deferred("_realizar_teleporte", destino, teleporte_item_ativo)
	teleporte_item_ativo = false


func _realizar_teleporte(destino: Vector2i, consumir_item: bool = false) -> void:
	_entrar_sala(destino, Vector2i.ZERO)
	if em_transicao or sala_atual == null or coordenada_atual != destino:
		return
	# Aparece exatamente ao lado do terminal, sobre a plataforma/piso.
	var terminal: Area2D = sala_atual.get_node_or_null("Conteudo/TerminalBreakpoint") as Area2D
	if terminal == null:
		terminal = sala_atual.get_node_or_null("Conteudo/TerminalBreakpointAposBoss") as Area2D
	if terminal != null:
		jogador.preparar_para_nova_sala()
		jogador.global_position = terminal.global_position + Vector2(-20.0, -41.0)
		posicao_segura_atual = jogador.global_position
	protecao_entrada_restante = TEMPO_PROTECAO_ENTRADA
	if consumir_item:
		jogador.utilitarios.consumir(InventarioUtilitarios.TELEPORTE)
	_aviso("BREAKPOINT: viagem concluida. HP, equipamentos e STACK preservados.", 3.0)

func _ao_descansar() -> void:
	if partida_terminou or not is_instance_valid(jogador):
		return
	jogador.descansar()
	# Reaparecem nas salas ao retornar; chefes derrotados não reaparecem.
	inimigos_derrotados.clear()
	tipos_inimigos_sorteados.clear()
	estados_inimigos.clear()
	if sala_atual != null:
		for inimigo in get_tree().get_nodes_in_group("inimigos"):
			if sala_atual.is_ancestor_of(inimigo):
				inimigo.queue_free()
		for drop in sala_atual.get_node("Conteudo").get_children():
			if drop is Area2D and drop.is_in_group("drops_provisorios"):
				drop.queue_free()
		# Recria depois que os anteriores forem removidos.
		call_deferred("_povoar_sala")
	_aviso("BREAKPOINT: HP restaurado. Equipamentos e STACK mantidos. Inimigos reiniciados.", 4.0)

func _instalar_exception_handler() -> void:
	if sala_atual == null or sala_atual.dados.get("tipo", "") != "exception":
		return

	var desafio: ControladorExceptionHandler = CENA_EXCEPTION_HANDLER.new() as ControladorExceptionHandler
	desafio.name = "ExceptionHandler"

	# Fork Bomb somente apos derrotar o primeiro chefe.
	desafio.configurar(jogador, chefes_derrotados.has(1))

	sala_atual.add_child(desafio)

	# Um desafio concluido nao pode ser repetido nesta run.
	if desafios_exception_concluidos.has(coordenada_atual):
		desafio.restaurar_concluido()
	else:
		desafio.desafio_concluido.connect(
			_ao_exception_concluido.bind(coordenada_atual)
		)

func _ao_exception_concluido(id_patch: StringName, sala: Vector2i) -> void:
	desafios_exception_concluidos[sala] = true

	if id_patch == &"":
		_aviso("EXCEPTION HANDLED! Build maximizada.", 4.0)
	else:
		_aviso("EXCEPTION HANDLED! Patch adquirido.", 4.0)

func _sinalizar_portas_boss() -> void:
	if sala_atual == null:
		return

	var conexoes: Dictionary = sala_atual.dados.get("conexoes", {})

	for direcao in conexoes:
		var direcao_saida: Vector2i = direcao
		var destino: Vector2i = conexoes[direcao_saida]
		var info: Dictionary = mapa.obter(destino)
		var tipo: String = String(info.get("tipo", ""))

		if not tipo.begins_with("boss"):
			continue

		var numero: int = tipo.substr(4).to_int()

		# Nao sinalizar chefes ja derrotados.
		if chefes_derrotados.has(numero):
			continue

		var posicao: Vector2 = Vector2.ZERO

		match direcao_saida:
			Vector2i.LEFT:
				posicao = Vector2(5, 437)
			Vector2i.RIGHT:
				posicao = Vector2(SalaMatriz.LARGURA - 75, 437)
			Vector2i.UP:
				posicao = Vector2(SalaMatriz.LARGURA / 2.0 - 35, 75)
			Vector2i.DOWN:
				posicao = Vector2(SalaMatriz.LARGURA / 2.0 - 35, SalaMatriz.ALTURA - 135)
			_:
				continue

		var aviso: Label = Label.new()
		aviso.name = "AvisoPortaBoss"
		aviso.text = "☠"
		aviso.position = posicao
		aviso.size = Vector2(70, 65)
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aviso.z_index = 10

		aviso.add_theme_font_size_override("font_size", 48)
		aviso.add_theme_color_override(
			"font_color",
			Color(1.0, 0.15, 0.22)
		)
		aviso.add_theme_color_override(
			"font_outline_color",
			Color(0.08, 0.02, 0.06)
		)
		aviso.add_theme_constant_override("outline_size", 5)

		sala_atual.get_node("Conteudo").add_child(aviso)
