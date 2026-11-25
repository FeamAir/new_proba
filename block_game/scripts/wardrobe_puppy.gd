extends RefCounted
## Cascado 0.12b: гардероб ЩЕНКА — весёлый спортсмен и приключенец. Рисуется только на щенке
## (точки крепления — hero.gd, _anchors "puppy").
## Наборы (0.13): «Спортплощадка» (обычный), «Цветочный пикник» (милый, вместо «Похода»),
## «Супергерой» (крутой); награды кузницы — Золотая фрисби, Радуга лепестков, Молнии-скорость;
## супер-эксклюзив — Пёс-герой / Собачка-героиня (развевающаяся накидка с лапкой, маска, золотая медаль;
## при победе — геройский прыжок, hero.gd).

const Sets := preload("res://scripts/hero_sets.gd")

const GOLD := Color("#FFC83A")
const GOLD_D := Color("#B8771A")
const RED := Color("#FF4B55")


static func hs(i: float, k := 0.0) -> float:
	return Sets.hs(i, k)


static func item(h, id: String, stage: String, a: Dictionary, t: float) -> void:
	match id:
		"pu_cap":
			if stage == "head":
				cap(h, a, t)
		"pu_whistle":
			if stage == "neck":
				whistle(h, a, t)
		"pu_visor":
			if stage == "eyes":
				visor(h, a, t)
		"pu_daisy_wreath":
			if stage == "head":
				daisy_wreath(h, a, t)
		"pu_flower_scarf":
			if stage == "neck":
				flower_scarf(h, a, t)
		"pu_daisy_specs":
			if stage == "eyes":
				daisy_specs(h, a, t)
		"pu_bolt_band":
			if stage == "head":
				bolt_band(h, a, t)
		"pu_hero_bandana":
			if stage == "neck":
				bandana(h, a, t)
		"pu_hero":
			if stage == "worn":
				hero_mask(h, a, t)
				medal(h, a, t)


static func companion(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	match id:
		"pu_ball":
			if front:
				ball(h, a, t, react)
		"pu_robo":
			if front:
				robo(h, a.comp + Vector2(sin(t * 0.9) * 10.0, sin(t * 1.8) * 8.0), t, react)
		"pu_frisbee":
			frisbee(h, a, t, front)
		"pu_basket":
			if front:
				basket(h, a.comp + Vector2(-6 + sin(t * 0.8) * 8.0, 8 + sin(t * 1.6) * 6.0), t, react)


static func aura(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	match id:
		"pu_aura_bolts":
			bolts(h, a, t, front)
		"pu_petal_rainbow":
			petal_rainbow(h, a, t, front)
		"pu_hero":
			if not front and a.kind != "icon" and a.has("back"):
				hero_cape(h, a, t, react)
			if front:
				_hero_stars(h, a, t)


static func icon(h, id: String, slot: String, a: Dictionary, t: float) -> bool:
	match id:
		"pu_daisy_wreath":
			a.top = Vector2(0, 30)
			a.top_w = 185.0
			daisy_wreath(h, a, t)
			return true
		"pu_ball":
			_ball_at(h, Vector2(0, 0), 4.2, t, 0.0)
			return true
		"pu_bolt_band":
			a.top = Vector2(0, -16)
			a.top_w = 130.0
			bolt_band(h, a, t)
			return true
	return false


# ==================== Голова ====================

## Бейсболка: красная, белый передок с лапкой, козырёк набок
static func cap(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var dome := PackedVector2Array()
	for i in 19:
		var ang := PI + PI * i / 18.0
		dome.append(Vector2(cos(ang) * 52, 12 + sin(ang) * 38))
	h._shape(["pu_cap_dome"], dome, Vector2(-8, -8), RED, 1.2, 0.5)
	# белый передок
	var front := PackedVector2Array()
	for i in 11:
		var ang := PI * 1.18 + PI * 0.64 * i / 10.0
		front.append(Vector2(cos(ang) * 30, 12 + sin(ang) * 34))
	front.append(Vector2(22, 12))
	front.append(Vector2(-22, 12))
	h._shape(["pu_cap_front"], front, Vector2(0, -6), Color("#FFF8F0"), 1.4, 0.4)
	# лапка
	var pc := Vector2(0, -6)
	h._ball(pc + Vector2(0, 3), 6.5, 5.5, RED, 0.0, 1.0, 0.5, 0.0)
	for k in 3:
		h._ball(pc + Vector2((k - 1) * 6.0, -5 + absf(k - 1) * 1.5), 2.6, 2.8, RED, 0.0, 1.0, 0.5, 0.0)
	# швы
	h._line(PackedVector2Array([Vector2(-36, 6), Vector2(-30, -16), Vector2(-10, -24)]), Color(1, 1, 1, 0.35), 1.6)
	h._line(PackedVector2Array([Vector2(36, 6), Vector2(30, -16), Vector2(10, -24)]), Color(1, 1, 1, 0.35), 1.6)
	# козырёк набок
	h._T = h._head_T(a) * Transform2D(-0.22, Vector2(26, 12))
	h._ball(Vector2(0, 0), 44, 10, Color("#D9323E"), 0.0, 1.5, 0.5)
	h._arc(Vector2(0, -2), 40, 6, 1.1 * PI, 1.9 * PI, Color(1, 1, 1, 0.35), 2.0, 10)
	h._T = h._head_T(a)
	h._ball(Vector2(0, -26), 5, 3.5, Color("#FFF8F0"), 0.0, 1.0, 0.7, 1.0)
	h._T = Transform2D.IDENTITY


## Повязка-молния: синяя спортивная повязка через лоб, жёлтая молния, хвостики развеваются
static func bolt_band(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		var x := lerpf(-74, 74, s)
		var y := 24.0 - sin(s * PI) * 8.0
		top.append(Vector2(x, y - 9))
		bot.append(Vector2(x * 0.98, y + 9))
	for i in 12:
		h._fill(PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]]), Color("#2E6BFF") if i % 4 != 1 else Color("#3E7CFF"))
	Sets._tube_shade(h, h._T * top, h._T * bot)
	# хвостики завязки справа
	for k in 2:
		var w := sin(t * 5.0 + k) * 0.2
		var b0: Vector2 = top[12].lerp(bot[12], 0.5)
		var tail := PackedVector2Array([b0, b0 + Vector2(16, 6 + k * 8).rotated(w), b0 + Vector2(30, 10 + k * 12).rotated(w * 1.5)])
		h._line(tail, Color("#2457D8"), 7.0 - k)
	# молния
	var bolt := PackedVector2Array([Vector2(4, 10), Vector2(-8, 26), Vector2(0, 26), Vector2(-5, 40), Vector2(10, 21), Vector2(2, 21), Vector2(8, 10)])
	h._fill(bolt, Color("#FFE23A"), Color("#B8771A"), 2.0)
	h._line(PackedVector2Array([Vector2(3, 12), Vector2(-4, 23)]), Color(1, 1, 1, 0.7), 1.6)
	h._T = Transform2D.IDENTITY
	h._sparkle(h._hv(a, Vector2(14, 12)), 3.0 + 2.0 * sin(t * 5.0), Color.WHITE)


# ==================== Глаза ====================

## Спортивные очки-козырёк: одно гнутое стекло с переливом, белая оправа
static func visor(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var hd: float = (a.eye_l as Vector2).distance_to(a.eye_r) / 2.0
	h._T = Transform2D(a.tilt, mid)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		var x := lerpf(-hd - r * 1.5, hd + r * 1.5, s)
		var dip := (0.0 if absf(s - 0.5) > 0.06 else 6.0)
		top.append(Vector2(x, -r * 1.05 + pow(2.0 * s - 1.0, 2) * r * 0.25))
		bot.append(Vector2(x, r * 0.95 - pow(2.0 * s - 1.0, 2) * r * 0.55 - dip))
	var lens := top.duplicate()
	var rb := bot.duplicate()
	rb.reverse()
	lens.append_array(rb)
	var cols := PackedColorArray()
	for v in lens:
		var k := clampf((v.x + hd + r * 1.5) / ((hd + r * 1.5) * 2.0), 0.0, 1.0)
		cols.append(Color(Color("#FF9A2E").lerp(Color("#FF4FA3"), k).lerp(Color("#7A5CFF"), maxf(0.0, k - 0.5) * 2.0), 0.5))
	h.ci.draw_polygon(h._T * lens, cols)
	var rim := bot.duplicate()
	h._line(rim, Color(1.0, 0.6, 0.85, 0.8), r * 0.07)
	h._line(top, Color("#FFFFFF"), r * 0.22)
	h._line(top, Color("#D8E0F0"), r * 0.08)
	for sx in [-1.0, 1.0]:
		h._ball(Vector2(sx * (hd + r * 1.5), -r * 0.62), r * 0.2, r * 0.26, Color("#2E6BFF"), 0.0, 1.0, 0.7, 1.0)
	# бегущий блик
	var ph := fposmod(t * 0.4, 1.6)
	if ph < 1.0:
		var x := lerpf(-hd - r, hd + r, ph)
		h._line(PackedVector2Array([Vector2(x, -r * 0.7), Vector2(x - r * 0.5, r * 0.5)]), Color(1, 1, 1, 0.55 * sin(ph * PI)), r * 0.2)
	h._line(PackedVector2Array([Vector2(-hd - r * 0.8, -r * 0.5), Vector2(-hd - r * 0.3, r * 0.2)]), Color(1, 1, 1, 0.5), r * 0.1)
	h._T = Transform2D.IDENTITY


## ПЁС-ГЕРОЙ — маска: синяя, с прорезями для глаз (глаза видны) и острыми кончиками
static func hero_mask(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var hd: float = (a.eye_l as Vector2).distance_to(a.eye_r) / 2.0
	h._T = Transform2D(a.tilt, mid)
	h._vgrad(PackedVector2Array([Vector2(-hd + r * 0.6, -r * 0.8), Vector2(hd - r * 0.6, -r * 0.8), Vector2(hd - r * 0.6, r * 0.25),
		Vector2(0, -r * 0.05), Vector2(-hd + r * 0.6, r * 0.25)]), Color("#4A6CFF"), Color("#2440C0"))
	for sx in [-1.0, 1.0]:
		var c := Vector2(sx * hd, 0)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 36:
			var ang := TAU * i / 36.0
			var d := Vector2(cos(ang), sin(ang))
			var tipk := pow(maxf(0.0, d.x * sx * 0.75 - d.y * 0.66), 4.0)
			var ro := r * (1.42 + 0.95 * tipk)
			outer.append(c + Vector2(d.x * ro * 1.06, d.y * ro * 0.8))
			inner.append(c + Vector2(d.x * r * 0.98, d.y * r * 0.88))
		Sets.band(h, outer, inner, Color("#2440C0"), Color("#4A6CFF"))
		h._line(Sets.closed(outer), Color("#16207A"), r * 0.08)
		h._line(Sets.closed(inner), Color("#FFE23A"), r * 0.09)
		h._line(PackedVector2Array([c + Vector2(-r * 1.0, -r * 0.75), c + Vector2(r * 0.2, -r * 1.05)]), Color(1, 1, 1, 0.45), r * 0.1)
	h._T = Transform2D.IDENTITY


# ==================== Шея ====================

## Свисток тренера на синем шнурке
static func whistle(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var n: Vector2 = a.neck
	var cord := PackedVector2Array()
	for i in 13:
		var ang := lerpf(0.0, PI, i / 12.0)
		cord.append(n + Vector2(cos(ang) * w * 0.44, -6 + sin(ang) * w * 0.22))
	h.ci.draw_polyline(cord, Color("#1E3FA0"), 5.0, true)
	h.ci.draw_polyline(cord, Color("#4A7CFF"), 2.6, true)
	var sw := sin(t * 2.2) * 0.12
	var pc: Vector2 = cord[6] + Vector2(0, 4)
	h._T = Transform2D(sw, Vector2(1.45, 1.45), 0.0, pc)
	h._ball(Vector2(0, 2), 3, 3, Color("#C0C8E0"), 0.0, 1.0, 0.9, 0.8)
	h._shape(["pu_whistle"], h._rrect(Rect2(-14, 6, 20, 11), 4), Vector2(-4, 11), Color("#D8DEF0"), 1.2, 0.95)
	h._ball(Vector2(8, 16), 10, 10, Color("#E4E9FA"), 0.0, 1.0, 0.95, 1.2)
	h._dot(Vector2(8, 16), 3.2, Color("#7A84A8"))
	h._line(PackedVector2Array([Vector2(-12, 8), Vector2(2, 8)]), Color(1, 1, 1, 0.8), 1.6)
	h._T = Transform2D.IDENTITY
	h._sparkle(pc + Vector2(16, 8), 2.5 + 2.0 * sin(t * 4.0), Color.WHITE)


## Геройская бандана: красный платок-треугольник со звёздочками, узелок сбоку
static func bandana(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var n: Vector2 = a.neck
	var sw := sin(t * 2.4) * 3.0
	var tri := PackedVector2Array([n + Vector2(-w * 0.46, -6), n + Vector2(w * 0.46, -6), n + Vector2(w * 0.08 + sw, w * 0.44), n + Vector2(-w * 0.02 + sw, w * 0.47)])
	h._T = Transform2D.IDENTITY
	h._shape(null, h._chaikin(tri, 1), n + Vector2(0, w * 0.14), Color("#E8323E"), 1.8, 0.4)
	for i in 6:
		var p := n + Vector2((hs(i, 1) - 0.5) * w * 0.6 * (1.0 - hs(i, 2) * 0.6), w * (0.02 + hs(i, 2) * 0.3))
		h._fill(Sets.star_pts(p, 4.5, 1.9, 5, i), Color("#FFE680"))
	var band := Sets._neck_curve(a, 11, -4.0, 0.98, 0.35)
	h.ci.draw_polyline(band, Color("#B01E2E"), 8.0, true)
	h.ci.draw_polyline(band, Color("#FF5A66"), 3.0, true)
	var knot := n + Vector2(-w * 0.4, -2)
	h._ball(knot, 7, 6, Color("#D02A38"), 0.0, 1.0, 0.6, 1.0)
	for k in 2:
		var e := knot + Vector2(-10 - k * 4, 10 + k * 6).rotated(sin(t * 4.0 + k) * 0.15)
		h._line(PackedVector2Array([knot, e]), Color("#E8323E"), 6.0 - k)


## ПЁС-ГЕРОЙ — золотая медаль на красно-белой ленте
static func medal(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var n: Vector2 = a.neck
	var pc := n + Vector2(0, w * 0.26)
	for sx in [-1.0, 1.0]:
		var rib := PackedVector2Array([n + Vector2(sx * w * 0.34, -6), n + Vector2(sx * w * 0.2, -8), pc + Vector2(sx * 2, -10), pc + Vector2(sx * 12, -8)])
		h._fill(rib, Color("#E8323E"))
		h._line(PackedVector2Array([rib[0].lerp(rib[1], 0.5), rib[2].lerp(rib[3], 0.5)]), Color("#FFFFFF", 0.85), 3.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.5)
	h._glow(pc, 26, 26, Color(1.0, 0.85, 0.35, snappedf(0.25 + 0.15 * pulse, 0.04)))
	h._ball(pc, 15, 15, GOLD, 0.0, 1.0, 0.95, 1.4)
	h._ball(pc, 10.5, 10.5, Color("#FFDC6A"), 0.0, 1.6, 0.9, 0.0)
	h._T = Transform2D(0.0, pc)
	h._ball(Vector2(0, 2.5), 4.0, 3.4, GOLD_D, 0.0, 1.0, 0.5, 0.0)
	for k in 3:
		h._ball(Vector2((k - 1) * 3.8, -3 + absf(k - 1) * 1.0), 1.7, 1.9, GOLD_D, 0.0, 1.0, 0.5, 0.0)
	h._T = Transform2D.IDENTITY
	h._sparkle(pc + Vector2(-8, -9), 4.0 + 3.0 * pulse, Color.WHITE)


# ==================== Спина ====================

## ПЁС-ГЕРОЙ — накидка: длинная красная, развевается на ветру вправо, на ней жёлтая эмблема-лапка;
## в прыжке (касание, победа) взлетает выше
static func hero_cape(h, a: Dictionary, t: float, react: float) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	var gust := 0.0
	if react >= 0.0 and react < 1.3:
		gust = sin(react / 1.3 * PI)
	var top_l := b + Vector2(-w * 0.36, -w * 0.34)
	var top_r := b + Vector2(w * 0.36, -w * 0.34)
	# край накидки: от левого низа к правому кончику, развевается
	var n := 15
	var hem := PackedVector2Array()
	for i in n:
		var s := i / float(n - 1)
		var x := lerpf(-w * 0.6, w * 1.25, s)
		var y := w * (0.62 - 0.55 * s * s) - gust * w * 0.35 * s
		y += sin(s * TAU * 1.5 - t * 5.0) * (5.0 + 9.0 * s)
		hem.append(b + Vector2(x, y))
	var pts := PackedVector2Array([top_l])
	pts.append_array(hem)
	pts.append(top_r)
	var cols := PackedColorArray()
	for v in pts:
		var k := clampf((v.x - (b.x - w * 0.6)) / (w * 1.9), 0.0, 1.0)
		cols.append(Color("#FF5A64").lerp(Color("#A0142C"), k * 0.8 + clampf((v.y - b.y) / w, 0.0, 1.0) * 0.3))
	h.ci.draw_polyline(Sets.closed(pts), Color(0.25, 0.0, 0.08, 0.6), 4.0, true)
	h.ci.draw_polygon(pts, cols)
	# складки
	for i in [4, 8, 11]:
		var hp: Vector2 = hem[i]
		h.ci.draw_line(b + Vector2(lerpf(-w * 0.2, w * 0.3, i / 14.0), -w * 0.2), hp + Vector2(0, -6), Color(0.35, 0.0, 0.1, 0.28), 7.0, true)
	h.ci.draw_polyline(hem, Color("#B8771A"), 6.0, true)
	h.ci.draw_polyline(hem, GOLD, 3.0, true)
	# эмблема-лапка на развевающемся конце
	var ec: Vector2 = hem[10].lerp(b + Vector2(w * 0.7, -w * 0.1), 0.45)
	h._T = Transform2D(-0.3 - gust * 0.3, ec)
	h._ball(Vector2.ZERO, 17, 17, GOLD, 0.0, 1.2, 0.8, 1.2)
	h._ball(Vector2(0, 3), 7, 6, Color("#E8323E"), 0.0, 1.0, 0.5, 0.0)
	for k in 3:
		h._ball(Vector2((k - 1) * 6.5, -6 + absf(k - 1) * 1.8), 2.8, 3.2, Color("#E8323E"), 0.0, 1.0, 0.5, 0.0)
	h._T = Transform2D.IDENTITY
	# застёжки на плечах
	for sx in [-1.0, 1.0]:
		h._ball(b + Vector2(sx * w * 0.36, -w * 0.34), 7, 7, GOLD, 0.0, 1.0, 0.9, 1.0)


static func _hero_stars(h, a: Dictionary, t: float) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	for i in 4:
		var ph := fposmod(t * 0.4 + i * 0.25, 1.0)
		var p := c + Vector2(cos(i * 1.9 + 0.5) * R * 1.15, -R * 0.4 + sin(i * 2.7) * R * 0.5)
		h._sparkle(p, (4.0 + 4.0 * sin(ph * PI)) * (0.7 if a.kind == "icon" else 1.0), Color(1.0, 0.95, 0.6, sin(ph * PI)))


# ==================== Спутники ====================

## Теннисный мячик: прыгает на земле рядом со щенком (сплющивается при ударе), тень
static func ball(h, a: Dictionary, t: float, react: float) -> void:
	var ph := fposmod(t * 1.4, 1.0)
	var hgt := sin(ph * PI) * 70.0
	if react >= 0.0 and react < 1.3:
		hgt += sin(react / 1.3 * PI) * 40.0
	var ground := Vector2(128, 112)
	h._glow(ground + Vector2(0, 4), 18 - hgt * 0.08, 5, Color(0.03, 0.0, 0.1, 0.4))
	var squash := 1.0 - 0.25 * maxf(0.0, 1.0 - hgt / 8.0)
	_ball_at(h, ground + Vector2(0, -13 - hgt), 1.0, t, 1.0 - squash)


static func _ball_at(h, p: Vector2, k: float, t: float, squash: float) -> void:
	h._T = Transform2D(t * 2.0, Vector2(k * (1.0 + squash), k * (1.0 - squash)), 0.0, p)
	h._ball(Vector2.ZERO, 13, 13, Color("#D8F03A"), 0.0, 1.0, 0.4, 1.4)
	h._arc(Vector2(-14, 0), 10, 10, -0.9, 0.9, Color("#FFFFFF"), 2.4, 10)
	h._arc(Vector2(14, 0), 10, 10, PI - 0.9, PI + 0.9, Color("#FFFFFF"), 2.4, 10)
	for i in 5:
		h._dot(Vector2((hs(i, 1) - 0.5) * 14, (hs(i, 2) - 0.5) * 14), 1.0, Color(1, 1, 0.8, 0.6))
	h._T = Transform2D.IDENTITY


## Робо-щенок: круглый помощник с экраном-мордашкой, антенной и пропеллером
static func robo(h, p: Vector2, t: float, react: float) -> void:
	var happy := react >= 0.0 and react < 1.3
	h._glow(p + Vector2(0, 34), 18, 5, Color(0.3, 0.9, 1.0, 0.35))
	h._T = Transform2D(sin(t * 1.4) * 0.08, p)
	# пропеллер
	var spin := absf(sin(t * 18.0))
	h._line(PackedVector2Array([Vector2(0, -22), Vector2(0, -30)]), Color("#8A93B8"), 2.4)
	h._oval(Vector2(0, -31), 18 * spin + 3, 3, Color(0.85, 0.9, 1.0, 0.75))
	h._ball(Vector2(0, -31), 3, 3, Color("#FF4B55"), 0.0, 1.0, 0.9, 0.8)
	# ушки-антенны
	for sx in [-1.0, 1.0]:
		h._ball(Vector2(sx * 17, -10), 5, 8, Color("#3FC8E0"), sx * 0.4, 1.0, 0.6, 1.0)
	h._ball(Vector2.ZERO, 20, 19, Color("#F2F6FF"), 0.0, 1.0, 0.8, 1.4)
	h._shape(["pu_robo_screen"], h._rrect(Rect2(-14, -10, 28, 18), 7), Vector2(0, -1), Color("#1E2A4A"), 1.6, 0.7, 0.0)
	var blink := fposmod(t, 2.7) < 0.15
	for sx in [-1.0, 1.0]:
		if happy:
			h._arc(Vector2(sx * 6, 0), 3.5, 3.0, 1.1 * PI, 1.9 * PI, Color("#5CFFE0"), 2.0, 6)
		elif blink:
			h._line(PackedVector2Array([Vector2(sx * 6 - 3, -1), Vector2(sx * 6 + 3, -1)]), Color("#5CFFE0"), 2.0)
		else:
			h._ball(Vector2(sx * 6, -1), 3.2, 4.0, Color("#5CFFE0"), 0.0, 1.0, 0.9, 0.0)
	h._arc(Vector2(0, 3), 4, 2.5, 0.1 * PI, 0.9 * PI, Color("#5CFFE0"), 1.6, 6)
	# ручки
	for sx in [-1.0, 1.0]:
		h._ball(Vector2(sx * 22, 8 + sin(t * 3.0 + sx) * 2.0), 4, 4, Color("#3FC8E0"), 0.0, 1.0, 0.7, 1.0)
	h._ball(Vector2(0, 16), 8, 3, Color("#3FC8E0"), 0.0, 1.0, 0.7, 0.8)
	h._T = Transform2D.IDENTITY


## Где фрисби (большая петля вокруг щенка)
static func _fr_at(a: Dictionary, t: float) -> Vector3:
	var c: Vector2 = a.center
	var R: float = a.size
	var ang := t * 1.0
	if a.kind == "icon":
		return Vector3(c.x + cos(ang) * 28.0, c.y + sin(ang) * 10.0, sin(ang))
	return Vector3(c.x + cos(ang) * R * 1.3, c.y + R * 0.42 + sin(ang) * R * 0.2 - cos(ang * 2.0) * R * 0.12, sin(ang))


## ЗОЛОТАЯ ФРИСБИ (легендарная): крутится, летает петлёй вокруг щенка, оставляет радужный след
static func frisbee(h, a: Dictionary, t: float, front: bool) -> void:
	var now := _fr_at(a, t)
	if (now.z > 0.0) != front:
		return
	var k := 1.0 if a.kind != "icon" else 1.7
	for i in range(10, 0, -1):
		var q := _fr_at(a, t - i * 0.045)
		var s := i / 10.0
		var col := Sets.hsv(s * 0.8 + t * 0.1, 0.55, 1.0)
		h._glow(Vector2(q.x, q.y), (12.0 - i * 0.7) * k, (8.0 - i * 0.5) * k, Color(col, snappedf(0.5 * (1.0 - s), 0.05)))
	var p := Vector2(now.x, now.y)
	h._glow(p, 30 * k, 20 * k, Color(1.0, 0.85, 0.35, 0.45))
	h._T = Transform2D(-0.15 + sin(t) * 0.1, Vector2(k, k), 0.0, p)
	h._ball(Vector2(0, 2), 22, 8, Color("#C98A2E"), 0.0, 1.0, 0.6, 1.0)
	h._ball(Vector2(0, -1), 21, 7, GOLD, 0.0, 1.2, 0.95, 1.0)
	var spin := t * 9.0
	for m in 3:
		var ang := spin + m * TAU / 3.0
		h._dot(Vector2(cos(ang) * 13.0, sin(ang) * 3.5 - 1.0), 2.0, Color(1, 1, 1, 0.5 + 0.5 * sin(ang)))
	h._arc(Vector2(0, -1), 14, 4, 0, TAU, Color("#FFE89A"), 1.6, 16)
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(-14, -8) * k, (3.0 + 3.0 * sin(t * 6.0)) * k, Color.WHITE)


# ==================== Сияние ====================

## МОЛНИИ-СКОРОСТЬ (легендарное): вокруг щенка потрескивают молнии, проносятся полоски скорости
static func bolts(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front:
		h._glow(c, R * 1.35, R * 1.35, Color(0.3, 0.6, 1.0, 0.17))
		# полоски скорости слева
		for i in 5:
			var ph := fposmod(t * 1.6 + hs(i, 1), 1.0)
			var y := c.y + (hs(i, 2) - 0.5) * R * 1.6
			var x0 := c.x - R * 0.6 - ph * R * 1.2
			h.ci.draw_line(Vector2(x0, y), Vector2(x0 - R * 0.5, y), Color(0.7, 0.85, 1.0, 0.45 * sin(ph * PI)), 4.0, true)
	var step := floorf(t / 0.14)
	for i in 3:
		if (i % 2 == 1) != front:
			continue
		var seed := step + i * 17.0
		if hs(seed, 1) < 0.35:
			continue
		var ang := hs(seed, 2) * TAU
		var p0 := c + Vector2(cos(ang), sin(ang) * 0.9) * R * 0.95
		var pts := PackedVector2Array([p0])
		var dir := Vector2(cos(ang), sin(ang))
		var q := p0
		for m in 4:
			q += dir * R * 0.12 + dir.orthogonal() * (hs(seed, 3 + m) - 0.5) * R * 0.22
			pts.append(q)
		h.ci.draw_polyline(pts, Color(0.5, 0.8, 1.0, 0.55), 8.0, true)
		h.ci.draw_polyline(pts, Color("#FFF6A0"), 3.0, true)
		h._sparkle(q, 7.0, Color(1, 1, 0.8, 0.9))
	if front:
		for i in 3:
			var ph := fposmod(t * 0.7 + i * 0.33, 1.0)
			var p := c + Vector2(cos(i * 2.1 + t * 0.6) * R * 1.2, sin(i * 2.1 + t * 0.6) * R * 0.9)
			h._sparkle(p, 5.0 * sin(ph * PI) + 0.5, Color(1.0, 0.95, 0.5, sin(ph * PI)))


# ==================== 0.13: «Цветочный пикник» ====================

const DAISY := Color("#FFFDF6")
const DAISY_C := Color("#FFC83A")
const LEAF := Color("#5CC46A")


## Ромашка: белые лепестки вокруг жёлтой серединки (центр p, радиус r, поворот rot)
static func daisy(h, p: Vector2, r: float, rot: float) -> void:
	var T0: Transform2D = h._T
	h._T = T0 * Transform2D(rot, p)
	for i in 8:
		var ang := i * TAU / 8.0
		h._ball(Vector2(cos(ang), sin(ang)) * r * 0.62, r * 0.48, r * 0.24, DAISY, ang, 1.2, 0.3, 0.8)
	h._ball(Vector2.ZERO, r * 0.36, r * 0.36, DAISY_C, 0.0, 1.0, 0.7, 1.0)
	h._dot(Vector2(-r * 0.12, -r * 0.12), r * 0.1, Color(1, 1, 1, 0.8))
	h._T = T0


## Веночек из ромашек: зелёная лоза вокруг макушки, ромашки и листики
static func daisy_wreath(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var ring := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 52, 12 + sin(ang) * 14))
	h._line(ring, Color("#3E9A4E"), 6.0)
	h._line(ring, Color("#7EDC86"), 2.4)
	for i in range(1, 16, 2):
		var p: Vector2 = ring[i]
		var sx := -1.0 if i < 8 else 1.0
		h._ball(p + Vector2(sx * 5, -5), 7, 3.4, LEAF, -sx * 0.7, 1.2, 0.4, 0.8)
	var sw := sin(t * 1.5) * 0.08
	for i in [0, 3, 6, 8, 10, 13, 16]:
		var p: Vector2 = ring[i]
		daisy(h, p + Vector2(0, -2), 11.0 if i == 8 else 9.0, sw + i * 0.4)
	h._T = Transform2D.IDENTITY
	h._sparkle(h._hv(a, Vector2(30, -14)), 2.5 + 2.0 * sin(t * 3.0), Color(1, 1, 1, 0.8))


## Платочек в цветочек: голубой платок-треугольник с ромашками, узелок сбоку
static func flower_scarf(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var n: Vector2 = a.neck
	var sw := sin(t * 2.0) * 2.0
	var tri := PackedVector2Array([n + Vector2(-w * 0.44, -6), n + Vector2(w * 0.44, -6), n + Vector2(w * 0.06 + sw, w * 0.4), n + Vector2(-w * 0.04 + sw, w * 0.42)])
	h._T = Transform2D.IDENTITY
	h._shape(null, h._chaikin(tri, 1), n + Vector2(0, w * 0.12), Color("#78C8F0"), 1.8, 0.4)
	for i in 7:
		var p := n + Vector2((hs(i, 1) - 0.5) * w * 0.62 * (1.0 - hs(i, 2) * 0.6), w * (0.0 + hs(i, 2) * 0.3))
		for k in 5:
			var ang := k * TAU / 5.0 + i
			h._dot(p + Vector2(cos(ang), sin(ang)) * 3.2, 2.4, Color(1, 1, 1, 0.95))
		h._dot(p, 1.8, DAISY_C)
	var band := Sets._neck_curve(a, 11, -4.0, 0.98, 0.35)
	h.ci.draw_polyline(band, Color("#3E8CC0"), 8.0, true)
	h.ci.draw_polyline(band, Color("#A8E0FF"), 3.0, true)
	var knot := n + Vector2(w * 0.4, -2)
	h._ball(knot, 7, 6, Color("#4E9ED0"), 0.0, 1.0, 0.6, 1.0)
	for k in 2:
		var e := knot + Vector2(10 + k * 4, 10 + k * 6).rotated(sin(t * 3.5 + k) * 0.15)
		h._line(PackedVector2Array([knot, e]), Color("#78C8F0"), 6.0 - k)


## Очки-ромашки: круглые стёкла, вокруг каждого — белые лепестки, жёлтая перемычка
static func daisy_specs(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.08
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._T = Transform2D(a.tilt + sin(t * 1.2 + i) * 0.03, e)
		for k in 12:
			var ang := k * TAU / 12.0 + (0.13 if i == 0 else -0.13)
			h._ball(Vector2(cos(ang), sin(ang)) * r * 1.3, r * 0.36, r * 0.2, DAISY, ang, 1.2, 0.3, 0.8)
		h._vgrad(h._ell(Vector2.ZERO, r * 0.98, r * 0.98, 0.0, 26), Color(1.0, 0.95, 0.6, 0.28), Color(1.0, 0.8, 0.4, 0.18), false)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#E0A020"), r * 0.16, 28)
		h._arc(Vector2.ZERO, r, r, 0, TAU, DAISY_C, r * 0.08, 28)
		h._line(PackedVector2Array([Vector2(-r * 0.5, -r * 0.1), Vector2(-r * 0.1, -r * 0.5)]), Color(1, 1, 1, 0.65), r * 0.1)
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r, -r * 0.1).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r, r * 0.1).rotated(a.tilt)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.25).rotated(a.tilt), rr]), Color("#E0A020"), r * 0.13)


## Корзинка с булочкой (спутник): плетёная корзинка, клетчатая салфетка, румяная булочка;
## при касании булочка подпрыгивает
static func basket(h, p: Vector2, t: float, react: float) -> void:
	var hop := 0.0
	if react >= 0.0 and react < 1.3:
		hop = absf(sin(react / 1.3 * TAU)) * 14.0
	h._T = Transform2D(sin(t * 1.3) * 0.05, p)
	# ручка
	h._arc(Vector2(0, -2), 24, 26, 1.0 * PI, 2.0 * PI, Color("#8A5A2E"), 5.0, 16)
	h._arc(Vector2(0, -2), 24, 26, 1.05 * PI, 1.5 * PI, Color("#D8A868"), 2.0, 10)
	# салфетка
	h._fill(PackedVector2Array([Vector2(-26, 0), Vector2(-14, -12), Vector2(0, -6), Vector2(14, -12), Vector2(26, 0)]), Color("#FFFFFF"))
	for k in 4:
		h._fill(PackedVector2Array([Vector2(-20 + k * 11, -5), Vector2(-15 + k * 11, -9), Vector2(-11 + k * 11, -4), Vector2(-16 + k * 11, 0)]), Color("#FF5F6D", 0.85))
	# булочка
	var bp := Vector2(2, -12 - hop)
	h._ball(bp, 13, 10, Color("#E8A050"), 0.0, 1.1, 0.6, 1.2)
	h._ball(bp + Vector2(0, -3), 9, 5, Color("#F4C07A"), 0.0, 1.6, 0.6, 0.0)
	for k in 4:
		h._dot(bp + Vector2(-6 + k * 4, -5 + (k % 2) * 2), 1.1, Color("#FFF6E0"))
	# корзинка
	var bk := PackedVector2Array([Vector2(-27, -2), Vector2(27, -2), Vector2(22, 20), Vector2(-22, 20)])
	h._shape(["pu_basket"], h._chaikin(bk, 1), Vector2(0, 8), Color("#D29A56"), 1.3, 0.35, 1.2)
	for k in 3:
		var y := 3.0 + k * 6.0
		h._line(PackedVector2Array([Vector2(-25 + k * 1.5, y), Vector2(25 - k * 1.5, y)]), Color("#9A6A30", 0.6), 1.6)
	for k in 6:
		var x := -20.0 + k * 8.0
		h._line(PackedVector2Array([Vector2(x, 0), Vector2(x * 0.85, 19)]), Color("#F0C88A", 0.55), 1.4)
	h._ball(Vector2(0, -1), 28, 3.5, Color("#B8803E"), 0.0, 1.4, 0.4, 1.0)
	h._T = Transform2D.IDENTITY


## РАДУГА ЛЕПЕСТКОВ (легендарное): за щенком — пастельная радуга, вокруг кружат лепестки,
## то тут, то там распускаются ромашки
static func petal_rainbow(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	var cols := [Color("#FF9FB8"), Color("#FFD08A"), Color("#FFF29A"), Color("#A8EEB0"), Color("#9FD8FF"), Color("#C8B0FF")]
	if not front:
		var rc := c + Vector2(0, R * 0.45)
		var pulse := 0.85 + 0.15 * sin(t * 1.6)
		for i in cols.size():
			var rr := R * (1.55 - i * 0.1)
			var arc := PackedVector2Array()
			for k in 25:
				var ang := PI + PI * k / 24.0
				arc.append(rc + Vector2(cos(ang) * rr, sin(ang) * rr * 0.95))
			h.ci.draw_polyline(arc, Color(cols[i], 0.85 * pulse), R * 0.1, true)
		h._glow(rc + Vector2(0, -R * 0.9), R * 1.2, R * 0.7, Color(1.0, 0.95, 0.8, 0.12))
		# облачка на концах радуги
		for sx in [-1.0, 1.0]:
			for k in 3:
				h._ball(rc + Vector2(sx * R * (1.38 + k * 0.1) - sx * k * R * 0.12, -R * 0.02 - absf(k - 1) * R * 0.08), R * 0.13, R * 0.1, Color("#FFFFFF"), 0.0, 1.3, 0.3, 0.0)
	for i in 10:
		if (i % 2 == 1) != front:
			continue
		var per := 4.5 + hs(i, 1) * 2.5
		var ph := fposmod(t / per + hs(i, 2), 1.0)
		var p := c + Vector2((hs(i, 3) - 0.5) * R * 2.6 + sin(t * 1.3 + i) * 12.0, -R * 1.2 + ph * R * 2.4)
		var al := sin(ph * PI)
		var fl := absf(cos(t * 2.2 + i))
		h._T = Transform2D(t * 1.1 + i, Vector2(0.4 + 0.6 * fl, 1.0), 0.0, p)
		var col: Color = cols[i % cols.size()].lerp(Color.WHITE, 0.25)
		h._fill(PackedVector2Array([Vector2(0, -7), Vector2(4.5, -2), Vector2(3.5, 4.5), Vector2(0, 7), Vector2(-3.5, 4.5), Vector2(-4.5, -2)]), Color(col, al))
		h._T = Transform2D.IDENTITY
	if front:
		# ромашки распускаются вокруг (по очереди)
		for k in 3:
			var ph := fposmod(t * 0.35 + k / 3.0, 1.0)
			var cyc := floorf(t * 0.35 + k / 3.0)
			var p := c + Vector2((hs(cyc + k * 5, 1) - 0.5) * R * 2.4, R * 0.75 + hs(cyc + k * 5, 2) * R * 0.25)
			var s := sin(ph * PI)
			if s > 0.05:
				h._T = Transform2D.IDENTITY
				daisy(h, p, R * 0.1 * s + 1.0, t * 0.5 + k)
				if ph < 0.5:
					h._sparkle(p + Vector2(R * 0.1, -R * 0.1), R * 0.06 * s, Color(1, 1, 1, s))
