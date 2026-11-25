extends RefCounted
## Cascado 0.12: вещи для слотов голова / глаза / шея / спина, нарисованные в 0.12 (общие помощники
## для гардеробов героев: шарфы, плащи, звёзды). 0.12b: общих вещей больше нет — эти рисунки берут
## вещи конкретных героев через поле draw (scripts/meta.gd): коралловая тиара, маска ныряльщика,
## жемчуг, плащ-волна — аксолотль; звёздный шарф, астролябия, лорнет — совёнок; ранец — щенок;
## маска и бальная накидка — котик.
## Рисуют через помощников героя h (scripts/hero.gd): h._ball, h._shape, h._line, h._glow...
## Координаты — как у старых вещей: головные уборы в «голове шириной 100» (h._head_T, макушка — 0,0),
## очки — от центров глаз (a.eye_l / a.eye_r, a.eye_rad), шея — a.neck / a.neck_w, спина — a.back / a.back_w.
## Вещь садится на героя по его точкам крепления (hero.gd, _anchors).
## Стиль «конфетный»: объёмные сетки (три тона + блик), насыщенные цвета, мелкие блёстки.

const GOLD := Color("#FFC83A")
const GOLD_D := Color("#B8771A")
const SILVER := Color("#E4E9FA")


static func hs(i: float, k := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


## Цвет с округлением (для кэша сеток свечения при переливах)
static func q(c: Color) -> Color:
	return Color(snappedf(c.r, 0.06), snappedf(c.g, 0.06), snappedf(c.b, 0.06), c.a)


static func hsv(hh: float, s: float, v: float, a := 1.0) -> Color:
	return Color.from_hsv(fposmod(snappedf(hh, 1.0 / 36.0), 1.0), s, v, a)


## Полоса между двумя контурами с одинаковым числом точек (рамка с «дыркой»: очки, маска)
static func band(h, outer: PackedVector2Array, inner: PackedVector2Array, co: Color, ci_: Color) -> void:
	var n := outer.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		pts.append(outer[i])
		cols.append(co)
		pts.append(inner[i])
		cols.append(ci_)
	var idx := PackedInt32Array()
	for i in n:
		var a0 := i * 2
		var b0 := ((i + 1) % n) * 2
		idx.append_array([a0, a0 + 1, b0 + 1, a0, b0 + 1, b0])
	RenderingServer.canvas_item_add_triangle_array(h._rid, idx, h._T * pts, cols)


static func star_pts(c: Vector2, ro: float, ri: float, n := 5, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var r := ro if i % 2 == 0 else ri
		pts.append(c + Vector2(0, -r).rotated(rot + i * PI / n))
	return pts


static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var o := p.duplicate()
	o.append(p[0])
	return o


## Серповидная луна (центр c, радиус r, поворот rot)
static func crescent(c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var ang := lerpf(-PI * 0.78, PI * 0.78, i / 16.0) + PI
		pts.append(c + Vector2(cos(ang), sin(ang)).rotated(rot) * r)
	for i in 17:
		var ang := lerpf(PI * 0.62, -PI * 0.62, i / 16.0) + PI
		pts.append(c + (Vector2(cos(ang), sin(ang)) * r * 0.78 + Vector2(-r * 0.38, 0)).rotated(rot))
	return pts


static func dispatch_head(h, id: String, a: Dictionary, t: float) -> bool:
	match id:
		"coral_tiara": coral_tiara(h, a, t)
		_: return false
	return true


static func dispatch_eyes(h, id: String, a: Dictionary, t: float) -> bool:
	match id:
		"dive_mask": dive_mask(h, a, t)
		"masquerade": masquerade(h, a, t)
		"star_lorgnette": star_lorgnette(h, a, t)
		_: return false
	return true


static func dispatch_neck(h, id: String, a: Dictionary, t: float) -> bool:
	match id:
		"pearl_necklace": pearl_necklace(h, a, t)
		"comet_scarf": comet_scarf(h, a, t)
		"star_compass": star_compass(h, a, t)
		_: return false
	return true


static func dispatch_back(h, id: String, a: Dictionary, t: float, behind: bool) -> bool:
	match id:
		"fin_cape": fin_cape(h, a, t, behind)
		"ball_cloak": ball_cloak(h, a, t, behind)
		"rocket_pack": rocket_pack(h, a, t, behind)
		_: return false
	return true


# ==================== Голова ====================

## Коралловая тиара: ветвистые кораллы, жемчуг и аквамарин
static func coral_tiara(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var ring := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 50, 8 + sin(ang) * 12))
	h._line(ring, Color("#D9894A"), 7.0)
	h._line(ring, Color("#FFD9A0"), 3.0)
	var xs := [-38.0, -19.0, 0.0, 19.0, 38.0]
	var hts := [20.0, 30.0, 40.0, 30.0, 20.0]
	var cols := [Color("#FF7A6B"), Color("#FF5E8A"), Color("#FF7A6B"), Color("#FF5E8A"), Color("#FF7A6B")]
	for i in 5:
		var x: float = xs[i]
		var base := Vector2(x, 8 + sin(PI + PI * (x + 50.0) / 100.0) * 12)
		var top := base + Vector2(x * 0.12, -hts[i])
		var c: Color = cols[i]
		h._line(PackedVector2Array([base, base.lerp(top, 0.5) + Vector2(2, 0), top]), c.darkened(0.15), 6.0)
		var b1 := base.lerp(top, 0.45)
		var e1 := b1 + Vector2(-9, -hts[i] * 0.35)
		var e2 := b1 + Vector2(9, -hts[i] * 0.3)
		h._line(PackedVector2Array([b1, e1]), c, 4.5)
		h._line(PackedVector2Array([b1 + Vector2(0, 3), e2]), c, 4.5)
		for e in [top, e1, e2]:
			h._ball(e, 4.2, 4.2, c.lerp(Color("#FFD0C8"), 0.45), 0.0, 1.0, 0.7, 1.0)
	# жемчуг по ободку
	for i in range(1, 16, 2):
		h._ball(ring[i] + Vector2(0, 2), 3.6, 3.6, Color("#FFF6FC"), 0.0, 1.0, 1.0, 0.8)
	h._gem(Vector2(0, 4), 9.0, Color("#3FE0D0"))
	var tw := 0.5 + 0.5 * sin(t * 3.5)
	h._sparkle(Vector2(-28, -22), 3 + 3 * tw, Color(1, 1, 1, 0.9))
	h._sparkle(Vector2(6, -46), 3 + 3 * (1.0 - tw), Color(1, 1, 1, 0.85))
	h._T = Transform2D.IDENTITY


# ==================== Глаза ====================

## Маска для ныряния: оранжевая рамка, стекло, ремешок и трубка
static func dive_mask(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var half: float = a.eye_l.distance_to(a.eye_r) / 2.0 + r * 1.2
	h._T = Transform2D(a.tilt, mid)
	# ремешок
	var tw: float = a.temple
	h._line(PackedVector2Array([Vector2(-tw * 1.02, -r * 0.1), Vector2(-half, -r * 0.15)]), Color("#1E9E95"), r * 0.5)
	h._line(PackedVector2Array([Vector2(half, -r * 0.15), Vector2(tw * 1.02, -r * 0.1)]), Color("#1E9E95"), r * 0.5)
	var outer: PackedVector2Array = h._rrect(Rect2(-half, -r * 1.25, half * 2, r * 2.4), r * 0.95)
	var inner: PackedVector2Array = h._rrect(Rect2(-half + r * 0.3, -r * 0.98, half * 2 - r * 0.6, r * 1.86), r * 0.7)
	h._vgrad(inner, Color(0.55, 0.95, 1.0, 0.28), Color(0.3, 0.6, 1.0, 0.14), false)
	band(h, outer, inner, Color("#E8611E"), Color("#FF9A4A"))
	h._line(closed(outer), Color("#A8400E"), r * 0.08)
	h._line(closed(inner), Color("#FFD0A0", 0.8), r * 0.06)
	# носик маски
	h._ball(Vector2(0, r * 1.1), r * 0.42, r * 0.32, Color("#FF8A3D"), 0.0, 1.1, 0.5, 1.0)
	# блики на стекле
	h._line(PackedVector2Array([Vector2(-half + r * 0.7, r * 0.2), Vector2(-half + r * 1.2, -r * 0.6)]), Color(1, 1, 1, 0.6), r * 0.16)
	h._line(PackedVector2Array([Vector2(-half + r * 1.5, r * 0.3), Vector2(-half + r * 1.75, -r * 0.1)]), Color(1, 1, 1, 0.4), r * 0.09)
	# трубка
	var sx := half + r * 0.2
	var tube := PackedVector2Array([Vector2(sx - r * 0.3, r * 0.9), Vector2(sx + r * 0.35, r * 0.7), Vector2(sx + r * 0.55, -r * 0.4), Vector2(sx + r * 0.55, -r * 2.6), Vector2(sx + r * 0.3, -r * 3.0)])
	h._line(tube, Color("#C99500"), r * 0.42)
	h._line(tube, Color("#FFD23C"), r * 0.3)
	h._line(PackedVector2Array([tube[2] + Vector2(-r * 0.07, 0), tube[3] + Vector2(-r * 0.07, 0)]), Color(1, 1, 1, 0.55), r * 0.08)
	h._ball(tube[4] + Vector2(0, -r * 0.1), r * 0.26, r * 0.22, Color("#FF4F93"), 0.0, 1.0, 0.7, 1.0)
	var bub := fposmod(t * 0.7, 1.0)
	h._arc(tube[4] + Vector2(r * 0.1, -r * (0.5 + bub * 1.6)), r * 0.16, r * 0.16, 0, TAU, Color(0.8, 0.97, 1.0, 0.7 * (1.0 - bub)), r * 0.05, 10)
	h._T = Transform2D.IDENTITY


## Маскарадная маска: фиолетовые «крылья» вокруг глаз, золотая кайма, пёрышки
static func masquerade(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var hd: float = a.eye_l.distance_to(a.eye_r) / 2.0
	h._T = Transform2D(a.tilt, mid)
	# перемычка
	var br := PackedVector2Array([Vector2(-hd + r * 0.8, -r * 0.55), Vector2(0, -r * 0.75), Vector2(hd - r * 0.8, -r * 0.55), Vector2(hd - r * 0.8, r * 0.1), Vector2(0, -r * 0.1), Vector2(-hd + r * 0.8, r * 0.1)])
	h._vgrad(br, Color("#8A3FE0"), Color("#5A1FA8"))
	for sx in [-1.0, 1.0]:
		var c := Vector2(sx * hd, 0)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 36:
			var ang := TAU * i / 36.0
			var d := Vector2(cos(ang), sin(ang))
			var out_k := maxf(0.0, d.x * sx * 0.8 - d.y * 0.6)
			var ro := r * (1.42 + 0.7 * pow(out_k, 3.0)) * (0.85 if d.y > 0 else 1.0)
			outer.append(c + Vector2(d.x * ro * 1.08, d.y * ro * 0.86))
			inner.append(c + Vector2(d.x * r * 0.92, d.y * r * 0.78))
		band(h, outer, inner, Color("#5A1FA8"), Color("#A65CFF"))
		var oc := closed(outer)
		h._line(oc, GOLD_D, r * 0.13)
		h._line(oc, GOLD, r * 0.07)
		var ic := closed(inner)
		h._line(ic, Color("#FFE38A"), r * 0.06)
		# горошины-стразы
		for k in 4:
			var p: Vector2 = outer[(4 + k * 3 if sx > 0 else 32 - k * 3) % 36].lerp(c, 0.18)
			h._dot(p, r * 0.08, Color("#FFF2FB"))
	# пёрышки у правого края
	var fp := Vector2(hd + r * 1.3, -r * 0.9)
	var sway := sin(t * 2.0) * 0.08
	for k in 3:
		var rot := -0.5 + k * 0.35 + sway
		var fc := fp + Vector2(0, -r * 0.9).rotated(rot)
		h._ball(fc, r * 0.32, r * 0.95, [Color("#FF5FA8"), Color("#FFD23C"), Color("#3FE0D0")][k], rot, 1.3, 0.5, 1.0)
		h._line(PackedVector2Array([fp, fp + Vector2(0, -r * 1.7).rotated(rot)]), Color(1, 1, 1, 0.55), r * 0.05)
	h._gem(fp, r * 0.28, Color("#FF3B6B"))
	h._gem(Vector2(0, -r * 0.42), r * 0.22, Color("#3BB8FF"))
	h._T = Transform2D.IDENTITY


## Звёздный лорнет: две линзы в золотой оправе на ручке, звёзды мерцают
static func star_lorgnette(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.08
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r * 0.95, 0).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r * 0.95, 0).rotated(a.tilt)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.25).rotated(a.tilt), rr]), GOLD_D, r * 0.2)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.25).rotated(a.tilt), rr]), GOLD, r * 0.11)
	# ручка от левой линзы вниз-влево
	var hs0: Vector2 = a.eye_l + Vector2(-r * 0.7, r * 0.7).rotated(a.tilt)
	var he: Vector2 = hs0 + Vector2(-r * 0.5, r * 2.4).rotated(a.tilt)
	h._line(PackedVector2Array([hs0, he]), GOLD_D, r * 0.26)
	h._line(PackedVector2Array([hs0, he]), GOLD, r * 0.16)
	h._line(PackedVector2Array([hs0 + Vector2(-r * 0.04, r * 0.2), he + Vector2(-r * 0.04, -r * 0.3)]), Color(1, 1, 0.85, 0.7), r * 0.05)
	h._ball(he, r * 0.2, r * 0.2, Color("#FFF2FB"), 0.0, 1.0, 1.0, 1.0)
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._T = Transform2D(a.tilt, e)
		h._vgrad(h._ell(Vector2.ZERO, r, r, 0.0, 26), Color(0.55, 0.6, 1.0, 0.26), Color(0.85, 0.5, 1.0, 0.2), false)
		# звёздочки внутри стекла плывут
		for k in 3:
			var ph := fposmod(t * 0.25 + k * 0.33 + i * 0.17, 1.0)
			var p := Vector2(lerpf(-r * 0.6, r * 0.6, ph), -r * 0.4 + k * r * 0.35)
			h._sparkle(p, r * 0.1 * sin(ph * PI), Color(1, 1, 1, 0.8 * sin(ph * PI)))
		h._arc(Vector2.ZERO, r, r, 0, TAU, GOLD_D, r * 0.28, 30)
		h._arc(Vector2.ZERO, r, r, 0, TAU, GOLD, r * 0.16, 30)
		h._arc(Vector2.ZERO, r, r, 1.05 * PI, 1.5 * PI, Color("#FFF6C8"), r * 0.07, 10)
		# звёзды на оправе
		for k in 3:
			var ang := -PI / 2.0 + (k - 1) * 0.6
			var sp := Vector2(cos(ang), sin(ang)) * r * 1.12
			var tw := 0.5 + 0.5 * sin(t * 4.0 + k * 2.0 + i)
			h._fill(star_pts(sp, r * (0.2 + 0.06 * tw), r * 0.09, 5, 0.0), Color("#FFE680"))
			h._dot(sp, r * 0.05, Color(1, 1, 1, 0.6 + 0.4 * tw))
	h._T = Transform2D.IDENTITY


# ==================== Шея ====================

## Кривая вокруг шеи (как у шарфа): точки от левого края к правому
static func _neck_curve(a: Dictionary, n: int, dy := 0.0, wk := 1.0, sag := 0.45) -> PackedVector2Array:
	var w: float = a.neck_w * wk
	var hh := w * 0.2
	var pts := PackedVector2Array()
	for i in n:
		var s := float(i) / (n - 1)
		pts.append(a.neck + Vector2((s - 0.5) * w, dy + (1.0 - pow(2.0 * s - 1.0, 2)) * hh * sag))
	return pts


## Жемчужное ожерелье: две нити жемчуга и розовая жемчужина в золотой «шапочке»
static func pearl_necklace(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w * 0.82
	var n: Vector2 = a.neck
	for s in 2:
		var cnt := 15 + s * 2
		var pts := PackedVector2Array()
		for i in cnt:
			var ang := lerpf(0.0, PI, i / float(cnt - 1))
			pts.append(n + Vector2(cos(ang) * w * (0.5 + s * 0.03), -8 + sin(ang) * w * (0.16 + s * 0.09)))
		for i in cnt:
			var rr := 4.4 if s == 0 else 4.0
			h._ball(pts[i], rr, rr, Color("#FFF6FA") if (i + s) % 3 != 0 else Color("#FFE4F0"), 0.0, 1.0, 1.0, 0.8)
	var pc := n + Vector2(0, -8 + w * 0.25 + 7)
	h._glow(pc, 16, 16, Color(1.0, 0.8, 0.9, 0.35))
	h._ball(pc, 8.5, 8.5, Color("#FFC2DA"), 0.0, 1.0, 1.0, 1.2)
	h._T = Transform2D(0.0, pc + Vector2(0, -8))
	h._shape(["pearl_cap"], PackedVector2Array([Vector2(-6, 0), Vector2(-3, -5), Vector2(3, -5), Vector2(6, 0), Vector2(0, 3)]), Vector2(0, -1), GOLD, 1.0, 0.9, 1.0)
	h._T = Transform2D.IDENTITY
	h._sparkle(pc + Vector2(-4, -3), 2.5 + 2.0 * sin(t * 4.0), Color.WHITE)


## Шарф-комета: тёмно-синий шарф со звёздами, конец развевается хвостом кометы
static func comet_scarf(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var hh := w * 0.18
	var top := _neck_curve(a, 13, -hh * 0.5)
	var bot := _neck_curve(a, 13, hh * 0.5, 0.96)
	# хвост кометы: от узла справа вниз-вправо, волнуется
	var knot: Vector2 = a.neck + Vector2(w * 0.22, hh * 0.6)
	var mid := PackedVector2Array()
	var n := 12
	for i in n:
		var s := i / float(n - 1)
		mid.append(knot + Vector2(s * w * 0.42, s * w * 0.42) + Vector2(sin(t * 4.0 - s * 5.0), -cos(t * 4.0 - s * 5.0) * 0.4) * s * hh * 0.7)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var s := i / float(n - 1)
		var tg := (mid[mini(i + 1, n - 1)] - mid[maxi(i - 1, 0)]).normalized()
		var wd := hh * 0.75 * (1.0 - s * 0.85)
		var c := Color("#FFF2A0").lerp(Color("#FF6FB0"), s).lerp(Color("#7A6CFF"), maxf(0.0, s - 0.5) * 1.6)
		pts.append(mid[i] + tg.orthogonal() * wd)
		cols.append(Color(c, 0.95 - s * 0.85))
		pts.append(mid[i] - tg.orthogonal() * wd)
		cols.append(Color(c, 0.95 - s * 0.85))
	var idx := PackedInt32Array()
	for i in n - 1:
		var a0 := i * 2
		idx.append_array([a0, a0 + 1, a0 + 3, a0, a0 + 3, a0 + 2])
	RenderingServer.canvas_item_add_triangle_array(h._rid, idx, pts, cols)
	for i in range(2, n, 3):
		h._sparkle(mid[i], hh * 0.22 * (0.6 + 0.4 * sin(t * 6.0 + i)), Color(1, 1, 1, 0.9 - i * 0.06))
	# основная полоса
	for i in 12:
		ci_quad(h, PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]]), Color("#2B3A9F") if i % 2 == 0 else Color("#3346B8"))
	_tube_shade(h, top, bot)
	for i in range(1, 12, 2):
		var c := top[i].lerp(bot[i], 0.5)
		var tw := 0.5 + 0.5 * sin(t * 3.0 + i)
		h._fill(star_pts(c, hh * 0.22, hh * 0.09, 5, 0.2), Color("#FFE680").lerp(Color.WHITE, tw * 0.5))
	var bandl := top.duplicate()
	var rb := bot.duplicate()
	rb.reverse()
	bandl.append_array(rb)
	bandl.append(top[0])
	h.ci.draw_polyline(bandl, Color(0.1, 0.05, 0.3, 0.55), 1.6, true)
	# голова кометы
	h._glow(knot, hh * 1.4, hh * 1.4, Color(1.0, 0.95, 0.6, 0.5))
	h._ball(knot, hh * 0.45, hh * 0.45, Color("#FFF6C0"), 0.0, 1.0, 1.0, 1.0)


static func ci_quad(h, q: PackedVector2Array, c: Color) -> void:
	h.ci.draw_colored_polygon(q, c)


## Объём «трубки» шарфа: светлый верх, тёмный низ
static func _tube_shade(h, top: PackedVector2Array, bot: PackedVector2Array) -> void:
	var sp := PackedVector2Array()
	var sc := PackedColorArray()
	var n := top.size()
	for i in n:
		sp.append(top[i])
		sc.append(Color(1, 1, 1, 0.36))
		sp.append(top[i].lerp(bot[i], 0.4))
		sc.append(Color(1, 1, 1, 0.0))
		sp.append(bot[i])
		sc.append(Color(0.1, 0.0, 0.3, 0.45))
	var idx := PackedInt32Array()
	for i in n - 1:
		for j in 2:
			var a0 := i * 3 + j
			var b0 := a0 + 3
			idx.append_array([a0, b0, b0 + 1, a0, b0 + 1, a0 + 1])
	RenderingServer.canvas_item_add_triangle_array(h._rid, idx, sp, sc)


## Звёздный компас: латунный медальон на шнурке, стрелка-звёздочка крутится
static func star_compass(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var n: Vector2 = a.neck
	var r := maxf(w * 0.15, 16.0)
	var pc := n + Vector2(0, w * 0.19)
	var cord := PackedVector2Array()
	for i in 13:
		var ang := lerpf(0.0, PI, i / 12.0)
		cord.append(n + Vector2(cos(ang) * w * 0.42, -6 + sin(ang) * w * 0.14))
	h.ci.draw_polyline(cord, Color("#5A3A1E"), 3.0, true)
	h.ci.draw_polyline(cord, Color("#B07A40"), 1.4, true)
	h._ball(pc + Vector2(0, -r * 1.08), r * 0.26, r * 0.2, GOLD, 0.0, 1.0, 0.9, 1.0)
	h._ball(pc, r * 1.12, r * 1.12, Color("#D99A26"), 0.0, 1.0, 0.85)
	h._T = Transform2D(0.0, pc)
	h._vgrad(h._ell(Vector2.ZERO, r * 0.86, r * 0.86, 0.0, 28), Color("#FFF8E6"), Color("#F2DDB0"))
	for k in 8:
		var ang := k * TAU / 8.0
		var d := Vector2(cos(ang), sin(ang))
		h._line(PackedVector2Array([d * r * 0.62, d * r * (0.78 if k % 2 == 0 else 0.72)]), Color("#7A4A12", 0.8), r * (0.07 if k % 2 == 0 else 0.04))
	var ang := t * 1.3 + sin(t * 2.7) * 0.5
	h._fill(star_pts(Vector2.ZERO, r * 0.62, r * 0.14, 4, ang), Color("#FF4F7A"))
	h._fill(star_pts(Vector2.ZERO, r * 0.62, r * 0.14, 4, ang).slice(0, 4) + PackedVector2Array([Vector2.ZERO]), Color("#FF9AB8"))
	h._fill(star_pts(Vector2.ZERO, r * 0.34, r * 0.1, 4, ang + PI / 4.0), Color("#FFD23C"))
	h._dot(Vector2.ZERO, r * 0.1, Color("#7A4A12"))
	h._arc(Vector2.ZERO, r * 0.8, r * 0.8, 1.05 * PI, 1.5 * PI, Color(1, 1, 1, 0.75), r * 0.12, 10)
	h._T = Transform2D.IDENTITY
	h._sparkle(pc + Vector2(r * 0.75, -r * 0.75), r * (0.22 + 0.12 * sin(t * 4.0)), Color.WHITE)


# ==================== Спина ====================

## Плащ-основа: верх у шеи, широкий низ с краем hem (функция края — callable(s) -> смещение по y)
static func _cape_pts(a: Dictionary, wk: float, lenk: float, hem_fn: Callable, n := 17) -> Array:
	var w: float = a.back_w
	var b: Vector2 = a.back
	var pts := PackedVector2Array([b + Vector2(-w * 0.34, -w * 0.36), b + Vector2(-w * 0.52 * wk, -w * 0.18)])
	var hem := PackedVector2Array()
	for i in n:
		var s := i / float(n - 1)
		var v := Vector2(b.x + lerpf(-w * 0.68, w * 0.68, s) * wk, b.y + w * lenk + hem_fn.call(s) - absf(s - 0.5) * 14.0)
		pts.append(v)
		hem.append(v)
	pts.append(b + Vector2(w * 0.52 * wk, -w * 0.18))
	pts.append(b + Vector2(w * 0.34, -w * 0.36))
	return [pts, hem]


static func _cape_fill(h, a: Dictionary, pts: PackedVector2Array, c0: Color, c1: Color) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	var cols := PackedColorArray()
	for v in pts:
		var ty := clampf((v.y - b.y + w * 0.5) / (w * 1.1), 0.0, 1.0)
		var tx := clampf((v.x - b.x) / (w * 1.3) + 0.5, 0.0, 1.0)
		cols.append(c0.lerp(c1, ty * 0.8 + tx * 0.25))
	h.ci.draw_polyline(closed(pts), Color(0.08, 0.03, 0.2, 0.6), 4.0, true)
	h.ci.draw_polygon(pts, cols)


## Плащ-плавник: бирюзовый, волнистый край колышется, лучики-перепонки
static func fin_cape(h, a: Dictionary, t: float, behind: bool) -> void:
	if not behind:
		var n: Vector2 = a.neck + Vector2(0, 6)
		h._T = Transform2D(0.0, n)
		var sh := PackedVector2Array([Vector2(-4, 8), Vector2(-7, 4)])
		for i in 13:
			var ang := lerpf(PI * 1.12, PI * 1.88, i / 12.0)
			sh.append(Vector2(cos(ang) * 13, 6 + sin(ang) * 13))
		sh.append_array([Vector2(7, 4), Vector2(4, 8)])
		h._shape(["fin_clasp"], sh, Vector2(0, -1), Color("#FFB3A7"), 1.1, 0.7, 1.2)
		for k in 5:
			var ang := lerpf(PI * 1.2, PI * 1.8, k / 4.0)
			h._line(PackedVector2Array([Vector2(0, 6), Vector2(cos(ang) * 11, 6 + sin(ang) * 11)]), Color("#E06A6A", 0.6), 1.4)
		h._T = Transform2D.IDENTITY
		return
	var w: float = a.back_w
	var res := _cape_pts(a, 1.05, 0.6, func(s: float) -> float: return sin(s * TAU * 2.5 + t * 3.0) * 9.0 + sin(s * TAU * 5.0 - t * 4.0) * 3.0)
	_cape_fill(h, a, res[0], Color("#3FE6D2"), Color("#0E6E86"))
	var hem: PackedVector2Array = res[1]
	var b: Vector2 = a.back
	# лучики-перепонки
	for i in range(1, hem.size() - 1, 2):
		var hp: Vector2 = hem[i]
		h.ci.draw_line(Vector2(lerpf(b.x, hp.x, 0.55), b.y - w * 0.1), hp, Color(0.85, 1.0, 1.0, 0.25), 2.5, true)
	h.ci.draw_polyline(hem, Color("#0A5A6E"), 7.0, true)
	h.ci.draw_polyline(hem, Color("#A8FFF0"), 3.5, true)
	# чешуйки-блёстки
	for i in 6:
		var p := b + Vector2((hs(i, 1) - 0.5) * w * 1.1, w * (0.05 + hs(i, 2) * 0.45))
		var tw := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
		h._sparkle(p, w * 0.03 * (0.6 + tw), Color(0.85, 1.0, 1.0, 0.5 + 0.5 * tw))


## Бальный плащ: бархатный, со стоячим воротником и серебряной каймой
static func ball_cloak(h, a: Dictionary, t: float, behind: bool) -> void:
	if not behind:
		var n: Vector2 = a.neck + Vector2(0, 6)
		h._glow(n, 16, 16, Color(0.8, 0.85, 1.0, 0.3))
		h._T = Transform2D(0.0, n)
		h._shape(["cloak_moon"], crescent(Vector2.ZERO, 10.0, 0.4), Vector2(-4, -1), SILVER, 1.0, 0.95, 1.2)
		h._T = Transform2D.IDENTITY
		h._ball(n + Vector2(5, -3), 3, 3, Color("#B46CFF"), 0.0, 1.0, 0.95, 0.8)
		return
	var w: float = a.back_w
	var b: Vector2 = a.back
	# стоячий воротник-веер за головой
	var col := PackedVector2Array()
	for i in 13:
		var ang := lerpf(PI * 1.08, PI * 1.92, i / 12.0)
		col.append(b + Vector2(0, -w * 0.3) + Vector2(cos(ang) * w * 0.5, sin(ang) * w * 0.3))
	col.append(b + Vector2(w * 0.3, -w * 0.28))
	col.append(b + Vector2(-w * 0.3, -w * 0.28))
	var cc := PackedColorArray()
	for v in col:
		cc.append(Color("#C8A0FF").lerp(Color("#5A2A9E"), clampf((v.y - (b.y - w * 0.62)) / (w * 0.35), 0.0, 1.0)))
	h.ci.draw_polygon(col, cc)
	h.ci.draw_polyline(col.slice(0, 13), SILVER, 3.0, true)
	var res := _cape_pts(a, 1.08, 0.6, func(s: float) -> float: return sin(s * TAU * 2.0 + t * 1.6) * 5.0)
	_cape_fill(h, a, res[0], Color("#7A3FC0"), Color("#25103F"))
	var hem: PackedVector2Array = res[1]
	for i in [4, 8, 12]:
		var hp: Vector2 = hem[i]
		h.ci.draw_line(Vector2(hp.x * 0.8 + b.x * 0.2, b.y - w * 0.05), hp + Vector2(0, -6), Color(0.05, 0.0, 0.15, 0.3), 7.0, true)
	h.ci.draw_polyline(hem, Color("#6A72A0"), 7.0, true)
	h.ci.draw_polyline(hem, SILVER, 3.5, true)
	for i in range(0, hem.size(), 4):
		h._ball(hem[i] + Vector2(0, 2), 3.2, 3.2, Color("#F4F6FF"), 0.0, 1.0, 1.0, 0.8)


## Ракетный ранец: две ракеты по бокам, из сопел мерцает пламя
static func rocket_pack(h, a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if not behind:
		var k := w / 184.0
		for sx in [-1.0, 1.0]:
			var top: Vector2 = b + Vector2(sx * 62, -8) * k
			var bot: Vector2 = b + Vector2(sx * 52, 74) * k
			if a.kind == "axolotl":
				top = b + Vector2(sx * 40, -22) * k
				bot = b + Vector2(sx * 50, 30) * k
			elif a.kind == "puppy" or a.kind == "kitten":
				top = b + Vector2(sx * 46, -30) * k
				bot = b + Vector2(sx * 58, 26) * k
			var strap := PackedVector2Array([top, top.lerp(bot, 0.5) + Vector2(sx * 4, 0), bot])
			h.ci.draw_polyline(strap, Color("#8A1E2E"), 15.0 * k + 2.0, true)
			h.ci.draw_polyline(strap, Color("#FF4F5E"), 10.0 * k, true)
			h.ci.draw_polyline(strap, Color(1, 1, 1, 0.35), 3.0 * k, true)
			h._ball(top.lerp(bot, 0.55), 5 * k + 1.0, 5 * k + 1.0, SILVER, 0.0, 1.0, 0.95, 1.0)
		return
	for sx in [-1.0, 1.0]:
		var c := b + Vector2(sx * w * (0.5 if a.kind == "owl" else 0.56), -w * 0.06)
		var rw := w * 0.12
		var rh := w * 0.5
		# пламя
		var fl := 0.75 + 0.25 * sin(t * 23.0 + sx) + 0.1 * sin(t * 37.0)
		var fb := c + Vector2(0, rh * 0.5)
		h._glow(fb + Vector2(0, rw * 1.2), rw * 1.6, rw * 2.4 * fl, Color(1.0, 0.6, 0.2, 0.45))
		var flame := PackedVector2Array([fb + Vector2(-rw * 0.7, 0), fb + Vector2(rw * 0.7, 0), fb + Vector2(rw * 0.3, rw * 1.6 * fl), fb + Vector2(0, rw * 3.0 * fl), fb + Vector2(-rw * 0.3, rw * 1.6 * fl)])
		h.ci.draw_colored_polygon(h._chaikin(flame, 1), Color("#FF7A2E"))
		var inner := PackedVector2Array([fb + Vector2(-rw * 0.4, 0), fb + Vector2(rw * 0.4, 0), fb + Vector2(0, rw * 1.8 * fl)])
		h.ci.draw_colored_polygon(inner, Color("#FFE680"))
		# корпус ракеты
		h._T = Transform2D(0.0, c)
		h._shape(["rocket_body", rw, rh], h._rrect(Rect2(-rw, -rh * 0.4, rw * 2, rh * 0.9), rw * 0.8), Vector2(0, 0), Color("#EEF0FA"), 1.3, 0.8)
		var nose := PackedVector2Array([Vector2(-rw * 0.98, -rh * 0.32), Vector2(-rw * 0.6, -rh * 0.48), Vector2(0, -rh * 0.62), Vector2(rw * 0.6, -rh * 0.48), Vector2(rw * 0.98, -rh * 0.32)])
		h._shape(["rocket_nose", rw, rh], nose, Vector2(0, -rh * 0.42), Color("#FF4F5E"), 1.0, 0.7)
		h._fill(PackedVector2Array([Vector2(-rw, rh * 0.12), Vector2(rw, rh * 0.12), Vector2(rw, rh * 0.22), Vector2(-rw, rh * 0.22)]), Color("#FF4F5E"))
		h._ball(Vector2(0, -rh * 0.12), rw * 0.48, rw * 0.48, Color("#3FD0FF"), 0.0, 1.0, 1.0, 1.4)
		h._dot(Vector2(-rw * 0.18, -rh * 0.16), rw * 0.15, Color(1, 1, 1, 0.9))
		for fx in [-1.0, 1.0]:
			var fin := PackedVector2Array([Vector2(fx * rw * 0.9, rh * 0.2), Vector2(fx * rw * 1.7, rh * 0.48), Vector2(fx * rw * 0.9, rh * 0.45)])
			h._fill(fin, Color("#FF4F5E"))
		h._fill(PackedVector2Array([Vector2(-rw * 0.6, rh * 0.48), Vector2(rw * 0.6, rh * 0.48), Vector2(rw * 0.75, rh * 0.56), Vector2(-rw * 0.75, rh * 0.56)]), Color("#7A7FA0"))
		h._T = Transform2D.IDENTITY


