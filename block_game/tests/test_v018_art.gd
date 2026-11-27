extends SceneTree
## Тесты 0.18 — нарисованные герои и гардероб (scripts/hero_art.gd):
##   картинки есть у всех героев, обликов, окрасов и поз (и у Мастера Уха); у всех вещей каталога
##   (кроме окрасов) есть слой посадки или значок; копии anchors.json / fit.json в assets совпадают с art_src;
##   сборка наряда не падает на всех «полных наборах» × поза, план сборки кэшируется;
##   посадка совпадает с эталонной сборкой art_src/wardrobe/compose.py (tests/data/fit_ref_*.png,
##   делает art_src/wardrobe/make_test_refs.py) с допуском;
##   позы героя у поля по событиям; переключатель HeroArt.enabled возвращает рисунок кодом;
##   картонка 3D-дома собирается один раз, а не каждый кадр.
## Запуск: godot --headless --path block_game -s tests/test_v018_art.gd

var failed := 0
var frame := 0
var started := false
const Meta := preload("res://scripts/meta.gd")
const Hero := preload("res://scripts/hero.gd")
const HeroArt := preload("res://scripts/hero_art.gd")
const PlayHero := preload("res://scripts/play_hero.gd")
const HeroCard := preload("res://scripts/home3d/hero_card.gd")

## Те же наряды, что в art_src/wardrobe/make_test_refs.py
const CASES := [
	["kitten", "happy", "boy", "", ["ki_feather_hat", "ki_bell_bow", "ki_yarn", "ki_trench"]],
	["axolotl", "idle", "girl", "ax_skin_pearl", ["ax_starfish", "ax_porthole", "ax_gill_pearls", "ax_shell_pack"]],
	["owl", "wow", "boy", "ow_skin_snowy", ["ow_halfglasses", "ow_book", "ow_stargazer"]],
	["puppy", "sad", "girl", "", ["pu_daisy_specs", "pu_flower_scarf", "pu_jetpack", "pu_robo"]],
]


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


func _skins(kind: String) -> Array:
	var out: Array = [""]
	for it in Meta.items_in("skin", kind):
		out.append(it.id)
	return out


func _run() -> void:
	HeroArt.enabled = true
	_test_files()
	_test_plans()
	_test_compose()
	_test_poses()
	await _test_drawing()
	await _test_card()
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


# ---------- Файлы ----------

func _test_files() -> void:
	print("— картинки и данные")
	for pair in [["res://assets/heroes_art/anchors.json", "res://art_src/heroes/anchors.json"], ["res://assets/wardrobe_art/fit.json", "res://art_src/wardrobe/fit.json"]]:
		var a := FileAccess.get_file_as_string(pair[0])
		var b := FileAccess.get_file_as_string(pair[1])
		check(a != "" and (b == "" or a == b), "%s есть и совпадает с копией в art_src" % pair[0])
	var miss: Array = []
	var n := 0
	for kind in Meta.HEROES:
		for gender in ["boy", "girl"]:
			for sk in _skins(kind):
				for pose in HeroArt.POSES:
					var key := HeroArt.hero_key(kind, pose, gender, sk)
					n += 1
					if not ResourceLoader.exists(HeroArt.hero_path(key)) or HeroArt.anchors(key).is_empty():
						miss.append(key)
	check(miss.is_empty() and n == 4 * 2 * 5 + 2 * 5 * (2 + 2 + 3 + 2), "у всех героев, обликов, окрасов и поз есть картинка и точки (%d)%s" % [n, "" if miss.is_empty() else ": нет " + str(miss)])
	var mm: Array = []
	for pose in HeroArt.MASTER_POSES:
		var key := HeroArt.hero_key("master", pose)
		if not ResourceLoader.exists(HeroArt.hero_path(key)) or HeroArt.anchors(key).is_empty():
			mm.append(key)
	check(mm.is_empty(), "Мастер Ух: talk, happy, forge — картинки есть")
	var bad: Array = []
	var no_icon: Array = []
	for it in Meta.ITEMS:
		var ic := ResourceLoader.exists(HeroArt.icon_path(it.hero, it.id))
		if not ic:
			no_icon.append(it.id)
		if it.slot == "skin":
			continue
		var fi := HeroArt.fit_item(it.id)
		var layers_ok: bool = not fi.is_empty() and not fi.get("layers", []).is_empty()
		for L in fi.get("layers", []):
			if not ResourceLoader.exists(HeroArt.layer_path(it.hero, L.file)):
				layers_ok = false
		if not layers_ok and not ic:
			bad.append(it.id)
	check(bad.is_empty(), "у всех вещей каталога (кроме окрасов) есть слой посадки или значок%s" % ("" if bad.is_empty() else ": нет " + str(bad)))
	check(no_icon.is_empty(), "у всех вещей и окрасов есть значок карточки (icons/)%s" % ("" if no_icon.is_empty() else ": нет " + str(no_icon)))


# ---------- План сборки ----------

func _test_plans() -> void:
	print("— сборка нарядов")
	var ok := true
	var n := 0
	var all_layers := true
	for kind in Meta.HEROES:
		# полный набор: все вещи по очереди (супер-награда снимает часть слотов) и без супер-награды
		var full := {}
		var plain := {}
		for it in Meta.hero_items(kind):
			if it.slot == "skin":
				continue
			Meta.put_on(full, it.id)
			if not it.has("covers"):
				Meta.put_on(plain, it.id)
		var sets: Array = [full, plain]
		for it in Meta.hero_items(kind):
			sets.append({it.slot: it.id})
		for gender in ["boy", "girl"]:
			for sk in _skins(kind):
				for pose in HeroArt.POSES:
					for o in sets.slice(0, 2):
						var oo: Dictionary = o.merged({"gender": gender})
						if sk != "":
							oo["skin"] = sk
						var p := HeroArt.plan(kind, oo, pose)
						n += 1
						if p.is_empty():
							ok = false
						elif not p.missing.is_empty() or p.front.size() + p.behind.size() == 0:
							all_layers = false
			for o in sets.slice(2):
				var p := HeroArt.plan(kind, o.merged({"gender": gender}), "idle")
				n += 1
				if p.is_empty():
					ok = false
	check(ok, "сборка не падает: 4 героя × 2 облика × все окрасы × 5 поз × полный набор (и по одной вещи) — %d планов" % n)
	check(all_layers, "в полных наборах у каждой вещи есть слои (ничего не рисуется кодом вместо картинки)")
	var b0 := HeroArt.plans_built
	var o := {"head": "ki_pompom_hat", "neck": "ki_bell_bow", "gender": "girl"}
	var p1 := HeroArt.plan("kitten", o, "idle")
	var p2 := HeroArt.plan("kitten", o.duplicate(), "idle")
	check(p1 == p2 and HeroArt.plans_built == b0 + 1, "план наряда кэшируется: повторный вызов не пересчитывает")
	HeroArt.plan("kitten", o, "happy")
	check(HeroArt.plans_built == b0 + 2, "другая поза — свой план")
	var t1 := HeroArt.tex(HeroArt.hero_path("kitten/boy_base_idle"))
	check(t1 != null and t1 == HeroArt.tex(HeroArt.hero_path("kitten/boy_base_idle")), "текстура загружается один раз (кэш)")
	# порядок слоёв: позади -> герой -> спереди, по order
	var p3 := HeroArt.plan("kitten", {"back": "ki_trench", "head": "ki_feather_hat"}, "idle")
	check(p3.behind.size() == 1 and p3.front.size() == 2, "плащ — позади героя, лацканы и шляпа — спереди")
	var Ls := HeroArt.layers_for(["ki_starry"], "girl")
	check(Ls.size() == 2 and Ls[0].z == "behind" and Ls[1].file == "ki_starry_tiara", "слой только для облика: у кошечки — диадема (у кота — корона)")
	check(HeroArt.layers_for(["ki_starry"], "boy")[1].file == "ki_starry_crown", "у кота — корона")


# ---------- Сравнение с compose.py ----------

func _test_compose() -> void:
	print("— посадка = compose.py")
	for i in CASES.size():
		var c: Array = CASES[i]
		var ref := Image.new()
		ref.load_png_from_buffer(FileAccess.get_file_as_bytes("res://tests/data/fit_ref_%d.png" % i))
		if ref.is_empty():
			check(false, "эталон tests/data/fit_ref_%d.png есть" % i)
			continue
		ref.convert(Image.FORMAT_RGBA8)
		var t0 := Time.get_ticks_msec()
		var mine := HeroArt.compose_image(c[0], c[1], c[4], c[2], c[3])
		var ms := Time.get_ticks_msec() - t0
		if mine == null:
			check(false, "%s: сборка в Image" % c[0])
			continue
		var res := _compare(mine, ref)
		var dsize := (mine.get_size() - ref.get_size()).abs()
		check(dsize.x <= 3 and dsize.y <= 3 and res[0] < 0.035 and res[1] > 0.96,
			"%s %s %s: совпадает с compose.py — размер %s/%s, средняя разница %.4f, совпадение силуэта %.3f (%d мс)" % [c[0], c[1], c[2], mine.get_size(), ref.get_size(), res[0], res[1], ms])


## [средняя разница цвета с учётом прозрачности, IoU силуэта] при лучшем сдвиге ±1 px
func _compare(a: Image, b: Image) -> Array:
	var best := [1.0, 0.0]
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var diff := 0.0
			var cnt := 0
			var inter := 0
			var uni := 0
			for y in range(2, h - 2, 3):
				for x in range(2, w - 2, 3):
					var ca := a.get_pixel(x, y)
					var cb := b.get_pixel(x + dx, y + dy)
					var ia := ca.a > 0.5
					var ib := cb.a > 0.5
					if ia or ib:
						uni += 1
						if ia and ib:
							inter += 1
					if ca.a > 0.02 or cb.a > 0.02:
						var m := maxf(ca.a, cb.a)
						diff += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0 * m + absf(ca.a - cb.a)
						cnt += 1
			var r := [diff / maxi(cnt, 1), float(inter) / maxi(uni, 1)]
			if r[0] < best[0]:
				best = r
	return best


# ---------- Позы героя у поля ----------

func _test_poses() -> void:
	print("— позы героя у поля")
	var ph = PlayHero.new()
	check(ph.pose() == "idle", "обычно — idle")
	ph.on_cascade(2)
	check(ph.pose() == "wow", "каскад ×2 — wow")
	ph.reset()
	ph.on_cascade(3)
	check(ph.pose() == "happy", "каскад ×3 — happy")
	ph.reset()
	ph.on_crystal()
	check(ph.pose() == "wow", "кристалл — wow")
	ph.update(PlayHero.WOW_TIME + 0.1, false)
	check(ph.pose() == "idle", "после «Ого!» — снова idle")
	ph.update(1.0, true)
	check(ph.pose() == "worried", "поле почти полное — worried")
	ph.reset()
	ph.on_win()
	check(ph.pose() == "happy", "победа — happy")
	ph.reset()
	ph.on_lose()
	check(ph.pose() == "sad", "поражение — sad")


# ---------- Рисование и переключатель ----------

func _test_drawing() -> void:
	print("— рисование (картинки и запасной рисунок кодом)")
	var node := Node2D.new()
	root.add_child(node)
	var res := {}
	node.draw.connect(func():
		var h = Hero.new()
		for art in [true, false]:
			HeroArt.enabled = art
			for kind in Meta.HEROES:
				var full := {"gender": "girl"}
				for it in Meta.hero_items(kind):
					Meta.put_on(full, it.id)
					h.draw_item_icon(node, it.id, it.slot, kind, Vector2(100, 100), 120, 1.0, "girl")
				for pose in HeroArt.POSES:
					h.draw(node, kind, Vector2(360, 600), 1.0, full, 1.3, 99.0, false, pose)
				h.draw_avatar(node, kind, Vector2(200, 200), 60, full, 1.0, Color.WHITE)
				h.draw_item_icon(node, "", "skin", kind, Vector2(100, 100), 120, 1.0)
			h.draw_master(node, Vector2(100, 300), 0.56, 1.0)
			h.draw_master(node, Vector2(100, 300), 0.56, 1.0, 0.2, "forge")
			res[art] = true
		HeroArt.enabled = true)
	node.queue_redraw()
	for i in 4:
		await process_frame
	if res.is_empty():
		print("  (рисование в режиме без экрана пропущено)")
	else:
		check(res.has(true) and res.has(false), "все герои, позы, аватарки, значки и Мастер Ух — нарисованы картинками и (переключатель выкл.) кодом без ошибок")
	HeroArt.enabled = false
	check(HeroArt.plan("owl", {}, "idle").is_empty() and not HeroArt.available("owl", {}), "переключатель выключен — нарисованного героя нет, рисуется кодом")
	HeroArt.enabled = true
	check(not HeroArt.available("owl", {"skin": "_unknown"}), "неизвестный окрас без картинки — рисунок кодом")
	node.free()


# ---------- Картонка 3D-дома ----------

func _test_card() -> void:
	print("— картонка 3D-дома")
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var card = HeroCard.new()
	card.kind = "kitten"
	card.outfit = {"head": "ki_pompom_hat", "neck": "ki_bell_bow"}
	card.size = 256
	vp.add_child(card)
	for i in 10:
		await process_frame
	var r1: int = card.renders
	for i in 10:
		await process_frame
	var r2: int = card.renders
	if r1 == 0:
		print("  (рисование в режиме без экрана пропущено)")
	else:
		check(r2 == r1 and vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "без касаний и смены наряда картинка не пересобирается (собрана %d раз за 20 кадров)" % r2)
		card.outfit = {"head": "ki_feather_hat"}
		for i in 3:
			await process_frame
		check(card.renders == r2 + 1, "смена наряда — картинка собрана заново один раз")
		card.poke()
		for i in 3:
			await process_frame
		check(card.renders == r2 + 2, "касание — поза happy, картинка собрана один раз")
	vp.queue_free()
	await process_frame
