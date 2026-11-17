extends CanvasLayer

## Painel de escolha temporario. A logica de coleta pertence ao controlador.
@onready var titulo_item: Label = $Fundo/Painel/TituloItem
@onready var efeito_item: Label = $Fundo/Painel/EfeitoItem
@onready var descricao_item: Label = $Fundo/Painel/DescricaoItem
@onready var opcao_q: Label = $Fundo/Painel/OpcaoQ
@onready var opcao_e: Label = $Fundo/Painel/OpcaoE


func mostrar_item(nome: String, efeito: String, descricao: String, item_q: String, item_e: String, selecionado: int) -> void:
    titulo_item.text = nome.to_upper()
    efeito_item.text = "EFEITO  |  " + efeito
    descricao_item.text = "DESCRICAO  |  " + descricao
    opcao_q.text = (">  " if selecionado == 0 else "    ") + "[Q] " + item_q
    opcao_e.text = (">  " if selecionado == 1 else "    ") + "[E] " + item_e
    opcao_q.modulate = Color(0.4, 1.0, 0.85, 1.0) if selecionado == 0 else Color(0.8, 0.85, 0.92, 1.0)
    opcao_e.modulate = Color(0.4, 1.0, 0.85, 1.0) if selecionado == 1 else Color(0.8, 0.85, 0.92, 1.0)
