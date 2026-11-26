extends RefCounted
## Значки новых украшений щенка (0.15) — 2D, для карточек панели «Украсить» и запасного 2D-дома.
## Вызывает scripts/home.gd (_generic_decor): draw(h, id, p, k, t) -> true, если значок нарисован.
## h — рисовальщик home.gd (его ci и помощники _fill / _oval / _glow / _rrect / _sparkle / _paw / _bone).
## p — точка «земли» вещи (низ по центру), k — масштаб, t — время. Рисунок — в рамке x ±62, y от −100 до 0.

const OUT := Color("#1E1236")


static func _star(c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + rot + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return pts


static func _bolt(c: Vector2, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in [Vector2(0.12, -0.5), Vector2(-0.22, -0.02), Vector2(-0.02, -0.02), Vector2(-0.14, 0.5), Vector2(0.24, -0.06), Vector2(0.03, -0.06)]:
		pts.append(c + v * h)
	return pts


static func _tri(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b, c])


static func draw(h, id: String, p: Vector2, k: float, t: float) -> bool:
	var ci: CanvasItem = h.ci
	var w := 3.0
	match id:
		"pup_sunflowers":
			for i in 3:
				var x := (-28 + i * 28) * k
				var top := p + Vector2(x, (-92 + absf(i - 1) * 18) * k)
				ci.draw_line(p + Vector2(x, 0), top, Color("#3F8A55"), 5 * k, true)
				h._oval(p + Vector2(x + 9 * k, -30 * k), 10 * k, 5 * k, Color("#5BC27E"), -0.5)
				var sw := sin(t * 1.2 + i) * 0.15
				for j in 12:
					var a := TAU * j / 12.0 + sw
					h._oval(top + Vector2(cos(a), sin(a)) * 14 * k, 8 * k, 4 * k, Color("#FFC93C"), a, OUT, 1.5)
				h._oval(top, 10 * k, 10 * k, Color("#6B3F22"), 0.0, OUT, w)
		"pup_picnic":
			h._fill(PackedVector2Array([p + Vector2(-60, -6) * k, p + Vector2(60, -6) * k, p + Vector2(42, -40) * k, p + Vector2(-42, -40) * k]), Color("#FFF4E6"), OUT, w)
			for i in 4:
				for j in 2:
					if (i + j) % 2 == 0:
						var a := Vector2(-55 + i * 27.5 + j * 4, -6 - j * 17) * k
						h._fill(PackedVector2Array([p + a, p + a + Vector2(24, 0) * k, p + a + Vector2(21, -15) * k, p + a + Vector2(-3, -15) * k]), Color("#E8505B"))
			var lid := -absf(sin(t * 2.0)) * 8 * k
			h._fill(h._rrect(Rect2(p + Vector2(-38, -64) * k, Vector2(40, 30) * k), 5 * k), Color("#C98A4A"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-41, -70) * k + Vector2(0, lid), Vector2(46, 9) * k), 4 * k), Color("#E0A260"), OUT, w)
			ci.draw_arc(p + Vector2(-18, -64) * k, 14 * k, PI, TAU, 12, Color("#A8692F"), 4 * k, true)
			h._oval(p + Vector2(26, -26) * k, 12 * k, 5 * k, Color("#FFFFFF"), 0.0, OUT, 2.0)
			h._oval(p + Vector2(26, -31) * k, 8 * k, 6 * k, Color("#FF9EC6"), 0.0, OUT, 2.0)
		"pup_birdbath":
			h._fill(PackedVector2Array([p + Vector2(-22, 0) * k, p + Vector2(22, 0) * k, p + Vector2(10, -12) * k, p + Vector2(8, -50) * k, p + Vector2(-8, -50) * k, p + Vector2(-10, -12) * k]), Color("#B9B4D6"), OUT, w)
			h._fill(PackedVector2Array([p + Vector2(-50, -62) * k, p + Vector2(50, -62) * k, p + Vector2(34, -50) * k, p + Vector2(-34, -50) * k]), Color("#B9B4D6"), OUT, w)
			h._oval(p + Vector2(0, -62) * k, 48 * k, 6 * k, Color("#6FC8F0"), 0.0, OUT, 2.0)
			var bx := sin(t * 1.4) * 26.0
			var hop := -absf(sin(t * 4.4)) * 6.0
			var b := p + Vector2(bx, -76 + hop) * k
			h._oval(b, 11 * k, 9 * k, Color("#5FB8FF"), 0.0, OUT, 2.0)
			h._oval(b + Vector2(8, -8) * k, 7 * k, 7 * k, Color("#5FB8FF"), 0.0, OUT, 2.0)
			h._fill(_tri(b + Vector2(14, -9) * k, b + Vector2(21, -7) * k, b + Vector2(14, -5) * k), Color("#FFB547"))
			ci.draw_circle(b + Vector2(10, -10) * k, 1.8 * k, OUT, true, -1.0, true)
		"pup_gazebo":
			h._glow(p + Vector2(0, -50) * k, 60 * k, Color("#FFB8E0"), 0.18)
			h._fill(h._rrect(Rect2(p + Vector2(-56, -10) * k, Vector2(112, 10) * k), 3 * k), Color("#E2D8F0"), OUT, w)
			for x in [-46, -16, 16, 46]:
				h._fill(h._rrect(Rect2(p + Vector2(x - 3, -66) * k, Vector2(6, 56) * k), 2 * k), Color("#F4F0FA"), OUT, 2.0)
			h._fill(PackedVector2Array([p + Vector2(-62, -64) * k, p + Vector2(62, -64) * k, p + Vector2(4, -98) * k, p + Vector2(-4, -98) * k]), Color("#FF8FB1"), OUT, w)
			h._sparkle(p + Vector2(0, -104) * k, (8 + 2 * sin(t * 3.0)) * k, Color("#FFE27A"))
			for i in 7:
				var x := -48 + i * 16
				var y := -60 + absf(sin(i * 1.3)) * 4
				ci.draw_circle(p + Vector2(x, y) * k, 3.2 * k, [Color("#FFE27A"), Color("#FF8FC8"), Color("#9FF0FF")][(i + int(t * 2.0)) % 3], true, -1.0, true)
			var sa := sin(t * 1.3) * 0.15
			var seat := p + Vector2(0, -26) * k + Vector2(sin(sa), 0) * 10 * k
			ci.draw_line(p + Vector2(-12, -62) * k, seat + Vector2(-12, 0) * k, Color("#C9B88A"), 2 * k, true)
			ci.draw_line(p + Vector2(12, -62) * k, seat + Vector2(12, 0) * k, Color("#C9B88A"), 2 * k, true)
			h._fill(h._rrect(Rect2(seat + Vector2(-18, -3) * k, Vector2(36, 7) * k), 3 * k), Color("#FF9EC6"), OUT, 2.0)
		"pup_pennants":
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(p + Vector2(-58 + i * 14.5, -86 + sin(i / 8.0 * PI) * 16) * k)
			ci.draw_polyline(pts, Color("#E8D6B0"), 2.5 * k, true)
			var cols := [Color("#FF5A6E"), Color("#FFD34D"), Color("#3FC8B8"), Color("#FF8A3D"), Color("#9C7BFF")]
			for i in 7:
				var a: Vector2 = pts[i + 1]
				var sway := sin(t * 3.0 + i) * 3.0
				h._fill(_tri(a + Vector2(-7, 0) * k, a + Vector2(7, 0) * k, a + Vector2(sway, 22) * k), cols[i % 5], OUT, 2.0)
		"pup_binoculars":
			for sx in [-1.0, 1.0]:
				ci.draw_line(p + Vector2(0, -40) * k, p + Vector2(sx * 24, 0) * k, Color("#8A5A3A"), 4 * k, true)
			ci.draw_line(p + Vector2(0, -40) * k, p + Vector2(0, 0) * k, Color("#8A5A3A"), 4 * k, true)
			var tilt := -0.35 + sin(t * 0.8) * 0.1
			for sx in [-1.0, 1.0]:
				var c := p + Vector2(sx * 16, -58) * k
				var r := Rect2(c + Vector2(-11, -22) * k, Vector2(22, 34) * k)
				h._fill(h._rrect(r, 8 * k), Color("#2E6A50"), OUT, w)
				h._oval(c + Vector2(0, -22) * k, 10 * k, 5 * k, Color("#9FE8FF"), 0.0, OUT, 2.0)
			h._fill(h._rrect(Rect2(p + Vector2(-6, -66) * k, Vector2(12, 14) * k), 3 * k), Color("#FFB547"), OUT, 2.0)
			h._sparkle(p + Vector2(34 + tilt * 10, -96) * k, 6 * k, Color("#FFE27A"))
		"pup_backpack":
			h._fill(h._rrect(Rect2(p + Vector2(-34, -80) * k, Vector2(68, 80) * k), 22 * k), Color("#4F9A5E"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-36, -84) * k, Vector2(72, 30) * k), 14 * k), Color("#3A7A48"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-22, -38) * k, Vector2(44, 30) * k), 10 * k), Color("#FF8A3D"), OUT, w)
			h._paw(p + Vector2(0, -24) * k, 0.7 * k, Color("#FFF1DC"))
			h._fill(h._rrect(Rect2(p + Vector2(-30, -100) * k, Vector2(60, 18) * k), 9 * k), Color("#E8505B"), OUT, w)
			var sw := sin(t * 2.0) * 3.0
			h._oval(p + Vector2(44 + sw, -34) * k, 10 * k, 9 * k, Color("#C0C4D8"), 0.0, OUT, 2.0)
		"pup_trailmap":
			h._fill(h._rrect(Rect2(p + Vector2(-56, -92) * k, Vector2(112, 80) * k), 8 * k), Color("#8A5A3A"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-48, -85) * k, Vector2(96, 66) * k), 4 * k), Color("#F3E3B5"))
			h._fill(_tri(p + Vector2(8, -40) * k, p + Vector2(28, -74) * k, p + Vector2(46, -40) * k), Color("#9A94C0"))
			h._fill(_tri(p + Vector2(22, -64) * k, p + Vector2(28, -74) * k, p + Vector2(34, -64) * k), Color("#FFFFFF"))
			var trail := [Vector2(-38, -28), Vector2(-24, -42), Vector2(-28, -58), Vector2(-8, -66), Vector2(8, -52), Vector2(22, -58), Vector2(36, -76)]
			for i in trail.size() - 1:
				var a: Vector2 = trail[i]
				var b: Vector2 = trail[i + 1]
				ci.draw_dashed_line(p + a * k, p + b * k, Color("#E8505B"), 2.5 * k, 5 * k, true)
			var u := fposmod(t * 0.25, 1.0) * (trail.size() - 1)
			var iu := mini(int(u), trail.size() - 2)
			var dot: Vector2 = (trail[iu] as Vector2).lerp(trail[iu + 1], u - iu)
			h._glow(p + dot * k, 9 * k, Color("#FFF2A0"), 0.5)
			ci.draw_circle(p + dot * k, 3.5 * k, Color("#FFF2A0"), true, -1.0, true)
		"pup_canoe":
			var hull := PackedVector2Array()
			for i in 17:
				var a := lerpf(0.0, PI, i / 16.0)
				hull.append(p + Vector2(-cos(a) * 62, -18 + sin(a) * 18 - 16) * k)
			h._fill(hull, Color("#E0503F"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-60, -38) * k, Vector2(120, 7) * k), 3 * k), Color("#F4E6D4"), OUT, 2.0)
			ci.draw_line(p + Vector2(-20, -10) * k, p + Vector2(40, -80) * k, Color("#C98A4A"), 4 * k, true)
			h._oval(p + Vector2(44, -86) * k, 7 * k, 13 * k, Color("#F4B45A"), 0.7, OUT, 2.0)
			h._paw(p + Vector2(-10, -22) * k, 0.55 * k, Color("#FFF1DC"))
		"pup_tent":
			h._fill(_tri(p + Vector2(-60, 0) * k, p + Vector2(60, 0) * k, p + Vector2(0, -96) * k), Color("#F29A4A"), OUT, w)
			var glow := 0.8 + 0.2 * sin(t * 3.0)
			h._fill(_tri(p + Vector2(-26, 0) * k, p + Vector2(26, 0) * k, p + Vector2(0, -52) * k), Color(Color("#FFB347"), glow))
			h._fill(_tri(p + Vector2(-26, 0) * k, p + Vector2(-38, 0) * k, p + Vector2(0, -52) * k), Color("#FFB870"), OUT, 2.0)
			h._fill(h._rrect(Rect2(p + Vector2(-60, -6) * k, Vector2(120, 6) * k), 2 * k), Color("#3FB8A8"))
			ci.draw_line(p + Vector2(0, -96) * k, p + Vector2(0, -110) * k, OUT, 2.5 * k, true)
			h._fill(_tri(p + Vector2(0, -110) * k, p + Vector2(16 + sin(t * 4.0) * 3, -106) * k, p + Vector2(0, -102) * k), Color("#3FB8A8"))
		"pup_campfire":
			h._glow(p + Vector2(0, -30) * k, 56 * k, Color("#FFA24A"), 0.25)
			for i in 5:
				h._oval(p + Vector2(-44 + i * 22, -6) * k, 12 * k, 8 * k, Color("#8E88B8"), 0.0, OUT, 2.0)
			ci.draw_line(p + Vector2(-34, -6) * k, p + Vector2(20, -30) * k, Color("#7A4A30"), 9 * k, true)
			ci.draw_line(p + Vector2(34, -6) * k, p + Vector2(-20, -30) * k, Color("#7A4A30"), 9 * k, true)
			var f := 1.0 + 0.1 * sin(t * 12.0)
			h._fill(PackedVector2Array([p + Vector2(-24, -12) * k, p + Vector2(24, -12) * k, p + Vector2(0, -12 - 72 * f) * k]), Color("#FF7A1A"))
			h._fill(PackedVector2Array([p + Vector2(-15, -12) * k, p + Vector2(15, -12) * k, p + Vector2(0, -12 - 50 * f) * k]), Color("#FFC23A"))
			h._fill(PackedVector2Array([p + Vector2(-7, -12) * k, p + Vector2(7, -12) * k, p + Vector2(0, -12 - 28 * f) * k]), Color("#FFF4B0"))
			for i in 3:
				var u := fposmod(t * 0.6 + i * 0.33, 1.0)
				ci.draw_circle(p + Vector2(sin(i * 2.0 + t) * 10, -60 - u * 40) * k, 2.2 * k, Color(1.0, 0.85, 0.5, 1.0 - u), true, -1.0, true)
			ci.draw_line(p + Vector2(58, -8) * k, p + Vector2(22, -50) * k, Color("#A8723E"), 3 * k, true)
			h._fill(h._rrect(Rect2(p + Vector2(14, -60) * k, Vector2(12, 12) * k), 3 * k), Color("#FFF6EE"), OUT, 2.0)
		"pup_cones":
			for i in 3:
				var x := -36 + i * 36
				var c := p + Vector2(x, 0) * k
				var fall := 0.0
				if i == 2:
					var u := fposmod(t, 4.0)
					fall = clampf(u * 2.0, 0.0, 1.0) * (1.0 - clampf((u - 1.5) * 2.0, 0.0, 1.0)) * 1.2
				var dirv := Vector2(sin(fall), -cos(fall))
				var side := Vector2(cos(fall), sin(fall))
				h._fill(PackedVector2Array([c - side * 16 * k, c + side * 16 * k, c + dirv * 60 * k + side * 3 * k, c + dirv * 60 * k - side * 3 * k]), Color("#FF7A2E"), OUT, w)
				h._fill(PackedVector2Array([c + dirv * 22 * k - side * 12 * k, c + dirv * 22 * k + side * 12 * k, c + dirv * 32 * k + side * 9.5 * k, c + dirv * 32 * k - side * 9.5 * k]), Color("#FFFFFF"))
				h._fill(h._rrect(Rect2(c + Vector2(-20, -5) * k, Vector2(40, 5) * k), 2 * k), Color("#E85A1E"), OUT, 2.0)
		"pup_spray":
			var cols := [Color("#FF4FA3"), Color("#3FE0FF"), Color("#FFD34D"), Color("#7AE08A")]
			for i in 4:
				var x := -45 + i * 30
				var sh := sin(t * 18.0) * 3.0 if i == 2 and fposmod(t, 3.0) < 1.0 else 0.0
				var c := p + Vector2(x + sh, 0) * k
				h._fill(h._rrect(Rect2(c + Vector2(-11, -58) * k, Vector2(22, 58) * k), 5 * k), cols[i], OUT, w)
				h._fill(h._rrect(Rect2(c + Vector2(-6, -70) * k, Vector2(12, 13) * k), 3 * k), Color("#D8DCEC"), OUT, 2.0)
				h._fill(h._rrect(Rect2(c + Vector2(-11, -26) * k, Vector2(22, 7) * k), 2 * k), Color("#FFFFFF"))
			h._oval(p + Vector2(15, -84) * k, 10 * k, 7 * k, Color(1.0, 0.85, 0.3, 0.6))
		"pup_headphones":
			ci.draw_arc(p + Vector2(0, -50) * k, 34 * k, PI, TAU, 24, OUT, 13 * k, true)
			ci.draw_arc(p + Vector2(0, -50) * k, 34 * k, PI, TAU, 24, Color("#3F7AE0"), 8 * k, true)
			var cols := [Color("#3FE0FF"), Color("#FF4FA3")]
			for i in 2:
				var sx := -1.0 if i == 0 else 1.0
				var c := p + Vector2(sx * 34, -40) * k
				h._fill(h._rrect(Rect2(c + Vector2(-13, -22) * k, Vector2(26, 44) * k), 10 * k), Color("#2A2440"), OUT, w)
				var g := 0.6 + 0.4 * sin(t * 3.0 + i * 2.0)
				h._glow(c, 18 * k, cols[i], 0.25 * g)
				h._oval(c, 8 * k, 14 * k, cols[i])
		"pup_skateboard":
			var r := sin(t * 1.4) * 0.04
			var deck := PackedVector2Array([p + Vector2(-60, -34) * k, p + Vector2(-48, -26) * k, p + Vector2(48, -26) * k, p + Vector2(60, -34) * k, p + Vector2(50, -18) * k, p + Vector2(-50, -18) * k])
			for i in deck.size():
				deck[i] = p + (deck[i] - p).rotated(r)
			h._fill(deck, Color("#FF8A3D"), OUT, w)
			h._fill(_bolt(p + Vector2(0, -24) * k, 14 * k).duplicate(), Color("#FFD34D"))
			for sx in [-30.0, 30.0]:
				var c := p + Vector2(sx, -8) * k
				h._oval(c, 9 * k, 9 * k, Color("#7AE8C8"), 0.0, OUT, 2.0)
				var a := t * 7.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * 4.5 * k, 2 * k, Color("#FFFFFF"), true, -1.0, true)
		"pup_hoop":
			h._fill(h._rrect(Rect2(p + Vector2(-50, -100) * k, Vector2(100, 64) * k), 8 * k), Color("#3F7AE0"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-44, -95) * k, Vector2(88, 54) * k), 5 * k), Color("#F4F7FF"))
			ci.draw_rect(Rect2(p + Vector2(-16, -76) * k, Vector2(32, 22) * k), Color("#FF6A2A"), false, 2.5 * k)
			h._fill(_star(p + Vector2(-32, -84) * k, 7 * k), Color("#FFD34D"))
			h._oval(p + Vector2(0, -44) * k, 24 * k, 6 * k, Color(0, 0, 0, 0), 0.0, Color("#FF6A2A"), 4.0)
			for i in 5:
				var x := -20 + i * 10
				ci.draw_line(p + Vector2(x, -42) * k, p + Vector2(x * 0.6, -16) * k, Color("#FFFFFF"), 2 * k, true)
			var u := fposmod(t * 0.5, 1.0)
			if u < 0.5:
				var s := u / 0.5
				var bp := Vector2(46, -10).lerp(Vector2(20, -96), s).lerp(Vector2(20, -96).lerp(Vector2(0, -56), s), s)
				h._oval(p + bp * k, 9 * k, 9 * k, Color("#FF7A2E"), 0.0, OUT, 2.0)
		"pup_graffiti":
			var hue := fposmod(t * 0.06, 1.0)
			h._fill(h._rrect(Rect2(p + Vector2(-60, -92) * k, Vector2(120, 70) * k), 26 * k), Color.from_hsv(hue, 0.55, 1.0), OUT, w)
			for i in 4:
				var x := -40 + i * 26
				ci.draw_line(p + Vector2(x, -24) * k, p + Vector2(x, -12 - (i % 2) * 8) * k, Color.from_hsv(hue, 0.55, 0.9), 6 * k, true)
			h._paw(p + Vector2(-24, -56) * k, 1.1 * k, Color("#FFFFFF"))
			h._fill(_bolt(p + Vector2(30, -58) * k, 52 * k), Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.6, 1.0), OUT, 2.0)
			h._fill(_star(p + Vector2(6, -80) * k, 9 * k), Color("#FFD34D"), OUT, 2.0)
		"pup_boombox":
			h._fill(h._rrect(Rect2(p + Vector2(-58, -66) * k, Vector2(116, 62) * k), 12 * k), Color("#3F7AE0"), OUT, w)
			ci.draw_arc(p + Vector2(0, -66) * k, 26 * k, PI, TAU, 16, OUT, 6 * k, true)
			var beat := 1.0 + 0.12 * exp(-fposmod(t * 2.0, 1.0) * 8.0)
			for sx in [-1.0, 1.0]:
				h._oval(p + Vector2(sx * 32, -34) * k, 19 * beat * k, 19 * beat * k, Color("#2A2440"), 0.0, OUT, 2.0)
				h._oval(p + Vector2(sx * 32, -34) * k, 8 * beat * k, 8 * beat * k, Color("#FF4FA3"))
			h._fill(h._rrect(Rect2(p + Vector2(-11, -44) * k, Vector2(22, 14) * k), 3 * k), Color("#1E1836"))
			for i in 2:
				var u := fposmod(t * 0.4 + i * 0.5, 1.0)
				var np := p + Vector2(-18 + i * 36, -76 - u * 26) * k
				ci.draw_circle(np, 5 * k, Color([Color("#FF6FC8"), Color("#3FE0FF")][i], 1.0 - u), true, -1.0, true)
				ci.draw_line(np + Vector2(5, 0) * k, np + Vector2(5, -16) * k, Color([Color("#FF6FC8"), Color("#3FE0FF")][i], 1.0 - u), 2 * k, true)
		"pup_neon":
			h._fill(h._rrect(Rect2(p + Vector2(-58, -96) * k, Vector2(116, 84) * k), 10 * k), Color("#231C3E"), OUT, w)
			var on := 1.0 if fposmod(t, 3.2) < 2.3 or fposmod(t * 8.0, 1.0) < 0.5 else 0.25
			h._glow(p + Vector2(-20, -54) * k, 30 * k, Color("#FF4FA3"), 0.25)
			var pc := Color("#FF6FC0")
			h._oval(p + Vector2(-20, -46) * k, 15 * k, 11 * k, Color(0, 0, 0, 0), 0.0, pc, 3.0)
			for d in [Vector2(-34, -62), Vector2(-25, -72), Vector2(-15, -72), Vector2(-6, -62)]:
				h._oval(p + d * k, 5 * k, 6 * k, Color(0, 0, 0, 0), 0.0, pc, 2.5)
			var bp := _bolt(p + Vector2(28, -54) * k, 58 * k)
			bp.append(bp[0])
			h._glow(p + Vector2(28, -54) * k, 26 * k, Color("#3FE0FF"), 0.22 * on)
			ci.draw_polyline(bp, Color(Color("#7FF0FF"), on), 3 * k, true)
		"pup_ramp":
			var prof := PackedVector2Array()
			for i in 21:
				var x := lerpf(-60, 60, i / 20.0)
				var ax := absf(x)
				var y := -6.0 if ax < 18 else -6.0 - (42.0 - sqrt(maxf(0.0, 42.0 * 42.0 - pow(minf(ax - 18.0, 41.0), 2.0))))
				prof.append(p + Vector2(x, y) * k)
			var side := prof.duplicate()
			side.append(p + Vector2(60, 0) * k)
			side.append(p + Vector2(-60, 0) * k)
			h._fill(side, Color("#F2C27A"), OUT, w)
			ci.draw_polyline(prof, Color("#4F8BEA"), 7 * k, true)
			h._fill(_bolt(p + Vector2(-40, -22) * k, 22 * k), Color("#FF4FA3"))
			h._fill(_bolt(p + Vector2(40, -22) * k, 22 * k), Color("#3FE0FF"))
			var sx := sin(t * 1.7) * 50.0
			var ax2 := absf(sx)
			var sy := -6.0 if ax2 < 18 else -6.0 - (42.0 - sqrt(maxf(0.0, 42.0 * 42.0 - pow(minf(ax2 - 18.0, 41.0), 2.0))))
			var sp := p + Vector2(sx, sy - 9) * k
			h._fill(h._rrect(Rect2(sp + Vector2(-16, -3) * k, Vector2(32, 6) * k), 3 * k), Color("#FF8A3D"), OUT, 2.0)
			h._sparkle(sp + Vector2(-signf(cos(t * 1.7)) * 20, -10) * k, 6 * k, Color("#FFE27A"))
		_:
			return false
	return true
