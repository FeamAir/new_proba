extends SceneTree
## Тесты 0.18 — посадка вещей на нарисованного героя НЕ зависит от размера экрана, масштаба рисования
## и способа запуска (баг с телефона: «ожерелье на животе, очки на лбу, наряды внутри героя»).
##   1) текстуры в игре (импорт: lossy WebP, мипмапы) того же размера и пропорций, что исходные картинки;
##   2) геометрия слоёв относительно героя (углы каждой вещи в пикселях картинки героя) одинакова
##      при масштабах 405×720, 720×1280, 1080×2340, 1440×3120 и разных размерах окна,
##      и совпадает с art_src/wardrobe/compose.py (place + pivot + поворот + отражение);
##   3) сборка «как в игре» — по ИМПОРТИРОВАННЫМ текстурам (то, что получает видеокарта) и матрицам плана —
##      при разных масштабах совпадает с эталонной сборкой compose_image (= compose.py), уменьшенной так же.
## Запуск: godot --headless --path block_game -s tests/test_v018_fit_scale.gd

var failed := 0
var frame := 0
var started := false
const Meta := preload("res://scripts/meta.gd")
const HeroArt := preload("res://scripts/hero_art.gd")

## Масштабы рисования: ширина экрана / 720 (405, 720, 1080, 1440 px)
const SCALES := [0.5625, 1.0, 1.5, 2.0]
## Наряды: эталонные (как tests/data/fit_ref_*) + вещи из жалобы владельца (ожерелья, очки, плащи)
const CASES := [
	["kitten", "happy", "boy", "", ["ki_feather_hat", "ki_bell_bow", "ki_yarn", "ki_trench"]],
	["axolotl", "idle", "girl", "ax_skin_pearl", ["ax_starfish", "ax_porthole", "ax_gill_pearls", "ax_shell_pack"]],
	["owl", "wow", "boy", "ow_skin_snowy", ["ow_halfglasses", "ow_book", "ow_stargazer"]],
	["puppy", "sad", "girl", "", ["pu_daisy_specs", "pu_flower_scarf", "pu_jetpack", "pu_robo"]],
	["kitten", "idle", "girl", "", ["ki_feather_hat", "ki_cameo", "ki_ball_cloak"]],
	["owl", "idle", "boy", "", ["ow_halfglasses", "ow_scholar_scarf"]],
	["axolotl", "happy", "boy", "", ["ax_dive_mask", "ax_pearls", "ax_wave_cape"]],
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


func _run() -> void:
	HeroArt.enabled = true
	HeroArt.clear_cache()
	_test_sizes()
	_test_geometry()
	_test_window()
	_test_raster()
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)


func _outfit(c: Array) -> Dictionary:
	var o := {"gender": c[2], "skin": c[3]}
	for id in c[4]:
		Meta.put_on(o, id)
	return o


## Размер исходной картинки (файл .webp проекта, как его видит compose.py)
func _src_size(path: String) -> Vector2:
	var img := Image.new()
	if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return Vector2.ZERO
	return Vector2(img.get_size())


# ---------- 1. Размер текстур в игре = исходные картинки ----------

func _test_sizes() -> void:
	print("— текстуры в игре того же размера, что исходные картинки")
	var bad: Array = []
	var n := 0
	var paths: Array = []
	for kind in Meta.HEROES:
		var skins: Array = [""]
		for it in Meta.items_in("skin", kind):
			skins.append(it.id)
		for g in ["boy", "girl"]:
			for sk in skins:
				for pose in HeroArt.POSES:
					paths.append(HeroArt.hero_path(HeroArt.hero_key(kind, pose, g, sk)))
	for id in HeroArt.fit_items():
		var owner := Meta.owner_of(id)
		for L in HeroArt.fit_item(id).get("layers", []):
			paths.append(HeroArt.layer_path(owner, L.file))
	for p in paths:
		if not ResourceLoader.exists(p):
			continue
		var t := HeroArt.tex(p)
		var s := _src_size(p)
		n += 1
		if t == null or s == Vector2.ZERO or t.get_size() != s:
			bad.append("%s %s/%s" % [p.get_file(), t.get_size() if t else "-", s])
			continue
		var im := t.get_image()  # то, что уходит в видеокарту (первый уровень мипмапов)
		if im == null or Vector2(im.get_size()) != s:
			bad.append("%s: картинка текстуры %s" % [p.get_file(), im.get_size() if im else "-"])
	check(n >= 200 and bad.is_empty(), "размер %d текстур (герои и слои вещей) = размер исходных .webp%s" % [n, "" if bad.is_empty() else ": " + str(bad.slice(0, 5))])


# ---------- 2. Геометрия слоёв относительно героя ----------

## Углы слоя в пикселях картинки героя — по правилам compose.py (независимо от layer_xform):
## pivot в точке place(), ширина width·U, высота — по пропорции ИСХОДНОЙ картинки, поворот по часовой, flip.
func _expected_corners(L: Dictionary, an: Dictionary, W: float, H: float, pose: String, kind: String, src: Vector2) -> PackedVector2Array:
	var pl := HeroArt.place(L, an, W, H, pose, kind)
	var at: Vector2 = pl[0]
	var wpx: float = pl[1]
	var hpx: float = wpx * src.y / src.x
	var pv: Array = L.get("pivot", [0.5, 0.5])
	var px := float(pv[0])
	var py := float(pv[1])
	var flip: bool = L.get("flip", false)
	var a := deg_to_rad(float(pl[2]))
	var out := PackedVector2Array()
	for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		# точка картинки вещи (доли) -> после отражения -> относительно pivot (в отражённой картинке pivot = 1 - px)
		var u: float = (1.0 - uv.x) if flip else uv.x
		var ppx := (1.0 - px) if flip else px
		var d := Vector2((u - ppx) * wpx, (uv.y - py) * hpx)
		out.append(at + d.rotated(a))
	return out


func _test_geometry() -> void:
	print("— вещи относительно героя: одинаково при любом масштабе и = compose.py")
	for c in CASES:
		var o := _outfit(c)
		var p := HeroArt.plan(c[0], o, c[1])
		if p.is_empty():
			check(false, "%s %s: план собран" % [c[0], c[1]])
			continue
		var an := HeroArt.anchors(p.key)
		var hsrc := _src_size(HeroArt.hero_path(p.key))
		var W := hsrc.x
		var H := hsrc.y
		var Ls := HeroArt.layers_for(HeroArt.items_of(o), c[2])
		var entries: Array = p.behind + p.front
		var worst := 0.0
		var spread := 0.0
		var count_ok := entries.size() == Ls.size()
		for s in SCALES:
			# как в игре: base = место и масштаб героя на экране (hero.gd _life без дыхания)
			var base := Transform2D(0.0, Vector2(s, s), 0.0, Vector2(360, 900) * s)
			var to_hero: Transform2D = (base * (p.X as Transform2D)).affine_inverse()
			var hero_quad := _quad(base * (p.X as Transform2D), p.hero.get_size())
			# герой на экране: ровно картинка W×H, масштаб не важен
			for k in 4:
				var back: Vector2 = to_hero * hero_quad[k]
				worst = maxf(worst, back.distance_to([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)][k]))
			var bi := 0
			var fi := 0
			for L in Ls:
				var is_b: bool = L.get("z", "") == "behind"
				var e: Array = p.behind[bi] if is_b else p.front[fi]
				if is_b:
					bi += 1
				else:
					fi += 1
				var t: Texture2D = e[0]
				var src := _src_size(HeroArt.layer_path(c[0], L.file))
				var exp := _expected_corners(L, an, W, H, c[1], c[0], src)
				var q := _quad(base * (e[1] as Transform2D), t.get_size())
				for k in 4:
					var got: Vector2 = to_hero * q[k]
					worst = maxf(worst, got.distance_to(exp[k]))
				# то же в пикселях экрана: относительное место не «плывёт» с масштабом
				var rel: Vector2 = (q[0] - hero_quad[0]) / s
				var rel1: Vector2 = (_quad(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(360, 900)) * (e[1] as Transform2D), t.get_size())[0]
					- _quad(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(360, 900)) * (p.X as Transform2D), p.hero.get_size())[0])
				spread = maxf(spread, rel.distance_to(rel1))
		check(count_ok and worst < 0.5 and spread < 0.01,
			"%s %s %s: %d слоёв, углы вещей = compose.py (отклонение %.3f px картинки героя), сдвиг от масштаба %.4f" % [c[0], c[1], c[2], entries.size(), worst, spread])


func _quad(M: Transform2D, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([M * Vector2.ZERO, M * Vector2(sz.x, 0), M * sz, M * Vector2(0, sz.y)])


## План не зависит от размера окна и растяжения (считается до/после смены — матрицы те же)
func _test_window() -> void:
	print("— план не зависит от размера окна")
	var c: Array = CASES[4]
	var o := _outfit(c)
	HeroArt.clear_cache()
	var p0 := HeroArt.plan(c[0], o, c[1])
	var same := true
	var old_size := root.size
	var old_cs := root.content_scale_size
	for wh in [Vector2i(405, 720), Vector2i(1080, 2340), Vector2i(1440, 3120)]:
		root.size = wh
		root.content_scale_size = Vector2i(720, 1280)
		HeroArt.clear_cache()
		var p1 := HeroArt.plan(c[0], o, c[1])
		same = same and (p1.X as Transform2D).is_equal_approx(p0.X)
		for w in ["behind", "front"]:
			for i in p0[w].size():
				same = same and (p1[w][i][1] as Transform2D).is_equal_approx(p0[w][i][1])
	root.size = old_size
	root.content_scale_size = old_cs
	check(same, "окно 405×720 / 1080×2340 / 1440×3120 — матрицы героя и вещей те же")


# ---------- 3. Сборка по текстурам игры ----------

## Сборка «как в игре»: импортированные текстуры (get_image — то, что получает видеокарта)
## рисуются матрицами плана в масштабе s на холст с теми же полями, что у compose_image.
func _raster(p: Dictionary, s: float, margin := 0.55) -> Image:
	var W: float = p.size.x
	var H: float = p.size.y
	var mx := int(W * margin)
	var my := int(H * margin)
	var cw := int(ceil((W + 2 * mx) * s))
	var ch := int(ceil((H + 2 * my) * s))
	var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	# координаты «героя кодом» -> пиксели холста (через пиксели картинки героя)
	var base := Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(mx, my)) * (p.X as Transform2D).affine_inverse()
	var items: Array = []
	for e in p.behind:
		items.append([e[0], base * (e[1] as Transform2D), e[2].a])
	items.append([p.hero, base * (p.X as Transform2D), 1.0])
	for e in p.front:
		items.append([e[0], base * (e[1] as Transform2D), e[2].a])
	for it in items:
		_blit(canvas, (it[0] as Texture2D).get_image(), it[1], it[2])
	return canvas


## Нарисовать картинку img с матрицей M (пиксели картинки -> холст), билинейно, «поверх»
func _blit(canvas: Image, img: Image, M: Transform2D, alpha: float) -> void:
	if img == null:
		return
	img = img.duplicate()
	if img.has_mipmaps():
		img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var sz := Vector2(img.get_size())
	var q := _quad(M, sz)
	var r := Rect2(q[0], Vector2.ZERO)
	for v in q:
		r = r.expand(v)
	var inv := M.affine_inverse()
	var x0 := maxi(0, floori(r.position.x))
	var y0 := maxi(0, floori(r.position.y))
	var x1 := mini(canvas.get_width() - 1, ceili(r.end.x))
	var y1 := mini(canvas.get_height() - 1, ceili(r.end.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var l: Vector2 = inv * Vector2(x + 0.5, y + 0.5) - Vector2(0.5, 0.5)
			if l.x < -0.5 or l.y < -0.5 or l.x > sz.x - 0.5 or l.y > sz.y - 0.5:
				continue
			var ix := floori(l.x)
			var iy := floori(l.y)
			var fx := l.x - ix
			var fy := l.y - iy
			var acc := Color(0, 0, 0, 0)
			for k in 4:
				var qx: int = clampi(ix + (k & 1), 0, img.get_width() - 1)
				var qy: int = clampi(iy + (k >> 1), 0, img.get_height() - 1)
				var wgt: float = (fx if k & 1 else 1.0 - fx) * (fy if k >> 1 else 1.0 - fy)
				var cc := img.get_pixel(qx, qy)
				acc += Color(cc.r * cc.a, cc.g * cc.a, cc.b * cc.a, cc.a) * wgt
			if acc.a * alpha < 0.004:
				continue
			var src := Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a * alpha)
			canvas.set_pixel(x, y, canvas.get_pixel(x, y).blend(src))


func _test_raster() -> void:
	print("— сборка по текстурам игры при разных масштабах = compose.py")
	for ci in [0, 4, 5]:
		var c: Array = CASES[ci]
		var o := _outfit(c)
		var p := HeroArt.plan(c[0], o, c[1])
		var ref := HeroArt.compose_image(c[0], c[1], HeroArt.items_of(o), c[2], c[3], 0.55, false)
		if p.is_empty() or ref == null:
			check(false, "%s %s: план и эталон собраны" % [c[0], c[1]])
			continue
		for s in [0.5, 1.0]:
			var t0 := Time.get_ticks_msec()
			var mine := _raster(p, s)
			var r := ref.duplicate() as Image
			r.resize(mine.get_width(), mine.get_height(), Image.INTERPOLATE_BILINEAR)
			var res := _compare(mine, r)
			var off := _offset(mine, r)
			check(res[0] < 0.05 and res[1] > 0.94 and off.length() <= 1.5,
				"%s %s масштаб %.1f: по текстурам игры = compose.py — разница %.4f, силуэт %.3f, сдвиг %s (%d мс)" % [c[0], c[1], s, res[0], res[1], off, Time.get_ticks_msec() - t0])


## Сдвиг «центра тяжести» непрозрачного (px холста): вещи не уехали вверх/вниз
func _offset(a: Image, b: Image) -> Vector2:
	var ca := Vector2.ZERO
	var cb := Vector2.ZERO
	var na := 0.0
	var nb := 0.0
	for y in range(0, mini(a.get_height(), b.get_height()), 2):
		for x in range(0, mini(a.get_width(), b.get_width()), 2):
			var pa := a.get_pixel(x, y).a
			var pb := b.get_pixel(x, y).a
			ca += Vector2(x, y) * pa
			cb += Vector2(x, y) * pb
			na += pa
			nb += pb
	return (ca / maxf(na, 1.0) - cb / maxf(nb, 1.0)).snappedf(0.01)


## [средняя разница цвета с учётом прозрачности, IoU силуэта] при лучшем сдвиге ±1 px (как в test_v018_art.gd)
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
