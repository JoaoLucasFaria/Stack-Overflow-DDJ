class_name GerenciadorPatches
extends Node

## Patches passivos da run. Nao ocupam Q/E, persistem ao trocar de sala
## e ao descansar. Como o Node pertence ao jogador, sao perdidos na morte.
signal patches_alterados
signal evento_patch(texto: String)

const MAX_SLOTS: int = 4
const MAX_NIVEL: int = 5
const HUD_SCRIPT = preload("res://scripts/patches/hud_patches.gd")
const MENU_SCRIPT = preload("res://scripts/patches/menu_build.gd")
const ORDEM: Array[StringName] = [
	&"overclock", &"recursive_call", &"critical_exception",
	&"heap_alloc", &"try_catch", &"watchdog",
	&"garbage_collect", &"stack_compression", &"cache_hit",
	&"branch_prediction", &"memory_cache", &"parallel_execution"
]
const NOMES: Dictionary = {
	&"overclock": "overclock()", &"recursive_call": "recursive_call()",
	&"critical_exception": "critical_exception()", &"heap_alloc": "heap_alloc()",
	&"try_catch": "try_catch()", &"watchdog": "watchdog()",
	&"garbage_collect": "garbage_collect()", &"stack_compression": "stack_compression()",
	&"cache_hit": "cache_hit()", &"branch_prediction": "branch_prediction()",
	&"memory_cache": "memory_cache()", &"parallel_execution": "parallel_execution()"
}
const DESCRICOES: Dictionary = {
	&"overclock": "Ataques basicos mais rapidos; equipamentos geram mais STACK.",
	&"recursive_call": "A cada alguns acertos basicos, repete parte do dano.",
	&"critical_exception": "Chance de dano adicional em ataques basicos.",
	&"heap_alloc": "+1 HP maximo por nivel (e cura 1 HP ao evoluir).",
	&"try_catch": "Periodicamente, evita um dano; recarga diminui por nivel.",
	&"watchdog": "Recupera 1 HP apos derrotar inimigos suficientes.",
	&"garbage_collect": "Abates de inimigos comuns reduzem STACK.",
	&"stack_compression": "Equipamentos geram menos STACK.",
	&"cache_hit": "Acertos basicos reduzem recargas de Q/E.",
	&"branch_prediction": "Aumenta a velocidade de movimento horizontal.",
	&"memory_cache": "Ao sofrer dano, acelera movimento e ataques por alguns segundos.",
	&"parallel_execution": "Usar Q/E fortalece o proximo ataque basico que causar dano."
}

var jogador
var niveis: Dictionary = {} # StringName -> int, em ordem de aquisicao
var tempo_try_catch: float = 0.0
var abates_watchdog: int = 0
var acertos_recursao: int = 0
var tempo_memory_cache: float = 0.0
var paralelo_preparado: bool = false
var hud: CanvasLayer
var menu: CanvasLayer


func configurar(alvo) -> void:
	jogador = alvo


func _ready() -> void:
	if not is_instance_valid(jogador):
		jogador = get_parent()
	hud = HUD_SCRIPT.new() as CanvasLayer
	hud.set("gerenciador", self)
	add_child(hud)
	menu = MENU_SCRIPT.new() as CanvasLayer
	menu.set("gerenciador", self)
	add_child(menu)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	tempo_try_catch = maxf(0.0, tempo_try_catch - delta)
	tempo_memory_cache = maxf(0.0, tempo_memory_cache - delta)


func nivel(id: StringName) -> int:
	return int(niveis.get(id, 0))


func nome_patch(id: StringName) -> String:
	return String(NOMES.get(id, String(id)))


func descricao_nivel(id: StringName, lvl: int = -1) -> String:
	## Valores derivados das formulas reais deste gerenciador. Esta funcao
	## tambem pode ser utilizada na futura tela de recompensa dos altares.
	if lvl < 0:
		lvl = nivel(id)
	if lvl <= 0:
		return "Patch nao instalado."
	lvl = mini(lvl, MAX_NIVEL)
	match id:
		&"overclock":
			return "Ataques basicos: +%d%% de velocidade.\nQ/E: +%d%% de STACK gerada (antes de outros bonus)." % [8 * lvl, 6 * lvl]
		&"recursive_call":
			var acertos: Array[int] = [4, 4, 3, 3, 2]
			var potencia: Array[int] = [30, 45, 50, 65, 75]
			return "A cada %d acertos basicos que causam dano, repete %d%% do dano base no mesmo alvo. O eco nao ativa outros Patches." % [acertos[lvl - 1], potencia[lvl - 1]]
		&"critical_exception":
			return "%d%% de chance de causar dano extra igual a %d%% do dano base do ataque (arredondado para cima)." % [5 * lvl, 50 + 10 * lvl]
		&"heap_alloc":
			return "+%d HP maximo nesta run. Cada nivel instalado tambem recupera 1 HP." % lvl
		&"try_catch":
			return "Ignora um golpe de dano recebido, recarregando a protecao a cada %d segundos." % (34 - 4 * lvl)
		&"watchdog":
			return "Recupera 1 HP apos %d abates de inimigos comuns validos (se a vida nao estiver cheia)." % maxi(2, 7 - lvl)
		&"garbage_collect":
			return "Cada abate de inimigo comum valido remove %d STACK. Processos invocados nao contam." % (3 * lvl)
		&"stack_compression":
			return "Q/E geram %d%% menos STACK antes de outros modificadores; custo nunca cai abaixo de 30%%." % (8 * lvl)
		&"cache_hit":
			return "Cada ataque basico que causa dano reduz %.1f s da recarga de cada equipamento Q/E equipado." % (0.2 * lvl)
		&"branch_prediction":
			return "+%d%% de velocidade horizontal de movimento." % (6 * lvl)
		&"memory_cache":
			return "Apos receber dano, ganha +%d%% de velocidade de movimento e ataques por %.1f segundos." % [8 + 2 * lvl, 1.8 + 0.4 * lvl]
		&"parallel_execution":
			return "Apos usar Q/E, o proximo ataque basico que causar dano recebe +%d de dano." % (1 + floori(float(lvl - 1) / 2.0))
	return String(DESCRICOES.get(id, "Descricao nao cadastrada."))


func slots_ocupados() -> int:
	return niveis.size()


func instalar_patch(id: StringName) -> bool:
	if not NOMES.has(id):
		return false
	var anterior: int = nivel(id)
	if anterior >= MAX_NIVEL or (anterior == 0 and slots_ocupados() >= MAX_SLOTS):
		return false
	niveis[id] = anterior + 1
	if id == &"heap_alloc" and is_instance_valid(jogador):
		jogador.vida_maxima += 1
		jogador.vida_atual = mini(jogador.vida_atual + 1, jogador.vida_maxima)
		jogador.vida_alterada.emit(jogador.vida_atual, jogador.vida_maxima)
	if id == &"watchdog":
		abates_watchdog = mini(abates_watchdog, maxi(1, 7 - nivel(id)) - 1)
	patches_alterados.emit()
	evento_patch.emit("PATCH %s: nivel %d/%d" % [String(NOMES[id]), nivel(id), MAX_NIVEL])
	return true


func opcoes_recompensa(quantidade: int = 3) -> Array[StringName]:
	## Quando lotado, oferece APENAS patches ja equipados que ainda evoluem.
	var candidatos: Array[StringName] = []
	for id in ORDEM:
		if nivel(id) >= MAX_NIVEL:
			continue
		if slots_ocupados() < MAX_SLOTS or niveis.has(id):
			candidatos.append(id)
	candidatos.shuffle()
	return candidatos.slice(0, mini(quantidade, candidatos.size()))


func multiplicador_velocidade() -> float:
	var bonus: float = 1.0 + 0.06 * nivel(&"branch_prediction")
	if tempo_memory_cache > 0.0:
		bonus += 0.08 + 0.02 * nivel(&"memory_cache")
	return bonus


func multiplicador_ataque() -> float:
	var bonus: float = 1.0 + 0.08 * nivel(&"overclock")
	if tempo_memory_cache > 0.0:
		bonus += 0.08 + 0.02 * nivel(&"memory_cache")
	return bonus


func multiplicador_stack_equipamento() -> float:
	## Os dois Patches podem coexistir, mas nunca tornam Q/E gratuitos.
	return maxf(0.30, (1.0 + 0.06 * nivel(&"overclock")) * (1.0 - 0.08 * nivel(&"stack_compression")))


func bonus_dano_proximo_ataque() -> int:
	if not paralelo_preparado:
		return 0
	return 1 + floori(float(nivel(&"parallel_execution") - 1) / 2.0) if nivel(&"parallel_execution") > 0 else 0


func dano_critico_extra(dano_base: int) -> int:
	var lvl: int = nivel(&"critical_exception")
	if lvl <= 0 or randf() >= 0.05 * lvl:
		return 0
	evento_patch.emit("critical_exception(): dano adicional!")
	return maxi(1, ceili(float(dano_base) * (0.5 + 0.1 * float(lvl))))


func registrar_uso_equipamento() -> void:
	if nivel(&"parallel_execution") > 0:
		paralelo_preparado = true
		patches_alterados.emit()


func registrar_acerto_basico(alvo: Object, dano_base: int) -> void:
	## Invocado uma unica vez por swing que realmente danificou algo.
	if paralelo_preparado:
		paralelo_preparado = false
		patches_alterados.emit()
	var lvl_cache: int = nivel(&"cache_hit")
	if lvl_cache > 0 and is_instance_valid(jogador):
		var itens = jogador.get_node_or_null("EquipamentosAtivos")
		if itens != null:
			for id in itens.slots:
				if id == &"":
					continue
				itens.recargas[id] = maxf(0.0, float(itens.recargas.get(id, 0.0)) - 0.2 * lvl_cache)
			itens.equipamentos_alterados.emit()
	var lvl_recursao: int = nivel(&"recursive_call")
	if lvl_recursao == 0:
		return
	acertos_recursao += 1
	var frequencias: Array[int] = [4, 4, 3, 3, 2]
	if acertos_recursao < frequencias[lvl_recursao - 1]:
		return
	acertos_recursao = 0
	if not is_instance_valid(alvo) or not alvo.has_method("receber_dano"):
		return
	if alvo is Node and (alvo as Node).is_queued_for_deletion():
		return
	var vida: Variant = alvo.get("vida_atual")
	if vida == null or int(vida) <= 0:
		return
	var proporcoes: Array[float] = [0.30, 0.45, 0.50, 0.65, 0.75]
	var extra: int = maxi(1, ceili(float(dano_base) * proporcoes[lvl_recursao - 1]))
	alvo.call("receber_dano", extra)
	evento_patch.emit("recursive_call(): eco de %d dano!" % extra)
	## O eco nao ativa novos patches e nao conta como segundo acerto/STACK.


func tentar_absorver_dano() -> bool:
	var lvl: int = nivel(&"try_catch")
	if lvl <= 0 or tempo_try_catch > 0.0:
		return false
	var recarga: float = maxf(14.0, 34.0 - 4.0 * lvl)
	tempo_try_catch = recarga
	evento_patch.emit("try_catch(): dano ignorado! Recarga %.0fs" % recarga)
	patches_alterados.emit()
	return true


func registrar_dano_recebido() -> void:
	var lvl: int = nivel(&"memory_cache")
	if lvl > 0:
		tempo_memory_cache = 1.8 + 0.4 * lvl
		evento_patch.emit("memory_cache(): aceleracao temporaria!")


func registrar_abate_comum() -> void:
	## Nunca contar processos invocados: evita farming infinito na Fork Bomb.
	if not is_instance_valid(jogador) or jogador.vida_atual <= 0:
		return
	var lixo: int = nivel(&"garbage_collect")
	if lixo > 0:
		jogador.reduzir_overflow(3.0 * lixo)
	var watchdog: int = nivel(&"watchdog")
	if watchdog <= 0:
		return
	abates_watchdog += 1
	var necessario: int = maxi(2, 7 - watchdog)
	if abates_watchdog >= necessario:
		abates_watchdog = 0
		if jogador.vida_atual < jogador.vida_maxima:
			jogador.vida_atual += 1
			jogador.vida_alterada.emit(jogador.vida_atual, jogador.vida_maxima)
			evento_patch.emit("watchdog(): +1 HP")
