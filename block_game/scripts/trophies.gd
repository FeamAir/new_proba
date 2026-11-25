extends RefCounted
## Кубки залов Cascado (0.14) — 2D-рисунки: экран победы «Новый кубок!», кнопка «Кубки», полка славы
## в запасном 2D-доме. 3D-кубки на полке в доме — scripts/home3d/trophy_art3d.gd (тот же замысел).
## Всё рисуется кодом. Десять кубков — у каждого свой силуэт, металл и камень в духе своего зала:
##   1 Аметистовый кубок   — лиловое серебро, гранёный аметист, из чаши растут кристаллы;
##   2 Изумрудная чаша     — широкая золотая чаша, зелёная эмаль, листья на ножке, изумруд над чашей;
##   3 Огненный кубок      — медный кубок-труба, ручки-языки пламени, сверху самоцвет-огонёк (колышется);
##   4 Ледяной бокал       — прозрачный бокал изо льда, иней на ножке и кромке, снежинка;
##   5 Золотое сердце      — золотая подставка-лапки и гранёное сердце-кристалл (пульсирует);
##   6 Сапфировая волна    — синий кубок с серебром, над ним гребень волны с пеной, сапфир;
##   7 Янтарная капля      — капля янтаря в золотой оправе на трёх ножках, внутри застывший жучок и искра;
##   8 Лунный кубок        — тонкий серебряный кубок, над ним полумесяц и звёздочки, жемчужина;
##   9 Фонарь светлячков   — стеклянная банка с золотой крышкой и ручками-ушками, внутри светлячки;
##  10 Кристальная корона  — золотая корона с самоцветами на бархатной подушке, переливается радугой.
## Рисунок в своих координатах: высота 100 (y от -50 до 50), центр (0, 0); draw() переносит и масштабирует.

const Meta := preload("res://scripts/meta.gd")
const OUT := Color("#1E1236")
const COUNT := 10

## Главный цвет кубка (свечение, лучи на экране победы, подсветка на полке)
const GLOW := [Color("#B46CFF"), Color("#3DDC97"), Color("#FF7A3D"), Color("#8FE9FF"), Color("#FF4D6D"),
	Color("#4D7CFF"), Color("#FFB547"), Color("#E6ECFF"), Color("#D9FF5A"), Color("#FF8AD8")]

static var _ci: CanvasItem
## Силуэт (кубок ещё не получен): всё рисуется одним цветом
static var _ghost := Color(0, 0, 0, 0)
static var _k := 1.0


static func glow_color(n: int) -> Color:
	return GLOW[clampi(n, 1, COUNT) - 1]


## Нарисовать кубок n (1..10): c — центр, s — высота в пикселях, t — время (анимация блеска).
## ghost — полупрозрачный силуэт (кубок ещё не получен).
static func draw(ci: CanvasItem, n: int, c: Vector2, s: float, t: float, ghost := false, ghost_col := Color(1, 1, 1, 0.16)) -> void:
	if s < 2.0:
		return
	_ci = ci
	_k = s / 100.0
	_ghost = ghost_col if ghost else Color(0, 0, 0, 0)
	ci.draw_set_transform(c, 0.0, Vector2(_k, _k))
	match clampi(n, 1, COUNT):
		1: _amethyst(t)
		2: _emerald(t)
		3: _flame(t)
		4: _frost(t)
		5: _heart(t)
		6: _wave(t)
		7: _amber(t)
		8: _moon(t)
		9: _fireflies(t)
		10: _crown(t)
	if not ghost:
		_twinkles(n, t)
	ci.draw_set_transform(Vector2.ZERO)
	_ghost = Color(0, 0, 0, 0)


## Лучи и сияние за кубком (экран победы, новый кубок)
static func draw_rays(ci: CanvasItem, n: int, c: Vector2, r: float, t: float, a := 1.0) -> void:
	if r < 4.0 or a <= 0.0:
		return
	var col := glow_color(n)
	for i in 14:
		var ang := t * 0.35 + i * TAU / 14.0
		var w := 0.11 if i % 2 == 0 else 0.07
		var rr := r * (1.0 if i % 2 == 0 else 0.8)
		var pts := PackedVector2Array([c, c + Vector2(cos(ang - w), sin(ang - w)) * rr, c + Vector2(cos(ang + w), sin(ang + w)) * rr])
		ci.draw_polygon(pts, PackedColorArray([Color(col.lightened(0.4), 0.5 * a), Color(col, 0.0), Color(col, 0.0)]))
	for i in 6:
		ci.draw_circle(c, r * (0.62 - i * 0.08), Color(col, 0.07 * a), true, -1.0, true)
	ci.draw_circle(c, r * 0.2, Color(1, 1, 1, 0.12 * a), true, -1.0, true)


# ---------- Общие приёмы ----------

static func _c(col: Color) -> Color:
	if _ghost.a > 0.0:
		return _ghost
	return col


## Металл на цилиндре: u от -1 (левый край) до 1 (правый) — тёмные края, яркая полоса слева от середины
static func _metal(base: Color, u: float) -> Color:
	var l := 0.5 + 0.5 * cos((u + 0.38) * 1.75)
	var col := base.darkened(0.6).lerp(base, smoothstep(0.0, 0.55, l))
	col = col.lerp(base.lightened(0.55), smoothstep(0.72, 0.98, l))
	col = col.lerp(base.lightened(0.25), smoothstep(0.7, 0.95, u) * 0.7)
	return col


## Тело вращения: профиль [Vector2(радиус, y)] сверху вниз; цвет по металлу; блик-полоска и обводка
static func _lathe(profile: Array, base: Color, shine := true, outline := true, alpha := 1.0) -> void:
	var cols := 12
	for j in profile.size() - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		for i in cols:
			var u0 := -1.0 + 2.0 * i / cols
			var u1 := -1.0 + 2.0 * (i + 1) / cols
			var c0 := _c(Color(_metal(base, u0), alpha))
			var c1 := _c(Color(_metal(base, u1), alpha))
			_ci.draw_primitive(PackedVector2Array([Vector2(p0.x * u0, p0.y), Vector2(p0.x * u1, p0.y), Vector2(p1.x * u1, p1.y), Vector2(p1.x * u0, p1.y)]),
				PackedColorArray([c0, c1, c1, c0]), PackedVector2Array())
	if shine and _ghost.a <= 0.0:
		var pts := PackedVector2Array()
		for p in profile:
			pts.append(Vector2(p.x * -0.5, p.y))
		_ci.draw_polyline(pts, Color(1, 1, 1, 0.55 * alpha), 1.6, true)
	if outline:
		_ci.draw_polyline(_silhouette(profile), _c(Color(OUT, 0.9)), 1.4, true)


static func _silhouette(profile: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in profile:
		pts.append(Vector2(p.x, p.y))
	for i in range(profile.size() - 1, -1, -1):
		pts.append(Vector2(-profile[i].x, profile[i].y))
	pts.append(pts[0])
	return pts


## Устье чаши: эллипс (внутри темнее, кромка светлая)
static func _mouth(y: float, r: float, base: Color, inner: Color) -> void:
	var e := _ell(Vector2(0, y), r, r * 0.26)
	_ci.draw_colored_polygon(e, _c(inner))
	var e2 := _ell(Vector2(0, y + r * 0.06), r * 0.86, r * 0.18)
	_ci.draw_colored_polygon(e2, _c(inner.darkened(0.35)))
	e.append(e[0])
	_ci.draw_polyline(e, _c(base.lightened(0.5)), 1.8, true)


static func _ell(c: Vector2, rx: float, ry: float, n := 28, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func _poly(pts: PackedVector2Array, col: Color, outline := true) -> void:
	_ci.draw_colored_polygon(pts, _c(col))
	if outline:
		var o := pts.duplicate()
		o.append(pts[0])
		_ci.draw_polyline(o, _c(Color(OUT, 0.9)), 1.3, true)


## Гранёный камень (вид спереди): площадка, грани вокруг, отблеск. sides — число граней
static func _gem(c: Vector2, rx: float, ry: float, col: Color, t: float, sides := 8, rot := 0.0) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides - PI / 2.0 + PI / sides + rot
		outer.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		inner.append(c + Vector2(cos(a) * rx * 0.52, sin(a) * ry * 0.52) + Vector2(-rx * 0.06, -ry * 0.06))
	if _ghost.a > 0.0:
		_poly(outer, col)
		return
	for i in sides:
		var j := (i + 1) % sides
		var a := TAU * (i + 0.5) / sides - PI / 2.0 + PI / sides + rot
		var lit := 0.5 + 0.5 * cos(a + 2.3)
		var fc := col.darkened(0.45).lerp(col.lightened(0.45), lit)
		_ci.draw_colored_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), fc)
	_ci.draw_colored_polygon(inner, col.lightened(0.2))
	# отблеск на площадке
	_ci.draw_colored_polygon(PackedVector2Array([inner[sides - 1], inner[0], c + Vector2(-rx * 0.06, -ry * 0.06)]), Color(1, 1, 1, 0.55))
	var o := outer.duplicate()
	o.append(outer[0])
	_ci.draw_polyline(o, Color(OUT, 0.9), 1.3, true)
	var tw := pow(maxf(0.0, sin(t * 2.1 + c.x * 0.3 + c.y * 0.2)), 8.0)
	if tw > 0.05:
		_star(c + Vector2(-rx * 0.35, -ry * 0.4), maxf(rx, ry) * 0.9 * tw, Color(1, 1, 1, 0.9 * tw))


## Кристалл-призма (острый верх): основание в b, длина h, ширина w, угол наклона
static func _crystal(b: Vector2, h: float, w: float, ang: float, col: Color) -> void:
	var up := Vector2(sin(ang), -cos(ang))
	var side := Vector2(cos(ang), sin(ang))
	var p0 := b - side * w * 0.5
	var p1 := b + side * w * 0.5
	var p2 := p1 + up * h * 0.72
	var p3 := b + up * h
	var p4 := p0 + up * h * 0.72
	if _ghost.a > 0.0:
		_poly(PackedVector2Array([p0, p1, p2, p3, p4]), col)
		return
	var mid := b + up * h * 0.72
	_ci.draw_colored_polygon(PackedVector2Array([p0, b, mid, p4]), col.lightened(0.25))
	_ci.draw_colored_polygon(PackedVector2Array([b, p1, p2, mid]), col.darkened(0.2))
	_ci.draw_colored_polygon(PackedVector2Array([p4, mid, p3]), col.lightened(0.55))
	_ci.draw_colored_polygon(PackedVector2Array([mid, p2, p3]), col.lightened(0.1))
	_ci.draw_polyline(PackedVector2Array([p0, p1, p2, p3, p4, p0]), Color(OUT, 0.9), 1.2, true)


static func _star(c: Vector2, r: float, col: Color) -> void:
	if r < 0.3:
		return
	_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.18, -r * 0.18), c + Vector2(r, 0), c + Vector2(r * 0.18, r * 0.18),
		c + Vector2(0, r), c + Vector2(-r * 0.18, r * 0.18), c + Vector2(-r, 0), c + Vector2(-r * 0.18, -r * 0.18)]), col)


static func _glow(c: Vector2, r: float, col: Color, a := 0.3) -> void:
	if _ghost.a > 0.0:
		return
	for i in 4:
		_ci.draw_circle(c, r * (1.0 - i * 0.22), Color(col, a * 0.35), true, -1.0, true)


## Подставка-основание (у всех кубков разная форма, но общий приём)
static func _foot(profile: Array, base: Color) -> void:
	_lathe(profile, base)


## Ручка кубка: дуга из толстой линии с обводкой
static func _handle(pts: PackedVector2Array, base: Color, w := 5.0) -> void:
	_ci.draw_polyline(pts, _c(OUT), w + 2.6, true)
	_ci.draw_polyline(pts, _c(base), w, true)
	if _ghost.a <= 0.0:
		var hi := PackedVector2Array()
		for p in pts:
			hi.append(p + Vector2(-0.6, -1.2))
		_ci.draw_polyline(hi, Color(1, 1, 1, 0.45), w * 0.3, true)


static func _arc_pts(c: Vector2, rx: float, ry: float, a0: float, a1: float, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Искорки-звёздочки вокруг кубка (мерцают по очереди)
static func _twinkles(n: int, t: float) -> void:
	for i in 4:
		var ph := t * 1.6 + i * 1.7 + n
		var a := pow(maxf(0.0, sin(ph)), 6.0)
		if a < 0.05:
			continue
		var p := Vector2(-34 + 68 * fposmod(sin(i * 12.9 + n * 3.1) * 43.7, 1.0), -44 + 70 * fposmod(sin(i * 7.3 + n * 1.9) * 91.3, 1.0))
		_star(p, 7.0 * a, Color(1, 1, 1, 0.9 * a))


# ---------- 1. Аметистовый кубок ----------

static func _amethyst(t: float) -> void:
	var m := Color("#C7B2F0")
	_glow(Vector2(0, -14), 46, GLOW[0], 0.35)
	# кристаллы из чаши (позади устья)
	_crystal(Vector2(-9, -16), 22, 9, -0.38, Color("#A35CF0"))
	_crystal(Vector2(9, -16), 20, 9, 0.42, Color("#C58AFF"))
	_crystal(Vector2(0, -16), 34, 12, 0.02, Color("#B46CFF"))
	_handle(_arc_pts(Vector2(-25, -3), 11, 13, -PI * 0.55, -PI * 1.45), m)
	_handle(_arc_pts(Vector2(25, -3), 11, 13, -PI * 0.45, PI * 0.45), m)
	_lathe([Vector2(28, -16), Vector2(27, -10), Vector2(24, 2), Vector2(17, 12), Vector2(8, 18), Vector2(5, 22)], m)
	_mouth(-16, 28, m, Color("#4A2A7A"))
	_crystal(Vector2(-9, -16), 22, 9, -0.38, Color("#A35CF0"))
	_crystal(Vector2(9, -16), 20, 9, 0.42, Color("#C58AFF"))
	_crystal(Vector2(0, -15), 34, 12, 0.02, Color("#B46CFF"))
	# ножка с узлом и восьмигранное основание
	_lathe([Vector2(5, 21), Vector2(9, 25), Vector2(9, 29), Vector2(5, 33), Vector2(5, 37)], m)
	_lathe([Vector2(9, 37), Vector2(21, 42), Vector2(23, 46), Vector2(23, 50)], m.darkened(0.08))
	_gem(Vector2(0, 0), 11, 12, Color("#9B4DFF"), t, 8)
	_gem(Vector2(0, 44), 3.5, 3, Color("#D9A8FF"), t + 1.0, 6)


# ---------- 2. Изумрудная чаша ----------

static func _leaf(c: Vector2, l: float, w: float, ang: float, col: Color) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		pts.append(c + d * l * u + n * sin(u * PI) * w)
	for i in range(7, 0, -1):
		var u := i / 8.0
		pts.append(c + d * l * u - n * sin(u * PI) * w)
	_poly(pts, col)
	if _ghost.a <= 0.0:
		_ci.draw_line(c, c + d * l * 0.85, col.lightened(0.45), 1.0, true)


static func _emerald(t: float) -> void:
	var gold := Color("#FFCF5A")
	_glow(Vector2(0, -22), 40, GLOW[1], 0.38)
	# изумруд над чашей: «изумрудная» огранка (прямоугольник со срезанными углами, ступени)
	var ec := Vector2(0, -27 + sin(t * 1.6) * 1.5)
	if _ghost.a > 0.0:
		_poly(_emerald_cut(ec, 13, 17, 0.32), Color("#1FBF7A"))
	else:
		_ci.draw_colored_polygon(_emerald_cut(ec, 13, 17, 0.32), Color("#0E8F57"))
		_ci.draw_colored_polygon(_emerald_cut(ec + Vector2(-0.5, -0.5), 9.5, 13, 0.32), Color("#2FD98E"))
		_ci.draw_colored_polygon(_emerald_cut(ec + Vector2(-0.8, -0.8), 6, 9, 0.32), Color("#7FF5C0"))
		_ci.draw_colored_polygon(PackedVector2Array([ec + Vector2(-6, -9), ec + Vector2(-1, -9), ec + Vector2(-6, -2)]), Color(1, 1, 1, 0.6))
		var o := _emerald_cut(ec, 13, 17, 0.32)
		o.append(o[0])
		_ci.draw_polyline(o, Color(OUT, 0.9), 1.3, true)
	# листья вокруг изумруда
	_leaf(Vector2(-6, -12), 18, 5, -2.6, Color("#3DBA6A"))
	_leaf(Vector2(6, -12), 18, 5, -0.55, Color("#2FA35C"))
	# широкая чаша
	_lathe([Vector2(34, -10), Vector2(33, -6), Vector2(27, 2), Vector2(15, 8), Vector2(6, 11)], gold)
	_mouth(-10, 34, gold, Color("#1F6B45"))
	# зелёная эмалевая полоса с кабошонами
	if _ghost.a <= 0.0:
		var band := PackedVector2Array()
		for i in 13:
			var u := -1.0 + 2.0 * i / 12.0
			band.append(Vector2(31 * u, -4 + 1.6 * (1.0 - u * u)))
		for i in range(12, -1, -1):
			var u := -1.0 + 2.0 * i / 12.0
			band.append(Vector2(27.5 * u, 1.5 + 1.6 * (1.0 - u * u)))
		_ci.draw_colored_polygon(band, Color("#169E62"))
		for x in [-18.0, 0.0, 18.0]:
			_gem(Vector2(x, -1.0 + 1.2 * (1.0 - (x / 31.0) * (x / 31.0))), 3.2, 3.0, Color("#5CF0A8"), t + x, 6)
	# ножка, обвитая листьями
	_lathe([Vector2(5, 10), Vector2(4, 22), Vector2(7, 26), Vector2(4, 30), Vector2(4, 38)], gold)
	_leaf(Vector2(0, 30), 15, 4, -2.4, Color("#3DBA6A"))
	_leaf(Vector2(0, 22), 15, 4, -0.7, Color("#2FA35C"))
	_lathe([Vector2(8, 38), Vector2(20, 44), Vector2(22, 47), Vector2(20, 50)], gold.darkened(0.06))


static func _emerald_cut(c: Vector2, hw: float, hh: float, cut: float) -> PackedVector2Array:
	var k := minf(hw, hh) * cut
	return PackedVector2Array([c + Vector2(-hw + k, -hh), c + Vector2(hw - k, -hh), c + Vector2(hw, -hh + k), c + Vector2(hw, hh - k),
		c + Vector2(hw - k, hh), c + Vector2(-hw + k, hh), c + Vector2(-hw, hh - k), c + Vector2(-hw, -hh + k)])


# ---------- 3. Огненный кубок ----------

static func _flame_poly(c: Vector2, w: float, h: float, t: float, ph := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sway := sin(t * 6.0 + ph) * 0.12 + sin(t * 11.0 + ph) * 0.05
	for i in 17:
		var a := PI * i / 16.0
		pts.append(c + Vector2(cos(a) * w, sin(a) * w * 0.9))
	var tip := c + Vector2(sway * w * 2.0, -h)
	pts.append(c + Vector2(-w * 0.9, -h * 0.25) + Vector2(sway * w * 0.5, 0))
	pts.append(c.lerp(tip, 0.6) + Vector2(-w * 0.45, 0))
	pts.append(tip)
	pts.append(c.lerp(tip, 0.55) + Vector2(w * 0.5, 0))
	pts.append(c + Vector2(w * 0.95, -h * 0.2) + Vector2(sway * w * 0.5, 0))
	return pts


static func _flame(t: float) -> void:
	var cu := Color("#E8834A")
	_glow(Vector2(0, -26), 42, GLOW[2], 0.45)
	# ручки — завитки пламени
	_handle(PackedVector2Array([Vector2(-17, -10), Vector2(-27, -14), Vector2(-31, -6), Vector2(-26, 2), Vector2(-18, 6), Vector2(-14, 10)]), cu)
	_handle(PackedVector2Array([Vector2(17, -10), Vector2(27, -14), Vector2(31, -6), Vector2(26, 2), Vector2(18, 6), Vector2(14, 10)]), cu)
	_lathe([Vector2(22, -16), Vector2(19, -8), Vector2(13, 4), Vector2(7, 12), Vector2(5, 18)], cu)
	_mouth(-16, 22, cu, Color("#5A1E10"))
	# самоцвет-огонёк над чашей
	var fc := Vector2(0, -18)
	var f1 := _flame_poly(fc, 13, 36 + 3.0 * sin(t * 7.0), t)
	if _ghost.a > 0.0:
		_poly(f1, Color.WHITE)
	else:
		_ci.draw_colored_polygon(f1, Color("#FF5A2A"))
		_ci.draw_colored_polygon(_flame_poly(fc + Vector2(0, 1), 9, 26 + 2.0 * sin(t * 9.0 + 1.0), t, 1.3), Color("#FF9A3A"))
		_ci.draw_colored_polygon(_flame_poly(fc + Vector2(0, 1), 5, 15 + 1.5 * sin(t * 13.0), t, 2.1), Color("#FFE27A"))
		var o := f1.duplicate()
		o.append(f1[0])
		_ci.draw_polyline(o, Color(OUT, 0.85), 1.3, true)
	# медная ножка и ступенчатое основание
	_lathe([Vector2(5, 17), Vector2(4, 28), Vector2(8, 31), Vector2(5, 34), Vector2(5, 37)], cu)
	_lathe([Vector2(10, 37), Vector2(18, 41), Vector2(18, 44), Vector2(22, 46), Vector2(22, 50)], cu.darkened(0.1))
	_gem(Vector2(0, 0), 7, 8, Color("#FF4A2A"), t, 6, PI / 6.0)


# ---------- 4. Ледяной бокал ----------

static func _frost(t: float) -> void:
	var ice := Color("#BDF4FF")
	_glow(Vector2(0, -4), 44, GLOW[3], 0.35)
	var a := 0.72
	# чаша из льда (полупрозрачная)
	_lathe([Vector2(24, -26), Vector2(25, -16), Vector2(22, -4), Vector2(15, 5), Vector2(6, 10), Vector2(3, 14)], ice, true, true, a)
	_mouth(-26, 24, ice, Color(0.55, 0.85, 1.0, 0.6))
	if _ghost.a <= 0.0:
		# внутренний свет и блики стекла
		_ci.draw_colored_polygon(_ell(Vector2(0, -6), 13, 10), Color(0.8, 0.97, 1.0, 0.35))
		_ci.draw_line(Vector2(-15, -20), Vector2(-12, 0), Color(1, 1, 1, 0.8), 2.4, true)
		_ci.draw_line(Vector2(15, -18), Vector2(13, -10), Color(1, 1, 1, 0.5), 1.4, true)
		_snowflake(Vector2(2, -9), 8.5, Color("#FFFFFF"), t)
	# иней на кромке: сосульки-шипы
	for i in 7:
		var x := -21.0 + i * 7.0
		var hh := 5.0 + 3.0 * fposmod(i * 0.37, 1.0)
		_poly(PackedVector2Array([Vector2(x - 2.5, -26 + 6.0 * (x / 24.0) * (x / 24.0) * 0.2), Vector2(x + 2.5, -26), Vector2(x, -26 + hh)]), Color("#F2FDFF"), false)
	# тонкая ножка с ледяным шариком
	_lathe([Vector2(3, 13), Vector2(2.5, 22), Vector2(6, 25), Vector2(6, 30), Vector2(2.5, 33), Vector2(2.5, 40)], ice, true, true, a)
	_lathe([Vector2(5, 40), Vector2(20, 45), Vector2(22, 48), Vector2(20, 50)], ice.darkened(0.05), true, true, a)
	# ледяные кристаллики у основания
	_crystal(Vector2(-15, 47), 13, 5, -0.5, Color("#9FE8FF"))
	_crystal(Vector2(15, 47), 11, 5, 0.55, Color("#C9F6FF"))
	_crystal(Vector2(-10, 47), 8, 4, -0.15, Color("#E6FCFF"))


static func _snowflake(c: Vector2, r: float, col: Color, t: float) -> void:
	var rot := t * 0.4
	for i in 6:
		var a := rot + i * TAU / 6.0
		var d := Vector2(cos(a), sin(a))
		_ci.draw_line(c, c + d * r, _c(col), 1.6, true)
		var m := c + d * r * 0.55
		_ci.draw_line(m, m + d.rotated(0.8) * r * 0.32, _c(col), 1.2, true)
		_ci.draw_line(m, m + d.rotated(-0.8) * r * 0.32, _c(col), 1.2, true)
	_ci.draw_circle(c, 1.8, _c(col), true, -1.0, true)


# ---------- 5. Золотое сердце ----------

static func _heart_pts(c: Vector2, w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := w / 32.0
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * s)
	return pts


static func _heart(t: float) -> void:
	var gold := Color("#FFC94A")
	var beat := 1.0 + 0.06 * maxf(0.0, sin(t * 3.2)) + 0.03 * maxf(0.0, sin(t * 3.2 - 0.8))
	_glow(Vector2(0, -16), 46 * beat, GLOW[4], 0.42)
	# подставка: чашечка-лапки, ножка, основание
	_lathe([Vector2(6, 8), Vector2(5, 22), Vector2(9, 26), Vector2(5, 30), Vector2(5, 36)], gold)
	_lathe([Vector2(9, 36), Vector2(22, 42), Vector2(24, 46), Vector2(24, 50)], gold.darkened(0.08))
	# сердце-кристалл: гранёное, «бьётся»
	var hc := Vector2(0, -14)
	var hp := _heart_pts(hc, 52 * beat)
	if _ghost.a > 0.0:
		_poly(hp, Color.WHITE)
	else:
		var ctr := hc + Vector2(-3, -4)
		for i in hp.size():
			var j := (i + 1) % hp.size()
			var a := (hp[i] - hc).angle()
			var lit := 0.5 + 0.5 * cos(a + 2.4)
			var band := 1.0 if (i / 4) % 2 == 0 else 0.82
			_ci.draw_colored_polygon(PackedVector2Array([ctr, hp[i], hp[j]]), Color("#B0123A").lerp(Color("#FF6A8A"), lit) * Color(band, band, band, 1.0))
		var inner := _heart_pts(hc + Vector2(-2, -1), 26 * beat)
		_ci.draw_colored_polygon(inner, Color(1.0, 0.45, 0.6, 0.55))
		_ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-17, -14), hc + Vector2(-9, -17), hc + Vector2(-13, -6)]), Color(1, 1, 1, 0.7))
		var o := hp.duplicate()
		o.append(hp[0])
		_ci.draw_polyline(o, Color(OUT, 0.9), 1.4, true)
	# золотые лапки держат сердце снизу
	for sx in [-1.0, 1.0]:
		_handle(PackedVector2Array([Vector2(0, 9), Vector2(sx * 7, 5), Vector2(sx * 11, -1), Vector2(sx * 12, -5)]), gold, 3.6)
	_gem(Vector2(0, 30), 3.5, 3.5, Color("#FF4D6D"), t, 6)


# ---------- 6. Сапфировая волна ----------

static func _wave(t: float) -> void:
	var silver := Color("#CFE0FF")
	var blue := Color("#2F5BE0")
	_glow(Vector2(0, -16), 44, GLOW[5], 0.38)
	# гребень волны над чашей (позади кромки)
	var sw := sin(t * 1.8) * 1.5
	var crest := PackedVector2Array([Vector2(-24, -14), Vector2(-20, -26), Vector2(-10, -38 + sw), Vector2(4, -44 + sw), Vector2(16, -40 + sw),
		Vector2(21, -31 + sw), Vector2(16, -26), Vector2(10, -32 + sw), Vector2(2, -32), Vector2(-4, -24), Vector2(2, -14)])
	if _ghost.a > 0.0:
		_poly(crest, Color.WHITE)
	else:
		var cols := PackedColorArray()
		for p in crest:
			cols.append(Color("#1E3FB8").lerp(Color("#5FA8FF"), clampf((-p.y - 14.0) / 30.0, 0.0, 1.0)))
		_ci.draw_polygon(crest, cols)
		var o := crest.duplicate()
		o.append(crest[0])
		_ci.draw_polyline(o, Color(OUT, 0.9), 1.3, true)
		# пена: белые шарики по гребню
		for i in 6:
			var u := i / 5.0
			var p := Vector2(-12 + u * 30, -40 + sw + 10.0 * (u - 0.5) * (u - 0.5) * 4.0 - 2.0)
			_ci.draw_circle(p, 2.6 - u * 0.8, Color(1, 1, 1, 0.95), true, -1.0, true)
		_ci.draw_line(Vector2(-16, -24), Vector2(-6, -36 + sw), Color(1, 1, 1, 0.55), 1.6, true)
	_handle(_arc_pts(Vector2(-24, -4), 9, 11, -PI * 0.55, -PI * 1.45), silver)
	_handle(_arc_pts(Vector2(24, -4), 9, 11, -PI * 0.45, PI * 0.45), silver)
	_lathe([Vector2(25, -14), Vector2(24, -6), Vector2(20, 4), Vector2(13, 11), Vector2(6, 15)], blue)
	_mouth(-14, 25, silver, Color("#102A7A"))
	# серебряные полоски-волны по чаше
	if _ghost.a <= 0.0:
		for row in 2:
			var pts := PackedVector2Array()
			for i in 15:
				var u := -0.95 + 1.9 * i / 14.0
				var r := lerpf(23.5, 19.0, float(row))
				pts.append(Vector2(r * u, -5 + row * 7 + 1.6 * sin(u * 9.0 + t * 2.0)))
			_ci.draw_polyline(pts, Color("#E8F0FF"), 1.6, true)
	_gem(Vector2(0, 1), 7.5, 7.5, Color("#2E5BFF"), t, 8)
	_lathe([Vector2(5, 14), Vector2(4, 30), Vector2(8, 33), Vector2(5, 36)], silver)
	_lathe([Vector2(8, 36), Vector2(22, 42), Vector2(23, 46), Vector2(22, 50)], silver.darkened(0.1))


# ---------- 7. Янтарная капля ----------

static func _drop_pts(c: Vector2, r: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		var y := sin(a)
		var x := cos(a)
		# верх — острый кончик
		var k := 1.0 if y > 0.0 else (1.0 - 0.75 * pow(-y, 1.4))
		pts.append(c + Vector2(x * r * k, y * (r if y > 0.0 else h)))
	return pts


static func _amber(t: float) -> void:
	var gold := Color("#FFC94A")
	_glow(Vector2(0, -6), 44, GLOW[6], 0.45)
	# три золотые ножки
	_handle(PackedVector2Array([Vector2(-6, 22), Vector2(-14, 32), Vector2(-20, 44), Vector2(-24, 48)]), gold, 3.8)
	_handle(PackedVector2Array([Vector2(6, 22), Vector2(14, 32), Vector2(20, 44), Vector2(24, 48)]), gold, 3.8)
	_lathe([Vector2(3, 20), Vector2(3, 36), Vector2(6, 40), Vector2(4, 44)], gold)
	_lathe([Vector2(14, 44), Vector2(17, 47), Vector2(16, 50)], gold.darkened(0.1))
	# капля
	var dc := Vector2(0, 2)
	var dp := _drop_pts(dc, 21, 44)
	if _ghost.a > 0.0:
		_poly(dp, Color.WHITE)
	else:
		var cols := PackedColorArray()
		for p in dp:
			var u := clampf(((p - dc).x + 21.0) / 42.0, 0.0, 1.0)
			cols.append(Color("#FFB23A").lerp(Color("#C9580E"), u * 0.8 + clampf((p.y - dc.y) / 21.0, 0.0, 1.0) * 0.3))
		_ci.draw_polygon(dp, cols)
		# свет внутри
		_ci.draw_colored_polygon(_ell(dc + Vector2(-2, 2), 12, 13), Color(1.0, 0.85, 0.4, 0.45))
		# застывший жучок
		var bc := dc + Vector2(2, 4)
		_ci.draw_colored_polygon(_ell(bc, 4.5, 6.0, 16, 0.5), Color(0.25, 0.1, 0.02, 0.8))
		_ci.draw_colored_polygon(_ell(bc + Vector2(-2.6, -5.4), 2.4, 2.4, 10), Color(0.25, 0.1, 0.02, 0.8))
		for sy in [-2.0, 1.0, 4.0]:
			_ci.draw_line(bc + Vector2(-3, sy), bc + Vector2(-7, sy - 1.5), Color(0.25, 0.1, 0.02, 0.7), 0.9, true)
			_ci.draw_line(bc + Vector2(3, sy), bc + Vector2(7, sy + 1.0), Color(0.25, 0.1, 0.02, 0.7), 0.9, true)
		# искра
		var sp := 0.7 + 0.3 * sin(t * 4.0)
		_star(dc + Vector2(-7, -8), 4.5 * sp, Color(1, 1, 0.85, 0.95))
		_ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(-13, -6), dc + Vector2(-9, -22), dc + Vector2(-6, -21), dc + Vector2(-9, -6)]), Color(1, 1, 1, 0.45))
		var o := dp.duplicate()
		_ci.draw_polyline(o, Color(OUT, 0.9), 1.4, true)
	# золотая оправа: кольцо-пояс и колпачок на кончике
	_handle(_arc_pts(dc, 21, 5, 0.0, PI), gold, 3.2)
	_handle(PackedVector2Array([dc + Vector2(-5, -36), dc + Vector2(0, -44), dc + Vector2(5, -36)]), gold, 3.0)
	_ci.draw_circle(dc + Vector2(0, -45), 2.6, _c(gold), true, -1.0, true)
	_gem(dc + Vector2(0, 5.5), 3.0, 3.0, Color("#FF8A2A"), t, 6)


# ---------- 8. Лунный кубок ----------

static func _moon(t: float) -> void:
	var silver := Color("#DCE4F5")
	_glow(Vector2(0, -30), 40, GLOW[7], 0.4)
	# полумесяц над кубком
	var mc := Vector2(2, -33)
	var cres := PackedVector2Array()
	for i in 25:
		var a := lerpf(0.9, TAU - 0.9, i / 24.0)
		cres.append(mc + Vector2(cos(a), sin(a)) * 15.0)
	var ic := mc + Vector2(6, 0)
	var r1 := Vector2(15.0 * cos(0.9) - 6.0, 15.0 * sin(0.9)).length()
	var e := atan2(15.0 * sin(0.9), 15.0 * cos(0.9) - 6.0)
	for i in range(1, 24):
		var a := lerpf(-e, -(TAU - e), i / 24.0)
		cres.append(ic + Vector2(cos(a), sin(a)) * r1)
	if _ghost.a > 0.0:
		_poly(cres, Color.WHITE)
	else:
		_ci.draw_colored_polygon(cres, Color("#FFF2B8"))
		var o := cres.duplicate()
		o.append(cres[0])
		_ci.draw_polyline(o, Color(OUT, 0.85), 1.2, true)
		_ci.draw_circle(mc + Vector2(-9, -3), 1.8, Color("#E8D48A"), true, -1.0, true)
		_ci.draw_circle(mc + Vector2(-8, 6), 1.3, Color("#E8D48A"), true, -1.0, true)
		for i in 3:
			var p: Vector2 = [Vector2(-20, -40), Vector2(19, -44), Vector2(22, -24)][i]
			var tw := 0.6 + 0.4 * sin(t * 3.0 + i * 2.0)
			_star(p, 4.0 * tw, Color(1, 0.97, 0.8, 0.95))
	# стерженёк к полумесяцу
	_handle(PackedVector2Array([Vector2(0, -14), Vector2(0, -19)]), silver, 2.4)
	# тонкий высокий кубок
	_handle(_arc_pts(Vector2(-17, -2), 6, 9, -PI * 0.5, -PI * 1.5), silver, 3.4)
	_handle(_arc_pts(Vector2(17, -2), 6, 9, -PI * 0.5, PI * 0.5), silver, 3.4)
	_lathe([Vector2(17, -14), Vector2(17, -6), Vector2(14, 4), Vector2(8, 12), Vector2(4, 16)], silver)
	_mouth(-14, 17, silver, Color("#2A3366"))
	if _ghost.a <= 0.0:
		_ci.draw_circle(Vector2(0, 0), 4.2, Color("#FFFFFF"), true, -1.0, true)
		_ci.draw_circle(Vector2(-1.2, -1.2), 1.6, Color(1, 1, 1, 1), true, -1.0, true)
		_ci.draw_circle(Vector2(0, 0), 4.2, Color("#C8D2F5"), false, 1.0, true)
	_lathe([Vector2(3.5, 15), Vector2(3, 32), Vector2(6, 35), Vector2(3.5, 38)], silver)
	_lathe([Vector2(7, 38), Vector2(18, 44), Vector2(19, 47), Vector2(18, 50)], silver.darkened(0.1))


# ---------- 9. Фонарь светлячков ----------

static func _fireflies(t: float) -> void:
	var gold := Color("#FFC94A")
	_glow(Vector2(0, -2), 44, GLOW[8], 0.42)
	# ручки-ушки
	_handle(_arc_pts(Vector2(-22, -6), 8, 12, -PI * 0.55, -PI * 1.45), gold)
	_handle(_arc_pts(Vector2(22, -6), 8, 12, -PI * 0.45, PI * 0.45), gold)
	# банка
	var jar := [Vector2(14, -26), Vector2(16, -22), Vector2(22, -16), Vector2(23, 10), Vector2(21, 20), Vector2(17, 24)]
	_lathe(jar, Color("#BFE8D8"), false, true, 0.45)
	# светлячки внутри
	if _ghost.a <= 0.0:
		_ci.draw_colored_polygon(_ell(Vector2(0, 2), 17, 18), Color(0.85, 1.0, 0.4, 0.18))
		for i in 6:
			var ph := i * 1.9
			var p := Vector2(sin(t * (0.9 + i * 0.13) + ph) * 13.0, -2 + cos(t * (0.7 + i * 0.11) + ph * 1.3) * 15.0)
			var b := 0.55 + 0.45 * sin(t * 3.0 + ph * 2.0)
			_ci.draw_circle(p, 5.5, Color(0.85, 1.0, 0.3, 0.25 * b), true, -1.0, true)
			_ci.draw_circle(p, 2.4, Color(0.95, 1.0, 0.55, 0.95 * b), true, -1.0, true)
		_ci.draw_line(Vector2(-15, -14), Vector2(-15, 12), Color(1, 1, 1, 0.65), 2.2, true)
		_ci.draw_line(Vector2(15, -10), Vector2(15, -2), Color(1, 1, 1, 0.4), 1.4, true)
	# крышка и листик
	_lathe([Vector2(16, -32), Vector2(17, -28), Vector2(15, -25)], gold)
	_lathe([Vector2(5, -38), Vector2(7, -34), Vector2(12, -32)], gold)
	_leaf(Vector2(3, -36), 13, 4, -0.5, Color("#5BC27E"))
	# подставка
	_lathe([Vector2(14, 24), Vector2(10, 28), Vector2(5, 32), Vector2(5, 38)], gold)
	_lathe([Vector2(9, 38), Vector2(21, 43), Vector2(22, 47), Vector2(21, 50)], gold.darkened(0.08))
	_gem(Vector2(0, 44), 3.0, 3.0, Color("#C6F04A"), t, 6)


# ---------- 10. Кристальная корона ----------

static func _crown(t: float) -> void:
	var gold := Color("#FFC94A")
	_glow(Vector2(0, -8), 46, GLOW[9], 0.4)
	# бархатная подушка с золотыми кисточками
	var cush := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var x := cos(a)
		var y := sin(a)
		cush.append(Vector2(x * 40 * (1.0 - 0.08 * y * y), 33 + y * 12 * (1.0 + 0.25 * x * x)))
	if _ghost.a > 0.0:
		_poly(cush, Color.WHITE)
	else:
		var cols := PackedColorArray()
		for p in cush:
			cols.append(Color("#8A1F7A").lerp(Color("#D14FB8"), clampf((40.0 - p.y) / 14.0, 0.0, 1.0)))
		_ci.draw_polygon(cush, cols)
		var o := cush.duplicate()
		o.append(cush[0])
		_ci.draw_polyline(o, Color(OUT, 0.9), 1.3, true)
		_ci.draw_line(Vector2(-30, 26), Vector2(-8, 24), Color(1, 0.8, 0.95, 0.5), 2.0, true)
		for sx in [-1.0, 1.0]:
			_ci.draw_circle(Vector2(sx * 39, 34), 3.2, gold, true, -1.0, true)
			_ci.draw_colored_polygon(PackedVector2Array([Vector2(sx * 39 - 2.5, 35), Vector2(sx * 39 + 2.5, 35), Vector2(sx * 39 + 1.5, 45), Vector2(sx * 39 - 1.5, 45)]), gold.darkened(0.1))
	# корона: обруч и пять зубцов
	var hue := fposmod(t * 0.08, 1.0)
	var band := PackedVector2Array([Vector2(-27, 26), Vector2(27, 26), Vector2(28, 12), Vector2(-28, 12)])
	var crown := PackedVector2Array([Vector2(-28, 14), Vector2(-33, -16), Vector2(-17, -2), Vector2(-9, -26), Vector2(0, -6), Vector2(9, -26),
		Vector2(17, -2), Vector2(33, -16), Vector2(28, 14)])
	if _ghost.a > 0.0:
		_poly(crown, Color.WHITE)
		_poly(band, Color.WHITE)
	else:
		var cc := PackedColorArray()
		for p in crown:
			cc.append(_metal(gold, p.x / 33.0))
		_ci.draw_polygon(crown, cc)
		var o := crown.duplicate()
		o.append(crown[0])
		_ci.draw_polyline(o, Color(OUT, 0.9), 1.3, true)
		var bc := PackedColorArray()
		for p in band:
			bc.append(_metal(gold.darkened(0.05), p.x / 28.0))
		_ci.draw_polygon(band, bc)
		var ob := band.duplicate()
		ob.append(band[0])
		_ci.draw_polyline(ob, Color(OUT, 0.9), 1.3, true)
		_ci.draw_line(Vector2(-26, 15), Vector2(26, 15), gold.lightened(0.5), 1.2, true)
	# самоцветы на зубцах и обруче — переливаются радугой
	var tips := [Vector2(-33, -16), Vector2(-9, -26), Vector2(9, -26), Vector2(33, -16)]
	for i in tips.size():
		var col := Color.from_hsv(fposmod(hue + i * 0.22, 1.0), 0.55, 1.0)
		_ci.draw_circle(tips[i], 4.5, _c(col), true, -1.0, true)
		if _ghost.a <= 0.0:
			_ci.draw_circle(tips[i] + Vector2(-1.3, -1.3), 1.5, Color(1, 1, 1, 0.9), true, -1.0, true)
			_ci.draw_circle(tips[i], 4.5, Color(OUT, 0.9), false, 1.1, true)
	_gem(Vector2(0, 4), 7, 9, Color.from_hsv(fposmod(hue + 0.85, 1.0), 0.6, 1.0), t, 8)
	for i in 4:
		var x: float = [-19.0, -9.0, 9.0, 19.0][i]
		_gem(Vector2(x, 19), 3.4, 3.4, Color.from_hsv(fposmod(hue + 0.12 + i * 0.25, 1.0), 0.6, 1.0), t + i, 6)
