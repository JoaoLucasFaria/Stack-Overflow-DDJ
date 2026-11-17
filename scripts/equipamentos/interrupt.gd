extends Node2D

## Interrompe ataques em preparacao/execucao por 1s, inclusive chefes.
## NAO provoca dano e NAO cancela transicoes de fase.
@export var custo_overflow: float = 25.0
@export var recarga_segundos: float = 40.0
@export var acompanha_jogador: bool = false
@export var raio: float = 460.0
@export var duracao_interrupcao: float = 1.0
var tempo_visual: float = 0.24


func ativar(alvo: Jogador, controle: EquipamentosAtivos) -> bool:
	global_position = alvo.global_position + Vector2(20, 20)
	var afetados: int = 0
	var chefe_em_transicao: bool = false
	for nodo in get_tree().get_nodes_in_group("chefes"):
		var chefe: BossBase = nodo as BossBase
		if chefe != null and not chefe.encerrado and global_position.distance_to(chefe.global_position) <= raio:
			if chefe.interromper_ataques(duracao_interrupcao):
				afetados += 1
			else:
				chefe_em_transicao = true
	for nodo in get_tree().get_nodes_in_group("inimigos"):
		var inimigo: InimigoBase = nodo as InimigoBase
		if inimigo != null and global_position.distance_to(inimigo.global_position) <= raio:
			if inimigo.interromper_ataques(duracao_interrupcao):
				afetados += 1
	if afetados == 0:
		controle.aviso.emit("interrupt(): boss protegido por fase ou nenhum ataque ao alcance." if chefe_em_transicao else "interrupt(): nenhum alvo ao alcance.")
		return false
	controle.aviso.emit("interrupt(): %d alvos interrompidos por 1 segundo." % afetados)
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	tempo_visual -= delta
	if tempo_visual <= 0.0:
		queue_free()


func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 80, Color(1.0, 0.52, 0.15, 0.55), 6.0)
	draw_line(Vector2(-30,-30), Vector2(30,30), Color(1,1,1,0.85), 5.0)
	draw_line(Vector2(30,-30), Vector2(-30,30), Color(1,1,1,0.85), 5.0)
