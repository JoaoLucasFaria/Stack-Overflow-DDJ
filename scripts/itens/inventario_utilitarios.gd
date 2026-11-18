class_name InventarioUtilitarios
extends Node

## Utilitarios de Data Cache: apenas cinco itens aprovados.
## O inventario pertence ao jogador e reinicia junto com a run.
signal inventario_alterado
signal aviso(texto: String)

const CURA: StringName = &"restore_point"
const REVIVE: StringName = &"system_restore"
const REROLL: StringName = &"patch_reroll"
const TELEPORTE: StringName = &"fast_travel"
const REFACTOR: StringName = &"patch_refactor"
const ITENS: Array[StringName] = [CURA, REVIVE, REROLL, TELEPORTE, REFACTOR]
const NOMES: Dictionary = {
 &"restore_point": "restore_point() | Recuperacao de Vida",
 &"system_restore": "system.restore() | Revive",
 &"patch_reroll": "patch.reroll() | Reroll",
 &"fast_travel": "fast.travel() | Teleporte",
 &"patch_refactor": "patch.refactor() | Refactor"
}
const DESCRICOES: Dictionary = {
 &"restore_point": "Cura 40% do HP maximo ao coletar.",
 &"system_restore": "Ao morrer, revive com 50% de HP, 3 segundos invulneravel e sem atacar. Unico por run.",
 &"patch_reroll": "Na recompensa de Exception Handler, sorteie outras tres opcoes.",
 &"fast_travel": "No BUILD, teleporte para um BREAKPOINT descoberto; consumido ao viajar.",
 &"patch_refactor": "No BUILD, substitua um Patch por um dos tres sorteados no nivel 1."
}

var jogador
var quantidades: Dictionary = {&"system_restore": 0, &"patch_reroll": 0, &"fast_travel": 0, &"patch_refactor": 0}
## Reserva o revive no SORTEIO, nao na coleta; nao pode reaparecer na mesma run.
var revive_sorteado: bool = false

func configurar(alvo) -> void:
 jogador = alvo

func quantidade(id: StringName) -> int:
 return int(quantidades.get(id, 0))

func sortear_para_cache() -> StringName:
 ## Pesos iniciais de balanceamento, sem moedas nem itens adicionais.
 var pesos: Dictionary = {&"restore_point": 30, &"patch_reroll": 25, &"fast_travel": 20, &"patch_refactor": 20}
 if not revive_sorteado:
  pesos[REVIVE] = 5
 var total: int = 0
 for peso in pesos.values():
  total += int(peso)
 var escolha: int = randi_range(1, total)
 for id in pesos.keys():
  escolha -= int(pesos[id])
  if escolha <= 0:
   var sorteado: StringName = StringName(id)
   if sorteado == REVIVE:
    revive_sorteado = true
   return sorteado
 return CURA

func pode_coletar(id: StringName) -> bool:
 if id == CURA:
  return is_instance_valid(jogador) and jogador.vida_atual > 0 and jogador.vida_atual < jogador.vida_maxima
 if id == REVIVE:
  return quantidade(REVIVE) == 0
 return ITENS.has(id)

func coletar(id: StringName) -> bool:
 if not pode_coletar(id):
  return false
 if id == CURA:
  var cura: int = maxi(1, ceili(float(jogador.vida_maxima) * 0.40))
  jogador.vida_atual = mini(jogador.vida_maxima, jogador.vida_atual + cura)
  jogador.vida_alterada.emit(jogador.vida_atual, jogador.vida_maxima)
 else:
  quantidades[id] = quantidade(id) + 1
 inventario_alterado.emit()
 aviso.emit("DATA CACHE: %s" % String(NOMES.get(id, str(id))))
 return true

func consumir(id: StringName) -> bool:
 if quantidade(id) <= 0:
  return false
 quantidades[id] = quantidade(id) - 1
 inventario_alterado.emit()
 return true

func tentar_reviver() -> bool:
 if not is_instance_valid(jogador) or quantidade(REVIVE) <= 0:
  return false
 if not consumir(REVIVE):
  return false
 jogador.vida_atual = maxi(1, ceili(float(jogador.vida_maxima) * 0.50))
 jogador.tempo_iframes = maxf(jogador.tempo_iframes, 3.0)
 jogador.tempo_bloqueio_ataque = 3.0
 jogador.tempo_knockback = 0.0
 jogador.tempo_travamento_overflow_restante = 0.0
 jogador.velocity = Vector2.ZERO
 jogador.vida_alterada.emit(jogador.vida_atual, jogador.vida_maxima)
 aviso.emit("system.restore(): revivido! 3s sem atacar.")
 return true
