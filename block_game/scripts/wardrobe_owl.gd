extends RefCounted
## Cascado 0.12b: гардероб СОВЁНКА — учёный и ночной волшебник. Рисуется только на совёнке
## (точки крепления — hero.gd, _anchors "owl"); через помощников героя h (h._ball, h._shape, h._line...).
## Наборы: «Библиотека совы», «Ночной дозор», «Обсерватория»; награды кузницы — Вихрь страниц,
## Ночное небо, Ручная комета; супер-эксклюзив — Мантия звездочёта (мантия, колпак, планеты, сияющие глаза).
## Этапы рисования (stage): back_b / back_f — спина позади / спереди, neck, eyes, head,
## worn — части супер-эксклюзива поверх головы (видны и на аватарке).

const Sets := preload("res://scripts/hero_sets.gd")

const GOLD := Color("#FFC83A")
const GOLD_D := Color("#B8771A")
const NAVY := Color("#2C3184")
const INK := Color("#1E1A4A")


static func hs(i: float, k := 0.0) -> float:
	return Sets.hs(i, k)


static func item(h, id: String, stage: String, a: Dictionary, t: float) -> void:
	match id:
		"ow_mortarboard":
			if stage == "head":
				mortarboard(h, a, t)
		"ow_halfglasses":
			if stage == "eyes":
				halfglasses(h, a, t)
		"ow_scholar_scarf":
			if stage == "neck":
				h._scarf(a, [Color("#2E3C9E"), Color("#FFC83A"), Color("#8E2A5E")], Color("#FFE27A"))
				_scarf_pin(h, a, t)
		"ow_quill":
			if stage == "head":
				quill(h, a, t)
		"ow_lantern":
			if stage == "back_f":
				lantern(h, Vector2(106, 100) if a.kind != "icon" else Vector2(0, 10), 1.0 if a.kind != "icon" else 2.2, t, a.kind != "icon")
		"ow_night_goggles":
			if stage == "eyes":
				night_goggles(h, a, t)
		"ow_dome_hat":
			if stage == "head":
				dome_hat(h, a, t)
		"ow_stargazer":
			if stage == "worn":
				wizard_hat(h, a, t)
				if a.kind != "icon":
					_glow_eyes(h, a, t)


static func companion(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	match id:
		"ow_book":
			if front:
				book(h, a.comp + Vector2(sin(t * 0.9) * 10.0, sin(t * 1.7) * 8.0), t, react)
		"ow_comet":
			comet(h, a, t, front)


static func aura(h, id: String, a: Dictionary, t: float, react: float, front: bool) -> void:
	match id:
		"ow_page_whirl":
			page_whirl(h, a, t, front)
		"ow_stargazer":
			if not front and a.kind != "icon" and a.has("back"):
				stargazer_mantle(h, a, t)
			planets(h, a, t, front)


## Свой значок для вещей, которые сидят «по анатомии» (фонарь на крыле)
static func icon(h, id: String, slot: String, a: Dictionary, t: float) -> bool:
	match id:
		"ow_lantern":
			lantern(h, Vector2(0, 14), 2.3, t, false)
			return true
		"ow_mortarboard":
			a.top = Vector2(0, 4)
			a.top_w = 140.0
			mortarboard(h, a, t)
			return true
		"ow_dome_hat":
			a.top = Vector2(-4, 34)
			a.top_w = 140.0
			dome_hat(h, a, t)
			return true
		"ow_quill":
			a.top = Vector2(-62, 50)
			a.top_w = 130.0
			quill(h, a, t)
			return true
		"ow_halfglasses":
			a.eye_l = Vector2(-50, -6)
			a.eye_r = Vector2(50, -6)
			a.eye_rad = 42.0
			halfglasses(h, a, t)
			return true
	return false


# ==================== Голова ====================

## Академическая шапочка: тёмно-синяя, квадратная доска, золотая пуговка и кисточка качается
static func mortarboard(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var cap := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		cap.append(Vector2(cos(ang) * 44, 6 + sin(ang) * 24))
	cap.append(Vector2(40, 12))
	cap.append(Vector2(-40, 12))
	h._shape(["ow_mb_cap"], cap, Vector2(0, -2), NAVY, 1.3, 0.5)
	h._line(PackedVector2Array([Vector2(-42, 8), Vector2(0, 12), Vector2(42, 8)]), Color("#4A52C0"), 4.0)
	# доска: толщина, верх с градиентом и светлой кромкой
	var L := Vector2(-66, -24)
	var T := Vector2(0, -40)
	var R := Vector2(66, -24)
	var B := Vector2(0, -8)
	var th := Vector2(0, 7)
	h._fill(PackedVector2Array([L, B, R, R + th, B + th, L + th]), INK)
	h._vgrad(PackedVector2Array([L, T, R, B]), Color("#4C55C8"), Color("#2A2E7A"))
	h._line(PackedVector2Array([L, T, R]), Color("#8D96FF", 0.8), 2.4)
	h._line(PackedVector2Array([L, B, R]), Color("#14123A", 0.6), 1.6)
	# кисточка на шнурке от пуговки к углу, свисает и качается
	var sw := sin(t * 2.1) * 0.16
	var corner := R + Vector2(-6, 1)
	h._line(PackedVector2Array([Vector2(0, -24), Vector2(30, -22), corner]), Color("#E0A63C"), 3.0)
	var hang := corner + Vector2(0, 30).rotated(sw)
	h._line(PackedVector2Array([corner, corner.lerp(hang, 0.5) + Vector2(1, 0), hang]), Color("#E0A63C"), 3.0)
	h._ball(hang + Vector2(0, 9).rotated(sw), 6.5, 12, GOLD, sw, 1.1, 0.8, 1.0)
	h._T = h._head_T(a) * Transform2D(sw, hang + Vector2(0, 9).rotated(sw))
	for k in 3:
		h._line(PackedVector2Array([Vector2(-4 + k * 4, 4), Vector2(-4 + k * 4, 12)]), GOLD_D, 1.4)
	h._line(PackedVector2Array([Vector2(-6, -4), Vector2(6, -4)]), GOLD_D, 2.2)
	h._T = h._head_T(a)
	h._ball(Vector2(0, -24), 5.5, 4, GOLD, 0.0, 1.0, 0.9, 1.0)
	h._sparkle(Vector2(-34, -30), 3.0 + 2.0 * sin(t * 3.0), Color(1, 1, 1, 0.8))
	h._T = Transform2D.IDENTITY


## Перо-хохолок: длинное синее перо с серебряными звёздами, приколото брошью-полумесяцем
static func quill(h, a: Dictionary, t: float) -> void:
	var rot := 0.42 + sin(t * 1.4) * 0.06
	var base := Vector2(30, 6)
	h._T = h._head_T(a) * Transform2D(rot, base)
	var key := ["ow_quill_vane"]
	var vane := PackedVector2Array()
	if not h._cache.has(key):
		for i in 13:
			var s := i / 12.0
			vane.append(Vector2(-15.0 * sin(PI * pow(s, 0.75)) * (1.0 - 0.2 * s) - 2.0, -s * 92.0))
		for i in range(12, -1, -1):
			var s := i / 12.0
			vane.append(Vector2(11.0 * sin(PI * pow(s, 0.8)) + 2.0, -s * 92.0 - 4.0 * sin(PI * s)))
	h._shape(key, vane, Vector2(-1, -46), Color("#3E46B8"), 1.6, 0.5)
	# светлый кончик и бородки
	h._glow(Vector2(-2, -80), 9, 14, Color(0.75, 0.85, 1.0, 0.55))
	for k in 6:
		var y := -18.0 - k * 12.0
		h._line(PackedVector2Array([Vector2(0, y), Vector2(-11, y - 9)]), Color(0.75, 0.82, 1.0, 0.35), 1.4)
		h._line(PackedVector2Array([Vector2(0, y - 4), Vector2(8, y - 12)]), Color(0.75, 0.82, 1.0, 0.3), 1.4)
	h._line(PackedVector2Array([Vector2(0, 6), Vector2(-1, -40), Vector2(-3, -90)]), Color("#F2EEFF"), 2.4)
	for k in 3:
		var tw := 0.5 + 0.5 * sin(t * 3.0 + k * 2.1)
		h._sparkle(Vector2(-5 + k * 4, -34 - k * 18), 2.5 + 2.5 * tw, Color(1, 1, 0.9, 0.5 + 0.5 * tw))
	h._T = h._head_T(a) * Transform2D(0.0, base + Vector2(0, 4))
	h._glow(Vector2.ZERO, 16, 16, Color(1.0, 0.9, 0.5, 0.35))
	h._shape(["ow_quill_moon"], Sets.crescent(Vector2.ZERO, 11.0, 0.5), Vector2(-5, -1), GOLD, 1.0, 0.95, 1.2)
	h._fill(Sets.star_pts(Vector2(7, -5), 5.0, 2.0, 5), Color("#FFF6D0"))
	h._T = Transform2D.IDENTITY


## Шапка-обсерватория: серебряный купол с прорезью, из неё выглядывает латунный телескоп
static func dome_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	# ободок с окошками
	var band := PackedVector2Array()
	for i in 17:
		var ang := PI * i / 16.0
		band.append(Vector2(-cos(ang) * 50, 6 + sin(ang) * 7))
	for i in 17:
		var ang := PI - PI * i / 16.0
		band.append(Vector2(-cos(ang) * 50, 18 + sin(ang) * 7))
	h._shape(["ow_dome_band"], band, Vector2(0, 14), Color("#3A3F9E"), 1.6, 0.5)
	for k in 5:
		var x := -32.0 + k * 16.0
		var lit := 0.6 + 0.4 * sin(t * 1.3 + k * 1.7)
		h._ball(Vector2(x, 16 + absf(x) * 0.04), 3.4, 4.2, Color(1.0, 0.85, 0.4).lerp(Color.WHITE, lit * 0.3), 0.0, 1.0, 0.8, 0.0)
	# телескоп (за куполом — сначала)
	var ang := -0.9 + sin(t * 0.5) * 0.18
	var tb := Vector2(4, -16)
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := dir.orthogonal()
	var tip := tb + dir * 58.0
	h._fill(PackedVector2Array([tb + nrm * 7, tip + nrm * 5, tip - nrm * 5, tb - nrm * 7]), Color("#C98A2E"))
	h._line(PackedVector2Array([tb + nrm * 5 + dir * 6, tip + nrm * 3]), Color("#FFE6A0", 0.8), 2.0)
	h._ball(tip, 5.0, 7.0, Color("#E0A63C"), ang, 1.0, 0.9, 1.0)
	h._dot(tip + dir * 2.0, 3.4, Color("#9FE8FF"))
	# купол
	var dome := PackedVector2Array()
	for i in 21:
		var ang2 := PI + PI * i / 20.0
		dome.append(Vector2(cos(ang2) * 46, 8 + sin(ang2) * 46))
	h._shape(["ow_dome"], dome, Vector2(-8, -14), Color("#DCE2F6"), 1.2, 0.7)
	for k in 3:
		var x := -30.0 + k * 30.0
		var top_y := 8.0 - 46.0 * sqrt(maxf(0.0, 1.0 - pow(x / 46.0, 2)))
		h._line(PackedVector2Array([Vector2(x, 8), Vector2(x * 0.7, (8.0 + top_y) / 2.0), Vector2(x * 0.4, top_y + 2)]), Color("#9AA4D0", 0.7), 1.8)
	# прорезь
	var slit := PackedVector2Array([Vector2(-7, 6), Vector2(-8, -24), Vector2(-4, -37), Vector2(6, -37), Vector2(9, -24), Vector2(9, 6)])
	h._vgrad(slit, Color("#12103A"), Color("#2A2468"))
	for k in 2:
		h._sparkle(Vector2(-1 + k * 4, -28 + k * 16), 2.0, Color(1, 1, 0.85, 0.8))
	h._ball(Vector2(0, -46), 5, 4, GOLD, 0.0, 1.0, 0.9, 1.0)
	# звёзды у телескопа
	for k in 3:
		var tw := 0.5 + 0.5 * sin(t * 2.6 + k * 2.2)
		h._sparkle(tip + Vector2(10 + k * 8, -6 - k * 10), 3.0 + 3.0 * tw, Color(1, 1, 0.85, 0.4 + 0.6 * tw))
	h._T = Transform2D.IDENTITY


# ==================== Глаза ====================

## Очки-половинки: тонкая золотая оправа низко на глазах и цепочка из бусин
static func halfglasses(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 0.92
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._T = Transform2D(a.tilt, e + Vector2(0, r * 0.22))
		var lens := PackedVector2Array()
		for k in 15:
			var ang := lerpf(-0.1, PI + 0.1, k / 14.0)
			lens.append(Vector2(cos(ang) * r, sin(ang) * r * 0.82))
		h._vgrad(lens, Color(0.85, 0.95, 1.0, 0.1), Color(0.7, 0.85, 1.0, 0.26), false)
		var cl := lens.duplicate()
		cl.append(lens[0])
		h._line(cl, GOLD_D, r * 0.15)
		h._line(cl, GOLD, r * 0.08)
		h._line(PackedVector2Array([Vector2(-r * 0.62, r * 0.18), Vector2(-r * 0.32, r * 0.55)]), Color(1, 1, 1, 0.65), r * 0.08)
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r, r * 0.18).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r, -r * 0.18).rotated(a.tilt)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.1), rr]), GOLD, r * 0.09)
	# цепочка от дужек вниз за шею
	if a.kind != "icon":
		for sx in [-1.0, 1.0]:
			var e: Vector2 = a.eye_l if sx < 0 else a.eye_r
			var st: Vector2 = e + Vector2(sx * r * 1.02, r * 0.25).rotated(a.tilt)
			for k in 8:
				var s := k / 7.0
				var p := st + Vector2(sx * (6.0 + sin(s * PI) * 8.0), s * 52.0)
				h._ball(p, 2.3 if k % 2 == 0 else 1.7, 2.3 if k % 2 == 0 else 1.7, GOLD if k % 2 == 0 else Color("#FFF0F8"), 0.0, 1.0, 0.9, 0.6)
	h._sparkle(a.eye_r + Vector2(r * 0.55, r * 0.6), r * (0.1 + 0.06 * sin(t * 4.0)), Color.WHITE)


## Ночные окуляры: латунные окуляры с мятными светящимися стёклами, ремешок и колёсико настройки
static func night_goggles(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.06
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var tw: float = a.temple
	h._T = Transform2D(a.tilt, mid)
	h._line(PackedVector2Array([Vector2(-tw * 1.05, -r * 0.1), Vector2(tw * 1.05, -r * 0.1)]), Color("#3A2A6A"), r * 0.5)
	h._line(PackedVector2Array([Vector2(-tw * 1.03, -r * 0.26), Vector2(tw * 1.03, -r * 0.26)]), Color("#6A58B0", 0.8), r * 0.08)
	h._T = Transform2D.IDENTITY
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._T = Transform2D(a.tilt, e)
		h._glow(Vector2.ZERO, r * 1.5, r * 1.5, Color(0.35, 1.0, 0.8, snappedf(0.12 + 0.1 * pulse, 0.04)))
		h._vgrad(h._ell(Vector2.ZERO, r, r, 0.0, 26), Color(0.4, 1.0, 0.82, 0.42), Color(0.1, 0.55, 0.6, 0.5), false)
		h._arc(Vector2.ZERO, r * 0.62, r * 0.62, 0, TAU, Color(0.7, 1.0, 0.9, 0.35), r * 0.05, 20)
		# бегущий блик «прибора ночного видения»
		var ph := fposmod(t * 0.6 + i * 0.3, 2.0)
		if ph < 1.0:
			var y := lerpf(-r * 0.7, r * 0.7, ph)
			var hw := sqrt(maxf(0.0, r * r * 0.8 - y * y))
			h._line(PackedVector2Array([Vector2(-hw, y), Vector2(hw, y)]), Color(0.8, 1.0, 0.9, 0.5 * sin(ph * PI)), r * 0.07)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#6A3E12"), r * 0.44, 30)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#D99A3A"), r * 0.3, 30)
		h._arc(Vector2.ZERO, r * 1.04, r * 1.04, 1.0 * PI, 1.55 * PI, Color("#FFE6A0"), r * 0.08, 10)
		for k in 8:
			var ang := k * TAU / 8.0 + 0.2
			h._dot(Vector2(cos(ang), sin(ang)) * r, r * 0.06, Color("#FFF0C0"))
		h._line(PackedVector2Array([Vector2(-r * 0.5, -r * 0.05), Vector2(-r * 0.15, -r * 0.5)]), Color(1, 1, 1, 0.6), r * 0.12)
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r, 0).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r, 0).rotated(a.tilt)
	h._line(PackedVector2Array([l, rr]), Color("#6A3E12"), r * 0.3)
	h._line(PackedVector2Array([l, rr]), Color("#D99A3A"), r * 0.18)
	# колёсико настройки сбоку
	var kc: Vector2 = a.eye_r + Vector2(r * 1.15, -r * 0.55).rotated(a.tilt)
	h._ball(kc, r * 0.24, r * 0.24, Color("#D99A3A"), 0.0, 1.0, 0.9, 1.0)
	var ka := t * 0.8
	h._line(PackedVector2Array([kc + Vector2(cos(ka), sin(ka)) * r * 0.16, kc - Vector2(cos(ka), sin(ka)) * r * 0.16]), Color("#6A3E12"), r * 0.06)


static func _glow_eyes(h, a: Dictionary, t: float) -> void:
	# 0.12b: у звездочёта глаза мягко светятся звёздным светом
	var pulse := 0.5 + 0.5 * sin(t * 1.8)
	for i in 2:
		var e: Vector2 = [a.eye_l, a.eye_r][i]
		h._glow(e, 44, 44, Color(1.0, 0.92, 0.55, snappedf(0.14 + 0.1 * pulse, 0.04)))
		h._sparkle(e + Vector2(-10, -12), 5.0 + 3.0 * pulse, Color(1, 1, 0.9, 0.9))
		h._sparkle(e + Vector2(12, 10), 2.5 + 1.5 * (1.0 - pulse), Color(0.85, 0.92, 1.0, 0.9))


# ==================== Шея ====================

## Значок-книжка на шарфе отличника
static func _scarf_pin(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var p: Vector2 = a.neck + Vector2(-w * 0.22, w * 0.03)
	h._T = Transform2D(-0.15, p)
	h._fill(PackedVector2Array([Vector2(-9, -6), Vector2(0, -4), Vector2(9, -6), Vector2(9, 6), Vector2(0, 8), Vector2(-9, 6)]), GOLD_D)
	h._fill(PackedVector2Array([Vector2(-8, -5), Vector2(-1, -3), Vector2(-1, 6), Vector2(-8, 4)]), Color("#FFF4D6"))
	h._fill(PackedVector2Array([Vector2(8, -5), Vector2(1, -3), Vector2(1, 6), Vector2(8, 4)]), Color("#FFE9B8"))
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(8, -8), 2.5 + 1.5 * sin(t * 3.5), Color.WHITE)


# ==================== Спина ====================

## Фонарь: совёнок держит его крылом. c — центр стекла, k — масштаб, live — с тёплым ореолом
static func lantern(h, c: Vector2, k: float, t: float, live: bool) -> void:
	var fl := 0.75 + 0.25 * sin(t * 9.0 + sin(t * 3.3) * 2.0)
	h._T = Transform2D(sin(t * 1.6) * 0.06, Vector2(k, k), 0.0, c)
	if live:
		h._glow(Vector2(0, 2), 46, 46, Color(1.0, 0.78, 0.35, snappedf(0.22 + 0.12 * fl, 0.04)))
	# ручка-кольцо (крыло держит её сверху)
	h._arc(Vector2(0, -26), 8, 8, PI, TAU, Color("#7A4A12"), 3.4, 10)
	h._arc(Vector2(0, -26), 8, 8, PI, TAU, Color("#E0A63C"), 1.8, 10)
	# крышка
	h._shape(["ow_lan_cap"], PackedVector2Array([Vector2(-6, -27), Vector2(6, -27), Vector2(14, -17), Vector2(-14, -17)]), Vector2(0, -21), Color("#D99A3A"), 1.0, 0.8, 1.2)
	h._ball(Vector2(0, -17), 14, 3, Color("#B8771A"), 0.0, 1.0, 0.7, 1.0)
	# стекло с огоньком
	var glass := PackedVector2Array([Vector2(-12, -15), Vector2(12, -15), Vector2(13, 12), Vector2(-13, 12)])
	h._vgrad(glass, Color(1.0, 0.93, 0.62, 0.9), Color(1.0, 0.66, 0.3, 0.9))
	h._glow(Vector2(0, -1), 12, 15, Color(1.0, 1.0, 0.85, snappedf(0.5 * fl + 0.2, 0.04)))
	var flame := PackedVector2Array([Vector2(0, -10 - 3 * fl), Vector2(4, -2), Vector2(3, 4), Vector2(0, 6), Vector2(-3, 4), Vector2(-4, -2)])
	h._fill(flame, Color("#FF9A2E"))
	h._fill(PackedVector2Array([Vector2(0, -5 - 2 * fl), Vector2(2, 0), Vector2(0, 4), Vector2(-2, 0)]), Color("#FFF6C0"))
	for sx in [-1.0, 1.0]:
		h._line(PackedVector2Array([Vector2(sx * 12.5, -15), Vector2(sx * 13.5, 12)]), Color("#B8771A"), 2.6)
	h._line(PackedVector2Array([Vector2(-6, -13), Vector2(-7, 8)]), Color(1, 1, 1, 0.55), 1.8)
	# донышко
	h._ball(Vector2(0, 14), 15, 4, Color("#D99A3A"), 0.0, 1.0, 0.8, 1.0)
	h._ball(Vector2(0, 19), 7, 3, Color("#B8771A"), 0.0, 1.0, 0.7, 1.0)
	h._T = Transform2D.IDENTITY
	if live:
		# мотылёк-искорка кружит у огня
		var mp := c + Vector2(cos(t * 2.3) * 24.0, -14.0 + sin(t * 4.6) * 8.0) * k
		h._sparkle(mp, 3.0 * k, Color(1.0, 0.95, 0.7, 0.85))


# ==================== Спутники ====================

## Летающая книжка: страницы шелестят и перелистываются, ленточка-закладка, из книги летят искорки
static func book(h, p: Vector2, t: float, react: float) -> void:
	var open := 0.3 + 0.12 * sin(t * 3.0)
	if react >= 0.0 and react < 1.3:
		open += 0.3 * sin(react / 1.3 * PI)  # при касании книжка радостно раскрывается
	h._glow(p, 40, 34, Color(1.0, 0.85, 0.5, 0.22))
	h._T = Transform2D(sin(t * 1.1) * 0.08, p)
	var lift := 12.0 * open
	for sx in [-1.0, 1.0]:
		# обложка
		h._fill(PackedVector2Array([Vector2(0, -19), Vector2(sx * 33, -19 - lift - 2), Vector2(sx * 33, 19 - lift + 2), Vector2(0, 21)]), Color("#B0386A"))
		# страницы стопкой
		for k in 3:
			var o := k * 1.6
			h._fill(PackedVector2Array([Vector2(0, -16 + o), Vector2(sx * (30 - o), -16 - lift + o), Vector2(sx * (30 - o), 16 - lift + o), Vector2(0, 18)]), Color("#F2E2C0") if k < 2 else Color("#FFF8E8"))
		# строчки
		for k in 4:
			var y := -9.0 + k * 6.0
			h._line(PackedVector2Array([Vector2(sx * 6, y + 1), Vector2(sx * 24, y - lift * 0.72)]), Color("#B8A890", 0.7), 1.2)
		# золотые уголки
		h._fill(PackedVector2Array([Vector2(sx * 33, -19 - lift - 2), Vector2(sx * 25, -19 - lift - 1), Vector2(sx * 33, -12 - lift)]), GOLD)
		h._fill(PackedVector2Array([Vector2(sx * 33, 19 - lift + 2), Vector2(sx * 25, 20 - lift + 1), Vector2(sx * 33, 12 - lift)]), GOLD)
	# перелистывается страница
	var ph := fposmod(t, 2.6)
	if ph < 0.7:
		var k := ph / 0.7
		var x := 28.0 * cos(k * PI)
		var up := sin(k * PI) * 9.0
		var ly := lift * absf(cos(k * PI))
		if absf(x) > 1.5:  # страница ребром — не рисуем (вырожденный многоугольник)
			h._fill(PackedVector2Array([Vector2(0, -16), Vector2(x, -16 - ly - up), Vector2(x, 16 - ly - up), Vector2(0, 18)]), Color("#FFFDF6").darkened(0.12 * absf(sin(k * PI))))
	h._line(PackedVector2Array([Vector2(0, -18), Vector2(0, 20)]), Color("#7A2048"), 2.4)
	# ленточка-закладка
	var rb := PackedVector2Array()
	for k in 6:
		var s := k / 5.0
		rb.append(Vector2(2 + sin(t * 3.0 + s * 4.0) * 3.0 * s, 20 + s * 18))
	h._line(rb, Color("#E8344E"), 3.2)
	h._T = Transform2D.IDENTITY
	# искорки-буквы поднимаются из страниц
	for i in 4:
		var q := fposmod(t * 0.45 + i * 0.25, 1.0)
		var sp := p + Vector2(sin(i * 2.3 + q * 4.0) * 16.0, -16.0 - q * 40.0)
		h._sparkle(sp, 3.5 * sin(q * PI) + 0.4, Color(1.0, 0.9, 0.5, sin(q * PI)))


## Где ручная комета (облетает совёнка вокруг головы)
static func _comet_at(a: Dictionary, t: float) -> Vector3:
	var R: float = a.size
	var ang := t * 0.85
	var c: Vector2 = a.center
	if a.kind == "icon":
		return Vector3(c.x + cos(ang) * 30.0, c.y + sin(ang) * 12.0, sin(ang))
	return Vector3(c.x + cos(ang) * R * 1.3, c.y - R * 1.0 + sin(ang) * R * 0.14 + sin(t * 2.0) * 6.0, sin(ang))


## РУЧНАЯ КОМЕТА (легендарная): ледяная головка с мордашкой и переливающийся хвост
static func comet(h, a: Dictionary, t: float, front: bool) -> void:
	var now := _comet_at(a, t)
	if (now.z > 0.0) != front:
		return
	var k := 1.0 if a.kind != "icon" else 1.8
	# хвост: следы прошлых положений
	for i in range(14, 0, -1):
		var q := _comet_at(a, t - i * 0.05)
		var s := i / 14.0
		var col := Color("#FFF6C0").lerp(Color("#FF7AD9"), s).lerp(Color("#7A8CFF"), maxf(0.0, s - 0.5) * 1.8)
		h._glow(Vector2(q.x, q.y), (14.0 - i * 0.6) * k, (14.0 - i * 0.6) * k, Sets.q(Color(col, 0.55 * (1.0 - s))))
		if i % 4 == 0:
			h._sparkle(Vector2(q.x, q.y) + Vector2(0, -4), 3.5 * (1.0 - s) * k + 0.5, Color(1, 1, 1, 0.9 * (1.0 - s)))
	var p := Vector2(now.x, now.y)
	h._glow(p, 26 * k, 26 * k, Color(1.0, 0.95, 0.7, 0.5))
	h._T = Transform2D(0.0, Vector2(k, k), 0.0, p)
	h._ball(Vector2.ZERO, 13, 13, Color("#FFF1B0"), 0.0, 1.0, 0.9, 1.0)
	h._dot(Vector2(-4.5, -1), 2.1, Color("#1A0E30"))
	h._dot(Vector2(4.5, -1), 2.1, Color("#1A0E30"))
	h._dot(Vector2(-5.2, -1.8), 0.8, Color.WHITE)
	h._dot(Vector2(3.8, -1.8), 0.8, Color.WHITE)
	h._arc(Vector2(0, 2.5), 3.0, 2.2, 0.15 * PI, 0.85 * PI, Color("#7A2A4C"), 1.4, 6)
	h._glow(Vector2(-8, 3), 3.5, 2.2, Color(1.0, 0.45, 0.6, 0.6))
	h._glow(Vector2(8, 3), 3.5, 2.2, Color(1.0, 0.45, 0.6, 0.6))
	h._T = Transform2D.IDENTITY
	h._sparkle(p + Vector2(-9, -11) * k, (3.5 + 2.0 * sin(t * 5.0)) * k, Color.WHITE)


# ==================== Сияния ====================

## ВИХРЬ СТРАНИЦ (легендарное): вокруг совёнка кружат страницы с золотыми рунами
static func page_whirl(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front:
		h._glow(c, R * 1.3, R * 1.3, Color(1.0, 0.8, 0.45, 0.16))
		# золотые руны поднимаются
		for i in 6:
			var ph := fposmod(t * 0.2 + hs(i, 1), 1.0)
			var p := c + Vector2((hs(i, 2) - 0.5) * R * 2.2, R * 0.9 - ph * R * 2.2)
			_rune(h, p, i, Color(1.0, 0.85, 0.4, 0.75 * sin(ph * PI)), 1.0 if not h._icon else 0.8)
	for i in 7:
		var ang := t * 0.55 + i * TAU / 7.0
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var p := c + Vector2(cos(ang) * R * 1.32, R * 0.05 + z * R * 0.3 + sin(t * 1.7 + i) * 7.0)
		var fl := 0.45 + 0.55 * absf(cos(t * 2.4 + i * 1.3))
		var s := (0.85 + 0.2 * z) * (1.35 if not h._icon else 1.0)
		h._T = Transform2D(sin(t * 1.3 + i) * 0.35, Vector2(s * fl, s), 0.0, p)
		var pg := PackedVector2Array([Vector2(-11, -14), Vector2(9, -15), Vector2(12, 13), Vector2(-10, 14)])
		h._vgrad(pg, Color("#FFF8E6"), Color("#F0DDB0"))
		for k in 4:
			h._line(PackedVector2Array([Vector2(-6, -8 + k * 5), Vector2(6, -8.5 + k * 5)]), Color("#B89A6A", 0.7), 1.2)
		h._T = Transform2D.IDENTITY
		_rune(h, p + Vector2(0, -1), i + 3, Color(1.0, 0.7, 0.2, 0.85), 0.7 * s)
	if front:
		for i in 3:
			var tw := 0.5 + 0.5 * sin(t * 2.0 + i * 2.1)
			h._sparkle(c + Vector2(cos(t * 0.55 + i * 2.1) * R * 1.32, -R * 0.15 + i * 10.0), 4.0 * tw, Color(1, 0.95, 0.7, tw))


## Руна-закорючка (часть заклинания) — разные по номеру
static func _rune(h, p: Vector2, i: int, col: Color, k: float) -> void:
	if col.a <= 0.02:
		return
	h._T = Transform2D(0.0, Vector2(k, k), 0.0, p)
	match i % 4:
		0:
			h._line(PackedVector2Array([Vector2(-4, 5), Vector2(0, -6), Vector2(4, 5)]), col, 1.8)
			h._line(PackedVector2Array([Vector2(-2, 1), Vector2(2, 1)]), col, 1.6)
		1:
			h._arc(Vector2.ZERO, 5, 5, 0.3 * PI, 1.7 * PI, col, 1.8, 8)
			h._dot(Vector2(4, 0), 1.4, col)
		2:
			h._line(PackedVector2Array([Vector2(0, -6), Vector2(0, 6)]), col, 1.8)
			h._line(PackedVector2Array([Vector2(0, -2), Vector2(4, -5)]), col, 1.6)
			h._line(PackedVector2Array([Vector2(0, 2), Vector2(-4, -1)]), col, 1.6)
		3:
			h._fill(Sets.star_pts(Vector2.ZERO, 5.5, 2.2, 4), col)
	h._T = Transform2D.IDENTITY


# ==================== Супер-эксклюзив: Мантия звездочёта ====================

## Созвездия на мантии: точки в долях ширины спины и пары-линии
const STAR_PTS := [Vector2(-0.5, 0.05), Vector2(-0.36, 0.18), Vector2(-0.48, 0.36), Vector2(-0.3, 0.46),
	Vector2(0.42, 0.02), Vector2(0.56, 0.2), Vector2(0.38, 0.32), Vector2(0.52, 0.48), Vector2(-0.62, 0.52), Vector2(0.64, 0.4)]
const STAR_LINES := [[0, 1], [1, 2], [2, 3], [4, 5], [5, 6], [6, 7], [5, 9]]


static func stargazer_mantle(h, a: Dictionary, t: float) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	# высокий звёздный воротник за головой
	var col := PackedVector2Array()
	var n := 25
	for i in n:
		var s := i / float(n - 1)
		var ang := lerpf(PI * 1.0, PI * 2.0, s)
		var rr := 1.0 + 0.1 * absf(sin(s * PI * 6.0))
		col.append(b + Vector2(0, -w * 0.3) + Vector2(cos(ang) * w * 0.66 * rr, sin(ang) * w * 0.46 * rr))
	col.append(b + Vector2(w * 0.4, -w * 0.18))
	col.append(b + Vector2(-w * 0.4, -w * 0.18))
	var cc := PackedColorArray()
	for v in col:
		cc.append(Color("#6A7CF0").lerp(Color("#1A1F66"), clampf((v.y - (b.y - w * 0.8)) / (w * 0.6), 0.0, 1.0)))
	h.ci.draw_polygon(col, cc)
	h.ci.draw_polyline(col.slice(0, n), GOLD_D, 6.0, true)
	h.ci.draw_polyline(col.slice(0, n), GOLD, 3.0, true)
	for i in range(2, n, 4):
		var tw := 0.5 + 0.5 * sin(t * 3.0 + i)
		h._fill(Sets.star_pts(col[i], 6.0 + 2.0 * tw, 2.5, 5), Color("#FFF2B0"))
	# сама мантия
	var res: Array = Sets._cape_pts(a, 1.3, 0.66, func(s: float) -> float: return sin(s * TAU * 2.0 + t * 1.3) * 6.0, 19)
	var pts: PackedVector2Array = res[0]
	Sets._cape_fill(h, a, pts, Color("#2E43C0"), Color("#0A0E3A"))
	var hem: PackedVector2Array = res[1]
	# созвездия: линии и звёзды, загораются по очереди
	for pr in STAR_LINES:
		h.ci.draw_line(b + STAR_PTS[pr[0]] * w, b + STAR_PTS[pr[1]] * w, Color(0.75, 0.85, 1.0, 0.45), 1.6, true)
	for i in STAR_PTS.size():
		var p: Vector2 = b + STAR_PTS[i] * w
		var lit := snappedf(maxf(0.0, sin(t * 1.4 - i * 0.7)), 0.2)
		h._glow(p, 9 + 9 * lit, 9 + 9 * lit, Color(1.0, 0.92, 0.6, snappedf(0.2 + 0.4 * lit, 0.05)))
		h._sparkle(p, 3.5 + 4.5 * lit, Color(1.0, 0.96, 0.8, 0.8 + 0.2 * lit))
	# полумесяц на подоле
	var mc := b + Vector2(-w * 0.12, w * 0.5)
	h._T = Transform2D(0.0, mc)
	h._glow(Vector2.ZERO, 22, 22, Color(1.0, 0.92, 0.6, 0.3))
	h._shape(["ow_sg_moon"], Sets.crescent(Vector2.ZERO, 14.0, -0.4), Vector2(-6, 0), GOLD, 1.0, 0.95, 1.2)
	h._T = Transform2D.IDENTITY
	# золотая кайма
	h.ci.draw_polyline(hem, GOLD_D, 7.0, true)
	h.ci.draw_polyline(hem, GOLD, 3.5, true)
	for i in range(1, hem.size(), 3):
		h._fill(Sets.star_pts(hem[i] + Vector2(0, -1), 5.0, 2.0, 5), Color("#FFF2B0"))


## Колпак звездочёта: высокий синий конус с загнутой верхушкой, звёзды и золотой месяц
static func wizard_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	h._ball(Vector2(0, 4), 64, 13, Color("#24318E"), 0.0, 1.4, 0.6)
	var sway := sin(t * 1.2) * 4.0
	var cone := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var s := float(i) / n
		cone.append(Vector2(lerpf(-40, -8, s) + s * s * (10.0 + sway), lerpf(4, -96, s)))
	cone.append(Vector2(24 + sway * 1.6, -112))  # загнутая верхушка
	for i in range(n, -1, -1):
		var s := float(i) / n
		cone.append(Vector2(lerpf(40, 8, s) + s * s * (18.0 + sway), lerpf(4, -94, s)))
	h._shape(["ow_wiz_cone", snappedf(sway, 1.0)], cone, Vector2(0, -36), Color("#3446C8"), 1.4, 0.55)
	# лента с пряжкой-звездой
	var rib := PackedVector2Array([Vector2(-38, -6), Vector2(38, -6), Vector2(36, -18), Vector2(-36, -18)])
	h._vgrad(rib, Color("#FFD966"), Color("#C98A2E"))
	h._fill(Sets.star_pts(Vector2(0, -12), 8.0, 3.4, 5), Color("#FFF6D0"))
	# месяц и звёзды на колпаке
	h._T = h._head_T(a) * Transform2D(0.0, Vector2(-10, -50))
	h._glow(Vector2.ZERO, 16, 16, Color(1.0, 0.92, 0.6, 0.35))
	h._shape(["ow_wiz_moon"], Sets.crescent(Vector2.ZERO, 11.0, 0.5), Vector2(-5, -1), GOLD, 1.0, 0.95, 1.2)
	h._T = h._head_T(a)
	for st in [Vector2(14, -36), Vector2(4, -74), Vector2(-24, -24), Vector2(22, -60)]:
		var tw := 0.5 + 0.5 * sin(t * 3.0 + st.x)
		h._fill(Sets.star_pts(st, 4.5 + 1.5 * tw, 1.9, 5), Color("#FFE680").lerp(Color.WHITE, tw * 0.5))
	var tip := Vector2(24 + sway * 1.6, -112)
	h._ball(tip + Vector2(3, 6), 6, 6, GOLD, 0.0, 1.0, 0.9, 1.0)
	h._sparkle(tip + Vector2(3, 6), 8.0 + 3.0 * sin(t * 4.0), Color(1, 1, 0.85, 0.9))
	h._T = Transform2D.IDENTITY


## Маленькие планеты медленно кружат вокруг (сзади — задняя половина орбиты)
const PLANETS := [[Color("#FF9A6B"), 13.0, 0.32, 0.0, false], [Color("#7FE3FF"), 10.0, 0.45, 2.1, false], [Color("#C79BFF"), 16.0, 0.24, 4.0, true]]


static func planets(h, a: Dictionary, t: float, front: bool) -> void:
	var c: Vector2 = a.center
	var R: float = a.size
	if not front and a.kind != "icon":
		h._glow(c + Vector2(0, -R * 0.2), R * 1.4, R * 1.3, Color(0.45, 0.55, 1.0, 0.16))
	for i in PLANETS.size():
		var pl: Array = PLANETS[i]
		var ang: float = t * float(pl[2]) + float(pl[3])
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var p := c + Vector2(cos(ang) * R * 1.36, -R * 0.42 + z * R * 0.22 + float(i) * 22.0)
		var r: float = float(pl[1]) * (0.85 + 0.2 * z)
		h._glow(p, r * 2.6, r * 2.6, Sets.q(Color(pl[0], 0.3)))
		h._ball(p, snappedf(r, 0.5), snappedf(r, 0.5), pl[0], 0.0, 1.0, 0.7, 1.0)
		h._arc(p, r * 0.75, r * 0.3, 0.1 * PI, 0.9 * PI, Color((pl[0] as Color).darkened(0.25), 0.6), r * 0.2, 8)
		if pl[4]:
			var ring := PackedVector2Array()
			for k in 17:
				var ra := PI * k / 16.0
				ring.append(p + Vector2(cos(ra) * r * 1.9, sin(ra) * r * 0.5).rotated(-0.3))
			h.ci.draw_polyline(ring, Color(1.0, 0.92, 0.75, 0.9), 2.4, true)
	# звёздная пыль
	for i in 5:
		if (i % 2 == 1) != front:
			continue
		var ph := fposmod(t * 0.15 + hs(i, 3), 1.0)
		var p := c + Vector2((hs(i, 4) - 0.5) * R * 2.4, -R * 1.2 + ph * R * 2.2)
		h._sparkle(p, 4.0 * sin(ph * PI) + 0.3, Color(0.9, 0.95, 1.0, sin(ph * PI)))
