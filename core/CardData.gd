## 卡牌规则数据。
##
## 全部规则都用「标记 (tag)」表达，所以设计新关卡不需要写一行逻辑：
##
##   starting       开局就在手边，可以直接出
##   requires       这些标记必须全部在场，这张牌才从「封印」变成「可出」
##   grants         出牌后投放这些标记（此外这张牌自己的 id 也会自动成为标记）
##   clears         出牌后抹除这些标记 —— 用来给一次鲁莽留补救的余地
##   liberated_by   这些标记全在场时，这张牌「解脱」，从桌上消失
##   blocked_by     其中任一标记在场，就永远无法解脱
##
## 结算顺序：出牌 → 投放/抹除标记 → 反复结算(解锁 + 解脱) → 判定胜负。
##
class_name CardData
extends Resource

## 只影响外观，不影响规则。
enum Kind {
	COMMON, ## 普通牌
	GOAL,   ## 释放型的目标牌，描金边
	GUIDE,  ## 接引型的迷途牌，不可出，只沿途移动
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: Kind = Kind.COMMON

@export var starting: bool = false
@export var requires: Array[StringName] = []
@export var grants: Array[StringName] = []
@export var clears: Array[StringName] = []
@export var liberated_by: Array[StringName] = []
@export var blocked_by: Array[StringName] = []

## 卡面素材。留空时按约定目录自动找 assets/cards/<id>.png，
## 都没有才退回纯色底。想手动指定，把 Texture2D 拖到这里即可。
@export var art: Texture2D

## 参考解。只用于自检测试与「看一眼提示」，引擎本身不读它。
@export var solution_hint: String = ""
