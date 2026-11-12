extends Area2D

## Recompensa VISUAL por enquanto. O equipamento de 2 slots ficará com a Frente A.
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
	$Nome.text = "DROP: " + str(NOMES.get(item_id, str(item_id)))
	body_entered.connect(_ao_coletar)


func _ao_coletar(corpo: Node2D) -> void:
	if corpo.is_in_group("jogador"):
		coletado.emit(item_id)
		queue_free()
