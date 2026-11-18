class_name Jogador
extends CharacterBody2D

const SCRIPT_PATCHES = preload("res://scripts/patches/gerenciador_patches.gd")
const SCRIPT_ITENS = preload("res://scripts/itens/inventario_utilitarios.gd")
var patches: GerenciadorPatches
var utilitarios: InventarioUtilitarios
var tempo_bloqueio_ataque: float = 0.0

## Movimentação básica. Mantemos os nomes exportados para preservar ajustes nas cenas.
@export_category("Movimentação")
@export var SPEED: float = 300.0
@export_range(-1000.0, 0.0, 10.0) var JUMP_VELOCITY: float = -600.0
@export_range(1, 10, 1) var MAX_JUMPS: int = 2
@export var jump_release_delay: float = 0.1

@export_category("Wall Slide / Wall Jump (inicial)")
@export var velocidade_maxima_wall_slide: float = 90.0
@export var impulso_wall_jump_x: float = 330.0
@export var impulso_wall_jump_y: float = -470.0
@export var trava_direcao_wall_jump: float = 0.17
var tempo_trava_wall_jump: float = 0.0

@export_category("Dano e Knockback")
@export var duracao_iframes: float = 0.8
@export var forca_knockback_x: float = 300.0
@export var forca_knockback_y: float = -220.0
@export var duracao_knockback: float = 0.18

var tempo_iframes: float = 0.0
var tempo_knockback: float = 0.0

@export_category("Vida")
@export_range(1, 999, 1) var vida_maxima: int = 10

signal vida_alterada(atual: int, maxima: int)
signal morreu
signal overflow_alterado(atual: float, maximo: float)
signal overflow_estourou

var vida_atual: int = 10
@export_category("Stack Overflow (interface para Frente A)")
@export_range(1.0, 1000.0, 1.0) var overflow_maximo: float = 100.0
var overflow_atual: float = 0.0
@export_range(0.1, 2.0, 0.05) var segundos_travamento_overflow: float = 0.5
@export_range(1, 10, 1) var dano_ao_estourar_overflow: int = 1
var tempo_travamento_overflow_restante: float = 0.0
## Correntes Deadlock reduzem o movimento, mas nao sao paredes.
var lentidao_deadlock_restante: float = 0.0
var fator_lentidao_deadlock: float = 1.0
var jumps_remaining: int = 2
var jump_release_timer: float = 0.0
var jump_released: bool = false
var direcao_olhar: int = 1

@export_category("Descida por plataformas")
@export_range(50.0, 300.0, 10.0) var impulso_descida: float = 120.0
## Cada plataforma atravessavel tem um corpo fisico proprio no projeto.
## Mantemos excecoes temporarias apenas para esses corpos, nunca para pisos solidos.
## Ao soltar S + Espaco, uma excecao so sai quando nao prende o jogador.
var plataformas_ignoradas_descida: Array[Dictionary] = []

## Progressão desta partida; o Main concede as habilidades pelos chefes.
var pulo_duplo_liberado: bool = false
var grapple_liberado: bool = false

@onready var dash_component: DashComponent = $DashComponent


func _ready() -> void:
	add_to_group("jogador")
	vida_atual = vida_maxima
	patches = SCRIPT_PATCHES.new() as GerenciadorPatches
	patches.name = "GerenciadorPatches"
	patches.configurar(self)
	add_child(patches)
	utilitarios = SCRIPT_ITENS.new() as InventarioUtilitarios
	utilitarios.name = "InventarioUtilitarios"
	utilitarios.configurar(self)
	add_child(utilitarios)
	jumps_remaining = quantidade_pulos_disponiveis()
	vida_alterada.emit(vida_atual, vida_maxima)
	overflow_alterado.emit(overflow_atual, overflow_maximo)


func _physics_process(delta: float) -> void:
	_atualizar_plataformas_ignoradas()
	lentidao_deadlock_restante = maxf(0.0, lentidao_deadlock_restante - delta)
	if lentidao_deadlock_restante <= 0.0:
		fator_lentidao_deadlock = 1.0
	tempo_iframes = maxf(0.0, tempo_iframes - delta)
	tempo_bloqueio_ataque = maxf(0.0, tempo_bloqueio_ataque - delta)
	tempo_knockback = maxf(0.0, tempo_knockback - delta)
	tempo_trava_wall_jump = maxf(0.0, tempo_trava_wall_jump - delta)
	if tempo_travamento_overflow_restante > 0.0:
		tempo_travamento_overflow_restante = maxf(0.0, tempo_travamento_overflow_restante - delta)
		velocity = Vector2.ZERO
		$ColorRect.modulate = Color(1.0, 0.42, 0.32, 1.0)
		return

	# Feedback visual durante a invencibilidade
	$ColorRect.modulate = Color(
	1.0, 1.0, 1.0,
	0.45 if tempo_iframes > 0.0 else 1.0
)

	# Durante o knockback, o jogador não controla o movimento.
	if tempo_knockback > 0.0:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	
	var no_chao: bool = is_on_floor()
	var direcao: float = Input.get_axis("ui_left", "ui_right")
	# W esta mapeado em ui_up neste projeto; Espaco/Enter usam ui_accept.
	var segurando_descida: bool = _segurando_descida()
	# A combinacao nunca vira um pulo, mesmo no ar ou encostado em parede.
	var pediu_pulo: bool = Input.is_action_just_pressed("ui_accept") and not segurando_descida
	var soltou_pulo: bool = Input.is_action_just_released("ui_accept")
	var normal_parede: Vector2 = get_wall_normal() if is_on_wall() else Vector2.ZERO
	var segurando_parede: bool = (
		not no_chao
		and tempo_trava_wall_jump <= 0.0
		and absf(normal_parede.x) > 0.7
		and direcao * normal_parede.x < -0.5
	)

	if not is_zero_approx(direcao):
		direcao_olhar = -1 if direcao < 0.0 else 1

	# Um único lugar controla o movimento físico (inclusive durante o dash).
	dash_component.atualizar(delta, no_chao, direcao_olhar)
	if dash_component.esta_dashing:
		velocity = dash_component.obter_velocidade_dash() * fator_lentidao_deadlock
		move_and_slide()
		return

	# Enquanto S + ESPACO estiver pressionado, atravessa TODAS as
	# plataformas de mao unica encontradas durante a queda.
	# Pisos solidos permanecem com colisao normal.
	if segurando_descida and _ignorar_plataformas_abaixo(delta):
		no_chao = false

	if not no_chao:
		# Ao cair de uma borda sem pular, o salto do chao nao fica guardado.
		# Sem pulo duplo: 0 saltos no ar. Com pulo duplo: resta 1.
		# mini() preserva pulos que ja foram consumidos durante o salto.
		jumps_remaining = mini(jumps_remaining, quantidade_pulos_disponiveis() - 1)
		velocity += get_gravity() * delta
	else:
		jumps_remaining = quantidade_pulos_disponiveis()

	# Deslizamento: apenas enquanto cai e pressiona contra uma parede.
	if segurando_parede and velocity.y > velocidade_maxima_wall_slide:
		velocity.y = velocidade_maxima_wall_slide

	# Wall Jump: nao consome os pulos aereos, sempre disponivel desde o inicio.
	if pediu_pulo and segurando_parede:
		velocity.x = normal_parede.x * impulso_wall_jump_x
		velocity.y = impulso_wall_jump_y
		tempo_trava_wall_jump = trava_direcao_wall_jump
		jump_released = false
		jump_release_timer = 0.0
		move_and_slide()
		return

	if pediu_pulo and jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
		jump_released = false
		jump_release_timer = 0.0

	if soltou_pulo and velocity.y < 0.0:
		jump_released = true
		jump_release_timer = jump_release_delay

	if jump_released:
		jump_release_timer -= delta
		if jump_release_timer <= 0.0:
			# Soltar o pulo corta a subida depois do atraso configurado.
			velocity.y = 0.0 if velocity.y < 0.0 else velocity.y
			jump_released = false

	# Durante alguns milissegundos o impulso horizontal do Wall Jump tem prioridade.
	var velocidade_efetiva: float = SPEED * (patches.multiplicador_velocidade() if is_instance_valid(patches) else 1.0)
	if tempo_trava_wall_jump <= 0.0:
		if not is_zero_approx(direcao):
			velocity.x = direcao * velocidade_efetiva * fator_lentidao_deadlock
		else:
			# Preserva a desaceleração do protótipo original.
			velocity.x = move_toward(velocity.x, 0.0, velocidade_efetiva)

	move_and_slide()


func aplicar_lentidao_deadlock(fator: float = 0.45, duracao: float = 0.16) -> void:
	## Varios campos de lentidao se acumulam por prioridade do mais forte,
	## sem alterar permanentemente SPEED nem o movimento dos inimigos.
	if vida_atual <= 0 or duracao <= 0.0:
		return
	fator_lentidao_deadlock = minf(fator_lentidao_deadlock, clampf(fator, 0.1, 1.0))
	lentidao_deadlock_restante = maxf(lentidao_deadlock_restante, duracao)


func _segurando_descida() -> bool:
	return Input.is_physical_key_pressed(KEY_S) and Input.is_physical_key_pressed(KEY_SPACE)


func _forma_uma_via(corpo: CollisionObject2D, indice: int) -> CollisionShape2D:
	if corpo == null or indice < 0:
		return null
	var dono_id: int = corpo.shape_find_owner(indice)
	if dono_id < 0:
		return null
	var forma: CollisionShape2D = corpo.shape_owner_get_owner(dono_id) as CollisionShape2D
	if forma != null and not forma.disabled and forma.one_way_collision:
		return forma
	return null


func _corpo_exclusivamente_uma_via(corpo: PhysicsBody2D) -> bool:
	## Excecoes atingem o corpo inteiro. Nao ignoramos um corpo que
	## compartilhe plataformas de mao unica com paredes/pisos solidos.
	var encontrou_forma: bool = false
	for dono_id in corpo.get_shape_owners():
		var forma: CollisionShape2D = corpo.shape_owner_get_owner(dono_id) as CollisionShape2D
		if forma == null:
			return false
		if forma.disabled:
			continue
		if not forma.one_way_collision:
			return false
		encontrou_forma = true
	return encontrou_forma


func _esta_ignorando(corpo: PhysicsBody2D) -> bool:
	for dados in plataformas_ignoradas_descida:
		if dados["corpo"] == corpo:
			return true
	return false


func _buscar_proxima_plataforma(delta: float) -> Dictionary:
	var colisao_jogador: CollisionShape2D = $CollisionShape2D
	var retangulo: RectangleShape2D = colisao_jogador.shape as RectangleShape2D
	if retangulo == null:
		return {}

	# Primeiro considera o contato detectado pelo move_and_slide anterior.
	# Isso evita falhas ao manter S + Espaco pressionado sobre uma plataforma.
	if is_on_floor():
		for i in range(get_slide_collision_count()):
			var colisao: KinematicCollision2D = get_slide_collision(i)
			if colisao.get_normal().dot(Vector2.UP) < 0.7:
				continue
			var corpo: PhysicsBody2D = colisao.get_collider() as PhysicsBody2D
			if corpo == null or _esta_ignorando(corpo) or not _corpo_exclusivamente_uma_via(corpo):
				continue
			var forma: CollisionShape2D = _forma_uma_via(corpo, colisao.get_collider_shape_index())
			if forma != null:
				return {"corpo": corpo, "forma": forma}

	# Raios detectam novas plataformas mesmo com o jogador ja caindo.
	# Tres pontos cobrem o centro e as bordas da hitbox de 42px.
	var excluidos: Array[RID] = [get_rid()]
	for dados in plataformas_ignoradas_descida:
		var corpo_ignorado: PhysicsBody2D = dados["corpo"] as PhysicsBody2D
		if is_instance_valid(corpo_ignorado):
			excluidos.append(corpo_ignorado.get_rid())
	var centro_pe: Vector2 = colisao_jogador.to_global(Vector2(0.0, retangulo.size.y * 0.5))
	var distancia: float = maxf(72.0, maxf(velocity.y, 0.0) * delta * 2.0 + 25.0)
	for deslocamento in [-16.0, 0.0, 16.0]:
		var inicio: Vector2 = centro_pe + Vector2(deslocamento, -6.0)
		var fim: Vector2 = inicio + Vector2.DOWN * distancia
		var parametros: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			inicio, fim, collision_mask, excluidos
		)
		var resultado: Dictionary = get_world_2d().direct_space_state.intersect_ray(parametros)
		if resultado.is_empty():
			continue
		var corpo_ray: PhysicsBody2D = resultado.get("collider") as PhysicsBody2D
		if corpo_ray == null or _esta_ignorando(corpo_ray) or not _corpo_exclusivamente_uma_via(corpo_ray):
			continue
		var forma_ray: CollisionShape2D = _forma_uma_via(corpo_ray, int(resultado.get("shape", -1)))
		if forma_ray != null:
			return {"corpo": corpo_ray, "forma": forma_ray}
	return {}


func _ignorar_plataformas_abaixo(delta: float) -> bool:
	var novas: bool = false
	# Pode haver plataformas muito proximas: continua procurando depois
	# de excluir temporariamente cada corpo encontrado.
	for _i in range(6):
		var dados: Dictionary = _buscar_proxima_plataforma(delta)
		if dados.is_empty():
			break
		if _comecar_descida(dados):
			novas = true
	return novas


func _comecar_descida(dados: Dictionary) -> bool:
	var corpo: PhysicsBody2D = dados["corpo"] as PhysicsBody2D
	var forma: CollisionShape2D = dados["forma"] as CollisionShape2D
	if corpo == null or forma == null or _esta_ignorando(corpo):
		return false
	var retangulo: RectangleShape2D = forma.shape as RectangleShape2D
	if retangulo == null:
		return false
	var semi: Vector2 = retangulo.size * 0.5
	var cantos: Array[Vector2] = [
		forma.to_global(Vector2(-semi.x, -semi.y)),
		forma.to_global(Vector2(semi.x, -semi.y)),
		forma.to_global(Vector2(-semi.x, semi.y)),
		forma.to_global(Vector2(semi.x, semi.y))
	]
	var esquerda: float = INF
	var direita: float = -INF
	var superior: float = INF
	var inferior: float = -INF
	for canto in cantos:
		esquerda = minf(esquerda, canto.x)
		direita = maxf(direita, canto.x)
		superior = minf(superior, canto.y)
		inferior = maxf(inferior, canto.y)
	plataformas_ignoradas_descida.append({
		"corpo": corpo, "esquerda": esquerda, "direita": direita,
		"superior": superior, "inferior": inferior
	})
	add_collision_exception_with(corpo)
	velocity.y = maxf(velocity.y, impulso_descida)
	jump_released = false
	jump_release_timer = 0.0
	return true


func _atualizar_plataformas_ignoradas() -> void:
	var colisao_jogador: CollisionShape2D = $CollisionShape2D
	var retangulo: RectangleShape2D = colisao_jogador.shape as RectangleShape2D
	if retangulo == null:
		_finalizar_descida()
		return
	var semi: Vector2 = retangulo.size * 0.5
	var topo: float = colisao_jogador.to_global(Vector2(0.0, -semi.y)).y
	var pe: float = colisao_jogador.to_global(Vector2(0.0, semi.y)).y
	var esquerda: float = colisao_jogador.to_global(Vector2(-semi.x, 0.0)).x
	var direita: float = colisao_jogador.to_global(Vector2(semi.x, 0.0)).x
	var segurando: bool = _segurando_descida()
	for i in range(plataformas_ignoradas_descida.size() - 1, -1, -1):
		var dados: Dictionary = plataformas_ignoradas_descida[i]
		var corpo: PhysicsBody2D = dados["corpo"] as PhysicsBody2D
		if not is_instance_valid(corpo):
			plataformas_ignoradas_descida.remove_at(i)
			continue
		var passou_abaixo: bool = topo > float(dados["inferior"]) + 2.0
		var fora_lateral: bool = direita < float(dados["esquerda"]) - 2.0 or esquerda > float(dados["direita"]) + 2.0
		var ainda_acima: bool = pe <= float(dados["superior"]) + 1.0
		if passou_abaixo or (not segurando and (fora_lateral or ainda_acima)):
			remove_collision_exception_with(corpo)
			plataformas_ignoradas_descida.remove_at(i)


func _finalizar_descida() -> void:
	for dados in plataformas_ignoradas_descida:
		var corpo: PhysicsBody2D = dados["corpo"] as PhysicsBody2D
		if is_instance_valid(corpo):
			remove_collision_exception_with(corpo)
	plataformas_ignoradas_descida.clear()


func quantidade_pulos_disponiveis() -> int:
	return maxi(2, MAX_JUMPS) if pulo_duplo_liberado else 1


func desbloquear_pulo_duplo() -> void:
	pulo_duplo_liberado = true
	jumps_remaining = quantidade_pulos_disponiveis()


func desbloquear_dash() -> void:
	dash_component.dash_desbloqueado = true


func desbloquear_grapple() -> void:
	grapple_liberado = true


func receber_dano(dano: int, origem_dano: Vector2 = Vector2.ZERO) -> void:
	if dano <= 0 or vida_atual <= 0:
		return

	# Invencibilidade por i-frames ou dash
	if tempo_iframes > 0.0 or dash_component.e_invencivel:
		return

	# Preserva a prioridade do escudo Memory Leak, depois tenta try_catch.
	var equipamentos: EquipamentosAtivos = get_node_or_null("EquipamentosAtivos") as EquipamentosAtivos
	if equipamentos != null and equipamentos.absorver_dano(origem_dano):
		return
	if is_instance_valid(patches) and patches.tentar_absorver_dano():
		tempo_iframes = maxf(tempo_iframes, 0.25)
		return

	vida_atual = maxi(vida_atual - dano, 0)
	vida_alterada.emit(vida_atual, vida_maxima)
	if is_instance_valid(patches) and vida_atual > 0:
		patches.registrar_dano_recebido()

	# Ativa invencibilidade e knockback (interrompe a escalada).
	tempo_iframes = duracao_iframes
	tempo_knockback = duracao_knockback
	tempo_trava_wall_jump = 0.0

	# Empurra o jogador para longe da origem do dano
	var lado: float = -float(direcao_olhar)

	if origem_dano != Vector2.ZERO:
		lado = 1.0 if global_position.x >= origem_dano.x else -1.0

	velocity.x = lado * forca_knockback_x
	velocity.y = forca_knockback_y

	if vida_atual <= 0:
		morrer()

func morrer() -> void:
	if is_instance_valid(utilitarios) and utilitarios.tentar_reviver():
		return
	print("O personagem morreu!")
	morreu.emit()
	queue_free()


func preparar_para_nova_sala() -> void:
	## Mantém a vida e os desbloqueios. Reinicia apenas estados transitórios.
	_finalizar_descida()
	velocity = Vector2.ZERO
	jumps_remaining = quantidade_pulos_disponiveis()
	jump_release_timer = 0.0
	jump_released = false
	tempo_trava_wall_jump = 0.0
	dash_component.cancelar_dash()
	var equipamentos: EquipamentosAtivos = get_node_or_null("EquipamentosAtivos") as EquipamentosAtivos
	if equipamentos != null:
		equipamentos.limpar_efeitos_de_sala()


func adicionar_overflow(quantidade: float) -> void:
	if quantidade <= 0.0 or vida_atual <= 0:
		return
	var overflow_anterior: float = overflow_atual
	# A barra fica em 100 ate o jogador reduzi-la com o ataque basico.
	overflow_atual = minf(overflow_maximo, overflow_atual + quantidade)
	overflow_alterado.emit(overflow_atual, overflow_maximo)
	# A penalidade ocorre somente na transicao de abaixo de 100 para 100.
	if overflow_anterior < overflow_maximo and overflow_atual >= overflow_maximo:
		_estourar_overflow()


func reduzir_overflow(quantidade: float) -> void:
	## Chamado apenas apos um ataque basico causar dano real a um inimigo.
	if quantidade <= 0.0 or vida_atual <= 0:
		return
	overflow_atual = maxf(0.0, overflow_atual - quantidade)
	overflow_alterado.emit(overflow_atual, overflow_maximo)


func esta_travado_por_overflow() -> bool:
	return tempo_travamento_overflow_restante > 0.0


func _estourar_overflow() -> void:
	## Penalidade direta: nao pode ser anulada pelo escudo nem pelos i-frames.
	## Nao zera a barra: ao atingir o limite, equipamentos ficam bloqueados.
	## A invencibilidade durante o travamento evita dano inevitavel em sequencia.
	dash_component.cancelar_dash()
	tempo_knockback = 0.0
	tempo_travamento_overflow_restante = segundos_travamento_overflow
	tempo_iframes = maxf(tempo_iframes, segundos_travamento_overflow)
	velocity = Vector2.ZERO
	vida_atual = maxi(0, vida_atual - dano_ao_estourar_overflow)
	vida_alterada.emit(vida_atual, vida_maxima)
	overflow_estourou.emit()
	if vida_atual <= 0:
		morrer()


func zerar_overflow() -> void:
	overflow_atual = 0.0
	overflow_alterado.emit(overflow_atual, overflow_maximo)


func descansar() -> void:
	## BREAKPOINT recupera HP, mas NAO reduz STACK nem altera equipamentos.
	if vida_atual <= 0:
		return
	vida_atual = vida_maxima
	vida_alterada.emit(vida_atual, vida_maxima)
