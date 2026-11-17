extends Node2D

## fork(): um processo falso atrai perseguidores comuns, sem causar dano.
@export var custo_overflow: float = 25.0
@export var recarga_segundos: float = 14.0
@export var acompanha_jogador: bool = false
@export var duracao: float = 5.0
@export var alcance_aggro: float = 350.0


func ativar(alvo: Jogador, controle: EquipamentosAtivos) -> bool:
	global_position = alvo.global_position + Vector2(20, 20)
	add_to_group("iscas_fork")
	var envolvidos: int = 0
	for nodo in get_tree().get_nodes_in_group("inimigos"):
		var inimigo: InimigoBase = nodo as InimigoBase
		if inimigo != null and not inimigo.encerrado and not inimigo.fixo_no_cenario and global_position.distance_to(inimigo.global_position) <= alcance_aggro:
			inimigo.definir_isca(self)
			envolvidos += 1
	controle.aviso.emit("fork(): isca criada; %d perseguidores atraidos." % envolvidos)
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	duracao -= delta
	if duracao <= 0.0:
		queue_free()


func receber_impacto() -> void:
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-17, -17, 34, 34), Color(0.71, 0.33, 1.0, 0.42))
	draw_rect(Rect2(-17, -17, 34, 34), Color(0.93, 0.76, 1.0), false, 2.0)
	draw_line(Vector2(-8,-3), Vector2(8,-3), Color(1,1,1), 2.0)
