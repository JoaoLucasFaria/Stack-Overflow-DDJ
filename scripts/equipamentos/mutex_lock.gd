extends Node2D

## Exclusao mutua: prende IA comum por 1,2s; chefes apenas desaceleram.
@export var custo_overflow: float = 30.0
@export var recarga_segundos: float = 16.0
@export var acompanha_jogador: bool = false
@export var raio: float = 265.0
@export var duracao_inimigos: float = 1.2
@export var duracao_lentidao_boss: float = 1.2
var tempo_visual: float = 0.24


func ativar(alvo: Jogador, controle: EquipamentosAtivos) -> bool:
	global_position = alvo.global_position + Vector2(20, 20)
	var afetados: int = 0
	for nodo in get_tree().get_nodes_in_group("inimigos"):
		var inimigo: InimigoBase = nodo as InimigoBase
		if inimigo != null and global_position.distance_to(inimigo.global_position) <= raio:
			if inimigo.interromper_ataques(duracao_inimigos):
				afetados += 1
	for nodo in get_tree().get_nodes_in_group("chefes"):
		var chefe: BossBase = nodo as BossBase
		if chefe != null and global_position.distance_to(chefe.global_position) <= raio:
			chefe.aplicar_lentidao_mutex(duracao_lentidao_boss)
			afetados += 1
	controle.aviso.emit("mutex.lock(): %d alvos controlados." % afetados)
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	tempo_visual -= delta
	if tempo_visual <= 0.0:
		queue_free()


func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0, TAU, 80, Color(0.30, 0.90, 1.0, 0.48), 5.0)
