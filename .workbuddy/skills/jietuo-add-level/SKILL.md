---
name: jietuo-add-level
description: 给「解脱」卡牌解谜（Godot 4.7.2）新增或修改关卡时使用。涵盖标记系统的设计约束、三种目标型的机关套路、占位素材生成、无头自检与真实渲染截图的完整流程。当用户说「加一关 / 再加几关 / 改一下第 N 关 / 关卡太难了」时触发。
agent_created: true
---

# 给「解脱」加关卡

工作区：`D:\Godot_v4.7.2-stable_win64.exe\卡片游戏\解脱\解脱`
引擎：上一级的 `Godot_v4.7.2-stable_win64_console.exe`（必须 console 版，否则没有 stdout）

## 铁律

**所有关卡都是数据，不要动 `core/`。** 加一关 = 在 `levels/LevelLibrary.gd` 写一个
`_level_0N()` 返回 `LevelData`，再挂进 `build()`。规则引擎里一行都不用改；
`Title.gd`（关卡清单）、`Main.gd`（底栏数字按钮）、`Game.gd`、测试与截图脚本全是按
`Game.levels.size()` 现读的，加关即自动生效。

## 先读这一节：标记系统的四条硬事实

设计陷阱全靠它们，写之前先想清楚哪条能用：

1. **OPEN 不可逆** —— 某张牌的 `requires` 满足过一次，它就永远可出；之后标记被 `clears`
   抹掉也不会退回封印。所以「靠线索消失封锁一张牌」无效。
2. **解脱不看状态** —— `_settle()` 只跳过已 LIBERATED 的牌，封印中的牌照样会被 `liberated_by`
   带走。「玩家点不到但会自己散去的牌」就靠这个：`requires: ["__never__"]` + `liberated_by: [...]`。
3. **`clears` 是一次性的** —— 只在出牌那一刻把标记置 0。**只要场上还有第二张能产出该标记的牌，
   抹除就等于没抹。** 想让顺序真正致命，必须让「收回 blocker」没有第二张牌可做。
4. **死局在「无牌可出」那一刻才判** —— 测试里断言「错序会死」之前要把剩下的牌出完
   （`tests/TestEngine.gd` 里的 `_exhaust()`），否则是假阴性。

另一个藏坑：**打出任意一张牌时，它自己的 id 也会成为一枚标记**。所以
`{"liberated_by": ["<自己的 id>"]}` 就是「打出即散去」的自解牌，写的时候要注释说明，否则很费解。

## 三种目标型各自的机关套路

| goal | 判定 | 好用的机关 |
| --- | --- | --- |
| `RELEASE` | `goal_ids` 全部解脱 | 双目标互斥 + 单向门：唯一的光源 + 唯一能把光抹掉的牌，正解必须先用光做完 A 再熄灯做 B |
| `CLEAR` | 桌上全部解脱（迷途牌除外） | 单次资源（先用掉就再没有第二次）+ 一张碰不到的牌 + 其余杂牌统一 `liberated_by: ["终局标记"]` 一起散场 |
| `GUIDE` | 迷途牌走完 `guide_route` | 站点标记被 `clears` 抹掉 → 要靠「再认一次」补回来；滞涩数就是容错预算，绕路成本要正好等于或略小于 `max_missteps` |

接引型注意：`advance` 只看**当前打出的这张牌是否 grants 了当前站的标记**，
所以正解路线上不应该混进不推进的牌 —— 否则正常通关也会吃滞涩。纯诱饵牌
（`grants` 一个没人用的标记）是安全且必要的，每关放 2~3 张。

## 流程

```powershell
# 0. 环境（本机 bash 缺 coreutils，用 PowerShell 跑）
$godot = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$py    = "D:\Users\63446\AppData\Local\Programs\Python\Python313\python.exe"   # 系统 Python 有 Pillow，托管那个没有

# 1. 写关卡数据（LevelLibrary.gd）
# 2. 补占位卡面（正则抓卡表，已有的真素材不会被覆盖）
& $py tools/make_placeholder_art.py
# 3. 先导入，否则 class_name 报 not found
& $godot --headless --import
# 4. 逻辑 + UI 自检（UI 段会沿参考解把每一关点一遍）
& $godot --headless --script res://tests/TestEngine.gd
# 5. 查运行期报错
& $godot --headless --quit-after 240
# 6. 真实渲染截图（会短暂开窗），产出 tools/preview_*.png
& $godot --script res://tools/SnapPreview.gd
```

PowerShell 有时不返回 Godot 的 stdout。**惯用解法：`| Out-File -FilePath .workbuddy\x.log -Encoding utf8` 再读文件**
（直接用 `>` 会写成 UTF-16，读不了）。筛日志时只留 `^\[FAIL\]|^----` 就够看。

## 新增关卡时同步改测试

`tests/TestEngine.gd` 的 `_run_logic()` 会自动覆盖「有牌开局 / 参考解通关」两项，
但**机关本身的定向用例要手写**。每组用例至少三条断言，别只测参考解：

- 错序 → `_exhaust()` 之后 `_dead != ""` 且 `not _solved`；
- 关键牌的状态正确（该解脱的解了、不该解脱的没解）；
- 补救路线真的能救回来，并且滞涩数等计数符合预期。

## 验收标准

- `--import` 无报错；`TestEngine` 全绿（当前 37 项）；`--quit-after 240` 无 ERROR/WARNING；
- 截图里每一关都排得开：桌面能放下的列数由 `_relayout()` 现算，**留意手牌总数和每行列数的关系**
  （1920 宽一列放 8 张，9 张会甩一张到第二排、单卡一排很难看；要么凑成 10 张排 8+2，
  要么删到 8 张一排）；
- 新卡的 `assets/cards/<id>.png` 都在，`CardArt` 不再报「找不到卡面素材」。
