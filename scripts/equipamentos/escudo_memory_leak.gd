extends Node2D

## Escudo de uma unica instancia de dano. Nao tem duracao maxima.
@export var custo_overflow: float = 25.0
@export var recarga_segundos: float = 8.0
@export var acompanha_jogador: bool = true
@export_category("Recuo ao bloquear")
@export_range(40.0, 200.0, 5.0) var alcance_empurrao: float = 130.0
@export_range(100.0, 950.0, 10.0) var forca_empurrao: float = 480.0
@export_range(0.05, 0.7, 0.05) var duracao_empurrao: float = 0.22

var jogador: Jogador
var inventario: EquipamentosAtivos


func ativar(alvo: Jogador, controle: EquipamentosAtivos) -> bool:
    if is_instance_valid(controle.escudo_ativo):
        controle.aviso.emit("Escudo ja esta ativo.")
        return false
    jogador = alvo
    inventario = controle
    controle.escudo_ativo = self
    position = Vector2(20, 20)
    queue_redraw()
    return true


func absorver_dano(origem_dano: Vector2 = Vector2.ZERO) -> bool:
    if inventario == null or inventario.escudo_ativo != self:
        return false
    # O escudo e consumido mesmo por ataques a distancia. O empurrao so
    # acontece se quem causou o golpe for um inimigo movel ao alcance.
    _repelir_agressor_proximo(origem_dano)
    inventario.escudo_ativo = null
    inventario.equipamentos_alterados.emit()
    inventario.aviso.emit("Escudo Memory Leak absorveu um golpe!")
    queue_free()
    return true


func _repelir_agressor_proximo(origem_dano: Vector2) -> void:
    if not is_instance_valid(jogador) or origem_dano == Vector2.ZERO:
        return
    var centro_jogador: Vector2 = jogador.global_position + Vector2(20.0, 20.0)
    var agressor: InimigoBase
    var menor_distancia_origem: float = 55.0
    for nodo in get_tree().get_nodes_in_group("inimigos"):
        var inimigo: InimigoBase = nodo as InimigoBase
        if inimigo == null or inimigo.encerrado or inimigo.fixo_no_cenario:
            continue
        # A origem do dano normalmente e a posicao do atacante. Isso evita
        # empurrar outro inimigo quando um projetil distante atinge o escudo.
        var distancia_origem: float = origem_dano.distance_to(inimigo.global_position)
        if distancia_origem > menor_distancia_origem:
            continue
        if centro_jogador.distance_to(inimigo.global_position) > alcance_empurrao:
            continue
        menor_distancia_origem = distancia_origem
        agressor = inimigo
    if is_instance_valid(agressor):
        agressor.aplicar_empurrao(centro_jogador, forca_empurrao, duracao_empurrao)


func _draw() -> void:
    draw_arc(Vector2.ZERO, 35.0, 0.0, TAU, 48, Color(0.39, 1.0, 0.63, 0.9), 5.0)
    draw_circle(Vector2.ZERO, 31.0, Color(0.32, 0.85, 0.52, 0.12))
