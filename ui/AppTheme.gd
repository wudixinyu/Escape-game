## 界面外观的唯一入口：字体和按钮样式。
##
## 中文界面必须显式指定系统字体 —— Godot 的默认字体不含汉字，不指定就是一排豆腐块。
## Main（牌桌）和 Title（主界面）都从这里取，省得两边各写一份、改起来漏一处。
##
class_name AppTheme
extends RefCounted

## 注意：这里用普通数组字面量，别写 PackedStringArray(...) —— 那是构造函数调用，
## Godot 不允许拿来初始化 const（报 "isn't a constant expression"）。
const FONT_NAMES := [
	"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans SC",
	"PingFang SC", "SimHei", "Source Han Sans SC",
]

const BASE_SIZE := 18

const BTN_FILL := Color(0.13, 0.16, 0.22, 0.85)
const BTN_FILL_HOVER := Color(0.18, 0.22, 0.30, 0.95)
const BTN_FILL_PRESSED := Color(0.09, 0.11, 0.15, 0.95)
const BTN_EDGE := Color(0.45, 0.52, 0.62, 0.50)
const BTN_EDGE_HOVER := Color(0.78, 0.86, 0.96, 0.85)


static func base() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.allow_system_fallback = true

	var th := Theme.new()
	th.default_font = font
	th.default_font_size = BASE_SIZE
	return th


## 深底淡边的按钮。默认按钮样式在深色背景上太跳，压一档才和卡面协调。
static func style_button(b: Button) -> void:
	var normal := _box(BTN_FILL, BTN_EDGE)
	var hover := _box(BTN_FILL_HOVER, BTN_EDGE_HOVER)
	var pressed := _box(BTN_FILL_PRESSED, BTN_EDGE)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)


static func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = edge
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


## 关卡目标的中文名，顶栏和主界面共用一套说法。
static func goal_label(goal: LevelData.Goal) -> String:
	match goal:
		LevelData.Goal.RELEASE: return "释放"
		LevelData.Goal.CLEAR: return "清除"
		LevelData.Goal.GUIDE: return "接引"
	return "关卡"
