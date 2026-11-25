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
			a.back = Vector2(0, -30)
			a.back_w = 150.0
			a.neck = Vector2(0, -78)
			a.neck_w = 150.0
			trench(h, a, t, true)
			trench(h, a, t, false)
			return true
		"ki_moustache":
			a.eye_l = Vector2(-44, -64)
			a.eye_r = Vector2(44, -64)
			a.eye_rad = 56.0
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

## Ошейник с бубенчиком (0.13: без банта): мягкий красный ремешок со строчкой, колечко и золотой бубенчик
static func bell_bow(h, a: Dictionary, t: float) -> void:
	var band := Sets._neck_curve(a, 13, -2.0, 0.94, 0.35)
	h.ci.draw_polyline(band, Color("#9E2236"), 11.0, true)
	h.ci.draw_polyline(band, Color("#E8455C"), 7.5, true)
	var st := PackedVector2Array()
	for v in band:
		st.append(v + Vector2(0, -1))
	for i in range(0, st.size() - 1, 2):
		h.ci.draw_line(st[i], st[i].lerp(st[i + 1], 0.6), Color(1, 1, 1, 0.45), 1.3, true)
	var c: Vector2 = band[6] + Vector2(0, 3)
	var k: float = a.neck_w / 118.0
	h._T = Transform2D(0.0, Vector2(k, k), 0.0, c)
	h._arc(Vector2(0, 2), 4.5, 4.5, 0, TAU, GOLD_D, 2.2, 12)
	# бубенчик
	var sw := sin(t * 3.0) * 0.2
	h._T = Transform2D(sw, Vector2(k, k), 0.0, c + Vector2(0, 5) * k)
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


# ==================== 0.13: «Кот-детектив» ====================

const TWEED := Color("#B98A52")
const TWEED_D := Color("#7A5230")
const COAT := Color("#B4A27A")
const COAT_D := Color("#6E5E40")


## Кепи сыщика: клетчатая шапочка с двумя козырьками (спереди и сзади) и ушками-клапанами,
## завязанными наверху на пуговку
static func sleuth_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(-0.08, Vector2(1.18, 1.18), 0.0, Vector2(0, 6))
	# задний козырёк выглядывает из-за шапочки
	h._ball(Vector2(0, 4), 50, 9, TWEED_D, 0.0, 1.5, 0.4)
	var dome := PackedVector2Array()
	for i in 19:
		var ang := PI + PI * i / 18.0
		dome.append(Vector2(cos(ang) * 45, 10 + sin(ang) * 36))
	h._shape(["ki_sleuth_dome"], dome, Vector2(-8, -8), TWEED, 1.2, 0.35)
	# клетка: тёмные и светлые полосы по куполу
	for k in 5:
		var x := -32.0 + k * 16.0
		var top := 10.0 - 36.0 * sqrt(maxf(0.0, 1.0 - pow(x / 45.0, 2))) + 3.0
		h._line(PackedVector2Array([Vector2(x, top), Vector2(x * 1.04, 8)]), Color(TWEED_D, 0.55), 2.6)
	for k in 3:
		var y := -2.0 - k * 10.0
		var hw := 45.0 * sqrt(maxf(0.0, 1.0 - pow((10.0 - y) / 36.0, 2))) - 2.0
		h._line(PackedVector2Array([Vector2(-hw, y), Vector2(0, y - 2), Vector2(hw, y)]), Color(TWEED_D, 0.5), 2.4)
		h._line(PackedVector2Array([Vector2(-hw, y + 4), Vector2(0, y + 2), Vector2(hw, y + 4)]), Color("#F0D29A", 0.35), 1.2)
	# ушки-клапаны, поднятые и завязанные наверху
	for sx in [-1.0, 1.0]:
		var fl := PackedVector2Array([Vector2(sx * 6, -30), Vector2(sx * 30, -22), Vector2(sx * 34, -10), Vector2(sx * 20, -10), Vector2(sx * 4, -24)])
		h._shape(["ki_sleuth_flap", sx], h._chaikin(fl, 2), Vector2(sx * 20, -18), TWEED.lightened(0.08), 1.4, 0.35)
		h._line(PackedVector2Array([Vector2(sx * 8, -28), Vector2(sx * 26, -16)]), Color(TWEED_D, 0.5), 1.6)
	h._ball(Vector2(0, -33), 6, 5, Color("#5A3A22"), 0.0, 1.0, 0.6, 1.0)
	h._line(PackedVector2Array([Vector2(-8, -30), Vector2(0, -33), Vector2(8, -30)]), Color("#5A3A22"), 2.2)
	# передний козырёк
	h._ball(Vector2(0, 12), 40, 8, TWEED_D.lightened(0.05), 0.0, 1.5, 0.45)
	h._arc(Vector2(0, 10), 36, 5, 1.1 * PI, 1.9 * PI, Color(1, 1, 1, 0.3), 1.8, 10)
	h._T = Transform2D.IDENTITY


## ЗВЁЗДНЫЙ КОТ — звёздная корона: золотой обруч с тремя лучами-зубцами, звёздочками и кристаллом
static func star_crown(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(0.0, Vector2(1.2, 1.2), 0.0, Vector2(0, 6))
	var band := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		band.append(Vector2(cos(ang) * 42, 8 + sin(ang) * 8))
	var pts := PackedVector2Array()
	var spikes := [[-30.0, 22.0], [0.0, 34.0], [30.0, 22.0]]
	pts.append(Vector2(-42, 10))
	pts.append(Vector2(-40, -4))
	for sp in spikes:
		var x: float = sp[0]
		var hh: float = sp[1]
		pts.append(Vector2(x - 11, -6 - absf(x) * 0.12))
		pts.append(Vector2(x, -6 - hh))
		pts.append(Vector2(x + 11, -6 - absf(x) * 0.12))
	pts.append(Vector2(40, -4))
	pts.append(Vector2(42, 10))
	pts.append(Vector2(0, 14))
	h._shape(["ki_star_crown"], h._chaikin(pts, 1), Vector2(0, -6), GOLD, 1.2, 0.9)
	h._line(band, Color("#FFE89A"), 3.0)
	for i in 3:
		var sp: Array = spikes[i]
		var tip := Vector2(sp[0], -6 - sp[1] - 4)
		var tw := 0.5 + 0.5 * sin(t * 4.0 + i * 2.0)
		h._fill(Sets.star_pts(tip, 6.5 + tw * 1.5, 2.8, 5, 0.0), Color("#FFF6C8"))
	for x in [-24.0, 24.0]:
		h._gem(Vector2(x, 2), 3.8, Color("#9FE8FF"))
	var hh2 := fposmod(t * 0.12, 1.0)
	var cc := Sets.hsv(0.55 + 0.25 * sin(hh2 * TAU), 0.45, 1.0)
	h._glow(Vector2(0, -8), 18, 18, Color(cc, 0.4))
	h._gem(Vector2(0, -6), 9.0, cc)
	h._T = Transform2D.IDENTITY
	h._sparkle(h._hv(a, Vector2(-30, -46)), 5.0 + 3.0 * sin(t * 4.0), Color.WHITE)


## Усы-щёточки: пышные каштановые усы под носиком, кончики подкручены вверх
static func moustache(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var k := r / 25.0
	var at: Vector2 = mid + Vector2(0, r * 1.38).rotated(a.tilt)
	var wig := sin(t * 2.0) * 0.05
	for sx in [-1.0, 1.0]:
		var key := ["ki_moustache3", sx]
		var pts := PackedVector2Array()
		if not h._cache.has(key):
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			for i in 13:
				var s := i / 12.0
				var x: float = sx * (1.0 + s * 29.0)
				var y := -pow(s, 3.0) * 11.0 + sin(s * PI) * 2.5
				var th := 15.0 * pow(sin(minf(s * 1.6, 1.0) * PI * 0.5), 0.5) * (1.0 - s * 0.8) + 2.0
				top.append(Vector2(x, y - th * 0.45))
				bot.append(Vector2(x, y + th * 0.75))
			bot.reverse()
			pts = top
			pts.append_array(bot)
		h._T = Transform2D(a.tilt + sx * wig, Vector2(k, k), 0.0, at)
		h._shape(key, pts, Vector2(sx * 11, 1), Color("#6E4026"), 1.2, 0.45, 1.6)
		# щёточка: светлые штрихи
		for m in 4:
			var x: float = sx * (5.0 + m * 6.5)
			h._line(PackedVector2Array([Vector2(x, 5.0 - m * 1.2), Vector2(x + sx * 3.0, -1.5 - m * 1.8)]), Color("#B07A4E", 0.75), 1.5)
	h._T = Transform2D.IDENTITY


## Значок сыщика: золотой щиток с лупой на кожаном шнурке
static func sleuth_badge(h, a: Dictionary, t: float) -> void:
	var band := Sets._neck_curve(a, 13, -4.0, 0.9, 0.34)
	h.ci.draw_polyline(band, Color("#4A2E1A"), 6.0, true)
	h.ci.draw_polyline(band, Color("#8A5A34"), 2.4, true)
	var c: Vector2 = band[6] + Vector2(0, 13)
	h._T = Transform2D(sin(t * 1.8) * 0.06, Vector2(1.3, 1.3), 0.0, c)
	var sh := PackedVector2Array([Vector2(-12, -12), Vector2(-4, -14), Vector2(0, -16), Vector2(4, -14), Vector2(12, -12), Vector2(12, 0), Vector2(6, 9), Vector2(0, 13), Vector2(-6, 9), Vector2(-12, 0)])
	h._shape(["ki_badge"], h._chaikin(sh, 1), Vector2(0, -2), GOLD, 1.1, 0.95, 1.3)
	var inner := PackedVector2Array()
	for v in h._chaikin(sh, 1):
		inner.append(v * 0.68 + Vector2(0, -0.6))
	h._fill(inner, Color("#2E4A8A"))
	# лупа на щитке
	h._arc(Vector2(-1.5, -3), 4.2, 4.2, 0, TAU, Color("#FFE89A"), 1.8, 14)
	h._line(PackedVector2Array([Vector2(1.5, 0.5), Vector2(5.5, 5)]), Color("#FFE89A"), 2.2)
	h._T = Transform2D.IDENTITY
	h._sparkle(c + Vector2(-9, -12), 2.5 + 2.0 * sin(t * 3.5), Color.WHITE)


## Плащ-тренч: песочный, с поднятым воротником за головой, поясом и пуговицами;
## спереди — отвороты-лацканы у шеи
static func trench(h, a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if not behind:
		var n: Vector2 = a.neck
		for sx in [-1.0, 1.0]:
			var lap := PackedVector2Array([n + Vector2(sx * w * 0.06, -6), n + Vector2(sx * w * 0.44, -10), n + Vector2(sx * w * 0.4, w * 0.1), n + Vector2(sx * w * 0.2, w * 0.1), n + Vector2(sx * w * 0.04, w * 0.24)])
			h._shape(null, h._chaikin(lap, 1), n + Vector2(sx * w * 0.24, w * 0.06), COAT, 1.5, 0.35, 1.6)
			h.ci.draw_polyline(PackedVector2Array([lap[2], lap[3], lap[4]]), COAT_D, 2.0, true)
			h._ball(n + Vector2(sx * w * 0.3, w * 0.16), 3.6, 3.6, Color("#3E2A18"), 0.0, 1.0, 0.6, 0.8)
		return
	# поднятый воротник-стойка за головой (два уголка; на значке — без него)
	var cl := PackedVector2Array()
	for sx in ([] if a.kind == "icon" else [-1.0, 1.0]):
		cl.clear()
		cl.append(b + Vector2(sx * w * 0.12, -w * 0.2))
		cl.append(b + Vector2(sx * w * 0.5, -w * 0.5))
		cl.append(b + Vector2(sx * w * 0.84, -w * 0.56))
		cl.append(b + Vector2(sx * w * 0.74, -w * 0.18))
		cl.append(b + Vector2(sx * w * 0.42, w * 0.02))
		h._shape(null, h._chaikin(cl, 1), b + Vector2(sx * w * 0.48, -w * 0.22), COAT.darkened(0.1), 1.5, 0.35, 1.6)
	var sway := sin(t * 1.4) * 3.0
	var res := Sets._cape_pts(a, 1.2, 0.66, func(s: float) -> float: return sin(s * TAU * 1.5 + t * 1.4) * 2.5 + (sway if s > 0.5 else -sway) * s)
	Sets._cape_fill(h, a, res[0], COAT.lightened(0.05), COAT_D.darkened(0.1))
	var hem: PackedVector2Array = res[1]
	# складки, шлица, пояс с хвостиками
	for i in [3, 8, 13]:
		var hp: Vector2 = hem[i]
		h.ci.draw_line(Vector2(hp.x * 0.85 + b.x * 0.15, b.y - w * 0.05), hp + Vector2(0, -4), Color(0.35, 0.2, 0.05, 0.25), 6.0, true)
	h.ci.draw_polyline(hem, COAT_D.darkened(0.2), 5.0, true)
	var by := b.y + w * 0.3
	for sx in [-1.0, 1.0]:
		var bx: float = b.x + sx * w * 0.64
		var bl := PackedVector2Array([Vector2(bx, by), Vector2(bx + sx * w * 0.06, by + w * 0.16 + sway * 0.5), Vector2(bx + sx * w * 0.02, by + w * 0.3)])
		h.ci.draw_polyline(bl, COAT_D.darkened(0.15), 7.0, true)
		h.ci.draw_polyline(bl, COAT_D, 4.0, true)
	h.ci.draw_line(Vector2(b.x - w * 0.66, by), Vector2(b.x + w * 0.66, by), COAT_D.darkened(0.15), 8.0, true)
	h.ci.draw_line(Vector2(b.x - w * 0.66, by - 1), Vector2(b.x + w * 0.66, by - 1), COAT_D, 4.0, true)


## Лупа (спутник): латунная оправа, стекло с бегущим бликом и следом лапки внутри,
## деревянная ручка; при касании — «приближает» (увеличивается) и блестит
static func magnifier(h, p: Vector2, t: float, react: float) -> void:
	var zoom := 1.0
	if react >= 0.0 and react < 1.3:
		zoom += 0.22 * sin(react / 1.3 * PI)
	h._T = Transform2D(-0.5 + sin(t * 1.1) * 0.12, Vector2(zoom, zoom), 0.0, p)
	# ручка
	h._shape(["ki_mag_handle"], h._rrect(Rect2(-5, 20, 10, 30), 5), Vector2(0, 35), Color("#8A4E28"), 1.2, 0.5, 1.2)
	h._ball(Vector2(0, 20), 6, 4, GOLD_D, 0.0, 1.0, 0.8, 1.0)
	h._ball(Vector2(0, 48), 5.5, 4, GOLD_D, 0.0, 1.0, 0.8, 1.0)
	# стекло
	h._glow(Vector2.ZERO, 26, 26, Color(0.75, 0.95, 1.0, 0.35))
	h._vgrad(h._ell(Vector2.ZERO, 17, 17, 0.0, 28), Color(0.8, 0.96, 1.0, 0.55), Color(0.55, 0.8, 1.0, 0.35))
	# увеличенный след лапки внутри
	var pc := Color("#5A3A6A", 0.55)
	h._oval(Vector2(0, 4), 6.0, 5.0, pc)
	for k in 4:
		h._oval(Vector2((k - 1.5) * 5.2, -4.0 + absf(k - 1.5) * 1.6), 2.3, 2.7, pc)
	# бегущий блик
	var ph := fposmod(t * 0.4, 1.0)
	var gx := lerpf(-14.0, 14.0, ph)
	h._line(PackedVector2Array([Vector2(gx - 5, 10), Vector2(gx + 5, -10)]), Color(1, 1, 1, 0.55 * sin(ph * PI)), 3.0)
	h._arc(Vector2.ZERO, 12, 12, 1.1 * PI, 1.45 * PI, Color(1, 1, 1, 0.8), 2.4, 8)
	# латунная оправа
	h._arc(Vector2.ZERO, 18.5, 18.5, 0, TAU, GOLD_D, 6.0, 32)
	h._arc(Vector2.ZERO, 18.5, 18.5, 0, TAU, GOLD, 3.4, 32)
	h._arc(Vector2.ZERO, 18.5, 18.5, 1.05 * PI, 1.5 * PI, Color("#FFF2B8"), 1.6, 10)
	h._T = Transform2D.IDENTITY
	if zoom > 1.05:
		h._sparkle(p + Vector2(-10, -12), 8.0 * (zoom - 1.0) * 4.0, Color.WHITE)


## ТАЙНА СЛЕДОВ (легендарное): светящиеся следы лапок обходят героя по кругу и гаснут,
## над героем покачиваются золотые знаки «?», позади — тёплый луч фонарика
static func clue_trail(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	var icon: bool = a.kind == "icon"
	if not front:
		h._glow(c + Vector2(0, -R * 0.1), R * 1.35, R * 1.25, Color(1.0, 0.85, 0.5, 0.16))
		h._glow(c + Vector2(-R * 0.2, -R * 0.5), R * 0.8, R * 0.5, Color(1.0, 0.95, 0.7, 0.12), -0.5)
	# следы по эллипсу: «шагают» друг за другом, у каждого свой возраст
	var n := 10
	var head := t * 0.9
	for i in n:
		var u := floorf(head) - i
		var age := (head - floorf(head) + i) / n
		var ang := u * 0.62
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var side := 1.0 if int(u) % 2 == 0 else -1.0
		var pos := c + Vector2(cos(ang) * R * 1.22, R * 0.62 + z * R * 0.22)
		var dir := Vector2(-sin(ang), cos(ang) * 0.3).normalized()
		pos += dir.orthogonal() * side * R * 0.06
		var al := (1.0 - age) * (0.65 + 0.35 * z if front else 0.5)
		_paw_print(h, pos, R * (0.16 if not icon else 0.2) * (0.85 + 0.2 * z), dir.angle() + PI / 2.0, Color(1.0, 0.84, 0.4, minf(1.0, al * 1.3)))
	if front:
		# знаки вопроса
		for k in 2:
			var ph := fposmod(t * 0.25 + k * 0.5, 1.0)
			var q := c + Vector2((k * 2 - 1) * R * (0.95 + 0.1 * sin(t + k)), -R * (0.9 + ph * 0.4))
			var al2 := sin(ph * PI)
			_question(h, q, R * (0.16 if not icon else 0.22), Color(1.0, 0.85, 0.35, al2))


static func _paw_print(h, p: Vector2, s: float, rot: float, col: Color) -> void:
	if col.a < 0.03:
		return
	h._glow(p, s * 2.2, s * 2.2, Sets.q(Color(col, col.a * 0.35)))
	h._T = Transform2D(rot, Vector2(s / 10.0, s / 10.0), 0.0, p)
	h._oval(Vector2(0, 3), 7.0, 6.0, col)
	for k in 4:
		h._oval(Vector2((k - 1.5) * 6.0, -6.0 + absf(k - 1.5) * 2.0), 2.6, 3.2, col)
	h._T = Transform2D.IDENTITY


static func _question(h, p: Vector2, s: float, col: Color) -> void:
	if col.a < 0.03:
		return
	h._glow(p, s * 1.8, s * 2.2, Sets.q(Color(col, col.a * 0.3)))
	h._T = Transform2D(0.0, Vector2(s / 10.0, s / 10.0), 0.0, p)
	var arc := PackedVector2Array()
	for i in 10:
		var ang := lerpf(PI * 1.05, PI * 2.35, i / 9.0)
		arc.append(Vector2(cos(ang) * 6.5, -6 + sin(ang) * 6.5))
	arc.append(Vector2(0, 4))
	h._line(arc, Color(0.35, 0.18, 0.05, col.a * 0.6), 5.0)
	h._line(arc, col, 3.4)
	h._dot(Vector2(0, 10), 2.4, col)
	h._T = Transform2D.IDENTITY


## ЗВЁЗДНЫЙ КОТ — кометы: звёздочки с хвостами облетают героя (у кошечки вместо них — бабочки)
static func comets(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front and a.kind != "icon":
		h._glow(c, R * 1.4, R * 1.4, Color(0.6, 0.7, 1.0, 0.18))
		h._glow(c + Vector2(0, -R * 0.5), R * 1.0, R * 0.7, Color(0.7, 0.85, 1.0, 0.12))
	var cols := [Color("#9FE8FF"), Color("#FFE680"), Color("#C8A4FF"), Color("#FFFFFF")]
	for i in 4:
		var ang := t * 0.55 + i * TAU / 4.0
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var orbit := func(a2: float) -> Vector2: return c + Vector2(cos(a2) * R * 1.28, -R * 0.45 + (i % 2) * R * 0.55 + sin(a2) * R * 0.12)
		var p: Vector2 = orbit.call(ang)
		for k in range(1, 7):
			var q: Vector2 = orbit.call(ang - k * 0.07)
			h._dot(q, (3.4 - k * 0.45) * (1.0 if a.kind != "icon" else 0.7), Color(cols[i], 0.55 - k * 0.08))
		var sc := (0.8 + 0.25 * z) * (1.0 if a.kind != "icon" else 0.7)
		h._glow(p, 16 * sc, 16 * sc, Sets.q(Color(cols[i], 0.45)))
		h._fill(Sets.star_pts(p, 9.0 * sc, 4.0 * sc, 5, t * 1.5 + i), cols[i].lerp(Color.WHITE, 0.3))
		h._dot(p, 2.2 * sc, Color.WHITE)
