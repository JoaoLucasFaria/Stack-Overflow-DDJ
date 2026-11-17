extends Area2D

## Armadilha unica. Causa dano e teleporta inimigos comuns para longe do jogador.
## Chefes recebem somente o dano: mover chefes quebra suas arenas roteirizadas.
@export var custo_overflow: float = 20.0
@export var recarga_segundos: float = 6.0
@export var acompanha_jogador: bool = false
@export_range(1, 15, 1) var dano: int = 2
@export var distancia_teleporte: float = 170.0
@export var duracao_maxima: float = 14.0

var jogador: Jogador
var vida: float = 0.0
var consumida: bool = false
var inimigo_pendente: InimigoBase


func ativar(alvo: Jogador, controle: EquipamentosAtivos) -> bool:
    jogador = alvo
    var origem: Vector2 = alvo.global_position + Vector2(20.0, 20.0)
    var busca: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origem, origem + Vector2(0.0, 320.0), 1)
    busca.exclude = [alvo.get_rid()]
    var solo: Dictionary = get_world_2d().direct_space_state.intersect_ray(busca)
    if solo.is_empty():
        controle.aviso.emit("Armadilha exige solo logo abaixo.")
        return false
    global_position = Vector2(origem.x, (solo.get("position") as Vector2).y - 13.0)
    vida = duracao_maxima
    body_entered.connect(_ao_corpo_entrar)
    # Caso algum inimigo ja esteja sobre o ponto ao criar a armadilha.
    call_deferred("_verificar_corpos_iniciais")
    return true


func _physics_process(delta: float) -> void:
    # A mudanca de posicao de um corpo fisico precisa ocorrer no frame de
    # fisica, e nao diretamente dentro do sinal body_entered.
    if inimigo_pendente != null:
        if is_instance_valid(inimigo_pendente) and not inimigo_pendente.is_queued_for_deletion():
            _teleportar_com_seguranca(inimigo_pendente)
        inimigo_pendente = null
        queue_free()
        return
    vida -= delta
    if vida <= 0.0:
        queue_free()


func _verificar_corpos_iniciais() -> void:
    if consumida:
        return
    for corpo in get_overlapping_bodies():
        if corpo is InimigoBase or corpo is BossBase:
            _ao_corpo_entrar(corpo)
            break


func _ao_corpo_entrar(corpo: Node2D) -> void:
    if consumida or not (corpo is InimigoBase or corpo is BossBase):
        return
    consumida = true
    corpo.call("receber_dano", dano)
    if is_instance_valid(corpo) and not corpo.is_queued_for_deletion() and corpo is InimigoBase:
        var inimigo: InimigoBase = corpo as InimigoBase
        if not inimigo.fixo_no_cenario:
            inimigo_pendente = inimigo
            return
    queue_free()


func _teleportar_com_seguranca(inimigo: InimigoBase) -> void:
    if not is_instance_valid(jogador):
        return
    var sentido: float = signf(inimigo.global_position.x - (jogador.global_position.x + 20.0))
    if is_zero_approx(sentido):
        sentido = float(jogador.direcao_olhar)
    var origem: Vector2 = inimigo.global_position
    var comprimento: float = distancia_teleporte
    # Se nao houver uma posicao segura (solo livre), somente o dano sera aplicado.
    for tentativa in range(5):
        var destino: Vector2 = origem + Vector2(sentido * comprimento, 0.0)
        var parede: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origem, destino, 1)
        parede.exclude = [inimigo.get_rid()]
        if get_world_2d().direct_space_state.intersect_ray(parede).is_empty():
            var sondagem: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(destino, destino + Vector2(0.0, 65.0), 1)
            sondagem.exclude = [inimigo.get_rid()]
            if not get_world_2d().direct_space_state.intersect_ray(sondagem).is_empty():
                var forma: CollisionShape2D = inimigo.get_node_or_null("CollisionShape2D") as CollisionShape2D
                if forma != null and forma.shape != null:
                    var teste: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
                    teste.shape = forma.shape
                    teste.transform = Transform2D(0.0, destino + forma.position)
                    teste.collision_mask = 1
                    teste.exclude = [inimigo.get_rid()]
                    if get_world_2d().direct_space_state.intersect_shape(teste, 1).is_empty():
                        inimigo.global_position = destino
                        inimigo.velocity = Vector2.ZERO
                        return
        comprimento *= 0.70
