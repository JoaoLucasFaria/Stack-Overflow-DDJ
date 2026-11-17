class_name EquipamentosAtivos
extends Node

## Dois slots Q/E. Cada item gerencia o seu proprio efeito.
## F abre e confirma a coleta; TAB alterna o slot; ESC cancela.
signal equipamentos_alterados
signal aviso(texto: String)

const CENAS: Dictionary = {
    &"memory_leak": preload("res://cenas/equipamentos/escudo_memory_leak.tscn"),
    &"segmentation_fault": preload("res://cenas/equipamentos/projetil_segmentation_fault.tscn"),
    &"null_pointer": preload("res://cenas/equipamentos/armadilha_null_pointer.tscn"),
    &"syntax_error": preload("res://cenas/equipamentos/ataque_syntax_error.tscn"),
    &"fork_bomb": preload("res://cenas/equipamentos/isca_fork.tscn"),
    &"race_condition": preload("res://cenas/equipamentos/mutex_lock.tscn"),
    &"deadlock": preload("res://cenas/equipamentos/interrupt.tscn")
}
const NOMES: Dictionary = {
    &"memory_leak": "Escudo Memory Leak",
    &"segmentation_fault": "Projetil Segmentation Fault",
    &"null_pointer": "Armadilha Null Pointer",
    &"syntax_error": "Golpe Syntax Error",
    &"fork_bomb": "fork() - Processo Isca",
    &"race_condition": "mutex.lock() - Exclusao Mutua",
    &"deadlock": "interrupt() - Interrupcao"
}
const EFEITOS: Dictionary = {
    &"memory_leak": "Absorve uma instancia de dano e repele inimigos moveis proximos.",
    &"segmentation_fault": "Dispara um projetil horizontal na direcao do jogador.",
    &"null_pointer": "Armadilha que causa dano e teleporta o inimigo para tras.",
    &"syntax_error": "Fortalece o alcance e o dano do proximo ataque basico.",
    &"fork_bomb": "Cria uma isca de 5s que distrai inimigos comuns proximos.",
    &"race_condition": "Congela inimigos comuns 1,2s; desacelera chefes brevemente.",
    &"deadlock": "Cancela ataques por 1s, inclusive chefes; nao causa dano. Recarga 40s."
}
## Espaco reservado para descricoes narrativas, a definir pela equipe.
const DESCRICOES: Dictionary = {
    &"memory_leak": "Descricao narrativa: a definir.",
    &"segmentation_fault": "Descricao narrativa: a definir.",
    &"null_pointer": "Descricao narrativa: a definir.",
    &"syntax_error": "Descricao narrativa: a definir.",
    &"fork_bomb": "Descricao narrativa: a definir.",
    &"race_condition": "Descricao narrativa: a definir.",
    &"deadlock": "Descricao narrativa: a definir."
}
const CENA_HUD: PackedScene = preload("res://cenas/equipamentos/hud_equipamentos.tscn")
const CENA_COLETA: PackedScene = preload("res://cenas/equipamentos/hud_coleta_item.tscn")

var slots: Array[StringName] = [&"", &""]
var slot_para_substituir: int = 0
## Recargas por tipo; re-equipar nao remove a recarga antiga.
var recargas: Dictionary = {}
var escudo_ativo: Node2D
var golpe_preparado: Node2D
var efeitos_de_sala: Array[Node2D] = []
var jogador: Jogador
var hud: CanvasLayer
var hud_coleta: CanvasLayer
var coleta_aberta: bool = false
## Evita abrir outra coleta no mesmo pressionamento de F usado para confirmar.
var aguardar_soltar_f: bool = false
var drop_pendente: Area2D
var item_pendente: StringName = &""


func _ready() -> void:
    jogador = get_parent() as Jogador
    hud = CENA_HUD.instantiate() as CanvasLayer
    add_child(hud)
    hud.set("inventario", self)
    hud_coleta = CENA_COLETA.instantiate() as CanvasLayer
    add_child(hud_coleta)
    hud_coleta.hide()
    # A confirmacao/cancelamento precisa funcionar mesmo com o mundo pausado.
    process_mode = Node.PROCESS_MODE_ALWAYS
    hud_coleta.process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
    if aguardar_soltar_f and not Input.is_action_pressed("coletar_item"):
        aguardar_soltar_f = false
    if coleta_aberta or not is_instance_valid(jogador) or jogador.vida_atual <= 0:
        return
    for tipo in recargas.keys():
        recargas[tipo] = maxf(0.0, float(recargas[tipo]) - delta)
    if jogador.esta_travado_por_overflow():
        return
    if Input.is_action_just_pressed("usar_item_1"):
        usar_slot(0)
    if Input.is_action_just_pressed("usar_item_2"):
        usar_slot(1)
    if Input.is_action_just_pressed("coletar_item") and not aguardar_soltar_f:
        tentar_coletar_mais_proximo()


func _input(evento: InputEvent) -> void:
    if not coleta_aberta or not evento.is_pressed():
        return
    if evento is InputEventKey and evento.is_echo():
        return
    if evento.is_action_pressed("selecionar_slot_item"):
        slot_para_substituir = 1 - slot_para_substituir
        _atualizar_painel_coleta()
        get_viewport().set_input_as_handled()
    elif evento.is_action_pressed("coletar_item"):
        aguardar_soltar_f = true
        confirmar_coleta()
        get_viewport().set_input_as_handled()
    elif evento.is_action_pressed("ui_cancel"):
        cancelar_coleta()
        get_viewport().set_input_as_handled()


func equipar(item_id: StringName) -> String:
    if not CENAS.has(item_id):
        return "Item desconhecido: " + str(item_id)
    if slots.has(item_id):
        # Itens iguais nao ocupam dois slots. Atualizam apenas a recarga.
        recargas[item_id] = 0.0
        equipamentos_alterados.emit()
        return "%s: recarga restaurada." % NOMES[item_id]
    var posicao: int = slot_para_substituir
    var anterior: StringName = slots[posicao]
    if anterior == &"memory_leak" and is_instance_valid(escudo_ativo):
        escudo_ativo.queue_free()
        escudo_ativo = null
    elif anterior == &"syntax_error" and is_instance_valid(golpe_preparado):
        golpe_preparado.queue_free()
        golpe_preparado = null
    slots[posicao] = item_id
    equipamentos_alterados.emit()
    if anterior == &"":
        return "%s equipado em %s." % [NOMES[item_id], "Q" if posicao == 0 else "E"]
    return "%s substituiu %s em %s." % [NOMES[item_id], NOMES[anterior], "Q" if posicao == 0 else "E"]


func usar_slot(indice: int) -> void:
    if indice < 0 or indice >= slots.size() or coleta_aberta:
        return
    if not is_instance_valid(jogador) or jogador.esta_travado_por_overflow():
        return
    # No limite nao e possivel usar Q/E; apenas acertos basicos reduzem STACK.
    if jogador.overflow_atual >= jogador.overflow_maximo:
        aviso.emit("OVERFLOW MAXIMO! Acerte ataques basicos para liberar os itens.")
        return
    var item_id: StringName = slots[indice]
    if item_id == &"":
        aviso.emit("Slot %s vazio. Colete um drop com F." % ("Q" if indice == 0 else "E"))
        return
    if jogador.dash_component.esta_dashing:
        return
    if float(recargas.get(item_id, 0.0)) > 0.0:
        return
    var cena: PackedScene = CENAS.get(item_id) as PackedScene
    var efeito: Node2D = cena.instantiate() as Node2D
    if efeito == null:
        return
    var custo: float = float(efeito.get("custo_overflow"))
    # O item que preenche a barra pode ser ativado; depois disso, Q/E ficam
    # bloqueados ate o jogador reduzir STACK com ataques basicos.
    var segue_jogador: bool = bool(efeito.get("acompanha_jogador"))
    if segue_jogador:
        jogador.add_child(efeito)
    else:
        jogador.get_parent().add_child(efeito)
    if not bool(efeito.call("ativar", jogador, self)):
        efeito.queue_free()
        return
    recargas[item_id] = float(efeito.get("recarga_segundos"))
    if not segue_jogador:
        efeitos_de_sala.append(efeito)
    jogador.adicionar_overflow(custo)
    equipamentos_alterados.emit()


func absorver_dano(origem_dano: Vector2 = Vector2.ZERO) -> bool:
    if not is_instance_valid(escudo_ativo):
        return false
    return bool(escudo_ativo.call("absorver_dano", origem_dano))


func consumir_modificador_ataque() -> Dictionary:
    if not is_instance_valid(golpe_preparado):
        return {}
    return golpe_preparado.call("consumir")


func limpar_efeitos_de_sala() -> void:
    for efeito in efeitos_de_sala:
        if is_instance_valid(efeito):
            efeito.queue_free()
    efeitos_de_sala.clear()


func tentar_coletar_mais_proximo() -> void:
    if coleta_aberta:
        return
    var centro: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
    var escolhido: Area2D
    var distancia: float = 62.0
    for nodo in get_tree().get_nodes_in_group("drops_provisorios"):
        var drop: Area2D = nodo as Area2D
        if drop == null or drop.is_queued_for_deletion() or not drop.has_method("coletar"):
            continue
        var nova_distancia: float = centro.distance_to(drop.global_position)
        if nova_distancia < distancia:
            escolhido = drop
            distancia = nova_distancia
    if escolhido != null:
        iniciar_coleta(escolhido)


func iniciar_coleta(drop: Area2D) -> void:
    if coleta_aberta or not is_instance_valid(drop):
        return
    var tipo: StringName = StringName(drop.get("item_id"))
    if not CENAS.has(tipo):
        return
    drop_pendente = drop
    item_pendente = tipo
    var primeiro_vazio: int = slots.find(&"")
    slot_para_substituir = primeiro_vazio if primeiro_vazio >= 0 else 0
    coleta_aberta = true
    _atualizar_painel_coleta()
    hud_coleta.show()
    get_tree().paused = true


func _atualizar_painel_coleta() -> void:
    if is_instance_valid(hud_coleta):
        hud_coleta.call("mostrar_item", NOMES.get(item_pendente, ""), EFEITOS.get(item_pendente, ""), DESCRICOES.get(item_pendente, ""), nome_slot(0), nome_slot(1), slot_para_substituir)


func confirmar_coleta() -> void:
    if not coleta_aberta:
        return
    var drop: Area2D = drop_pendente
    _fechar_coleta()
    # Somente agora o drop e consumido. O sinal 'coletado' equipa no slot
    # selecionado, na campanha e nas arenas de teste.
    if is_instance_valid(drop) and not drop.is_queued_for_deletion():
        drop.call("coletar", jogador)


func cancelar_coleta() -> void:
    if coleta_aberta:
        _fechar_coleta()


func _fechar_coleta() -> void:
    coleta_aberta = false
    drop_pendente = null
    item_pendente = &""
    hud_coleta.hide()
    get_tree().paused = false


func _exit_tree() -> void:
    if coleta_aberta:
        get_tree().paused = false


func nome_slot(indice: int) -> String:
    var tipo: StringName = slots[indice]
    return "Vazio" if tipo == &"" else String(NOMES.get(tipo, str(tipo)))


func recarga_slot(indice: int) -> float:
    return float(recargas.get(slots[indice], 0.0))
