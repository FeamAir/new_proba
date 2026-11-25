extends RefCounted
## Cascado 0.12: редкости вещей — цвета рамок и «блеск». Всё рисуется кодом, без картинок.
##   common    — серо-голубая рамка, без эффекта;
##   rare      — синяя рамка, раз в 2–3 с по вещи пробегает блик;
##   epic      — фиолетовая рамка, цвет рамки и вещи плавно переливается;
##   legendary — золотая рамка, мягкое свечение и редкие искры вокруг вещи;
##   super     — радужная вращающаяся рамка, анимация вокруг всего героя (Крылья Каскада).
## Функции рисуют на CanvasItem ci в его текущем преобразовании (карточки гардероба,
## кузница; на герое — в координатах героя, см. scripts/hero_magic.gd).

const COL := {
	"common": Color("#8FA3C8"),
	"rare": Color("#3E8BFF"),
	"epic": Color("#B44CFF"),
	"legendary": Color("#FFC83A"),
	"super": Color("#FF5FD0"),
}
const WIDTH := {"common": 3.0, "rare": 4.0, "epic": 4.5, "legendary": 5.0, "super": 6.0}
const SHEEN_PERIOD := 2.6


static func col(r: String) -> Color:
	return COL.get(r, COL.common)


## Псевдослучайное 0..1 по номеру (одинаковое между кадрами).
static func hs(i: float, k := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


## Цвет рамки в момент t (эпическая переливается, супер — радуга).
static func frame_col(r: String, t: float, seed := 0.0) -> Color:
	match r:
		"epic":
			var k := 0.5 + 0.5 * sin(t * 1.6 + seed)
			return Color("#B44CFF").lerp(Color("#FF5FD0"), k).lerp(Color("#6F8BFF"), 0.5 + 0.5 * sin(t * 1.1 + seed + 2.0) * 0.6 - 0.3)
		"super":
			return Color.from_hsv(fposmod(t * 0.25 + seed, 1.0), 0.65, 1.0)
	return col(r)


static func _rr(r: Rect2, rad: float, per := 6) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.49)
	var pts := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for q in 4:
		for i in per + 1:
			var ang := -PI / 2.0 + q * PI / 2.0 + i * (PI / 2.0) / per
			pts.append(cs[q] + Vector2(cos(ang), sin(ang)) * rad)
	return pts


## Рамка карточки по редкости (rad — скругление). seed — сдвиг фазы, чтобы карточки мерцали вразнобой.
static func frame(ci: CanvasItem, r: Rect2, rar: String, t: float, rad := 20.0, seed := 0.0) -> void:
	var w: float = WIDTH.get(rar, 3.0)
	var pts := _rr(r.grow(-w * 0.5), rad)
	pts.append(pts[0])
	match rar:
		"super":
			var cols := PackedColorArray()
			var n := pts.size()
			for i in n:
				cols.append(Color.from_hsv(fposmod(float(i) / (n - 1) - t * 0.35, 1.0), 0.7, 1.0))
			ci.draw_polyline_colors(_grow_pts(pts, r, 3.0), _alpha(cols, 0.35), w + 6.0, true)
			ci.draw_polyline_colors(pts, cols, w, true)
		"legendary":
			var pulse := 0.5 + 0.5 * sin(t * 2.2 + seed)
			ci.draw_polyline(_grow_pts(pts, r, 3.0), Color(1.0, 0.8, 0.3, 0.18 + 0.2 * pulse), w + 7.0, true)
			ci.draw_polyline(pts, Color("#B8771A"), w + 2.0, true)
			ci.draw_polyline(pts, Color("#FFD45A").lerp(Color("#FFF4C0"), pulse * 0.5), w - 1.0, true)
		"epic":
			var c := frame_col(rar, t, seed)
			ci.draw_polyline(_grow_pts(pts, r, 2.0), Color(c, 0.25), w + 4.0, true)
			ci.draw_polyline(pts, c, w, true)
		_:
			ci.draw_polyline(pts, col(rar), w, true)


static func _alpha(cols: PackedColorArray, a: float) -> PackedColorArray:
	var o := PackedColorArray()
	for c in cols:
		o.append(Color(c, a))
	return o


static func _grow_pts(pts: PackedVector2Array, r: Rect2, d: float) -> PackedVector2Array:
	var c := r.get_center()
	var o := PackedVector2Array()
	for p in pts:
		var v := p - c
		o.append(p + Vector2(signf(v.x), signf(v.y)) * d * 0.7)
	return o


## Эффект вокруг значка вещи (карточка, кузница): c — центр, s — размер значка, clip — область
## карточки (блик не выходит за неё).
static func icon_fx(ci: CanvasItem, rar: String, c: Vector2, s: float, t: float, seed: float, clip: Rect2) -> void:
	match rar:
		"rare":
			sheen(ci, clip, t, seed)
		"epic":
			# цветной перелив поверх вещи и искорки по кругу
			var hh := fposmod(t * 0.12 + seed, 1.0)
			soft_disc(ci, c + Vector2(cos(t * 0.9), sin(t * 0.7)) * s * 0.12, s * 0.36, Color.from_hsv(hh, 0.6, 1.0, 0.22))
			for k in 3:
				var a := t * 1.2 + k * TAU / 3.0 + seed
				star4(ci, c + Vector2(cos(a), sin(a) * 0.7) * s * 0.42, s * 0.045 * (0.7 + 0.3 * sin(t * 5.0 + k)), Color.from_hsv(fposmod(hh + k * 0.2, 1.0), 0.45, 1.0, 0.95))
			sheen(ci, clip, t * 0.8, seed + 1.0, Color.from_hsv(hh, 0.35, 1.0, 0.5))
		"legendary":
			sparks(ci, c, s * 0.5, t, seed, Color("#FFE27A"), 5)
			sheen(ci, clip, t * 0.7, seed + 2.0, Color(1, 0.95, 0.7, 0.55))
		"super":
			for k in 6:
				var a := t * 1.4 + k * TAU / 6.0
				var p := c + Vector2(cos(a), sin(a) * 0.82) * s * 0.52
				ci.draw_circle(p, s * 0.05, Color.from_hsv(fposmod(k / 6.0 + t * 0.2, 1.0), 0.55, 1.0, 0.9), true, -1.0, true)
				star4(ci, p, s * 0.06 * (0.6 + 0.4 * sin(t * 5.0 + k)), Color(1, 1, 1, 0.9))
			sparks(ci, c, s * 0.5, t, seed, Color(1, 1, 1), 6)


## Мягкое пятно света: в центре col, к краю прозрачное (плавный градиент, без «колец»).
static func soft_disc(ci: CanvasItem, c: Vector2, r: float, col: Color, sy := 1.0) -> void:
	var n := 28
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	for k in [0.55, 1.0]:
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a), sin(a) * sy) * r * k)
			cols.append(Color(col, col.a * (0.55 if k < 1.0 else 0.0)))
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
		var a0 := 1 + i
		var b0 := 1 + (i + 1) % n
		idx.append_array([a0, a0 + n, b0 + n, a0, b0 + n, b0])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## Мягкое свечение под значком (рисовать ДО значка): эпическая — переливается, легендарная — золото.
static func icon_glow(ci: CanvasItem, rar: String, c: Vector2, s: float, t: float, seed: float) -> void:
	match rar:
		"epic":
			soft_disc(ci, c, s * 0.55, Color.from_hsv(fposmod(t * 0.12 + seed, 1.0), 0.6, 1.0, 0.4))
		"legendary":
			soft_disc(ci, c, s * 0.62, Color(1.0, 0.82, 0.3, 0.42 + 0.14 * sin(t * 2.0 + seed)))
		"super":
			soft_disc(ci, c, s * 0.66, Color.from_hsv(fposmod(t * 0.2, 1.0), 0.5, 1.0, 0.45))


## Блик: светлая косая полоса раз в SHEEN_PERIOD секунд пробегает по области clip.
static func sheen(ci: CanvasItem, clip: Rect2, t: float, seed: float, tint := Color(1, 1, 1, 0.55)) -> void:
	var ph := fposmod(t + seed * 0.83, SHEEN_PERIOD) / 0.55
	if ph >= 1.0:
		return
	var w := clip.size.x
	var x := clip.position.x - w * 0.4 + ph * w * 1.8
	var hgt := clip.size.y
	var band := PackedVector2Array([Vector2(x, clip.position.y), Vector2(x + w * 0.16, clip.position.y),
		Vector2(x + w * 0.16 - hgt * 0.45, clip.end.y), Vector2(x - hgt * 0.45, clip.end.y)])
	var rect := PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)])
	var a := sin(ph * PI)
	for poly in Geometry2D.intersect_polygons(band, rect):
		if poly.size() >= 3:
			ci.draw_colored_polygon(poly, Color(tint, tint.a * a))
	var thin := PackedVector2Array([Vector2(x + w * 0.22, clip.position.y), Vector2(x + w * 0.26, clip.position.y),
		Vector2(x + w * 0.26 - hgt * 0.45, clip.end.y), Vector2(x + w * 0.22 - hgt * 0.45, clip.end.y)])
	for poly in Geometry2D.intersect_polygons(thin, rect):
		if poly.size() >= 3:
			ci.draw_colored_polygon(poly, Color(tint, tint.a * a * 0.7))


## Четырёхлучевая звёздочка-искра.
static func star4(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r <= 0.3:
		return
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.2, -r * 0.2), c + Vector2(r, 0), c + Vector2(r * 0.2, r * 0.2),
		c + Vector2(0, r), c + Vector2(-r * 0.2, r * 0.2), c + Vector2(-r, 0), c + Vector2(-r * 0.2, -r * 0.2)]), col)


## Редкие искры вокруг точки: вспыхивают и гаснут в разных местах.
static func sparks(ci: CanvasItem, c: Vector2, rad: float, t: float, seed: float, col: Color, n := 4) -> void:
	for i in n:
		var per := 1.6 + hs(i, seed) * 1.4
		var cyc := floorf((t + hs(i, seed + 3.0) * per) / per)
		var ph := fposmod(t + hs(i, seed + 3.0) * per, per) / per
		if ph > 0.45:
			continue
		var k := sin(ph / 0.45 * PI)
		var ang := hs(cyc + i * 7.0, seed + 1.0) * TAU
		var d := rad * (0.75 + 0.45 * hs(cyc + i * 3.0, seed + 2.0))
		var p := c + Vector2(cos(ang), sin(ang)) * d
		ci.draw_circle(p, rad * 0.1 * k, Color(col, 0.25 * k), true, -1.0, true)
		star4(ci, p, rad * 0.13 * k, Color(col, 0.95 * k))
		star4(ci, p, rad * 0.06 * k, Color(1, 1, 1, k))


## Эффект редкости на герое (в координатах героя): c — центр вещи, rad — её размер.
static func on_hero(ci: CanvasItem, rar: String, c: Vector2, rad: float, t: float, seed: float) -> void:
	match rar:
		"rare":
			# блик пробегает по вещи
			var ph := fposmod(t + seed * 0.83, SHEEN_PERIOD) / 0.5
			if ph < 1.0:
				var k := sin(ph * PI)
				var p := c + Vector2(lerpf(-rad, rad, ph), lerpf(rad * 0.45, -rad * 0.45, ph))
				ci.draw_line(p + Vector2(-rad * 0.22, rad * 0.5), p + Vector2(rad * 0.22, -rad * 0.5), Color(1, 1, 1, 0.45 * k), rad * 0.12, true)
				star4(ci, p, rad * 0.28 * k, Color(1, 1, 1, 0.95 * k))
				ci.draw_circle(p, rad * 0.12 * k, Color(0.7, 0.85, 1.0, 0.4 * k), true, -1.0, true)
		"epic":
			# переливающиеся искорки кружат вокруг вещи (мягкий цветной ореол — hero_magic.gd)
			var hh := fposmod(t * 0.14 + seed, 1.0)
			for k in 3:
				var a := t * 1.3 + k * TAU / 3.0 + seed
				var p := c + Vector2(cos(a), sin(a) * 0.55) * rad * 0.95
				var cc := Color.from_hsv(fposmod(hh + k * 0.22, 1.0), 0.55, 1.0, 0.9)
				star4(ci, p, rad * 0.11 * (0.7 + 0.3 * sin(t * 5.0 + k)), cc)
			sparks(ci, c, rad, t, seed, Color.from_hsv(hh, 0.35, 1.0), 2)
		"legendary":
			sparks(ci, c, rad * 1.1, t, seed, Color("#FFE27A"), 5)
