# MEMORY.md

## 项目：「解脱」卡牌解谜（Godot 4.7.2）

工作区：`D:\Godot_v4.7.2-stable_win64.exe\卡片游戏\解脱\解脱`
引擎可执行文件在同级的 `Godot_v4.7.2-stable_win64_console.exe`（必须用 console 版才有 stdout）。

### 玩法定位
出牌顺序 + 2D + 休闲解谜。核心概念「解脱」= 关卡终点，不是「赢」，是「解开」。

### 目录约定
- `core/` —— 纯规则，不碰节点：`CardData`、`LevelData`、`LiberationEngine`
- `ui/` —— `CardView`（根节点 Control，不用 Area2D）；`CardArt.gd` 是卡面素材定位的唯一入口
- **`ui/AppTheme.gd` 是字体/按钮样式/关卡目标译名的唯一入口**，Main 和 Title 共用
- **`Title.tscn` 是主场景（run/main_scene）**：入局 + 关卡清单（现读 Game.levels/cleared）；Main 底栏「主界面」切回
- **`ui/CardView.gd` 的 `SIZE` 是卡尺寸唯一入口（现为 200x300）**：排布、Sheet 高度、字号都从它派生，换视口/换尺寸只改这一处
- `Main._relayout()` 自适应：列数按桌宽现算、整桌居中；guide_stops 只取 x，y 由布局定
- `assets/cards/<卡id>.png` —— 卡面素材，同名覆盖即替换，当前规格 512x768（2:3），方图也行（shader 会裁圆角，素材按 COVERED 铺满）
- `assets/bg/table.png` —— 桌面/主界面共用水墨背景；压暗走 Main.tscn 的 Veil 层 alpha
- `tools/make_placeholder_art.py` —— 从 LevelLibrary 抓卡表重画占位素材（--force 才覆盖已有图）
- `tools/_pack_art.py` / `_pack_bg.py` —— AI 生图的后处理（裁切/圆角/压暗→写进 assets/）；原图备份在 tools/_gen/
- `tools/SnapPreview.gd` —— 真实渲染下截主界面 + 每一关画面（非 headless 跑；关卡数从 Game.levels 现读）
- `levels/LevelLibrary.gd` —— 关卡数据，唯一数据源，全是 Dictionary 配置，无逻辑
- `tests/TestEngine.gd` —— 无头自检（16 项）
- `Game.gd` —— autoLoad（`level_changed` 信号 + 关卡进度，内存态不落盘）

### 规则表达方式（新增卡牌/关卡时照这套走）
全部用「标记 tag」表达，不写逻辑分支：

| 字段 | 含义 |
| --- | --- |
| `starting` | 开局可出 |
| `requires` | 全部满足才从封印变可出 |
| `grants` | 出牌后投放（自身 id 自动成为一枚标记） |
| `clears` | 出牌后抹除（给鲁莽留补救） |
| `liberated_by` | 满足即从桌上消失 |
| `blocked_by` | 任一在场则永不可解脱 |

三种目标靠 `LevelData.goal` 切换，判定只在 `LiberationEngine.is_solved()`：
`RELEASE` 释放型 / `CLEAR` 清除型 / `GUIDE` 接引型。

### 设计关卡时绕不开的四条硬事实（设计陷阱全靠它们）
1. **OPEN 不可逆**：一旦某张牌的 requires 满足过，就永远是可出状态，之后标记被 `clears` 抹掉也不会退回封印。
   所以「靠线索消失来封锁一张牌」是无效的，封锁必须在它第一次满足之前发生。
2. **解脱不看状态**：`_settle()` 只跳过已 LIBERATED，封印中的牌照样可以被 `liberated_by` 带走 ——
   这是「玩家碰不到但会自己散去」的牌（第五关「妄念」）成立的原因。
3. **`clears` 是一次性的**：只在出牌那一刻把标记置 0。只要场上存在第二张能产出该标记的牌，抹除就等于没抹。
   **想让顺序真的致命，就必须让「收回 blocker」这件事没有第二张牌可做**（第四关的单向门）。
4. **死局在「无牌可出」时才判**：写「错序必死」的测试要把还剩的牌出完（tests 里的 `_exhaust()`），
   否则断言假阴性。

### 常用命令
```bash
# 1. 新增/改动脚本后先导入一次（否则所有 class_name 报 not found，并顺便检查语法）
"...console.exe" --headless --import 2>&1 | tail -n 30
# 2. 逻辑 + UI 自检（16 项）
"...console.exe" --headless --script res://tests/TestEngine.gd
# 3. 跑帧查运行期报错
"...console.exe" --headless --quit-after 240
```

### 已知坑（详见 skill: godot-headless-smoke-test）
GDScript lambda 按值捕获；`add_child` 的 READY 延后一帧；`await` 会把控制权还给调用者；
autoLoad 初始化放 `_init()`；
anchor 的 `offset_top=-N` 是「从顶部上移 N」不是「距底 N」，贴底用 preset 12；
`ceili()`/`floori()` 只有 1 参，除法取整要自己 `float(a)/float(b)`；
const 不能用 `PackedStringArray(...)` 等构造调用初始化（非常量表达式），用数组字面量再在函数里转。
