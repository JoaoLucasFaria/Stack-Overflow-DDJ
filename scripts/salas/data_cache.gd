extends Area2D

## Data Cache V16: F abre (sorteia uma unica vez), F seguinte coleta.
## O conteudo persiste ao sair/voltar, inclusive sem coletar.
@export var identificador: String = "cache"
@export var requer_pulo_duplo: bool = false

var _jogador: Jogador
var _sala: SalaMatriz
var _aberto: bool = false
var _coletado: bool = false
var _item: StringName = &""
var _esperando_soltar_f: bool = false
@onready var _mensagem: Label = $Mensagem
@onready var _corpo_visual: ColorRect = $Visual
@onready var _icone: Label = $Icone

func _ready() -> void:
 collision_layer = 0
 collision_mask = 1
 body_entered.connect(_entrou)
 body_exited.connect(_saiu)
 var ancestral: Node = get_parent()
 while ancestral != null and not (ancestral is SalaMatriz):
  ancestral = ancestral.get_parent()
 _sala = ancestral as SalaMatriz
 if _sala != null:
  var chave: String = _chave()
  _aberto = bool(_sala.dados.get(chave + "_aberto", false))
  _coletado = bool(_sala.dados.get(chave + "_coletado", false))
  _item = StringName(_sala.dados.get(chave + "_item", ""))
 _atualizar_visual()

func _chave() -> String:
 ## Dois caches com identificadores diferentes nao dividem recompensa.
 return "data_cache_v16_" + identificador

func _process(_delta: float) -> void:
 if not is_instance_valid(_jogador) or _coletado or get_tree().paused:
  return
 if _esperando_soltar_f:
  if not Input.is_action_pressed("coletar_item"):
   _esperando_soltar_f = false
  return
 if not Input.is_action_just_pressed("coletar_item"):
  return
 if requer_pulo_duplo and not _jogador.pulo_duplo_liberado:
  _mensagem.text = "PULO DUPLO NECESSARIO"
  return
 if not is_instance_valid(_jogador.utilitarios):
  return
 _esperando_soltar_f = true
 if not _aberto:
  _item = _jogador.utilitarios.sortear_para_cache()
  _aberto = true
  _persistir()
 elif not _jogador.utilitarios.pode_coletar(_item):
  _mensagem.text = "HP CHEIO" if _item == InventarioUtilitarios.CURA else "ITEM JA POSSUIDO"
  return
 elif _jogador.utilitarios.coletar(_item):
  _coletado = true
  _persistir()
 _atualizar_visual()

func _persistir() -> void:
 if _sala == null:
  return
 var chave: String = _chave()
 _sala.dados[chave + "_aberto"] = _aberto
 _sala.dados[chave + "_coletado"] = _coletado
 _sala.dados[chave + "_item"] = String(_item)

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
  _corpo_visual.color = Color(0.25, 0.35, 0.39) if _coletado else (Color(0.22, 0.77, 0.59) if _aberto else Color(0.94, 0.70, 0.22))
 if _icone != null:
  _icone.text = "[VAZIO]" if _coletado else ("[ITEM]" if _aberto else "<DATA>")
 if _mensagem == null:
  return
 _mensagem.visible = is_instance_valid(_jogador) and not _coletado
 if _coletado:
  _mensagem.text = ""
 elif _aberto:
  var nome: String = String(InventarioUtilitarios.NOMES.get(_item, String(_item)))
  _mensagem.text = "%s  [F] COLETAR" % nome
 elif requer_pulo_duplo and is_instance_valid(_jogador) and not _jogador.pulo_duplo_liberado:
  _mensagem.text = "PULO DUPLO NECESSARIO"
 else:
  _mensagem.text = "[F] ABRIR DATA CACHE"
