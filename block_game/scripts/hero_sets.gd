extends RefCounted
## Cascado 0.12: вещи пяти наборов и награды кузницы для слотов голова / глаза / шея / спина.
## Рисуют через помощников героя h (scripts/hero.gd): h._ball, h._shape, h._line, h._glow...
## Координаты — как у старых вещей: головные уборы в «голове шириной 100» (h._head_T, макушка — 0,0),
## очки — от центров глаз (a.eye_l / a.eye_r, a.eye_rad), шея — a.neck / a.neck_w, спина — a.back / a.back_w.
## Поэтому каждая вещь садится на всех четырёх героев по их точкам крепления (hero.gd, _anchors).
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
		"acorn_cap": acorn_cap(h, a, t)
		"bluebell_hat": bluebell_hat(h, a, t)
		"shell_clip": shell_clip(h, a, t)
		"coral_tiara": coral_tiara(h, a, t)
		"top_hat": top_hat(h, a, t)
		"space_helmet": space_helmet(h, a, t)
		"crystal_diadem": crystal_diadem(h, a, t)
		"firefly_crown": firefly_crown(h, a, t)
		_: return false
	return true


static func dispatch_eyes(h, id: String, a: Dictionary, t: float) -> bool:
	match id:
		"daisy_glasses": daisy_glasses(h, a, t)
		"dive_mask": dive_mask(h, a, t)
		"masquerade": masquerade(h, a, t)
		"star_lorgnette": star_lorgnette(h, a, t)
		"flight_goggles": flight_goggles(h, a, t)
		"amethyst_monocle": amethyst_monocle(h, a, t)
		_: return false
	return true


static func dispatch_neck(h, id: String, a: Dictionary, t: float) -> bool:
	match id:
		"leaf_scarf": leaf_scarf(h, a, t)
		"pearl_necklace": pearl_necklace(h, a, t)
		"moth_tie": moth_tie(h, a, t)
		"comet_scarf": comet_scarf(h, a, t)
		"star_compass": star_compass(h, a, t)
		"ermine_collar": ermine_collar(h, a, t)
		"mountain_heart": mountain_heart(h, a, t)
		_: return false
	return true


static func dispatch_back(h, id: String, a: Dictionary, t: float, behind: bool) -> bool:
	match id:
		"dragonfly_wings": dragonfly_wings(h, a, t, behind)
		"fin_cape": fin_cape(h, a, t, behind)
		"ball_cloak": ball_cloak(h, a, t, behind)
		"rocket_pack": rocket_pack(h, a, t, behind)
		"royal_mantle": royal_mantle(h, a, t, behind)
		"fullmoon_mantle": fullmoon_mantle(h, a, t, behind)
		_: return false
	return true


# ==================== Голова ====================

## Шапочка-жёлудь: пузатая шляпка-плюска с чешуйками, хвостик и листик
static func acorn_cap(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var dome := PackedVector2Array()
	for i in 21:
		var ang := PI + PI * i / 20.0
		dome.append(Vector2(cos(ang) * 47, 6 + sin(ang) * 40))
	for i in range(1, 6):
		dome.append(Vector2(lerpf(47, -47, i / 6.0), 10 + sin(PI * i / 6.0) * 3))
	h._shape(["acorn_dome"], dome, Vector2(-6, -14), Color("#C47A38"), 1.1, 0.55)
	# чешуйки плюски: ряды «черепицы»
	for row in 4:
		var y := 2.0 - row * 10.0
		var half := 44.0 - row * row * 3.2
		var cnt := 7 - row
		for i in cnt:
			var x := lerpf(-half + 6, half - 6, (i + 0.5 * (row % 2)) / maxf(cnt - 1 + 0.5 * (row % 2), 1.0))
			h._arc(Vector2(x, y), 7, 5, 0.1 * PI, 0.9 * PI, Color("#7A4520", 0.75), 2.6, 6)
			h._arc(Vector2(x - 1, y - 2.5), 5, 3, 0.2 * PI, 0.7 * PI, Color(1, 0.9, 0.75, 0.45), 1.5, 5)
	# ободок шляпки
	h._ball(Vector2(0, 9), 50, 8, Color("#9A5626"), 0.0, 1.3, 0.55)
	# хвостик-черешок и листик
	h._line(PackedVector2Array([Vector2(0, -32), Vector2(3, -44), Vector2(10, -52), Vector2(17, -53)]), Color("#5E361A"), 7.0)
	h._line(PackedVector2Array([Vector2(-1, -36), Vector2(2, -45)]), Color(1, 0.85, 0.6, 0.5), 2.0)
	h._T = h._head_T(a) * Transform2D(-0.5, Vector2(14, -46))
	var leaf: PackedVector2Array = h._chaikin(PackedVector2Array([Vector2(0, 0), Vector2(16, -12), Vector2(38, -10), Vector2(46, 0), Vector2(30, 10), Vector2(12, 8)]), 2)
	h._shape(["acorn_leaf"], leaf, Vector2(22, -1), Color("#5FCB4C"), 1.3, 0.5)
	h._line(PackedVector2Array([Vector2(3, 0), Vector2(22, -1), Vector2(40, -2)]), Color("#2E8A3A", 0.8), 2.0)
	h._T = h._head_T(a)
	h._dot(Vector2(-22, -24), 4.0, Color(1, 1, 1, 0.75))
	h._dot(Vector2(-14, -30), 2.2, Color(1, 1, 1, 0.6))
	h._T = Transform2D.IDENTITY


## Шляпка-колокольчик: перевёрнутый синий цветок, лепестки-завитки и светящаяся капля
static func bluebell_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var blue := Color("#5B7BFF")
	# стебелёк с завитком и листом
	h._line(PackedVector2Array([Vector2(0, -52), Vector2(-2, -66), Vector2(6, -76), Vector2(16, -74), Vector2(15, -66)]), Color("#3FAE55"), 6.0)
	h._ball(Vector2(-16, -64), 12, 5, Color("#58C96A"), -0.5, 1.2, 0.4, 1.0)
	# колокол
	var bell := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		bell.append(Vector2(lerpf(-40, -16, s) - sin(s * PI) * 4, lerpf(6, -54, s)))
	for i in 9:
		var ang := PI + PI * i / 8.0
		bell.append(Vector2(cos(ang) * 16, -54 + sin(ang) * 6))
	for i in 13:
		var s := 1.0 - i / 12.0
		bell.append(Vector2(-(lerpf(-40, -16, s) - sin(s * PI) * 4), lerpf(6, -54, s)))
	h._shape(["bell_body"], bell, Vector2(-4, -22), blue, 1.15, 0.6)
	# прожилки
	for x in [-22.0, -8.0, 8.0, 22.0]:
		h._line(PackedVector2Array([Vector2(x * 0.45, -50), Vector2(x * 0.8, -26), Vector2(x, 0)]), Color(0.85, 0.9, 1.0, 0.35), 2.0)
	# пять лепестков-завитков по краю
	for i in 5:
		var x := lerpf(-46, 46, i / 4.0)
		var rot := x / 46.0 * 0.7
		var pc := Vector2(x, 7 + absf(x) * 0.06)
		h._ball(pc, 14, 9, Color("#6F8DFF"), rot, 1.15, 0.6)
		h._ball(pc + Vector2(signf(x) * 8 if absf(x) > 1 else 0.0, 6), 6, 4.5, Color("#9DB4FF"), rot, 1.0, 0.5, 1.0)
	# светящаяся капля росы на крайнем лепестке
	var sw := sin(t * 1.8) * 2.0
	var dp := Vector2(50 + sw, 26 + absf(sw))
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	h._glow(dp, 30, 30, Color(0.6, 0.95, 1.0, snappedf(0.45 + 0.35 * pulse, 0.05)))
	h._line(PackedVector2Array([Vector2(48, 14), dp + Vector2(0, -6)]), Color(0.75, 0.95, 1.0, 0.6), 1.6)
	var drop := PackedVector2Array([dp + Vector2(0, -11), dp + Vector2(5, -2), dp + Vector2(7, 4), dp + Vector2(0, 9), dp + Vector2(-7, 4), dp + Vector2(-5, -2)])
	h._fill(h._chaikin(drop, 2), Color(0.75, 0.98, 1.0, 0.95))
	h._dot(dp + Vector2(-1.5, -1), 1.8, Color.WHITE)
	# блики на колоколе
	h._dot(Vector2(-18, -34), 4.5, Color(1, 1, 1, 0.8))
	h._dot(Vector2(-12, -42), 2.4, Color(1, 1, 1, 0.65))
	h._sparkle(Vector2(26, -36), 5 + 3 * pulse, Color(1, 1, 1, 0.85))
	h._T = Transform2D.IDENTITY


## Ракушка-заколка: веерный гребешок с рёбрышками и жемчужиной
static func shell_clip(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(0.3, Vector2(30, -2))
	var sh := PackedVector2Array([Vector2(-8, 12), Vector2(-12, 6)])
	for i in 25:
		var ang := lerpf(PI * 1.12, PI * 1.88, i / 24.0)
		var r := 30.0 + 2.2 * cos(i * PI)
		sh.append(Vector2(cos(ang) * r, 8 + sin(ang) * r))
	sh.append_array([Vector2(12, 6), Vector2(8, 12)])
	h._shape(["shell_fan"], sh, Vector2(0, -6), Color("#FFAE9E"), 1.2, 0.6)
	for k in 7:
		var ang := lerpf(PI * 1.18, PI * 1.82, k / 6.0)
		var e := Vector2(cos(ang), sin(ang)) * 27 + Vector2(0, 8)
		h._line(PackedVector2Array([Vector2(0, 8), e]), Color("#E06A6A", 0.55), 2.6)
		h._line(PackedVector2Array([Vector2(0, 6) + (e - Vector2(0, 8)) * 0.3, e * 0.9 + Vector2(-1.2, -1)]), Color(1, 1, 1, 0.45), 1.3)
	# «ушки» у основания
	h._ball(Vector2(0, 12), 14, 6, Color("#FF8F86"), 0.0, 1.2, 0.5, 1.2)
	h._ball(Vector2(0, 10), 6.5, 6.5, Color("#FFF4FA"), 0.0, 1.0, 1.0, 1.0)
	h._dot(Vector2(-2, 8), 2.0, Color.WHITE)
	h._sparkle(Vector2(-14, -12), 3.5 + 2.0 * sin(t * 4.0), Color(1, 1, 1, 0.9))
	h._T = Transform2D.IDENTITY


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


## Цилиндр: серебряная лента и брошь-полумесяц
static func top_hat(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a) * Transform2D(0.08, Vector2(4, 0))
	var navy := Color("#211A52")
	h._ball(Vector2(0, 4), 56, 10, navy.darkened(0.15), 0.0, 1.3, 0.7)
	var body := PackedVector2Array()
	for i in 9:
		body.append(Vector2(lerpf(-34, -38, i / 8.0), lerpf(2, -76, i / 8.0)))
	for i in 9:
		body.append(Vector2(lerpf(-38, 38, i / 8.0), -76 - sin(PI * i / 8.0) * 2))
	for i in 9:
		body.append(Vector2(lerpf(38, 34, i / 8.0), lerpf(-76, 2, i / 8.0)))
	for i in range(1, 8):
		body.append(Vector2(lerpf(34, -34, i / 8.0), 2 + sin(PI * i / 8.0) * 3))
	h._shape(["tophat_body"], body, Vector2(-4, -34), navy, 1.6, 0.7)
	h._ball(Vector2(0, -76), 38, 7, navy.lightened(0.12), 0.0, 1.3, 0.6, 1.0)
	# серебряная лента
	var rib := PackedVector2Array([Vector2(-35, -18), Vector2(35, -18), Vector2(34, -3), Vector2(-34, -3)])
	h._vgrad(rib, Color("#F4F7FF"), Color("#9AA6D8"))
	h._line(PackedVector2Array([Vector2(-34, -15), Vector2(34, -15)]), Color(1, 1, 1, 0.8), 1.6)
	# блик-полоса
	h._line(PackedVector2Array([Vector2(-24, -66), Vector2(-22, -24)]), Color(1, 1, 1, 0.28), 6.0)
	h._line(PackedVector2Array([Vector2(-26, -64), Vector2(-25, -50)]), Color(1, 1, 1, 0.55), 2.5)
	# брошь-полумесяц со звёздочкой
	h._glow(Vector2(16, -11), 18, 18, Color(1.0, 0.9, 0.5, 0.35))
	h._shape(["tophat_moon"], crescent(Vector2(16, -11), 11.0, 0.5), Vector2(10, -13), GOLD, 1.0, 0.9, 1.2)
	h._fill(star_pts(Vector2(25, -17), 4.5, 1.8, 4), Color("#FFF6D0"))
	var tw := 0.5 + 0.5 * sin(t * 3.0)
	h._sparkle(Vector2(8, -22), 3 + 2.5 * tw, Color(1, 1, 1, 0.9))
	h._T = Transform2D.IDENTITY


## Космический шлем: прозрачный купол с бликом, кольцо с огоньками и антенна
static func space_helmet(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var dome := PackedVector2Array()
	for i in 25:
		var ang := PI + PI * i / 24.0
		dome.append(Vector2(cos(ang) * 64, 14 + sin(ang) * 74))
	h._vgrad(dome, Color(0.78, 0.95, 1.0, 0.30), Color(0.6, 0.85, 1.0, 0.10), false)
	h._line(dome, Color(0.85, 0.97, 1.0, 0.75), 3.2)
	h._arc(Vector2(0, 14), 52, 62, 1.12 * PI, 1.42 * PI, Color(1, 1, 1, 0.85), 7.0, 12)
	h._arc(Vector2(0, 14), 52, 62, 1.48 * PI, 1.56 * PI, Color(1, 1, 1, 0.7), 5.0, 4)
	h._arc(Vector2(0, 14), 56, 66, 1.7 * PI, 1.9 * PI, Color(0.6, 0.9, 1.0, 0.5), 3.0, 8)
	# антенна
	h._line(PackedVector2Array([Vector2(38, -42), Vector2(48, -70), Vector2(52, -84)]), Color("#C9D2EE"), 4.0)
	var bl := 0.5 + 0.5 * sin(t * 5.0)
	h._glow(Vector2(53, -88), 16, 16, Color(1.0, 0.35, 0.6, snappedf(0.25 + 0.4 * bl, 0.05)))
	h._ball(Vector2(53, -88), 6, 6, Color("#FF4F93"), 0.0, 1.0, 0.9, 1.0)
	# кольцо-основание с огоньками
	h._ball(Vector2(0, 16), 68, 9.5, Color("#EEF2FF"), 0.0, 1.3, 0.85)
	var lc := [Color("#FF4F93"), Color("#FFD23C"), Color("#3FE0D0"), Color("#FFD23C"), Color("#FF4F93")]
	for i in 5:
		var on := 0.5 + 0.5 * sin(t * 4.0 - i * 0.9)
		var p := Vector2(lerpf(-48, 48, i / 4.0), 17)
		h._dot(p, 3.6, (lc[i] as Color).lerp(Color.WHITE, on * 0.4))
		h._glow(p, 9, 7, Color(lc[i], snappedf(0.2 + 0.4 * on, 0.05)))
	h._T = Transform2D.IDENTITY


## Кристальная диадема: тонкий серебряный ободок и три кристалла
static func crystal_diadem(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var ring := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		ring.append(Vector2(cos(ang) * 48, 8 + sin(ang) * 11))
	h._line(ring, Color("#8C96C8"), 6.0)
	h._line(ring, SILVER, 3.0)
	for i in range(2, 15, 3):
		h._ball(ring[i] + Vector2(0, 1), 3.2, 3.2, Color("#D7C4FF"), 0.0, 1.0, 1.0, 0.8)
	_crystal(h, Vector2(0, -2), 11.0, 38.0, Color("#B48CFF"), 0.0)
	_crystal(h, Vector2(-22, 2), 7.0, 22.0, Color("#8FE8FF"), -0.32)
	_crystal(h, Vector2(22, 2), 7.0, 22.0, Color("#8FE8FF"), 0.32)
	var tw := 0.5 + 0.5 * sin(t * 4.0)
	h._glow(Vector2(0, -24), 22, 30, Color(0.8, 0.65, 1.0, snappedf(0.15 + 0.2 * tw, 0.05)))
	h._sparkle(Vector2(-6, -36), 3 + 4 * tw, Color.WHITE)
	h._sparkle(Vector2(26, -14), 2 + 3 * (1.0 - tw), Color(1, 1, 1, 0.9))
	h._T = Transform2D.IDENTITY


## Гранёный кристалл-призма (основание в b, вверх на hgt, полуширина w) в текущем h._T
static func _crystal(h, b: Vector2, w: float, hgt: float, col: Color, rot: float) -> void:
	var up := Vector2(0, -1).rotated(rot)
	var rt := up.orthogonal() * -1.0
	var top := b + up * hgt
	var sh := b + up * hgt * 0.72
	var pl := b - rt * w + up * hgt * 0.1
	var pr := b + rt * w + up * hgt * 0.1
	var sl := sh - rt * w
	var sr := sh + rt * w
	var mid_b := b + up * hgt * 0.05
	var mid_s := sh + up * hgt * 0.02
	h._fill(PackedVector2Array([pl, sl, mid_s, mid_b]), col.lightened(0.25))
	h._fill(PackedVector2Array([mid_b, mid_s, sr, pr]), col.darkened(0.12))
	h._fill(PackedVector2Array([sl, top, mid_s]), col.lightened(0.55))
	h._fill(PackedVector2Array([mid_s, top, sr]), col.lightened(0.1))
	h._line(closed(PackedVector2Array([pl, sl, top, sr, pr, mid_b])), col.darkened(0.45), 1.6)
	h._line(PackedVector2Array([sl.lerp(pl, 0.15) + rt * w * 0.3, sl + rt * w * 0.3 + up * 2]), Color(1, 1, 1, 0.7), 1.6)


## ВЕНЕЦ СВЕТЛЯЧКОВ (легендарный): венок из стеблей, на концах 5 огоньков вспыхивают по очереди,
## вокруг головы кружат 2 огонька
static func firefly_crown(h, a: Dictionary, t: float) -> void:
	h._T = h._head_T(a)
	var glowc := Color("#E8FF6A")
	# два огонька за головой (задняя половина орбиты) — тусклее
	_crown_flies(h, t, false)
	# венок: два переплетённых стебля
	for s in 2:
		var pts := PackedVector2Array()
		for i in 21:
			var ang := PI + PI * i / 20.0
			var wob := sin(i * 1.1 + s * PI) * 3.0
			pts.append(Vector2(cos(ang) * (50 + wob), 8 + sin(ang) * (13 + wob * 0.5)))
		h._line(pts, Color("#3E8F3A") if s == 0 else Color("#C9A73E"), 5.0)
	for i in 9:
		var ang := PI + PI * (i + 0.5) / 9.0
		var p := Vector2(cos(ang) * 50, 8 + sin(ang) * 13)
		h._ball(p + Vector2(0, -3), 7, 3.6, Color("#6FD25A"), ang + PI / 2.0 + (0.6 if i % 2 == 0 else -0.6), 1.2, 0.35, 1.0)
	# пять стеблей с завитками и огоньками
	var xs := [-40.0, -21.0, 0.0, 21.0, 40.0]
	var hts := [30.0, 42.0, 52.0, 42.0, 30.0]
	for i in 5:
		var x: float = xs[i]
		var base := Vector2(x, 8 + sin(PI + PI * (x + 50.0) / 100.0) * 13)
		var top := base + Vector2(x * 0.18, -hts[i])
		var curl := PackedVector2Array([base, base.lerp(top, 0.4) + Vector2(-3, 0), base.lerp(top, 0.8) + Vector2(3, 0), top])
		h._line(curl, Color("#4FA64A"), 4.0)
		h._line(PackedVector2Array([curl[1] + Vector2(-1, 0), curl[2] + Vector2(-1, 0)]), Color(1, 1, 0.8, 0.4), 1.4)
		h._ball(curl[1] + Vector2(-5, 2), 6, 2.8, Color("#7EDB5E"), -0.7, 1.2, 0.35, 1.0)
		# вспышки по очереди
		var ph := fposmod(t * 0.9 - i * 0.2, 1.0)
		var flash := maxf(0.0, 1.0 - ph * 3.0)
		var base_l := 0.45 + 0.15 * sin(t * 3.0 + i)
		var lum := clampf(base_l + flash, 0.0, 1.4)
		h._glow(top, 16 + 14 * lum, 16 + 14 * lum, Color(0.92, 1.0, 0.45, snappedf(0.22 + 0.32 * minf(lum, 1.0), 0.04)))
		h._ball(top, 6.5, 7.5, Color("#F6FF8C").lerp(Color.WHITE, minf(flash, 1.0) * 0.6), 0.0, 1.0, 0.9, 1.0)
		if flash > 0.2:
			h._sparkle(top, 6 + 10 * flash, Color(1, 1, 0.85, minf(flash, 1.0)))
	_crown_flies(h, t, true)
	h._T = Transform2D.IDENTITY


static func _crown_flies(h, t: float, front: bool) -> void:
	for i in 2:
		var ang := t * 1.6 + i * PI
		var z := sin(ang)
		if (z > 0.0) != front:
			continue
		var p := Vector2(cos(ang) * 74, -16 + z * 18 + sin(t * 3.0 + i) * 4)
		var k := 0.7 + 0.3 * z
		var fl := 0.6 + 0.4 * sin(t * 9.0 + i * 2.0)
		h._glow(p, 18 * k, 18 * k, Color(0.9, 1.0, 0.4, snappedf(0.35 * fl * (1.0 if front else 0.5), 0.04)))
		h._dot(p, 4.2 * k, Color("#F8FF9A", 1.0 if front else 0.6))
		h._dot(p + Vector2(-1, -1), 1.6 * k, Color.WHITE)


# ==================== Глаза ====================

## Очки-ромашки: каждая линза — цветок с белыми лепестками, перемычка — зелёный стебелёк
static func daisy_glasses(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.05
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r * 0.95, 0).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r * 0.95, 0).rotated(a.tilt)
	h._line(PackedVector2Array([l, (l + rr) / 2.0 + Vector2(0, -r * 0.2).rotated(a.tilt), rr]), Color("#3FAE55"), r * 0.16)
	for e in [a.eye_l, a.eye_r]:
		h._T = Transform2D(a.tilt, e)
		for k in 12:
			var ang := k * TAU / 12.0 + 0.13
			var pc := Vector2(cos(ang), sin(ang)) * r * 1.36
			h._ball(pc, r * 0.34, r * 0.15, Color("#FFFFFF") if k % 2 == 0 else Color("#FFF0F8"), snappedf(ang, 0.02), 1.2, 0.45, 1.0)
		h._vgrad(h._ell(Vector2.ZERO, r, r, 0.0, 24), Color(1.0, 0.95, 0.5, 0.18), Color(1.0, 0.8, 0.3, 0.1), false)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#D99A16"), r * 0.3, 30)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#FFD23C"), r * 0.18, 30)
		h._arc(Vector2.ZERO, r * 1.02, r * 1.02, 1.05 * PI, 1.45 * PI, Color(1, 1, 0.85, 0.95), r * 0.07, 8)
		for k in 8:
			var ang := k * TAU / 8.0
			h._dot(Vector2(cos(ang), sin(ang)) * r, r * 0.05, Color("#A86A08", 0.6))
		h._line(PackedVector2Array([Vector2(-r * 0.5, -r * 0.1), Vector2(-r * 0.1, -r * 0.5)]), Color(1, 1, 1, 0.45), r * 0.1)
	h._T = Transform2D.IDENTITY


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


## Лётные очки: кожаный ремешок, латунные оправы с заклёпками, янтарные стёкла
static func flight_goggles(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.08
	var mid: Vector2 = (a.eye_l + a.eye_r) / 2.0
	var tw: float = a.temple
	h._T = Transform2D(a.tilt, mid)
	h._line(PackedVector2Array([Vector2(-tw * 1.02, -r * 0.05), Vector2(tw * 1.02, -r * 0.05)]), Color("#6E3F20"), r * 0.62)
	h._line(PackedVector2Array([Vector2(-tw * 1.0, -r * 0.24), Vector2(tw * 1.0, -r * 0.24)]), Color("#B07040", 0.8), r * 0.1)
	for k in 7:
		var x := lerpf(-tw * 0.95, tw * 0.95, k / 6.0)
		h._line(PackedVector2Array([Vector2(x, r * 0.12), Vector2(x + r * 0.1, r * 0.12)]), Color("#3E2210", 0.6), r * 0.05)
	h._T = Transform2D.IDENTITY
	for e in [a.eye_l, a.eye_r]:
		h._T = Transform2D(a.tilt, e)
		h._vgrad(h._ell(Vector2.ZERO, r, r, 0.0, 26), Color(1.0, 0.78, 0.35, 0.2), Color(1.0, 0.5, 0.25, 0.12), false)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#7A4A12"), r * 0.42, 30)
		h._arc(Vector2.ZERO, r, r, 0, TAU, Color("#E0A63C"), r * 0.3, 30)
		h._arc(Vector2.ZERO, r * 1.03, r * 1.03, 1.0 * PI, 1.55 * PI, Color("#FFE6A0"), r * 0.08, 10)
		for k in 6:
			var ang := k * TAU / 6.0 + 0.3
			h._dot(Vector2(cos(ang), sin(ang)) * r, r * 0.07, Color("#FFF0C0"))
		h._line(PackedVector2Array([Vector2(-r * 0.5, r * 0.05), Vector2(-r * 0.12, -r * 0.45)]), Color(1, 1, 1, 0.55), r * 0.13)
		h._dot(Vector2(r * 0.35, r * 0.3), r * 0.06, Color(1, 1, 1, 0.6))
	h._T = Transform2D.IDENTITY
	var l: Vector2 = a.eye_l + Vector2(r, 0).rotated(a.tilt)
	var rr: Vector2 = a.eye_r - Vector2(r, 0).rotated(a.tilt)
	h._line(PackedVector2Array([l, rr]), Color("#7A4A12"), r * 0.28)
	h._line(PackedVector2Array([l, rr]), Color("#E0A63C"), r * 0.16)


## Аметистовый монокль: шестигранная фиолетовая оправа и цепочка из бусин
static func amethyst_monocle(h, a: Dictionary, t: float) -> void:
	var r: float = a.eye_rad * 1.15
	var e: Vector2 = a.eye_r
	h._T = Transform2D(a.tilt, e)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var ang := i * TAU / 6.0 + PI / 6.0
		outer.append(Vector2(cos(ang), sin(ang)) * r * 1.12)
		inner.append(Vector2(cos(ang), sin(ang)) * r * 0.86)
	h._vgrad(inner, Color(0.85, 0.7, 1.0, 0.22), Color(0.7, 0.5, 1.0, 0.12), false)
	# грани оправы разной яркости — как огранка
	for i in 6:
		var j := (i + 1) % 6
		var shade := 0.5 + 0.5 * cos(i * TAU / 6.0 + PI / 6.0 + 2.3)
		var c := Color("#6A34B8").lerp(Color("#D9B8FF"), shade)
		h._fill(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), c)
	h._line(closed(outer), Color("#3E1A78"), r * 0.06)
	h._line(PackedVector2Array([Vector2(-r * 0.45, r * 0.05), Vector2(-r * 0.1, -r * 0.45)]), Color(1, 1, 1, 0.55), r * 0.1)
	h._T = Transform2D.IDENTITY
	var start: Vector2 = e + Vector2(r * 0.8, r * 0.75).rotated(a.tilt)
	for i in 10:
		var s := i / 9.0
		var c := start + Vector2(s * r * 0.8, s * r * 2.6 + sin(s * PI) * r * 0.5)
		if i % 3 == 1:
			h._ball(c, r * 0.1, r * 0.1, Color("#B46CFF"), 0.0, 1.0, 1.0, 0.8)
		else:
			h._ball(c, r * 0.065, r * 0.065, GOLD, 0.0, 1.0, 0.9, 0.6)
	h._sparkle(e + Vector2(-r * 0.6, -r * 0.6), r * (0.12 + 0.07 * sin(t * 4.0)), Color.WHITE)


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


## Листик-шарф: листья внахлёст вокруг шеи, два листа свисают, на листе — божья коровка
static func leaf_scarf(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w
	var k := w / 150.0
	var cv := _neck_curve(a, 11, -2.0, 1.02)
	var greens := [Color("#5CC45A"), Color("#3FA34D"), Color("#8EDB5E")]
	# свисающие листья (сзади-спереди справа)
	var hp: Vector2 = a.neck + Vector2(w * 0.2, w * 0.06)
	var sw := sin(t * 1.6) * 0.06
	for j in 2:
		var rot := 0.25 + j * 0.42 + sw
		h._T = Transform2D(rot, Vector2(k, k), 0.0, hp)
		var lf: PackedVector2Array = h._chaikin(PackedVector2Array([Vector2(0, 0), Vector2(12, 10), Vector2(10, 34), Vector2(0, 46), Vector2(-10, 34), Vector2(-12, 10)]), 2)
		h._shape(["leafsc_hang"], lf, Vector2(0, 20), greens[j], 1.3, 0.5)
		h._line(PackedVector2Array([Vector2(0, 2), Vector2(0, 42)]), Color("#2E7A3A", 0.7), 2.0)
		for m in 3:
			h._line(PackedVector2Array([Vector2(0, 12 + m * 9), Vector2(7, 8 + m * 9)]), Color("#2E7A3A", 0.45), 1.4)
	h._T = Transform2D.IDENTITY
	# листья вдоль шеи
	for i in 11:
		var p: Vector2 = cv[i]
		var tg: Vector2 = (cv[mini(i + 1, 10)] - cv[maxi(i - 1, 0)]).normalized()
		var rot := snappedf(tg.angle() + (0.35 if i % 2 == 0 else -0.25), 0.04)
		h._ball(p, 13 * k + 3, 7 * k + 2, greens[i % 3], rot, 1.3, 0.5, 1.0)
		h._T = Transform2D(rot, p)
		h._line(PackedVector2Array([Vector2(-10 * k - 2, 0), Vector2(10 * k + 2, 0)]), Color("#2E7A3A", 0.55), 1.4)
		h._T = Transform2D.IDENTITY
	# божья коровка
	var lb: Vector2 = cv[3] + Vector2(0, -2)
	h._ball(lb, 6 * k + 1.5, 5 * k + 1.2, Color("#FF3B3B"), 0.0, 1.0, 0.9, 1.0)
	h._dot(lb + Vector2(-4 * k - 1, 0), 2.6 * k + 0.6, Color("#2A1A1A"))
	h._dot(lb + Vector2(2 * k, -2 * k), 1.4 * k + 0.5, Color("#2A1A1A"))
	h._dot(lb + Vector2(2.5 * k, 2.2 * k), 1.4 * k + 0.5, Color("#2A1A1A"))
	h._dot(lb + Vector2(-1.5 * k, -2.5 * k), 1.2 * k + 0.4, Color(1, 1, 1, 0.9))


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


## Ночная бабочка-галстук: крылья с «глазками», пушистое тельце, усики
static func moth_tie(h, a: Dictionary, t: float) -> void:
	var k: float = a.neck_w / 150.0
	var n: Vector2 = a.neck + Vector2(0, 3)
	var flap := 1.0 + 0.06 * sin(t * 3.0)
	h._T = Transform2D(0.0, Vector2(k * flap, k), 0.0, n)
	for sx in [-1.0, 1.0]:
		var up := PackedVector2Array([Vector2(sx * 5, -4), Vector2(sx * 18, -22), Vector2(sx * 38, -24), Vector2(sx * 44, -10), Vector2(sx * 34, 2), Vector2(sx * 8, 2)])
		h._shape(["moth_up", sx], h._chaikin(up, 2), Vector2(sx * 24, -10), Color("#6A44B8"), 1.2, 0.5)
		var lo := PackedVector2Array([Vector2(sx * 6, 2), Vector2(sx * 30, 4), Vector2(sx * 34, 16), Vector2(sx * 20, 22), Vector2(sx * 8, 12)])
		h._shape(["moth_lo", sx], h._chaikin(lo, 2), Vector2(sx * 18, 10), Color("#8E63D8"), 1.2, 0.5)
		# «глазки» на крыльях
		h._ball(Vector2(sx * 28, -12), 7, 7, Color("#FFB547"), 0.0, 1.0, 0.6, 1.0)
		h._dot(Vector2(sx * 28, -12), 3.4, Color("#2A1450"))
		h._dot(Vector2(sx * 27, -13.5), 1.4, Color(1, 1, 1, 0.9))
		h._arc(Vector2(sx * 22, -6), 18, 13, PI * (1.1 if sx < 0 else 1.6), PI * (1.4 if sx < 0 else 1.9), Color("#D9C4FF", 0.7), 2.0, 8)
		h._dot(Vector2(sx * 22, 12), 2.2, Color("#D9C4FF", 0.8))
	# усики
	for sx in [-1.0, 1.0]:
		h._line(PackedVector2Array([Vector2(sx * 2, -8), Vector2(sx * 7, -18), Vector2(sx * 13, -22)]), Color("#3A2468"), 2.0)
		h._dot(Vector2(sx * 13, -22), 2.2, Color("#FFD23C"))
	h._ball(Vector2(0, 0), 6, 11, Color("#E8DDFF"), 0.0, 1.1, 0.4)
	for m in 3:
		h._arc(Vector2(0, -5 + m * 5), 5, 2, 0.1 * PI, 0.9 * PI, Color("#9C80D0", 0.7), 1.4, 6)
	h._T = Transform2D.IDENTITY


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


## Горностаевый воротник: белые пушистые шарики, чёрные кончики хвостиков, золотая застёжка
static func ermine_collar(h, a: Dictionary, t: float) -> void:
	var k: float = a.neck_w / 150.0
	var cv := _neck_curve(a, 12, 0.0, 1.04)
	for i in 12:
		var p: Vector2 = cv[i]
		h._ball(p + Vector2(0, 2), 12 * k + 2, 10 * k + 2, Color("#F4F2FA"), 0.0, 1.2, 0.3, 1.0)
	var cv2 := _neck_curve(a, 9, 9.0 * k + 3, 0.92)
	for i in 9:
		h._ball(cv2[i], 11 * k + 2, 9 * k + 2, Color("#FFFFFF"), 0.0, 1.2, 0.3, 1.0)
	for i in [1, 4, 7]:
		var p: Vector2 = cv2[i] + Vector2(0, 7 * k + 2)
		h._ball(p, 3.2 * k + 1.2, 6.5 * k + 1.5, Color("#2A2436"), 0.0, 1.0, 0.6, 0.0)
	for i in [2, 6, 9]:
		var p: Vector2 = cv[i] + Vector2(0, 5 * k)
		h._ball(p, 2.6 * k + 1.0, 5 * k + 1.2, Color("#2A2436"), 0.0, 1.0, 0.6, 0.0)
	var c: Vector2 = a.neck + Vector2(0, 20 * k + 4)
	for sx in [-1.0, 1.0]:
		h._ball(c + Vector2(sx * 9 * k, 0), 5 * k + 1.5, 5 * k + 1.5, GOLD, 0.0, 1.0, 0.95, 1.0)
	h.ci.draw_line(c + Vector2(-9 * k, 0), c + Vector2(9 * k, 0), GOLD_D, 2.0 * k + 0.8, true)
	h._sparkle(c + Vector2(-9 * k, -3 * k), (3.0 + 2.0 * sin(t * 4.0)) * k + 0.8, Color.WHITE)


## КУЛОН «СЕРДЦЕ ГОРЫ» (легендарный): гранёный кристалл на золотой цепи,
## внутри пульсирует свет, расходятся лучики
static func mountain_heart(h, a: Dictionary, t: float) -> void:
	var w: float = a.neck_w * 0.84
	var n: Vector2 = a.neck
	var chain := PackedVector2Array()
	for i in 19:
		var ang := lerpf(0.0, PI, i / 18.0)
		chain.append(n + Vector2(cos(ang) * w * 0.5, -8 + sin(ang) * w * 0.2))
	h.ci.draw_polyline(chain, GOLD_D, 2.4, true)
	for i in 19:
		if i == 9:
			continue
		h._ball(chain[i], 3.4 if i % 2 == 0 else 2.6, 3.4 if i % 2 == 0 else 2.6, GOLD if i % 2 == 0 else Color("#FFE9A8"), 0.0, 1.0, 0.95, 0.8)
	var r := maxf(w * 0.18, 17.0)
	var pc: Vector2 = chain[9] + Vector2(0, r * 1.05)
	var pulse := 0.5 + 0.5 * sin(t * 2.6)
	# лучики
	for k in 10:
		var ang := k * TAU / 10.0 + t * 0.35
		var ln := r * (1.9 + 0.5 * sin(t * 3.0 + k * 1.3))
		var d := Vector2(cos(ang), sin(ang))
		var ray := PackedVector2Array([pc + d.orthogonal() * r * 0.1 + d * r * 0.7, pc + d * ln, pc - d.orthogonal() * r * 0.1 + d * r * 0.7])
		h.ci.draw_colored_polygon(ray, Color(1.0, 0.75, 0.85, 0.22 + 0.18 * pulse))
	h._glow(pc, r * (2.2 + 0.4 * pulse), r * (2.2 + 0.4 * pulse), Color(1.0, 0.4, 0.6, snappedf(0.25 + 0.2 * pulse, 0.04)))
	# гранёный кристалл
	var top := pc + Vector2(0, -r)
	var bot := pc + Vector2(0, r * 1.25)
	var ul := pc + Vector2(-r * 0.85, -r * 0.45)
	var ur := pc + Vector2(r * 0.85, -r * 0.45)
	var ml := pc + Vector2(-r * 0.95, r * 0.15)
	var mr := pc + Vector2(r * 0.95, r * 0.15)
	var cc := pc + Vector2(0, -r * 0.1)
	var base := Color("#FF3D7A")
	var f := [[top, ur, cc, base.lightened(0.35)], [top, cc, ul, base.lightened(0.6)], [ul, cc, ml, base.lightened(0.2)],
		[ur, mr, cc, base.darkened(0.15)], [ml, cc, bot, base], [cc, mr, bot, base.darkened(0.35)]]
	for fc in f:
		h.ci.draw_colored_polygon(PackedVector2Array([fc[0], fc[1], fc[2]]), fc[3])
	h.ci.draw_polyline(closed(PackedVector2Array([top, ur, mr, bot, ml, ul])), Color("#8A1040"), 1.8, true)
	h._glow(cc + Vector2(0, r * 0.2), r * 0.7, r * 0.7, Color(1.0, 0.95, 0.8, snappedf(0.35 + 0.45 * pulse, 0.04)))
	h._dot(cc + Vector2(0, r * 0.2), r * (0.14 + 0.1 * pulse), Color(1, 1, 1, 0.9))
	h._ball(chain[9], 4.5, 4.5, GOLD, 0.0, 1.0, 0.95, 1.0)
	h.ci.draw_line(top + Vector2(-r * 0.3, r * 0.25), top + Vector2(-r * 0.05, r * 0.02), Color(1, 1, 1, 0.9), 1.8, true)
	h._sparkle(pc + Vector2(-r * 0.55, -r * 0.5), r * (0.25 + 0.2 * pulse), Color.WHITE)


# ==================== Спина ====================

## Крылышки стрекозы: четыре прозрачно-голубых крыла с прожилками и переливом
static func dragonfly_wings(h, a: Dictionary, t: float, behind: bool) -> void:
	if not behind:
		return
	var w: float = a.back_w
	var root: Vector2 = a.back + Vector2(0, -w * 0.22)
	var flut := sin(t * 14.0) * 0.07 + sin(t * 1.3) * 0.03
	var wk := 184.0 / w * 0.25 + 0.75   # у маленьких героев крылья относительно больше
	for sx in [-1.0, 1.0]:
		for j in 2:
			var ln := w * (0.92 if j == 0 else 0.74) * wk
			var rot: float = (-0.42 + flut if j == 0 else 0.3 - flut)
			var ang: float = PI - rot if sx < 0 else rot
			var d := Vector2(cos(ang), sin(ang))
			var c := root + d * ln * 0.55
			var hh := fposmod(t * 0.12 + j * 0.2 + (0.0 if sx < 0 else 0.1), 1.0)
			var rim := hsv(hh, 0.45, 1.0, 0.85)
			var pts: PackedVector2Array = h._ell(c, ln * 0.55, ln * 0.19, ang, 26)
			var cols := PackedColorArray()
			for p in pts:
				var s := clampf((p - root).length() / ln, 0.0, 1.0)
				cols.append(Color(0.6, 0.9, 1.0, 0.62 - s * 0.2).lerp(Color(rim, 0.55), s * 0.7))
			h.ci.draw_polygon(pts, cols)
			h.ci.draw_polyline(closed(pts), Color(rim, 0.9), 2.0, true)
			h.ci.draw_line(root, c + d * ln * 0.5, Color(0.55, 0.75, 1.0, 0.55), 1.6, true)
			for m in 4:
				var p := root + d * ln * (0.25 + m * 0.2)
				h.ci.draw_line(p, p + d.rotated(0.6) * ln * 0.12, Color(0.6, 0.8, 1.0, 0.4), 1.0, true)
				h.ci.draw_line(p, p + d.rotated(-0.6) * ln * 0.12, Color(0.6, 0.8, 1.0, 0.4), 1.0, true)
			# блик
			h.ci.draw_line(c - d * ln * 0.25 + d.orthogonal() * ln * 0.06, c + d * ln * 0.2 + d.orthogonal() * ln * 0.07, Color(1, 1, 1, 0.55), 2.5, true)
	h._ball(root, w * 0.05, w * 0.05, Color("#3FE0D0"), 0.0, 1.0, 0.8, 1.0)


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


## Королевская мантия: алый бархат, горностаевая кайма с чёрными хвостиками
static func royal_mantle(h, a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if not behind:
		var n: Vector2 = a.neck + Vector2(0, 8)
		for sx in [-1.0, 1.0]:
			var m := n + Vector2(sx * w * 0.2, -4)
			h.ci.draw_line(n, m, GOLD_D, 3.5, true)
			h.ci.draw_line(n, m, GOLD, 2.0, true)
			h._ball(m, 6, 6, GOLD, 0.0, 1.0, 0.95, 1.0)
			h._dot(m, 2.4, Color("#FF3B6B"))
		h._ball(n, 5, 5, GOLD, 0.0, 1.0, 0.95, 1.0)
		return
	var res := _cape_pts(a, 1.1, 0.62, func(s: float) -> float: return sin(s * TAU * 2.0 + t * 1.5) * 5.0)
	_cape_fill(h, a, res[0], Color("#E23A5E"), Color("#5E0A26"))
	var hem: PackedVector2Array = res[1]
	for i in [4, 8, 12]:
		var hp: Vector2 = hem[i]
		h.ci.draw_line(Vector2(hp.x * 0.8 + b.x * 0.2, b.y - w * 0.05), hp + Vector2(0, -6), Color(0.2, 0.0, 0.08, 0.3), 7.0, true)
	# горностаевая кайма
	for i in hem.size():
		h._ball(hem[i] + Vector2(0, -3), w * 0.055, w * 0.04, Color("#FAF8FF"), 0.0, 1.2, 0.3, 0.0)
	for i in range(1, hem.size(), 3):
		h._ball(hem[i] + Vector2(0, -2), w * 0.014, w * 0.03, Color("#2A2436"), 0.0, 1.0, 0.6, 0.0)
	# воротник
	for sx in [-1.0, 1.0]:
		for k in 3:
			h._ball(b + Vector2(sx * w * (0.3 + k * 0.08), -w * (0.32 - k * 0.06)), w * 0.06, w * 0.05, Color("#FAF8FF"), 0.0, 1.2, 0.3, 1.0)


## МАНТИЯ ПОЛНОЙ ЛУНЫ (легендарная): плащ из ночного неба с большой светящейся луной,
## звёзды плывут по ткани, край роняет блёстки
static func fullmoon_mantle(h, a: Dictionary, t: float, behind: bool) -> void:
	var w: float = a.back_w
	var b: Vector2 = a.back
	if not behind:
		var n: Vector2 = a.neck + Vector2(0, 6)
		h._glow(n, 20, 20, Color(1.0, 0.92, 0.6, 0.4))
		h._T = Transform2D(0.0, n)
		h._shape(["fm_clasp"], crescent(Vector2.ZERO, 12.0, 0.4), Vector2(-5, -1), GOLD, 1.0, 0.95, 1.2)
		h._fill(star_pts(Vector2(7, -5), 6, 2.4, 5), Color("#FFF6D0"))
		h._T = Transform2D.IDENTITY
		return
	var res := _cape_pts(a, 1.28, 0.66, func(s: float) -> float: return sin(s * TAU * 2.0 + t * 1.4) * 6.0, 19)
	var pts: PackedVector2Array = res[0]
	_cape_fill(h, a, pts, Color("#2A3A9E"), Color("#080B2E"))
	var hem: PackedVector2Array = res[1]
	# звёзды плывут по ткани (в пределах силуэта плаща)
	for i in 10:
		var ph := fposmod(t * 0.05 + hs(i, 4), 1.0)
		var p := b + Vector2(lerpf(-0.78, 0.78, ph) * w, w * (-0.05 + hs(i, 5) * 0.6))
		if Geometry2D.is_point_in_polygon(p, pts):
			var tw := 0.5 + 0.5 * sin(t * 3.0 + i * 2.1)
			var e := sin(ph * PI)
			h._sparkle(p, w * (0.018 + 0.016 * tw) * e + 0.5, Color(1.0, 0.97, 0.85, (0.45 + 0.55 * tw) * e))
	# большая луна сбоку
	var mc := b + Vector2(-w * 0.66, w * 0.3)
	var mr := w * 0.14
	h._glow(mc, mr * 2.8, mr * 2.8, Color(1.0, 0.95, 0.7, snappedf(0.3 + 0.1 * sin(t * 1.5), 0.04)))
	h._ball(mc, mr, mr, Color("#FFF1B8"), 0.0, 1.1, 0.5)
	for cr in [[Vector2(-0.3, -0.2), 0.22], [Vector2(0.3, 0.25), 0.16], [Vector2(0.1, -0.45), 0.1], [Vector2(-0.2, 0.45), 0.12]]:
		h._ball(mc + cr[0] * mr, mr * cr[1], mr * cr[1], Color("#EAD48A"), 0.0, 1.0, 0.1, 0.0)
	# кайма и блёстки с края
	h.ci.draw_polyline(hem, Color("#5A64A8"), 7.0, true)
	h.ci.draw_polyline(hem, Color("#DCE4FF"), 3.5, true)
	for i in 10:
		var ph := fposmod(t * 0.55 + hs(i, 7), 1.0)
		var hp: Vector2 = hem[int(hs(i, 8) * (hem.size() - 1))]
		var p := hp + Vector2(sin(ph * 6.0 + i) * 4.0, ph * w * 0.28)
		h._sparkle(p, w * 0.022 * (1.0 - ph) + 0.5, Color(1.0, 0.95, 0.75, 1.0 - ph))
