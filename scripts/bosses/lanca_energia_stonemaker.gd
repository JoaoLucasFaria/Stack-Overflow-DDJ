extends Area2D

## Lança energética: atravessa a arena, volta uma vez e desaparece.
var dono_lanca: Node2D
var direcao: int = 1
var dano: int = 2
var velocidade: float = 740.0
var retornando: bool = false
var duracao: float = 3.0
var x_inicio: float = 0.0


func configurar(dono: Node2D, lado: int, dano_configurado: int, velocidade_configurada: float) -> void:
	dono_lanca = dono
	direcao = 1 if lado >= 0 else -1
	dano = dano_configurado
	velocidade = velocidade_configurada


func _ready() -> void:
	x_inicio = global_position.x
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_ao_tocar)


func _physics_process(delta: float) -> void:
	duracao -= delta
	if duracao <= 0.0:
		queue_free()
		return
	var sentido: int = -direcao if retornando else direcao
	global_position.x += float(sentido) * velocidade * delta
	if not retornando and (global_position.x >= 1090.0 or global_position.x <= 62.0):
		retornando = true
		modulate = Color(1.0, 0.48, 0.44)
	if retornando and ((direcao > 0 and global_position.x <= x_inicio) or (direcao < 0 and global_position.x >= x_inicio)):
		queue_free()


func _ao_tocar(corpo: Node2D) -> void:
	if corpo is Jogador:
		corpo.receber_dano(dano, global_position)
		# A lança não desaparece: jogador deve evitar ida e volta.
