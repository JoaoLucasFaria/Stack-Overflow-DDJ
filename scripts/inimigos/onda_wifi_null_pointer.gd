extends Area2D

## Sinal em tres arcos tipo Wi-Fi. Viaja em linha reta, atravessa
## paredes/plataformas e desaparece depois do alcance maximo.
var direcao: Vector2 = Vector2.LEFT
var velocidade: float = 330.0
var dano: int = 1
var alcance_maximo: float = 470.0
var percorrido: float = 0.0


func configurar(nova_direcao: Vector2, nova_velocidade: float, novo_dano: int, novo_alcance: float) -> void:
	direcao = nova_direcao.normalized() if not nova_direcao.is_zero_approx() else Vector2.LEFT
	velocidade = nova_velocidade
	dano = novo_dano
	alcance_maximo = novo_alcance


func _ready() -> void:
	# So detecta o jogador. Area2D nao bloqueia contra solidos:
	# os arcos passam atraves de paredes e plataformas.
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var formato: CircleShape2D = CircleShape2D.new()
	formato.radius = 23.0
	var colisao: CollisionShape2D = CollisionShape2D.new()
	colisao.shape = formato
	add_child(colisao)
	body_entered.connect(_ao_tocar_corpo)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var passo: float = velocidade * delta
	global_position += direcao * passo
	percorrido += passo
	if percorrido >= alcance_maximo:
		queue_free()


func _ao_tocar_corpo(corpo: Node2D) -> void:
	if corpo is Jogador:
		(corpo as Jogador).receber_dano(dano, global_position)
		queue_free()


func _draw() -> void:
	var angulo: float = direcao.angle()
	var cor: Color = Color(0.43, 0.95, 1.0, 0.92)
	# Tres arcos concêntricos voltados para a direcao do tiro: )))
	for raio in [8.0, 15.0, 22.0]:
		draw_arc(Vector2.ZERO, raio, angulo - 0.92, angulo + 0.92, 24, cor, 3.0, true)
	draw_circle(Vector2.ZERO, 3.5, Color(0.95, 1.0, 1.0, 1.0))
