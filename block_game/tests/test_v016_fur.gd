extends SceneTree
## Тесты 0.16 — пушистые щенок и котик (scripts/hero.gd, мех): все окраски, оба пола, все вещи,
## касание, аватарки и маленькие значки рисуются без ошибок; мех считается один раз (кэш) и
## в следующих кадрах не перестраивается; на крошечных значках меха нет; совёнок и аксолотль без меха.
## 0.18: герои по умолчанию — картинки (scripts/hero_art.gd); мех есть только у рисунка кодом,
## поэтому здесь переключатель HeroArt.enabled выключен (проверяется запасной рисунок кодом).
## Запуск: godot --headless --path block_game -s tests/test_v016_fur.gd

var failed := 0
const Meta := preload("res://scripts/meta.gd")
const Hero := preload("res://scripts/hero.gd")
const HeroArt := preload("res://scripts/hero_art.gd")
const FURRY := ["puppy", "kitten"]
var frame := 0
var started := false


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3 or started:
		return false
	started = true
	_run()
	return false


## Ключи кэша меха (кайма, прядки, мех хвоста котика)
static func _fur_keys() -> Array:
	var out: Array = []
	for k in Hero._cache:
		if k is Array and k.size() > 0 and k[0] is String and (String(k[0]).begins_with("fur_") or String(k[0]).begins_with("str_") or k[0] == "kit_tail_fur"):
			out.append(k)
	return out


func _draw_pass(node: Node2D, step: int) -> Callable:
	return func():
		var h = Hero.new()
		var t := 1.7 + step * 0.83
		for kind in FURRY:
			var skins: Array = [""]
			for it in Meta.hero_items(kind):
				if it.slot == "skin":
					skins.append(it.id)
			for sk in skins:
				for g in ["boy", "girl"]:
					var base := {"gender": g}
					if sk != "":
						base["skin"] = sk
					for react in [99.0, 0.2, 0.6]:
						h.draw(node, kind, Vector2(360, 600), 1.0, base, t, react)
					h.draw(node, kind, Vector2(360, 600), 0.4, base, t, 99.0)   # аватарка средняя / дальний план
					h.draw(node, kind, Vector2(360, 600), 0.2, base, t, 99.0)   # крошечный значок — без меха
					for r in [74, 56, 20]:
						h.draw_avatar(node, kind, Vector2(200, 200), r, base, t, Color.WHITE, 0.4)
			if step == 0:
				# все вещи по одной и все сразу, оба пола
				for g in ["boy", "girl"]:
					var full := {"gender": g}
					for it in Meta.hero_items(kind):
						var o := {it.slot: it.id, "gender": g}
						h.draw(node, kind, Vector2(360, 600), 1.0, o, t, 0.3)
						h.draw(node, kind, Vector2(360, 600), 1.0, o, t, 0.3, true)
						Meta.put_on(full, it.id)
					h.draw(node, kind, Vector2(360, 600), 1.0, full, t, 0.5)
					h.draw(node, kind, Vector2(360, 600), 1.5, full, t, 99.0)   # как «картонка» в 3D-доме
					h.draw_avatar(node, kind, Vector2(200, 200), 80, full, t, Color.WHITE, 0.4)
		node.set_meta("drawn", step + 1)


func _run() -> void:
	print("— пушистые щенок и котик")
	HeroArt.enabled = false  # мех — только у рисунка кодом
	Hero._cache.clear()
	var node := Node2D.new()
	root.add_child(node)
	# совёнок и аксолотль — без меха
	var plain := func():
		var h = Hero.new()
		for kind in ["owl", "axolotl"]:
			h.draw(node, kind, Vector2(360, 600), 1.0, {}, 1.7, 0.3)
			h.draw(node, kind, Vector2(360, 600), 1.0, {"gender": "girl"}, 1.7, 99.0)
		node.set_meta("plain", true)
	node.draw.connect(plain)
	node.queue_redraw()
	for i in 4:
		await process_frame
	node.draw.disconnect(plain)
	if not node.has_meta("plain"):
		print("  (рисование в режиме без экрана пропущено)")
		quit(0)
		return
	check(_fur_keys().is_empty(), "у совёнка и аксолотля меха нет")

	var c0 := _draw_pass(node, 0)
	node.draw.connect(c0)
	node.queue_redraw()
	for i in 4:
		await process_frame
	node.draw.disconnect(c0)
	check(node.get_meta("drawn", 0) == 1, "все окраски, оба пола, касание, все вещи, аватарки — нарисованы без ошибок")
	var keys := _fur_keys()
	check(keys.size() > 20, "мех щенка и котика построен и закэширован (%d сеток)" % keys.size())
	var lod0 := keys.filter(func(k): return k[k.size() - 1] is int and k[k.size() - 1] == 0)
	check(lod0.is_empty(), "на крошечных значках меха нет (детализация 0 не строится)")
	var lods := {}
	for k in keys:
		if k[k.size() - 1] is int:
			lods[k[k.size() - 1]] = true
	check(lods.has(1) and lods.has(2), "две детализации меха: крупно — полная, на аватарках — реже и крупнее")

	# следующие кадры (другое время, касание) — мех не перестраивается
	var before := keys.size()
	var c1 := _draw_pass(node, 1)
	node.draw.connect(c1)
	node.queue_redraw()
	for i in 4:
		await process_frame
	node.draw.disconnect(c1)
	check(node.get_meta("drawn", 0) == 2, "второй кадр нарисован")
	check(_fur_keys().size() == before, "мех не перестраивается от кадра к кадру (%d → %d)" % [before, _fur_keys().size()])
	node.free()
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
