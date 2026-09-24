## 一关的全部内容。
##
## 三种「解脱」目标共用同一套「顺序执行 + 状态判定」，
## 差别只在 LiberationEngine.is_solved() 的收尾条件：
##
##   Goal.RELEASE 释放型：goal_ids 里的牌全部解脱
##   Goal.CLEAR   清除型：桌上所有牌全部解脱（迷途牌除外）
##   Goal.GUIDE   接引型：迷途牌走完整条 guide_route
##
class_name LevelData
extends Resource

enum Goal {
	RELEASE,
	CLEAR,
	GUIDE,
}

@export var title: String = ""
@export var intro: String = ""
@export var goal: Goal = Goal.RELEASE
@export var cards: Array[CardData] = []

## ---- 释放型 ----
## 这些牌全部解脱即通关。
@export var goal_ids: Array[StringName] = []

## ---- 接引型 ----
## 迷途牌的 id。它通常配一条永远满足不了的 requires，所以永远「封印」、不能被点。
@export var guide_id: StringName = &""
## 沿途依次需要的标记。每张推进用的牌必须 grants 出当前这一站的标记（或本身就是这个 id）。
@export var guide_route: Array[StringName] = []
## 落点，长度应为 guide_route.size() + 1（起点 + 每一站）。不足时 Main.gd 会自动补位。
@export var guide_stops: Array[Vector2] = []
## 允许的「滞涩」次数：出了没有推进接引的牌就 +1，超过即失败。
@export var max_missteps: int = 0

## 参考解，仅供自检测试使用。
@export var solution: Array[StringName] = []
