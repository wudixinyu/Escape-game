## 关卡内容集中在这里，全部是数据，没有逻辑。
##
## 想加一关就写一个返回 LevelData 的函数，再挂进 build()。
## 想要能在检查器里点着改，就把这里 build 出来的对象用 ResourceSaver 存成 .tres。
##
class_name LevelLibrary
extends RefCounted


static func build() -> Array[LevelData]:
	return [
		_level_01(),
		_level_02(),
		_level_03(),
		_level_04(),
		_level_05(),
		_level_06(),
	]


# ---------------------------------------------------------------- 第一关

## 释放型：桌上有一张被困住的牌，按顺序把锁链、油、光补齐，它才散去。
## 撕符是最直接的一条错路；净露是留给鲁莽的第二次机会。
static func _level_01() -> LevelData:
	var lv := _level("解  封", LevelData.Goal.RELEASE,
		"钥匙、油、光，缺一不可；顺序错了，被困的东西会先碎。")
	lv.goal_ids = _sg(["soul"])
	lv.cards = [
		_card("key", "铜  钥", "咔哒一声，锁舌退回半寸。", {"starting": true, "grants": ["启锁"]}),
		_card("chain", "封魔锁链", "一环扣一环，最脆的那一环通常在最里面。", {"requires": ["启锁"], "grants": ["链断"]}),
		_card("oil", "灯  油", "没有油，光是点不着的。", {"starting": true, "grants": ["油满"]}),
		_card("light", "灯  芯", "火苗窜起来的那一瞬，影子纷纷退场。", {"requires": ["链断", "油满"], "grants": ["照见"]}),
		_card("dark", "浓  夜", "它并不攻击，只是不肯让开。", {"requires": ["启锁"], "liberated_by": ["照见"]}),
		_card("soul", "被困之魂", "它等的是一个顺序，而不是一双迫切的手。", {
			"kind": CardData.Kind.GOAL,
			"requires": ["启锁"],
			"liberated_by": ["照见"],
			"blocked_by": ["符裂"],
		}),
		_card("talisman", "撕  符", "急躁的手扯下了符纸 —— 除非还有净露。", {"starting": true, "grants": ["符裂"]}),
		_card("water", "净  露", "清水洗过一次鲁莽，痕迹可以抹平。", {"requires": ["符裂"], "clears": ["符裂"]}),
	]
	lv.solution = _sg(["key", "chain", "oil", "light"])
	return lv


# ---------------------------------------------------------------- 第二关

## 清除型：桌上每一张都要散去。牌面诉述的是同一件事的下半段，
## 而「放」既是收尾，也是让所有牌一起消失的那枚标记。
## 陷阱在于：静水必须留到「缠 / 焚」出现之后才有用 —— 它先被用掉就再没有第二次。
static func _level_02() -> LevelData:
	var lv := _level("度  尽", LevelData.Goal.CLEAR,
		"桌上的每一张都要散去。「放」是最后一张，可它自己也留不住。")
	lv.cards = [
		_card("watch", "观", "先把它看清楚，才谈得上放下。", {"starting": true, "grants": ["观照"], "liberated_by": ["尽"]}),
		_card("regret", "悔", "承认自己来过。", {"requires": ["观照"], "grants": ["低头"], "liberated_by": ["尽"]}),
		_card("forgive", "恕", "它其实并不欠你。", {"requires": ["低头"], "grants": ["松手"], "liberated_by": ["尽"]}),
		_card("letgo", "放", "松开的那一刻，最后一张牌也跟着散了。", {
			"kind": CardData.Kind.GOAL,
			"requires": ["松手"],
			"grants": ["尽"],
			"liberated_by": ["尽"],
			"blocked_by": ["缠", "焚"],
		}),
		_card("anger", "怒", "烧得最快，也最早成灰。", {"starting": true, "grants": ["焚"], "liberated_by": ["尽"]}),
		_card("grasp", "执", "攥得越紧，桌面越满。", {"starting": true, "grants": ["缠"], "liberated_by": ["尽"]}),
		_card("still", "静  水", "回来看一眼盆里的水 —— 只在你把手弄脏之后才管用。", {
			"starting": true, "clears": ["缠", "焚"], "liberated_by": ["尽"],
		}),
	]
	lv.solution = _sg(["watch", "regret", "forgive", "letgo"])
	return lv


# ---------------------------------------------------------------- 第三关

## 接引型：迷途牌不认标记铺路，它只认「这张牌是不是当前这一站要的」。
## 出了不相干的牌就是一次「滞涩」，两次还能救回来，第三次雾就合拢了。
## guide_stops 只取 x（y 由 Main 的布局决定），是四站在桌面上的横坐标。
static func _level_03() -> LevelData:
	var lv := _level("引  渡", LevelData.Goal.GUIDE,
		"三步之内把它送到渡口。多走的每一步，雾都会更浓一点。")
	lv.goal = LevelData.Goal.GUIDE
	lv.guide_id = StringName("lost")
	lv.guide_route = _sg(["引", "照", "渡"])
	lv.guide_stops = [
		Vector2(40, 0), Vector2(560, 0), Vector2(1080, 0), Vector2(1600, 0),
	]
	lv.max_missteps = 2
	lv.cards = [
		_card("lost", "迷  魂", "它认得路，只是不敢先走。", {
			"kind": CardData.Kind.GUIDE,
			"requires": ["__never__"],
		}),
		_card("bell", "引  铃", "铃声只在前三步里有用。", {"starting": true, "grants": ["引"]}),
		_card("lantern", "提  灯", "光只照亮下一步。", {"requires": ["引"], "grants": ["照"]}),
		_card("boat", "渡  舟", "到了岸就不用再回头。", {"requires": ["照"], "grants": ["渡"]}),
		_card("coin", "买路钱", "雾不收银两。", {"starting": true, "grants": ["财"]}),
		_card("mirror", "妄  镜", "镜子里也有一个它在招手。", {"starting": true, "grants": ["妄"]}),
		_card("flame", "引路火", "在雾里点火，只照得见自己。", {"starting": true, "grants": ["灼"]}),
	]
	lv.solution = _sg(["bell", "lantern", "boat"])
	return lv


# ---------------------------------------------------------------- 第四关

## 释放型：一张单向的门 —— 灯点着就点着了，熄了就再也亮不起来。
##
## 形要靠光才照得见、才超度得了，可它一碰上「暗」便再也松不了口；
## 影则相反，非得等到灯灭之后循声去摸。
## 熄犀是全桌唯一能产出「暗」的牌，也唯一一次能把「明」抹掉的机会 ——
## 一旦先熄了灯，「照见 → 超度」这条链子就永远接不上（被锁死的 requires 不会再开），
## 而此时再回头点「燃犀」也来不及了：它虽然还能点着，可形已经被「暗」挡住，
## 且再没有第二张牌能把这个「暗」收回去。
##
## 所以正解是：先在光底下把「形」送走，再熄灯去摸「影」。顺序只有这一条。
static func _level_04() -> LevelData:
	var lv := _level("燃  犀", LevelData.Goal.RELEASE,
		"「形」要光，「影」要暗 —— 熄灯之前，先把光底下该做的事做完。")
	lv.goal_ids = _sg(["form", "shadow"])
	lv.cards = [
		_card("wax", "燃  犀", "犀角点着了，屋里照得纤毫毕现。", {"starting": true, "grants": ["明"]}),
		_card("see", "照  见", "看清了轮廓，才知道要超度的是谁。", {"requires": ["明"], "grants": ["见"]}),
		_card("rite", "超  度", "几句听不清的话，说完它就松了口。", {"requires": ["见"], "grants": ["释"]}),
		_card("form", "形", "它有轮廓，有重量，唯独不肯说话。", {
			"kind": CardData.Kind.GOAL,
			"requires": ["明"],
			"liberated_by": ["释"],
			"blocked_by": ["暗"],
		}),
		_card("douse", "熄  犀", "一捏就灭。点得着火的东西有很多，这一截犀角却只有一段。", {"starting": true, "clears": ["明"], "grants": ["暗"]}),
		_card("feel", "循  声", "看不见了，反倒听得真切。", {"requires": ["暗"], "grants": ["触"]}),
		_card("shadow", "影", "它不怕黑，只怕灯一直亮着。", {
			"kind": CardData.Kind.GOAL,
			"requires": ["明"],
			"liberated_by": ["触"],
			"blocked_by": ["明"],
		}),
	]
	lv.solution = _sg(["wax", "see", "rite", "douse", "feel"])
	return lv


# ---------------------------------------------------------------- 第五关

## 清除型：桌上每一张都要散去，其中一张你根本碰不到。
## 「妄念」写着一条永远满足不了的 requires，所以它永远是封印状态、点不出来 ——
## 但它照样会解脱，只要条件到了。这一关想说的是：有些东西不必动手。
## 「搅」是唯一会坏事的牌：搅过之后妄念就赖着不走，得让「沉淀」把那一下抹平。
static func _level_05() -> LevelData:
	var lv := _level("澄  心", LevelData.Goal.CLEAR,
		"每一张都要散去。有一张你点不着 —— 它不必你出手，自然会走。")
	lv.cards = [
		_card("brush", "扫  帚", "扫过一遍，浮尘也就跟着散了。", {"starting": true, "grants": ["净"], "liberated_by": ["尽心"]}),
		_card("dust", "积  尘", "它自己不会走，可也不必你去碰它。", {"starting": true, "liberated_by": ["净"]}),
		_card("pour", "一  瓢", "水倒下去就没打算再收回来。", {"starting": true, "grants": ["湿"], "liberated_by": ["尽心"]}),
		_card("stain", "陈  渍", "扫不掉的那些，得先让它湿一湿。", {"requires": ["湿"], "liberated_by": ["拭"]}),
		_card("cloth", "拭  布", "擦到听见布面发涩的声音为止。", {"requires": ["湿"], "grants": ["拭"], "liberated_by": ["尽心"]}),
		_card("sit", "净  坐", "尘扫了，渍擦了，才坐得住。坐下之后，屋里就空了。", {"requires": ["净", "拭"], "grants": ["尽心"], "liberated_by": ["尽心"]}),
		_card("curse", "妄  念", "它不在手边，也不听使唤 —— 你拿它毫无办法，它只是最后才肯走。", {"requires": ["__never__"], "liberated_by": ["尽心"], "blocked_by": ["搅"]}),
		_card("fold", "叠  衣", "顺手叠好。做与不做都行，只是做完了屋子更空。", {"starting": true, "grants": ["齐"], "liberated_by": ["尽心"]}),
		_card("stir", "搅", "手贱搅一下，水就再也静不下来了。", {"starting": true, "grants": ["搅"], "liberated_by": ["尽心"]}),
		_card("settle", "沉  淀", "什么都不做，等它自己落下去。", {"requires": ["搅"], "clears": ["搅"], "liberated_by": ["尽心"]}),
	]
	lv.solution = _sg(["brush", "pour", "cloth", "sit"])
	return lv


# ---------------------------------------------------------------- 第六关

## 接引型：比第三关多一站，容错也更薄（只有两次滞涩）。
## 「忘川」会把「认」抹掉 —— 关键在「渡舟」要背着两样东西才肯开：
## 船资，和一个你认得的人。在它开口之前把「认」抹了，就得再花一步把它认回来，
## 两步滞涩刚好用光容错。诱饵还是老样子：雾里的图和无主的曲子。
static func _level_06() -> LevelData:
	var lv := _level("问  津", LevelData.Goal.GUIDE,
		"四步送到渡口。喝过忘川不要紧 —— 认回来就是了，只是没多少余裕了。")
	lv.guide_id = StringName("pilgrim")
	lv.guide_route = _sg(["唤", "认", "资", "渡"])
	lv.max_missteps = 2
	lv.cards = [
		_card("pilgrim", "迷  津", "它在对岸看得见你，只是不肯先开口。", {
			"kind": CardData.Kind.GUIDE,
			"requires": ["__never__"],
		}),
		_card("call", "唤  名", "先叫对了名字，它才肯回头。", {"starting": true, "grants": ["唤"]}),
		_card("know", "相  认", "看清了脸，才谈得上同行。", {"requires": ["唤"], "grants": ["认"]}),
		_card("fare", "渡  资", "认得出人才肯收钱，认不出的给再多也不收。", {"requires": ["认"], "grants": ["资"]}),
		_card("ferry", "渡  舟", "上船要凭两样东西：钱，和一个你认得的人。", {"requires": ["资", "认"], "grants": ["渡"]}),
		_card("forget", "忘  川", "喝一口就什么都不记得了 —— 好在忘得不算彻底。", {"starting": true, "clears": ["认"]}),
		_card("recall", "重  相  识", "再看一眼那张脸，居然还是想起来的。", {"requires": ["唤"], "grants": ["认"]}),
		_card("chart", "水  路  图", "画得清清楚楚，可惜这里没有水。", {"starting": true, "grants": ["图"]}),
		_card("song", "招  魂  曲", "唱得太响，来的多半不是要找的那个。", {"starting": true, "grants": ["曲"]}),
	]
	lv.solution = _sg(["call", "know", "fare", "ferry"])
	return lv


# ---------------------------------------------------------------- 工具

static func _level(title: String, goal: LevelData.Goal, intro: String) -> LevelData:
	var lv := LevelData.new()
	lv.title = title
	lv.goal = goal
	lv.intro = intro
	return lv


static func _card(id: String, name_: String, desc: String, o: Dictionary = {}) -> CardData:
	var c := CardData.new()
	c.id = StringName(id)
	c.display_name = name_
	c.description = desc
	c.starting = o.get("starting", false)
	c.kind = o.get("kind", CardData.Kind.COMMON)
	c.requires = _sg(o.get("requires", []))
	c.grants = _sg(o.get("grants", []))
	c.clears = _sg(o.get("clears", []))
	c.liberated_by = _sg(o.get("liberated_by", []))
	c.blocked_by = _sg(o.get("blocked_by", []))
	return c


static func _sg(src: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for x in src:
		out.append(StringName(x))
	return out
