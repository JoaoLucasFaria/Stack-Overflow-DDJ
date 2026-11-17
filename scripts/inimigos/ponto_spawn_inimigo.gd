class_name PontoSpawnInimigo
extends Marker2D

## Posicione o marcador sobre um piso seguro na cena manual.
## Mantem os valores gravados nas salas antigas, sem mostrar o seletor legado.
@export_storage var tipo_inimigo: String = "syntax_error"

## Marque um ou mais tipos; zero mantem o inimigo antigo da cena.
@export_flags("Syntax Error", "Null Pointer", "Memory Leak", "Segmentation Fault") var tipos_possiveis: int = 0

## Os novos tipos entram na rotacao sem reescrever os marcadores manuais antigos.
@export var permitir_novos_inimigos: bool = true
@export_range(0, 100, 1) var chance_novo_inimigo_percentual: int = 32

const NOMES_TIPOS = [
    "syntax_error",
    "null_pointer",
    "memory_leak",
    "segmentation_fault"
]


func sortear_tipo(pos_boss1: bool = false) -> String:
	var candidatos: Array[String] = []
	for indice in range(NOMES_TIPOS.size()):
		if (tipos_possiveis & (1 << indice)) != 0:
			candidatos.append(NOMES_TIPOS[indice])

	if permitir_novos_inimigos and randi_range(1, 100) <= chance_novo_inimigo_percentual:
		var novos: Array[String] = ["race_condition", "deadlock", "out_of_bounds"]
		if pos_boss1:
			novos.append("fork_bomb")
		return novos.pick_random()
	if candidatos.is_empty():
		return tipo_inimigo
	return candidatos.pick_random()
