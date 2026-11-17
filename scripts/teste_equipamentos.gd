extends Node2D

## F6: teste rapido dos dois slots e dos quatro efeitos independentes.
const CENA_JOGADOR: PackedScene = preload("res://cenas/player.tscn")
const CENA_DROP: PackedScene = preload("res://cenas/inimigos/drop_provisorio.tscn")
const CENA_TERMINAL: PackedScene = preload("res://cenas/descanso/terminal_breakpoint.tscn")
const ITENS: Array[StringName] = [&"memory_leak", &"segmentation_fault", &"null_pointer", &"syntax_error"]
const CENAS_INIMIGOS: Array[PackedScene] = [
    preload("res://cenas/inimigos/inimigo_syntax_error.tscn"),
    preload("res://cenas/inimigos/inimigo_null_pointer.tscn"),
    preload("res://cenas/inimigos/inimigo_memory_leak.tscn")
]
var jogador: Jogador
var instrucoes: Label


func _ready() -> void:
    jogador = CENA_JOGADOR.instantiate() as Jogador
    add_child(jogador)
    jogador.position = Vector2(58.0, 540.0)
    jogador.desbloquear_pulo_duplo()
    jogador.desbloquear_dash()
    var inventario: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
    inventario.aviso.connect(func(texto: String) -> void: print("[ITEM] ", texto))
    for i in range(ITENS.size()):
        var drop: Area2D = CENA_DROP.instantiate() as Area2D
        drop.call("configurar", ITENS[i])
        add_child(drop)
        drop.global_position = Vector2(150.0 + i * 64.0, 555.0)
        drop.coletado.connect(_ao_coletar)
    var terminal: Area2D = CENA_TERMINAL.instantiate() as Area2D
    add_child(terminal)
    terminal.position = Vector2(85.0, 600.0)
    terminal.descansou.connect(_ao_descansar)
    instrucoes = Label.new()
    instrucoes.position = Vector2(18, 20)
    instrucoes.add_theme_font_size_override("font_size", 16)
    add_child(instrucoes)
    _criar_inimigos()


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("reiniciar_partida"):
        get_tree().reload_current_scene()
        return
    if not is_instance_valid(jogador):
        instrucoes.text = "PROCESSO ENCERRADO - R para recomeçar"
        return
    instrucoes.text = "TESTE ITENS | F: abrir/confirmar coleta | TAB: escolher | ENTER/ESPACO: confirmar | ESC: cancelar\nQ/E: usar itens | J: basico reduz STACK ao acertar | G: BREAKPOINT | R: reiniciar"


func _ao_coletar(item_id: StringName) -> void:
    if not is_instance_valid(jogador):
        return
    var controle: EquipamentosAtivos = jogador.get_node("EquipamentosAtivos") as EquipamentosAtivos
    print("[ITEM] ", controle.equipar(item_id))


func _criar_inimigos() -> void:
    for i in range(CENAS_INIMIGOS.size()):
        var inimigo: InimigoBase = CENAS_INIMIGOS[i].instantiate() as InimigoBase
        inimigo.configurar(jogador)
        add_child(inimigo)
        inimigo.global_position = Vector2(525.0 + i * 230.0, 568.0)
        inimigo.derrotado.connect(_ao_inimigo_derrotado)


func _ao_inimigo_derrotado(_posicao: Vector2, _id: StringName, _caiu: bool) -> void:
    pass


func _ao_descansar() -> void:
    if not is_instance_valid(jogador):
        return
    jogador.descansar()
    for inimigo in get_tree().get_nodes_in_group("inimigos"):
        inimigo.queue_free()
    call_deferred("_criar_inimigos")
