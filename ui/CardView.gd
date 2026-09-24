## 一张牌的外观节点。
##
## 根节点用 Control（不是 Area2D）：解谜游戏不要物理，只要鼠标点击和布局。
## 点击走 _gui_input，悬停走 mouse_entered / mouse_exited。
## 子节点全部设成 mouse_filter = IGNORE，否则 Label 会把点击吃掉。
##
## 层次（从下到上）：
##   Base  纯色兜底底，按卡的 kind 着色 —— 没素材时它就是卡面
##   Art   卡面图片，素材放 assets/cards/<id>.png 即可，见 ui/CardArt.gd
##   Sheet 底部文字条（名称/描述/状态），盖在图上保证可读
##   Frame 最上层的圆角描边，只负责表达状态（可出 / 封印 / 悬停）
##
class_name CardView
extends Control

signal clicked(id: StringName)

## 卡的实际显示尺寸 —— 全项目只有这一处定尺寸。
## Main.gd 的排布、底部文字条高度、字号都从它派生，改这里就够了。
## 比例 2:3，和 assets/cards/ 里素材的建议规格 256x384 对齐。
const SIZE := Vector2(200, 300)

## 底部文字条占卡高的比例；上面的部分留给卡面素材。
const SHEET_RATIO := 0.46
## 文字条离卡边的内缩，和圆角对齐，免得压在描边上。
const SHEET_INSET := 6.0

## 字号跟着卡走：卡片放大了字还留原来那么小，卡面会显得头重脚轻。
const TITLE_SIZE := 26
const DESC_SIZE := 15
const NOTE_SIZE := 15

## 悬停抬起的高度、解脱时飘起的高度，都按卡高取比例。
const HOVER_LIFT := 10.0

const BASE_TINT := Color(0.17, 0.19, 0.25, 1.0)
const GOAL_TINT := Color(0.24, 0.19, 0.11, 1.0)
const GUIDE_TINT := Color(0.12, 0.23, 0.28, 1.0)

const GEM_SEALED := Color(0.36, 0.38, 0.44, 1.0)
const GEM_OPEN := Color(0.55, 0.88, 0.66, 1.0)
const GEM_PLAYED := Color(0.40, 0.42, 0.50, 1.0)
const GEM_GUIDE := Color(0.55, 0.80, 0.95, 1.0)

const ROUND_SHADER := preload("res://ui/card_round_corners.gdshader")

@export var card_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var role: CardData.Kind = CardData.Kind.COMMON

@onready var _base: PanelContainer = $Base
@onready var _art: TextureRect = $Art
@onready var _frame: PanelContainer = $Frame
@onready var _sheet: PanelContainer = $Sheet
@onready var _gem: ColorRect = $Sheet/Margin/VBox/Head/Face
@onready var _title: Label = $Sheet/Margin/VBox/Head/Title
@onready var _desc: Label = $Sheet/Margin/VBox/Desc
@onready var _note: Label = $Sheet/Margin/VBox/Note

var _locked := true
var _home := Vector2.ZERO
var _cur: int = -1


func _ready() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_base.add_theme_stylebox_override("panel", _tint_box())
	_round_the_art()
	_layout_sheet()
	_style_sheet()
	_scale_type()

	_desc.text = description
	_title.text = display_name
	_refresh_style(false)


# ---------------------------------------------------------------- 对外

## 卡面素材。传 null 就露出 Base 的纯色底。
func set_art(tex: Texture2D) -> void:
	_art.texture = tex
	_art.visible = tex != null


## home 是这张牌在桌面上的落位；移动用补间，别硬改 position。
func set_home(pos: Vector2, animate := true) -> void:
	_home = pos
	if not animate:
		position = pos
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", pos, 0.45)


## 同一状态重复推过来时直接跳过，避免每帧堆一堆互相打架的补间。
func apply_state(state: LiberationEngine.State) -> void:
	if _cur == state:
		return
	_cur = state
	match state:
		LiberationEngine.State.SEALED:
			_locked = true
			_note.text = "封 印"
			_set_gem(GEM_SEALED)
			_refresh_style(false)
		LiberationEngine.State.OPEN:
			_locked = false
			_note.text = "可 出"
			_set_gem(GEM_OPEN if role != CardData.Kind.GUIDE else GEM_GUIDE)
			_refresh_style(true)
		LiberationEngine.State.PLAYED:
			_locked = true
			_note.text = "已 出"
			_set_gem(GEM_PLAYED)
			_refresh_style(false)
		LiberationEngine.State.LIBERATED:
			_locked = true
			_note.text = "解 脱"
			_set_gem(GEM_OPEN)
			_refresh_style(false)
			liberate()


## 迷途牌专用：把「走到第几站」写在这张牌自己身上。
func set_progress(index: int, total: int) -> void:
	_note.text = "第 %d / %d 站" % [index, total]


func liberate() -> void:
	_locked = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_property(self, "position:y", position.y - CardView.SIZE.y * 0.16, 0.6)
	tw.chain().tween_callback(func() -> void: visible = false)


# ---------------------------------------------------------------- 内部

func _gui_input(event: InputEvent) -> void:
	if _locked:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	accept_event()
	clicked.emit(card_id)


func _on_mouse_entered() -> void:
	if _locked:
		return
	z_index = 10
	_refresh_style(true, true)


func _on_mouse_exited() -> void:
	z_index = 0
	if _locked:
		return
	_refresh_style(true, false)


func _set_gem(color: Color) -> void:
	var tw := create_tween()
	tw.tween_property(_gem, "color", color, 0.2)


## hover / 可出 时长得亮一点，其余时候压暗。hover 用 offset 抬 6 像素。
func _refresh_style(lit: bool, hovered := false) -> void:
	var alpha := 0.55 if not lit else 1.0
	modulate = Color(1, 1, 1, alpha)
	position = _home + (Vector2(0, -HOVER_LIFT) if hovered else Vector2.ZERO)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.60, 0.70, 0.55 if lit else 0.28)
	if hovered:
		sb.border_color = Color(0.85, 0.92, 1.0, 0.95)
	_frame.add_theme_stylebox_override("panel", sb)


func _tint() -> Color:
	if role == CardData.Kind.GOAL:
		return GOAL_TINT
	if role == CardData.Kind.GUIDE:
		return GUIDE_TINT
	return BASE_TINT


## 兜底底色：没素材时它就是卡面，圆角和 Frame 对齐。
func _tint_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _tint()
	sb.set_corner_radius_all(12)
	return sb


## 底部文字条的高度跟着 SIZE 走，卡片改尺寸时不用再回来改场景文件。
func _layout_sheet() -> void:
	_sheet.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0
	)
	_sheet.offset_left = SHEET_INSET
	_sheet.offset_right = -SHEET_INSET
	_sheet.offset_top = -roundf(SIZE.y * SHEET_RATIO)
	_sheet.offset_bottom = -SHEET_INSET
	var m := _sheet.get_node_or_null("Margin") as MarginContainer
	if m != null:
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_right", 12)
		m.add_theme_constant_override("margin_top", 10)
		m.add_theme_constant_override("margin_bottom", 10)


## 场景文件里写的是一份默认值，真正生效的字号在这里按常量覆盖一次。
func _scale_type() -> void:
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_desc.add_theme_font_size_override("font_size", DESC_SIZE)
	_note.add_theme_font_size_override("font_size", NOTE_SIZE)
	_note.custom_minimum_size = Vector2(0, NOTE_SIZE + 8)
	_gem.custom_minimum_size = Vector2(12, 0)
	# 卡名只有一行，超了直接截断，别把底部文字条撑高。
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


## 不管素材是不是方图，统一裁成圆角，替换素材时就不用自己抠透明角了。
func _round_the_art() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = ROUND_SHADER
	mat.set_shader_parameter("half_size", SIZE * 0.5)
	_art.material = mat


## 底部文字条压一层半透明黑，图再亮字也看得清。
func _style_sheet() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.8)
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	_sheet.add_theme_stylebox_override("panel", sb)
