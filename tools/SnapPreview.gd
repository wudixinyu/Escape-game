extends SceneTree

## 临时截图：真实渲染器下把主界面和每一关各截一张，确认素材与布局。
## 关卡数从 Game.levels 现读，加关不用改这里。

func _initialize() -> void:
	_snap()


func _save(name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://tools/")
	root.get_texture().get_image().save_png(dir + "preview_%s.png" % name)
	print("saved %s" % name)


func _settle() -> void:
	await process_frame
	await process_frame


func _snap() -> void:
	var title: Node = (load("res://Title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await _settle()
	_save("title")
	title.queue_free()

	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()

	var count: int = (root.get_node("Game") as Node).get("levels").size()
	for i in count:
		root.get_node("Game").goto(i)
		await _settle()
		_save("level_%d" % (i + 1))

	quit()
