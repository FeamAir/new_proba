extends RefCounted
## Значки новых украшений котика (0.15) — 2D, для карточек панели «Украсить» и запасного 2D-дома.
## Вызывает scripts/home.gd (_generic_decor): draw(h, id, p, k, t) -> true, если значок нарисован.
## h — рисовальщик home.gd (его ci и помощники _fill / _oval / _glow / _rrect / _sparkle / _paw).
## p — точка «земли» вещи (низ по центру), k — масштаб, t — время. Рисунок — в рамке x ±62, y от −100 до 0.

const OUT := Color("#1E1236")
const PuppyIcons := preload("res://scripts/decor_data/puppy_icons.gd")


static func _tri(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b, c])


static func _note(h, c: Vector2, k: float, col: Color) -> void:
	var ci: CanvasItem = h.ci
	h._oval(c, 6 * k, 4.5 * k, col, -0.3)
	ci.draw_line(c + Vector2(5, -1) * k, c + Vector2(5, -18) * k, col, 2.2 * k, true)
	ci.draw_line(c + Vector2(5, -18) * k, c + Vector2(11, -13) * k, col, 2.2 * k, true)


static func draw(h, id: String, p: Vector2, k: float, t: float) -> bool:
	var ci: CanvasItem = h.ci
	var w := 3.0
	match id:
		"kit_tea":
			h._fill(h._rrect(Rect2(p + Vector2(-60, -8) * k, Vector2(120, 8) * k), 4 * k), Color("#C98A5A"), OUT, w)
			h._oval(p + Vector2(-14, -36) * k, 28 * k, 24 * k, Color("#7FD8C8"), 0.0, OUT, w)
			ci.draw_line(p + Vector2(10, -38) * k, p + Vector2(30, -56) * k, OUT, 9 * k, true)
			ci.draw_line(p + Vector2(10, -38) * k, p + Vector2(30, -56) * k, Color("#7FD8C8"), 5 * k, true)
			h._oval(p + Vector2(-14, -62) * k, 10 * k, 5 * k, Color("#FFFFFF"), 0.0, OUT, 2.0)
			for i in 3:
				var u := fposmod(t * 0.5 + i * 0.33, 1.0)
				ci.draw_circle(p + Vector2(32 + sin(u * 6.0) * 4, -62 - u * 30) * k, (4 + u * 3) * k, Color(1, 1, 1, 0.7 * (1.0 - u)), true, -1.0, true)
			h._fill(h._rrect(Rect2(p + Vector2(28, -26) * k, Vector2(22, 18) * k), 5 * k), Color("#FF9EC6"), OUT, 2.0)
			h._oval(p + Vector2(-46, -12) * k, 11 * k, 4 * k, Color("#E8A860"), 0.0, OUT, 2.0)
		"kit_windowseat":
			h._fill(h._rrect(Rect2(p + Vector2(-60, -30) * k, Vector2(120, 26) * k), 12 * k), Color("#B8A2FF"), OUT, w)
			h._oval(p + Vector2(-34, -44) * k, 18 * k, 14 * k, Color("#FF9EC6"), -0.3, OUT, w)
			h._oval(p + Vector2(32, -44) * k, 18 * k, 14 * k, Color("#FFE27A"), 0.3, OUT, w)
			var sw := sin(t * 1.2) * 3.0
			h._fill(PackedVector2Array([p + Vector2(-4, -26) * k, p + Vector2(34, -26) * k, p + Vector2(34 + sw, 8) * k, p + Vector2(-4 + sw, 8) * k]), Color("#FF8FB1"), OUT, 2.0)
			for i in 2:
				ci.draw_line(p + Vector2(-3 + sw * 0.5, -14 + i * 12) * k, p + Vector2(33 + sw * 0.5, -14 + i * 12) * k, Color("#FFF1DC"), 3 * k, true)
		"kit_stove":
			h._glow(p + Vector2(0, -40) * k, 50 * k, Color("#FF9A4A"), 0.22)
			ci.draw_line(p + Vector2(-12, -70) * k, p + Vector2(-12, -104) * k, OUT, 13 * k, true)
			ci.draw_line(p + Vector2(-12, -70) * k, p + Vector2(-12, -104) * k, Color("#2E2844"), 9 * k, true)
			h._fill(h._rrect(Rect2(p + Vector2(-38, -78) * k, Vector2(76, 68) * k), 26 * k), Color("#3E3656"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-42, -82) * k, Vector2(84, 9) * k), 4 * k), Color("#E0B050"), OUT, 2.0)
			for sx in [-26.0, 26.0]:
				ci.draw_line(p + Vector2(sx, -10) * k, p + Vector2(sx, 0) * k, OUT, 5 * k, true)
			var f := 0.8 + 0.2 * sin(t * 9.0)
			h._oval(p + Vector2(0, -42) * k, 15 * k, 15 * k, Color("#E0B050"), 0.0, OUT, 2.0)
			h._oval(p + Vector2(0, -42) * k, 11 * k, 11 * k, Color(Color("#FF7A2A"), f))
			h._fill(_tri(p + Vector2(-6, -34) * k, p + Vector2(6, -34) * k, p + Vector2(0, -34 - 14 * f) * k), Color("#FFE08A"))
			for i in 2:
				var u := fposmod(t * 0.4 + i * 0.5, 1.0)
				ci.draw_circle(p + Vector2(-12 + sin(u * 5.0) * 5, -108 - u * 20) * k, (4 + u * 4) * k, Color(0.8, 0.78, 0.9, 0.6 * (1.0 - u)), true, -1.0, true)
		"kit_headphones":
			ci.draw_arc(p + Vector2(0, -50) * k, 34 * k, PI, TAU, 24, OUT, 13 * k, true)
			ci.draw_arc(p + Vector2(0, -50) * k, 34 * k, PI, TAU, 24, Color("#FF8FC8"), 8 * k, true)
			var g := 0.7 + 0.3 * sin(t * 2.5)
			for sx in [-1.0, 1.0]:
				var e := p + Vector2(sx * 20, -82) * k
				h._fill(_tri(e + Vector2(-11, 6) * k, e + Vector2(11, 6) * k, e + Vector2(sx * 4, -16) * k), Color("#FFFFFF"), OUT, 2.0)
				h._glow(e, 12 * k, Color("#FF6FB4"), 0.3 * g)
				h._fill(_tri(e + Vector2(-6, 4) * k, e + Vector2(6, 4) * k, e + Vector2(sx * 2, -9) * k), Color(Color("#FF6FB4"), g))
				var c := p + Vector2(sx * 34, -40) * k
				h._fill(h._rrect(Rect2(c + Vector2(-13, -22) * k, Vector2(26, 44) * k), 10 * k), Color("#FFFFFF"), OUT, w)
				h._oval(c, 8 * k, 13 * k, Color("#FF8FC8"))
		"kit_poster":
			h._fill(h._rrect(Rect2(p + Vector2(-38, -100) * k, Vector2(76, 96) * k), 4 * k), Color("#3A2066"), OUT, w)
			h._fill(PuppyIcons._bolt(p + Vector2(0, -52) * k, 72 * k), Color("#FFD34D"), OUT, 2.0)
			h._fill(PuppyIcons._star(p + Vector2(-22, -84) * k, 7 * k), Color("#FFFFFF"))
			h._fill(PuppyIcons._star(p + Vector2(24, -20) * k, 6 * k), Color("#FFFFFF"))
			for c in [Vector2(-36, -98), Vector2(36, -98)]:
				h._fill(h._rrect(Rect2(p + (c + Vector2(-8, -3)) * k, Vector2(16, 6) * k), 1 * k), Color("#F4EAD8"))
		"kit_mic":
			for sx in [-1.0, 0.0, 1.0]:
				ci.draw_line(p + Vector2(0, -16) * k, p + Vector2(sx * 24, 0) * k, OUT, 4 * k, true)
			ci.draw_line(p + Vector2(0, -16) * k, p + Vector2(0, -72) * k, Color("#D8DCEC"), 4 * k, true)
			var sw := sin(t * 1.4) * 3.0
			var m := p + Vector2(sw, -80) * k
			ci.draw_line(m, m + Vector2(10, -14) * k, OUT, 8 * k, true)
			h._oval(m + Vector2(14, -22) * k, 11 * k, 12 * k, Color("#D8DCEC"), 0.0, OUT, w)
			h._glow(m + Vector2(6, -8) * k, 8 * k, Color("#FF4FA3"), 0.4)
		"kit_beanbag":
			var b := 1.0 + 0.02 * sin(t * 1.2)
			h._fill(h._ell(p + Vector2(0, -32) * k, 56 * k * b, 32 * k / b), Color("#2A2440"), OUT, w)
			h._oval(p + Vector2(-4, -50) * k, 34 * k, 10 * k, Color("#3A3256"))
			h._fill(PuppyIcons._bolt(p + Vector2(4, -26) * k, 36 * k), Color("#FFD34D"))
			ci.draw_arc(p + Vector2(0, -32) * k, 54 * k, 0.4, PI - 0.4, 16, Color("#FF4FA3"), 3 * k, true)
		"kit_vinyl":
			h._fill(h._rrect(Rect2(p + Vector2(-56, -36) * k, Vector2(112, 32) * k), 6 * k), Color("#C98A5A"), OUT, w)
			h._oval(p + Vector2(-8, -40) * k, 40 * k, 12 * k, Color("#1E1836"), 0.0, OUT, 2.0)
			var a := t * 3.5
			h._oval(p + Vector2(-8, -40) * k, 12 * k, 4 * k, Color("#FF4FA3"))
			ci.draw_circle(p + Vector2(-8 + cos(a) * 26, -40 + sin(a) * 7) * k, 2 * k, Color("#6A6488"), true, -1.0, true)
			ci.draw_line(p + Vector2(46, -46) * k, p + Vector2(20, -38) * k, Color("#D8DCEC"), 3 * k, true)
			for i in 2:
				var u := fposmod(t * 0.4 + i * 0.5, 1.0)
				_note(h, p + Vector2(-24 + i * 30, -60 - u * 30) * k, k, Color([Color("#FF6FC8"), Color("#3FE0FF")][i], 1.0 - u))
		"kit_amp":
			h._fill(h._rrect(Rect2(p + Vector2(-46, -64) * k, Vector2(92, 64) * k), 6 * k), Color("#2A2440"), OUT, w)
			h._fill(h._rrect(Rect2(p + Vector2(-36, -98) * k, Vector2(72, 32) * k), 6 * k), Color("#2A2440"), OUT, w)
			var beat := 1.0 + 0.12 * exp(-fposmod(t * 2.0, 1.0) * 8.0)
			for sx in [-1.0, 1.0]:
				h._oval(p + Vector2(sx * 22, -32) * k, 17 * beat * k, 17 * beat * k, Color("#1E1836"), 0.0, Color("#D8DCEC"), 2.0)
				h._oval(p + Vector2(sx * 22, -32) * k, 7 * beat * k, 7 * beat * k, Color("#FF4FA3"))
			var lvl := int(exp(-fposmod(t * 2.0, 1.0) * 8.0) * 6.0 + 1.0)
			for i in 6:
				ci.draw_rect(Rect2(p + Vector2(-26 + i * 9, -84) * k, Vector2(7, 5) * k), [Color("#3FE0FF"), Color("#7AE08A"), Color("#FFE27A")][i / 2] if i < lvl else Color("#3A3256"))
		"kit_disco":
			ci.draw_line(p + Vector2(0, -100) * k, p + Vector2(0, -80) * k, Color("#E0B050"), 3 * k, true)
			h._glow(p + Vector2(0, -50) * k, 46 * k, Color("#D0B0FF"), 0.22)
			h._oval(p + Vector2(0, -50) * k, 30 * k, 30 * k, Color("#C8D0F0"), 0.0, OUT, w)
			for r in 5:
				for c in 6:
					var x := -25 + c * 10 + (5 if r % 2 == 1 else 0)
					var y := -70 + r * 10
					if Vector2(x, y + 50).length() < 26:
						var tw := pow(maxf(0.0, sin(t * 2.0 + r * 1.7 + c * 2.3)), 8.0)
						ci.draw_rect(Rect2(p + Vector2(x - 4, y - 4) * k, Vector2(8, 8) * k), Color("#FFFFFF").lerp(Color("#A0F0FF"), float((r + c) % 2)) * (0.75 + tw * 0.5))
			for i in 4:
				var a := t * 0.6 + i * PI / 2.0
				h._sparkle(p + Vector2(cos(a) * 50, -50 + sin(a) * 30) * k, 5 * k, Color([Color("#FF8FC8"), Color("#9FF0FF"), Color("#FFE27A"), Color("#B8A2FF")][i]))
		"kit_neon":
			var on := 1.0 if fposmod(t, 3.4) < 2.4 or fposmod(t * 8.0, 1.0) < 0.5 else 0.2
			h._glow(p + Vector2(0, -50) * k, 44 * k, Color("#FF4FA3"), 0.25 * on)
			var bp := PuppyIcons._bolt(p + Vector2(0, -50) * k, 92 * k)
			bp.append(bp[0])
			ci.draw_polyline(bp, Color(Color("#FF7FC8"), on), 5 * k, true)
			h._fill(PuppyIcons._star(p + Vector2(-34, -82) * k, 9 * k), Color("#FFE27A"))
			h._fill(PuppyIcons._star(p + Vector2(36, -26) * k, 7 * k), Color("#FFE27A"))
		"kit_guitar":
			var body := PackedVector2Array([Vector2(4, -56), Vector2(-26, -30), Vector2(-8, -30), Vector2(-22, 0), Vector2(26, -36), Vector2(8, -36), Vector2(22, -56)])
			for i in body.size():
				body[i] = p + body[i] * k
			ci.draw_line(p + Vector2(12, -50) * k, p + Vector2(12, -98) * k, OUT, 10 * k, true)
			ci.draw_line(p + Vector2(12, -50) * k, p + Vector2(12, -98) * k, Color("#C98A5A"), 6 * k, true)
			h._fill(body, Color("#FF4FA3"), OUT, w)
			for sx in [-1.0, 1.0]:
				h._fill(_tri(p + Vector2(12 + sx * 3, -98) * k, p + Vector2(12 + sx * 11, -98) * k, p + Vector2(12 + sx * 7, -108) * k), Color("#FF4FA3"), OUT, 1.5)
			var vib := sin(t * 40.0) * (1.0 if fposmod(t, 2.4) < 0.6 else 0.0)
			ci.draw_line(p + Vector2(10 + vib, -98) * k, p + Vector2(10, -26) * k, Color("#F4F7FF"), 1.2 * k, true)
			ci.draw_line(p + Vector2(14 - vib, -98) * k, p + Vector2(14, -26) * k, Color("#F4F7FF"), 1.2 * k, true)
		"kit_drums":
			h._glow(p + Vector2(0, -40) * k, 56 * k, Color("#FF4FA3"), 0.15)
			h._oval(p + Vector2(0, -32) * k, 30 * k, 30 * k, Color("#FF4FA3"), 0.0, OUT, w)
			h._oval(p + Vector2(0, -32) * k, 23 * k, 23 * k, Color("#FFF6EE"))
			h._paw(p + Vector2(0, -30) * k, 0.8 * k, Color("#FF4FA3"))
			for sx in [-1.0, 1.0]:
				h._fill(h._rrect(Rect2(p + Vector2(sx * 40 - 14, -54) * k, Vector2(28, 22) * k), 5 * k), Color("#FF4FA3"), OUT, w)
				h._oval(p + Vector2(sx * 40, -54) * k, 14 * k, 4 * k, Color("#FFF6EE"), 0.0, OUT, 2.0)
			var beat := exp(-fposmod(t * 2.0, 1.0) * 8.0)
			h._oval(p + Vector2(-46, -86) * k, 18 * k, 4 * k, Color("#F2C84A").lightened(0.4 * beat), 0.2 * sin(t * 6.0), OUT, 2.0)
			ci.draw_line(p + Vector2(-46, -86) * k, p + Vector2(-46, -60) * k, Color("#D8DCEC"), 2 * k, true)
			var st := -0.6 + 0.6 * beat
			ci.draw_line(p + Vector2(22, -84) * k, p + Vector2(22, -84) * k + Vector2(cos(st + 2.4), sin(st + 2.4)) * -30 * k, Color("#F2D2A0"), 3 * k, true)
		"kit_paints":
			h._fill(h._ell(p + Vector2(-6, -18) * k, 52 * k, 16 * k), Color("#E8C28A"), OUT, w)
			var cols := [Color("#FF4FA3"), Color("#3FE0FF"), Color("#FFD34D"), Color("#7AE08A"), Color("#B48CFF")]
			for i in 5:
				h._oval(p + Vector2(-36 + i * 15, -20 + (i % 2) * 5) * k, 6 * k, 4 * k, cols[i])
			h._fill(h._rrect(Rect2(p + Vector2(30, -52) * k, Vector2(22, 34) * k), 5 * k), Color(0.7, 0.9, 1.0, 0.7), OUT, 2.0)
			var sw := sin(t * 1.3) * 0.2
			for i in 3:
				var a := -0.3 + i * 0.3 + (sw if i == 1 else 0.0)
				var top := p + Vector2(41, -48) * k + Vector2(sin(a), -cos(a)) * 42 * k
				ci.draw_line(p + Vector2(41, -40) * k, top, Color(["#C98A5A", "#FF8FC8", "#5FC8FF"][i]), 3 * k, true)
				ci.draw_circle(top, 3 * k, cols[i], true, -1.0, true)
		"kit_vase":
			var v := PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(24, -18), Vector2(22, -36), Vector2(10, -52), Vector2(12, -62), Vector2(-12, -62), Vector2(-10, -52), Vector2(-22, -36), Vector2(-24, -18)])
			for i in v.size():
				v[i] = p + v[i].rotated(0.06) * k
			ci.draw_line(p + Vector2(0, -60) * k, p + Vector2(sin(t * 1.0) * 4, -98) * k, Color("#3F9A5E"), 3 * k, true)
			var fc := p + Vector2(sin(t * 1.0) * 4, -98) * k
			for i in 7:
				var a := TAU * i / 7.0
				h._oval(fc + Vector2(cos(a), sin(a)) * 7 * k, 5 * k, 3 * k, Color("#FFFFFF"), a, OUT, 1.0)
			ci.draw_circle(fc, 3.5 * k, Color("#FFB547"), true, -1.0, true)
			h._fill(v, Color("#D9774A"), OUT, w)
			ci.draw_line(p + Vector2(-22, -30) * k, p + Vector2(22, -28) * k, Color("#7FD8C8"), 3 * k, true)
		"kit_cranes":
			var rot := sin(t * 0.3) * 0.3
			ci.draw_line(p + Vector2(0, -100) * k, p + Vector2(0, -84) * k, Color("#F4EAD8"), 1.5 * k, true)
			ci.draw_line(p + Vector2(-50 * cos(rot), -84) * k, p + Vector2(50 * cos(rot), -84) * k, Color("#C98A5A"), 3 * k, true)
			var cols := [Color("#FF9EC6"), Color("#9FE8D8"), Color("#FFE27A")]
			for i in 3:
				var x := (-46 + i * 46) * cos(rot)
				var ln := 30.0 + 14.0 * (i % 2)
				ci.draw_line(p + Vector2(x, -84) * k, p + Vector2(x, -84 + ln) * k, Color("#F4EAD8"), 1.2 * k, true)
				var c := p + Vector2(x, -84 + ln + 8 + sin(t * 1.3 + i) * 2) * k
				h._fill(_tri(c + Vector2(-14, 0) * k, c + Vector2(14, 0) * k, c + Vector2(0, 8) * k), cols[i], OUT, 1.5)
				h._fill(_tri(c + Vector2(-3, 0) * k, c + Vector2(6, 0) * k, c + Vector2(-10, -14) * k), cols[i].darkened(0.1), OUT, 1.5)
				ci.draw_line(c + Vector2(10, 0) * k, c + Vector2(16, -10) * k, cols[i], 2 * k, true)
		"kit_plants":
			var pots := [[-38.0, Color("#F4F0FA")], [0.0, Color("#D9774A")], [38.0, Color("#FFD34D")]]
			for pp in pots:
				var x: float = pp[0]
				h._fill(PackedVector2Array([p + Vector2(x - 13, -26) * k, p + Vector2(x + 13, -26) * k, p + Vector2(x + 10, 0) * k, p + Vector2(x - 10, 0) * k]), pp[1], OUT, w)
			for i in 5:
				var a := -0.9 + i * 0.45 + sin(t * 1.1 + i) * 0.08
				h._oval(p + Vector2(0, -30) * k + Vector2(sin(a), -cos(a)) * 26 * k, 6 * k, 15 * k, Color("#4FB868"), a, OUT, 1.5)
			for i in 5:
				var a := TAU * i / 5.0
				h._oval(p + Vector2(-38, -32) * k + Vector2(cos(a), sin(a) * 0.6) * 8 * k, 6 * k, 5 * k, Color("#7FD0A0"), 0.0, OUT, 1.5)
			for i in 3:
				var vx := 30.0 + i * 8.0
				ci.draw_line(p + Vector2(38, -26) * k, p + Vector2(vx + 4, -4 + i * 6) * k, Color("#3F9A5E"), 2 * k, true)
				ci.draw_circle(p + Vector2(vx + 4, -4 + i * 6) * k, 3.5 * k, Color("#FF8FC8"), true, -1.0, true)
		"kit_starlamp":
			h._glow(p + Vector2(0, -50) * k, 46 * k, Color("#9A8CFF"), 0.25)
			h._fill(h._rrect(Rect2(p + Vector2(-26, -20) * k, Vector2(52, 20) * k), 6 * k), Color("#FFD34D"), OUT, w)
			h._oval(p + Vector2(0, -48) * k, 30 * k, 30 * k, Color("#3A2A80"), 0.0, OUT, w)
			for i in 5:
				var a := t * 0.3 + TAU * i / 5.0
				if cos(a) > -0.2:
					h._fill(PuppyIcons._star(p + Vector2(sin(a) * 20, -48 + (i % 2) * 10 - 5) * k, 5 * k), Color("#FFE9A0"))
			for i in 3:
				h._sparkle(p + Vector2(-44 + i * 44, -96 + (i % 2) * 8) * k, (4 + sin(t * 2.0 + i)) * k, Color("#FFE9A0"))
		"kit_easel":
			for sx in [-1.0, 1.0]:
				ci.draw_line(p + Vector2(sx * 30, 0) * k, p + Vector2(sx * 6, -104) * k, Color("#C98A5A"), 4 * k, true)
			h._fill(h._rrect(Rect2(p + Vector2(-38, -90) * k, Vector2(76, 58) * k), 3 * k), Color("#F4EAD8"), OUT, w)
			var u := fposmod(t / 7.0, 1.0) * 1.35
			var pics := [Color("#6FB8FF"), Color("#FFB86A"), Color("#5A4AA0")]
			var pic := int(fposmod(floorf(t / 7.0), 3.0))
			var fillw := clampf(u, 0.0, 1.0) * 68.0
			ci.draw_rect(Rect2(p + Vector2(-34, -86) * k, Vector2(fillw, 50) * k), pics[pic])
			if pic == 0 and u > 0.6:
				h._oval(p + Vector2(-6, -62) * k, 12 * k, 8 * k, Color("#FF8A3D"))
			elif pic == 1 and u > 0.6:
				h._oval(p + Vector2(0, -60) * k, 14 * k, 12 * k, Color("#FFE0B0"))
			elif pic == 2 and u > 0.6:
				ci.draw_circle(p + Vector2(18, -76) * k, 6 * k, Color("#FFF2B0"), true, -1.0, true)
			ci.draw_line(p + Vector2(-40, -30) * k, p + Vector2(40, -30) * k, Color("#C98A5A"), 5 * k, true)
			ci.draw_line(p + Vector2(-34 + fillw, -60) * k, p + Vector2(-20 + fillw, -80) * k, Color("#FF8FC8"), 3 * k, true)
		"kit_stainedglass":
			var c := p + Vector2(0, -56) * k
			for i in 3:
				var a := 0.15 + i * 0.1
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-16 + i * 16, 10) * k, c + Vector2(-4 + i * 16, 10) * k, c + Vector2(-40 + i * 40 + 14, 56) * k, c + Vector2(-40 + i * 40 - 14, 56) * k]),
					Color.from_hsv(fposmod(t * 0.03 + i * 0.33, 1.0), 0.5, 1.0, a))
			h._oval(c, 46 * k, 46 * k, Color("#E0B050"), 0.0, OUT, w)
			for s in 8:
				var a0 := TAU * s / 8.0
				var a1 := TAU * (s + 1) / 8.0
				for ring in 2:
					var r0 := 8.0 if ring == 0 else 22.0
					var r1 := 22.0 if ring == 0 else 40.0
					var col := Color.from_hsv(fposmod(s * 0.125 + ring * 0.37 + t * 0.03, 1.0), 0.6, 1.0)
					var poly := PackedVector2Array()
					for j in 5:
						var a := lerpf(a0, a1, j / 4.0)
						poly.append(c + Vector2(cos(a), sin(a)) * r0 * k)
					for j in 5:
						var a := lerpf(a1, a0, j / 4.0)
						poly.append(c + Vector2(cos(a), sin(a)) * r1 * k)
					h._fill(poly, col, OUT, 1.5)
			h._oval(c, 8 * k, 8 * k, Color("#FFD34D"), 0.0, OUT, 1.5)
		_:
			return false
	return true
