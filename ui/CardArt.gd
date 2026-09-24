## 卡面素材的定位规则，全项目只有这一处说了「图放哪」。
##
## 默认约定：把图片按卡 id 命名，丢进 res://assets/cards/ 即可 ——
##     assets/cards/soul.png        ← 第一关「被困之魂」的卡面
##
## 替换素材时不用动任何代码，同名覆盖就行。
## 想换目录或扩展名，改下面两个常量。
##
## 建议规格：512 x 768（2:3，当前素材就是这个规格；显示尺寸 200 x 300 的两倍多）。
## 素材按 KEEP_ASPECT_COVERED 铺满卡面，比例差太多会被裁掉边缘，主体别贴太靠边。
## 方图也行 —— ui/card_round_corners.gdshader 会统一裁成圆角。
## 重做素材的流水线：tools/_pack_art.py 负责 2:3 裁切 + 圆角 + 底部压暗。
##
class_name CardArt
extends RefCounted

const DIR := "res://assets/cards/"
const EXT := ".png"


## 先看卡数据里有没有显式指定的，再按 id 查约定目录，都没有就返回 null（露出纯色底）。
static func for_card(id: StringName, explicit: Texture2D = null) -> Texture2D:
	if explicit != null:
		return explicit

	var path := DIR + String(id) + EXT
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	push_warning("CardArt: 找不到卡面素材 %s，用纯色底凑合" % path)
	return null
