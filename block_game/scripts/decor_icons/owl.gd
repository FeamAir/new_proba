extends RefCounted
## Значки новых украшений дома совёнка (Cascado 0.15): карточки панели «Украсить» и запасной 2D-дом.
## Рисует home.gd через draw(h, id, p, k, t): p — точка, где вещь стоит (низ по центру), k — масштаб,
## t — время (для мигания). Рисунок — вверх от p (y < 0). H — высота значка (для центровки в карточке).
## Помощники берутся из home.gd: h._fill, h._oval, h._rrect, h._glow, h._sparkle, h._gem, h.ci.

const OUT := Color("#1E1236")
const WOOD := Color("#9A6A44")
const WOOD_D := Color("#6B4433")
const BRASS := Color("#E8B44E")
const CREAM := Color("#FFF3E0")

const H := {
	"owl_candles": 70.0, "owl_tea": 70.0, "owl_clock": 110.0, "owl_armchair": 96.0, "owl_bookcase": 130.0,
	"owl_starmap": 100.0, "owl_globe": 96.0, "owl_comet": 80.0, "owl_planets": 90.0, "owl_telescope": 100.0,
	"owl_observatory": 120.0, "owl_mortar": 64.0, "owl_herbs": 80.0, "owl_wreath": 90.0, "owl_fireflies": 84.0,
	"owl_potions": 70.0, "owl_crystals": 90.0, "owl_staff": 124.0, "owl_spellbook": 100.0, "owl_cauldron": 96.0,
}


static func draw(h, id: String, p: Vector2, k: float, t: float) -> bool:
	match id:
		"owl_candles": _candles(h, p, k, t)
		"owl_tea": _tea(h, p, k, t)
		"owl_clock": _clock(h, p, k, t)
		"owl_armchair": _armchair(h, p, k)
		"owl_bookcase": _bookcase(h, p, k, t)
		"owl_starmap": _starmap(h, p, k, t)
		"owl_globe": _globe(h, p, k, t)
		"owl_comet": _comet(h, p, k, t)
		"owl_planets": _planets(h, p, k, t)
		"owl_telescope": _telescope(h, p, k)
		"owl_observatory": _observatory(h, p, k, t)
		"owl_mortar": _mortar(h, p, k, t)
		"owl_herbs": _herbs(h, p, k, t)
		"owl_wreath": _wreath(h, p, k)
		"owl_fireflies": _fireflies(h, p, k, t)
		"owl_potions": _potions(h, p, k, t)
		"owl_crystals": _crystals(h, p, k, t)
		"owl_staff": _staff(h, p, k, t)
		"owl_spellbook": _spellbook(h, p, k, t)
		"owl_cauldron": _cauldron(h, p, k, t)
		_: return false
	return true


static func _r(h, p: Vector2, k: float, x: float, y: float, w: float, hh: float, col: Color, rad := 4.0) -> void:
	h._fill(h._rrect(Rect2(p + Vector2(x, y) * k, Vector2(w, hh) * k), rad * k), col, OUT, 3.0 * k)


static func _flame(h, c: Vector2, k: float, t: float, ph: float) -> void:
	var f := 1.0 + 0.12 * sin(t * 9.0 + ph)
	h._glow(c, 18 * k, Color("#FFD46B"), 0.25)
	h._oval(c, 5 * k, 9 * k * f, Color("#FFD46B"), 0.0, Color("#FF9E3A"), 2.0 * k)


static func _candles(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -6) * k, 44 * k, 9 * k, WOOD, 0.0, OUT, 3.0 * k)
	var cs := [[-22.0, 48.0, Color("#FFF1D6")], [20.0, 34.0, Color("#FFE0E6")], [0.0, 22.0, Color("#FFF1D6")]]
	var i := 0
	for c in cs:
		var x: float = c[0]
		var hh: float = c[1]
		_r(h, p, k, x - 9, -10 - hh, 18, hh, c[2], 5)
		_flame(h, p + Vector2(x, -18 - hh) * k, k, t, i * 2.0)
		i += 1


static func _tea(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -10, -30, 20, 30, WOOD_D, 3)
	h._oval(p + Vector2(0, -32) * k, 52 * k, 11 * k, Color("#E8C48E"), 0.0, OUT, 3.0 * k)
	h._oval(p + Vector2(-10, -50) * k, 20 * k, 16 * k, Color("#6FB6E6"), 0.0, OUT, 3.0 * k)
	h.ci.draw_line(p + Vector2(8, -52) * k, p + Vector2(22, -62) * k, OUT, 6 * k, true)
	h.ci.draw_line(p + Vector2(8, -52) * k, p + Vector2(22, -62) * k, Color("#6FB6E6"), 3.5 * k, true)
	h._oval(p + Vector2(-10, -67) * k, 6 * k, 4 * k, Color("#FFD34D"), 0.0, OUT, 2.0 * k)
	_r(h, p, k, 24, -50, 16, 13, Color("#FF9EB5"), 3)
	for i in 3:
		var u := fposmod(t * 0.4 + i / 3.0, 1.0)
		h.ci.draw_circle(p + Vector2(24 + 4 * sin(u * 6.0), -66 - u * 26) * k, (5 - 3 * u) * k, Color(1, 1, 1, 0.6 * (1.0 - u)), true, -1.0, true)


static func _clock(h, p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -70) * k
	var ang := sin(t * 2.4) * 0.3
	var bob := c + Vector2(0, 58).rotated(-ang) * k
	h.ci.draw_line(c, bob, BRASS.darkened(0.2), 3 * k, true)
	h._oval(bob, 9 * k, 9 * k, BRASS, 0.0, OUT, 2.5 * k)
	for sx in [-1.0, 1.0]:
		h._fill(PackedVector2Array([c + Vector2(sx * 14, -26) * k, c + Vector2(sx * 30, -44) * k, c + Vector2(sx * 30, -18) * k]), WOOD, OUT, 3.0 * k)
	h._oval(c, 34 * k, 34 * k, WOOD, 0.0, OUT, 3.0 * k)
	h._oval(c, 26 * k, 26 * k, CREAM, 0.0, BRASS, 3.0 * k)
	for i in 12:
		var a := TAU * i / 12.0
		h.ci.draw_circle(c + Vector2(sin(a), -cos(a)) * 20 * k, (2.4 if i % 3 == 0 else 1.3) * k, OUT, true, -1.0, true)
	h.ci.draw_line(c, c + Vector2(0, -17).rotated(t * 0.4) * k, OUT, 2.5 * k, true)
	h.ci.draw_line(c, c + Vector2(0, -11).rotated(t * 0.04 + 2.0) * k, Color("#E0556F"), 3 * k, true)


static func _armchair(h, p: Vector2, k: float) -> void:
	_r(h, p, k, -38, -90, 76, 70, Color("#7A5141"), 18)
	_r(h, p, k, -42, -46, 84, 46, Color("#7A5141"), 8)
	h._oval(p + Vector2(0, -64) * k, 28 * k, 20 * k, Color("#7FD088"), 0.0, OUT, 3.0 * k)
	h._oval(p + Vector2(0, -44) * k, 38 * k, 11 * k, Color("#5DBB63"), 0.0, OUT, 3.0 * k)
	_r(h, p, k, 26, -58, 16, 40, Color("#E0556F"), 3)
	for i in 3:
		h.ci.draw_line(p + Vector2(27, -52 + i * 12) * k, p + Vector2(41, -52 + i * 12) * k, CREAM, 2 * k, true)
	for i in 4:
		h.ci.draw_line(p + Vector2(-30 + i * 20, -40) * k, p + Vector2(-30 + i * 20, -4) * k, WOOD_D, 2 * k, true)


static func _bookcase(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -42, -120, 84, 120, Color("#8A5A3A"), 6)
	h._oval(p + Vector2(0, -118) * k, 42 * k, 20 * k, Color("#8A5A3A"), 0.0, OUT, 3.0 * k)
	_r(h, p, k, -34, -112, 68, 106, Color("#5A3A2A"), 3)
	h._oval(p + Vector2(0, -124) * k, 10 * k, 8 * k, Color("#3A2440"), 0.0, BRASS, 2.0 * k)
	for sx in [-1.0, 1.0]:
		h.ci.draw_circle(p + Vector2(sx * 4, -124) * k, 2.5 * k, Color("#FFD34D"), true, -1.0, true)
	var pal := [Color("#E0556F"), Color("#5FC8FF"), Color("#FFD34D"), Color("#3DDC97"), Color("#B46CFF"), Color("#FF9E5C")]
	for row in 4:
		var y := -14.0 - row * 26.0
		h.ci.draw_line(p + Vector2(-34, y) * k, p + Vector2(34, y) * k, Color("#C99A6A"), 3 * k, true)
		var x := -32.0
		var i := 0
		while x < 28.0:
			var w := 6.0 + 3.0 * fposmod(i * 1.7 + row, 2.0)
			var hh := 15.0 + 5.0 * fposmod(i * 2.3 + row * 1.1, 1.0)
			var dx := 3.0 * clampf(sin(t * 0.7) * 2.5 - 1.2, 0.0, 1.0) if row == 1 and i == 2 else 0.0
			h.ci.draw_rect(Rect2(p + Vector2(x, y - hh - dx) * k, Vector2(w, hh) * k), pal[(i + row * 2) % pal.size()])
			x += w + 1.0
			i += 1
	h._glow(p + Vector2(24, -100) * k, 14 * k, Color("#FFB866"), 0.3)


static func _starmap(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -36, -92, 72, 80, Color("#1C2050"), 3)
	for y in [-92.0, -12.0]:
		_r(h, p, k, -42, y - 4, 84, 8, Color("#2C3470"), 4)
	var pts := [Vector2(-22, -70), Vector2(-8, -78), Vector2(6, -66), Vector2(20, -74), Vector2(12, -44), Vector2(-14, -36), Vector2(4, -26)]
	for i in pts.size() - 1:
		h.ci.draw_line(p + pts[i] * k, p + pts[i + 1] * k, Color(1, 0.8, 0.4, 0.7), 1.5 * k, true)
	var seq := int(t * 1.6) % pts.size()
	for i in pts.size():
		h._sparkle(p + pts[i] * k, (7.0 if i == seq else 4.0) * k, Color("#FFF2B0"))


static func _globe(h, p: Vector2, k: float, t: float) -> void:
	for sx in [-1.0, 0.0, 1.0]:
		h.ci.draw_line(p + Vector2(0, -40) * k, p + Vector2(sx * 22, 0) * k, WOOD_D, 4 * k, true)
	var c := p + Vector2(0, -66) * k
	h._glow(c, 36 * k, Color("#6F8CFF"), 0.2)
	h._oval(c, 26 * k, 26 * k, Color("#2F3FA8"), 0.0, OUT, 3.0 * k)
	for i in 9:
		var a := TAU * i / 9.0 + t * 0.5
		var x := cos(a) * 20.0
		if sin(a) > -0.2:
			h.ci.draw_circle(c + Vector2(x, -14 + i * 3.2) * k, 1.8 * k, Color("#FFF2B0"), true, -1.0, true)
	h.ci.draw_arc(c, 31 * k, -2.2, 1.2, 20, BRASS, 3.5 * k, true)


static func _comet(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -26, -66, 52, 60, Color(0.85, 0.95, 1.0, 0.35), 10)
	_r(h, p, k, -22, -76, 44, 12, Color("#C98A5C"), 4)
	_r(h, p, k, -28, -8, 56, 8, WOOD, 3)
	var c := p + Vector2(0, -36) * k
	for i in 6:
		var a := t * 2.6 - i * 0.35
		h.ci.draw_circle(c + Vector2(cos(a) * 14, sin(a) * 7) * k, (6.0 - i * 0.9) * k, Color(0.7, 0.95, 1.0, 1.0 - i * 0.14), true, -1.0, true)
	h._glow(c, 24 * k, Color("#9FE8FF"), 0.25)


static func _planets(h, p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -40) * k
	h.ci.draw_line(p + Vector2(0, -90) * k, c, BRASS, 2 * k, true)
	h.ci.draw_arc(c, 40 * k, 0, TAU, 40, Color(BRASS, 0.6), 1.5 * k, true)
	h._glow(c, 22 * k, Color("#FFD34D"), 0.35)
	h._oval(c, 11 * k, 11 * k, Color("#FFD34D"), 0.0, OUT, 2.5 * k)
	var defs := [[24.0, 6.0, Color("#7FE3FF"), 1.1], [40.0, 8.0, Color("#FF8FA0"), 0.7], [40.0, 9.0, Color("#B46CFF"), -0.45]]
	for d in defs:
		var a: float = t * d[3] + d[1]
		var q: Vector2 = c + Vector2(cos(a) * d[0], sin(a) * d[0] * 0.35) * k
		h._oval(q, d[1] * k, d[1] * k, d[2], 0.0, OUT, 2.0 * k)


static func _telescope(h, p: Vector2, k: float) -> void:
	for sx in [-1.0, 0.0, 1.0]:
		h.ci.draw_line(p + Vector2(0, -50) * k, p + Vector2(sx * 26, 0) * k, OUT, 6 * k, true)
		h.ci.draw_line(p + Vector2(0, -50) * k, p + Vector2(sx * 26, 0) * k, WOOD, 3.5 * k, true)
	var a := Vector2(-28, -38)
	var b := Vector2(30, -96)
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	h._fill(PackedVector2Array([p + (a + nrm * 7) * k, p + (b + nrm * 11) * k, p + (b - nrm * 11) * k, p + (a - nrm * 7) * k]), BRASS, OUT, 3.0 * k)
	h._oval(p + b * k, 6 * k, 11 * k, Color("#9FE8FF"), -d.angle(), OUT, 2.0 * k)
	h._sparkle(p + Vector2(38, -110) * k, 7 * k, Color("#FFF2B0"))


static func _observatory(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -38, -64, 76, 60, Color("#E9E6FF"), 6)
	_r(h, p, k, -44, -10, 88, 10, Color("#8A7FA8"), 3)
	_r(h, p, k, -9, -36, 18, 30, Color("#5A3A6A"), 8)
	var dc := p + Vector2(0, -64) * k
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(dc + Vector2(cos(a) * 40, sin(a) * 38) * k)
	h._fill(pts, Color("#F7F8FF"), OUT, 3.0 * k)
	var open_ := clampf(sin(t * 0.45) * 2.0 + 0.6, 0.0, 1.0)
	h.ci.draw_rect(Rect2(dc + Vector2(-5 - 4 * open_, -38) * k, Vector2(10 + 8 * open_, 36) * k), Color("#262A5A"))
	if open_ > 0.3:
		h._fill(PackedVector2Array([dc + Vector2(-6, -40) * k, dc + Vector2(6, -40) * k, dc + Vector2(22, -100) * k, dc + Vector2(-22, -100) * k]), Color(0.5, 0.85, 1.0, 0.3 * open_))
	h._sparkle(dc + Vector2(0, -46) * k, 7 * k, Color("#FFD34D"))
	h.ci.draw_circle(p + Vector2(22, -44) * k, 4 * k, Color("#FFD27A"), true, -1.0, true)


static func _mortar(h, p: Vector2, k: float, t: float) -> void:
	var ang := sin(t * 1.3) * 0.25
	h.ci.draw_line(p + Vector2(0, -24) * k, p + Vector2(0, -24) * k + Vector2(20, -38).rotated(ang) * k, OUT, 10 * k, true)
	h.ci.draw_line(p + Vector2(0, -24) * k, p + Vector2(0, -24) * k + Vector2(20, -38).rotated(ang) * k, Color("#C7CDD0"), 7 * k, true)
	var bowl := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		bowl.append(p + Vector2(-cos(a) * 32, -26 + sin(a) * 24) * k)
	h._fill(bowl, Color("#A3ACB0"), OUT, 3.0 * k)
	h._oval(p + Vector2(0, -26) * k, 30 * k, 7 * k, Color("#7FD86A"), 0.0, OUT, 2.0 * k)
	h._oval(p + Vector2(-12, -32) * k, 8 * k, 4 * k, Color("#3FAF6E"), 0.4)


static func _herbs(h, p: Vector2, k: float, t: float) -> void:
	var top := p + Vector2(0, -74) * k
	h.ci.draw_line(top + Vector2(-46, 0) * k, top + Vector2(46, 0) * k, WOOD, 5 * k, true)
	var cols := [[Color("#5E9A4A"), Color("#B48CFF")], [Color("#7FB85A"), Color("#FFD34D")], [Color("#4E8A3A"), Color("#FF9EB5")]]
	for i in 3:
		var x := -30.0 + i * 30.0
		var sw := sin(t * 1.2 + i) * 2.0
		var b := top + Vector2(x + sw, 0) * k
		h.ci.draw_line(b, b + Vector2(0, 14) * k, Color("#C9B88A"), 2 * k, true)
		h._fill(PackedVector2Array([b + Vector2(-4, 14) * k, b + Vector2(4, 14) * k, b + Vector2(14, 56) * k, b + Vector2(-14, 56) * k]), cols[i][0], OUT, 2.5 * k)
		h.ci.draw_circle(b + Vector2(-5, 46) * k, 3.5 * k, cols[i][1], true, -1.0, true)
		h.ci.draw_circle(b + Vector2(6, 38) * k, 3 * k, cols[i][1], true, -1.0, true)


static func _wreath(h, p: Vector2, k: float) -> void:
	var c := p + Vector2(0, -46) * k
	h.ci.draw_arc(c, 30 * k, 0, TAU, 40, OUT, 20 * k, true)
	h.ci.draw_arc(c, 30 * k, 0, TAU, 40, Color("#4E9A4A"), 15 * k, true)
	for i in 14:
		var a := TAU * i / 14.0
		h._oval(c + Vector2(cos(a), sin(a)) * 31 * k, 7 * k, 4 * k, [Color("#6FBF5A"), Color("#8FCB6A"), Color("#D9A13A")][i % 3], a + 0.8)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		h.ci.draw_circle(c + Vector2(cos(a), sin(a)) * 26 * k, 3.5 * k, Color("#E83A50"), true, -1.0, true)
	for sx in [-1.0, 1.0]:
		h._fill(PackedVector2Array([c + Vector2(0, 30) * k, c + Vector2(sx * 14, 22) * k, c + Vector2(sx * 14, 38) * k]), Color("#FFB86B"), OUT, 2.0 * k)


static func _fireflies(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -24, -62, 48, 58, Color(0.85, 1.0, 0.85, 0.3), 10)
	h._oval(p + Vector2(0, -64) * k, 28 * k, 9 * k, Color("#E0556F"), 0.0, OUT, 3.0 * k)
	h.ci.draw_arc(p + Vector2(0, -72) * k, 12 * k, PI, TAU, 12, Color("#9A9A9A"), 3 * k, true)
	var c := p + Vector2(0, -34) * k
	h._glow(c, 28 * k, Color("#E8FF7A"), 0.25)
	for i in 6:
		var a := t * (1.3 if i % 2 else -0.9) + i * 1.05
		h.ci.draw_circle(c + Vector2(cos(a) * 12, sin(a * 1.3) * 14) * k, 3 * k, Color("#F4FF9A"), true, -1.0, true)


static func _potions(h, p: Vector2, k: float, t: float) -> void:
	var defs := [[-28.0, 22.0, 30.0, Color("#B46CFF")], [-6.0, 14.0, 52.0, Color("#3DDC97")], [14.0, 20.0, 32.0, Color("#FF8FD8")], [32.0, 10.0, 24.0, Color("#FFB547")]]
	var i := 0
	for d in defs:
		var x: float = d[0]
		var w: float = d[1]
		var hh: float = d[2]
		var col: Color = d[3]
		var glow := 0.75 + 0.25 * sin(t * (1.6 + i * 0.4) + i)
		h._glow(p + Vector2(x, -hh * 0.4) * k, w * 0.9 * k, col, 0.18 * glow)
		_r(h, p, k, x - w * 0.5, -hh, w, hh, Color(col, 0.9), w * 0.4)
		_r(h, p, k, x - 3, -hh - 8, 6, 9, Color("#C98A5C"), 2)
		i += 1


static func _crystals(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -6) * k, 40 * k, 10 * k, Color("#6E6A80"), 0.0, OUT, 3.0 * k)
	var defs := [[0.0, 70.0, 12.0, 0.0, Color("#B46CFF")], [-20.0, 46.0, 9.0, -0.4, Color("#D08CFF")], [20.0, 52.0, 10.0, 0.4, Color("#8A5CFF")], [6.0, 32.0, 8.0, 0.2, Color("#9FE8FF")]]
	var i := 0
	for d in defs:
		var b := p + Vector2(d[0], -8) * k
		var up := Vector2(0, -d[1]).rotated(d[3]) * k
		var side := Vector2(d[2], 0).rotated(d[3]) * k
		var col: Color = (d[4] as Color).lightened(0.12 * sin(t * 1.5 + i))
		h._fill(PackedVector2Array([b - side, b - side + up * 0.75, b + up, b + side + up * 0.75, b + side]), col, OUT, 2.5 * k)
		h._fill(PackedVector2Array([b, b + up * 0.75, b + up, b + side + up * 0.75, b + side]), Color(1, 1, 1, 0.25))
		i += 1
	h._sparkle(p + Vector2(10, -70) * k, (5 + 2 * sin(t * 3.0)) * k, Color.WHITE)


static func _staff(h, p: Vector2, k: float, t: float) -> void:
	h.ci.draw_line(p + Vector2(-6, 0) * k, p + Vector2(4, -100) * k, OUT, 10 * k, true)
	h.ci.draw_line(p + Vector2(-6, 0) * k, p + Vector2(4, -100) * k, Color("#8A5A3A"), 7 * k, true)
	var c := p + Vector2(5, -112) * k
	h._glow(c, 24 * k, Color("#5FF0C8"), 0.3)
	var s := absf(cos(t * 1.4))
	h._fill(PackedVector2Array([c + Vector2(0, -16) * k, c + Vector2(8 * s + 2, 0) * k, c + Vector2(0, 14) * k, c + Vector2(-8 * s - 2, 0) * k]), Color("#5FF0C8"), OUT, 2.0 * k)
	for sx in [-1.0, 1.0]:
		h.ci.draw_arc(c + Vector2(sx * 6, 6) * k, 9 * k, PI * 0.5, PI * 1.2 if sx < 0 else -PI * 0.2, 8, Color("#8A5A3A"), 3 * k, true)
	h._oval(p + Vector2(2, -86) * k, 6 * k, 4 * k, Color("#E0556F"))


static func _spellbook(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -5, -60, 10, 56, WOOD, 3)
	_r(h, p, k, -24, -6, 48, 6, WOOD_D, 3)
	h._fill(PackedVector2Array([p + Vector2(-40, -62) * k, p + Vector2(40, -62) * k, p + Vector2(34, -84) * k, p + Vector2(-34, -84) * k]), Color("#5A2E7A"), OUT, 3.0 * k)
	h._fill(PackedVector2Array([p + Vector2(-36, -66) * k, p + Vector2(-2, -64) * k, p + Vector2(-2, -86) * k, p + Vector2(-32, -88) * k]), CREAM, OUT, 2.0 * k)
	h._fill(PackedVector2Array([p + Vector2(2, -64) * k, p + Vector2(36, -66) * k, p + Vector2(32, -88) * k, p + Vector2(2, -86) * k]), CREAM, OUT, 2.0 * k)
	for i in 3:
		h.ci.draw_line(p + Vector2(-28, -72 - i * 5) * k, p + Vector2(-8, -71 - i * 5) * k, Color("#7FD86A"), 2 * k, true)
	h.ci.draw_arc(p + Vector2(18, -76) * k, 6 * k, 0, TAU, 12, Color("#7FD86A"), 2 * k, true)
	for i in 3:
		var u := fposmod(t * 0.4 + i / 3.0, 1.0)
		h._sparkle(p + Vector2(-16 + i * 16, -92 - u * 24) * k, 4 * k * (1.0 - u), Color("#C8FF8A"))


static func _cauldron(h, p: Vector2, k: float, t: float) -> void:
	h._glow(p + Vector2(0, -8) * k, 26 * k, Color("#FF9E3A"), 0.3)
	for sx in [-1.0, 1.0]:
		h.ci.draw_line(p + Vector2(sx * 22, -10) * k, p + Vector2(sx * 28, 0) * k, OUT, 6 * k, true)
	var body := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		body.append(p + Vector2(-cos(a) * 46, -50 + sin(a) * 42) * k)
	h._fill(body, Color("#3B3654"), OUT, 3.0 * k)
	h._oval(p + Vector2(0, -50) * k, 44 * k, 10 * k, Color("#4A4566"), 0.0, OUT, 3.0 * k)
	h._oval(p + Vector2(0, -51) * k, 38 * k, 7 * k, Color("#7FE86A"))
	h._glow(p + Vector2(0, -56) * k, 40 * k, Color("#9CFF6A"), 0.18)
	for i in 3:
		var u := fposmod(t * 0.5 + i / 3.0, 1.0)
		var hue := fposmod(0.33 + 0.2 * sin(t * 0.35), 1.0)
		h.ci.draw_circle(p + Vector2(-14 + i * 14 + 4 * sin(u * 6.0), -62 - u * 36) * k, (8 - 4 * u) * k, Color.from_hsv(hue, 0.4, 1.0, 0.65 * (1.0 - u)), true, -1.0, true)
	h.ci.draw_arc(p + Vector2(0, -30) * k, 7 * k, 0, TAU, 12, Color("#7FD86A"), 2 * k, true)
