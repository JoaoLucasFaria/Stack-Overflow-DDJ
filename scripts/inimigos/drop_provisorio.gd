extends Area2D

## Cada drop representa um dos quatro equipamentos reais.
## Coleta manual por F, administrada pelo EquipamentosAtivos (um item por tecla).
signal coletado(item_id: StringName)

var item_id: StringName = &"syntax_error"
const NOMES: Dictionary = {
    &"syntax_error": "Syntax Error",
    &"null_pointer": "Null Pointer",
    &"memory_leak": "Memory Leak",
    &"segmentation_fault": "Segmentation Fault"
}
const CORES: Dictionary = {
    &"syntax_error": Color("f27a63"),
    &"null_pointer": Color("b887ee"),
    &"memory_leak": Color("70d599"),
    &"segmentation_fault": Color("f0c768")
}


func configurar(id: StringName) -> void:
    item_id = id


func _ready() -> void:
    add_to_group("drops_provisorios")
    collision_layer = 0
    collision_mask = 1
    $Visual.color = CORES.get(item_id, Color.WHITE)
    $Nome.text = "[F] " + str(NOMES.get(item_id, str(item_id)))


func coletar(jogador: Jogador) -> void:
    if is_queued_for_deletion() or not is_instance_valid(jogador):
        return
    if (jogador.global_position + Vector2(20.0, 20.0)).distance_to(global_position) > 62.0:
        return
    coletado.emit(item_id)
    queue_free()
