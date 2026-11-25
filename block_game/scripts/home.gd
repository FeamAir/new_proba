extends RefCounted
## Дома героев Cascado и украшения для них. Всё рисуется кодом.
##   совёнок — дупло большого дерева под ночным небом, корни уходят к кристальной пещере;
##   аксолотль — подводный грот: вода, пузырьки, водоросли, кристаллы на дне.
## Сцена нарисована в своих координатах 720×1280 (как экран высотой 1280);
## draw() переносит её в любое место экрана с масштабом (главный экран и превью в гардеробе).
## stage 0..3 — «дом богатеет» по пройденным залам (Meta.home_stage), украшения — поверх.

const Hero := preload("res://scripts/hero.gd")
const OUT := Color("#1E1236")

## Места для украшений в координатах сцены: точка и масштаб.
## floor/wall/near — точка, на которой предмет стоит (низ); hang — точка подвеса (верх).
const SPOTS := {
	"owl": {
		"floor_l": [Vector2(112, 872), 1.0], "floor_r": [Vector2(612, 872), 1.0],
		"wall_l": [Vector2(112, 408), 0.85], "wall_r": [Vector2(652, 324), 0.85],
		"hang": [Vector2(532, 360), 0.95], "near": [Vector2(452, 712), 0.62],
	},
	"axolotl": {
		"floor_l": [Vector2(128, 872), 1.0], "floor_r": [Vector2(620, 872), 1.0],
		"wall_l": [Vector2(98, 500), 0.85], "wall_r": [Vector2(630, 452), 0.85],
		"hang": [Vector2(606, 232), 1.0], "near": [Vector2(496, 840), 0.7],
	},
}
## Положение и масштаб героя в сцене
const HERO_AT := {"owl": [Vector2(338, 606), 0.8], "axolotl": [Vector2(340, 590), 0.95]}
## Высота предмета (для подвешивания: верх предмета — на конце нитки)
const DECOR_H := {
	"owl_lantern": 74.0, "owl_birdhouse": 110.0, "owl_moon": 110.0, "owl_mushrooms": 64.0,
	"owl_hammock": 60.0, "owl_books": 72.0, "owl_nightlight": 84.0, "owl_garland": 50.0, "owl_nest": 26.0,
	"owl_swing": 130.0, "axo_chest": 96.0, "axo_coral": 92.0, "axo_shell": 56.0, "axo_castle": 116.0,
	"axo_starfish": 62.0, "axo_bubble": 80.0, "axo_lily": 64.0, "axo_tree": 130.0, "axo_anchor": 104.0, "axo_sofa": 60.0,
}
## Предметы, у которых своя нитка/верёвка (рисуются от точки подвеса)
const SELF_HUNG := ["owl_swing", "owl_moon", "owl_garland", "axo_lily"]

var ci: CanvasItem
var hero_drawer = Hero.new()
var origin := Vector2.ZERO
var scale := 1.0


func _xf(local_xf := true) -> void:
	if local_xf:
		ci.draw_set_transform(origin, 0.0, Vector2(scale, scale))
	else:
		ci.draw_set_transform(Vector2.ZERO)


func to_screen(v: Vector2) -> Vector2:
	return origin + v * scale


func spot_screen(kind: String, spot: String) -> Vector2:
	var sp: Array = SPOTS[kind][spot]
	var p: Vector2 = sp[0]
	var k: float = sp[1]
	var h: float = 60.0
	if spot == "hang":
		return to_screen(p + Vector2(0, 70 * k))
	return to_screen(p - Vector2(0, h * 0.5 * k))


# ---------- Фигуры ----------

func _ell(c: Vector2, rx: float, ry: float, rot := 0.0, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _fill(pts: PackedVector2Array, col: Color, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, outline if w > 0.0 else col, w if w > 0.0 else 1.2, true)


func _oval(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	_fill(_ell(c, rx, ry, rot), col, outline, w)


func _glow(c: Vector2, r: float, col: Color, a := 0.25) -> void:
	for i in 4:
		ci.draw_circle(c, r * (1.0 - i * 0.22), Color(col, a * (0.35 + i * 0.2)), true, -1.0, true)


func _gem(c: Vector2, r: float, col: Color) -> void:
	_fill(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.7, -r * 0.2)]), col, col.darkened(0.45), maxf(1.0, r * 0.12))
	_fill(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, -r * 0.05)]), Color(1, 1, 1, 0.5))


func _sparkle(c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0), c + Vector2(r * 0.25, r * 0.25),
		c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), col)


func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.49)
	var pts := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for q in 4:
		for i in 6:
			var ang := -PI / 2.0 + q * PI / 2.0 + i * (PI / 2.0) / 5.0
			pts.append(cs[q] + Vector2(cos(ang), sin(ang)) * rad)
	return pts


static func _hash(i: int, k: int) -> float:
	return fposmod(sin(i * 127.1 + k * 311.7) * 43758.5453, 1.0)


# ---------- Главный вызов ----------

## view — видимая часть сцены (в её координатах): фон заполняет её целиком.
## highlight — место, которое подсвечивается (выбор украшений), "" — нет.
func draw(target: CanvasItem, kind: String, at: Vector2, sc: float, view: Rect2, stage: int, placed: Dictionary,
		outfit: Dictionary, t: float, react: float, highlight := "", show_empty := false) -> void:
	ci = target
	origin = at
	scale = sc
	_xf()
	if kind == "axolotl":
		_grotto(view, stage, t)
	else:
		_hollow_tree(view, stage, t)
	# украшения позади героя
	for spot in ["hang", "wall_l", "wall_r", "floor_l", "floor_r"]:
		_place_decor(kind, spot, placed.get(spot, ""), t)
	_xf(false)
	var ha: Array = HERO_AT[kind]
	var hp: Vector2 = ha[0]
	if kind == "axolotl":
		hp.y += sin(t * 1.4) * 7.0
	hero_drawer.draw(ci, kind, to_screen(hp), sc * ha[1], outfit, t, react)
	_xf()
	if kind == "owl":
		# край гнезда спереди совёнка
		_nest_front(t)
	_place_decor(kind, "near", placed.get("near", ""), t)
	if kind == "axolotl":
		_bubbles(view, t, stage, true)
	for spot in SPOTS[kind]:
		var sp: Array = SPOTS[kind][spot]
		var c: Vector2 = sp[0] + (Vector2(0, 70) if spot == "hang" else Vector2(0, -34)) * sp[1]
		if spot == highlight:
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			ci.draw_arc(c, 62 * sp[1] + 6 * pulse, 0, TAU, 40, Color(1, 0.84, 0.4, 0.9), 5.0, true)
		elif show_empty and placed.get(spot, "") == "":
			var a := 0.35 + 0.2 * sin(t * 2.5 + c.x)
			ci.draw_circle(c, 24, Color(1, 1, 1, a * 0.35), true, -1.0, true)
			ci.draw_line(c - Vector2(10, 0), c + Vector2(10, 0), Color(1, 1, 1, a), 4.0, true)
			ci.draw_line(c - Vector2(0, 10), c + Vector2(0, 10), Color(1, 1, 1, a), 4.0, true)
	_xf(false)


func _place_decor(kind: String, spot: String, id: String, t: float) -> void:
	if id == "":
		return
	var sp: Array = SPOTS[kind][spot]
	var p: Vector2 = sp[0]
	var k: float = sp[1]
	if spot == "hang" and not SELF_HUNG.has(id):
		var len := 50.0 * k
		var sw := sin(t * 1.3) * 0.05
		var end := p + Vector2(0, len).rotated(sw)
		ci.draw_line(p, end, Color("#C9B88A"), 2.5, true)
		draw_decor(id, end + Vector2(0, DECOR_H.get(id, 60.0) * k), k, t)
	else:
		draw_decor(id, p, k, t)


# ---------- Дупло совёнка ----------

func _hollow_tree(view: Rect2, stage: int, t: float) -> void:
	var top := view.position.y
	var bot := maxf(view.end.y, 900.0)
	# ночное небо
	ci.draw_polygon(PackedVector2Array([Vector2(view.position.x, top), Vector2(view.end.x, top), Vector2(view.end.x, 880), Vector2(view.position.x, 880)]),
		PackedColorArray([Color("#0B0826"), Color("#0B0826"), Color("#2A1D57"), Color("#2A1D57")]))
	for i in 46:
		var p := Vector2(_hash(i, 1) * 720.0, lerpf(maxf(top, 120.0), 720.0, _hash(i, 2)))
		if p.y < top:
			continue
		var tw := 0.4 + 0.6 * absf(sin(t * (0.8 + _hash(i, 3)) + i))
		var r := 1.2 + _hash(i, 4) * 2.2
		ci.draw_circle(p, r, Color(1, 0.97, 0.85, tw * 0.85), true, -1.0, true)
		if r > 3.0:
			_sparkle(p, r * 2.6 * tw, Color(1, 1, 0.9, 0.6 * tw))
	if stage >= 3:
		# северное сияние
		for j in 3:
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in 13:
				var x := i * 60.0
				var y := 230.0 + j * 26.0 + sin(x * 0.012 + t * 0.5 + j) * 30.0
				pts.append(Vector2(x, y))
				cols.append(Color(0.3, 1.0, 0.75, 0.0))
			for i in range(12, -1, -1):
				var x := i * 60.0
				var y := 230.0 + j * 26.0 + sin(x * 0.012 + t * 0.5 + j) * 30.0 + 70.0
				pts.append(Vector2(x, y))
				cols.append(Color(0.45, 0.7, 1.0, 0.10))
			ci.draw_polygon(pts, cols)
	# луна
	var mc := Vector2(632, 196)
	_glow(mc, 110 + stage * 10, Color("#FFF1B8"), 0.12)
	_oval(mc, 46, 46, Color("#FFF3C9"))
	for cr in [[Vector2(-14, -10), 9.0], [Vector2(12, 12), 7.0], [Vector2(16, -16), 4.5]]:
		_oval(mc + cr[0], cr[1], cr[1], Color("#EFDDA0"))
	# далёкие холмы
	var hills := PackedVector2Array([Vector2(-240, 880)])
	for i in 21:
		hills.append(Vector2(-240 + i * 60.0, 780 + sin(i * 1.3) * 24.0))
	hills.append(Vector2(960, 880))
	_fill(hills, Color("#1B1440"))

	# крона
	var leaf_cols := [Color("#173A35"), Color("#1F4C40"), Color("#27604C")]
	var blobs := [[Vector2(150, 300), 95.0], [Vector2(260, 220), 110.0], [Vector2(400, 210), 115.0], [Vector2(510, 270), 95.0],
		[Vector2(80, 360), 60.0], [Vector2(330, 300), 110.0]]
	for layer in 3:
		for i in blobs.size():
			var b: Array = blobs[i]
			var c: Vector2 = b[0] + Vector2(0, layer * 14.0 - 14.0) + Vector2(sin(t * 0.7 + i) * 3.0, 0)
			if c.y + b[1] < top:
				continue
			_oval(c, b[1] * (1.0 - layer * 0.18), b[1] * (0.8 - layer * 0.15), leaf_cols[layer])
	# ствол
	var bark := Color("#5B3A2E")
	var trunk := PackedVector2Array([Vector2(232, 300), Vector2(488, 300), Vector2(512, 640), Vector2(540, 830), Vector2(600, 880),
		Vector2(120, 880), Vector2(180, 830), Vector2(208, 640)])
	_fill(trunk, bark, OUT, 6.0)
	# ветки
	_fill(PackedVector2Array([Vector2(236, 430), Vector2(240, 476), Vector2(120, 420), Vector2(20, 414), Vector2(24, 396), Vector2(130, 398)]), bark, OUT, 5.0)
	_fill(PackedVector2Array([Vector2(484, 352), Vector2(488, 392), Vector2(600, 344), Vector2(712, 332), Vector2(708, 314), Vector2(596, 320)]), bark, OUT, 5.0)
	# листики на ветках
	for lp in [Vector2(40, 392), Vector2(70, 386), Vector2(690, 310), Vector2(660, 304)]:
		_oval(lp, 16, 8, Color("#2F7A55"), -0.5)
	# кора
	for i in 7:
		var x := 236.0 + i * 40.0
		var line := PackedVector2Array()
		for j in 9:
			var y := 320.0 + j * 64.0
			if y > 860:
				break
			line.append(Vector2(x + sin(j * 1.7 + i) * 8.0 + (x - 360.0) * (y - 320.0) / 1500.0, y))
		ci.draw_polyline(line, Color("#3D261E"), 4.0, true)
	# дупло
	var hc := Vector2(352, 590)
	_oval(hc, 132, 150, Color("#7B5141"), 0.0, OUT, 6.0)
	_oval(hc, 116, 134, Color("#160C1E"))
	var warm := 0.10 + stage * 0.07
	_glow(hc + Vector2(0, 40), 120, Color("#FFB547"), warm)
	# гнездо внутри
	_oval(Vector2(348, 708), 104, 30, Color("#8A6239"), 0.0, OUT, 4.0)
	for i in 9:
		var x := 262.0 + i * 20.0
		ci.draw_line(Vector2(x, 694 + _hash(i, 9) * 10.0), Vector2(x + 26, 712 - _hash(i, 8) * 8.0), Color("#C59A5C"), 3.0, true)
	# корни и земля
	_fill(PackedVector2Array([Vector2(-240, 870), Vector2(960, 870), Vector2(960, bot + 2), Vector2(-240, bot + 2)]), Color("#1A1230"))
	_fill(PackedVector2Array([Vector2(-240, 862), Vector2(0, 862), Vector2(150, 872), Vector2(360, 866), Vector2(560, 874), Vector2(720, 862), Vector2(960, 862),
		Vector2(960, 900), Vector2(-240, 900)]), Color("#2B4A32"))
	for r in [[Vector2(200, 880), Vector2(110, 1000), Vector2(60, 1160)], [Vector2(300, 880), Vector2(280, 1040), Vector2(210, 1220)],
			[Vector2(430, 880), Vector2(470, 1030), Vector2(520, 1200)], [Vector2(520, 880), Vector2(620, 990), Vector2(690, 1120)]]:
		var pts := PackedVector2Array()
		for i in 9:
			var s := i / 8.0
			var q: Vector2 = r[0].lerp(r[1], s).lerp(r[1].lerp(r[2], s), s)
			if q.y > bot:
				break
			pts.append(q)
		if pts.size() > 1:
			ci.draw_polyline(pts, Color("#3D261E"), 16.0, true)
	# кристаллы пещеры под корнями
	var cave := [Color("#B46CFF"), Color("#3FD0FF"), Color("#3DDC97"), Color("#FF8FD8")]
	var count := 3 + stage * 3
	for i in count:
		var p := Vector2(40 + _hash(i, 5) * 640.0, 960 + _hash(i, 6) * 260.0)
		if p.y > bot - 10:
			continue
		var c: Color = cave[i % cave.size()]
		_glow(p, 30, c, 0.12 + 0.05 * sin(t * 2.0 + i))
		_gem(p, 12 + _hash(i, 7) * 10.0, c)
	if stage >= 1:
		for p in [Vector2(176, 862), Vector2(546, 866)]:
			_mushroom(p, 0.7, Color("#7FF5E0"), t)
	if stage >= 2:
		# кристаллы-фонарики на ветках
		for i in 4:
			var p: Vector2 = [Vector2(70, 410), Vector2(180, 420), Vector2(560, 346), Vector2(680, 330)][i]
			var sw := sin(t * 1.5 + i) * 3.0
			ci.draw_line(p, p + Vector2(sw, 30), Color("#C9B88A"), 2.0, true)
			_glow(p + Vector2(sw, 40), 24, cave[i], 0.25)
			_gem(p + Vector2(sw, 40), 9, cave[i])
	if stage >= 3:
		for i in 5:
			var p := Vector2(250 + _hash(i, 11) * 220.0, 340 + _hash(i, 12) * 140.0)
			_gem(p, 6, cave[i % 4])
	# светлячки
	var flies := 4 + stage * 6
	for i in flies:
		var base := Vector2(60 + _hash(i, 13) * 600.0, 240 + _hash(i, 14) * 560.0)
		var p := base + Vector2(sin(t * (0.6 + _hash(i, 15)) + i) * 30.0, cos(t * (0.5 + _hash(i, 16)) + i * 2.0) * 20.0)
		var a := 0.5 + 0.5 * sin(t * 3.0 + i * 1.9)
		ci.draw_circle(p, 10, Color(1, 0.95, 0.4, 0.15 * a), true, -1.0, true)
		ci.draw_circle(p, 3.2, Color(1, 0.97, 0.6, 0.5 + 0.5 * a), true, -1.0, true)


func _nest_front(t: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(0.0, PI, i / 16.0)
		pts.append(Vector2(348 + cos(a) * 106, 710 + sin(a) * 26))
	var top := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI, 0.0, i / 16.0)
		top.append(Vector2(348 + cos(a) * 106, 708 + sin(a) * -6))
	pts.append_array(top)
	_fill(pts, Color("#9A6E42"), OUT, 4.0)
	for i in 10:
		var x := 256.0 + i * 19.0
		ci.draw_line(Vector2(x, 712), Vector2(x + 22, 724 + _hash(i, 21) * 6.0), Color("#D3A867"), 3.0, true)


func _mushroom(p: Vector2, k: float, col: Color, t: float) -> void:
	_glow(p + Vector2(0, -34) * k, 40 * k, col, 0.18 + 0.06 * sin(t * 2.0 + p.x))
	_fill(PackedVector2Array([p + Vector2(-7, 0) * k, p + Vector2(-5, -34) * k, p + Vector2(5, -34) * k, p + Vector2(7, 0) * k]), Color("#F2E8FF"))
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		cap.append(p + (Vector2(0, -32) + Vector2(cos(a) * 26, sin(a) * 22)) * k)
	_fill(cap, col, OUT, 3.0)
	for d in [Vector2(-10, -42), Vector2(6, -46), Vector2(14, -38)]:
		ci.draw_circle(p + d * k, 3.0 * k, Color(1, 1, 1, 0.7), true, -1.0, true)


# ---------- Грот аксолотля ----------

func _grotto(view: Rect2, stage: int, t: float) -> void:
	var top := view.position.y
	var bot := maxf(view.end.y, 900.0)
	ci.draw_polygon(PackedVector2Array([Vector2(view.position.x, top), Vector2(view.end.x, top), Vector2(view.end.x, bot), Vector2(view.position.x, bot)]),
		PackedColorArray([Color("#1B5C7A"), Color("#1B5C7A"), Color("#0A1E3C"), Color("#0A1E3C")]))
	# блики света сверху
	for i in 5:
		var x := 90.0 + i * 140.0 + sin(t * 0.4 + i) * 30.0
		var w := 50.0 + 20.0 * sin(t * 0.7 + i * 2.0)
		ci.draw_polygon(PackedVector2Array([Vector2(x - w * 0.3, top), Vector2(x + w * 0.3, top), Vector2(x + w + 60, 900), Vector2(x - w + 60, 900)]),
			PackedColorArray([Color(0.7, 1, 1, 0.13), Color(0.7, 1, 1, 0.13), Color(0.7, 1, 1, 0.0), Color(0.7, 1, 1, 0.0)]))
	# волны у поверхности
	for j in 2:
		var pts := PackedVector2Array()
		for i in 25:
			pts.append(Vector2(i * 30.0, maxf(top, 150.0) + 14 + j * 16 + sin(i * 0.8 + t * 1.6 + j) * 5.0))
		ci.draw_polyline(pts, Color(0.8, 1, 1, 0.18 - j * 0.07), 3.0, true)
	# скалы по бокам
	var rock := Color("#16304F")
	var rock2 := Color("#22466B")
	_fill(PackedVector2Array([Vector2(-240, maxf(top, 140.0)), Vector2(0, maxf(top, 140.0)), Vector2(70, 200), Vector2(150, 330), Vector2(120, 470), Vector2(176, 520),
		Vector2(150, 700), Vector2(200, 880), Vector2(-240, 880)]), rock, OUT, 5.0)
	_fill(PackedVector2Array([Vector2(960, maxf(top, 140.0)), Vector2(720, maxf(top, 140.0)), Vector2(650, 190), Vector2(590, 300), Vector2(616, 420), Vector2(560, 470),
		Vector2(600, 650), Vector2(540, 880), Vector2(960, 880)]), rock, OUT, 5.0)
	# уступы для украшений
	_oval(Vector2(98, 504), 88, 16, rock2, 0.0, OUT, 4.0)
	_oval(Vector2(630, 456), 92, 16, rock2, 0.0, OUT, 4.0)
	for p in [Vector2(60, 300), Vector2(90, 640), Vector2(660, 300), Vector2(640, 610)]:
		_oval(p, 26, 12, rock2, 0.3)
	# дно: песок и камешки
	var sand := PackedVector2Array()
	for i in 21:
		sand.append(Vector2(-240 + i * 60.0, 858 + sin(i * 1.1) * 10.0))
	sand.append(Vector2(960, bot + 2))
	sand.append(Vector2(-240, bot + 2))
	_fill(sand, Color("#3E5A6E"))
	ci.draw_polygon(PackedVector2Array([Vector2(-240, 900), Vector2(960, 900), Vector2(960, bot + 2), Vector2(-240, bot + 2)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.03, 0.05, 0.12, 0.8), Color(0.03, 0.05, 0.12, 0.8)]))
	var peb := [Color("#7C8FA6"), Color("#9C8AB5"), Color("#6C9C9A"), Color("#B59C86")]
	for i in 18:
		var p := Vector2(_hash(i, 31) * 720.0, 872 + _hash(i, 32) * 60.0)
		_oval(p, 8 + _hash(i, 33) * 8.0, 5 + _hash(i, 34) * 4.0, peb[i % 4])
	# водоросли
	var weeds := 3 + stage * 2
	for i in weeds:
		var x := 30.0 + fmod(i * 157.0 + 40.0, 660.0)
		var h := 120.0 + _hash(i, 35) * 120.0
		var pts := PackedVector2Array()
		for j in 10:
			var s := j / 9.0
			pts.append(Vector2(x + sin(t * 1.3 + i + s * 3.0) * 16.0 * s, 870 - h * s))
		var col := Color("#2FAE7A") if i % 2 == 0 else Color("#4FC48A")
		ci.draw_polyline(pts, col.darkened(0.3), 11.0, true)
		ci.draw_polyline(pts, col, 7.0, true)
		for j in range(2, 9, 2):
			_oval(pts[j] + Vector2(8 if j % 4 == 0 else -8, 0), 10, 4.5, col, 0.5 if j % 4 == 0 else -0.5)
	# светящиеся кристаллы на дне
	var cc := [Color("#3FD0FF"), Color("#B46CFF"), Color("#3DDC97"), Color("#FF8FD8"), Color("#9FF6FF")]
	var crystals := 2 + stage * 3
	for i in crystals:
		var p := Vector2(60 + fmod(i * 233.0 + 90.0, 600.0), 880 + _hash(i, 36) * 30.0)
		var c: Color = cc[i % cc.size()]
		_glow(p + Vector2(0, -16), 40, c, 0.14 + 0.05 * sin(t * 2.0 + i))
		for k in 3:
			var off := Vector2((k - 1) * 12, 0)
			var hh := 22.0 + (8.0 if k == 1 else 0.0) + _hash(i + k, 37) * 8.0
			_fill(PackedVector2Array([p + off + Vector2(-6, 0), p + off + Vector2(-5, -hh), p + off + Vector2(0, -hh - 8), p + off + Vector2(5, -hh), p + off + Vector2(6, 0)]),
				c, c.darkened(0.45), 2.0)
	if stage >= 2:
		for p in [Vector2(120, 330), Vector2(620, 320), Vector2(150, 690)]:
			_glow(p, 22, Color("#9FF6FF"), 0.2)
			_gem(p, 8, Color("#9FF6FF"))
	if stage >= 3:
		# стайка светящихся рыбок
		for i in 5:
			var p := Vector2(fposmod(t * 40.0 + i * 90.0, 900.0) - 90.0, 250 + sin(t + i) * 20.0 + i * 12.0)
			_oval(p, 9, 5, Color(1, 0.85, 0.4, 0.9))
			_fill(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-16, -5), p + Vector2(-16, 5)]), Color(1, 0.85, 0.4, 0.9))
	_bubbles(view, t, stage, false)


func _bubbles(view: Rect2, t: float, stage: int, front: bool) -> void:
	var n := (6 + stage * 3) if not front else 5
	for i in n:
		var speed := 40.0 + _hash(i, 41 + int(front)) * 50.0
		var x := _hash(i, 42 + int(front)) * 720.0
		var y := 900.0 - fposmod(t * speed + _hash(i, 43) * 800.0, 760.0)
		if front:
			# пузырьки изо рта аксолотля
			x = 340.0 + sin(t * 2.0 + i) * 10.0 + i * 3.0
			y = 600.0 - fposmod(t * 60.0 + i * 70.0, 380.0)
		if y < view.position.y + 10:
			continue
		var r := 3.0 + _hash(i, 44) * 6.0
		x += sin(t * 2.0 + i) * 6.0
		ci.draw_arc(Vector2(x, y), r, 0, TAU, 16, Color(0.85, 1, 1, 0.55), 2.0, true)
		ci.draw_circle(Vector2(x - r * 0.35, y - r * 0.35), r * 0.25, Color(1, 1, 1, 0.7), true, -1.0, true)


# ---------- Украшения ----------

## Рисует украшение id. p — точка, на которой предмет стоит (низ, середина);
## у «своих» подвесных (SELF_HUNG) p — точка подвеса.
func draw_decor(id: String, p: Vector2, k: float, t: float) -> void:
	match id:
		"owl_lantern": _lantern(p, k, t)
		"owl_birdhouse": _birdhouse(p, k)
		"owl_swing": _swing(p, k, t)
		"owl_moon": _moon_mobile(p, k, t)
		"owl_mushrooms":
			_mushroom(p + Vector2(-26, 0) * k, 0.8 * k, Color("#7FF5E0"), t)
			_mushroom(p + Vector2(22, 4) * k, 1.05 * k, Color("#C38BFF"), t + 1.0)
			_mushroom(p + Vector2(0, 6) * k, 0.6 * k, Color("#FFB547"), t + 2.0)
		"owl_hammock": _hammock(p, k, t)
		"owl_books": _books(p, k)
		"owl_nightlight": _nightlight(p, k, t)
		"owl_garland": _garland(p, k, t)
		"owl_nest": _rug(p, k)
		"axo_chest": _chest(p, k, t)
		"axo_coral": _coral(p, k, Color("#FF7BA8"), t)
		"axo_shell": _shell(p, k, t)
		"axo_castle": _castle(p, k, t)
		"axo_starfish": _starfish(p, k, t)
		"axo_bubble": _bubble_lamp(p, k, t)
		"axo_lily": _lily(p, k, t)
		"axo_tree":
			_coral(p + Vector2(-26, 0) * k, k * 1.25, Color("#4FD8C8"), t)
			_coral(p + Vector2(28, 2) * k, k * 0.95, Color("#B07CFF"), t + 1.0)
		"axo_anchor": _anchor(p, k)
		"axo_sofa": _sofa(p, k)


## Значок украшения для карточки гардероба (вписан в квадрат size вокруг c)
func draw_decor_icon(target: CanvasItem, id: String, c: Vector2, size: float, t: float) -> void:
	ci = target
	var h: float = DECOR_H.get(id, 60.0)
	var k := size / maxf(140.0, h * 1.25)
	if SELF_HUNG.has(id):
		draw_decor(id, c - Vector2(0, h * k * 0.55), k, t)
	else:
		draw_decor(id, c + Vector2(0, h * k * 0.5), k, t)


func _lantern(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -36) * k
	var fl := 0.5 + 0.5 * sin(t * 4.0)
	_glow(c, 60 * k, Color("#FFE27A"), 0.2 + 0.08 * fl)
	ci.draw_arc(p + Vector2(0, -74) * k, 9 * k, PI, TAU, 10, Color("#3A2A55"), 4 * k, true)
	_fill(_rrect(Rect2(p + Vector2(-24, -66) * k, Vector2(48, 10) * k), 4 * k), Color("#3A2A55"), OUT, 3.0)
	_oval(c, 24 * k, 28 * k, Color(1, 0.9, 0.5, 0.55), 0.0, Color("#3A2A55"), 4 * k)
	for i in 3:
		var d := Vector2(sin(t * 2.0 + i * 2.0) * 10.0, cos(t * 1.7 + i * 1.3) * 12.0) * k
		ci.draw_circle(c + d, 3.5 * k, Color(1, 1, 0.75), true, -1.0, true)
	_fill(_rrect(Rect2(p + Vector2(-20, -8) * k, Vector2(40, 8) * k), 3 * k), Color("#3A2A55"), OUT, 3.0)


func _birdhouse(p: Vector2, k: float) -> void:
	_fill(_rrect(Rect2(p + Vector2(-34, -74) * k, Vector2(68, 74) * k), 6 * k), Color("#E7B26A"), OUT, 4.0)
	_fill(PackedVector2Array([p + Vector2(-46, -70) * k, p + Vector2(0, -110) * k, p + Vector2(46, -70) * k]), Color("#E0556F"), OUT, 4.0)
	_oval(p + Vector2(0, -44) * k, 13 * k, 13 * k, Color("#2A1A3A"))
	ci.draw_line(p + Vector2(0, -22) * k, p + Vector2(0, -10) * k, Color("#8A5A3A"), 5 * k, true)
	ci.draw_line(p + Vector2(-10, -10) * k, p + Vector2(10, -10) * k, Color("#8A5A3A"), 5 * k, true)
	_oval(p + Vector2(22, -86) * k, 5 * k, 5 * k, Color(1, 1, 1, 0.5))


func _swing(p: Vector2, k: float, t: float) -> void:
	var ang := sin(t * 1.6) * 0.18
	var seat := p + Vector2(0, 120 * k).rotated(ang)
	for sx in [-1.0, 1.0]:
		ci.draw_line(p + Vector2(sx * 30, 0) * k, seat + Vector2(sx * 30, 0).rotated(ang) * k, Color("#C9B88A"), 3 * k, true)
	_fill(_rrect(Rect2(seat + Vector2(-40, -6) * k, Vector2(80, 12) * k), 5 * k), Color("#9A6A44"), OUT, 3.0)
	for sx in [-1.0, 1.0]:
		_oval(seat + Vector2(sx * 30, -10) * k, 9 * k, 6 * k, Color("#3FAF6E"), 0.0)


func _moon_mobile(p: Vector2, k: float, t: float) -> void:
	ci.draw_line(p, p + Vector2(0, 20) * k, Color("#C9B88A"), 2.5 * k, true)
	var bar := p + Vector2(0, 20) * k
	var ang := sin(t * 0.9) * 0.12
	var l := bar + Vector2(-56, 0).rotated(ang) * k
	var r := bar + Vector2(56, 0).rotated(ang) * k
	ci.draw_line(l, r, Color("#9A6A44"), 5 * k, true)
	var mc := bar + Vector2(0, 66) * k
	ci.draw_line(bar, mc - Vector2(0, 30) * k, Color("#C9B88A"), 2 * k, true)
	_glow(mc, 46 * k, Color("#FFF1B8"), 0.18)
	var crescent := PackedVector2Array()
	for i in 17:
		var a := lerpf(-PI * 0.75, PI * 0.75, i / 16.0)
		crescent.append(mc + Vector2(-cos(a), sin(a)) * 30 * k)
	for i in range(16, -1, -1):
		var a := lerpf(-PI * 0.75, PI * 0.75, i / 16.0)
		crescent.append(mc + Vector2(-cos(a) * 14 - 8, sin(a) * 22) * k)
	_fill(crescent, Color("#FFE58A"), OUT, 3.0)
	for side in [[l, 40.0], [r, 26.0]]:
		var e: Vector2 = side[0] + Vector2(0, side[1] * k)
		ci.draw_line(side[0], e, Color("#C9B88A"), 2 * k, true)
		var star := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0 + sin(t * 2.0) * 0.2
			star.append(e + Vector2(0, 14 * k) + Vector2(cos(a), sin(a)) * (14 if i % 2 == 0 else 6.5) * k)
		_fill(star, Color("#FFD34D"), OUT, 2.5)


func _hammock(p: Vector2, k: float, t: float) -> void:
	var sw := sin(t * 1.2) * 4.0
	for sx in [-1.0, 1.0]:
		ci.draw_line(p + Vector2(sx * 56, 0) * k, p + Vector2(sx * 56, -60) * k, Color("#7A5141"), 6 * k, true)
	var pts := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		pts.append(p + Vector2(lerpf(-56, 56, s), -54 + sin(s * PI) * (26 + sw)) * k)
	for i in range(12, -1, -1):
		var s := i / 12.0
		pts.append(p + Vector2(lerpf(-56, 56, s), -56 + sin(s * PI) * (16 + sw)) * k)
	_fill(pts, Color("#3FAF6E"), OUT, 3.0)
	for i in range(2, 11, 2):
		_oval(pts[i] + Vector2(0, -4) * k, 9 * k, 4 * k, Color("#6FD08E"), 0.4)
	_oval(p + Vector2(-24, -40 + sw * 0.5) * k, 14 * k, 8 * k, Color("#F3D6FF"), -0.2, OUT, 2.5)


func _books(p: Vector2, k: float) -> void:
	_fill(_rrect(Rect2(p + Vector2(-58, -8) * k, Vector2(116, 10) * k), 3 * k), Color("#9A6A44"), OUT, 3.0)
	var cols := [Color("#E0556F"), Color("#5FC8FF"), Color("#FFD34D"), Color("#3DDC97")]
	var x := -50.0
	for i in 4:
		var h: float = [54.0, 46.0, 58.0, 40.0][i]
		var w: float = [14.0, 12.0, 16.0, 13.0][i]
		_fill(_rrect(Rect2(p + Vector2(x, -8 - h) * k, Vector2(w, h) * k), 2 * k), cols[i], OUT, 2.5)
		ci.draw_line(p + Vector2(x + 2, -8 - h + 10) * k, p + Vector2(x + w - 2, -8 - h + 10) * k, Color(1, 1, 1, 0.6), 2 * k, true)
		x += w + 2
	# свеча
	_fill(_rrect(Rect2(p + Vector2(24, -32) * k, Vector2(12, 24) * k), 2 * k), Color("#FFF3E0"), OUT, 2.0)
	_glow(p + Vector2(30, -40) * k, 18 * k, Color("#FFB547"), 0.3)
	_oval(p + Vector2(30, -40) * k, 4 * k, 7 * k, Color("#FFD34D"))


func _nightlight(p: Vector2, k: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	_glow(p + Vector2(0, -44) * k, 70 * k, Color("#7FE3FF"), 0.18 + 0.08 * pulse)
	_oval(p + Vector2(0, -8) * k, 40 * k, 12 * k, Color("#4A3B6B"), 0.0, OUT, 3.0)
	for c in [[Vector2(-18, -10), 40.0, -0.25, Color("#9FF6FF")], [Vector2(16, -10), 46.0, 0.2, Color("#7FE3FF")], [Vector2(0, -10), 70.0, 0.0, Color("#C8FBFF")]]:
		var b: Vector2 = p + c[0] * k
		var h: float = c[1] * k
		var pts := PackedVector2Array([b + Vector2(-9, 0) * k, b + Vector2(-8, -h * 0.8).rotated(c[2]), b + Vector2(0, -h).rotated(c[2]),
			b + Vector2(8, -h * 0.8).rotated(c[2]), b + Vector2(9, 0) * k])
		_fill(pts, c[3], Color("#2A6A8A"), 2.5)
	_sparkle(p + Vector2(-6, -60) * k, (5 + 3 * pulse) * k, Color.WHITE)


func _garland(p: Vector2, k: float, t: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var s := i / 16.0
		pts.append(p + Vector2(lerpf(-110, 110, s), sin(s * PI) * 46 + sin(t * 1.4) * 4.0 * sin(s * PI)) * k)
	ci.draw_polyline(pts, Color("#3E9E62"), 4 * k, true)
	for i in range(1, 16, 2):
		_oval(pts[i] + Vector2(0, 4) * k, 8 * k, 4 * k, Color("#5BC27E"), 0.6)
	var cols := [Color("#FF4D6D"), Color("#B46CFF"), Color("#FF8FD8")]
	for i in range(2, 16, 2):
		var c := pts[i] + Vector2(0, 10) * k
		_oval(c, 7 * k, 7 * k, cols[i % 3], 0.0, OUT, 2.0)
		ci.draw_circle(c + Vector2(-2, -2) * k, 2 * k, Color(1, 1, 1, 0.7), true, -1.0, true)


func _rug(p: Vector2, k: float) -> void:
	_oval(p + Vector2(0, -12) * k, 70 * k, 20 * k, Color("#B98A52"), 0.0, OUT, 3.0)
	_oval(p + Vector2(0, -14) * k, 50 * k, 12 * k, Color("#D9AE70"))
	for i in 8:
		var x := -56.0 + i * 16.0
		ci.draw_line(p + Vector2(x, -18) * k, p + Vector2(x + 14, -6) * k, Color("#8A6239"), 2.5 * k, true)
	_oval(p + Vector2(18, -22) * k, 10 * k, 13 * k, Color("#F7F0FF"), 0.0, OUT, 2.0)
	ci.draw_circle(p + Vector2(15, -26) * k, 2 * k, Color("#9FC8FF"), true, -1.0, true)


func _chest(p: Vector2, k: float, t: float) -> void:
	var open := clampf(sin(t * 0.8) * 2.0, 0.0, 1.0)
	var gold := Color("#FFCB45")
	_glow(p + Vector2(0, -50) * k, 60 * k, gold, 0.25 * open)
	_fill(_rrect(Rect2(p + Vector2(-46, -46) * k, Vector2(92, 46) * k), 6 * k), Color("#9A5A34"), OUT, 4.0)
	ci.draw_rect(Rect2(p + Vector2(-46, -30) * k, Vector2(92, 6) * k), gold)
	if open > 0.05:
		for i in 5:
			_oval(p + Vector2(-30 + i * 15, -50 - (i % 2) * 6) * k, 7 * k, 7 * k, gold, 0.0, Color("#B07A1F"), 2.0)
		_gem(p + Vector2(10, -62) * k, 8 * k, Color("#FF4D6D"))
	var lid := PackedVector2Array()
	var hinge := p + Vector2(46, -46) * k
	for i in 11:
		var a := PI + PI * i / 10.0
		lid.append(p + Vector2(cos(a) * 46, -46 + sin(a) * 22) * k)
	for i in lid.size():
		lid[i] = hinge + (lid[i] - hinge).rotated(open * 0.9)
	_fill(lid, Color("#B06A3C"), OUT, 4.0)
	_oval(p + Vector2(0, -36) * k, 6 * k, 8 * k, gold, 0.0, OUT, 2.0)


func _coral(p: Vector2, k: float, col: Color, t: float) -> void:
	var sw := sin(t * 1.1 + p.x) * 0.05
	var branches := [[Vector2(0, 0), Vector2(0, -60)], [Vector2(0, -30), Vector2(-28, -70)], [Vector2(0, -40), Vector2(26, -84)],
		[Vector2(-14, -50), Vector2(-40, -54)], [Vector2(12, -60), Vector2(34, -60)], [Vector2(0, -60), Vector2(-4, -92)]]
	for b in branches:
		var a: Vector2 = p + b[0].rotated(sw) * k
		var e: Vector2 = p + b[1].rotated(sw) * k
		ci.draw_line(a, e, col.darkened(0.35), 14 * k, true)
	for b in branches:
		var a: Vector2 = p + b[0].rotated(sw) * k
		var e: Vector2 = p + b[1].rotated(sw) * k
		ci.draw_line(a, e, col, 9 * k, true)
		ci.draw_circle(e, 7 * k, col.lightened(0.2), true, -1.0, true)


func _shell(p: Vector2, k: float, t: float) -> void:
	var pink := Color("#FFC2D6")
	_oval(p + Vector2(0, -12) * k, 44 * k, 14 * k, pink.darkened(0.15), 0.0, OUT, 3.0)
	var pearl := p + Vector2(0, -20) * k
	_glow(pearl, 26 * k, Color.WHITE, 0.25 + 0.1 * sin(t * 2.0))
	_oval(pearl, 11 * k, 11 * k, Color("#F4F0FF"), 0.0, Color("#B9B0D6"), 2.0)
	ci.draw_circle(pearl + Vector2(-3, -3) * k, 3 * k, Color.WHITE, true, -1.0, true)
	var top := PackedVector2Array()
	var open := 0.35 + 0.1 * sin(t * 1.2)
	for i in 13:
		var a := PI + PI * i / 12.0
		top.append(p + Vector2(cos(a) * 44, -14 + sin(a) * 30) * k)
	var hinge := p + Vector2(0, -14) * k
	for i in top.size():
		top[i] = hinge + (top[i] - hinge).rotated(0.0) + Vector2(0, -open * 30.0 * k)
	_fill(top, pink, OUT, 3.0)
	for i in range(2, 12, 2):
		ci.draw_line(hinge + Vector2(0, -open * 30.0 * k), top[i], pink.darkened(0.2), 2.5 * k, true)


func _castle(p: Vector2, k: float, t: float) -> void:
	var sand := Color("#E6C98E")
	_fill(_rrect(Rect2(p + Vector2(-50, -56) * k, Vector2(100, 56) * k), 4 * k), sand, OUT, 4.0)
	for tx in [-44.0, 44.0]:
		_fill(_rrect(Rect2(p + Vector2(tx - 16, -86) * k, Vector2(32, 86) * k), 3 * k), sand.lightened(0.1), OUT, 4.0)
		_fill(PackedVector2Array([p + Vector2(tx - 20, -84) * k, p + Vector2(tx, -110) * k, p + Vector2(tx + 20, -84) * k]), Color("#E0556F"), OUT, 3.0)
		_oval(p + Vector2(tx, -60) * k, 5 * k, 8 * k, Color("#2A3A5A"))
	_fill(PackedVector2Array([p + Vector2(-14, 0) * k, p + Vector2(-14, -24) * k, p + Vector2(0, -34) * k, p + Vector2(14, -24) * k, p + Vector2(14, 0) * k]), Color("#5A3A2E"))
	ci.draw_line(p + Vector2(44, -110) * k, p + Vector2(44, -130) * k, OUT, 2.5 * k, true)
	var fw := sin(t * 3.0) * 3.0
	_fill(PackedVector2Array([p + Vector2(44, -130) * k, p + Vector2(62, -125 + fw) * k, p + Vector2(44, -120) * k]), Color("#FFD34D"))
	for i in 3:
		_oval(p + Vector2(-30 + i * 30, -40) * k, 4 * k, 4 * k, Color("#9FF6FF"))


func _starfish(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -32) * k
	var pts := PackedVector2Array()
	var rot := sin(t * 0.8) * 0.1
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0 + rot
		pts.append(c + Vector2(cos(a), sin(a)) * (32 if i % 2 == 0 else 15) * k)
	_fill(pts, Color("#FF8A4C"), OUT, 4.0)
	for i in 5:
		var a := -PI / 2.0 + i * TAU / 5.0 + rot
		for j in 2:
			ci.draw_circle(c + Vector2(cos(a), sin(a)) * (10 + j * 9) * k, 2.5 * k, Color("#FFD1A8"), true, -1.0, true)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * 6, -3) * k, 2.5 * k, OUT, true, -1.0, true)
	ci.draw_arc(c + Vector2(0, 2) * k, 5 * k, 0.2 * PI, 0.8 * PI, 8, OUT, 2 * k, true)


func _bubble_lamp(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -40 + sin(t * 1.5) * 3.0) * k
	_glow(c, 64 * k, Color("#9FF6FF"), 0.25)
	ci.draw_circle(c, 34 * k, Color(0.7, 1, 1, 0.18), true, -1.0, true)
	ci.draw_arc(c, 34 * k, 0, TAU, 40, Color(0.85, 1, 1, 0.8), 3 * k, true)
	ci.draw_circle(c, 12 * k, Color("#FFF6C8"), true, -1.0, true)
	_glow(c, 20 * k, Color("#FFE27A"), 0.4)
	ci.draw_arc(c, 24 * k, -2.4, -1.6, 10, Color(1, 1, 1, 0.7), 4 * k, true)
	for i in 3:
		var y := fposmod(t * 30.0 + i * 20.0, 60.0)
		ci.draw_arc(c + Vector2(sin(t + i) * 8, -40 - y) * k, (3 + i) * k, 0, TAU, 10, Color(0.85, 1, 1, 0.6 * (1.0 - y / 60.0)), 1.5, true)


func _lily(p: Vector2, k: float, t: float) -> void:
	# кувшинка на поверхности (p — у поверхности), под ней светлячок
	var c := p + Vector2(0, 10) * k
	var pad := PackedVector2Array()
	for i in 24:
		var a := 0.25 + (TAU - 0.5) * i / 23.0
		pad.append(c + Vector2(cos(a) * 56, sin(a) * 14) * k)
	pad.append(c)
	_fill(pad, Color("#3FAF6E"), OUT, 3.0)
	for i in 6:
		var a := -PI / 2.0 + (i - 2.5) * 0.45
		var tip := c + Vector2(cos(a) * 14, -6 + sin(a) * 26) * k
		_fill(PackedVector2Array([c + Vector2(-7, -4) * k, tip, c + Vector2(7, -4) * k]), Color("#FFB8D6"), Color("#E0709F"), 2.0)
	_oval(c + Vector2(0, -10) * k, 7 * k, 5 * k, Color("#FFD34D"))
	var f := c + Vector2(sin(t * 1.3) * 26, 40 + cos(t * 1.7) * 10) * k
	_glow(f, 26 * k, Color("#FFF27A"), 0.35)
	ci.draw_circle(f, 4 * k, Color(1, 1, 0.75), true, -1.0, true)


func _anchor(p: Vector2, k: float) -> void:
	var grey := Color("#8FA3B8")
	ci.draw_line(p + Vector2(0, -8) * k, p + Vector2(0, -88) * k, OUT, 16 * k, true)
	ci.draw_line(p + Vector2(0, -8) * k, p + Vector2(0, -88) * k, grey, 10 * k, true)
	ci.draw_line(p + Vector2(-26, -70) * k, p + Vector2(26, -70) * k, OUT, 14 * k, true)
	ci.draw_line(p + Vector2(-26, -70) * k, p + Vector2(26, -70) * k, grey, 8 * k, true)
	ci.draw_arc(p + Vector2(0, -96) * k, 11 * k, 0, TAU, 20, OUT, 9 * k, true)
	ci.draw_arc(p + Vector2(0, -96) * k, 11 * k, 0, TAU, 20, grey, 5 * k, true)
	ci.draw_arc(p + Vector2(0, -42) * k, 38 * k, 0.15 * PI, 0.85 * PI, 20, OUT, 14 * k, true)
	ci.draw_arc(p + Vector2(0, -42) * k, 38 * k, 0.15 * PI, 0.85 * PI, 20, grey, 8 * k, true)
	for sx in [-1.0, 1.0]:
		var tip := p + Vector2(sx * 33, -26) * k
		_fill(PackedVector2Array([tip + Vector2(-8, 4) * k, tip + Vector2(sx * 8, -14) * k, tip + Vector2(8, 4) * k]), grey, OUT, 2.5)
	ci.draw_arc(p + Vector2(10, -78) * k, 16 * k, -1.2, 2.2, 14, Color("#C9A46A"), 4 * k, true)


func _sofa(p: Vector2, k: float) -> void:
	var stone := Color("#6E7F99")
	_fill(_rrect(Rect2(p + Vector2(-60, -58) * k, Vector2(120, 40) * k), 16 * k), stone, OUT, 4.0)
	_fill(_rrect(Rect2(p + Vector2(-66, -30) * k, Vector2(132, 30) * k), 12 * k), stone.lightened(0.1), OUT, 4.0)
	_oval(p + Vector2(-14, -32) * k, 34 * k, 9 * k, Color("#4FC48A"), 0.0, OUT, 2.5)
	_oval(p + Vector2(28, -34) * k, 22 * k, 8 * k, Color("#6FD8A0"), 0.0, OUT, 2.5)
	for d in [Vector2(-40, -46), Vector2(30, -50), Vector2(48, -12)]:
		ci.draw_circle(p + d * k, 3 * k, Color(0, 0, 0, 0.2), true, -1.0, true)
