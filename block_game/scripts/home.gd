extends RefCounted
## Дома героев Cascado и украшения для них. Всё рисуется кодом.
##   совёнок — дупло большого дерева под ночным небом, корни уходят к кристальной пещере;
##   аксолотль — подводный грот: вода, пузырьки, водоросли, кристаллы на дне;
##   щенок — будка в ночном саду у входа в кристальную пещеру (забор, фонарики, светлячки);
##   котик — уютный чердак с круглым окном на луну и кристаллы пещеры (корзинка, полки, ковёр).
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
	"puppy": {
		"floor_l": [Vector2(92, 874), 1.0], "floor_r": [Vector2(640, 874), 1.0],
		"wall_l": [Vector2(52, 738), 0.72], "wall_r": [Vector2(622, 556), 0.8],
		"hang": [Vector2(142, 418), 0.95], "near": [Vector2(516, 872), 0.68],
	},
	"kitten": {
		"floor_l": [Vector2(98, 874), 1.0], "floor_r": [Vector2(626, 874), 1.0],
		"wall_l": [Vector2(98, 612), 0.8], "wall_r": [Vector2(626, 640), 0.8],
		"hang": [Vector2(604, 456), 0.75], "near": [Vector2(530, 874), 0.68],
	},
}
## В этих домах «сверху» — высокая полка: предмет стоит, а не висит на нитке
const HANG_SHELF := ["kitten"]
## Положение и масштаб героя в сцене
const HERO_AT := {"owl": [Vector2(338, 606), 0.8], "axolotl": [Vector2(340, 590), 0.95],
	"puppy": [Vector2(340, 766), 0.82], "kitten": [Vector2(360, 752), 0.86]}
## Высота предмета (для подвешивания: верх предмета — на конце нитки)
const DECOR_H := {
	"owl_lantern": 74.0, "owl_birdhouse": 110.0, "owl_moon": 110.0, "owl_mushrooms": 64.0,
	"owl_hammock": 60.0, "owl_books": 72.0, "owl_nightlight": 84.0, "owl_garland": 50.0, "owl_nest": 26.0,
	"owl_swing": 130.0, "axo_chest": 96.0, "axo_coral": 92.0, "axo_shell": 56.0, "axo_castle": 116.0,
	"axo_starfish": 62.0, "axo_bubble": 80.0, "axo_lily": 64.0, "axo_tree": 130.0, "axo_anchor": 104.0, "axo_sofa": 60.0,
	"pup_ball": 46.0, "pup_bone": 30.0, "pup_bowl": 38.0, "pup_sign": 70.0, "pup_flowerbed": 76.0, "pup_pinwheel": 112.0,
	"pup_lamp": 80.0, "pup_bed": 44.0, "pup_kite": 150.0, "pup_teddy": 84.0,
	"kit_yarn": 48.0, "kit_mouse": 30.0, "kit_pillow": 48.0, "kit_picture": 84.0, "kit_catnip": 84.0, "kit_box": 66.0,
	"kit_scratcher": 124.0, "kit_lamp": 168.0, "kit_aquarium": 76.0, "kit_tree": 176.0,
}
## Предметы, у которых своя нитка/верёвка (рисуются от точки подвеса)
const SELF_HUNG := ["owl_swing", "owl_moon", "owl_garland", "axo_lily", "pup_kite"]

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
	if spot == "hang" and not HANG_SHELF.has(kind):
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
	elif kind == "puppy":
		_garden(view, stage, t)
	elif kind == "kitten":
		_attic(view, stage, t)
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
	elif kind == "kitten":
		_basket_front()
	_place_decor(kind, "near", placed.get("near", ""), t)
	if kind == "axolotl":
		_bubbles(view, t, stage, true)
	for spot in SPOTS[kind]:
		var sp: Array = SPOTS[kind][spot]
		var c: Vector2 = sp[0] + (Vector2(0, 70) if spot == "hang" and not HANG_SHELF.has(kind) else Vector2(0, -34)) * sp[1]
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
	if spot == "hang" and not SELF_HUNG.has(id) and not HANG_SHELF.has(kind):
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


# ---------- Сад щенка ----------

## Ночное небо со звёздами (общая часть сада и вида из окна)
func _night_sky(view: Rect2, top: float, bot: float, t: float, n: int) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(view.position.x, top), Vector2(view.end.x, top), Vector2(view.end.x, bot), Vector2(view.position.x, bot)]),
		PackedColorArray([Color("#0B0826"), Color("#0B0826"), Color("#2C1F5C"), Color("#2C1F5C")]))
	for i in n:
		var p := Vector2(_hash(i, 51) * 720.0, lerpf(maxf(top, 110.0), bot - 60.0, _hash(i, 52)))
		if p.y < top:
			continue
		var tw := 0.4 + 0.6 * absf(sin(t * (0.8 + _hash(i, 53)) + i))
		var r := 1.2 + _hash(i, 54) * 2.2
		ci.draw_circle(p, r, Color(1, 0.97, 0.85, tw * 0.85), true, -1.0, true)
		if r > 3.0:
			_sparkle(p, r * 2.6 * tw, Color(1, 1, 0.9, 0.6 * tw))


func _moon(mc: Vector2, r: float, glow: float) -> void:
	_glow(mc, r * 2.4, Color("#FFF1B8"), glow)
	_oval(mc, r, r, Color("#FFF3C9"))
	_oval(mc + Vector2(r * 0.12, r * 0.1), r * 0.86, r * 0.86, Color("#FFF8DC"))
	for cr in [[Vector2(-0.3, -0.22), 0.2], [Vector2(0.26, 0.26), 0.15], [Vector2(0.35, -0.35), 0.1]]:
		_oval(mc + cr[0] * r, cr[1] * r, cr[1] * r, Color("#EFDDA0"))


## Фейерверк: вспышки по очереди (последняя ступень сада)
func _fireworks(t: float) -> void:
	var cols := [Color("#FF6FA8"), Color("#7FE3FF"), Color("#FFD34D"), Color("#B48CFF")]
	for i in 3:
		var period := 3.2
		var ph := fposmod(t + i * 1.07, period) / period
		if ph > 0.55:
			continue
		var c := Vector2(170 + i * 190 + _hash(int(t / period) + i, 61) * 60.0, 300 + _hash(int(t / period) + i, 62) * 90.0)
		var k := ph / 0.55
		var a := 1.0 - k
		var col: Color = cols[(i + int(t / period)) % 4]
		ci.draw_circle(c, 10 + 60 * k, Color(col, 0.10 * a), true, -1.0, true)
		for j in 12:
			var ang := j * TAU / 12.0
			var r1 := 14.0 + 62.0 * k
			var p1 := c + Vector2(cos(ang), sin(ang)) * r1 + Vector2(0, 18 * k * k)
			var p0 := c + Vector2(cos(ang), sin(ang)) * r1 * 0.6 + Vector2(0, 10 * k * k)
			ci.draw_line(p0, p1, Color(col, a), 3.0, true)
			ci.draw_circle(p1, 2.6, Color(1, 1, 1, a), true, -1.0, true)


func _garden(view: Rect2, stage: int, t: float) -> void:
	var top := view.position.y
	var bot := maxf(view.end.y, 900.0)
	_night_sky(view, top, 870.0, t, 44)
	if stage >= 3:
		# радужное сияние
		var rc := [Color(1.0, 0.45, 0.6), Color(1.0, 0.8, 0.4), Color(0.45, 1.0, 0.7), Color(0.45, 0.75, 1.0), Color(0.75, 0.5, 1.0)]
		for j in 5:
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in 13:
				var x := i * 60.0
				pts.append(Vector2(x, 250.0 + j * 18.0 + sin(x * 0.01 + t * 0.4) * 24.0))
				cols.append(Color(rc[j], 0.0))
			for i in range(12, -1, -1):
				var x := i * 60.0
				pts.append(Vector2(x, 250.0 + j * 18.0 + sin(x * 0.01 + t * 0.4) * 24.0 + 40.0))
				cols.append(Color(rc[j], 0.09))
			ci.draw_polygon(pts, cols)
		_fireworks(t)
	_moon(Vector2(612, 300), 42, 0.12 + stage * 0.02)
	# далёкие холмы
	var hills := PackedVector2Array([Vector2(-240, 880)])
	for i in 21:
		hills.append(Vector2(-240 + i * 60.0, 700 + sin(i * 1.1 + 0.5) * 22.0))
	hills.append(Vector2(960, 880))
	_fill(hills, Color("#1D1645"))

	# скала со входом в кристальную пещеру (справа)
	var rock := PackedVector2Array([Vector2(408, 880), Vector2(430, 690), Vector2(482, 590), Vector2(548, 520), Vector2(632, 486),
		Vector2(720, 494), Vector2(960, 520), Vector2(960, 880)])
	_fill(rock, Color("#2B2552"), OUT, 5.0)
	_fill(PackedVector2Array([Vector2(470, 610), Vector2(548, 534), Vector2(632, 502), Vector2(700, 508), Vector2(640, 540), Vector2(560, 580)]), Color("#3A3368"))
	# уступ для украшения
	_fill(_chaikin(PackedVector2Array([Vector2(548, 546), Vector2(702, 542), Vector2(694, 566), Vector2(640, 574), Vector2(560, 566)])), Color("#3E3870"), OUT, 4.0)
	ci.draw_line(Vector2(560, 550), Vector2(690, 547), Color(1, 1, 1, 0.18), 3.0, true)
	# вход в пещеру: тёмная арка, внутри светятся кристаллы
	var mouth := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		mouth.append(Vector2(596 + cos(a) * 86, 870 + sin(a) * 196))
	_fill(mouth, Color("#120B26"), Color("#1A1236"), 6.0)
	var cave := [Color("#B46CFF"), Color("#3FD0FF"), Color("#3DDC97"), Color("#FF8FD8")]
	_glow(Vector2(596, 800), 90, Color("#7FE3FF"), 0.10 + 0.03 * sin(t * 1.5))
	for i in 5:
		var cp := Vector2(536 + i * 30, 860 - _hash(i, 71) * 30.0)
		var c: Color = cave[i % 4]
		_glow(cp + Vector2(0, -16), 26, c, 0.16 + 0.05 * sin(t * 2.0 + i))
		var h := 26.0 + _hash(i, 72) * 26.0
		_fill(PackedVector2Array([cp + Vector2(-8, 0), cp + Vector2(-6, -h), cp + Vector2(0, -h - 10), cp + Vector2(6, -h), cp + Vector2(8, 0)]), c, c.darkened(0.45), 2.0)
		ci.draw_line(cp + Vector2(-3, -4), cp + Vector2(-3, -h + 2), Color(1, 1, 1, 0.35), 2.0, true)
	# кристаллы на краях арки
	for q in [[Vector2(512, 700), 14.0, 0], [Vector2(680, 690), 12.0, 1], [Vector2(530, 640), 9.0, 3], [Vector2(660, 630), 10.0, 2]]:
		_glow(q[0], q[1] * 2.6, cave[q[2]], 0.16)
		_gem(q[0], q[1], cave[q[2]])
	if stage >= 2:
		for q in [[Vector2(470, 760), 10.0, 1], [Vector2(700, 760), 11.0, 0], [Vector2(560, 500), 9.0, 2]]:
			_glow(q[0], q[1] * 2.6, cave[q[2]], 0.16)
			_gem(q[0], q[1], cave[q[2]])

	# дерево слева с веткой (для подвеса)
	var bark := Color("#5B3A2E")
	_fill(PackedVector2Array([Vector2(-60, 880), Vector2(-50, 380), Vector2(40, 380), Vector2(52, 880)]), bark, OUT, 5.0)
	_fill(PackedVector2Array([Vector2(30, 450), Vector2(36, 420), Vector2(130, 406), Vector2(196, 384), Vector2(204, 398), Vector2(140, 426), Vector2(40, 470)]), bark, OUT, 4.0)
	var leaf := [Color("#173A35"), Color("#1F4C40"), Color("#27604C")]
	for layer in 3:
		for b in [[Vector2(-20, 330), 120.0], [Vector2(90, 300), 90.0], [Vector2(-60, 430), 80.0], [Vector2(190, 362), 46.0]]:
			var c: Vector2 = b[0] + Vector2(sin(t * 0.7 + b[1]) * 3.0, layer * 12.0 - 12.0)
			_oval(c, b[1] * (1.0 - layer * 0.18), b[1] * (0.78 - layer * 0.15), leaf[layer])
	for lp in [Vector2(170, 380), Vector2(120, 398), Vector2(206, 372)]:
		_oval(lp, 14, 7, Color("#2F7A55"), -0.4)

	# забор-штакетник
	var picket := Color("#D9CBE0")
	ci.draw_rect(Rect2(-240, 772, 680, 12), picket.darkened(0.25))
	ci.draw_rect(Rect2(-240, 822, 680, 12), picket.darkened(0.25))
	for i in 12:
		var x := -10.0 + i * 38.0
		var hgt := 108.0 if i % 3 == 0 else 96.0
		var pk := PackedVector2Array([Vector2(x - 12, 868), Vector2(x - 12, 868 - hgt + 12), Vector2(x, 868 - hgt), Vector2(x + 12, 868 - hgt + 12), Vector2(x + 12, 868)])
		_fill(pk, picket, OUT, 3.0)
		ci.draw_line(Vector2(x - 7, 868 - hgt + 16), Vector2(x - 7, 860), Color(1, 1, 1, 0.35), 3.0, true)
	# садовые фонарики на столбиках
	var lamps := [Vector2(166, 750), Vector2(470, 742)] if stage >= 1 else []
	for i in lamps.size():
		var lp: Vector2 = lamps[i]
		ci.draw_line(lp, lp + Vector2(0, 120), Color("#3A2A55"), 6.0, true)
		_glow(lp + Vector2(0, -16), 50, Color("#FFD98A"), 0.2 + 0.05 * sin(t * 3.0 + i))
		_oval(lp + Vector2(0, -16), 13, 16, Color("#FFE9A8"), 0.0, Color("#3A2A55"), 3.0)
		_fill(PackedVector2Array([lp + Vector2(-16, -30), lp + Vector2(0, -42), lp + Vector2(16, -30)]), Color("#3A2A55"))
	if stage >= 2:
		# гирлянда-лампочки вдоль забора
		var pts := PackedVector2Array()
		for i in 25:
			var s := i / 24.0
			pts.append(Vector2(lerpf(-20, 440, s), 770 + sin(s * PI * 4.0) * 10.0 + 10.0))
		ci.draw_polyline(pts, Color("#2A2040"), 2.0, true)
		var bc := [Color("#FF6FA8"), Color("#FFD34D"), Color("#7FE3FF"), Color("#9CF58A")]
		for i in range(1, 25, 2):
			var a := 0.6 + 0.4 * sin(t * 3.0 + i)
			ci.draw_circle(pts[i] + Vector2(0, 6), 9, Color(bc[i % 4], 0.2 * a), true, -1.0, true)
			ci.draw_circle(pts[i] + Vector2(0, 6), 4.5, Color(bc[i % 4], a), true, -1.0, true)

	# будка
	_doghouse(stage, t)

	# земля и трава
	_fill(PackedVector2Array([Vector2(-240, 866), Vector2(960, 866), Vector2(960, bot + 2), Vector2(-240, bot + 2)]), Color("#1A1230"))
	var grass := PackedVector2Array([Vector2(-240, 900)])
	for i in 49:
		var x := -240.0 + i * 25.0
		grass.append(Vector2(x, 864 + (0.0 if i % 2 == 0 else -10.0) + sin(i * 0.7) * 3.0))
	grass.append(Vector2(960, 900))
	_fill(grass, Color("#2E5A3A"))
	ci.draw_rect(Rect2(-240, 880, 1200, 22), Color("#24482F"))
	# дорожка из камешков к пещере
	for i in 4:
		_oval(Vector2(470 + i * 36, 890 - i * 3), 16, 6, Color("#6E6A8E"), 0.0, OUT, 2.0)
	# корни и кристаллы под землёй
	for i in 3 + stage * 3:
		var p := Vector2(40 + _hash(i, 75) * 640.0, 960 + _hash(i, 76) * 260.0)
		if p.y > bot - 10:
			continue
		var c: Color = cave[i % 4]
		_glow(p, 30, c, 0.12 + 0.05 * sin(t * 2.0 + i))
		_gem(p, 12 + _hash(i, 77) * 10.0, c)
	# цветы у забора
	var fl := [Color("#FF8FC8"), Color("#FFE27A"), Color("#B8A2FF"), Color("#FFFFFF")]
	var nf := 3 + stage * 3
	for i in nf:
		var x := 20.0 + fmod(i * 97.0 + 30.0, 420.0)
		var y := 868.0 + _hash(i, 78) * 6.0
		var sw := sin(t * 1.4 + i) * 2.0
		ci.draw_line(Vector2(x, y), Vector2(x + sw, y - 22), Color("#3F8A55"), 3.0, true)
		var fc := Vector2(x + sw, y - 24)
		for k in 5:
			ci.draw_circle(fc + Vector2(0, -5).rotated(k * TAU / 5.0), 4.2, fl[i % 4], true, -1.0, true)
		ci.draw_circle(fc, 3.0, Color("#FFB547"), true, -1.0, true)
	# светлячки
	for i in 4 + stage * 5:
		var base := Vector2(40 + _hash(i, 81) * 640.0, 420 + _hash(i, 82) * 420.0)
		var p := base + Vector2(sin(t * (0.6 + _hash(i, 83)) + i) * 30.0, cos(t * (0.5 + _hash(i, 84)) + i * 2.0) * 20.0)
		var a := 0.5 + 0.5 * sin(t * 3.0 + i * 1.9)
		ci.draw_circle(p, 10, Color(1, 0.95, 0.4, 0.15 * a), true, -1.0, true)
		ci.draw_circle(p, 3.2, Color(1, 0.97, 0.6, 0.5 + 0.5 * a), true, -1.0, true)


func _doghouse(stage: int, t: float) -> void:
	var wood := Color("#C88A58")
	var wood_d := Color("#9E6640")
	# стены
	var wall := PackedVector2Array([Vector2(196, 868), Vector2(196, 592), Vector2(340, 474), Vector2(484, 592), Vector2(484, 868)])
	ci.draw_polygon(wall, PackedColorArray([wood_d, wood, wood.lightened(0.1), wood, wood_d]))
	var cw := wall.duplicate()
	cw.append(wall[0])
	ci.draw_polyline(cw, OUT, 5.0, true)
	# доски
	for i in 9:
		var y := 620.0 + i * 28.0
		ci.draw_line(Vector2(200, y), Vector2(480, y), Color(0.35, 0.18, 0.1, 0.35), 2.5, true)
	# круглый вход: тёмный, с тёплым светом изнутри
	var door := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		door.append(Vector2(340 + cos(a) * 94, 760 + sin(a) * 112))
	door.append(Vector2(434, 868))
	door.append(Vector2(246, 868))
	_fill(door, Color("#7A4A30"), OUT, 5.0)
	var inner := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		inner.append(Vector2(340 + cos(a) * 80, 762 + sin(a) * 98))
	inner.append(Vector2(420, 868))
	inner.append(Vector2(260, 868))
	_fill(inner, Color("#1E1028"))
	_glow(Vector2(340, 820), 96, Color("#FFB547"), 0.12 + stage * 0.05)
	# крыша
	var roof := Color("#E0596F")
	var rl := PackedVector2Array([Vector2(170, 612), Vector2(340, 456), Vector2(352, 470), Vector2(352, 484), Vector2(186, 636)])
	var rr := PackedVector2Array([Vector2(510, 612), Vector2(340, 456), Vector2(328, 470), Vector2(328, 484), Vector2(494, 636)])
	_fill(rl, roof, OUT, 5.0)
	_fill(rr, roof.darkened(0.12), OUT, 5.0)
	for i in 4:
		var s := 0.2 + i * 0.2
		ci.draw_line(Vector2(170, 612).lerp(Vector2(340, 456), s) + Vector2(4, 8), Vector2(186, 636).lerp(Vector2(352, 484), s), Color(0.5, 0.12, 0.2, 0.5), 3.0, true)
		ci.draw_line(Vector2(510, 612).lerp(Vector2(340, 456), s) + Vector2(-4, 8), Vector2(494, 636).lerp(Vector2(328, 484), s), Color(0.5, 0.12, 0.2, 0.5), 3.0, true)
	ci.draw_line(Vector2(176, 608), Vector2(338, 460), Color(1, 1, 1, 0.3), 3.0, true)
	# лунный блик на коньке и снег-звёздочка
	_oval(Vector2(340, 462), 10, 10, Color("#FFD34D"), 0.0, OUT, 3.0)
	if stage >= 1:
		# табличка-косточка над входом с отпечатком лапки
		_bone(Vector2(340, 618), 0.75, Color("#FFF3E0"))
		_paw(Vector2(340, 618), 0.42, Color("#C88A58"))
	# подушка у входа (на ней сидит щенок)
	_oval(Vector2(340, 866), 124, 26, Color("#5E3C8A"), 0.0, OUT, 4.0)
	_oval(Vector2(340, 858), 112, 22, Color("#8C63D0"))
	_oval(Vector2(320, 852), 70, 9, Color(1, 1, 1, 0.18))
	for i in 7:
		var x := 250.0 + i * 30.0
		ci.draw_circle(Vector2(x, 862 + sin(i * 1.3) * 3.0), 3.0, Color("#FFD34D"), true, -1.0, true)


func _bone(c: Vector2, k: float, col: Color) -> void:
	_fill(_rrect(Rect2(c + Vector2(-30, -8) * k, Vector2(60, 16) * k), 6 * k), col, OUT, 3.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_oval(c + Vector2(sx * 32, sy * 8) * k, 11 * k, 11 * k, col, 0.0, OUT, 3.0)
	ci.draw_rect(Rect2(c + Vector2(-30, -6) * k, Vector2(60, 12) * k), col)
	for sx in [-1.0, 1.0]:
		_oval(c + Vector2(sx * 32, 0) * k, 9 * k, 9 * k, col)
	ci.draw_line(c + Vector2(-26, -4) * k, c + Vector2(22, -4) * k, Color(1, 1, 1, 0.6), 3 * k, true)


func _paw(c: Vector2, k: float, col: Color) -> void:
	_oval(c + Vector2(0, 6) * k, 14 * k, 11 * k, col)
	for d in [Vector2(-15, -8), Vector2(-5, -15), Vector2(5, -15), Vector2(15, -8)]:
		_oval(c + d * k, 5.5 * k, 6.5 * k, col)


# ---------- Чердак котика ----------

func _attic(view: Rect2, stage: int, t: float) -> void:
	var top := view.position.y
	var bot := maxf(view.end.y, 900.0)
	# стена с обоями
	ci.draw_polygon(PackedVector2Array([Vector2(view.position.x, top), Vector2(view.end.x, top), Vector2(view.end.x, 880), Vector2(view.position.x, 880)]),
		PackedColorArray([Color("#3A2252"), Color("#3A2252"), Color("#4E2E5E"), Color("#4E2E5E")]))
	for i in 9:
		for j in 9:
			var p := Vector2(-20 + i * 90 + (j % 2) * 45, 150 + j * 84)
			if p.y < top or p.y > 860:
				continue
			_sparkle(p, 6, Color(1, 0.85, 0.95, 0.10))
	# круглое окно: ночь, луна, кристальная пещера вдали
	var wc := Vector2(360, 420)
	var wr := 130.0
	_glow(wc, wr * 1.9, Color("#9FB8FF"), 0.08 + 0.02 * stage)
	_oval(wc, wr + 22, wr + 22, Color("#8A5A44"), 0.0, OUT, 6.0)
	_oval(wc, wr + 8, wr + 8, Color("#6E4434"))
	var sky := PackedVector2Array()
	var scol := PackedColorArray()
	for i in 40:
		var a := TAU * i / 40.0
		var v := wc + Vector2(cos(a), sin(a)) * wr
		sky.append(v)
		scol.append(Color("#0E0A30").lerp(Color("#3A2A70"), clampf((v.y - wc.y + wr) / (2 * wr), 0.0, 1.0)))
	ci.draw_polygon(sky, scol)
	for i in 18:
		var a := _hash(i, 91) * TAU
		var d := sqrt(_hash(i, 92)) * wr * 0.9
		var p := wc + Vector2(cos(a), sin(a)) * d
		if p.y > wc.y + 40:
			continue
		var tw := 0.4 + 0.6 * absf(sin(t * (0.8 + _hash(i, 93)) + i))
		ci.draw_circle(p, 1.4 + _hash(i, 94) * 1.6, Color(1, 0.97, 0.85, tw), true, -1.0, true)
	_moon(wc + Vector2(-50, -52), 28, 0.14)
	# холм с пещерой и кристаллами за окном
	var hill := PackedVector2Array()
	for i in 21:
		var a := lerpf(0.12 * PI, 0.88 * PI, i / 20.0)
		hill.append(wc + Vector2(cos(a), sin(a)) * wr)
	hill.append(wc + Vector2(-wr * 0.95, 34))
	hill.append(wc + Vector2(-40, 22))
	hill.append(wc + Vector2(20, 30))
	hill.append(wc + Vector2(wr * 0.95, 20))
	_fill(hill, Color("#241C4A"))
	var mouth := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		mouth.append(wc + Vector2(30, 96) + Vector2(cos(a) * 34, sin(a) * 46))
	_fill(mouth, Color("#0E0820"))
	var cave := [Color("#B46CFF"), Color("#3FD0FF"), Color("#3DDC97"), Color("#FF8FD8")]
	var nc := 3 + stage * 2
	for i in nc:
		var p := wc + Vector2(-86 + fmod(i * 47.0, 190.0), 70 + _hash(i, 95) * 40.0)
		if (p - wc).length() > wr - 12:
			continue
		var c: Color = cave[i % 4]
		_glow(p, 18, c, 0.2 + 0.06 * sin(t * 2.0 + i))
		_gem(p, 6 + _hash(i, 96) * 4.0, c)
	# переплёт окна
	ci.draw_line(wc + Vector2(-wr, 0), wc + Vector2(wr, 0), Color("#8A5A44"), 10.0, true)
	ci.draw_line(wc + Vector2(0, -wr), wc + Vector2(0, wr), Color("#8A5A44"), 10.0, true)
	ci.draw_arc(wc + Vector2(-20, -20), wr * 0.8, 3.6, 4.3, 12, Color(1, 1, 1, 0.18), 6.0, true)
	# подоконник
	_fill(_rrect(Rect2(wc + Vector2(-150, wr + 14), Vector2(300, 22)), 8), Color("#A06A4E"), OUT, 4.0)
	if stage >= 2:
		# свечи на подоконнике
		for x in [-120.0, 112.0]:
			var cp := wc + Vector2(x, wr + 14)
			_fill(_rrect(Rect2(cp + Vector2(-8, -30), Vector2(16, 30)), 3), Color("#FFF3E0"), OUT, 2.0)
			_glow(cp + Vector2(0, -38), 26, Color("#FFB547"), 0.3 + 0.08 * sin(t * 6.0 + x))
			_oval(cp + Vector2(0, -38 + sin(t * 8.0 + x) * 1.0), 4, 7, Color("#FFD34D"))
	# скошенный потолок с балками
	var wood := Color("#5E3B3A")
	var ct := minf(top - 2.0, 100.0)
	# скаты сходятся в конёк (360, 110): y = 110 + 0.75·|x − 360|
	_fill(PackedVector2Array([Vector2(-240, ct), Vector2(362, ct), Vector2(362, 110), Vector2(-240, 560)]), wood)
	_fill(PackedVector2Array([Vector2(960, ct), Vector2(358, ct), Vector2(358, 110), Vector2(960, 560)]), wood.darkened(0.1))
	for k in 5:
		var d := 40.0 + k * 70.0
		ci.draw_line(Vector2(-240, 560 - d), Vector2(360, 110 - d), Color(0.2, 0.1, 0.12, 0.4), 3.0, true)
		ci.draw_line(Vector2(960, 560 - d), Vector2(360, 110 - d), Color(0.2, 0.1, 0.12, 0.4), 3.0, true)
	ci.draw_line(Vector2(360, ct), Vector2(360, 110), Color(0.2, 0.1, 0.12, 0.5), 4.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(-240, 560), Vector2(360, 110), Vector2(960, 560)]), OUT, 20.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(-240, 560), Vector2(360, 110), Vector2(960, 560)]), Color("#7A5048"), 14.0, true)
	if stage >= 1:
		# гирлянда вдоль скатов
		var bc := [Color("#FFD34D"), Color("#FF8FC8"), Color("#9FF6FF")]
		for side in [-1.0, 1.0]:
			var a0 := Vector2(360 + side * 40, 140)
			var a1 := Vector2(360 + side * 380, 395)
			var pts := PackedVector2Array()
			for i in 13:
				var s := i / 12.0
				pts.append(a0.lerp(a1, s) + Vector2(0, 22 + sin(s * PI * 3.0) * 12.0))
			ci.draw_polyline(pts, Color("#2A1A30"), 2.0, true)
			for i in range(1, 13):
				var a := 0.6 + 0.4 * sin(t * 2.5 + i + side)
				ci.draw_circle(pts[i] + Vector2(0, 6), 10, Color(bc[i % 3], 0.18 * a), true, -1.0, true)
				ci.draw_circle(pts[i] + Vector2(0, 6), 4.5, Color(bc[i % 3], a), true, -1.0, true)
	# полки
	for sh in [[Vector2(98, 612), 140.0], [Vector2(626, 640), 140.0], [Vector2(604, 456), 110.0]]:
		_fill(_rrect(Rect2(sh[0] + Vector2(-sh[1] / 2.0, 0), Vector2(sh[1], 14)), 4), Color("#A06A4E"), OUT, 4.0)
		for sx in [-0.3, 0.3]:
			ci.draw_line(sh[0] + Vector2(sx * sh[1], 14), sh[0] + Vector2(sx * sh[1] + 10, 40), Color("#6E4434"), 6.0, true)
	if stage >= 2:
		# растение в горшке на полу справа у стены
		for i in 5:
			var a := -PI / 2.0 + (i - 2) * 0.4 + sin(t * 1.2 + i) * 0.04
			var b := Vector2(700, 800)
			ci.draw_line(b, b + Vector2(cos(a), sin(a)) * 60, Color("#3F9A5E"), 5.0, true)
			_oval(b + Vector2(cos(a), sin(a)) * 60, 14, 7, Color("#4FC27A"), a)
		_fill(PackedVector2Array([Vector2(680, 800), Vector2(720, 800), Vector2(714, 840), Vector2(686, 840)]), Color("#E07A5F"), OUT, 3.0)
	# пол и ковёр
	ci.draw_rect(Rect2(-240, 860, 1200, bot - 858), Color("#5A3A34"))
	for i in 14:
		var x := -240.0 + i * 90.0
		ci.draw_line(Vector2(x, 862), Vector2(360 + (x - 360) * 1.6, bot), Color(0.2, 0.1, 0.1, 0.35), 3.0, true)
	ci.draw_line(Vector2(-240, 862), Vector2(960, 862), OUT, 5.0, true)
	ci.draw_rect(Rect2(-240, 862, 1200, 10), Color("#7A5048"))
	_oval(Vector2(360, 900), 260, 40, Color("#B8506E"), 0.0, OUT, 4.0)
	_oval(Vector2(360, 900), 220, 30, Color("#D9708C"))
	_oval(Vector2(360, 900), 160, 20, Color("#F0A0B4"))
	_oval(Vector2(360, 900), 90, 11, Color("#FFD0DA"))
	# тёплый свет лампы-ночника
	_glow(Vector2(360, 760), 230, Color("#FFB86B"), 0.07 + stage * 0.02)
	if stage >= 3:
		# звёздный проектор: звёзды и созвездия плывут по стенам и потолку
		var cen := Vector2(360, 520)
		for i in 26:
			var a := _hash(i, 97) * TAU + t * 0.06
			var d := 160.0 + _hash(i, 98) * 300.0
			var p := cen + Vector2(cos(a), sin(a) * 0.8) * d
			var tw := 0.5 + 0.5 * sin(t * 2.0 + i)
			_sparkle(p, 5 + 4 * tw, Color(0.75, 0.9, 1.0, 0.5 + 0.3 * tw))
		for i in 3:
			var a := t * 0.06 + i * 2.1
			var c := cen + Vector2(cos(a), sin(a) * 0.8) * 250
			var pts := PackedVector2Array([c, c + Vector2(26, -14), c + Vector2(54, -6), c + Vector2(70, 18)])
			ci.draw_polyline(pts, Color(0.8, 0.9, 1.0, 0.35), 2.0, true)
			for q in pts:
				ci.draw_circle(q, 3.0, Color(0.9, 0.95, 1.0, 0.8), true, -1.0, true)
	# пылинки в лунном свете
	for i in 6 + stage * 4:
		var p := Vector2(220 + _hash(i, 99) * 280.0 + sin(t * 0.5 + i) * 20.0, 560 + fposmod(_hash(i, 100) * 300.0 - t * 10.0, 300.0))
		ci.draw_circle(p, 2.0, Color(1, 0.95, 0.8, 0.35 + 0.25 * sin(t * 2.0 + i)), true, -1.0, true)
	# корзинка-лежанка (задняя часть) с подушкой
	_oval(Vector2(360, 856), 124, 34, Color("#B07A44"), 0.0, OUT, 4.0)
	_oval(Vector2(360, 846), 108, 24, Color("#6A4A8A"))
	_oval(Vector2(350, 842), 90, 16, Color("#8F6CC0"))


func _basket_front() -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(0.0, PI, i / 16.0)
		pts.append(Vector2(360 + cos(a) * 124, 858 + sin(a) * 40))
	for i in 17:
		var a := lerpf(PI, 0.0, i / 16.0)
		pts.append(Vector2(360 + cos(a) * 124, 856 + sin(a) * 6))
	_fill(pts, Color("#C8904F"), OUT, 4.0)
	for i in 12:
		var x := 252.0 + i * 19.0
		var y := 870.0 + sin((x - 360.0) / 124.0 * PI * 0.5 + PI * 0.5) * 18.0
		ci.draw_line(Vector2(x, 862), Vector2(x + 8, y), Color("#8A5A30"), 2.5, true)
	ci.draw_polyline(PackedVector2Array([Vector2(240, 860), Vector2(360, 866), Vector2(480, 860)]), Color(1, 1, 1, 0.3), 3.0, true)


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
		"pup_ball": _pup_ball(p, k, t)
		"pup_bone": _pup_bone(p, k)
		"pup_bowl": _pup_bowl(p, k)
		"pup_sign": _pup_sign(p, k, t)
		"pup_flowerbed": _pup_flowerbed(p, k, t)
		"pup_pinwheel": _pup_pinwheel(p, k, t)
		"pup_lamp": _pup_lamp(p, k, t)
		"pup_bed": _pup_bed(p, k)
		"pup_kite": _pup_kite(p, k, t)
		"pup_teddy": _pup_teddy(p, k, t)
		"kit_yarn": _kit_yarn(p, k, t)
		"kit_mouse": _kit_mouse(p, k, t)
		"kit_pillow": _kit_pillow(p, k)
		"kit_picture": _kit_picture(p, k, t)
		"kit_catnip": _kit_catnip(p, k, t)
		"kit_box": _kit_box(p, k, t)
		"kit_scratcher": _kit_scratcher(p, k, t)
		"kit_lamp": _kit_lamp(p, k, t)
		"kit_aquarium": _kit_aquarium(p, k, t)
		"kit_tree": _kit_tree(p, k, t)


## Значок украшения для карточки гардероба (вписан в квадрат size вокруг c)
func draw_decor_icon(target: CanvasItem, id: String, c: Vector2, size: float, t: float) -> void:
	ci = target
	var h: float = DECOR_H.get(id, 60.0)
	var k := size / maxf(140.0, h * 1.25)
	if id == "pup_kite":
		k = size / 150.0
		draw_decor(id, c + Vector2(-50, 50) * k, k, t)
	elif SELF_HUNG.has(id):
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

# ---------- Украшения сада щенка ----------

func _shine(c: Vector2, rx: float, ry: float, rot := -0.5) -> void:
	_oval(c, rx, ry, Color(1, 1, 1, 0.55), rot)


func _pup_ball(p: Vector2, k: float, t: float) -> void:
	var hop := absf(sin(t * 2.2)) * 6.0
	_oval(p + Vector2(0, -2) * k, 22 * k * (1.0 - hop / 40.0), 5 * k, Color(0, 0, 0, 0.25))
	var c := p + Vector2(0, -22 - hop) * k
	var r := 22 * k
	_oval(c, r, r, Color("#FF5A6E"), 0.0, OUT, 3.0)
	var band := PackedVector2Array()
	for i in 13:
		var a := lerpf(-0.9, 0.9, i / 12.0)
		band.append(c + Vector2(sin(a) * r * 0.98, cos(a) * r * 0.35 - r * 0.05))
	ci.draw_polyline(band, Color("#FFF3E0"), 7 * k, true)
	_shine(c + Vector2(-8, -9) * k, 6 * k, 4 * k)
	var star := PackedVector2Array()
	for i in 10:
		star.append(c + Vector2(4, 8) * k + Vector2(0, -(6.0 if i % 2 == 0 else 2.6) * k).rotated(i * TAU / 10.0))
	ci.draw_colored_polygon(star, Color("#FFD34D"))


func _pup_bone(p: Vector2, k: float) -> void:
	_oval(p + Vector2(0, -2) * k, 46 * k, 6 * k, Color(0, 0, 0, 0.22))
	_bone(p + Vector2(0, -15) * k, 1.0 * k, Color("#FFF6E8"))


func _pup_bowl(p: Vector2, k: float) -> void:
	_oval(p + Vector2(0, -2) * k, 48 * k, 7 * k, Color(0, 0, 0, 0.25))
	_oval(p + Vector2(0, -30) * k, 38 * k, 9 * k, Color("#7A3A2A"))
	for i in 7:
		_oval(p + Vector2(-26 + i * 9, -32 - (i % 2) * 3) * k, 5 * k, 4 * k, Color("#C27A3A"), 0.0, Color("#7A4A20"), 1.5)
	var body := PackedVector2Array([p + Vector2(-42, -30) * k, p + Vector2(42, -30) * k, p + Vector2(34, -4) * k, p + Vector2(-34, -4) * k])
	_fill(body, Color("#3FA9F5"), OUT, 3.0)
	ci.draw_line(p + Vector2(-42, -30) * k, p + Vector2(42, -30) * k, Color("#8FD6FF"), 5 * k, true)
	_bone(p + Vector2(0, -17) * k, 0.4 * k, Color("#FFFFFF"))
	ci.draw_line(p + Vector2(-34, -22) * k, p + Vector2(-30, -10) * k, Color(1, 1, 1, 0.45), 3 * k, true)


func _pup_sign(p: Vector2, k: float, t: float) -> void:
	var sw := sin(t * 1.3) * 0.04
	var nail := p + Vector2(0, -68) * k
	var pts := _rrect(Rect2(Vector2(-44, 18) * k, Vector2(88, 46) * k), 10 * k)
	for i in pts.size():
		pts[i] = nail + pts[i].rotated(sw)
	ci.draw_line(nail, pts[0], Color("#C9B88A"), 2.5 * k, true)
	ci.draw_line(nail, pts[pts.size() / 4 * 3], Color("#C9B88A"), 2.5 * k, true)
	_fill(pts, Color("#D69A62"), OUT, 3.0)
	var c := nail + Vector2(0, 43 * k).rotated(sw)
	_bone(c + Vector2(-10, 0) * k, 0.5 * k, Color("#FFF6E8"))
	_paw(c + Vector2(26, 2) * k, 0.45 * k, Color("#7A4A30"))
	ci.draw_circle(nail, 4 * k, Color("#8A8AA0"), true, -1.0, true)


func _pup_flowerbed(p: Vector2, k: float, t: float) -> void:
	var cols := [Color("#FF6FA8"), Color("#FFD34D"), Color("#B48CFF"), Color("#FF8A5C"), Color("#FFFFFF")]
	for i in 7:
		var x := -48.0 + i * 16.0
		var h := 46.0 + _hash(i, 101) * 22.0
		var sw := sin(t * 1.5 + i) * 3.0
		var base := p + Vector2(x, -30) * k
		var top := p + Vector2(x + sw, -30 - h) * k
		ci.draw_line(base, top, Color("#3F8A55"), 3 * k, true)
		_oval(base.lerp(top, 0.5) + Vector2(6, 0) * k, 7 * k, 3.5 * k, Color("#5BC27E"), -0.5)
		for j in 5:
			_oval(top + Vector2(0, -7).rotated(j * TAU / 5.0 + t * 0.2) * k, 5.5 * k, 5.5 * k, cols[i % 5])
		_oval(top, 4 * k, 4 * k, Color("#FFB547"))
	_fill(_rrect(Rect2(p + Vector2(-60, -34) * k, Vector2(120, 34) * k), 5 * k), Color("#A8663E"), OUT, 3.0)
	for i in 3:
		ci.draw_line(p + Vector2(-58, -24 + i * 10) * k, p + Vector2(58, -24 + i * 10) * k, Color(0.35, 0.18, 0.1, 0.4), 2 * k, true)
	ci.draw_line(p + Vector2(-56, -31) * k, p + Vector2(56, -31) * k, Color(1, 1, 1, 0.3), 2.5 * k, true)


func _pup_pinwheel(p: Vector2, k: float, t: float) -> void:
	var hub := p + Vector2(0, -88) * k
	ci.draw_line(p, hub, OUT, 8 * k, true)
	ci.draw_line(p, hub, Color("#E8D6B0"), 5 * k, true)
	var cols := [Color("#FF5A6E"), Color("#FFD34D"), Color("#3FD0FF"), Color("#7AE08A")]
	var rot := t * 3.0
	for i in 4:
		var a := rot + i * TAU / 4.0
		var d := Vector2(cos(a), sin(a))
		var o := d.orthogonal()
		var blade := PackedVector2Array([hub, hub + d * 34 * k, hub + (d * 26 + o * 16) * k])
		_fill(blade, cols[i], OUT, 2.5)
		_fill(PackedVector2Array([hub, hub + (d * 26 + o * 16) * k, hub + (d * 8 + o * 14) * k]), cols[i].darkened(0.2))
	_oval(hub, 6 * k, 6 * k, Color("#FFFFFF"), 0.0, OUT, 2.0)


func _pup_lamp(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -38) * k
	var fl := 0.5 + 0.5 * sin(t * 4.0)
	_glow(c, 64 * k, Color("#FFD98A"), 0.22 + 0.06 * fl)
	ci.draw_arc(p + Vector2(0, -74) * k, 10 * k, PI, TAU, 10, Color("#2E3A5A"), 4 * k, true)
	_fill(PackedVector2Array([p + Vector2(-26, -62) * k, p + Vector2(0, -78) * k, p + Vector2(26, -62) * k]), Color("#2E3A5A"), OUT, 3.0)
	_oval(c, 22 * k, 24 * k, Color(1.0, 0.92, 0.6, 0.85), 0.0, Color("#2E3A5A"), 4 * k)
	ci.draw_line(c + Vector2(0, -24) * k, c + Vector2(0, 24) * k, Color("#2E3A5A"), 3 * k, true)
	ci.draw_line(c + Vector2(-22, 0) * k, c + Vector2(22, 0) * k, Color("#2E3A5A"), 3 * k, true)
	_oval(c, 7 * k, 10 * k, Color("#FFF8D8"))
	_fill(_rrect(Rect2(p + Vector2(-20, -14) * k, Vector2(40, 14) * k), 4 * k), Color("#2E3A5A"), OUT, 3.0)


func _pup_bed(p: Vector2, k: float) -> void:
	_oval(p + Vector2(0, -16) * k, 76 * k, 24 * k, Color("#3FA9A0"), 0.0, OUT, 3.0)
	_oval(p + Vector2(0, -22) * k, 58 * k, 14 * k, Color("#F4E6D4"))
	_oval(p + Vector2(-10, -24) * k, 40 * k, 7 * k, Color(1, 1, 1, 0.5))
	for i in 9:
		var a := lerpf(0.1, PI - 0.1, i / 8.0)
		ci.draw_circle(p + Vector2(cos(a) * 66, -12 + sin(a) * 14) * k, 3.5 * k, Color("#FFD34D"), true, -1.0, true)
	_paw(p + Vector2(30, -24) * k, 0.35 * k, Color("#D8BFA4"))


func _pup_kite(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(70 + sin(t * 0.9) * 8.0, -104 + cos(t * 1.2) * 6.0) * k
	var line := PackedVector2Array()
	for i in 9:
		var s := i / 8.0
		line.append(p.lerp(c, s) + Vector2(0, sin(s * PI) * 16 * k))
	ci.draw_polyline(line, Color(1, 1, 1, 0.6), 1.8, true)
	var rot := sin(t * 1.1) * 0.12
	var pts := PackedVector2Array([Vector2(0, -40), Vector2(30, -4), Vector2(0, 44), Vector2(-30, -4)])
	var q := PackedVector2Array()
	for v in pts:
		q.append(c + v.rotated(rot) * k)
	_fill(PackedVector2Array([q[0], q[1], c]), Color("#FF5A6E"))
	_fill(PackedVector2Array([q[1], q[2], c]), Color("#FFD34D"))
	_fill(PackedVector2Array([q[2], q[3], c]), Color("#3FD0FF"))
	_fill(PackedVector2Array([q[3], q[0], c]), Color("#7AE08A"))
	var cl := q.duplicate()
	cl.append(q[0])
	ci.draw_polyline(cl, OUT, 3.0, true)
	ci.draw_line(q[0], q[2], Color(0.2, 0.1, 0.2, 0.6), 2.0, true)
	ci.draw_line(q[1], q[3], Color(0.2, 0.1, 0.2, 0.6), 2.0, true)
	# хвост с бантиками
	var tail := PackedVector2Array()
	for i in 9:
		var s := i / 8.0
		tail.append(q[2] + Vector2(sin(t * 3.0 + s * 5.0) * 10.0 * s, s * 70) * k)
	ci.draw_polyline(tail, Color("#F4E6D4"), 2.0, true)
	var bc := [Color("#FF8FC8"), Color("#FFD34D"), Color("#7FE3FF")]
	for i in 3:
		var b := tail[2 + i * 3]
		ci.draw_colored_polygon(PackedVector2Array([b, b + Vector2(-9, -5) * k, b + Vector2(-9, 5) * k]), bc[i])
		ci.draw_colored_polygon(PackedVector2Array([b, b + Vector2(9, -5) * k, b + Vector2(9, 5) * k]), bc[i])


func _pup_teddy(p: Vector2, k: float, t: float) -> void:
	var br := Color("#B9805A")
	var lt := Color("#E8C29A")
	_oval(p + Vector2(0, -3) * k, 40 * k, 7 * k, Color(0, 0, 0, 0.22))
	_oval(p + Vector2(0, -26) * k, 28 * k, 24 * k, br, 0.0, OUT, 3.0)
	_oval(p + Vector2(0, -24) * k, 15 * k, 14 * k, lt)
	for sx in [-1.0, 1.0]:
		_oval(p + Vector2(sx * 22, -8) * k, 13 * k, 10 * k, br, 0.0, OUT, 3.0)
		_oval(p + Vector2(sx * 22, -8) * k, 7 * k, 6 * k, lt)
		_oval(p + Vector2(sx * 28, -34) * k, 9 * k, 14 * k, br, sx * -0.5, OUT, 3.0)
	var hc := p + Vector2(0, -62 + sin(t * 1.5) * 1.0) * k
	for sx in [-1.0, 1.0]:
		_oval(hc + Vector2(sx * 18, -16) * k, 9 * k, 9 * k, br, 0.0, OUT, 3.0)
		_oval(hc + Vector2(sx * 18, -16) * k, 4.5 * k, 4.5 * k, lt)
	_oval(hc, 24 * k, 21 * k, br, 0.0, OUT, 3.0)
	_oval(hc + Vector2(0, 7) * k, 10 * k, 8 * k, lt)
	_oval(hc + Vector2(0, 3) * k, 4 * k, 3 * k, OUT)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(hc + Vector2(sx * 9, -4) * k, 3 * k, OUT, true, -1.0, true)
		ci.draw_circle(hc + Vector2(sx * 9 - 1, -5) * k, 1 * k, Color.WHITE, true, -1.0, true)
	# бантик на шее
	for sx in [-1.0, 1.0]:
		_fill(PackedVector2Array([hc + Vector2(0, 20) * k, hc + Vector2(sx * 12, 14) * k, hc + Vector2(sx * 12, 26) * k]), Color("#FF4FA3"), OUT, 2.0)
	_shine(hc + Vector2(-10, -10) * k, 5 * k, 3 * k)


# ---------- Украшения чердака котика ----------

func _kit_yarn(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -22) * k
	_oval(p + Vector2(0, -2) * k, 30 * k, 6 * k, Color(0, 0, 0, 0.25))
	var thread := PackedVector2Array()
	for i in 10:
		var s := i / 9.0
		thread.append(c + Vector2(16 + s * 40, 18 + sin(s * 7.0 + t * 1.5) * 4.0) * k)
	ci.draw_polyline(thread, Color("#FF8FC8"), 3 * k, true)
	_oval(c, 22 * k, 22 * k, Color("#FF7FB4"), 0.0, OUT, 3.0)
	for i in 5:
		var a := -0.9 + i * 0.4
		ci.draw_arc(c + Vector2(cos(a), sin(a)) * 10 * k, 16 * k, a + 1.0, a + 2.6, 10, Color("#D94F8A"), 2.0 * k, true)
	_shine(c + Vector2(-8, -9) * k, 6 * k, 3.5 * k)
	ci.draw_line(c + Vector2(-26, -26) * k, c + Vector2(10, 8) * k, Color("#C9A46A"), 3 * k, true)
	ci.draw_line(c + Vector2(26, -26) * k, c + Vector2(-8, 6) * k, Color("#C9A46A"), 3 * k, true)
	ci.draw_circle(c + Vector2(-26, -26) * k, 3.5 * k, Color("#FFD34D"), true, -1.0, true)
	ci.draw_circle(c + Vector2(26, -26) * k, 3.5 * k, Color("#FFD34D"), true, -1.0, true)


func _kit_mouse(p: Vector2, k: float, t: float) -> void:
	var grey := Color("#B8B0C8")
	_oval(p + Vector2(0, -2) * k, 30 * k, 5 * k, Color(0, 0, 0, 0.22))
	var tail := PackedVector2Array()
	for i in 9:
		var s := i / 8.0
		tail.append(p + Vector2(22 + s * 28, -8 - sin(s * 5.0 + t * 2.0) * 6.0 * s) * k)
	ci.draw_polyline(tail, Color("#FF9FC0"), 2.5 * k, true)
	var body := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		body.append(p + Vector2(cos(a) * 26, -2 + sin(a) * 22) * k + Vector2(-pow(maxf(0.0, -cos(a)), 3.0) * 10 * k, 0))
	_fill(body, grey, OUT, 3.0)
	_oval(p + Vector2(-12, -22) * k, 8 * k, 9 * k, grey, 0.0, OUT, 2.5)
	_oval(p + Vector2(-12, -22) * k, 4.5 * k, 5 * k, Color("#FFA3BE"))
	ci.draw_circle(p + Vector2(-26, -8) * k, 3 * k, Color("#FF7FA4"), true, -1.0, true)
	ci.draw_circle(p + Vector2(-18, -12) * k, 2.4 * k, OUT, true, -1.0, true)
	_shine(p + Vector2(-2, -16) * k, 6 * k, 3 * k)


func _kit_pillow(p: Vector2, k: float) -> void:
	var pts := PackedVector2Array([Vector2(-50, -46), Vector2(0, -40), Vector2(50, -46), Vector2(44, -24), Vector2(50, -2), Vector2(0, -6), Vector2(-50, -2), Vector2(-44, -24)])
	var q := PackedVector2Array()
	for v in pts:
		q.append(p + v * k)
	_fill(_chaikin(q), Color("#7FC8F0"), OUT, 3.0)
	for i in 3:
		_fish(p + Vector2(-26 + i * 26, -24 + (i % 2) * 6) * k, 0.4 * k, Color("#FFB547"))
	for v in [Vector2(-50, -46), Vector2(50, -46), Vector2(50, -2), Vector2(-50, -2)]:
		ci.draw_circle(p + v * k, 5 * k, Color("#FFD34D"), true, -1.0, true)
	_shine(p + Vector2(-26, -36) * k, 10 * k, 4 * k)


func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	for _k in 2:
		var o := PackedVector2Array()
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			o.append(a.lerp(b, 0.25))
			o.append(a.lerp(b, 0.75))
		pts = o
	return pts


func _fish(c: Vector2, k: float, col: Color, flip := 1.0) -> void:
	_oval(c, 18 * k, 11 * k, col, 0.0, OUT, 2.0)
	_fill(PackedVector2Array([c + Vector2(-flip * 14, 0) * k, c + Vector2(-flip * 28, -11) * k, c + Vector2(-flip * 28, 11) * k]), col, OUT, 2.0)
	ci.draw_circle(c + Vector2(flip * 8, -3) * k, 2.5 * k, OUT, true, -1.0, true)


func _kit_picture(p: Vector2, k: float, t: float) -> void:
	var nail := p + Vector2(0, -84) * k
	var r := Rect2(p + Vector2(-46, -70) * k, Vector2(92, 70) * k)
	ci.draw_line(nail, r.position + Vector2(10, 0) * k, Color("#C9B88A"), 2 * k, true)
	ci.draw_line(nail, r.position + Vector2(82, 0) * k, Color("#C9B88A"), 2 * k, true)
	_fill(_rrect(r, 6 * k), Color("#E0A84E"), OUT, 3.0)
	var inner := r.grow(-9 * k)
	ci.draw_polygon(PackedVector2Array([inner.position, inner.position + Vector2(inner.size.x, 0), inner.end, inner.position + Vector2(0, inner.size.y)]),
		PackedColorArray([Color("#9FE0FF"), Color("#9FE0FF"), Color("#3F7FD0"), Color("#3F7FD0")]))
	_fish(inner.get_center() + Vector2(sin(t * 1.2) * 6, 2) * k, 0.8 * k, Color("#FF8A3D"))
	for i in 3:
		ci.draw_arc(inner.get_center() + Vector2(22, -14 - i * 8) * k, (2 + i) * k, 0, TAU, 10, Color(1, 1, 1, 0.7), 1.5, true)
	ci.draw_line(inner.position + Vector2(4, inner.size.y - 6), inner.end - Vector2(4, 6), Color("#3FAF6E"), 4 * k, true)
	ci.draw_circle(nail, 3.5 * k, Color("#8A8AA0"), true, -1.0, true)


func _kit_catnip(p: Vector2, k: float, t: float) -> void:
	for i in 7:
		var a := -PI / 2.0 + (i - 3) * 0.32 + sin(t * 1.3 + i) * 0.05
		var b := p + Vector2(0, -34) * k
		var e := b + Vector2(cos(a), sin(a)) * (40 + (i % 2) * 10) * k
		ci.draw_line(b, e, Color("#3F9A5E"), 3 * k, true)
		_oval(e, 11 * k, 6 * k, Color("#6FD08E"), a, Color("#3F9A5E"), 2.0)
		_oval(b.lerp(e, 0.55), 8 * k, 4 * k, Color("#5BC27E"), a + 0.6)
	var pot := PackedVector2Array([p + Vector2(-26, -36) * k, p + Vector2(26, -36) * k, p + Vector2(20, 0) * k, p + Vector2(-20, 0) * k])
	_fill(pot, Color("#E07A5F"), OUT, 3.0)
	_fill(_rrect(Rect2(p + Vector2(-30, -42) * k, Vector2(60, 10) * k), 3 * k), Color("#F09A7F"), OUT, 3.0)
	_paw(p + Vector2(0, -18) * k, 0.35 * k, Color("#FFE0D0"))


func _kit_box(p: Vector2, k: float, t: float) -> void:
	var cb := Color("#D9A066")
	_oval(p + Vector2(0, -2) * k, 56 * k, 7 * k, Color(0, 0, 0, 0.22))
	_fill(PackedVector2Array([p + Vector2(-46, -50) * k, p + Vector2(46, -50) * k, p + Vector2(46, 0) * k, p + Vector2(-46, 0) * k]), cb, OUT, 3.0)
	_fill(PackedVector2Array([p + Vector2(-46, -50) * k, p + Vector2(-64, -66) * k, p + Vector2(-56, -44) * k]), cb.darkened(0.12), OUT, 3.0)
	_fill(PackedVector2Array([p + Vector2(46, -50) * k, p + Vector2(66, -62) * k, p + Vector2(56, -42) * k]), cb.darkened(0.12), OUT, 3.0)
	ci.draw_rect(Rect2(p + Vector2(-8, -50) * k, Vector2(16, 50) * k), Color("#E8C890"))
	_fill(_heart(p + Vector2(0, -24) * k, 10 * k), Color("#FF7FA4"))
	ci.draw_line(p + Vector2(-42, -46) * k, p + Vector2(42, -46) * k, Color(0.2, 0.1, 0.05, 0.4), 3 * k, true)
	# из коробки иногда выглядывают ушки
	var peek := clampf(sin(t * 0.7) * 3.0 - 1.5, 0.0, 1.0)
	if peek > 0.0:
		for sx in [-1.0, 1.0]:
			_fill(PackedVector2Array([p + Vector2(sx * 12 - 8, -50) * k, p + Vector2(sx * 16, -50 - 18 * peek) * k, p + Vector2(sx * 12 + 8, -50) * k]), Color("#8A7A9A"), OUT, 2.0)


func _heart(c: Vector2, w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := w / 16.0
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a)) - 3.0) * s)
	return pts


func _kit_scratcher(p: Vector2, k: float, t: float) -> void:
	_fill(_rrect(Rect2(p + Vector2(-48, -14) * k, Vector2(96, 14) * k), 5 * k), Color("#8C63D0"), OUT, 3.0)
	_fill(PackedVector2Array([p + Vector2(-14, -14) * k, p + Vector2(14, -14) * k, p + Vector2(14, -110) * k, p + Vector2(-14, -110) * k]), Color("#D9B88A"), OUT, 3.0)
	for i in 12:
		var y := -20.0 - i * 7.5
		ci.draw_line(p + Vector2(-13, y) * k, p + Vector2(13, y - 3) * k, Color("#A8865A"), 2 * k, true)
	_fill(_rrect(Rect2(p + Vector2(-34, -124) * k, Vector2(68, 14) * k), 5 * k), Color("#8C63D0"), OUT, 3.0)
	var sw := sin(t * 2.0) * 0.3
	var h := p + Vector2(26, -112) * k
	var ball := h + Vector2(0, 40 * k).rotated(sw)
	ci.draw_line(h, ball, Color("#FFF0C0"), 2 * k, true)
	_oval(ball, 8 * k, 8 * k, Color("#FFD34D"), 0.0, OUT, 2.0)


func _kit_lamp(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -136) * k
	_glow(c + Vector2(0, 20) * k, 90 * k, Color("#FFC98A"), 0.2 + 0.03 * sin(t * 2.0))
	_fill(_rrect(Rect2(p + Vector2(-26, -10) * k, Vector2(52, 10) * k), 5 * k), Color("#3A2A55"), OUT, 3.0)
	ci.draw_line(p + Vector2(0, -10) * k, c, OUT, 7 * k, true)
	ci.draw_line(p + Vector2(0, -10) * k, c, Color("#C9A46A"), 4 * k, true)
	var shade := PackedVector2Array([c + Vector2(-20, -32) * k, c + Vector2(20, -32) * k, c + Vector2(40, 8) * k, c + Vector2(-40, 8) * k])
	ci.draw_polygon(PackedVector2Array([c + Vector2(-40, 8) * k, c + Vector2(40, 8) * k, c + Vector2(70, 120) * k, c + Vector2(-70, 120) * k]),
		PackedColorArray([Color(1, 0.85, 0.55, 0.22), Color(1, 0.85, 0.55, 0.22), Color(1, 0.85, 0.55, 0), Color(1, 0.85, 0.55, 0)]))
	_fill(shade, Color("#FFB0C8"), OUT, 3.0)
	ci.draw_line(c + Vector2(-38, 4) * k, c + Vector2(38, 4) * k, Color("#FF7FA4"), 4 * k, true)
	for i in 4:
		ci.draw_circle(c + Vector2(-28 + i * 19, 12) * k, 3 * k, Color("#FFD34D"), true, -1.0, true)
	ci.draw_line(c + Vector2(-14, -26) * k, c + Vector2(-26, 0) * k, Color(1, 1, 1, 0.5), 3 * k, true)


func _kit_aquarium(p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -38) * k
	_glow(c, 56 * k, Color("#7FE3FF"), 0.15)
	_oval(c, 38 * k, 34 * k, Color(0.6, 0.9, 1.0, 0.25), 0.0, Color("#BFF0FF"), 3.0)
	var water := PackedVector2Array()
	for i in 17:
		var a := lerpf(-0.3, PI + 0.3, i / 16.0)
		water.append(c + Vector2(cos(a) * 36, sin(a) * 32) * k)
	ci.draw_colored_polygon(water, Color(0.3, 0.7, 1.0, 0.45))
	ci.draw_line(c + Vector2(-12, 28) * k, c + Vector2(-10, 8) * k, Color("#3FAF6E"), 4 * k, true)
	ci.draw_line(c + Vector2(14, 28) * k, c + Vector2(18, 12) * k, Color("#3FAF6E"), 4 * k, true)
	var fx := sin(t * 0.9) * 14.0
	var flip := 1.0 if cos(t * 0.9) > 0.0 else -1.0
	_fish(c + Vector2(fx, 6 + sin(t * 2.0) * 3.0) * k, 0.55 * k, Color("#FF8A3D"), flip)
	for i in 3:
		var y := fposmod(t * 14.0 + i * 9.0, 26.0)
		ci.draw_arc(c + Vector2(fx * 0.5 + 6 + i * 3, -2 - y) * k, (1.5 + i * 0.6) * k, 0, TAU, 8, Color(1, 1, 1, 0.7), 1.2, true)
	ci.draw_arc(c, 34 * k, 3.6, 4.4, 10, Color(1, 1, 1, 0.6), 3 * k, true)
	_fill(_rrect(Rect2(c + Vector2(-24, -38) * k, Vector2(48, 8) * k), 3 * k), Color("#BFF0FF"), OUT, 2.0)
	_fill(_rrect(Rect2(p + Vector2(-30, -6) * k, Vector2(60, 6) * k), 3 * k), Color("#8C63D0"), OUT, 2.0)


func _kit_tree(p: Vector2, k: float, t: float) -> void:
	var post := Color("#D9B88A")
	var plush := Color("#9C7BDA")
	_fill(_rrect(Rect2(p + Vector2(-56, -16) * k, Vector2(112, 16) * k), 6 * k), plush, OUT, 3.0)
	for x in [-30.0, 26.0]:
		_fill(PackedVector2Array([p + Vector2(x - 9, -16) * k, p + Vector2(x + 9, -16) * k, p + Vector2(x + 9, -150) * k, p + Vector2(x - 9, -150) * k]), post, OUT, 3.0)
		for i in 14:
			ci.draw_line(p + Vector2(x - 8, -22 - i * 9) * k, p + Vector2(x + 8, -25 - i * 9) * k, Color("#A8865A"), 2 * k, true)
	# домик с круглым входом
	_fill(_rrect(Rect2(p + Vector2(-50, -96) * k, Vector2(64, 50) * k), 10 * k), plush, OUT, 3.0)
	_oval(p + Vector2(-18, -70) * k, 15 * k, 15 * k, Color("#3A2452"))
	# полки
	_fill(_rrect(Rect2(p + Vector2(-4, -120) * k, Vector2(62, 12) * k), 6 * k), plush, OUT, 3.0)
	_fill(_rrect(Rect2(p + Vector2(-58, -162) * k, Vector2(110, 14) * k), 7 * k), plush, OUT, 3.0)
	var sw := sin(t * 2.2) * 0.3
	var h := p + Vector2(48, -114) * k
	var ball := h + Vector2(0, 34 * k).rotated(sw)
	ci.draw_line(h, ball, Color("#FFF0C0"), 2 * k, true)
	_oval(ball, 7 * k, 7 * k, Color("#FF7FB4"), 0.0, OUT, 2.0)
	_shine(p + Vector2(-34, -158) * k, 14 * k, 3 * k, 0.0)
