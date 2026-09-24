## 主界面：只负责「入局」和「挑一关」，进去之后的事全归 Main。
##
## 关卡清单从 Game.levels 现读，通关标记从 Game.cleared 现读，
## 所以这里是「显示进度」而不是「存进度」—— 进度本身在 Game.gd 里。
##
extends Control

const MAIN_SCENE := "res://Main.tscn"

## 中文序数，超过就用阿拉伯数字兜底。
const ORDINAL := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

@onready var _start: Button = $"Center/Box/Start"
@onready var _levels: VBoxContainer = $"Center/Box/Levels"
@onready var _foot: Label = $"Center/Box/Foot"


func _ready() -> void:
	theme = AppTheme.base()
	AppTheme.style_button(_start)
	_start.pressed.connect(_enter.bind(0))
	_build_entries()
	_foot.text = "共 %d 关 · 已解开 %d 关" % [Game.levels.size(), Game.cleared.size()]


## 关卡清单：通关的挂个勾，没通关的也照常能进 —— 这是解谜，不是闯关。
func _build_entries() -> void:
	for c in _levels.get_children():
		c.queue_free()

	for i in Game.levels.size():
		var lv: LevelData = Game.levels[i]
		var done := Game.cleared.has(i)
		var b := Button.new()
		b.text = "%s · %s · %s%s" % [
			_ordinal(i), lv.title, AppTheme.goal_label(lv.goal), "   ✓" if done else "",
		]
		b.custom_minimum_size = Vector2(560, 0)
		AppTheme.style_button(b)
		b.pressed.connect(_enter.bind(i))
		_levels.add_child(b)


func _enter(index: int) -> void:
	Game.index = index
	get_tree().change_scene_to_file(MAIN_SCENE)


func _ordinal(i: int) -> String:
	return ORDINAL[i] if i < ORDINAL.size() else str(i + 1)
