class_name SalaMatriz
extends Node2D

## Cada cena herdada de sala_base.tscn possui TODA a geometria editável.
## Este script gerencia somente transições físicas, chefes e eventos especiais.
## Os bits do Inspector precisam corresponder exatamente às conexões do mapa:
## esquerda=1, direita=2, cima=4, baixo=8.
signal boss_derrotado(identificador: int)
signal altar_ativado

const LARGURA: float = 1152.0
const ALTURA: float = 648.0
const PISO_Y: float = 600.0
const VAO_TOPO_X: float = 514.0
const VAO_TOPO_L: float = 124.0
const CENA_BOSS = preload("res://scripts/boss_provisorio.gd")

@export_category("Conexoes do modulo")
@export_flags("Esquerda", "Direita", "Cima", "Baixo") var mascara_saidas: int = 0

var coordenada: Vector2i = Vector2i.ZERO
var dados: Dictionary = {}
var jogador: Jogador
var chefes_derrotados: Dictionary = {}
var grapple_realizado: bool = false
var final_ativado: bool = false
var ponto_retorno_abismo: Vector2 = Vector2(100, 540)
var barreira_boss_final: StaticBody2D


func configurar(posicao: Vector2i, informacoes: Dictionary, alvo: Jogador, derrotados: Dictionary) -> void:
	coordenada = posicao
	dados = informacoes
	jogador = alvo
	chefes_derrotados = derrotados


func _ready() -> void:
	var mascara_necessaria: int = MapaMatriz.mascara_das_conexoes(dados.get("conexoes", {}))
	if mascara_saidas != mascara_necessaria:
		push_error("Modelo de sala com saídas incompatíveis: %s. Tem %d, precisa %d." % [scene_file_path, mascara_saidas, mascara_necessaria])

	var tipo: String = dados.get("tipo", "normal")
	if tipo.begins_with("boss"):
		var identificador: int = tipo.substr(4).to_int()
		if not chefes_derrotados.has(identificador):
			var boss: BossProvisorio = CENA_BOSS.new() as BossProvisorio
			boss.position = _marcador("PosicaoBoss").position
			boss.configurar(identificador, jogador)
			boss.derrotado.connect(_ao_derrotar_boss)
			$Conteudo.add_child(boss)
	if tipo == "boss3":
		barreira_boss_final = get_node_or_null("Contorno/Boss3Barrier") as StaticBody2D
		if chefes_derrotados.has(3) and is_instance_valid(barreira_boss_final):
			barreira_boss_final.queue_free()


func _marcador(nome: String) -> Marker2D:
	return get_node("Pontos/" + nome) as Marker2D


func direcao_de_passagem_confirmada(alvo: Jogador) -> Vector2i:
	## Não usa Area2D que dispare duas vezes: cruza a borda real da sala.
	if not is_instance_valid(alvo):
		return Vector2i.ZERO
	var colisao: CollisionShape2D = alvo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if colisao == null:
		return Vector2i.ZERO
	var centro: Vector2 = to_local(colisao.global_position)
	var velocidade: Vector2 = alvo.velocity
	var lateral: bool = centro.y >= 496.0 and centro.y <= PISO_Y
	var vertical: bool = centro.x >= VAO_TOPO_X and centro.x <= VAO_TOPO_X + VAO_TOPO_L
	var conexoes: Dictionary = dados.get("conexoes", {})
	if conexoes.has(Vector2i.LEFT) and centro.x < 0.0 and velocidade.x < -0.01 and lateral:
		return Vector2i.LEFT
	if conexoes.has(Vector2i.RIGHT) and centro.x > LARGURA and velocidade.x > 0.01 and lateral:
		return Vector2i.RIGHT
	if conexoes.has(Vector2i.UP) and centro.y < 0.0 and velocidade.y < -0.01 and vertical:
		return Vector2i.UP
	if conexoes.has(Vector2i.DOWN) and centro.y > ALTURA and velocidade.y > 0.01 and vertical:
		return Vector2i.DOWN
	return Vector2i.ZERO


func spawn_para_entrada(direcao_movimento: Vector2i) -> Vector2:
	var nome: String = "SpawnInicio"
	if direcao_movimento == Vector2i.LEFT:
		nome = "SpawnDireita"
	elif direcao_movimento == Vector2i.RIGHT:
		nome = "SpawnEsquerda"
	elif direcao_movimento == Vector2i.UP:
		nome = "SpawnCima"
	elif direcao_movimento == Vector2i.DOWN:
		nome = "SpawnBaixo"
	var posicao: Vector2 = _marcador(nome).global_position
	if dados.get("tipo", "") == "bloqueio_dash":
		ponto_retorno_abismo = _marcador("RetornoAbismoDireita").global_position if direcao_movimento == Vector2i.LEFT else _marcador("RetornoAbismoEsquerda").global_position
	return posicao


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(jogador):
		return
	var tipo: String = dados.get("tipo", "")
	if tipo == "bloqueio_dash":
		if jogador.global_position.y > ALTURA + global_position.y + 45.0:
			jogador.preparar_para_nova_sala()
			jogador.global_position = ponto_retorno_abismo
	elif tipo == "final":
		if jogador.grapple_liberado and not grapple_realizado and Input.is_action_just_pressed("grapple_final"):
			if jogador.global_position.distance_to(_marcador("AncoraGrapple").global_position) <= 285.0:
				grapple_realizado = true
				jogador.preparar_para_nova_sala()
				jogador.global_position = _marcador("DestinoGrapple").global_position
				queue_redraw()
		if grapple_realizado and not final_ativado:
			if jogador.global_position.distance_to(_marcador("Altar").global_position) <= 90.0:
				final_ativado = true
				altar_ativado.emit()


func _draw() -> void:
	## Apenas o EFEITO dinâmico do grapple. Nenhuma plataforma é desenhada aqui.
	if grapple_realizado and dados.get("tipo", "") == "final":
		draw_line(_marcador("AncoraGrapple").position, _marcador("DestinoGrapple").position, Color("a4e9e2"), 3.0)


func _ao_derrotar_boss(identificador: int) -> void:
	if identificador == 3 and is_instance_valid(barreira_boss_final):
		barreira_boss_final.queue_free()
	boss_derrotado.emit(identificador)
