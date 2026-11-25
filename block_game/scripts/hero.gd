extends RefCounted
## Герои Cascado — совёнок и аксолотль — и вещи гардероба. Всё рисуется кодом.
## Использование: Hero.new().draw(canvas_item, "owl", центр, масштаб, наряд, время, react)
##   наряд — словарь слот -> id вещи (scripts/meta.gd), react — секунд с последнего касания.
## Герой нарисован в своих координатах: туловище около (0, 0), ширина ~200, ноги на y ≈ 115.
## У каждого героя свои точки крепления вещей (_anchors): макушка, глаза, шея, спина.

const OUT := Color("#1E1236")
const AMBER := Color("#FFB547")
const BLUSH := Color(1.0, 0.45, 0.6, 0.38)
const REACT_TIME := 1.3

const PALETTES := {
	"owl": {
		"": {"body": Color("#8A63D2"), "dark": Color("#5E3FA3"), "belly": Color("#D6C4FF"), "face": Color("#F1E9FF")},
		"skin_mint": {"body": Color("#45B994"), "dark": Color("#2A8467"), "belly": Color("#C8F4E2"), "face": Color("#EEFFF7")},
		"skin_moon": {"body": Color("#95A8D6"), "dark": Color("#6274A6"), "belly": Color("#E6EDFF"), "face": Color("#F7F9FF")},
		"skin_gold": {"body": Color("#E7A73A"), "dark": Color("#B0761C"), "belly": Color("#FFE6A6"), "face": Color("#FFF7DE")},
	},
	"axolotl": {
		"": {"body": Color("#FFB3CD"), "dark": Color("#E888AA"), "belly": Color("#FFE3EE"), "gill": Color("#FF5F9C"), "gill2": Color("#FF9CC3")},
		"skin_mint": {"body": Color("#A3EED0"), "dark": Color("#68C9A3"), "belly": Color("#E3FFF4"), "gill": Color("#22B88D"), "gill2": Color("#69DDB8")},
		"skin_moon": {"body": Color("#DCE2FA"), "dark": Color("#A9B3DE"), "belly": Color("#F7F9FF"), "gill": Color("#8090FF"), "gill2": Color("#B5BEFF")},
		"skin_gold": {"body": Color("#FFD07A"), "dark": Color("#E3A847"), "belly": Color("#FFF1CC"), "gill": Color("#FF7E33"), "gill2": Color("#FFAE6A")},
	},
}

var ci: CanvasItem


# ---------- Простые фигуры (в координатах героя) ----------

func _ell(c: Vector2, rx: float, ry: float, rot := 0.0, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _fill(pts: PackedVector2Array, col: Color, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	if w > 0.0:
		ci.draw_polyline(closed, outline, w, true)
	else:
		ci.draw_polyline(closed, col, 1.2, true)  # сглаживает край


func _oval(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	_fill(_ell(c, rx, ry, rot), col, outline, w)


func _dot(c: Vector2, r: float, col: Color) -> void:
	_fill(_ell(c, r, r, 0.0, 20), col)


func _line(pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(pts, col, w, true)
	ci.draw_circle(pts[0], w / 2.0, col)
	ci.draw_circle(pts[pts.size() - 1], w / 2.0, col)


func _sparkle(c: Vector2, r: float, col: Color) -> void:
	_fill(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0), c + Vector2(r * 0.25, r * 0.25),
		c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), col)


func _gem(c: Vector2, r: float, col: Color) -> void:
	_fill(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, -r * 0.25), c + Vector2(0, r), c + Vector2(-r * 0.75, -r * 0.25)]), col, col.darkened(0.4), maxf(1.0, r * 0.12))
	_fill(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, -r * 0.25), c + Vector2(0, -r * 0.05)]), Color(1, 1, 1, 0.55))


static func palette(kind: String, outfit: Dictionary) -> Dictionary:
	var p: Dictionary = PALETTES.get(kind, PALETTES.owl)
	return p.get(outfit.get("skin", ""), p[""])


## 0..1: огибающая реакции на касание
static func react_env(react: float) -> float:
	if react >= REACT_TIME or react < 0.0:
		return 0.0
	return sin(react / REACT_TIME * PI)


static func blink(t: float, phase := 0.0) -> float:
	var b := fmod(t + phase, 3.6)
	if b < 0.16:
		return absf(b - 0.08) / 0.08
	return 1.0


# ---------- Главный вызов ----------

## head_only — для аватарки: без лапок и туловища (у совёнка — без лапок).
func draw(target: CanvasItem, kind: String, pos: Vector2, sc: float, outfit: Dictionary, t: float, react := 99.0, head_only := false) -> void:
	ci = target
	var breath := 1.0 + 0.018 * sin(t * 2.2)
	var sway := 0.025 * sin(t * 1.25)
	ci.draw_set_transform(pos, sway, Vector2(sc, sc * breath))
	var p := palette(kind, outfit)
	if kind == "axolotl":
		_axolotl(p, outfit, t, react, head_only)
	else:
		_owl(p, outfit, t, react, head_only)
	ci.draw_set_transform(Vector2.ZERO)


## Аватарка: голова героя в наряде, в круге.
func draw_avatar(target: CanvasItem, kind: String, c: Vector2, r: float, outfit: Dictionary, t: float, ring: Color, react := 99.0) -> void:
	target.draw_circle(c, r + 4, OUT, true, -1.0, true)
	target.draw_circle(c, r, Color("#2A1A4F"), true, -1.0, true)
	target.draw_circle(c + Vector2(0, r * 0.35), r * 0.7, Color(ring, 0.18), true, -1.0, true)
	if kind == "axolotl":
		draw(target, kind, c + Vector2(0, r * 0.22), r / 118.0, outfit, t, react, true)
	else:
		draw(target, kind, c + Vector2(0, r * 0.12), r / 125.0, outfit, t, react, true)
	target.draw_arc(c, r + 2, 0, TAU, 64, ring, 5.0, true)


# ---------- Точки крепления ----------

func _anchors(kind: String, hp: Callable, tilt: float) -> Dictionary:
	if kind == "axolotl":
		return {"top": Vector2(0, -92), "top_w": 116.0, "tilt": tilt,
			"eye_l": Vector2(-46, -32), "eye_r": Vector2(46, -32), "eye_rad": 22.0, "temple": 96.0,
			"neck": Vector2(0, 46), "neck_w": 118.0, "back": Vector2(0, 62), "back_w": 128.0, "kind": kind}
	return {"top": hp.call(Vector2(0, -84)), "top_w": 104.0, "tilt": tilt,
		"eye_l": hp.call(Vector2(-37, -30)), "eye_r": hp.call(Vector2(37, -30)), "eye_rad": 34.0, "temple": 88.0,
		"neck": Vector2(0, 22), "neck_w": 156.0, "back": Vector2(0, 14), "back_w": 184.0, "kind": kind}


# ---------- Совёнок ----------

func _owl(p: Dictionary, outfit: Dictionary, t: float, react: float, head_only: bool) -> void:
	var env := react_env(react)
	# Поворот головы: при касании — оглядывается в сторону и обратно, в покое — чуть-чуть
	var turn := 0.12 * sin(t * 0.55)
	if env > 0.0:
		turn = sin(clampf(react / REACT_TIME, 0.0, 1.0) * TAU) * 1.0
	var shift := turn * 20.0
	var tilt := turn * 0.1
	var pivot := Vector2(0, -30)
	var hp := func(v: Vector2) -> Vector2: return (v - pivot).rotated(tilt) + pivot + Vector2(shift, 0)
	var a := _anchors("owl", hp, tilt)

	_back_items(outfit, a, t, true)

	# Крылышки (за туловищем), при касании взмахивают
	var flap := 0.35 * env * sin(react * 18.0)
	for sx in [-1.0, 1.0]:
		var wc := Vector2(sx * 78, 36)
		_oval(wc, 26, 50, p.dark, -sx * (0.3 + flap), OUT, 5.0)
		for f in 3:
			var fp := wc + Vector2(sx * 6, 14 + f * 12).rotated(-sx * (0.3 + flap))
			ci.draw_arc(fp, 9, 0.2 * PI, 0.8 * PI, 8, Color(p.body, 0.6), 3.0, true)

	# Ушки-треугольники
	for sx in [-1.0, 1.0]:
		var e := PackedVector2Array([hp.call(Vector2(sx * 82, -50)), hp.call(Vector2(sx * 30, -82)), hp.call(Vector2(sx * 86, -128))])
		_fill(e, p.body, OUT, 5.0)
		_fill(PackedVector2Array([hp.call(Vector2(sx * 72, -66)), hp.call(Vector2(sx * 50, -80)), hp.call(Vector2(sx * 80, -112))]), p.dark)

	# Туловище
	_oval(Vector2(0, 10), 94, 100, p.body, 0.0, OUT, 6.0)
	# Животик с пёрышками
	_oval(Vector2(0, 62), 58, 42, p.belly)
	for row in 2:
		for i in 4 - row:
			var c := Vector2((i - (3 - row) / 2.0) * 24, 52 + row * 20)
			ci.draw_arc(c, 8, 0.25 * PI, 0.75 * PI, 8, Color(p.dark, 0.5), 3.0, true)

	# Лицевой диск (сердечком) — два круга вокруг глаз
	for sx in [-1.0, 1.0]:
		_oval(hp.call(Vector2(sx * 37, -30)), 48, 46, Color(p.dark, 0.55))
	for sx in [-1.0, 1.0]:
		_oval(hp.call(Vector2(sx * 37, -30)), 44, 42, p.face)

	# Румянец
	for sx in [-1.0, 1.0]:
		_oval(hp.call(Vector2(sx * 64, 4)), 13, 7, BLUSH)

	# Глаза-кольца с янтарными огоньками
	var b := blink(t)
	for sx in [-1.0, 1.0]:
		var ec: Vector2 = hp.call(Vector2(sx * 37, -30))
		if b < 0.3:
			ci.draw_arc(ec + Vector2(0, -6), 20, 0.15 * PI, 0.85 * PI, 16, OUT, 6.0, true)
			continue
		var look := Vector2(turn * 5.0, 0)
		_oval(ec, 31, 31 * b, Color("#2A1A4F"), 0.0, Color.WHITE, 6.0)
		_oval(ec + look, 19, 19 * b, Color(AMBER, 0.35))
		_oval(ec + look, 13, 13 * b, AMBER)
		_oval(ec + look, 6, 6 * b, Color("#FFE7B0"))
		_oval(ec + look + Vector2(-9, -10 * b), 5, 5 * b, Color.WHITE)

	# Клюв
	var bk := PackedVector2Array([hp.call(Vector2(-12, -8)), hp.call(Vector2(12, -8)), hp.call(Vector2(0, 14))])
	_fill(bk, AMBER, Color("#B5711A"), 3.0)

	if not head_only:
		for sx in [-1.0, 1.0]:
			for k in 3:
				_oval(Vector2(sx * 32 + (k - 1) * 11, 108), 7, 9, AMBER, 0.0, Color("#B5711A"), 2.5)

	_front_items(outfit, a, t)


# ---------- Аксолотль ----------

func _axolotl(p: Dictionary, outfit: Dictionary, t: float, react: float, head_only: bool) -> void:
	var env := react_env(react)
	var a := _anchors("axolotl", func(v): return v, 0.0)

	if not head_only:
		_back_items(outfit, a, t, true)
		# Хвост с плавником, покачивается
		var sway := sin(t * 1.6) * 0.18 + env * 0.3 * sin(react * 10.0)
		var p0 := Vector2(20, 96)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		var mid := PackedVector2Array()
		for i in 15:
			var s := i / 14.0
			var c := p0.bezier_interpolate(Vector2(90, 122), Vector2(150, 96), Vector2(158, 34), s)
			c = p0 + (c - p0).rotated(-sway * s)
			var nx := p0.bezier_interpolate(Vector2(90, 122), Vector2(150, 96), Vector2(158, 34), minf(1.0, s + 0.02))
			nx = p0 + (nx - p0).rotated(-sway * minf(1.0, s + 0.02))
			var tang := (nx - c).normalized() if i < 14 else (c - mid[i - 1]).normalized()
			var nrm := tang.orthogonal()
			var w := 20.0 * (1.0 - s) + 3.0
			var fin := 13.0 * sin(minf(s * 1.15, 1.0) * PI) + 2.0
			mid.append(c)
			top.append(c + nrm * (w + fin))
			bot.append(c - nrm * (w + fin * 0.6))
		var fin_poly := top.duplicate()
		var rev := bot.duplicate()
		rev.reverse()
		fin_poly.append_array(rev)
		_fill(fin_poly, Color(p.dark, 0.85), OUT, 5.0)
		var core := PackedVector2Array()
		var core_b := PackedVector2Array()
		for i in 15:
			var w := 20.0 * (1.0 - i / 14.0) + 2.0
			var nrm := (top[i] - mid[i]).normalized()
			core.append(mid[i] + nrm * w)
			core_b.append(mid[i] - nrm * w)
		core_b.reverse()
		core.append_array(core_b)
		_fill(core, p.body)

		# Задние лапки
		for sx in [-1.0, 1.0]:
			_oval(Vector2(sx * 30, 108), 15, 12, p.body, 0.0, OUT, 4.0)
		# Туловище
		_oval(Vector2(0, 66), 64, 48, p.body, 0.0, OUT, 6.0)
		_oval(Vector2(0, 78), 40, 28, p.belly)
		# Передние лапки с пальчиками
		for sx in [-1.0, 1.0]:
			var lc := Vector2(sx * 62, 96)
			_oval(lc, 16, 14, p.body, sx * 0.3, OUT, 4.0)
			for k in 3:
				_dot(lc + Vector2(sx * 4 + (k - 1) * 8, 11), 4.5, p.dark)

	# Жабры-веточки: по 3 с каждой стороны, шевелятся (при касании — сильнее)
	var amp := 0.06 + 0.32 * env
	var freq := 2.0 + 9.0 * env
	var angles := [-2.45, -2.95, 2.75]
	var lens := [58.0, 62.0, 50.0]
	var bases := [Vector2(-66, -66), Vector2(-86, -40), Vector2(-90, -10)]
	var gills: Array = []
	for sx in [-1.0, 1.0]:
		for i in 3:
			var ang: float = angles[i] + amp * sin(t * freq + i * 1.3 + (0.0 if sx < 0 else 1.7))
			var dir := Vector2(cos(ang), sin(ang))
			if sx > 0:
				dir.x = -dir.x
			var b0 := Vector2(absf(bases[i].x) * sx, bases[i].y)
			var bend := amp * 0.8 * sin(t * freq * 1.3 + i) + 0.25
			var pts := PackedVector2Array()
			for k in 7:
				var s := k / 6.0
				var d := dir.rotated(bend * s * -sx * (1.0 if i < 2 else -1.0))
				pts.append(b0 + d * lens[i] * s)
			gills.append(pts)
	# Сначала контур всех жабр, потом пушистые веточки, потом стебли
	for pts in gills:
		_line(pts, OUT, 14.0)
	for pts in gills:
		for k in range(1, 7):
			var s := k / 6.0
			var q: Vector2 = pts[k]
			var tang: Vector2 = (pts[k] - pts[k - 1]).normalized()
			var nrm := tang.orthogonal()
			var r := 11.0 - s * 3.5
			for side in [-1.0, 1.0]:
				var fd: Vector2 = (tang * -0.55 + nrm * side).normalized()
				_oval(q + fd * (r + 2.0), r, r * 0.48, p.gill2, fd.angle(), p.gill.darkened(0.25), 2.5)
	for pts in gills:
		_line(pts, p.gill, 9.0)
		_dot(pts[6], 7.5, p.gill)

	# Голова — широкая, приплюснутая
	_oval(Vector2(0, -22), 102, 72, p.body, 0.0, OUT, 6.0)
	_oval(Vector2(0, -6), 70, 40, Color(p.belly, 0.45))
	# Крапинки
	for d in [Vector2(-26, -76), Vector2(-6, -84), Vector2(18, -78), Vector2(36, -70)]:
		_dot(d, 3.5, Color(p.dark, 0.7))
	# Румянец
	for sx in [-1.0, 1.0]:
		_oval(Vector2(sx * 68, -6), 15, 8, BLUSH)

	# Глаза-бусинки
	var b := blink(t, 1.3)
	for sx in [-1.0, 1.0]:
		var ec := Vector2(sx * 46, -32)
		if b < 0.3:
			ci.draw_arc(ec + Vector2(0, -4), 9, 0.15 * PI, 0.85 * PI, 10, OUT, 4.0, true)
			continue
		_oval(ec, 10, 11 * b, OUT)
		_oval(ec + Vector2(-3, -4 * b), 3.6, 3.6 * b, Color.WHITE)
		_oval(ec + Vector2(3, 3 * b), 1.6, 1.6 * b, Color(1, 1, 1, 0.8))

	# Улыбка: широкая; при касании — открытый счастливый ротик
	var mouth := PackedVector2Array()
	var open := env
	var depth := 12.0 + 10.0 * open
	for i in 17:
		var a2 := lerpf(0.12 * PI, 0.88 * PI, i / 16.0)
		mouth.append(Vector2(cos(a2) * 40.0, -6.0 + sin(a2) * depth))
	if open > 0.05:
		var m := PackedVector2Array([mouth[0]])
		for i in range(16, -1, -1):
			m.append(mouth[i])
		m = PackedVector2Array()
		for i in 17:
			var a3 := lerpf(0.12 * PI, 0.88 * PI, i / 16.0)
			m.append(Vector2(cos(a3) * 40.0, -6.0 + sin(a3) * depth * 0.25))
		for i in range(16, -1, -1):
			m.append(mouth[i])
		_fill(m, Color("#B23A64"))
		_oval(Vector2(0, -6 + depth * 0.75), 14 * open + 2, 6 * open + 1, Color("#FF7FA6"))
	_line(mouth, Color("#7A2A4C"), 4.5)

	_front_items(outfit, a, t)


# ---------- Вещи ----------

func _back_items(outfit: Dictionary, a: Dictionary, t: float, behind: bool) -> void:
	match outfit.get("back", ""):
		"cape": _cape(a, t, behind)
		"backpack": _backpack(a, behind)


func _front_items(outfit: Dictionary, a: Dictionary, t: float) -> void:
	_back_items(outfit, a, t, false)
	match outfit.get("neck", ""):
		"scarf": _scarf(a)
		"bowtie": _bowtie(a)
		"necklace": _necklace(a, t)
	match outfit.get("eyes", ""):
		"crystal_glasses": _crystal_glasses(a, t)
		"sunglasses": _sunglasses(a)
		"monocle": _monocle(a)
	match outfit.get("head", ""):
		"bow": _bow(a)
		"cap": _cap(a)
		"miner": _miner(a, t)
		"crown": _crown(a, t)
		"wreath": _wreath(a, t)


## Точка на голове: v в единицах «голова шириной 100», от макушки, с наклоном головы.
func _hv(a: Dictionary, v: Vector2) -> Vector2:
	return a.top + v.rotated(a.tilt) * (a.top_w / 100.0)


func _hpoly(a: Dictionary, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(_hv(a, v))
	return out


func _hk(a: Dictionary) -> float:
	return a.top_w / 100.0


func _bow(a: Dictionary) -> void:
	var c := Vector2(30, 0)
	var col := Color("#FF5FA8")
	var k := _hk(a)
	for sx in [-1.0, 1.0]:
		var lobe := _hpoly(a, [c, c + Vector2(sx * 34, -22), c + Vector2(sx * 40, -4), c + Vector2(sx * 30, 16)])
		_fill(lobe, col, OUT, 4.0 * k)
		_fill(_hpoly(a, [c + Vector2(sx * 6, -2), c + Vector2(sx * 28, -14), c + Vector2(sx * 30, -6)]), Color(1, 1, 1, 0.35))
	_oval(_hv(a, c), 9 * k, 9 * k, col.darkened(0.15), 0.0, OUT, 4.0 * k)


func _cap(a: Dictionary) -> void:
	var k := _hk(a)
	var base := [Vector2(-36, 6), Vector2(36, 6)]
	var tip := Vector2(10, -84)
	var cone := _hpoly(a, [base[0], tip, base[1]])
	_fill(cone, Color("#5FC8FF"), OUT, 5.0 * k)
	# полоски
	for s in [0.35, 0.65]:
		var l: Vector2 = base[0].lerp(tip, s)
		var r: Vector2 = base[1].lerp(tip, s)
		var l2: Vector2 = base[0].lerp(tip, s + 0.13)
		var r2: Vector2 = base[1].lerp(tip, s + 0.13)
		_fill(_hpoly(a, [l, r, r2, l2]), Color("#FFD34D"))
	_oval(_hv(a, Vector2(0, 6)), 42 * k, 9 * k, Color("#3E8FD8"), a.tilt, OUT, 4.0 * k)
	_oval(_hv(a, tip), 13 * k, 13 * k, Color.WHITE, 0.0, OUT, 4.0 * k)


func _miner(a: Dictionary, t: float) -> void:
	var k := _hk(a)
	var lamp := _hv(a, Vector2(0, -24))
	# луч фонаря
	var beam := PackedVector2Array([lamp, _hv(a, Vector2(-70, -150)), _hv(a, Vector2(70, -150))])
	var fl := 0.16 + 0.04 * sin(t * 3.0)
	ci.draw_polygon(beam, PackedColorArray([Color(1, 0.95, 0.6, fl), Color(1, 0.95, 0.6, 0.0), Color(1, 0.95, 0.6, 0.0)]))
	var dome := [Vector2(-50, 8)]
	for i in 15:
		var ang := PI + PI * i / 14.0
		dome.append(Vector2(cos(ang) * 50, 8 + sin(ang) * 48))
	_fill(_hpoly(a, dome), Color("#FFC83D"), OUT, 5.0 * k)
	_fill(_hpoly(a, [Vector2(-6, -38), Vector2(6, -38), Vector2(5, 6), Vector2(-5, 6)]), Color("#E8A92A"))
	_oval(_hv(a, Vector2(0, 8)), 60 * k, 9 * k, Color("#D9952A"), a.tilt, OUT, 4.0 * k)
	_oval(lamp, 17 * k, 17 * k, Color("#7A5A20"), 0.0, OUT, 4.0 * k)
	_oval(lamp, 11 * k, 11 * k, Color("#FFF6C8"))
	_oval(lamp, 18 * k, 18 * k, Color(1, 0.95, 0.6, fl))


func _crown(a: Dictionary, t: float) -> void:
	var k := _hk(a)
	var gold := Color("#FFCB45")
	var pts := [Vector2(-42, 8), Vector2(-46, -34), Vector2(-24, -14), Vector2(-12, -46), Vector2(0, -18),
		Vector2(12, -46), Vector2(24, -14), Vector2(46, -34), Vector2(42, 8)]
	_fill(_hpoly(a, pts), gold, OUT, 5.0 * k)
	_fill(_hpoly(a, [Vector2(-42, -6), Vector2(42, -6), Vector2(42, 8), Vector2(-42, 8)]), Color("#F0A92C"))
	var gems := [Color("#FF4D6D"), Color("#3FD0FF"), Color("#3DDC97")]
	for i in 3:
		_gem(_hv(a, Vector2((i - 1) * 26, 1)), 7 * k, gems[i])
	for v in [Vector2(-46, -34), Vector2(-12, -46), Vector2(12, -46), Vector2(46, -34)]:
		_dot(_hv(a, v), 5 * k, Color("#B46CFF"))
	_sparkle(_hv(a, Vector2(-30, -30)), (5 + 3 * sin(t * 4.0)) * k, Color(1, 1, 1, 0.9))


func _wreath(a: Dictionary, t: float) -> void:
	var k := _hk(a)
	var ring := []
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 52, 6 + sin(ang) * 14))
	var leaf := Color("#3E9E62")
	ci.draw_polyline(_hpoly(a, ring), OUT, 14.0 * k, true)
	ci.draw_polyline(_hpoly(a, ring), leaf, 9.0 * k, true)
	for i in range(1, 16, 3):
		var v: Vector2 = ring[i]
		_oval(_hv(a, v + Vector2(0, 4)), 8 * k, 4 * k, Color("#5BC27E"), 0.5 + a.tilt)
	var caps := [Color("#7FF5E0"), Color("#C38BFF"), Color("#7FF5E0"), Color("#C38BFF"), Color("#7FF5E0")]
	var xs := [-44, -22, 0, 22, 44]
	for i in 5:
		var base := Vector2(xs[i], 6 + sin(PI + PI * (xs[i] + 52) / 104.0) * 14)
		var h := 22.0 if i % 2 == 0 else 16.0
		var glow := 0.25 + 0.15 * sin(t * 3.0 + i)
		_oval(_hv(a, base + Vector2(0, -h)), 20 * k, 14 * k, Color(caps[i], glow))
		_fill(_hpoly(a, [base + Vector2(-4, 0), base + Vector2(-3, -h), base + Vector2(3, -h), base + Vector2(4, 0)]), Color("#F4EEFF"))
		var cap := []
		for j in 11:
			var ang := PI + PI * j / 10.0
			cap.append(base + Vector2(0, -h) + Vector2(cos(ang) * 13, sin(ang) * 11))
		_fill(_hpoly(a, cap), caps[i], OUT, 3.0 * k)
		_dot(_hv(a, base + Vector2(-4, -h - 5)), 2.2 * k, Color(1, 1, 1, 0.8))


func _crystal_glasses(a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.12
	var frame := Color("#9FF6FF")
	for e in [a.eye_l, a.eye_r]:
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(e + Vector2(cos(i * TAU / 6.0 + PI / 6.0), sin(i * TAU / 6.0 + PI / 6.0)) * r)
		ci.draw_colored_polygon(hex, Color(0.6, 0.95, 1.0, 0.25))
		var cl := hex.duplicate()
		cl.append(hex[0])
		ci.draw_polyline(cl, OUT, r * 0.24, true)
		ci.draw_polyline(cl, frame, r * 0.13, true)
		_sparkle(e + Vector2(-r * 0.45, -r * 0.45), r * (0.18 + 0.06 * sin(t * 4.0)), Color.WHITE)
	var l: Vector2 = a.eye_l + Vector2(r * 0.87, 0)
	var rr: Vector2 = a.eye_r - Vector2(r * 0.87, 0)
	ci.draw_line(l, rr, frame, r * 0.13, true)
	_gem((l + rr) / 2.0, r * 0.22, Color("#B46CFF"))


func _sunglasses(a: Dictionary) -> void:
	var r: float = a.eye_rad * 1.12
	var bridge := PackedVector2Array([a.eye_l + Vector2(r * 0.9, -r * 0.2), (a.eye_l + a.eye_r) / 2.0 + Vector2(0, -r * 0.35), a.eye_r - Vector2(r * 0.9, r * 0.2)])
	ci.draw_polyline(bridge, OUT, r * 0.2, true)
	for e in [a.eye_l, a.eye_r]:
		var lens := PackedVector2Array()
		for i in 24:
			var ang := TAU * i / 24.0
			var v := Vector2(cos(ang) * r * 1.08, sin(ang) * r * 0.86)
			if v.y < 0:
				v.y *= 0.8
			lens.append(e + v)
		_fill(lens, Color("#22163A"), Color("#FF5FA8"), r * 0.14)
		ci.draw_line(e + Vector2(-r * 0.6, -r * 0.1), e + Vector2(-r * 0.15, -r * 0.5), Color(1, 1, 1, 0.55), r * 0.13, true)
		ci.draw_line(e + Vector2(-r * 0.25, r * 0.15), e + Vector2(r * 0.05, -r * 0.15), Color(1, 1, 1, 0.35), r * 0.09, true)


func _monocle(a: Dictionary) -> void:
	var r: float = a.eye_rad * 1.15
	var e: Vector2 = a.eye_r
	var gold := Color("#FFCB45")
	ci.draw_circle(e, r, Color(0.8, 0.95, 1.0, 0.15), true, -1.0, true)
	ci.draw_arc(e, r, 0, TAU, 40, OUT, r * 0.24, true)
	ci.draw_arc(e, r, 0, TAU, 40, gold, r * 0.13, true)
	var chain := PackedVector2Array()
	var start := e + Vector2(r * 0.7, r * 0.7)
	for i in 9:
		var s := i / 8.0
		chain.append(start + Vector2(s * r * 0.9, s * r * 2.6 - sin(s * PI) * -r * 0.5))
	ci.draw_polyline(chain, gold, maxf(2.0, r * 0.07), true)
	ci.draw_line(e + Vector2(-r * 0.5, -r * 0.3), e + Vector2(-r * 0.1, -r * 0.65), Color(1, 1, 1, 0.6), r * 0.1, true)


func _scarf(a: Dictionary) -> void:
	var w: float = a.neck_w
	var h := w * 0.2
	var n: Vector2 = a.neck
	var red := Color("#FF5A7A")
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		var x := (s - 0.5) * w
		var curve := (1.0 - pow(2.0 * s - 1.0, 2)) * h * 0.45
		top.append(n + Vector2(x, -h * 0.5 + curve))
		bot.append(n + Vector2(x * 0.96, h * 0.5 + curve))
	# хвостик шарфа
	var tl := n + Vector2(w * 0.18, h * 0.3)
	var tail := PackedVector2Array([tl, tl + Vector2(h * 1.1, 0), tl + Vector2(h * 1.4, h * 2.4), tl + Vector2(h * 0.3, h * 2.5)])
	_fill(tail, red.darkened(0.12), OUT, 4.0)
	for i in 4:
		var fx: Vector2 = tail[3].lerp(tail[2], (i + 0.5) / 4.0)
		ci.draw_line(fx, fx + Vector2(0, h * 0.35), Color("#FFD34D"), 3.0, true)
	var band := top.duplicate()
	var rb := bot.duplicate()
	rb.reverse()
	band.append_array(rb)
	_fill(band, red, OUT, 5.0)
	for i in range(1, 12, 2):
		var c := top[i].lerp(bot[i], 0.5)
		var d := h * 0.32
		_fill(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.8, 0), c + Vector2(0, d), c + Vector2(-d * 0.8, 0)]), Color("#FFD34D"))
	_fill(PackedVector2Array([tail[0] + Vector2(h * 0.55, h * 0.9), tail[0] + Vector2(h * 0.85, h * 1.3), tail[0] + Vector2(h * 0.6, h * 1.7), tail[0] + Vector2(h * 0.3, h * 1.3)]), Color("#FFD34D"))


func _bowtie(a: Dictionary) -> void:
	var k: float = a.neck_w / 150.0
	var n: Vector2 = a.neck + Vector2(0, 2)
	var col := Color("#FF4D6D")
	for sx in [-1.0, 1.0]:
		var wing := PackedVector2Array([n, n + Vector2(sx * 34, -20) * k, n + Vector2(sx * 38, 0) * k, n + Vector2(sx * 34, 20) * k])
		_fill(wing, col, OUT, 4.0)
		_fill(PackedVector2Array([n + Vector2(sx * 8, -2) * k, n + Vector2(sx * 28, -13) * k, n + Vector2(sx * 30, -5) * k]), Color(1, 1, 1, 0.3))
	_oval(n, 9 * k, 11 * k, col.darkened(0.2), 0.0, OUT, 3.5)
	for sx in [-1.0, 1.0]:
		_dot(n + Vector2(sx * 22, 8) * k, 3 * k, Color(1, 1, 1, 0.75))


func _necklace(a: Dictionary, t: float) -> void:
	var w: float = a.neck_w * 0.8
	var n: Vector2 = a.neck
	var chain := PackedVector2Array()
	for i in 17:
		var ang := lerpf(0.0, PI, i / 16.0)
		chain.append(n + Vector2(cos(ang) * w * 0.5, -8 + sin(ang) * w * 0.17))
	ci.draw_polyline(chain, OUT, 6.0, true)
	ci.draw_polyline(chain, Color("#FFCB45"), 3.0, true)
	var cols := [Color("#B46CFF"), Color("#3FD0FF"), Color("#9FF6FF"), Color("#3FD0FF"), Color("#B46CFF")]
	for i in 5:
		var c := chain[2 + i * 3]
		var r := w * (0.07 if i == 2 else 0.05)
		_gem(c + Vector2(0, r), r, cols[i])
	_sparkle(chain[8] + Vector2(w * 0.09, -2), w * (0.04 + 0.02 * sin(t * 4.0)), Color.WHITE)


func _cape(a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if not behind:
		# застёжка: шнурок и звёздочка под подбородком
		var n: Vector2 = a.neck + Vector2(0, 6)
		_sparkle(n, 13.0, Color("#FFCB45"))
		_dot(n, 3.5, Color("#FFF3C4"))
		return
	# высокий воротник за головой и широкий плащ до земли
	var pts := PackedVector2Array([b + Vector2(-w * 0.34, -w * 0.36), b + Vector2(-w * 0.50, -w * 0.2)])
	var bottom_y := b.y + w * 0.58
	for i in 11:
		var s := i / 10.0
		var x := lerpf(-w * 0.66, w * 0.66, s)
		pts.append(Vector2(b.x + x, bottom_y + sin(s * TAU * 2.0 + t * 2.0) * 6.0 + (absf(s - 0.5) * -14.0)))
	pts.append(b + Vector2(w * 0.50, -w * 0.2))
	pts.append(b + Vector2(w * 0.34, -w * 0.36))
	var cols := PackedColorArray()
	for v in pts:
		cols.append(Color("#3A47A8").lerp(Color("#1A1652"), clampf((v.y - b.y + w * 0.5) / (w * 1.1), 0.0, 1.0)))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, OUT, 10.0, true)
	ci.draw_polygon(pts, cols)
	var stars := [Vector2(-0.55, 0.35), Vector2(0.55, 0.28), Vector2(-0.42, 0.52), Vector2(0.46, 0.5), Vector2(0.6, 0.02), Vector2(-0.6, 0.05)]
	for i in stars.size():
		var tw := 0.6 + 0.4 * sin(t * 3.0 + i * 1.7)
		_sparkle(b + stars[i] * w, w * 0.04 * (0.7 + tw * 0.5), Color(1, 0.95, 0.75, tw))


func _backpack(a: Dictionary, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	var brown := Color("#D9823F")
	if behind:
		var c := b + Vector2(w * 0.5, -w * 0.12)
		var s := Vector2(w * 0.5, w * 0.6)
		var r := Rect2(c - s / 2.0, s)
		_fill(_rrect(r, s.x * 0.25), brown, OUT, 5.0)
		_fill(_rrect(Rect2(r.position + Vector2(s.x * 0.08, s.y * 0.48), Vector2(s.x * 0.84, s.y * 0.4)), s.x * 0.15), brown.darkened(0.15))
		_fill(_rrect(Rect2(r.position + Vector2(0, -2), Vector2(s.x, s.y * 0.32)), s.x * 0.25), brown.lightened(0.15), OUT, 4.0)
		_dot(c + Vector2(0, -s.y * 0.2 + s.y * 0.14), s.x * 0.08, Color("#FFCB45"))
		return
	# лямки спереди
	var k := w / 184.0
	for sx in [-1.0, 1.0]:
		var top: Vector2 = b + Vector2(sx * 62, -8) * k
		var bot: Vector2 = b + Vector2(sx * 52, 74) * k
		if a.kind == "axolotl":
			top = b + Vector2(sx * 40, -22) * k
			bot = b + Vector2(sx * 50, 30) * k
		var strap := PackedVector2Array([top, top.lerp(bot, 0.5) + Vector2(sx * 4, 0), bot])
		ci.draw_polyline(strap, OUT, 16.0 * k + 2.0, true)
		ci.draw_polyline(strap, brown.darkened(0.1), 11.0 * k, true)
		_dot(top.lerp(bot, 0.55), 4.0 * k + 1.0, Color("#FFCB45"))


func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.49)
	var pts := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for q in 4:
		for i in 7:
			var ang := -PI / 2.0 + q * PI / 2.0 + i * (PI / 2.0) / 6.0
			pts.append(cs[q] + Vector2(cos(ang), sin(ang)) * rad)
	return pts


# ---------- Значок вещи для гардероба ----------

## Рисует вещь отдельно, в квадрате размером size вокруг c. Окраска — мини-аватаркой героя.
func draw_item_icon(target: CanvasItem, id: String, slot: String, kind: String, c: Vector2, size: float, t: float) -> void:
	ci = target
	if slot == "skin":
		draw_avatar(target, kind, c, size * 0.36, {"skin": id}, t, palette(kind, {"skin": id}).body)
		return
	var sc := size / 200.0
	ci.draw_set_transform(c, 0.0, Vector2(sc, sc))
	var a := {"top": Vector2(0, 40), "top_w": 120.0, "tilt": 0.0,
		"eye_l": Vector2(-44, 0), "eye_r": Vector2(44, 0), "eye_rad": 34.0, "temple": 90.0,
		"neck": Vector2(0, 0), "neck_w": 170.0, "back": Vector2(0, -40), "back_w": 150.0, "kind": "icon"}
	match slot:
		"head":
			var oy := {"bow": 0.0, "cap": 10.0, "miner": 0.0, "crown": 0.0, "wreath": 0.0}
			a.top = Vector2(0, 20 + oy.get(id, 0.0))
			if id == "bow":
				a.top = Vector2(-36, 10)
				a.top_w = 180.0
			_front_items({"head": id}, a, t)
		"eyes":
			if id == "monocle":
				a.eye_r = Vector2(-20, -30)
				a.eye_rad = 42.0
			_front_items({"eyes": id}, a, t)
		"neck":
			a.neck = Vector2(0, -20)
			_front_items({"neck": id}, a, t)
		"back":
			if id == "backpack":
				a.back = Vector2(-84, 10)
				a.back_w = 220.0
				_back_items({"back": id}, a, t, true)
			else:
				a.back = Vector2(0, -50)
				a.back_w = 150.0
				a.neck = Vector2(28, -55)
				a.neck_w = 0.0
				_back_items({"back": id}, a, t, true)
	ci.draw_set_transform(Vector2.ZERO)
