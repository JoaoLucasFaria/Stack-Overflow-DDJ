extends StaticBody2D

## Nucleo destrutivel da sala 19. O ataque basico atinge camada fisica 2.
## Persistencia: flag na Dictionary de dados da sala, mantida pelo mapa na run.
@export_range(1, 8, 1) var golpes_para_romper: int = 3
var golpes_restantes: int = 3
var rompido: bool = false
var _sala: SalaMatriz
@onready var _texto: Label = $Mensagem
@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	golpes_restantes = golpes_para_romper
	_sala = get_parent().get_parent() as SalaMatriz
	if _sala != null and bool(_sala.dados.get("nucleo_cache_rompido", false)):
		rompido = true
		golpes_restantes = 0
		call_deferred("_desativar_barreira")
	_atualizar_visual()

func receber_dano(quantidade: int) -> void:
	if quantidade <= 0 or rompido:
		return
	golpes_restantes = maxi(0, golpes_restantes - 1)
	if golpes_restantes == 0:
		rompido = true
		if _sala != null:
			_sala.dados["nucleo_cache_rompido"] = true
		# Nunca destruir colisores diretamente durante o intersect_shape do ataque.
		call_deferred("_desativar_barreira")
	_atualizar_visual()

func _desativar_barreira() -> void:
	var barreira: StaticBody2D = get_parent().get_node_or_null("BarreiraCache") as StaticBody2D
	if barreira != null:
		barreira.collision_layer = 0
		barreira.visible = false
		for filho in barreira.get_children():
			var colisor: CollisionShape2D = filho as CollisionShape2D
			if colisor != null:
				colisor.disabled = true
	collision_layer = 0

func _atualizar_visual() -> void:
	if _visual != null:
		_visual.color = Color(0.19, 0.39, 0.43) if rompido else Color(1.0, 0.37 + 0.13 * (golpes_restantes - 1), 0.29)
	if _texto != null:
		_texto.text = "CORE LIBERADO" if rompido else "CORE %d/%d [J]" % [golpes_para_romper - golpes_restantes, golpes_para_romper]
