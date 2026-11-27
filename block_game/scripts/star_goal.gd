extends RefCounted
## 0.18: строка «до 3 звёзд» на панели уровня.
## 0.19: здесь же общая формула звёзд за победу (game.gd _win, экран победы, обучение):
## 3 — фигур не больше limit(par, 3) = ceil(par × K3), 2 — не больше limit(par, 2) = ceil(par × K2), иначе 1.
## (до 0.19: 3 — не больше par, 2 — не больше int(par × 1.4); живые игроки почти всегда получали 1 звезду.)
## Строка показывает, сколько фигур ещё можно поставить (вместе с той, что падает сейчас),
## чтобы получить 3 звезды; когда этот предел пройден — сколько до 2 звёзд; когда пройден
## и он — строка прячется.

const I18n := preload("res://scripts/i18n.gd")


## 0.19: нормы под живого человека (подобраны роботом tools/level_bot.gd в режиме «человек», см. README).
const K3 := 1.5
const K2 := 3.0


## Предел фигур для звёзд n (3 или 2): ceil(par × K), не меньше par.
static func limit(par: int, n: int) -> int:
	var k := K3 if n >= 3 else K2
	return maxi(par, ceili(par * k - 0.0001))


## Звёзды за победу, в которой поставлено used фигур (1–3).
static func stars(par: int, used: int) -> int:
	if used <= limit(par, 3):
		return 3
	return 2 if used <= limit(par, 2) else 1


## [звёзды, сколько фигур ещё можно] или [0, 0] — строка не нужна.
static func goal(par: int, used: int) -> Array:
	for n in [3, 2]:
		var left := limit(par, n) - used
		if left > 0:
			return [n, left]
	return [0, 0]


## Нарисовать строку на панели: звёздочки и «ещё N». Возвращает высоту строки (0 — не рисовалась).
static func draw(g, x: float, y: float, w: float, size: int) -> float:
	var gl := goal(g.par, g.pieces_used)
	if gl[0] == 0:
		return 0.0
	var r := 9.0 * size / 22.0
	for i in gl[0]:
		g._draw_star(Vector2(x + r + 2 + i * (r * 2 + 2), y - size * 0.36), r, true)
	var tx: float = x + gl[0] * (r * 2 + 2) + 8
	var txt := I18n.t("goal_left") % gl[1]
	var fs: int = g.assist_ui.fit(txt, size, w - (tx - x))
	var col: Color = g.TEXT if gl[0] == 3 else g.DIM
	if gl[1] <= 2:
		col = g.ACCENT
	g.draw_string(g.font, Vector2(tx, y), txt, HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x), fs, col)
	return size + 12.0


## 0.19: строка под звёздами на экране победы. Не 3 звезды — «— за 12 фигур и меньше · у тебя 15»
## (перед ней рисуются три звёздочки, см. draw_win_line); 3 звезды — похвала.
static func win_line(par: int, used: int) -> String:
	if stars(par, used) >= 3:
		return I18n.t("win_perfect")
	var n := limit(par, 3)
	return I18n.t("win_need3") % [n, I18n.forms("win_pieces_forms", n), used]


## 0.19: нарисовать строку win_line по центру на высоте y (базовая линия). Возвращает ширину строки.
static func draw_win_line(g, cx: float, y: float, max_w: float, size: int) -> float:
	var three: bool = g.last_stars >= 3
	var txt := win_line(g.par, g.pieces_used)
	var r := 9.0 * size / 22.0
	var icons := 0.0 if three else 3 * (r * 2 + 2) + 8
	var fs: int = g.assist_ui.fit(txt, size, max_w - icons) if g.assist_ui else size
	var tw: float = g.font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := cx - (icons + tw) / 2.0
	if not three:
		for i in 3:
			g._draw_star(Vector2(x + r + 2 + i * (r * 2 + 2), y - fs * 0.36), r, true)
	g.draw_string(g.font, Vector2(x + icons, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, g.ACCENT if three else g.TEXT)
	return icons + tw
