extends RefCounted
## Cascado 0.12b: гардероб КОТИКА — уютный модник. Рисуется только на котике
## (точки крепления — hero.gd, _anchors "kitten"; хвост — h._tail_mid / h._tail_w, этап part_tail;
## туловище — этап part_body: свитер под лапками).
## Наборы (0.13): «Уютный вечер» (обычный), «Кот-детектив» (крутой, вместо «Парижского шика»),
## «Бал-маскарад» (нарядный); награды кузницы — Чайная чашечка, Тайна следов, Праздничный салют;
## супер-эксклюзив — Звёздный кот / Звёздная кошка (хвост из звёздной пыли; у кошечки — тиара
## и бабочки, у кота — звёздная корона и кометы; h._girl — hero.gd).

const Sets := preload("res://scripts/hero_sets.gd")

const GOLD := Color("#FFC83A")
const GOLD_D := Color("#B8771A")
const PINK := Color("#FF6FA8")
const LACE := Color("#FFFDF8")


static func hs(i: float, k := 0.0) -> float:
	return Sets.hs(i, k)


static func item(h, id: String, stage: String, a: Dictionary, t: float) -> void:
	match id:
		"ki_pompom_hat":
			if stage == "head":
				pompom_hat(h, a, t)
		"ki_bell_bow":
			if stage == "neck":
				bell_bow(h, a, t)
		"ki_sweater":
			if stage == "part_body":
				sweater(h, Vector2(0, 70), 1.0, t)
		"ki_sleuth_hat":
			if stage == "head":
				sleuth_hat(h, a, t)
		"ki_moustache":
			if stage == "eyes":
				moustache(h, a, t)
		"ki_sleuth_badge":
			if stage == "neck":
				sleuth_badge(h, a, t)
		"ki_trench":
			if stage == "back_b" or stage == "back_f":
				trench(h, a, t, stage == "back_b")
		"ki_cameo":
			if stage == "neck":
				cameo(h, a, t)
		"ki_feather_hat":
			if stage == "head":
				feather_hat(h, a, t)
		"ki_starry":
			if stage == "worn":
				if h._girl:
					tiara(h, a, t)
				else:
					star_crown(h, a, t)
			elif stage == "part_tail":
				star_tail(h, t)


static func companion(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	if not front:
		return
	match id:
		"ki_yarn":
			yarn(h, a.comp + Vector2(sin(t * 0.8) * 10.0, absf(sin(t * 1.6)) * -10.0 + 6.0), t, react)
		"ki_teacup":
			teacup(h, a.comp + Vector2(sin(t * 0.7) * 8.0, sin(t * 1.4) * 7.0), t, react)
		"ki_magnifier":
			magnifier(h, a.comp + Vector2(sin(t * 0.8) * 9.0, sin(t * 1.5) * 8.0), t, react)


static func aura(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	match id:
		"ki_clue_trail":
			clue_trail(h, a, t, front)
		"ki_aura_fireworks":
			fireworks(h, a, t, front)
		"ki_starry":
			if h._girl:
				butterflies(h, a, t, front)
			else:
				comets(h, a, t, front)


static func icon(h, id: String, slot: String, a: Dictionary, t: float) -> bool:
	match id:
		"ki_sweater":
			sweater(h, Vector2(0, -6), 1.35, t)
			return true
		"ki_trench":
			a.back = Vector2(0, -40)
			a.back_w = 150.0
			trench(h, a, t, true)
			trench(h, a, t, false)
			return true
		"ki_moustache":
			moustache(h, a, t)
			return true
		"ki_sleuth_hat":
			a.top = Vector2(0, 30)
			a.top_w = 170.0
			sleuth_hat(h, a, t)
			return true
		"ki_pompom_hat":
			a.top = Vector2(0, 36)
			a.top_w = 190.0
			pompom_hat(h, a, t)
			return true
		"ki_feather_hat":
			a.top = Vector2(-24, 48)
			a.top_w = 150.0
			feather_hat(h, a, t)
			return true
	return false


# ==================== Голова ====================

## Вязаная шапочка с помпоном: розовая в белую полоску, между ушками
static func pompom_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var dome := PackedVector2Array()
	for i in 19:
		var ang := PI + PI * i / 18.0
		dome.append(Vector2(cos(ang) * 44, 10 + sin(ang) * 40))
	h._shape(["ki_beanie"], dome, Vector2(-6, -8), Color("#FF8FB8"), 1.2, 0.35)
	# белые полоски и вязка «косичкой»
	for k in 2:
		var y := -8.0 - k * 14.0
		var hw := 44.0 * sqrt(maxf(0.0, 1.0 - pow((10.0 - y) / 40.0, 2))) - 2.0
		h._line(PackedVector2Array([Vector2(-hw, y), Vector2(0, y + 2), Vector2(hw, y)]), Color("#FFF2F6", 0.9), 5.0)
	for k in 5:
		var x := -24.0 + k * 12.0
		for m in 2:
			h._line(PackedVector2Array([Vector2(x - 3, -30 + m * 10), Vector2(x, -27 + m * 10), Vector2(x + 3, -30 + m * 10)]), Color(1, 1, 1, 0.3), 1.4)
	# отворот в резинку
	var cuff := PackedVector2Array([Vector2(-47, 2), Vector2(47, 2), Vector2(46, 15), Vector2(-46, 15)])
	h._shape(["ki_beanie_cuff"], h._chaikin(cuff, 1), Vector2(0, 8), Color("#FF6FA0"), 1.6, 0.35)
	for k in 12:
		var x := -40.0 + k * 7.3
		h._line(PackedVector2Array([Vector2(x, 4), Vector2(x, 13)]), Color("#D94A80", 0.5), 1.4)
	# помпон
	var pp := Vector2(sin(t * 2.0) * 2.0, -36)
	h._ball(pp, 15, 14, Color("#FFF6FA"), 0.0, 1.3, 0.3, 1.0)
	for k in 7:
		var ang := k * TAU / 7.0
		h._ball(pp + Vector2(cos(ang), sin(ang)) * 11.0, 5, 5, Color("#FFFFFF"), 0.0, 1.2, 0.3, 0.0)
	h._T = Transform2D.IDENTITY


## Маскарадная шляпка: маленький бархатный цилиндр набок, вуаль-сеточка, пышное перо и камень
static func feather_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(0.22, Vector2(18, 2))
	var plum := Color("#6A3AB8")
	# перо
	var sw := sin(t * 1.6) * 0.07
	h._T = h._head_T(a) * Transform2D(0.22, Vector2(18, 2)) * Transform2D(-0.5 + sw, Vector2(-14, -14))
	var key := ["ki_hat_feather"]
	var vane := PackedVector2Array()
	if not h._cache.has(key):
		for i in 11:
			var s := i / 10.0
			vane.append(Vector2(-12.0 * sin(PI * pow(s, 0.7)), -s * 70.0 - sin(s * PI) * 6.0))
		for i in range(10, -1, -1):
			var s := i / 10.0
			vane.append(Vector2(10.0 * sin(PI * pow(s, 0.8)) + s * 10.0, -s * 70.0))
	h._shape(key, vane, Vector2(0, -34), Color("#FF7AD9"), 1.6, 0.5)
	h._glow(Vector2(2, -58), 10, 14, Color(1.0, 0.85, 1.0, 0.5))
	h._line(PackedVector2Array([Vector2(0, 0), Vector2(1, -40), Vector2(6, -68)]), Color("#FFE8F8"), 2.0)
	h._T = h._head_T(a) * Transform2D(0.22, Vector2(18, 2))
	h._ball(Vector2(0, 4), 30, 7, plum.darkened(0.15), 0.0, 1.3, 0.6)
	var body := PackedVector2Array([Vector2(-19, 4), Vector2(-21, -26), Vector2(21, -26), Vector2(19, 4)])
	h._shape(["ki_hat_body"], h._chaikin(body, 1), Vector2(0, -10), plum, 1.5, 0.6)
	h._ball(Vector2(0, -26), 21, 5, plum.lightened(0.12), 0.0, 1.3, 0.5, 1.0)
	h._vgrad(PackedVector2Array([Vector2(-20, -6), Vector2(20, -6), Vector2(20, 2), Vector2(-20, 2)]), Color("#FFC8F0"), Color("#E07AC0"))
	h._gem(Vector2(-10, -2), 5.5, Color("#3FE0D0"))
	# вуаль-сеточка
	for k in 4:
		var y := 6.0 + k * 6.0
		h._line(PackedVector2Array([Vector2(-26 + k * 2, y), Vector2(18 - k * 3, y + 3)]), Color(0.1, 0.05, 0.2, 0.3), 1.0)
	for k in 6:
		var x := -24.0 + k * 8.0
		h._line(PackedVector2Array([Vector2(x, 5), Vector2(x + 3, 26)]), Color(0.1, 0.05, 0.2, 0.25), 1.0)
	h._T = Transform2D.IDENTITY


## ЗВЁЗДНАЯ КОШКА — тиара с кристаллом: серебряная, в центре переливается большой кристалл
static func tiara(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(0.0, Vector2(1.3, 1.3), 0.0, Vector2(0, 4))
	var silver := Color("#E4E9FA")
	var ring := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 44, 10 + sin(ang) * 10))
	h._line(ring, Color("#8A93B8"), 6.0)
	h._line(ring, silver, 3.0)
	# узор-завитки и зубцы
	for k in 5:
		var s := k / 4.0
		var x := lerpf(-34, 34, s)
		var base := Vector2(x, 10 - sin(PI * (x + 44.0) / 88.0) * 10.0)
		var hgt := 10.0 + 14.0 * sin(s * PI)
		h._line(PackedVector2Array([base, base + Vector2(-5, -hgt * 0.5), base + Vector2(0, -hgt)]), silver, 2.4)
		h._line(PackedVector2Array([base, base + Vector2(5, -hgt * 0.5), base + Vector2(0, -hgt)]), silver, 2.4)
		if k != 2:
			h._gem(base + Vector2(0, -hgt - 3), 3.6, Color("#FF9FD8") if k % 2 == 0 else Color("#9FE8FF"))
	var hh := fposmod(t * 0.12, 1.0)
	var cc := Sets.hsv(0.55 + 0.25 * sin(hh * TAU), 0.45, 1.0)
	var cp := Vector2(0, -26)
	h._glow(cp, 26, 26, Color(cc, 0.4))
	h._gem(cp, 12.0, cc)
	h._T = Transform2D.IDENTITY
	h._sparkle(h._hv(a, cp * 1.3 + Vector2(-6, -8)), 7.0 + 3.0 * sin(t * 4.0), Color.WHITE)


# ==================== Шея ====================

## Бант с бубенчиком: атласная розовая лента вокруг шеи, бантик и золотой бубенчик
static func bell_bow(h, a: Dictionary, t: float) -> void:
	var band := Sets._neck_curve(a, 13, -2.0, 0.94, 0.35)
	h.ci.draw_polyline(band, Color("#D93A78"), 9.0, true)
	h.ci.draw_polyline(band, PINK, 6.0, true)
	h.ci.draw_polyline(band, Color(1, 1, 1, 0.35), 1.6, true)
	var c: Vector2 = band[6] + Vector2(0, 2)
	var k: float = a.neck_w / 118.0
	h._T = Transform2D(0.0, Vector2(k, k), 0.0, c)
	for sx in [-1.0, 1.0]:
		var tl := PackedVector2Array([Vector2(sx * 2, 2), Vector2(sx * 9, 4), Vector2(sx * 15, 18), Vector2(sx * 9, 16), Vector2(sx * 5, 20), Vector2(sx * -1, 6)])
		h._shape(["ki_bb_tail", sx], tl, Vector2(sx * 7, 10), Color("#E04A88"), 1.4)
		h._ball(Vector2(sx * 13, -3), 13, 9, PINK, sx * -0.3, 1.1, 0.5)
	h._ball(Vector2.ZERO, 5.5, 6, Color("#E04A88"), 0.0, 1.0, 0.6)
	# бубенчик
	var sw := sin(t * 3.0) * 0.2
	h._T = Transform2D(sw, Vector2(k, k), 0.0, c + Vector2(0, 6) * k)
	h._ball(Vector2(0, 9), 8.5, 8.5, GOLD, 0.0, 1.0, 0.95, 1.2)
	h._line(PackedVector2Array([Vector2(-6, 9), Vector2(6, 9)]), GOLD_D, 1.6)
	h._dot(Vector2(0, 13), 2.0, Color("#6A3E12"))
	h._line(PackedVector2Array([Vector2(0, 13), Vector2(0, 17)]), Color("#6A3E12"), 1.4)
	h._T = Transform2D.IDENTITY
	if fposmod(t, 2.4) < 0.4:
		h._sparkle(c + Vector2(10, 12) * k, 4.0 * sin(fposmod(t, 2.4) / 0.4 * PI), Color(1, 1, 0.85, 0.9))


## Камея на бархотке: чёрная бархатная ленточка, розовая камея с силуэтом котика в золотой рамке
static func cameo(h, a: Dictionary, t: float) -> void:
	var band := Sets._neck_curve(a, 13, -4.0, 0.92, 0.32)
	h.ci.draw_polyline(band, Color("#1E1430"), 8.0, true)
	h.ci.draw_polyline(band, Color("#3A2A5A"), 3.0, true)
	var c: Vector2 = band[6] + Vector2(0, 12)
	h._T = Transform2D(0.0, Vector2(1.35, 1.35), 0.0, c)
	var o := Vector2.ZERO
	h._ball(o, 13, 15, GOLD, 0.0, 1.0, 0.95, 1.2)
	for k in 12:
		var ang := k * TAU / 12.0
		h._dot(o + Vector2(cos(ang) * 12.0, sin(ang) * 14.0), 1.5, Color("#FFE89A"))
	h._ball(o, 10, 12, Color("#FFB3C8"), 0.0, 1.4, 0.6, 0.0)
	# силуэт котика (профиль): головка с ушком и тельце
	h._fill(PackedVector2Array([Vector2(-3, -8), Vector2(-2, -4), Vector2(1, -5), Vector2(3, -9), Vector2(4, -4), Vector2(5, 0),
		Vector2(3, 3), Vector2(5, 8), Vector2(-5, 8), Vector2(-4, 2), Vector2(-5, -2)]), Color("#FFF8FA"))
	h._ball(o + Vector2(0, 19), 3.5, 4.5, Color("#FFF6FA"), 0.0, 1.0, 1.0, 0.8)
	h._T = Transform2D.IDENTITY
	h._sparkle(c + Vector2(-7, -9), 2.5 + 2.0 * sin(t * 3.5), Color.WHITE)


# ==================== Туловище и хвост ====================

## Вязаный свитер: лавандовый, с косами, рядом сердечек, отворотом-горлом и резинкой снизу
static func sweater(h, c: Vector2, k: float, t: float) -> void:
	h._T = Transform2D(0.0, Vector2(k, k), 0.0, c)
	var lav := Color("#A98AF0")
	var key := ["ki_sweater"]
	var body := PackedVector2Array()
	if not h._cache.has(key):
		for i in 25:
			var ang := lerpf(-PI * 0.86, PI * 0.0, i / 24.0)
			body.append(Vector2(cos(ang) * 61.0, sin(ang) * 50.0 - 2.0))
		body.append(Vector2(62, 18))
		body.append(Vector2(52, 36))
		body.append(Vector2(-52, 36))
		body.append(Vector2(-62, 18))
		for i in 25:
			var ang := lerpf(PI * 1.0, PI * 1.14, i / 24.0)
			body.append(Vector2(cos(ang) * 61.0, sin(ang) * 50.0 - 2.0))
	h._shape(key, body, Vector2(0, -4), lav, 1.3, 0.35)
	# косы
	for x in [-30.0, 30.0]:
		for m in 5:
			var y := -36.0 + m * 12.0
			h._arc(Vector2(x - 3, y), 4, 6, -0.5 * PI, 0.5 * PI, Color("#7A5CC8", 0.7), 2.2, 6)
			h._arc(Vector2(x + 3, y + 6), 4, 6, 0.5 * PI, 1.5 * PI, Color("#C8B4FF", 0.8), 2.2, 6)
	# ряд сердечек
	for i in 3:
		var hp := Vector2(-14 + i * 14, -2)
		h._T = Transform2D(0.0, Vector2(k, k), 0.0, c) * Transform2D(0.0, hp)
		h._fill(h._heart(Vector2.ZERO, 5.0, 16), Color("#FF8FC0"))
		h._T = Transform2D(0.0, Vector2(k, k), 0.0, c)
	# резинка снизу
	var rib := PackedVector2Array([Vector2(-54, 24), Vector2(54, 24), Vector2(51, 36), Vector2(-51, 36)])
	h._vgrad(rib, Color("#9478E0"), Color("#7A5CC8"))
	for m in 15:
		var x := -48.0 + m * 6.9
		h._line(PackedVector2Array([Vector2(x, 26), Vector2(x, 34)]), Color("#C8B4FF", 0.6), 1.4)
	# горлышко
	h._ball(Vector2(0, -46), 40, 11, Color("#9478E0"), 0.0, 1.6, 0.35, 1.0)
	for m in 11:
		var x := -34.0 + m * 6.8
		h._line(PackedVector2Array([Vector2(x, -52), Vector2(x * 1.04, -40)]), Color("#C8B4FF", 0.5), 1.4)
	h._T = Transform2D.IDENTITY


## ЗВЁЗДНАЯ КОШКА — хвост из звёздной пыли: перелив и искры, которые осыпаются с хвоста
static func star_tail(h, t: float) -> void:
	var mid: PackedVector2Array = h._tail_mid
	var n := mid.size()
	if n < 4:
		return
	h._T = Transform2D.IDENTITY
	for i in range(2, n):
		var s := float(i) / (n - 1)
		var col := Sets.hsv(fposmod(0.55 + s * 0.4 - t * 0.12, 1.0), 0.5, 1.0)
		var wd: float = h._tail_w[i] if h._tail_w.size() > i else 13.0
		h._glow(mid[i], wd * 1.3, wd * 1.3, Color(col, snappedf(0.2 + 0.35 * s, 0.05)))
	for i in range(3, n, 2):
		var tw := 0.5 + 0.5 * sin(t * 4.0 + i * 1.3)
		var wd: float = h._tail_w[i] if h._tail_w.size() > i else 13.0
		var off := Vector2((hs(i, 1) - 0.5), (hs(i, 2) - 0.5)) * wd * 1.2
		h._sparkle(mid[i] + off, 3.0 + 4.0 * tw, Color(1, 1, 1, 0.5 + 0.5 * tw))
	# осыпающаяся звёздная пыль с кончика
	for k in 6:
		var ph := fposmod(t * 0.6 + k / 6.0, 1.0)
		var p: Vector2 = mid[n - 1] + Vector2(sin(ph * 5.0 + k) * 10.0, ph * 70.0 - 6.0)
		h._sparkle(p, 4.0 * (1.0 - ph) + 0.4, Sets.hsv(fposmod(k * 0.15 + t * 0.1, 1.0), 0.4, 1.0, 1.0 - ph))


# ==================== Спина ====================

# ==================== Спутники ====================

## Клубочек: лавандово-розовый, нитки-обмотка, спицы крест-накрест, кончик нитки вьётся
static func yarn(h, p: Vector2, t: float, react: float) -> void:
	var rot := t * 0.8
	if react >= 0.0 and react < 1.3:
		rot += sin(react / 1.3 * PI) * 2.0
	# хвостик нитки
	var tail := PackedVector2Array()
	for k in 10:
		var s := k / 9.0
		tail.append(p + Vector2(-14 - s * 34.0, 10 + sin(t * 3.0 + s * 5.0) * 7.0 * s + s * 10.0))
	h.ci.draw_polyline(tail, Color("#FF8FC0"), 3.0, true)
	h._T = Transform2D(0.0, p)
	# спицы позади
	h._line(PackedVector2Array([Vector2(-24, -20), Vector2(20, 22)]), Color("#C98A2E"), 3.0)
	h._line(PackedVector2Array([Vector2(22, -22), Vector2(-18, 20)]), Color("#C98A2E"), 3.0)
	h._ball(Vector2(-24, -20), 3.5, 3.5, Color("#FF5FA8"), 0.0, 1.0, 0.8, 0.8)
	h._ball(Vector2(22, -22), 3.5, 3.5, Color("#5FC8FF"), 0.0, 1.0, 0.8, 0.8)
	h._ball(Vector2.ZERO, 18, 18, Color("#FF9FC8"), 0.0, 1.0, 0.35, 1.2)
	h._T = Transform2D(rot, p)
	for k in 5:
		var ang := k * 0.65
		h._arc(Vector2.ZERO, 15, 6 + k * 1.5, PI + 0.3, TAU - 0.3, Color("#E06A9E", 0.8), 1.8, 10)
		h._T = Transform2D(rot + ang, p)
	h._T = Transform2D(-rot * 0.5, p)
	for k in 3:
		h._arc(Vector2.ZERO, 16, 9, 0.15 * PI, 0.85 * PI, Color("#FFD0E4", 0.8), 1.6, 8)
		h._T = Transform2D(-rot * 0.5 + 0.9 * (k + 1), p)
	h._T = Transform2D.IDENTITY
	h._dot(p + Vector2(-6, -7), 3.0, Color(1, 1, 1, 0.5))


## ЧАЙНАЯ ЧАШЕЧКА (легендарная): фарфоровая с золотой каёмкой и мордашкой, пар — сердечками
static func teacup(h, p: Vector2, t: float, react: float) -> void:
	var happy := react >= 0.0 and react < 1.3
	h._glow(p, 40, 34, Color(1.0, 0.8, 0.9, 0.3))
	# пар сердечками
	for k in 3:
		var q := fposmod(t * 0.35 + k / 3.0, 1.0)
		var sp := p + Vector2(sin(q * 6.0 + k * 2.0) * 7.0, -18.0 - q * 44.0)
		var al := sin(q * PI)
		h._T = Transform2D(0.0, Vector2(0.6 + q * 0.5, 0.6 + q * 0.5), 0.0, sp)
		h._fill(h._heart(Vector2.ZERO, 6.0, 16), Color(1.0, 0.75, 0.88, 0.75 * al))
		h._T = Transform2D.IDENTITY
	h._T = Transform2D(sin(t * 1.2) * 0.06, p)
	# блюдце
	h._ball(Vector2(0, 18), 30, 7, Color("#FFF4FA"), 0.0, 1.3, 0.8, 1.0)
	h._arc(Vector2(0, 18), 27, 5, 0.05 * PI, 0.95 * PI, GOLD, 1.6, 10)
	# ручка
	h._arc(Vector2(21, 2), 8, 8, -0.5 * PI, 0.55 * PI, Color("#F2D8E6"), 4.2, 10)
	h._arc(Vector2(21, 2), 8, 8, -0.5 * PI, 0.55 * PI, GOLD, 1.4, 10)
	# чашка
	var cup := PackedVector2Array([Vector2(-22, -10)])
	for k in 11:
		var ang := lerpf(PI, 0.0, k / 10.0)
		cup.append(Vector2(-cos(ang) * 21.0 * (1.0 - 0.0), 2 + sin(ang) * 15.0))
	cup.append(Vector2(22, -10))
	h._shape(["ki_cup"], cup, Vector2(0, 0), Color("#FFC8DE"), 1.3, 0.8)
	h._ball(Vector2(0, -10), 22, 5, Color("#C98A6A"), 0.0, 1.6, 0.6, 0.0)
	h._arc(Vector2(0, -10), 22, 5, 0, TAU, GOLD, 2.0, 18)
	# мордашка
	if happy:
		h._arc(Vector2(-7, 3), 3.0, 2.6, 1.1 * PI, 1.9 * PI, Color("#4A1A2A"), 1.6, 6)
		h._arc(Vector2(7, 3), 3.0, 2.6, 1.1 * PI, 1.9 * PI, Color("#4A1A2A"), 1.6, 6)
	else:
		h._dot(Vector2(-7, 2), 2.2, Color("#4A1A2A"))
		h._dot(Vector2(7, 2), 2.2, Color("#4A1A2A"))
		h._dot(Vector2(-7.7, 1.2), 0.8, Color.WHITE)
		h._dot(Vector2(6.3, 1.2), 0.8, Color.WHITE)
	h._arc(Vector2(0, 6), 2.6, 2.0, 0.15 * PI, 0.85 * PI, Color("#4A1A2A"), 1.3, 6)
	h._glow(Vector2(-13, 7), 3.5, 2.2, Color(1.0, 0.4, 0.55, 0.65))
	h._glow(Vector2(13, 7), 3.5, 2.2, Color(1.0, 0.4, 0.55, 0.65))
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(-16, -8), 3.5 + 2.5 * sin(t * 4.0), Color.WHITE)


# ==================== Сияния ====================

## ПРАЗДНИЧНЫЙ САЛЮТ (легендарное): вокруг котика распускаются пастельные искры-салюты
static func fireworks(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front:
		h._glow(c, R * 1.35, R * 1.35, Color(0.95, 0.6, 1.0, 0.15))
	var cols := [Color("#FF8FC0"), Color("#9FE8FF"), Color("#FFE680"), Color("#C8A4FF")]
	for b in 4:
		if (b % 2 == 1) != front:
			continue
		var per := 2.4
		var ph := fposmod(t / per + b * 0.25, 1.0)
		var cyc := floorf(t / per + b * 0.25)
		var bc := c + Vector2((hs(cyc + b * 7, 1) - 0.5) * R * 2.2, -R * 0.6 - hs(cyc + b * 7, 2) * R * 0.7)
		var col: Color = cols[b]
		if ph < 0.25:
			# взлёт
			var k := ph / 0.25
			var st := Vector2(bc.x, c.y + R * 0.9)
			var q := st.lerp(bc, k)
			h.ci.draw_line(q, q + Vector2(0, 14), Color(col, 0.6), 2.4, true)
			h._sparkle(q, 3.0, Color(1, 1, 1, 0.9))
		else:
			var k := (ph - 0.25) / 0.75
			var al := 1.0 - k
			h._glow(bc, R * 0.45 * k + 4.0, R * 0.45 * k + 4.0, Sets.q(Color(col, snappedf(0.35 * al, 0.05))))
			for m in 12:
				var ang := m * TAU / 12.0 + b
				var d := Vector2(cos(ang), sin(ang))
				var p := bc + d * R * 0.55 * sqrt(k) + Vector2(0, k * k * 18.0)
				h.ci.draw_line(p - d * 12.0 * al, p, Color(col, al * 0.9), 3.0, true)
				h._dot(p, 3.2 * al + 0.5, Color(col.lerp(Color.WHITE, 0.5), al))
				if m % 3 == 0:
					h._sparkle(p, 5.0 * al, Color(1, 1, 1, al))
			if k < 0.5:
				h._sparkle(bc, 10.0 * (1.0 - k * 2.0), Color(1, 1, 1, al))


## ЗВЁЗДНАЯ КОШКА — светящиеся бабочки порхают вокруг, за ними — пыльца
static func butterflies(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front and a.kind != "icon":
		h._glow(c, R * 1.4, R * 1.4, Color(0.75, 0.6, 1.0, 0.18))
		h._glow(c + Vector2(0, -R * 0.5), R * 1.0, R * 0.7, Color(1.0, 0.7, 0.95, 0.12))
	var cols := [Color("#9FE8FF"), Color("#FF9FD8"), Color("#FFE680"), Color("#C8A4FF")]
	for i in 4:
		var ang := t * 0.45 + i * TAU / 4.0
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var p := c + Vector2(cos(ang) * R * 1.28, -R * 0.45 + (i % 2) * R * 0.55 + sin(t * 2.2 + i) * 12.0 + z * R * 0.1)
		for k in range(1, 5):
			var ap := t * 0.45 - k * 0.05 + i * TAU / 4.0
			var q := c + Vector2(cos(ap) * R * 1.28, -R * 0.45 + (i % 2) * R * 0.55 + sin((t - k * 0.05) * 2.2 + i) * 12.0 + sin(ap) * R * 0.1)
			h._dot(q, 2.2 - k * 0.4, Color(cols[i], 0.5 - k * 0.1))
		_butterfly(h, p, (0.8 + 0.25 * z) * (1.45 if a.kind != "icon" else 1.0), cols[i], t * 9.0 + i, -0.3 if cos(ang) > 0.0 else 0.3)


static func _butterfly(h, p: Vector2, s: float, col: Color, ph: float, rot: float) -> void:
	var fl := 0.35 + 0.65 * absf(sin(ph))
	h._glow(p, 22 * s, 20 * s, Sets.q(Color(col, 0.4)))
	h._T = Transform2D(rot, Vector2(s * fl, s), 0.0, p)
	for sx in [-1.0, 1.0]:
		h._ball(Vector2(sx * 8, -5), 9, 7, col.lerp(Color.WHITE, 0.35), sx * -0.5, 1.2, 0.6, 0.8)
		h._ball(Vector2(sx * 6, 6), 6, 5, col, sx * 0.4, 1.2, 0.6, 0.8)
		h._dot(Vector2(sx * 9, -6), 2.0, Color(1, 1, 1, 0.9))
	h._T = Transform2D(rot, Vector2(s, s), 0.0, p)
	h._ball(Vector2.ZERO, 2.2, 8, Color("#4A3A78"), 0.0, 1.0, 0.5, 0.0)
	h._line(PackedVector2Array([Vector2(0, -7), Vector2(-4, -13)]), Color("#4A3A78"), 1.0)
	h._line(PackedVector2Array([Vector2(0, -7), Vector2(4, -13)]), Color("#4A3A78"), 1.0)
	h._T = Transform2D.IDENTITY
