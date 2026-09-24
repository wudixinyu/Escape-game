## 自动加载。只管「现在在第几关」和「哪几关通了」，不碰任何规则。
##
extends Node

const LIBRARY := preload("res://levels/LevelLibrary.gd")

signal level_changed(index: int)

var index: int = 0
var levels: Array[LevelData] = []
var cleared: Array[int] = []


## 放在 _init 里而不是 _ready：无头跑 --script 时 autoLoad 的 _ready 不一定被调用。
func _init() -> void:
	levels = LevelLibrary.build()


func current_level() -> LevelData:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]


func goto(i: int) -> void:
	var next := clampi(i, 0, levels.size() - 1)
	if next == index:
		level_changed.emit(index) ## 同关也重发一次，等于「重来」
		return
	index = next
	level_changed.emit(index)


func mark_cleared(i: int) -> void:
	if not cleared.has(i):
		cleared.append(i)
