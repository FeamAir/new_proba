extends RefCounted
## Герои Cascado — совёнок, аксолотль и щенок — и вещи гардероба. Всё рисуется кодом.
## Использование: Hero.new().draw(canvas_item, "owl", центр, масштаб, наряд, время, react)
##   наряд — словарь слот -> id вещи (scripts/meta.gd), react — секунд с последнего касания.
## Герой нарисован в своих координатах: туловище около (0, 0), ширина ~200, ноги на y ≈ 115.
## У каждого героя свои точки крепления вещей (_anchors): макушка, глаза, шея, спина.
##
## Объём («мягкая 3D-игрушка»): каждая округлая деталь — сетка треугольников с цветом в вершинах.
## Цвет вершины считается по «нормали» как у шара: свет сверху-слева, тень снизу-справа,
## подсветка контура справа-снизу и мягкий блик. Сетки считаются один раз и кэшируются (_cache),
## в кадре только сдвигаются — поэтому рисование дешёвое.

const OUT := Color("#1E1236")
const AMBER := Color("#FFB547")
const BLUSH := Color(1.0, 0.42, 0.62, 0.62)
const REACT_TIME := 1.3
## Направление света (на зрителя — +z), нормировано
const LIGHT := Vector3(-0.48, -0.70, 0.53)
## Кольца сетки (доля радиуса): гуще к краю, где освещение меняется быстрее
const RINGS := [0.45, 0.72, 0.88, 0.965, 1.0]
const EYE_DARK := Color("#1A0E30")

const PALETTES := {
	"owl": {
		"": {"body": Color("#9270E0"), "dark": Color("#6446B8"), "belly": Color("#E2D6FF"), "face": Color("#F6F0FF"), "iris": Color("#FFB23E")},
		"skin_mint": {"body": Color("#4CC79E"), "dark": Color("#2C9474"), "belly": Color("#D2F8E8"), "face": Color("#F0FFF8"), "iris": Color("#FFC24A")},
		"skin_moon": {"body": Color("#9DB0E4"), "dark": Color("#6A7CB8"), "belly": Color("#EBF0FF"), "face": Color("#FAFBFF"), "iris": Color("#7FD8FF")},
		"skin_gold": {"body": Color("#F2B240"), "dark": Color("#C27E1E"), "belly": Color("#FFEBB5"), "face": Color("#FFF9E6"), "iris": Color("#FF8A3D")},
	},
	"axolotl": {
		"": {"body": Color("#FFB5D0"), "dark": Color("#EE86AC"), "belly": Color("#FFE9F2"), "gill": Color("#FF4E92"), "tip": Color("#FFC4DC")},
		"skin_mint": {"body": Color("#97E8C6"), "dark": Color("#5FC49D"), "belly": Color("#E8FFF6"), "gill": Color("#16B58A"), "tip": Color("#B8F7DF")},
		"skin_moon": {"body": Color("#D8DEFA"), "dark": Color("#A6B0E0"), "belly": Color("#F9FAFF"), "gill": Color("#7682FF"), "tip": Color("#D6DAFF")},
		"skin_gold": {"body": Color("#FFCF70"), "dark": Color("#E8A848"), "belly": Color("#FFF3D2"), "gill": Color("#FF7428"), "tip": Color("#FFD6A6")},
	},
}

## Общий кэш сеток (на все экземпляры): ключ — параметры детали
static var _cache := {}

var ci: CanvasItem
var _rid: RID
## Текущее локальное преобразование деталей (голова/вещь) внутри координат героя
var _T := Transform2D.IDENTITY


# ---------- Объёмные сетки ----------

static func _store(key, ms) -> void:
	if _cache.size() > 4000:
		_cache.clear()
	_cache[key] = ms


static func _mat(base: Color, spec := 0.4) -> Dictionary:
	var key := ["m", base, spec]
	if _cache.has(key):
		return _cache[key]
	var m := {
		"hi": base.lerp(Color(1.0, 0.98, 0.95), 0.42),
		"mid": base,
		"lo": base.darkened(0.32).lerp(Color("#5A2C86"), 0.3),
		"rim": base.lerp(Color(1.0, 0.93, 1.0), 0.62),
		"spec": spec, "a": base.a, "over": false}
	_store(key, m)
	return m


## Материал-«накладка»: только тень и свет поверх плоского узора (полоски, горошек)
static func _over_mat() -> Dictionary:
	return {"hi": Color(1, 1, 1, 0.4), "mid": Color(1, 1, 1, 0), "lo": Color(0.16, 0.02, 0.3, 0.5),
		"rim": Color(1, 1, 1, 0.3), "spec": 0.5, "a": 1.0, "over": true}


static func _shade(n: Vector3, m: Dictionary) -> Color:
	var d := n.dot(LIGHT)
	var k := clampf(d * 0.6 + 0.45, 0.0, 1.0)
	var rim := pow(clampf(1.0 - n.z, 0.0, 1.0), 2.0) * clampf(0.75 * n.x + 0.45 * n.y + 0.1, 0.0, 1.0)
	var h := Vector3(LIGHT.x, LIGHT.y, LIGHT.z + 1.0).normalized()
	var s: float = pow(maxf(n.dot(h), 0.0), 22.0) * m.spec
	var c: Color
	if m.over:
		var lo: Color = m.lo
		if k < 0.6:
			c = lo.lerp(Color(lo, 0.0), smoothstep(0.05, 0.6, k))
		else:
			c = Color(1, 1, 1, 0).lerp(m.hi, smoothstep(0.62, 1.0, k))
		c = c.lerp(m.rim, rim * 0.7) if c.a < 0.01 else c
		c = c.lerp(Color(1, 1, 1, 0.9), s)
		return c
	c = (m.lo as Color).lerp(m.mid, smoothstep(0.05, 0.6, k))
	c = c.lerp(m.hi, smoothstep(0.62, 1.0, k))
	c = c.lerp(m.rim, rim * 0.7)
	c = c.lerp(Color.WHITE, s)
	c.a = m.a
	return c


## Сетка «надутой» фигуры по контуру (контур должен быть виден целиком из ctr).
## flat > 1 — фигура площе (мягче тени у края).
static func _build(outline: PackedVector2Array, ctr: Vector2, m: Dictionary, flat := 1.0) -> Array:
	var n := outline.size()
	var pts := PackedVector2Array([ctr])
	var cols := PackedColorArray([_shade(Vector3(0, 0, 1), m)])
	var nr: Array[Vector2] = []
	for i in n:
		var tg := outline[(i + 1) % n] - outline[(i - 1 + n) % n]
		var v := Vector2(tg.y, -tg.x).normalized()
		if v.dot(outline[i] - ctr) < 0.0:
			v = -v
		nr.append(v)
	for f in RINGS:
		var z: float = sqrt(maxf(1.0 - f * f, 0.0)) * flat
		for i in n:
			pts.append(ctr + (outline[i] - ctr) * f)
			var nv: Vector2 = nr[i] * f
			cols.append(_shade(Vector3(nv.x, nv.y, z).normalized(), m))
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	for r in RINGS.size() - 1:
		var a0 := 1 + r * n
		var b0 := a0 + n
		for i in n:
			var j := (i + 1) % n
			idx.append_array([a0 + i, b0 + i, b0 + j, a0 + i, b0 + j, a0 + j])
	var ep := PackedVector2Array()
	var ec := PackedColorArray()
	var last := 1 + (RINGS.size() - 1) * n
	for i in n + 1:
		ep.append(pts[last + i % n])
		ec.append(cols[last + i % n])
	return [pts, cols, idx, ep, ec]


## Мягкое пятно: цвет в центре, к краю прозрачнее (тень, румянец, свечение)
static func _build_glow(rx: float, ry: float, rot: float, col: Color) -> Array:
	var n := 28
	var pts := PackedVector2Array([Vector2.ZERO])
	var cols := PackedColorArray([col])
	var fs := [0.45, 0.75, 1.0]
	var al := [0.8, 0.38, 0.0]
	for r in 3:
		for i in n:
			var a := TAU * i / n
			pts.append(Vector2(cos(a) * rx, sin(a) * ry).rotated(rot) * fs[r])
			cols.append(Color(col, col.a * al[r]))
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	for r in 2:
		var a0 := 1 + r * n
		var b0 := a0 + n
		for i in n:
			var j := (i + 1) % n
			idx.append_array([a0 + i, b0 + i, b0 + j, a0 + i, b0 + j, a0 + j])
	return [pts, cols, idx]


func _put(ms: Array, off: Vector2, edge := 1.4) -> void:
	var t := _T * Transform2D(0.0, off)
	RenderingServer.canvas_item_add_triangle_array(_rid, ms[2], t * (ms[0] as PackedVector2Array), ms[1])
	if edge > 0.0 and ms.size() > 3:
		ci.draw_polyline_colors(t * (ms[3] as PackedVector2Array), ms[4], edge, true)


## Объёмный эллипс (шарик)
func _ball(c: Vector2, rx: float, ry: float, base: Color, rot := 0.0, flat := 1.0, spec := 0.4, edge := 1.4) -> void:
	rot = snappedf(rot, 0.02)
	var key := ["b", rx, ry, rot, base, flat, spec]
	var ms = _cache.get(key)
	if ms == null:
		var nseg := clampi(int(maxf(rx, ry) * 0.45) + 12, 14, 44)
		ms = _build(_ell(Vector2.ZERO, rx, ry, rot, nseg), Vector2.ZERO, _mat(base, spec), flat)
		_store(key, ms)
	_put(ms, c, edge)


## Шарик с кэшем по грубому углу rs и точным доворотом extra (для шевелящихся деталей), без контура
func _ball_r(c: Vector2, rx: float, ry: float, base: Color, rs: float, extra: float) -> void:
	var key := ["br", rx, ry, rs, base]
	var ms = _cache.get(key)
	if ms == null:
		ms = _build(_ell(Vector2.ZERO, rx, ry, rs, 14), Vector2.ZERO, _mat(base, 0.3), 1.0)
		_store(key, ms)
	var t := _T * Transform2D(extra, c)
	RenderingServer.canvas_item_add_triangle_array(_rid, ms[2], t * (ms[0] as PackedVector2Array), ms[1])


## Объёмная фигура по контуру; key — для кэша (null — не кэшировать)
func _shape(key, outline: PackedVector2Array, ctr: Vector2, base: Color, flat := 1.0, spec := 0.4, edge := 1.4) -> void:
	var ms = _cache.get(key) if key != null else null
	if ms == null:
		ms = _build(outline, ctr, _mat(base, spec), flat)
		if key != null:
			_store(key, ms)
	_put(ms, Vector2.ZERO, edge)


## Тень-и-свет поверх плоского узора
func _overlay(key, outline: PackedVector2Array, ctr: Vector2, flat := 1.0) -> void:
	var ms = _cache.get(key) if key != null else null
	if ms == null:
		ms = _build(outline, ctr, _over_mat(), flat)
		if key != null:
			_store(key, ms)
	_put(ms, Vector2.ZERO, 0.0)


func _glow(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	col.a = snappedf(col.a, 0.04)
	var key := ["g", rx, ry, snappedf(rot, 0.02), col]
	var ms = _cache.get(key)
	if ms == null:
		ms = _build_glow(rx, ry, rot, col)
		_store(key, ms)
	_put(ms, c, 0.0)


# ---------- Простые фигуры (в координатах героя, через _T) ----------

static func _ell(c: Vector2, rx: float, ry: float, rot := 0.0, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _fill(pts: PackedVector2Array, col: Color, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	var q := _T * pts
	ci.draw_colored_polygon(q, col)
	q.append(q[0])
	if w > 0.0:
		ci.draw_polyline(q, outline, w, true)
	else:
		ci.draw_polyline(q, col, 1.2, true)  # сглаживает край


## Многоугольник с вертикальным градиентом (сверху top, снизу bot)
func _vgrad(pts: PackedVector2Array, top: Color, bot: Color, edge := true) -> void:
	var y0 := INF
	var y1 := -INF
	for v in pts:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var cols := PackedColorArray()
	for v in pts:
		cols.append(top.lerp(bot, (v.y - y0) / maxf(y1 - y0, 0.001)))
	var q := _T * pts
	ci.draw_polygon(q, cols)
	if edge:
		q.append(q[0])
		cols.append(cols[0])
		ci.draw_polyline_colors(q, cols, 1.2, true)


func _oval(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	_fill(_ell(c, rx, ry, rot, clampi(int(maxf(rx, ry) * 0.6) + 12, 14, 40)), col, outline, w)


func _dot(c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(_T * c, r * _T.get_scale().x, col, true, -1.0, true)


func _line(pts: PackedVector2Array, col: Color, w: float) -> void:
	var q := _T * pts
	var k := _T.get_scale().x
	ci.draw_polyline(q, col, w * k, true)
	ci.draw_circle(q[0], w * k / 2.0, col, true, -1.0, true)
	ci.draw_circle(q[q.size() - 1], w * k / 2.0, col, true, -1.0, true)


func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, w: float, n := 12) -> void:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_line(pts, col, w)


func _sparkle(c: Vector2, r: float, col: Color) -> void:
	_fill(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.22, -r * 0.22), c + Vector2(r, 0), c + Vector2(r * 0.22, r * 0.22),
		c + Vector2(0, r), c + Vector2(-r * 0.22, r * 0.22), c + Vector2(-r, 0), c + Vector2(-r * 0.22, -r * 0.22)]), col)


## Гранёный камень: четыре грани разной яркости и блик
func _gem(c: Vector2, r: float, col: Color) -> void:
	var top := c + Vector2(0, -r)
	var rt := c + Vector2(r * 0.8, -r * 0.2)
	var bot := c + Vector2(0, r)
	var lf := c + Vector2(-r * 0.8, -r * 0.2)
	var mid := c + Vector2(0, -r * 0.15)
	ci.draw_colored_polygon(_T * PackedVector2Array([top, mid, lf]), col.lightened(0.45))
	ci.draw_colored_polygon(_T * PackedVector2Array([top, rt, mid]), col.lightened(0.15))
	ci.draw_colored_polygon(_T * PackedVector2Array([lf, mid, bot]), col)
	ci.draw_colored_polygon(_T * PackedVector2Array([mid, rt, bot]), col.darkened(0.35))
	var o := _T * PackedVector2Array([top, rt, bot, lf, top])
	ci.draw_polyline(o, col.darkened(0.45), maxf(1.0, r * 0.14) * _T.get_scale().x, true)
	_dot(c + Vector2(-r * 0.28, -r * 0.45), r * 0.17, Color(1, 1, 1, 0.95))


## Скругление углов ломаной (замкнутой) — срезание углов Чайкина
static func _chaikin(pts: PackedVector2Array, it: int) -> PackedVector2Array:
	for _k in it:
		var o := PackedVector2Array()
		var n := pts.size()
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			o.append(a.lerp(b, 0.25))
			o.append(a.lerp(b, 0.75))
		pts = o
	return pts


func _heart(c: Vector2, half_w: float, n := 28) -> PackedVector2Array:
	var s := half_w / 16.0
	var pts := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)) - 3.0) * s)
	return pts


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
	_rid = target.get_canvas_item()
	_T = Transform2D.IDENTITY
	var breath := 1.0 + 0.018 * sin(t * 2.2)
	var sway := 0.025 * sin(t * 1.25)
	if kind == "puppy" and not head_only:
		# при касании щенок радостно подпрыгивает (два прыжка)
		pos.y -= absf(sin(clampf(react / REACT_TIME, 0.0, 1.0) * TAU)) * 14.0 * sc * react_env(react)
	ci.draw_set_transform(pos, sway, Vector2(sc, sc * breath))
	var p := palette(kind, outfit)
	if kind == "puppy":
		_puppy(p, outfit, t, react, head_only)
	elif kind == "axolotl":
		_axolotl(p, outfit, t, react, head_only)
	else:
		_owl(p, outfit, t, react, head_only)
	_T = Transform2D.IDENTITY
	ci.draw_set_transform(Vector2.ZERO)


## Аватарка: голова героя в наряде, в круге.
func draw_avatar(target: CanvasItem, kind: String, c: Vector2, r: float, outfit: Dictionary, t: float, ring: Color, react := 99.0) -> void:
	target.draw_circle(c, r + 4, OUT, true, -1.0, true)
	target.draw_circle(c, r, Color("#2A1A4F"), true, -1.0, true)
	target.draw_circle(c + Vector2(0, r * 0.35), r * 0.7, Color(ring, 0.18), true, -1.0, true)
	if kind == "axolotl":
		draw(target, kind, c + Vector2(0, r * 0.22), r / 118.0, outfit, t, react, true)
	elif kind == "puppy":
		draw(target, kind, c + Vector2(0, r * 0.3), r / 118.0, outfit, t, react, true)
	else:
		draw(target, kind, c + Vector2(0, r * 0.12), r / 125.0, outfit, t, react, true)
	target.draw_arc(c, r + 2, 0, TAU, 64, ring, 5.0, true)


# ---------- Точки крепления ----------

func _anchors(kind: String, hp: Callable, tilt: float) -> Dictionary:
	if kind == "puppy":
		# макушка — между висячими ушками; ошейник — под подбородком
		return {"top": hp.call(Vector2(0, -106)), "top_w": 100.0, "tilt": tilt,
			"eye_l": hp.call(Vector2(-38, -44)), "eye_r": hp.call(Vector2(38, -44)), "eye_rad": 24.0, "temple": 92.0,
			"neck": Vector2(0, 42), "neck_w": 124.0, "back": Vector2(0, 66), "back_w": 136.0, "kind": kind}
	if kind == "axolotl":
		return {"top": Vector2(0, -92), "top_w": 116.0, "tilt": tilt,
			"eye_l": Vector2(-44, -30), "eye_r": Vector2(44, -30), "eye_rad": 22.0, "temple": 96.0,
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
	var TH := Transform2D(tilt, pivot + Vector2(shift, 0)) * Transform2D(0.0, -pivot)
	var a := _anchors("owl", hp, tilt)
	var body: Color = p.body
	var dark: Color = p.dark

	if not head_only:
		_glow(Vector2(0, 118), 92, 15, Color(0.03, 0.0, 0.1, 0.5))
	_back_items(outfit, a, t, true)

	# Крылышки (за туловищем), при касании взмахивают
	var flap := 0.35 * env * sin(react * 18.0)
	for sx in [-1.0, 1.0]:
		var rot: float = -sx * (0.3 + flap)
		var wc := Vector2(sx * 80, 36)
		_ball(wc, 27, 50, dark, rot, 1.1)
		for f in 3:
			var fp: Vector2 = wc + Vector2(sx * 5, 12 + f * 12).rotated(rot)
			_arc(fp, 10, 7, 0.2 * PI, 0.8 * PI, Color(body.lightened(0.2), 0.55), 3.0, 8)

	# Ушки-пёрышки
	_T = TH
	for sx in [-1.0, 1.0]:
		var ek := ["owl_ear", sx, body]
		var e := PackedVector2Array() if _cache.has(ek) else _chaikin(PackedVector2Array([Vector2(sx * 84, -46), Vector2(sx * 58, -60), Vector2(sx * 30, -80), Vector2(sx * 62, -108), Vector2(sx * 92, -138), Vector2(sx * 92, -90)]), 2)
		_shape(ek, e, Vector2(sx * 72, -82), body, 1.2)
		_vgrad(_chaikin(PackedVector2Array([Vector2(sx * 74, -66), Vector2(sx * 52, -78), Vector2(sx * 82, -120), Vector2(sx * 82, -88)]), 1), dark.darkened(0.1), Color(dark, 0.0), false)
	_T = Transform2D.IDENTITY

	# Туловище — пухлое яйцо
	_ball(Vector2(0, 10), 95, 101, body, 0.0, 1.15)
	# Пушистая грудка с пёрышками-дугами
	_glow(Vector2(0, 60), 66, 52, Color(p.belly, 0.95))
	_ball(Vector2(0, 66), 52, 38, p.belly, 0.0, 2.2, 0.15, 0.0)
	for row in 3:
		var cnt := 4 - row % 2
		for i in cnt:
			var c := Vector2((i - (cnt - 1) / 2.0) * 22, 46 + row * 15)
			_arc(c, 8, 6, 0.2 * PI, 0.8 * PI, Color(dark, 0.32), 2.6, 8)
			_arc(c + Vector2(-1, -2), 6, 4, 0.25 * PI, 0.6 * PI, Color(1, 1, 1, 0.5), 1.6, 6)

	_T = TH
	# Лицевой диск сердечком: объединение двух кругов вокруг глаз
	_shape(["owl_disc", p.face], _owl_disc(), Vector2(0, -30), p.face, 2.4, 0.2, 0.0)
	var dpts := _owl_disc()
	dpts.append(dpts[0])
	_line(dpts, Color(dark, 0.35), 3.0)

	# Румянец
	for sx in [-1.0, 1.0]:
		_glow(Vector2(sx * 62, 4), 17, 10, BLUSH)

	# Большие блестящие глаза
	var b := blink(t)
	var happy := env > 0.55 and absf(turn) < 0.6
	for sx in [-1.0, 1.0]:
		var ec := Vector2(sx * 37, -30)
		if happy:
			_arc(ec + Vector2(0, 6), 17, 15, 1.12 * PI, 1.88 * PI, EYE_DARK, 6.0)
			continue
		if b < 0.3:
			_arc(ec + Vector2(0, -6), 19, 12, 0.15 * PI, 0.85 * PI, EYE_DARK, 6.0)
			continue
		_owl_eye(ec, b, Vector2(turn * 5.0, 0), p)

	# Клюв
	var bk := PackedVector2Array([Vector2(-11, -9), Vector2(-5, -11), Vector2(5, -11), Vector2(11, -9), Vector2(4, 8), Vector2(0, 13), Vector2(-4, 8)])
	_shape(["owl_beak"], bk, Vector2(0, -4), AMBER, 1.0, 0.7, 1.4)
	_T = Transform2D.IDENTITY

	if not head_only:
		for sx in [-1.0, 1.0]:
			for k in 3:
				_ball(Vector2(sx * 32 + (k - 1) * 11, 108), 7, 9, AMBER, 0.0, 1.0, 0.5)

	_front_items(outfit, a, t)


func _owl_disc() -> PackedVector2Array:
	var key := ["owl_disc_pts"]
	if _cache.has(key):
		return _cache[key]
	var pts := PackedVector2Array()
	var r := 46.0
	var cy := -30.0
	# Простой способ: обходим лучами из центра (0, cy) и берём дальнюю точку объединения
	for i in 48:
		var th := TAU * i / 48.0
		var d := Vector2(cos(th), sin(th))
		var best := 0.0
		for sx in [-1.0, 1.0]:
			var cc := Vector2(sx * 37, 0)
			var bb := -d.dot(cc)
			var disc := bb * bb - (cc.length_squared() - r * r)
			if disc >= 0.0:
				best = maxf(best, -bb + sqrt(disc))
		pts.append(Vector2(0, cy) + d * best)
	_store(key, pts)
	return pts


func _owl_eye(ec: Vector2, b: float, look: Vector2, p: Dictionary) -> void:
	b = snappedf(b, 0.1)
	_ball(ec, 31, 31 * b, Color("#2A1A4F"), 0.0, 1.4, 0.3, 1.4)
	var e := ec + look
	var iris: Color = p.iris
	_vgrad(_ell(e, 24, 24 * b, 0.0, 28), iris.darkened(0.25), iris.lerp(Color("#FFF3B0"), 0.55))
	_vgrad(_ell(e, 14, 14 * b, 0.0, 22), EYE_DARK, Color("#3A2468"))
	_oval(e + Vector2(-9, -9 * b), 7.5, 6.5 * b, Color(1, 1, 1, 0.97), -0.5)
	_dot(e + Vector2(8, 8 * b), 3.4 * b, Color(1, 1, 1, 0.9))
	_arc(e, 19, 19 * b, 0.15 * PI, 0.55 * PI, Color(1, 1, 1, 0.35), 2.0, 8)


# ---------- Аксолотль ----------

func _axolotl(p: Dictionary, outfit: Dictionary, t: float, react: float, head_only: bool) -> void:
	var env := react_env(react)
	var a := _anchors("axolotl", func(v): return v, 0.0)
	var body: Color = p.body
	var gill: Color = p.gill
	var tipc: Color = p.tip

	if not head_only:
		_glow(Vector2(4, 122), 100, 15, Color(0.03, 0.0, 0.1, 0.5))
		_back_items(outfit, a, t, true)
		_axo_tail(p, t, env, react)
		# Задние лапки
		for sx in [-1.0, 1.0]:
			_ball(Vector2(sx * 34, 108), 17, 12, body.darkened(0.05), sx * 0.2)
		# Туловище
		_ball(Vector2(0, 64), 64, 50, body, 0.0, 1.1)
		_glow(Vector2(-2, 78), 44, 32, Color(p.belly, 0.9))
		# Передние лапки с пальчиками
		for sx in [-1.0, 1.0]:
			var lc := Vector2(sx * 60, 96)
			_ball(lc, 17, 15, body, sx * 0.35, 1.0)
			for k in 3:
				_ball(lc + Vector2(sx * 3 + (k - 1) * 8.5, 11 - absf(k - 1) * 1.5), 4.6, 4.2, body.lerp(Color.WHITE, 0.35), 0.0, 1.0, 0.3, 1.0)

	# Жабры-веточки: по 3 с каждой стороны, шевелятся (при касании — сильнее)
	var amp := 0.06 + 0.32 * env
	var freq := 2.0 + 9.0 * env
	var angles := [-2.45, -2.95, 2.75]
	var lens := [64.0, 68.0, 56.0]
	var bases := [Vector2(-64, -70), Vector2(-88, -42), Vector2(-92, -10)]
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
	# Сначала пушистые ворсинки, поверх — сужающийся стебель и светлый кончик
	for pts in gills:
		for kk in range(2, 13):
			var s := kk / 12.0
			var k0 := mini(kk / 2, 5)
			var q: Vector2 = pts[k0].lerp(pts[k0 + 1], (kk % 2) * 0.5) if kk < 12 else pts[6]
			var tang: Vector2 = (pts[k0 + 1] - pts[k0]).normalized()
			var nrm := tang.orthogonal()
			var ln := 7.0 + 13.0 * sin(minf(s * 1.15, 1.0) * PI * 0.85 + 0.25)
			var wd := 5.6 + 1.2 * sin(s * PI)
			var col := gill.lerp(tipc, 0.05 + s * 0.7)
			col = Color(snappedf(col.r, 0.03), snappedf(col.g, 0.03), snappedf(col.b, 0.03))
			for side in [-1.0, 1.0]:
				var fd: Vector2 = (nrm * side + tang * (0.75 + s * 0.5)).normalized()
				var rs := snappedf(fd.angle(), 0.12)
				_ball_r(q + fd * ln * 0.5, snappedf(ln * 0.6, 0.5), snappedf(wd, 0.25), col, rs, fd.angle() - rs)
	for pts in gills:
		var l := PackedVector2Array()
		var r := PackedVector2Array()
		for k in 7:
			var tang: Vector2 = (pts[mini(k + 1, 6)] - pts[maxi(k - 1, 0)]).normalized()
			var w := lerpf(6.5, 3.0, k / 6.0)
			l.append(pts[k] + tang.orthogonal() * w)
			r.append(pts[k] - tang.orthogonal() * w)
		r.reverse()
		l.append_array(r)
		_fill(l, gill)
		var hl := PackedVector2Array()
		for k in range(0, 6):
			hl.append(pts[k] + Vector2(-0.8, -1.8))
		_line(hl, Color(gill.lerp(Color.WHITE, 0.5), 0.8), 2.2)
		var tg: Vector2 = (pts[6] - pts[5]).normalized()
		_ball(pts[6] + tg * 3.0, 6.5, 6.5, tipc, 0.0, 1.1, 0.45, 1.0)

	# Голова — широкая, мягкая
	_ball(Vector2(0, -22), 102, 75, body, 0.0, 1.15, 0.45)
	# Светлая мордочка
	_glow(Vector2(0, -2), 66, 38, Color(p.belly, 0.6))
	# Румянец и веснушки
	for sx in [-1.0, 1.0]:
		_glow(Vector2(sx * 66, 0), 21, 12, BLUSH)
		for f in [Vector2(56, -8), Vector2(64, -11), Vector2(72, -7)]:
			_dot(Vector2(sx * f.x, f.y), 1.9, Color(gill.darkened(0.15), 0.55))

	# Большие блестящие глаза
	var b := blink(t, 1.3)
	var happy := env > 0.5
	for sx in [-1.0, 1.0]:
		var ec := Vector2(sx * 44, -30)
		if happy:
			_arc(ec + Vector2(0, 6), 13, 12, 1.1 * PI, 1.9 * PI, EYE_DARK, 5.5)
			continue
		if b < 0.3:
			_arc(ec + Vector2(0, -3), 13, 8, 0.15 * PI, 0.85 * PI, EYE_DARK, 5.0)
			continue
		_axo_eye(ec, b, p)

	# Ротик: маленькая улыбка; при касании — открытый счастливый
	var mc := Vector2(0, -6)
	if env > 0.05:
		var o := env
		var m := PackedVector2Array()
		for i in 13:
			var a2 := lerpf(0.0, PI, i / 12.0)
			m.append(mc + Vector2(cos(a2) * 13.0, -1.0 + sin(a2) * (4.0 + 11.0 * o)))
		_vgrad(m, Color("#8E2C58"), Color("#B5406E"))
		_glow(mc + Vector2(0, 3 + 7 * o), 7 + 3 * o, 3 + 3 * o, Color("#FF7FA6"))
		var top := PackedVector2Array()
		for i in 9:
			top.append(mc + Vector2(lerpf(-13, 13, i / 8.0), -1.0))
		_line(top, Color("#7A2A4C"), 3.0)
	else:
		var mouth := PackedVector2Array()
		for i in 11:
			var a2 := lerpf(0.15 * PI, 0.85 * PI, i / 10.0)
			mouth.append(mc + Vector2(cos(a2) * 13.0, -5.0 + sin(a2) * 7.0))
		_line(mouth, Color("#7A2A4C"), 3.6)

	_front_items(outfit, a, t)


func _axo_eye(ec: Vector2, b: float, p: Dictionary) -> void:
	b = snappedf(b, 0.1)
	var rx := 15.5
	var ry := 18.0 * b
	var key := ["axo_eye", b, p.gill]
	var ms = _cache.get(key)
	if ms == null:
		var outl := _ell(Vector2.ZERO, rx, ry, 0.0, 30)
		var low: Color = (p.gill as Color).darkened(0.25).lerp(Color("#6A3AB0"), 0.4)
		var pts := PackedVector2Array([Vector2(0, ry * 0.1)])
		var cols := PackedColorArray([EYE_DARK.lerp(low, 0.35)])
		for v in outl:
			pts.append(v)
			cols.append(EYE_DARK.lerp(low, clampf(v.y / maxf(ry, 1.0) * 0.9 + 0.1, 0.0, 1.0)))
		var idx := PackedInt32Array()
		for i in 30:
			idx.append_array([0, 1 + i, 1 + (i + 1) % 30])
		var ep := PackedVector2Array()
		var ec2 := PackedColorArray()
		for i in 31:
			ep.append(pts[1 + i % 30])
			ec2.append(cols[1 + i % 30])
		ms = [pts, cols, idx, ep, ec2]
		_store(key, ms)
	_put(ms, ec, 1.6)
	# большой и маленький блики
	_oval(ec + Vector2(-5, -7 * b), 6.0, 6.4 * b, Color(1, 1, 1, 0.97), -0.4)
	_dot(ec + Vector2(5.5, 6.5 * b), 2.6 * b, Color(1, 1, 1, 0.92))
	_dot(ec + Vector2(1.5, -10 * b), 1.4 * b, Color(1, 1, 1, 0.7))


func _axo_tail(p: Dictionary, t: float, env: float, react: float) -> void:
	var body: Color = p.body
	var sway := sin(t * 1.6) * 0.18 + env * 0.3 * sin(react * 10.0)
	var p0 := Vector2(20, 96)
	var n := 15
	var mid := PackedVector2Array()
	var nrm: Array[Vector2] = []
	var ws: Array[float] = []
	var fins: Array[float] = []
	for i in n:
		var s := i / float(n - 1)
		var c := p0.bezier_interpolate(Vector2(90, 122), Vector2(150, 96), Vector2(158, 34), s)
		mid.append(p0 + (c - p0).rotated(-sway * s))
	for i in n:
		var s := i / float(n - 1)
		var tang := (mid[mini(i + 1, n - 1)] - mid[maxi(i - 1, 0)]).normalized()
		nrm.append(tang.orthogonal())
		ws.append(20.0 * (1.0 - s) + 2.5)
		fins.append(14.0 * sin(minf(s * 1.15, 1.0) * PI) + 2.0)
	# Кэш цветов (зависит только от палитры): плавник — 4 полосы, хвост — 5 полос
	var key := ["tail_cols", body, p.tip]
	var cc = _cache.get(key)
	if cc == null:
		var m := _mat(body, 0.35)
		var fin_edge := Color((p.gill as Color).lerp(p.tip, 0.45), 0.9)
		var fin_in: Color = body.lerp(p.gill, 0.3)
		var tube := PackedColorArray()
		var fs := [1.0, 0.55, 0.0, -0.55, -1.0]
		for i in n:
			var nv := Vector2(0, -1).rotated(-0.5 + i * 0.12)  # грубая нормаль для света вдоль хвоста
			for f in fs:
				var v2: Vector2 = nv * f
				tube.append(_shade(Vector3(v2.x, v2.y, sqrt(maxf(1.0 - f * f, 0.0)) * 1.1).normalized(), m))
		cc = [fin_edge, fin_in, tube]
		_store(key, cc)
	# Плавник-гребень: полупрозрачная перепонка от тела к светлому краю
	var fpts := PackedVector2Array()
	var fcols := PackedColorArray()
	for i in n:
		fpts.append(mid[i] + nrm[i] * (ws[i] + fins[i]))
		fcols.append(cc[0])
		fpts.append(mid[i] + nrm[i] * ws[i] * 0.6)
		fcols.append(cc[1])
		fpts.append(mid[i] - nrm[i] * ws[i] * 0.6)
		fcols.append(cc[1])
		fpts.append(mid[i] - nrm[i] * (ws[i] + fins[i] * 0.6))
		fcols.append(cc[0])
	var fidx := PackedInt32Array()
	for i in n - 1:
		for j in 3:
			var a0 := i * 4 + j
			var b0 := a0 + 4
			fidx.append_array([a0, b0, b0 + 1, a0, b0 + 1, a0 + 1])
	RenderingServer.canvas_item_add_triangle_array(_rid, fidx, fpts, fcols)
	var edge := PackedVector2Array()
	for i in n:
		edge.append(fpts[i * 4])
	for i in range(n - 1, -1, -1):
		edge.append(fpts[i * 4 + 3])
	ci.draw_polyline(edge, cc[0], 1.4, true)
	# Лучики плавника
	for i in range(2, n - 1, 2):
		ci.draw_line(mid[i] + nrm[i] * ws[i], mid[i] + nrm[i] * (ws[i] + fins[i] * 0.85), Color(p.gill, 0.22), 1.5, true)
	# Сам хвост — объёмная трубка
	var tpts := PackedVector2Array()
	var fs2 := [1.0, 0.55, 0.0, -0.55, -1.0]
	for i in n:
		for f in fs2:
			tpts.append(mid[i] + nrm[i] * ws[i] * f)
	var tidx := PackedInt32Array()
	for i in n - 1:
		for j in 4:
			var a0 := i * 5 + j
			var b0 := a0 + 5
			tidx.append_array([a0, b0, b0 + 1, a0, b0 + 1, a0 + 1])
	RenderingServer.canvas_item_add_triangle_array(_rid, tidx, tpts, cc[2])


# ---------- Вещи ----------

func _back_items(outfit: Dictionary, a: Dictionary, t: float, behind: bool) -> void:
	match outfit.get("back", ""):
		"cape": _cape(a, t, behind)
		"backpack": _backpack(a, t, behind)


func _front_items(outfit: Dictionary, a: Dictionary, t: float) -> void:
	_back_items(outfit, a, t, false)
	match outfit.get("neck", ""):
		"scarf": _scarf(a)
		"bowtie": _bowtie(a)
		"necklace": _necklace(a, t)
	match outfit.get("eyes", ""):
		"crystal_glasses": _crystal_glasses(a, t)
		"sunglasses": _sunglasses(a)
		"monocle": _monocle(a, t)
	match outfit.get("head", ""):
		"bow": _bow(a)
		"cap": _cap(a)
		"miner": _miner(a, t)
		"crown": _crown(a, t)
		"wreath": _wreath(a, t)
	_T = Transform2D.IDENTITY


## Преобразование «головы шириной 100» (от макушки, с наклоном головы)
func _head_T(a: Dictionary) -> Transform2D:
	var k: float = a.top_w / 100.0
	return Transform2D(a.tilt, Vector2(k, k), 0.0, a.top)


func _hv(a: Dictionary, v: Vector2) -> Vector2:
	return a.top + v.rotated(a.tilt) * (a.top_w / 100.0)


func _bow(a: Dictionary) -> void:
	_T = _head_T(a)
	var c := Vector2(30, -2)
	var pink := Color("#FF4FA3")
	# хвостики ленты
	for sx in [-1.0, 1.0]:
		var tl := PackedVector2Array([c + Vector2(sx * 1, 2), c + Vector2(sx * 8, 4), c + Vector2(sx * 17, 22), c + Vector2(sx * 11, 20), c + Vector2(sx * 7, 26), c + Vector2(sx * -2, 8)])
		_shape(["bow_tail", sx], tl, c + Vector2(sx * 7, 12), pink.darkened(0.12), 1.4)
	for sx in [-1.0, 1.0]:
		var lc := c + Vector2(sx * 21, -6)
		_ball(lc, 22, 15.5, pink, sx * -0.35, 1.1, 0.5)
		for d in [Vector2(-7, -5), Vector2(7, 1), Vector2(-1, 7), Vector2(10, -8)]:
			_dot(lc + Vector2(d.x * sx, d.y).rotated(sx * -0.35), 2.4, Color(1, 1, 1, 0.92))
		_glow(c + Vector2(sx * 7, -4), 9, 10, Color("#9E1558", 0.5))
	_ball(c, 8.5, 9.5, pink.darkened(0.08), 0.0, 1.0, 0.6)


func _cap(a: Dictionary) -> void:
	_T = _head_T(a)
	var tip := Vector2(8, -84)
	var bl := Vector2(-37, 4)
	var br := Vector2(37, 4)
	var cone := PackedVector2Array()
	for i in 9:
		cone.append(bl.lerp(tip, i / 8.0))
	for i in range(1, 9):
		cone.append(tip.lerp(br, i / 8.0))
	for i in range(1, 8):
		var s := i / 8.0
		cone.append(Vector2(lerpf(37, -37, s), 4 + sin(s * PI) * 6))
	var ctr := Vector2(3, -18)
	_shape(["cap_cone"], cone, ctr, Color("#33C3F2"), 1.1, 0.35)
	# косые полоски
	var cols := [Color("#FF5FA8"), Color("#FFD93D"), Color("#FF5FA8")]
	for j in 3:
		var s0 := 0.12 + j * 0.27
		var s1 := s0 + 0.11
		var q := PackedVector2Array([bl.lerp(tip, s0 + 0.06), br.lerp(tip, s0 - 0.04), br.lerp(tip, s1 - 0.04), bl.lerp(tip, s1 + 0.06)])
		_fill(q, cols[j])
	for d in [Vector2(-8, -8), Vector2(14, -30), Vector2(2, -54), Vector2(20, -6)]:
		_dot(d, 2.6, Color(1, 1, 1, 0.9))
	_overlay(["cap_over"], cone, ctr, 1.1)
	# рюшка по краю
	for i in 7:
		var s := i / 6.0
		var x := lerpf(-34, 34, s)
		_ball(Vector2(x, 6 + sin(s * PI) * 5), 7, 6, Color("#FFD93D") if i % 2 == 0 else Color("#FF5FA8"), 0.0, 1.0, 0.4, 1.0)
	# помпон
	for d in [Vector2(-6, 2), Vector2(6, 3), Vector2(0, -6), Vector2(-5, -4), Vector2(5, -5)]:
		_ball(tip + d, 7, 7, Color("#FFF2FA"), 0.0, 1.0, 0.3, 1.0)
	_ball(tip + Vector2(0, 0), 8, 8, Color.WHITE, 0.0, 1.0, 0.4, 1.0)


func _miner(a: Dictionary, t: float) -> void:
	_T = _head_T(a)
	var lamp := Vector2(0, -24)
	var fl := 0.2 + 0.05 * sin(t * 3.0)
	# луч фонаря
	var beam := PackedVector2Array([lamp + Vector2(-8, 0), lamp + Vector2(8, 0), Vector2(80, -170), Vector2(-80, -170)])
	ci.draw_polygon(_T * beam, PackedColorArray([Color(1, 0.95, 0.6, fl), Color(1, 0.95, 0.6, fl), Color(1, 0.95, 0.6, 0.0), Color(1, 0.95, 0.6, 0.0)]))
	var dome := PackedVector2Array()
	for i in 21:
		var ang := PI + PI * i / 20.0
		dome.append(Vector2(cos(ang) * 50, 8 + sin(ang) * 50))
	for i in range(1, 6):
		dome.append(Vector2(lerpf(50, -50, i / 6.0), 9))
	_shape(["miner_dome"], dome, Vector2(-4, -16), Color("#FFC83A"), 1.0, 0.75)
	# красная светоотражающая полоса
	var band := PackedVector2Array([Vector2(-49.5, -4), Vector2(49.5, -4), Vector2(50, 6), Vector2(-50, 6)])
	_fill(band, Color("#FF5A3C"))
	_fill(PackedVector2Array([Vector2(-49, -2.5), Vector2(49, -2.5), Vector2(49, -0.5), Vector2(-49, -0.5)]), Color(1, 1, 1, 0.55))
	# гребень
	_shape(["miner_ridge"], PackedVector2Array([Vector2(-6, -46), Vector2(6, -46), Vector2(7, -5), Vector2(-7, -5)]), Vector2(0, -24), Color("#FFD85A"), 1.3, 0.6)
	_overlay(["miner_over"], dome, Vector2(-4, -16), 1.4)
	for sx in [-1.0, 1.0]:
		_ball(Vector2(sx * 30, -24), 3, 3, Color("#FFE9A0"), 0.0, 1.0, 0.8, 0.8)
	_ball(Vector2(0, 8), 60, 9.5, Color("#E8961E"), 0.0, 1.3, 0.5)
	# фонарь: корпус, светящееся стекло, ореол
	_glow(lamp, 46, 46, Color(1.0, 0.93, 0.55, fl * 1.6))
	_ball(lamp, 17, 17, Color("#6E5C86"), 0.0, 1.0, 0.6)
	_ball(lamp, 12, 12, Color("#FFF0A0"), 0.0, 1.4, 0.9, 1.0)
	_dot(lamp + Vector2(-3, -3), 5, Color(1, 1, 1, 0.95))


func _crown(a: Dictionary, t: float) -> void:
	_T = _head_T(a)
	var gold := Color("#FFC83A")
	var pts := PackedVector2Array([Vector2(-42, 8), Vector2(-46, -34), Vector2(-24, -14), Vector2(-12, -46), Vector2(0, -20),
		Vector2(12, -46), Vector2(24, -14), Vector2(46, -34), Vector2(42, 8), Vector2(0, 10)])
	_shape(["crown"], pts, Vector2(0, -8), gold, 1.0, 0.85)
	var band := PackedVector2Array()
	for i in 13:
		band.append(Vector2(lerpf(-44, 44, i / 12.0), -8))
	band.append(Vector2(44, 0))
	for i in 13:
		band.append(Vector2(lerpf(44, -44, i / 12.0), 10))
	band.append(Vector2(-44, 0))
	_shape(["crown_band"], band, Vector2(0, 1), Color("#F4A62A"), 1.8, 0.8)
	var gems := [Color("#FF3B6B"), Color("#3BB8FF"), Color("#2EE59D")]
	for i in 3:
		_gem(Vector2((i - 1) * 27, 1), 8.0 if i == 1 else 7.0, gems[i])
	for v in [Vector2(-46, -34), Vector2(-12, -46), Vector2(12, -46), Vector2(46, -34)]:
		_ball(v, 5.5, 5.5, Color("#FFEFFB"), 0.0, 1.0, 0.9, 1.0)
	var tw := 0.5 + 0.5 * sin(t * 4.0)
	_sparkle(Vector2(-30, -26), 4 + 4 * tw, Color(1, 1, 1, 0.95))
	_sparkle(Vector2(32, -18), 3 + 3 * (1.0 - tw), Color(1, 1, 1, 0.85))


func _wreath(a: Dictionary, t: float) -> void:
	_T = _head_T(a)
	var ring := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 52, 6 + sin(ang) * 14))
	_line(ring, Color("#2D7F4F"), 7.0)
	for i in range(0, 17):
		var v: Vector2 = ring[i]
		var tg: Vector2 = (ring[mini(i + 1, 16)] - ring[maxi(i - 1, 0)]).normalized()
		var up := -1.0 if i % 2 == 0 else 1.0
		var col := Color("#4CC774") if i % 2 == 0 else Color("#36A85E")
		_ball(v + tg.orthogonal() * up * -5.0, 9, 4.5, col, tg.angle() + up * 0.55, 1.2, 0.3, 1.0)
	# цветочки
	for fx in [-36.0, 36.0]:
		var fc := Vector2(fx, 6 + sin(PI + PI * (fx + 52) / 104.0) * 14 + 2)
		for k in 5:
			_dot(fc + Vector2(0, -4.5).rotated(k * TAU / 5.0), 3.6, Color("#FFF4FB"))
		_dot(fc, 2.6, Color("#FFC83A"))
	var caps := [Color("#5FF0D6"), Color("#C38BFF"), Color("#FF8FD0"), Color("#C38BFF"), Color("#5FF0D6")]
	var xs := [-44, -22, 0, 22, 44]
	for i in 5:
		var base := Vector2(xs[i], 6 + sin(PI + PI * (xs[i] + 52) / 104.0) * 14)
		var h := 22.0 if i % 2 == 0 else 16.0
		var glow := 0.3 + 0.18 * sin(t * 3.0 + i)
		_glow(base + Vector2(0, -h), 24, 18, Color(caps[i], glow))
		_shape(["wr_stem", h], PackedVector2Array([base + Vector2(-4.5, 0), base + Vector2(-3, -h), base + Vector2(3, -h), base + Vector2(4.5, 0)]) , base + Vector2(0, -h / 2.0), Color("#F4EEFF"), 1.5, 0.2, 1.0)
		var cap := PackedVector2Array()
		for j in 13:
			var ang := PI + PI * j / 12.0
			cap.append(base + Vector2(0, -h) + Vector2(cos(ang) * 13, sin(ang) * 11))
		cap.append(base + Vector2(0, -h + 2.5))
		_shape(["wr_cap", i], cap, base + Vector2(-2, -h - 4), caps[i], 1.0, 0.6)
		_dot(base + Vector2(-5, -h - 6), 2.2, Color(1, 1, 1, 0.9))
		_dot(base + Vector2(4, -h - 3), 1.6, Color(1, 1, 1, 0.8))


func _crystal_glasses(a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.12
	var frame := Color("#9FF6FF")
	for e in [a.eye_l, a.eye_r]:
		_T = Transform2D(a.tilt, e)
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(Vector2(cos(i * TAU / 6.0 + PI / 6.0), sin(i * TAU / 6.0 + PI / 6.0)) * r)
		_vgrad(hex, Color(0.6, 1.0, 1.0, 0.32), Color(0.8, 0.55, 1.0, 0.3), false)
		var cl := hex.duplicate()
		cl.append(hex[0])
		_line(cl, Color("#2A86B8"), r * 0.26)
		_line(cl, frame, r * 0.13)
		_line(PackedVector2Array([hex[3].lerp(hex[4], 0.15), hex[4], hex[5].lerp(hex[4], 0.6)]), Color(1, 1, 1, 0.85), r * 0.05)
		_line(PackedVector2Array([Vector2(-r * 0.45, r * 0.1), Vector2(-r * 0.05, -r * 0.35)]), Color(1, 1, 1, 0.4), r * 0.1)
		_sparkle(Vector2(-r * 0.5, -r * 0.5), r * (0.16 + 0.08 * sin(t * 4.0)), Color.WHITE)
	_T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r * 0.87, 0).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r * 0.87, 0).rotated(a.tilt)
	ci.draw_line(l, rr, Color("#2A86B8"), r * 0.2, true)
	ci.draw_line(l, rr, frame, r * 0.1, true)
	_gem((l + rr) / 2.0, r * 0.24, Color("#B46CFF"))


func _sunglasses(a: Dictionary) -> void:
	var r: float = a.eye_rad * 1.12
	var bridge := PackedVector2Array()
	for i in 7:
		var s := i / 6.0
		bridge.append(a.eye_l.lerp(a.eye_r, 0.5 + (s - 0.5) * 0.42) + Vector2(0, -r * 0.42 - sin(s * PI) * r * 0.12))
	ci.draw_polyline(bridge, Color("#C81E6A"), r * 0.18, true)
	for e in [a.eye_l, a.eye_r]:
		_T = Transform2D(a.tilt, e)
		var h := _heart(Vector2.ZERO, r * 1.1)
		_vgrad(h, Color("#3A1670"), Color("#FF4FA3"))
		var hc := h.duplicate()
		hc.append(h[0])
		_line(hc, Color("#E0247A"), r * 0.17)
		_line(hc, Color("#FF8CC6"), r * 0.06)
		_line(PackedVector2Array([Vector2(-r * 0.62, -r * 0.2), Vector2(-r * 0.3, -r * 0.55)]), Color(1, 1, 1, 0.7), r * 0.12)
		_line(PackedVector2Array([Vector2(-r * 0.3, r * 0.08), Vector2(-r * 0.05, -r * 0.2)]), Color(1, 1, 1, 0.4), r * 0.08)
	_T = Transform2D.IDENTITY


func _monocle(a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.15
	var e: Vector2 = a.eye_r
	_T = Transform2D(a.tilt, e)
	_glow(Vector2(0, 0), r, r, Color(0.75, 0.95, 1.0, 0.18))
	_arc(Vector2.ZERO, r, r, 0, TAU, Color("#A8651A"), r * 0.26, 40)
	_arc(Vector2.ZERO, r, r, 0, TAU, Color("#FFCB45"), r * 0.15, 40)
	_arc(Vector2.ZERO, r, r, 1.05 * PI, 1.55 * PI, Color("#FFF4C0"), r * 0.06, 12)
	_line(PackedVector2Array([Vector2(-r * 0.5, -r * 0.25), Vector2(-r * 0.15, -r * 0.6)]), Color(1, 1, 1, 0.6), r * 0.1)
	_T = Transform2D.IDENTITY
	var start := e + Vector2(r * 0.72, r * 0.72)
	for i in 9:
		var s := i / 8.0
		var c := start + Vector2(s * r * 0.9, s * r * 2.6 + sin(s * PI) * r * 0.5)
		_ball(c, maxf(2.2, r * 0.07), maxf(2.2, r * 0.07), Color("#FFCB45"), 0.0, 1.0, 0.8, 0.8)
	_sparkle(e + Vector2(-r * 0.55, -r * 0.55), r * (0.1 + 0.06 * sin(t * 4.0)), Color.WHITE)


func _scarf(a: Dictionary) -> void:
	var w: float = a.neck_w
	var h := w * 0.2
	var n: Vector2 = a.neck
	var stripes := [Color("#FF5A6E"), Color("#FFD23F"), Color("#2EC4B6")]
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		var x := (s - 0.5) * w
		var curve := (1.0 - pow(2.0 * s - 1.0, 2)) * h * 0.45
		top.append(n + Vector2(x, -h * 0.5 + curve))
		bot.append(n + Vector2(x * 0.96, h * 0.5 + curve))
	# хвостик шарфа с бахромой и бубенчиком
	var tl := n + Vector2(w * 0.18, h * 0.3)
	var tail := PackedVector2Array([tl, tl + Vector2(h * 1.1, 0), tl + Vector2(h * 1.4, h * 2.4), tl + Vector2(h * 0.3, h * 2.5)])
	_fill(tail, stripes[0].darkened(0.1))
	for j in 2:
		var s0 := 0.3 + j * 0.34
		_fill(PackedVector2Array([tail[0].lerp(tail[3], s0), tail[1].lerp(tail[2], s0), tail[1].lerp(tail[2], s0 + 0.15), tail[0].lerp(tail[3], s0 + 0.15)]), stripes[1 + j])
	_vgrad(tail, Color(1, 1, 1, 0.0), Color(0.15, 0.0, 0.3, 0.3), false)
	for i in 5:
		var fx: Vector2 = tail[3].lerp(tail[2], (i + 0.5) / 5.0)
		ci.draw_line(fx, fx + Vector2(0, h * 0.4), stripes[i % 3], 3.0, true)
	_ball(tail[3].lerp(tail[2], 0.5) + Vector2(0, h * 0.75), h * 0.3, h * 0.3, Color("#FFCB45"), 0.0, 1.0, 0.9, 1.0)
	ci.draw_line(tail[3].lerp(tail[2], 0.5) + Vector2(-h * 0.18, h * 0.85), tail[3].lerp(tail[2], 0.5) + Vector2(h * 0.18, h * 0.85), Color("#8A5A10"), 1.6, true)
	# основная полоса: вязаные полоски
	for i in 12:
		var q := PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]])
		ci.draw_colored_polygon(q, stripes[i % 3])
	# объём трубки: светлый верх, тёмный низ
	var sp := PackedVector2Array()
	var sc := PackedColorArray()
	for i in 13:
		sp.append(top[i])
		sc.append(Color(1, 1, 1, 0.38))
		sp.append(top[i].lerp(bot[i], 0.4))
		sc.append(Color(1, 1, 1, 0.0))
		sp.append(bot[i])
		sc.append(Color(0.18, 0.0, 0.32, 0.42))
	var idx := PackedInt32Array()
	for i in 12:
		for j in 2:
			var a0 := i * 3 + j
			var b0 := a0 + 3
			idx.append_array([a0, b0, b0 + 1, a0, b0 + 1, a0 + 1])
	RenderingServer.canvas_item_add_triangle_array(_rid, idx, sp, sc)
	# вязка: «ёлочки»
	for i in range(1, 12):
		var c := top[i].lerp(bot[i], 0.5)
		ci.draw_polyline(PackedVector2Array([c + Vector2(-3, -3), c, c + Vector2(3, -3)]), Color(1, 1, 1, 0.35), 1.6, true)
	var band := top.duplicate()
	var rb := bot.duplicate()
	rb.reverse()
	band.append_array(rb)
	band.append(top[0])
	ci.draw_polyline(band, Color(0.35, 0.05, 0.2, 0.5), 1.6, true)


func _bowtie(a: Dictionary) -> void:
	var k: float = a.neck_w / 150.0
	var n: Vector2 = a.neck + Vector2(0, 2)
	_T = Transform2D(0.0, Vector2(k, k), 0.0, n)
	var col := Color("#FF3B5C")
	for sx in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(sx * 6, -6), Vector2(sx * 22, -18), Vector2(sx * 36, -19), Vector2(sx * 40, -6), Vector2(sx * 40, 6), Vector2(sx * 36, 19), Vector2(sx * 22, 18), Vector2(sx * 6, 6)])
		_shape(["bt_wing", sx], wing, Vector2(sx * 24, 0), col, 1.25, 0.55)
		for d in [Vector2(18, -8), Vector2(30, 2), Vector2(18, 9), Vector2(32, -11), Vector2(31, 13)]:
			_dot(Vector2(d.x * sx, d.y), 2.6, Color(1, 1, 1, 0.92))
		_glow(Vector2(sx * 10, 0), 8, 12, Color("#8E0F30", 0.45))
	_ball(Vector2.ZERO, 9, 11, col.darkened(0.1), 0.0, 1.0, 0.6)


func _necklace(a: Dictionary, t: float) -> void:
	var w: float = a.neck_w * 0.8
	var n: Vector2 = a.neck
	var chain := PackedVector2Array()
	for i in 17:
		var ang := lerpf(0.0, PI, i / 16.0)
		chain.append(n + Vector2(cos(ang) * w * 0.5, -8 + sin(ang) * w * 0.17))
	ci.draw_polyline(chain, Color("#B07A1A"), 2.0, true)
	for i in 17:
		if i == 8:
			continue
		if i % 2 == 0:
			_ball(chain[i], 4.6, 4.6, Color("#FFF0F8"), 0.0, 1.0, 0.9, 1.0)
		else:
			_ball(chain[i], 3.4, 3.4, Color("#FFC83A"), 0.0, 1.0, 0.9, 1.0)
	# подвеска-сердечко
	var pc: Vector2 = chain[8] + Vector2(0, w * 0.1)
	var hk := w * 0.12
	_T = Transform2D(0.0, pc)
	_shape(["neck_heart", hk], _heart(Vector2.ZERO, hk, 24), Vector2(0, -hk * 0.15), Color("#C25CFF"), 1.0, 0.9)
	_dot(Vector2(-hk * 0.45, -hk * 0.45), hk * 0.16, Color(1, 1, 1, 0.95))
	_T = Transform2D.IDENTITY
	_ball(chain[8] - Vector2(0, 1), 3.2, 3.2, Color("#FFC83A"), 0.0, 1.0, 0.9, 1.0)
	_sparkle(pc + Vector2(hk * 0.9, -hk * 0.7), hk * (0.4 + 0.25 * sin(t * 4.0)), Color.WHITE)


func _cape(a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if not behind:
		# застёжка: золотая звёздочка под подбородком
		var n: Vector2 = a.neck + Vector2(0, 6)
		var star := PackedVector2Array()
		for i in 10:
			var rr := 14.0 if i % 2 == 0 else 6.5
			star.append(n + Vector2(0, -rr).rotated(i * TAU / 10.0))
		_shape(["cape_star", n], star, n, Color("#FFCB45"), 1.0, 0.8)
		_ball(n, 3.5, 3.5, Color("#FF5FA8"), 0.0, 1.0, 0.9, 0.8)
		return
	# высокий воротник за головой и широкий плащ до земли
	var pts := PackedVector2Array([b + Vector2(-w * 0.34, -w * 0.36), b + Vector2(-w * 0.50, -w * 0.2)])
	var bottom_y := b.y + w * 0.58
	var hem := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		var x := lerpf(-w * 0.66, w * 0.66, s)
		var v := Vector2(b.x + x, bottom_y + sin(s * TAU * 2.0 + t * 2.0) * 6.0 + (absf(s - 0.5) * -14.0))
		pts.append(v)
		hem.append(v)
	pts.append(b + Vector2(w * 0.50, -w * 0.2))
	pts.append(b + Vector2(w * 0.34, -w * 0.36))
	var cols := PackedColorArray()
	for v in pts:
		var ty := clampf((v.y - b.y + w * 0.5) / (w * 1.1), 0.0, 1.0)
		var tx := clampf((v.x - b.x) / (w * 1.3) + 0.5, 0.0, 1.0)
		cols.append(Color("#7A5CF0").lerp(Color("#24166A"), ty * 0.8 + tx * 0.25))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(0.1, 0.05, 0.25, 0.6), 4.0, true)
	ci.draw_polygon(pts, cols)
	# складки
	for i in [3, 6, 9]:
		var hp: Vector2 = hem[i]
		ci.draw_line(Vector2(hp.x * 0.8 + b.x * 0.2, b.y - w * 0.05), hp + Vector2(0, -6), Color(0.08, 0.02, 0.2, 0.25), 6.0, true)
	# золотая кайма
	ci.draw_polyline(hem, Color("#B8771A"), 7.0, true)
	ci.draw_polyline(hem, Color("#FFCB45"), 4.0, true)
	var stars := [Vector2(-0.55, 0.35), Vector2(0.55, 0.28), Vector2(-0.42, 0.52), Vector2(0.46, 0.5), Vector2(0.6, 0.02), Vector2(-0.6, 0.05), Vector2(-0.3, 0.2), Vector2(0.3, 0.4)]
	for i in stars.size():
		var tw := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
		var sc: Vector2 = b + stars[i] * w
		_glow(sc, w * 0.07, w * 0.07, Color(1, 0.9, 0.55, 0.32 * tw))
		_sparkle(sc, w * 0.04 * (0.7 + tw * 0.6), Color(1, 0.96, 0.78, 0.55 + 0.45 * tw))


func _backpack(a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	var orange := Color("#FF8A3D")
	if behind:
		var c := b + Vector2(w * 0.5, -w * 0.12)
		var s := Vector2(w * 0.5, w * 0.6)
		var r := Rect2(c - s / 2.0, s)
		_shape(["bp_body", w, b], _rrect(r, s.x * 0.28), c, orange, 1.4, 0.4)
		var pk := Rect2(r.position + Vector2(s.x * 0.1, s.y * 0.5), Vector2(s.x * 0.8, s.y * 0.4))
		_shape(["bp_pocket", w, b], _rrect(pk, s.x * 0.16), pk.get_center(), Color("#FFB03D"), 1.6, 0.4)
		_T = Transform2D(0.0, pk.get_center())
		_shape(["bp_heart", w], _heart(Vector2.ZERO, s.x * 0.12, 20), Vector2.ZERO, Color("#FF4F93"), 1.0, 0.6, 1.0)
		_T = Transform2D.IDENTITY
		var fl := Rect2(r.position + Vector2(0, -2), Vector2(s.x, s.y * 0.34))
		_shape(["bp_flap", w, b], _rrect(fl, s.x * 0.26), fl.get_center(), Color("#2EC4B6"), 1.5, 0.45)
		_ball(c + Vector2(0, -s.y * 0.2 + s.y * 0.14), s.x * 0.09, s.x * 0.09, Color("#FFCB45"), 0.0, 1.0, 0.9)
		# брелок-звёздочка покачивается
		var ch := r.position + Vector2(s.x * 0.9, s.y * 0.3)
		var sw := sin(t * 2.4) * 0.3
		var sp := ch + Vector2(0, s.y * 0.22).rotated(sw)
		ci.draw_line(ch, sp, Color("#FFF0C0"), 1.6, true)
		_sparkle(sp, s.x * 0.12, Color("#FFE066"))
		return
	# лямки спереди
	var k := w / 184.0
	for sx in [-1.0, 1.0]:
		var top: Vector2 = b + Vector2(sx * 62, -8) * k
		var bot: Vector2 = b + Vector2(sx * 52, 74) * k
		if a.kind == "axolotl":
			top = b + Vector2(sx * 40, -22) * k
			bot = b + Vector2(sx * 50, 30) * k
		elif a.kind == "puppy":
			top = b + Vector2(sx * 46, -30) * k
			bot = b + Vector2(sx * 58, 26) * k
		var strap := PackedVector2Array([top, top.lerp(bot, 0.5) + Vector2(sx * 4, 0), bot])
		ci.draw_polyline(strap, Color("#B5521E"), 15.0 * k + 2.0, true)
		ci.draw_polyline(strap, Color("#2EC4B6"), 10.0 * k, true)
		ci.draw_polyline(strap, Color(1, 1, 1, 0.35), 3.0 * k, true)
		_ball(top.lerp(bot, 0.55), 4.5 * k + 1.0, 4.5 * k + 1.0, Color("#FFCB45"), 0.0, 1.0, 0.9, 1.0)


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
	_rid = target.get_canvas_item()
	_T = Transform2D.IDENTITY
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
	_T = Transform2D.IDENTITY
	ci.draw_set_transform(Vector2.ZERO)
