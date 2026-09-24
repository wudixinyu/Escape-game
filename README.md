# 解脱

一款 2D 休闲卡牌解谜。桌上摊着几张牌，你按某个顺序把它们一张张打出去，
顺序对了，桌上的东西就散了；顺序错了，桌上就再没有能出的牌。

水墨 + 禅意的皮，内核是一个纯数据的规则引擎：
**关卡里没有任何一行逻辑，只有「标记谁来、谁走」。**

- 引擎：Godot 4.7.2 stable（GDScript）
- 视口：1920 × 1080，卡牌与牌桌自适应
- 内容：6 关 / 48 张卡

---

## 玩法

一张牌在一局里只有四种处境：

| 状态 | 意思 | 牌面 |
| --- | --- | --- |
| `SEALED` 封印 | 条件没到，点不动 | 压暗，边框灰 |
| `OPEN` 可出 | 点击即出 | 提亮，边框银 |
| `PLAYED` 已出 | 留在桌上当记录 | 变灰，角标「已出」 |
| `LIBERATED` 解脱 | 条件到了，从桌上飘走 | 淡出上浮 |

出一张牌的结算就一句话：

> 出牌 → 投放/抹除标记 → 反复结算（解锁 + 解脱）→ 判定胜负

「反复结算」是关键：它会一直循环到没有牌的状态再变化为止，
所以「最后一张牌自己也散去」这种写法天然成立。

### 三种目标

关卡靠 `LevelData.goal` 切换，判定只在 `LiberationEngine.is_solved()` 一处：

| 目标 | 通关条件 |
| --- | --- |
| `RELEASE` 释放 | `goal_ids` 里的牌全部解脱 |
| `CLEAR` 清除 | 桌上每一张牌都解脱（迷途牌除外） |
| `GUIDE` 接引 | 迷途牌走完整条 `guide_route` |

接引型多两条规则：出的牌必须推进当前这一站，否则记一次「滞涩」；
滞涩超过 `max_missteps` 就散回雾里。

### 规则的表达方式：只有标记，没有分支

新增卡牌/关卡时照这张表填，不需要写一行逻辑：

| 字段 | 含义 |
| --- | --- |
| `starting` | 开局就在手边，可直接出 |
| `requires` | 这些标记**全部**在场，才从封印变可出 |
| `grants` | 出牌后投放这些标记（此外这张牌自己的 id 也自动成为一枚标记） |
| `clears` | 出牌后抹除这些标记 —— 给一次鲁莽留补救的余地 |
| `liberated_by` | 这些标记全在场时，这张牌解脱、从桌上消失 |
| `blocked_by` | 其中任一标记在场，就永远无法解脱 |

---

## 关卡

| # | 标题 | 目标 | 张数 | 想说的事 |
| --- | --- | --- | --- | --- |
| 1 | 解 封 | 释放 | 8 | 钥匙、油、光，缺一不可；撕符是最直接的一条错路，净露是留给鲁莽的第二次机会 |
| 2 | 度 尽 | 清除 | 7 | 每一张都要散去。「放」是最后一张，可它自己也留不住；静水必须留到手弄脏之后 |
| 3 | 引 渡 | 接引 | 7 | 三步送到渡口。雾里全是假的引路东西，多走一步雾就更浓 |
| 4 | 燃 犀 | 释放 | 7 | 「形」要光，「影」要暗 —— 单向门，熄灯之前得先把光底下该做的做完 |
| 5 | 澄 心 | 清除 | 10 | 有一张牌你根本点不着，它也照样会走。有些东西不必动手 |
| 6 | 问 津 | 接引 | 9 | 四步到渡口。喝过忘川不要紧，认回来就是 —— 只是余裕刚好用光 |

---

## 跑起来

编辑器直接打开项目即可（主场景 `res://Title.tscn`）。

命令行（引擎可执行文件默认在项目上两级，按实际位置改 `GODOT`）：

```bash
GODOT="D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
PROJ="D:/Godot_v4.7.2-stable_win64.exe/卡片游戏/解脱/解脱"

# 1. 改动脚本后先导入一次（否则 class_name 会报 not found，顺便检查语法）
"$GODOT" --headless --path "$PROJ" --import

# 2. 逻辑 + UI 自检（37 项，全过才退出码 0）
"$GODOT" --headless --path "$PROJ" --script res://tests/TestEngine.gd

# 3. 跑帧查运行期报错
"$GODOT" --headless --path "$PROJ" --quit-after 240
```

> 必须用 **console 版** 的引擎，普通版在 Windows 下不输出到 stdout。

导出：`export_presets.cfg` 里已配好 Windows Desktop。

---

## 目录

```
core/     纯规则，不碰任何节点
  CardData.gd          一张牌的全部规则字段（全是标记）
  LevelData.gd         一关的全部内容 + 三种目标
  LiberationEngine.gd  出牌 → 结算 → 判定，四个信号
levels/
  LevelLibrary.gd      关卡数据，唯一数据源，全是 Dictionary 配置
ui/
  CardView.gd/.tscn    一张牌的外观节点（根节点是 Control，不用 Area2D）
  CardArt.gd           卡面素材定位的唯一入口
  AppTheme.gd          字体 / 按钮样式 / 目标译名的唯一入口
  card_round_corners.gdshader   把任意比例的图统一裁成圆角
Main.gd / Main.tscn    牌桌 + HUD + 结算层
Title.gd / Title.tscn  主场景：入局 + 关卡清单
Game.gd                autoLoad：现在第几关、哪几关通了（内存态，不落盘）
tests/TestEngine.gd    无头自检
tools/                 素材流水线与截图脚本
assets/cards/<id>.png  卡面素材，同名覆盖即替换
assets/bg/table.png    桌面 / 主界面共用水墨背景
```

分工是硬的：`core/` 不知道 `ui/` 存在，`Main.gd` 里一行判定都没有。
UI 只监听 `changed / guide_moved / solved / deadlocked` 四个信号，做全量同步。

---

## 加一张卡 / 加一关

**加卡**：往 `assets/cards/` 丢一张 `<id>.png`，再在 `LevelLibrary` 里写一行
`_card(id, 名字, 描述, {...规则...})`。

**加关**：写一个返回 `LevelData` 的静态函数，挂进 `build()`。
关卡按钮、主界面清单、截图脚本都从 `Game.levels` 现读，不用改。

### 设计关卡时绕不开的四条硬事实

陷阱全靠它们，写之前先过一遍：

1. **OPEN 不可逆。** 一旦某张牌的 `requires` 满足过，就永远是可出状态，
   之后标记被 `clears` 抹掉也不会退回封印。
   所以「靠线索消失来封锁一张牌」是无效的 —— 封锁必须发生在它第一次满足之前。

2. **解脱不看状态。** `_settle()` 只跳过已解脱的牌，封印中的牌照样能被
   `liberated_by` 带走。这是「玩家碰不到但会自己散去」的牌（第五关「妄念」）成立的原因。

3. **`clears` 是一次性的。** 只在出牌那一刻把标记置 0。只要场上还有第二张牌能产出该标记，
   抹除就等于没抹。**想让顺序真的致命，就得让「收回 blocker」这件事没有第二张牌可做**
   （第四关的单向门就是这么做出来的）。

4. **死局在「无牌可出」那一刻才判。** 写「错序必死」的测试要把剩下的牌出完
   （tests 里的 `_exhaust()`），否则断言假阴性。

---

## 换美术

卡面：按卡 id 命名，丢进 `assets/cards/`，同名覆盖即可，代码一行都不用动。
规格建议 **512 × 768（2:3）**；素材按 `KEEP_ASPECT_COVERED` 铺满卡面，
比例差太多会裁掉边缘，主体别贴太靠边。方图也行，shader 会统一裁圆角。

背景：`assets/bg/table.png`，16:9。整体明暗不用重新出图，
调 `Main.tscn` 里 Veil 那层的 alpha 就行。

素材流水线：

```bash
python tools/make_placeholder_art.py          # 从 LevelLibrary 抓卡表重画占位图
python tools/make_placeholder_art.py --force  # 连已有图也重画（会冲掉真素材，慎用）
python tools/_pack_art.py                     # AI 生图的后处理：2:3 裁切 + 圆角 + 压暗
python tools/_pack_bg.py                      # 背景裁 16:9 + 压暗
```

原图备份在 `tools/_gen/`。`tools/SnapPreview.gd` 在真实渲染下截主界面 + 每一关。

---

## 自检

`tests/TestEngine.gd` 同时跑逻辑和 UI：

- 逻辑：每关开局有牌可出、参考解能通关、错序真的判死局、
  以及各关的补救路线（撕符后有净露、搅过之后能沉淀、喝过忘川能重新相认）
- UI：立起 `Main.tscn`，沿 `_on_card_clicked` 把每一关的参考解点一遍

当前 **37 项全过**。加关后先跑它 —— 它会替你确认参考解和死局都还在。

---

## 已知坑

- GDScript 的 lambda **按值捕获**：闭包里改的标志位外面读不到，信号要用成员方法接。
- `add_child` 只同步派 `ENTER_TREE`，`READY` 会塞进消息队列等下一帧。
  无头下不跑帧就断言，会得到「桌上没牌」。
- `await` 会把控制权还给调用者，调用处也要 `await` 住，否则提前跑到总结去了。
- autoLoad 的初始化放 `_init()`：`--script` 无头跑时 `_ready` 不一定被调用。
- anchor 的 `offset_top = -N` 是「从顶部上移 N」不是「距底 N」，贴底用 preset 12。
- `ceili()` / `floori()` 只有 1 参，除法取整要自己 `float(a) / float(b)`。
- const 不能用 `PackedStringArray(...)` 这类构造调用初始化（不是常量表达式），
  用数组字面量、在函数里再转。
- 中文界面必须显式指定系统字体（见 `ui/AppTheme.gd`），Godot 默认字体不含汉字。
