extends Area2D

## Estrutura de Data Cache para integrar o sorteio de itens na proxima etapa.
## F abre o cache, mas a recompensa ainda nao é sorteada/coletada.
## A abertura permanece registrada em dados da sala durante toda a run.
@export var identificador: String = "cache"
@export var requer_pulo_duplo: bool = false

var _jogador: Jogador
var _sala: SalaMatriz
var _aberto: bool = false
@onready var _mensagem: Label = $Mensagem
@onready var _corpo_visual: ColorRect = $Visual

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_entrou)
	body_exited.connect(_saiu)
	_sala = get_parent().get_parent() as SalaMatriz
	if _sala != null:
		_aberto = bool(_sala.dados.get("cache_aberto_" + identificador, false))
	_atualizar_visual()

func _process(_delta: float) -> void:
	if not is_instance_valid(_jogador):
		return
	if not Input.is_action_just_pressed("coletar_item"):
		return
	if requer_pulo_duplo and not _jogador.pulo_duplo_liberado:
		_mensagem.text = "PULO DUPLO NECESSARIO"
		return
	if _aberto:
		_mensagem.text = "RECOMPENSA: aguardando V16"
		return
	_aberto = true
	if _sala != null:
		_sala.dados["cache_aberto_" + identificador] = true
	_atualizar_visual()

func _entrou(corpo: Node2D) -> void:
	if corpo is Jogador:
		_jogador = corpo as Jogador
		_atualizar_visual()

func _saiu(corpo: Node2D) -> void:
	if corpo == _jogador:
		_jogador = null
		_atualizar_visual()

func _atualizar_visual() -> void:
	if _corpo_visual != null:
		_corpo_visual.color = Color(0.26, 0.73, 0.82, 0.85) if _aberto else Color(0.94, 0.70, 0.22, 1.0)
	if _mensagem != null:
		_mensagem.visible = is_instance_valid(_jogador)
		if _aberto:
			_mensagem.text = "RECOMPENSA: aguardando V16"
		elif requer_pulo_duplo and is_instance_valid(_jogador) and not _jogador.pulo_duplo_liberado:
			_mensagem.text = "PULO DUPLO NECESSARIO"
		else:
			_mensagem.text = "[F] ABRIR DATA CACHE"
