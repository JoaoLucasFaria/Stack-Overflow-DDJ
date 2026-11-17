extends Area2D

## Tiro independente; segue apenas a direcao horizontal do ultimo movimento.
@export var custo_overflow: float = 15.0
@export var recarga_segundos: float = 2.0
@export var acompanha_jogador: bool = false
@export var velocidade: float = 620.0
@export_range(1, 15, 1) var dano: int = 2
@export var distancia_maxima: float = 1150.0

var jogador: Jogador
var direcao: int = 1
var distancia: float = 0.0


func ativar(alvo: Jogador, _controle: EquipamentosAtivos) -> bool:
    jogador = alvo
    direcao = -1 if alvo.direcao_olhar < 0 else 1
    global_position = alvo.global_position + Vector2(20.0 + direcao * 39.0, 20.0)
    rotation = 0.0
    return true


func _physics_process(delta: float) -> void:
    if not is_instance_valid(jogador):
        queue_free()
        return
    var origem: Vector2 = global_position
    var destino: Vector2 = origem + Vector2(float(direcao) * velocidade * delta, 0.0)
    # Raycast evita atravessar inimigos finos por causa da velocidade alta.
    var consulta: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origem, destino, 3)
    consulta.exclude = [jogador.get_rid()]
    var colisao: Dictionary = get_world_2d().direct_space_state.intersect_ray(consulta)
    if not colisao.is_empty():
        var alvo: Object = colisao.get("collider")
        if alvo != null and alvo.has_method("receber_dano"):
            alvo.call("receber_dano", dano)
        queue_free()
        return
    global_position = destino
    distancia += velocidade * delta
    if distancia >= distancia_maxima:
        queue_free()
