extends RefCounted
## Значки новых украшений дома аксолотля (Cascado 0.15): карточки панели «Украсить» и запасной 2D-дом.
## Рисует home.gd через draw(h, id, p, k, t): p — точка, где вещь стоит (низ по центру), k — масштаб,
## t — время. Рисунок — вверх от p (y < 0). H — высота значка (для центровки в карточке).

const OUT := Color("#1E1236")
const WOOD := Color("#9A5A34")
const WOOD_D := Color("#6A3A22")
const GOLD := Color("#FFCB45")
const BRASS := Color("#E0A83A")
const CREAM := Color("#FFF3E0")

const H := {
	"axo_kelp": 100.0, "axo_seahorse": 90.0, "axo_arch": 130.0, "axo_bottle": 50.0, "axo_map": 80.0,
	"axo_spyglass": 60.0, "axo_lantern": 96.0, "axo_barrel": 84.0, "axo_flag": 110.0, "axo_wheel": 100.0,
	"axo_ship": 130.0, "axo_plankton": 70.0, "axo_anemones": 70.0, "axo_vent": 90.0, "axo_neonsquid": 96.0,
	"axo_crystal": 96.0, "axo_angler": 96.0, "axo_pod": 96.0, "axo_jelly": 100.0, "axo_sub": 110.0,
}


static func draw(h, id: String, p: Vector2, k: float, t: float) -> bool:
	match id:
		"axo_kelp": _kelp(h, p, k, t)
		"axo_seahorse": _seahorse(h, p, k, t)
		"axo_arch": _arch(h, p, k, t)
		"axo_bottle": _bottle(h, p, k, t)
		"axo_map": _map(h, p, k, t)
		"axo_spyglass": _spyglass(h, p, k, t)
		"axo_lantern": _lantern(h, p, k, t)
		"axo_barrel": _barrel(h, p, k, t)
		"axo_flag": _flag(h, p, k, t)
		"axo_wheel": _wheel(h, p, k, t)
		"axo_ship": _ship(h, p, k, t)
		"axo_plankton": _plankton(h, p, k, t)
		"axo_anemones": _anemones(h, p, k, t)
		"axo_vent": _vent(h, p, k, t)
		"axo_neonsquid": _neonsquid(h, p, k, t)
		"axo_crystal": _crystal(h, p, k, t)
		"axo_angler": _angler(h, p, k, t)
		"axo_pod": _pod(h, p, k, t)
		"axo_jelly": _jelly(h, p, k, t)
		"axo_sub": _sub(h, p, k, t)
		_: return false
	return true


static func _r(h, p: Vector2, k: float, x: float, y: float, w: float, hh: float, col: Color, rad := 4.0) -> void:
	h._fill(h._rrect(Rect2(p + Vector2(x, y) * k, Vector2(w, hh) * k), rad * k), col, OUT, 3.0 * k)


static func _line(h, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	h.ci.draw_line(a, b, OUT, w + 3.0, true)
	h.ci.draw_line(a, b, col, w, true)


static func _wavy(h, a: Vector2, len: float, k: float, t: float, col: Color, w: float, ph: float, down := true) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var s := i / 8.0
		pts.append(a + Vector2(sin(s * 5.0 + t * 1.5 + ph) * 6.0 * s, (s if down else -s) * len) * k)
	h.ci.draw_polyline(pts, OUT, (w + 3.0) * k, true)
	h.ci.draw_polyline(pts, col, w * k, true)


static func _kelp(h, p: Vector2, k: float, t: float) -> void:
	var top := p + Vector2(0, -92) * k
	_line(h, top + Vector2(-44, 0) * k, top + Vector2(44, 0) * k, Color("#B08A5A"), 5 * k)
	var cols := [Color("#2FAE7A"), Color("#4FC48A"), Color("#8FB84A"), Color("#3DBE9A"), Color("#C8A04A")]
	for i in 5:
		_wavy(h, top + Vector2(-34 + i * 17, 3) * k, 70 + 14 * (i % 2), k, t, cols[i], 6.0, i * 1.3)


static func _horse(h, c: Vector2, k: float, col: Color, flip: float) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var s := i / 11.0
		pts.append(c + Vector2(flip * (6 * sin(s * 3.0) - 4 * s), -30 + s * 44) * k)
	h.ci.draw_polyline(pts, OUT, 13 * k, true)
	h.ci.draw_polyline(pts, col, 10 * k, true)
	h.ci.draw_arc(c + Vector2(flip * -8, 16) * k, 6 * k, 0, PI * 1.5, 10, col, 5 * k, true)
	h._oval(c + Vector2(0, -32) * k, 9 * k, 8 * k, col, 0.0, OUT, 2.5 * k)
	_line(h, c + Vector2(flip * 6, -32) * k, c + Vector2(flip * 18, -30) * k, col, 4 * k)
	h.ci.draw_circle(c + Vector2(flip * 2, -34) * k, 2.2 * k, OUT, true, -1.0, true)


static func _seahorse(h, p: Vector2, k: float, t: float) -> void:
	var b := sin(t * 1.7) * 3.0
	_horse(h, p + Vector2(-20, -44 + b) * k, k, Color("#FF9E5C"), 1.0)
	_horse(h, p + Vector2(20, -44 - b) * k, k, Color("#C890FF"), -1.0)
	h.ci.draw_circle(p + Vector2(0, -82) * k, 4 * k, Color(1, 1, 1, 0.6), false, 1.5 * k, true)


static func _arch(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -5) * k, 56 * k, 8 * k, Color("#E8D0A8"), 0.0, OUT, 3.0 * k)
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 11:
			var a := lerpf(PI if side < 0 else 0.0, PI * 0.5, i / 10.0)
			pts.append(p + Vector2(cos(a) * 40, -6 - sin(a) * 100) * k)
		h.ci.draw_polyline(pts, OUT, 17 * k, true)
		h.ci.draw_polyline(pts, Color("#FF6F9E") if side < 0 else Color("#FF9E6C"), 13 * k, true)
		for i in range(1, 10, 2):
			var q: Vector2 = pts[i]
			var tw := 0.6 + 0.4 * sin(t * 2.0 + i)
			h.ci.draw_circle(q + Vector2(0, 0), 3.5 * k, Color(1, 0.97, 1, tw), true, -1.0, true)
	var top := p + Vector2(0, -110) * k
	h._oval(top, 20 * k, 9 * k, Color("#FFC2D6"), 0.0, OUT, 2.5 * k)
	h._glow(top + Vector2(0, -6) * k, 16 * k, Color.WHITE, 0.3)
	h._oval(top + Vector2(0, -6) * k, 8 * k, 8 * k, Color("#F6F2FF"), 0.0, OUT, 2.0 * k)
	for i in 4:
		var u := fposmod(t * 0.35 + i / 4.0, 1.0)
		h.ci.draw_circle(p + Vector2(4 * sin(u * 8.0 + i), -12 - u * 80) * k, (3 + i % 2) * k, Color(0.85, 1, 1, 0.7 * (1.0 - u)), false, 1.5 * k, true)


static func _bottle(h, p: Vector2, k: float, t: float) -> void:
	var a := sin(t * 0.9) * 0.15
	var c := p + Vector2(0, -16) * k
	var d := Vector2(1, -0.25).normalized().rotated(a)
	var n := Vector2(-d.y, d.x)
	h._fill(PackedVector2Array([c - d * 30 * k + n * 12 * k, c + d * 10 * k + n * 12 * k, c + d * 22 * k + n * 5 * k, c + d * 34 * k + n * 5 * k,
		c + d * 34 * k - n * 5 * k, c + d * 22 * k - n * 5 * k, c + d * 10 * k - n * 12 * k, c - d * 30 * k - n * 12 * k]), Color(0.6, 0.9, 0.7, 0.75), OUT, 3.0 * k)
	h._fill(PackedVector2Array([c - d * 20 * k + n * 6 * k, c + d * 6 * k + n * 6 * k, c + d * 6 * k - n * 6 * k, c - d * 20 * k - n * 6 * k]), CREAM)
	h.ci.draw_line(c - d * 7 * k + n * 6 * k, c - d * 7 * k - n * 6 * k, Color("#E0556F"), 2.5 * k, true)
	h._oval(c + d * 37 * k, 4 * k, 5 * k, Color("#C98A5C"), d.angle(), OUT, 2.0 * k)


static func _map(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -44, -72, 88, 60, Color("#E8D2A0"), 3)
	for sx in [-1.0, 1.0]:
		_r(h, p, k, sx * 44 - 5, -76, 10, 68, Color("#D8BC88"), 5)
	h._oval(p + Vector2(-14, -46) * k, 18 * k, 12 * k, Color("#9CC870"), 0.3)
	h._oval(p + Vector2(18, -50) * k, 12 * k, 8 * k, Color("#9CC870"), -0.2)
	for i in 6:
		h.ci.draw_circle(p + Vector2(-30 + i * 8, -26 - i * 3.5) * k, 1.6 * k, Color("#8A4A2A"), true, -1.0, true)
	var bl := 0.5 + 0.5 * sin(t * 4.0)
	var x := p + Vector2(22, -48) * k
	h.ci.draw_line(x + Vector2(-6, -6) * k, x + Vector2(6, 6) * k, Color(0.9, 0.15, 0.15, 0.6 + 0.4 * bl), 4 * k, true)
	h.ci.draw_line(x + Vector2(-6, 6) * k, x + Vector2(6, -6) * k, Color(0.9, 0.15, 0.15, 0.6 + 0.4 * bl), 4 * k, true)


static func _spyglass(h, p: Vector2, k: float, t: float) -> void:
	var o := clampf(sin(t * 0.6) * 1.6 + 0.3, 0.0, 1.0)
	var c := p + Vector2(-30, -28) * k
	_r(h, c, 1.0, 0, -9 * k, 30 * k / 1.0, 18 * k, BRASS, 4 * k)
	_r(h, c, 1.0, (26 + 14 * o) * k - 18 * k, -7 * k, 26 * k, 14 * k, BRASS.lightened(0.1), 4 * k)
	_r(h, c, 1.0, (46 + 26 * o) * k - 18 * k, -5 * k, 20 * k, 10 * k, BRASS.lightened(0.2), 3 * k)
	h._oval(c + Vector2(-2, 0) * k, 5 * k, 11 * k, Color("#9FE8FF"), 0.0, OUT, 2.0 * k)
	for sx in [-14.0, 14.0]:
		_line(h, p + Vector2(sx, 0) * k, p + Vector2(sx * 0.6, -20) * k, WOOD_D, 3 * k)


static func _lantern(h, p: Vector2, k: float, t: float) -> void:
	var sw := sin(t * 1.1) * 0.08
	var c := p + Vector2(0, -40) * k
	h._glow(c, 34 * k, Color("#FFD46B"), 0.25 + 0.05 * sin(t * 9.0))
	_r(h, p, k, -22, -14, 44, 10, Color("#4A3A2A"), 3)
	_r(h, p, k, -18, -64, 36, 50, Color(1.0, 0.85, 0.5, 0.6), 4)
	for sx in [-18.0, 0.0, 18.0]:
		h.ci.draw_line(p + Vector2(sx, -64) * k, p + Vector2(sx, -14) * k, BRASS, 2.5 * k, true)
	h._fill(PackedVector2Array([p + Vector2(-24, -64) * k, p + Vector2(24, -64) * k, p + Vector2(6, -80) * k, p + Vector2(-6, -80) * k]), Color("#4A3A2A"), OUT, 3.0 * k)
	h.ci.draw_arc(p + Vector2(0, -86) * k, 7 * k, 0, TAU, 12, BRASS, 3 * k, true)
	h._oval(c + Vector2(sw * 20, 0) * k, 6 * k, 10 * k, Color("#FFD46B"), 0.0, Color("#FF9E3A"), 2.0 * k)


static func _barrel(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -30, -66, 60, 66, WOOD, 14)
	for y in [-56.0, -12.0]:
		h.ci.draw_line(p + Vector2(-29, y) * k, p + Vector2(29, y) * k, Color("#5A5A6A"), 5 * k, true)
	for x in [-14.0, 0.0, 14.0]:
		h.ci.draw_line(p + Vector2(x, -62) * k, p + Vector2(x, -4) * k, WOOD_D, 1.5 * k, true)
	h._oval(p + Vector2(0, -68) * k, 28 * k, 12 * k, GOLD, 0.0, OUT, 3.0 * k)
	for i in 5:
		h.ci.draw_circle(p + Vector2(-16 + i * 8, -72 + (i % 2) * 4) * k, 4 * k, Color("#FFE27A"), true, -1.0, true)
	var u := fposmod(t * 0.35, 1.0)
	if u < 0.45:
		var s := u / 0.45
		h._oval(p + Vector2(34 * s, -70 - 30 * sin(s * PI) + 66 * s * s) * k, 5 * k, 5 * k * absf(cos(t * 6.0)) + 1.0, Color("#FFE27A"), 0.0, OUT, 1.5 * k)


static func _flag(h, p: Vector2, k: float, t: float) -> void:
	_line(h, p, p + Vector2(0, -104) * k, WOOD, 4 * k)
	h.ci.draw_circle(p + Vector2(0, -106) * k, 4 * k, GOLD, true, -1.0, true)
	var pts := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 9:
		var s := i / 8.0
		var w := sin(s * 7.0 - t * 3.0) * 5.0 * s
		pts.append(p + Vector2(s * 56, -100 + w) * k)
		bot.append(p + Vector2(s * 56, -62 + w) * k)
	var poly := pts.duplicate()
	for i in range(8, -1, -1):
		poly.append(bot[i])
	h._fill(poly, Color("#2E78C0"), OUT, 3.0 * k)
	var c := p + Vector2(30, -81 + sin(0.5 * 7.0 - t * 3.0) * 2.5) * k
	var sh := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		sh.append(c + Vector2(cos(a) * 11, sin(a) * 10 + 4) * k)
	sh.append(c + Vector2(0, 8) * k)
	h._fill(sh, Color("#FFB8D0"), OUT, 2.0 * k)
	for i in 3:
		h.ci.draw_line(c + Vector2(0, 7) * k, c + Vector2(-7 + i * 7, -4) * k, Color("#D06890"), 1.5 * k, true)


static func _wheel(h, p: Vector2, k: float, t: float) -> void:
	var c := p + Vector2(0, -56) * k
	var a0 := sin(t * 0.55) * 0.7
	for i in 8:
		var a := a0 + TAU * i / 8.0
		_line(h, c, c + Vector2(cos(a), sin(a)) * 46 * k, WOOD, 4 * k)
		h.ci.draw_circle(c + Vector2(cos(a), sin(a)) * 46 * k, 4.5 * k, WOOD_D, true, -1.0, true)
	h.ci.draw_arc(c, 32 * k, 0, TAU, 40, OUT, 12 * k, true)
	h.ci.draw_arc(c, 32 * k, 0, TAU, 40, WOOD, 8 * k, true)
	h.ci.draw_arc(c, 32 * k, 0, TAU, 40, GOLD, 2.5 * k, true)
	h._oval(c, 9 * k, 9 * k, GOLD, 0.0, OUT, 2.5 * k)


static func _ship(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -6) * k, 62 * k, 9 * k, Color("#D8C49A"), 0.0, OUT, 3.0 * k)
	_line(h, p + Vector2(4, -30) * k, p + Vector2(-4, -122) * k, WOOD_D, 5 * k)
	var sail := PackedVector2Array([p + Vector2(-2, -112) * k, p + Vector2(-44 + 3 * sin(t), -104) * k, p + Vector2(-40 + 3 * sin(t), -62) * k, p + Vector2(2, -58) * k])
	h._fill(sail, Color("#EEE2C2"), OUT, 2.5 * k)
	h._oval(p + Vector2(-20, -84) * k, 9 * k, 8 * k, Color("#FFB8D0"))
	var hull := PackedVector2Array([p + Vector2(-50, -46) * k, p + Vector2(46, -34) * k, p + Vector2(58, -50) * k, p + Vector2(36, -10) * k, p + Vector2(-40, -10) * k])
	h._fill(hull, Color("#8A4E2C"), OUT, 3.0 * k)
	for i in 3:
		var c := p + Vector2(-22 + i * 22, -26) * k
		h._glow(c, 9 * k, Color("#FFD27A"), 0.3)
		h._oval(c, 5 * k, 5 * k, Color("#FFD27A"), 0.0, BRASS, 2.0 * k)
	for i in 3:
		var u := fposmod(t * 0.3 + i / 3.0, 1.0)
		h.ci.draw_circle(p + Vector2(20 + 4 * sin(u * 7.0), -50 - u * 70) * k, (3 + i) * k, Color(0.85, 1, 1, 0.7 * (1.0 - u)), false, 1.5 * k, true)


static func _plankton(h, p: Vector2, k: float, t: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var s := i / 16.0
		pts.append(p + Vector2(lerpf(-48, 48, s), -60 + sin(s * PI) * 26 + sin(s * 12.0) * 3) * k)
	h.ci.draw_polyline(pts, Color("#7FB8D0"), 2 * k, true)
	var cols := [Color("#7FF5E0"), Color("#9F8CFF"), Color("#FF8FD8"), Color("#6FD8FF")]
	for i in range(1, 16, 2):
		var g := 0.6 + 0.4 * sin(t * 2.4 + i * 0.8)
		h._glow(pts[i], 9 * k, cols[i % 4], 0.3 * g)
		h.ci.draw_circle(pts[i], (3 + (i % 3)) * k, Color(cols[i % 4], g), true, -1.0, true)


static func _anemones(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -5) * k, 40 * k, 8 * k, Color("#3C6E90"), 0.0, OUT, 3.0 * k)
	var defs := [[-18.0, Color("#C060FF"), Color("#FF8FF0"), 1.0], [18.0, Color("#2FB0D0"), Color("#9FF6FF"), 0.85], [0.0, Color("#FF5FA0"), Color("#FFD0E8"), 0.7]]
	for d in defs:
		var b := p + Vector2(d[0], -8) * k
		var s: float = d[3]
		_r(h, b, k, -7 * s, -22 * s, 14 * s, 22 * s, d[1], 5)
		for i in 7:
			var a := lerpf(-1.1, 1.1, i / 6.0) + sin(t * 1.4 + i) * 0.08
			var tip := b + Vector2(0, -22 * s) * k + Vector2(sin(a), -cos(a)) * 22 * s * k
			h.ci.draw_line(b + Vector2(0, -22 * s) * k, tip, d[2], 3 * k, true)
			h.ci.draw_circle(tip, 3 * k * s, d[2], true, -1.0, true)
		h._glow(b + Vector2(0, -36 * s) * k, 16 * k * s, d[2], 0.22)


static func _vent(h, p: Vector2, k: float, t: float) -> void:
	h._fill(PackedVector2Array([p + Vector2(-38, 0) * k, p + Vector2(-16, -66) * k, p + Vector2(16, -66) * k, p + Vector2(38, 0) * k]), Color("#4A4A66"), OUT, 3.0 * k)
	h._oval(p + Vector2(0, -66) * k, 16 * k, 6 * k, Color("#FFB060"), 0.0, OUT, 2.0 * k)
	h._glow(p + Vector2(0, -70) * k, 24 * k, Color("#FF8A3A"), 0.35)
	for i in 4:
		var u := fposmod(t * 0.45 + i / 4.0, 1.0)
		h.ci.draw_circle(p + Vector2(4 * sin(u * 7.0 + i), -72 - u * 22) * k, (4 - 2 * u) * k, Color(1.0, 0.75, 0.85, 1.0 - u), true, -1.0, true)


static func _neonsquid(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -34, -92, 68, 84, Color("#1E1A34"), 6)
	var u := fposmod(t, 5.0)
	var on := 0.25 if (u > 4.3 and u < 4.6 and fposmod(t * 14.0, 1.0) < 0.5) else 1.0
	var pink := Color(1.0, 0.37, 0.85, on)
	var cyan := Color(0.37, 0.94, 1.0, 1.0)
	var mantle := PackedVector2Array()
	for i in 15:
		var a := lerpf(-PI * 0.42, PI * 1.42, i / 14.0)
		var r := 15.0 + 9.0 * pow(maxf(0.0, sin(a)), 4.0)
		mantle.append(p + Vector2(cos(a) * 14, -54 - sin(a) * r) * k)
	h._glow(p + Vector2(0, -60) * k, 30 * k, Color("#FF5FD8"), 0.15 * on)
	h.ci.draw_polyline(mantle, pink, 3.5 * k, true)
	for i in 4:
		var pts := PackedVector2Array()
		for j in 6:
			var s := j / 5.0
			pts.append(p + Vector2(-10 + i * 7 + 4 * sin(s * 6.0 + i), -48 + s * 32) * k)
		h.ci.draw_polyline(pts, cyan, 2.5 * k, true)
	for sx in [-1.0, 1.0]:
		h.ci.draw_arc(p + Vector2(sx * 6, -60) * k, 3 * k, 0, TAU, 10, cyan, 2 * k, true)


static func _crystal(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -6) * k, 34 * k, 9 * k, Color("#2A2A44"), 0.0, OUT, 3.0 * k)
	var g := 0.6 + 0.4 * sin(t * 1.6)
	h._glow(p + Vector2(0, -44) * k, 34 * k, Color("#B07CFF"), 0.3 * g)
	h._fill(PackedVector2Array([p + Vector2(-16, -10) * k, p + Vector2(-14, -62) * k, p + Vector2(0, -86) * k, p + Vector2(14, -62) * k, p + Vector2(16, -10) * k]), Color(0.42, 0.29, 0.78, 0.85), OUT, 3.0 * k)
	h._oval(p + Vector2(0, -44) * k, 8 * k * (0.9 + 0.2 * g), 8 * k * (0.9 + 0.2 * g), Color("#E0C8FF"))
	for sx in [-1.0, 1.0]:
		h._fill(PackedVector2Array([p + Vector2(sx * 16, -8) * k, p + Vector2(sx * 24, -44) * k, p + Vector2(sx * 30, -40) * k, p + Vector2(sx * 22, -8) * k]), Color("#8A5CFF"), OUT, 2.0 * k)


static func _angler(h, p: Vector2, k: float, t: float) -> void:
	h._oval(p + Vector2(0, -6) * k, 34 * k, 8 * k, Color("#3C6E90"), 0.0, OUT, 3.0 * k)
	var c := p + Vector2(0, -40 + 2 * sin(t * 1.3)) * k
	var sw := sin(t * 1.4) * 0.25
	var tip := c + Vector2(0, -30) * k + Vector2(16, -26).rotated(sw) * k
	h.ci.draw_line(c + Vector2(0, -28) * k, tip, Color("#5A6AD8"), 3 * k, true)
	h._glow(tip, 18 * k, Color("#BFFFF0"), 0.4)
	h.ci.draw_circle(tip, 6 * k, Color("#DFFFF8"), true, -1.0, true)
	h._fill(PackedVector2Array([c + Vector2(26, 0) * k, c + Vector2(46, -14) * k, c + Vector2(46, 14) * k]), Color("#5A6AD8"), OUT, 2.5 * k)
	h._oval(c, 30 * k, 28 * k, Color("#5A6AD8"), 0.0, OUT, 3.0 * k)
	h._oval(c + Vector2(0, 10) * k, 20 * k, 12 * k, Color("#A8B8FF"))
	for sx in [-1.0, 1.0]:
		h._oval(c + Vector2(sx * 11, -6) * k, 8 * k, 9 * k, Color.WHITE, 0.0, OUT, 2.0 * k)
		h.ci.draw_circle(c + Vector2(sx * 11, -5) * k, 4.5 * k, OUT, true, -1.0, true)
		h.ci.draw_circle(c + Vector2(sx * 11 - 1.5, -7) * k, 1.6 * k, Color.WHITE, true, -1.0, true)
	h.ci.draw_arc(c + Vector2(0, 6) * k, 7 * k, 0.3, PI - 0.3, 10, OUT, 2 * k, true)


static func _pod(h, p: Vector2, k: float, t: float) -> void:
	_r(h, p, k, -8, -20, 16, 20, Color("#2A2A44"), 4)
	h._glow(p + Vector2(0, -24) * k, 40 * k, Color("#5FF0FF"), 0.18 + 0.05 * sin(t * 1.2))
	h._oval(p + Vector2(0, -22) * k, 44 * k, 8 * k, Color("#5FF0FF"), 0.0, OUT, 2.5 * k)
	var shell := PackedVector2Array()
	for i in 19:
		var a := PI * 0.95 + PI * 1.1 * i / 18.0
		shell.append(p + Vector2(0, -58) * k + Vector2(cos(a), sin(a)) * 40 * k)
	h._fill(shell, Color(0.62, 0.9, 1.0, 0.35), OUT, 2.5 * k)
	h._oval(p + Vector2(0, -40) * k, 30 * k, 11 * k, Color("#FF8FD8"), 0.0, OUT, 2.5 * k)
	h._oval(p + Vector2(0, -62) * k, 22 * k, 14 * k, Color("#FFB3E6"), 0.0, OUT, 2.5 * k)


static func _jelly(h, p: Vector2, k: float, t: float) -> void:
	h.ci.draw_line(p + Vector2(0, -100) * k, p + Vector2(0, -84) * k, Color("#9FE8FF"), 1.5 * k, true)
	h._oval(p + Vector2(0, -84) * k, 40 * k, 6 * k, Color("#9F8CFF"), 0.0, OUT, 2.5 * k)
	var cols := [Color("#7FD8FF"), Color("#FF9FE0"), Color("#9F8CFF")]
	for i in 3:
		var x := -28.0 + i * 28.0
		var y := -46.0 - 8.0 * (i % 2) + 3.0 * sin(t * 1.1 + i * 2.0)
		var c := p + Vector2(x, y) * k
		h.ci.draw_line(p + Vector2(x, -84) * k, c + Vector2(0, -14) * k, Color("#9FE8FF"), 1.2 * k, true)
		var pul := 1.0 + 0.08 * sin(t * 1.6 + i * 1.4)
		h._glow(c, 22 * k, cols[i], 0.25)
		for j in 3:
			_wavy(h, c + Vector2(-8 + j * 8, 2) * k, 22, k, t, cols[i].lightened(0.2), 1.5, i + j)
		var dome := PackedVector2Array()
		for j in 13:
			var a := PI + PI * j / 12.0
			dome.append(c + Vector2(cos(a) * 15 * pul, sin(a) * 16 * pul) * k)
		h._fill(dome, Color(cols[i], 0.8), OUT, 2.0 * k)


static func _sub(h, p: Vector2, k: float, t: float) -> void:
	for sx in [-1.0, 1.0]:
		_line(h, p + Vector2(-42, -4) * k, p + Vector2(42, -4) * k, Color("#5A5A6A"), 4 * k)
		_line(h, p + Vector2(sx * 22, -4) * k, p + Vector2(sx * 14, -24) * k, Color("#5A5A6A"), 3 * k)
	var c := p + Vector2(0, -56) * k
	var a := sin(t * 0.45) * 0.4
	var beam_dir := Vector2(1, -0.35).rotated(a).normalized()
	var b0 := c + Vector2(14, -30) * k
	var bn := Vector2(-beam_dir.y, beam_dir.x)
	h._fill(PackedVector2Array([b0 + bn * 4 * k, b0 + (beam_dir * 60 + bn * 20) * k, b0 + (beam_dir * 60 - bn * 20) * k, b0 - bn * 4 * k]), Color(1.0, 0.95, 0.7, 0.3))
	var pr := absf(cos(t * 5.0))
	h._oval(c + Vector2(-46, 0) * k, 4 * k, 16 * k * pr + 2.0, Color("#E0A83A"), 0.0, OUT, 2.0 * k)
	h._oval(c, 40 * k, 40 * k, Color("#FFC83A"), 0.0, OUT, 3.0 * k)
	h._oval(c + Vector2(8, 2) * k, 17 * k, 17 * k, Color("#1A3A5A"), 0.0, BRASS, 4.0 * k)
	h._glow(c + Vector2(8, 2) * k, 16 * k, Color("#5FD8FF"), 0.3)
	h._oval(c + Vector2(8, 4) * k, 7 * k, 6 * k, Color("#FFB8D0"))
	_r(h, c, k, -10, -46, 20, 8, Color("#E0A020"), 3)
	_r(h, c, k, 10, -38, 12, 10, Color("#5A5A6A"), 3)
	h.ci.draw_line(c + Vector2(-14, -40) * k, c + Vector2(-14, -58) * k, Color("#5A5A6A"), 2 * k, true)
	h.ci.draw_circle(c + Vector2(-14, -60) * k, 3.5 * k, Color(1.0, 0.3, 0.4, 0.5 + 0.5 * sin(t * 4.0)), true, -1.0, true)
