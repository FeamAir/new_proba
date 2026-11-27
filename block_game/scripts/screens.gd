extends RefCounted
## Экраны мета-слоя Cascado (0.6, четыре друга — 0.9): выбор героя, дом, гардероб (вещи и украшения дома),
## карта-путешествие, экраны победы и поражения. Рисуют на узле игры (g — scripts/game.gd)
## и обрабатывают касания на этих экранах. Правила уровня — в game.gd, данные — в meta.gd.

const Meta := preload("res://scripts/meta.gd")
const Hero := preload("res://scripts/hero.gd")
const Home := preload("res://scripts/home.gd")
const I18n := preload("res://scripts/i18n.gd")
const TryOn := preload("res://scripts/tryon.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")
## 0.12: редкости (рамки и блеск карточек)
const Rarity := preload("res://scripts/rarity.gd")
const Swipe := preload("res://scripts/swipe.gd")
const SpecialsDraw := preload("res://scripts/specials_draw.gd")  # 0.18: значки новых целей на карте
const Levels := preload("res://scripts/levels.gd")
const StarGoal := preload("res://scripts/star_goal.gd")  # 0.19: строка «★★★ — за N фигур» на экране победы
## 0.18: первая карточка каждой вкладки вещей — «ничего» (у окраски — «Родной окрас»): снять вещь слота
const BARE := "_bare"
## 0.12: вещей на странице гардероба (2 ряда по 3)
const PAGE_SIZE := 6

const NODE_GAP := 130.0     # шаг между уровнями на карте
const HALL_HEAD := 240.0    # место под заголовок зала
const MAP_TOP := 150.0
const DARK_TEXT := Color("#2A1A0A")
const OK_COL := Color("#3DDC97")
const BAD_COL := Color("#FF6B8A")
## Выбор друга: подсветка и масштаб каждого героя в карточке
const PICK_GLOW := {"owl": Color("#B46CFF"), "axolotl": Color("#FF8FD8"), "puppy": Color("#FFB547"), "kitten": Color("#7FE3FF")}
const PICK_SCALE := {"owl": 0.66, "axolotl": 0.6, "puppy": 0.66, "kitten": 0.66}
## Масштаб героя на сцене гардероба
const WR_SCALE := {"owl": 1.5, "axolotl": 1.36, "puppy": 1.42, "kitten": 1.44}

var g                       # узел игры
var hero = Hero.new()
var home = Home.new()
var react := 99.0           # секунд с касания героя
var fade := 0.0             # затемнение при смене героя
var pick_choice := ""
var tab := "head"           # вкладка гардероба: слот или "home"
var spot := "floor_l"       # выбранное место для украшения
var toast := ""
var toast_t := 0.0
var rects := {}             # кнопки текущего экрана (заполняются при рисовании)
var map_scroll := 0.0
var map_vel := 0.0
var drag := {}
var tryon = TryOn.new()     # примерка некупленной вещи / украшения (scripts/tryon.gd)
var fx_t := 99.0            # секунд с покупки (короткий эффект)
var fx_at := Vector2.ZERO
var focus := Vector2.ZERO   # где на сцене гардероба герой / место примерки
var page := 0               # 0.12: страница вещей во вкладке гардероба
var strip = Swipe.new()     # 0.18: свайп по сетке вещей листает страницы
## 0.14: гардероб открыт с экрана «Дом» по «+» у места (или по цели «Можно купить») — после покупки
## или размещения украшения игрок сразу возвращается домой, камера 3D-дома подлетает к новой вещи
var from_home_spot := false


func _init(game) -> void:
	g = game


func update(delta: float) -> void:
	react += delta
	fade = maxf(0.0, fade - delta * 2.5)
	toast_t = maxf(0.0, toast_t - delta)
	fx_t += delta
	if drag.is_empty() and absf(map_vel) > 1.0:
		map_scroll += map_vel * delta
		map_vel = move_toward(map_vel, 0.0, maxf(600.0, absf(map_vel) * 3.0) * delta)
		_clamp_scroll()


func poke_hero() -> void:
	react = 0.0


func say(text: String) -> void:
	toast = text
	toast_t = 1.8


# ---------- Общие элементы ----------

func _text(pos: Vector2, s: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	g.draw_string(g.font, pos, s, align, width, size, col)


## Размер шрифта, при котором строка влезает в ширину (не меньше 14).
func fit_size(s: String, w: float, size: int) -> int:
	while size > 14 and g.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		size -= 1
	return size


func _ctext(cx: float, y: float, s: String, size: int, col: Color, width := 700.0) -> void:
	g.draw_string(g.font, Vector2(cx - width / 2.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _shadow_text(cx: float, y: float, s: String, size: int, col: Color, width := 700.0) -> void:
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 3)]:
		g.draw_string(g.font, Vector2(cx - width / 2.0, y) + o, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0.05, 0.03, 0.1, 0.8))
	_ctext(cx, y, s, size, col, width)


## Иконка осколка — маленький кристалл
func shard_icon(c: Vector2, r: float) -> void:
	g.draw_circle(c, r * 1.3, Color(0.62, 0.96, 1.0, 0.15), true, -1.0, true)
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.62, -r * 0.3), c + Vector2(r * 0.4, r * 0.75),
		c + Vector2(-r * 0.4, r * 0.75), c + Vector2(-r * 0.62, -r * 0.3)])
	g.draw_colored_polygon(pts, g.CRYSTAL_COL)
	var cl := pts.duplicate()
	cl.append(pts[0])
	g.draw_polyline(cl, Color("#3A7FA0"), maxf(1.5, r * 0.12), true)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.62, -r * 0.3), c + Vector2(0, -r * 0.05)]), Color(1, 1, 1, 0.65))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.05), c + Vector2(r * 0.4, r * 0.75), c + Vector2(-r * 0.4, r * 0.75)]), Color(0.1, 0.45, 0.6, 0.35))


func _lock_icon(c: Vector2, s: float, col: Color) -> void:
	g.draw_arc(c + Vector2(0, -s * 0.35), s * 0.45, PI, TAU, 12, col, s * 0.18, true)
	g.draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.35), Vector2(s * 1.3, s)), col)
	g.draw_circle(c + Vector2(0, s * 0.1), s * 0.16, Color("#1A1030"), true, -1.0, true)


func _pill(r: Rect2, col: Color) -> void:
	g._rbox(r, col, int(r.size.y / 2.0))


func _button(name: String, r: Rect2, label: String, primary := false, size := 36, enabled := true) -> void:
	rects[name] = r
	var col: Color = g.ACCENT if primary else g.BTN
	if not enabled:
		col = Color(col, 0.4)
	if primary:
		g._rbox(r.grow(5), Color(g.ACCENT, 0.22), 30)
	g._rbox(r, col, 26)
	g._rbox(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, r.size.y * 0.42)), Color(1, 1, 1, 0.08), 22)
	_text(Vector2(r.position.x, r.get_center().y + size * 0.36), label, size, DARK_TEXT if primary else g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Кнопка языка: глобус и код (EN / RU). Нажатие — следующий язык, выбор сохраняется.
func _lang_button(r: Rect2) -> void:
	rects["lang"] = r
	_pill(r, Color(0.1, 0.06, 0.2, 0.78))
	var c := r.position + Vector2(30, r.size.y / 2.0)
	var rad := 14.0
	g.draw_arc(c, rad, 0, TAU, 28, g.TEXT, 2.5, true)
	g.draw_line(c - Vector2(rad, 0), c + Vector2(rad, 0), g.TEXT, 2.0, true)
	g.draw_line(c - Vector2(0, rad), c + Vector2(0, rad), g.TEXT, 2.0, true)
	g.draw_set_transform(c, 0.0, Vector2(0.45, 1.0))
	g.draw_arc(Vector2.ZERO, rad, 0, TAU, 28, g.TEXT, 2.5, true)
	g.draw_set_transform(Vector2.ZERO)
	_text(Vector2(r.position.x + 50, r.position.y + r.size.y / 2.0 + 11), I18n.lang_code(), 30, g.TEXT)


func _tap_lang(pos: Vector2) -> bool:
	if not rects.get("lang", Rect2()).has_point(pos):
		return false
	g.play("click")
	g.toggle_language()
	say(I18n.lang_name())
	return true


func _back_button() -> void:
	var r := Rect2(20, 30, 92, 76)
	rects["back"] = r
	g._rbox(r, g.BTN, 22)
	var c := r.get_center()
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 0), c + Vector2(0, -18), c + Vector2(0, 18)]), g.TEXT)
	g.draw_rect(Rect2(c + Vector2(-2, -7), Vector2(24, 14)), g.TEXT)


func _counters(right: float, y: float) -> void:
	var sw := 150.0
	var shr := Rect2(right - sw, y, sw, 58)
	var str_ := Rect2(right - sw * 2 - 12, y, sw, 58)
	_pill(str_, Color(0.1, 0.06, 0.2, 0.78))
	g._draw_star(str_.position + Vector2(32, 29), 18, true)
	_text(str_.position + Vector2(58, 42), str(g.total_stars()), 34, g.ACCENT)
	rects["shards"] = shr
	_pill(shr, Color(0.1, 0.06, 0.2, 0.78))
	shard_icon(shr.position + Vector2(32, 29), 17)
	_text(shr.position + Vector2(58, 42), str(g.meta.shards), 34, g.CRYSTAL_COL)


func avatar(c: Vector2, r: float, ring := Color(-1, 0, 0)) -> void:
	if ring.r < 0:
		ring = Meta.hall(g.max_level).col
	hero.draw_avatar(g, g.meta.hero if g.meta.hero != "" else "owl", c, r, g.meta.outfit(), g.t_total, ring, react)


func _toast(y: float) -> void:
	if toast_t <= 0.0:
		return
	var a := clampf(toast_t / 0.3, 0.0, 1.0)
	var w := minf(680.0, g.font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 60.0)
	var r := Rect2((g.W - w) / 2.0, y, w, 64)
	g._rbox(r, Color(0.08, 0.04, 0.16, 0.92 * a), 30)
	_ctext(g.W / 2.0, y + 43, toast, 30, Color(g.TEXT, a), w)


func _fade_over(r: Rect2) -> void:
	if fade > 0.0:
		g.draw_rect(r, Color(0.02, 0.01, 0.05, clampf(fade, 0.0, 1.0)))


# ---------- Выбор героя ----------

func draw_pick() -> void:
	rects.clear()
	var H: float = g.H
	var oy := (H - 1280.0) * 0.4
	_shadow_text(g.W / 2.0, 136 + oy, I18n.t("pick_title"), 60, g.TEXT)
	_ctext(g.W / 2.0, 188 + oy, I18n.t("pick_sub"), 28, g.DIM)
	# четыре друга — сетка 2×2 (0.13: каждый — в выбранном виде: мальчик или девочка)
	for i in Meta.HEROES.size():
		var kind: String = Meta.HEROES[i]
		var r := Rect2(24 + (i % 2) * 344, 216 + oy + (i / 2) * 304, 328, 290)
		rects["hero_" + kind] = r
		var sel := pick_choice == kind
		if sel:
			g._rbox(r.grow(8), Color(g.ACCENT, 0.3 + 0.1 * sin(g.t_total * 4.0)), 40)
		g._rbox(r, Color("#2A1A4F") if not sel else Color("#3A2468"), 34)
		var glow: Color = PICK_GLOW.get(kind, Color("#B46CFF"))
		for k in 4:
			g.draw_circle(r.position + Vector2(r.size.x / 2.0, 114), 108 - k * 21, Color(glow, 0.05 + k * 0.02), true, -1.0, true)
		var sc: float = PICK_SCALE.get(kind, 0.64) * 0.96
		hero.draw(g, kind, r.position + Vector2(r.size.x / 2.0, 132), sc, g.meta.outfit_for(kind), g.t_total + i * 1.7, react if sel else 99.0)
		var nm: String = g.meta.display_name(kind)
		_ctext(r.get_center().x, r.end.y - 46, nm, fit_size(nm, r.size.x - 20, 36), g.ACCENT if sel else g.TEXT, r.size.x)
		var lv := I18n.t("pick_lives_" + kind)
		_ctext(r.get_center().x, r.end.y - 14, lv, fit_size(lv, r.size.x - 16, 22), g.DIM, r.size.x)
	# 0.13: мальчик или девочка — для выбранного друга (по умолчанию мальчик, можно сменить в любой момент)
	if pick_choice != "":
		gender_toggle(Rect2(60, 836 + oy, 600, 88), pick_choice, true)
	_button("ok", Rect2(160, 946 + oy, 400, 112), I18n.t("pick_ok"), true, 50, pick_choice != "")
	_ctext(g.W / 2.0, 1096 + oy, I18n.t("pick_hint"), 26, g.DIM)
	_lang_button(Rect2(g.W - 136, 24 + oy * 0.5, 116, 58))
	_toast(1120 + oy)


func tap_pick(pos: Vector2) -> void:
	if _tap_lang(pos):
		return
	if pick_choice != "" and tap_gender(pos, pick_choice):
		return
	for kind in Meta.HEROES:
		if rects.get("hero_" + kind, Rect2()).has_point(pos):
			pick_choice = kind
			poke_hero()
			g.play("crystal")
			return
	if rects.get("ok", Rect2()).has_point(pos) and pick_choice != "":
		# 0.16: смена мгновенная — у каждого друга свои вещи и дом, ничего не снимается
		var first: bool = g.meta.hero == ""
		var changed: bool = g.meta.hero != pick_choice
		g.meta.switch_hero(pick_choice)
		if changed and g.meta.take_switch_hint(first):
			g.notice_ui.show_hint(pick_choice)
		g._save()
		g.play("levelup")
		fade = 1.0
		g.go_home()


# ---------- 0.13: мальчик / девочка и имя ----------

const BOY_COL := Color("#5FC8FF")
const GIRL_COL := Color("#FF8FCB")


## Значок пола: "boy" — кружок со стрелкой (♂), "girl" — кружок с крестиком (♀). Рисуется линиями
## (в шрифте может не быть этих знаков).
func gender_icon(c: Vector2, s: float, gender: String, col: Color) -> void:
	var w := maxf(2.5, s * 0.12)
	if gender == "boy":
		var o := c + Vector2(-s * 0.12, s * 0.12)
		g.draw_arc(o, s * 0.32, 0, TAU, 24, col, w, true)
		var tip := c + Vector2(s * 0.42, -s * 0.42)
		g.draw_line(o + Vector2(s * 0.23, -s * 0.23), tip, col, w, true)
		g.draw_line(tip, tip + Vector2(-s * 0.26, 0), col, w, true)
		g.draw_line(tip, tip + Vector2(0, s * 0.26), col, w, true)
	else:
		var o := c + Vector2(0, -s * 0.16)
		g.draw_arc(o, s * 0.3, 0, TAU, 24, col, w, true)
		g.draw_line(o + Vector2(0, s * 0.3), c + Vector2(0, s * 0.56), col, w, true)
		g.draw_line(c + Vector2(-s * 0.18, s * 0.38), c + Vector2(s * 0.18, s * 0.38), col, w, true)


## Переключатель «мальчик / девочка» для героя kind: две кнопки (labels — с подписями,
## иначе круглые значки). Кнопки — rects "g_boy" / "g_girl".
## На экране выбора (labels) без предвыбора: пока игрок не выбрал, обе кнопки не подсвечены
## (герой нарисован мальчиком — так по умолчанию); в гардеробе подсвечен текущий вид.
func gender_toggle(r: Rect2, kind: String, labels: bool) -> void:
	var cur: String = g.meta.gender_of(kind) if (not labels or g.meta.genders.has(kind)) else ""
	var gap := 12.0 if labels else 8.0
	var bw := (r.size.x - gap) / 2.0
	for i in 2:
		var gd: String = ["boy", "girl"][i]
		var col: Color = BOY_COL if gd == "boy" else GIRL_COL
		var br := Rect2(r.position.x + i * (bw + gap), r.position.y, bw, r.size.y)
		rects["g_" + gd] = br
		var on := gd == cur
		if on:
			g._rbox(br.grow(4), Color(col, 0.3 + 0.08 * sin(g.t_total * 4.0)), int(br.size.y / 2.0) + 4)
		g._rbox(br, col if on else Color(0.1, 0.06, 0.2, 0.88), int(br.size.y / 2.0))
		if not on:
			g.draw_polyline(_rr_outline(br.grow(-1), br.size.y / 2.0 - 1), Color(col, 0.75), 2.5, true)
		var ic_col: Color = DARK_TEXT if on else col
		if labels:
			var lbl := I18n.t("gender_" + gd)
			var fs := fit_size(lbl, bw - 96, 32)
			var lw: float = g.font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var x0: float = br.get_center().x - (lw + 52) / 2.0
			gender_icon(Vector2(x0 + 20, br.get_center().y), 40, gd, ic_col)
			_text(Vector2(x0 + 52, br.get_center().y + fs * 0.36), lbl, fs, ic_col)
		else:
			gender_icon(br.get_center(), br.size.y * 0.62, gd, ic_col)


## Касание переключателя пола (для героя kind). true — касание обработано.
func tap_gender(pos: Vector2, kind: String) -> bool:
	for gd in ["boy", "girl"]:
		if rects.get("g_" + gd, Rect2()).has_point(pos):
			if g.meta.gender_of(kind) != gd or not g.meta.genders.has(kind):
				g.meta.set_gender(kind, gd)  # вещи не снимаются, осколки не возвращаются — тот же герой
				g._save()
				g.play("crystal", 1.15 if gd == "girl" else 0.95)
				say(I18n.t("gender_now_" + gd))
			else:
				g.play("click", 0.9)
			poke_hero()
			return true
	return false


## Кнопка имени: карандашик и имя героя (или «Имя», если не задано). Rect — "name".
func name_button(r: Rect2, kind: String) -> Rect2:
	var nm: String = g.meta.name_of(kind)
	var lbl: String = nm if nm != "" else I18n.t("name_give")
	var fs := fit_size(lbl, r.size.x - 62, 26)
	var lw: float = g.font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := minf(r.size.x, lw + 70.0)
	var br := Rect2(r.position, Vector2(w, r.size.y))
	rects["name"] = br
	_pill(br, Color(0.1, 0.06, 0.2, 0.88))
	g.draw_polyline(_rr_outline(br.grow(-1), br.size.y / 2.0 - 1), Color(g.ACCENT, 0.7), 2.0, true)
	pencil_icon(br.position + Vector2(26, br.size.y / 2.0), 26, g.ACCENT)
	_text(Vector2(br.position.x + 48, br.get_center().y + fs * 0.36), lbl, fs, g.TEXT if nm != "" else g.ACCENT)
	return br


## Карандашик (в шрифте может не быть знака ✎)
func pencil_icon(c: Vector2, s: float, col: Color) -> void:
	var d := Vector2(1, -1).normalized()
	var a := c - d * s * 0.42
	var b := c + d * s * 0.3
	var n := d.orthogonal() * s * 0.14
	g.draw_colored_polygon(PackedVector2Array([b + n, b - n, a - n, a + n]), col)
	g.draw_colored_polygon(PackedVector2Array([a + n, a - n, a - d * s * 0.2]), Color(col, 0.6))
	g.draw_colored_polygon(PackedVector2Array([b + n, b + d * s * 0.16 + n, b + d * s * 0.16 - n, b - n]), Color("#FF8FB8"))


## 0.16: сменить друга — сразу, без окна: у каждого друга свой гардероб и свой дом (meta.gd,
## switch_hero). При первой смене в жизни — плашка-подсказка (scripts/notice_ui.gd, show_hint).
func request_switch(h: String) -> void:
	if h == g.meta.hero or not g.meta.switch_hero(h):
		return
	tryon.clear()
	page = 0
	fade = 1.0
	poke_hero()
	if g.meta.take_switch_hint(false):
		g.notice_ui.show_hint(h)
	g._save()


# ---------- Дом ----------

func _home_view() -> Array:
	var H: float = g.H
	var oy := (H - 1280.0) * 0.5
	return [Vector2(0, oy), Rect2(0, -oy, 720, H)]


func draw_home() -> void:
	rects.clear()
	var H: float = g.H
	var hv := _home_view()
	var kind: String = g.meta.hero if g.meta.hero != "" else "owl"
	var du = g.decor_ui
	var decorating: bool = du != null and du.active
	var placed: Dictionary = du.tryon.placed(g.meta, kind) if decorating else g.meta.decor_placed.get(kind, {})
	if g.home3d.showing():
		# 0.12: 3D-дом (scripts/home3d/); касания мимо кнопок крутят камеру, тап по месту / герою — там же
		g.home3d.draw(g, Rect2(0, 0, g.W, H))
	else:
		# запасной 2D-дом: 3D недоступно или выбрано «Графика: 2D» (0.15: стиль комнаты — оттенком;
		# метки «+» пустых мест — только в режиме украшения)
		var room_st: Dictionary = du.tryon.room(g.meta, kind) if decorating else g.meta.room_of(kind)
		home.draw(g, kind, hv[0], 1.0, hv[1], Meta.home_stage(g.max_level), placed, g.meta.outfit(), g.t_total, react,
			du.spot if decorating else "", decorating, room_st)
		var ha: Array = Home.HERO_AT[kind]
		if not decorating:
			rects["hero"] = Rect2(hv[0] + ha[0] - Vector2(110, 130), Vector2(220, 240))
		for s in Catalog.spot_ids(kind):
			if decorating or placed.get(s, "") != "":
				var sp: Vector2 = home.spot_screen(kind, s)
				if sp.x > -999.0:
					rects["spot_" + s] = Rect2(sp - Vector2(56, 56), Vector2(112, 112))
	if decorating:
		du.draw()
		_buy_fx()
		_fade_over(Rect2(0, 0, g.W, H))
		return
	# верхняя полоса
	g.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(g.W, 0), Vector2(g.W, 250), Vector2(0, 250)]),
		PackedColorArray([Color(0.04, 0.02, 0.1, 0.75), Color(0.04, 0.02, 0.1, 0.75), Color(0.04, 0.02, 0.1, 0), Color(0.04, 0.02, 0.1, 0)]))
	var L := home_layout()  # 0.17: те же прямоугольники видит экскурсия (scripts/home_tour.gd)
	avatar(Vector2(72, 72), 48)
	rects["avatar"] = L.avatar_btn
	# 0.13: имя друга (или Совёнок / Совушка...) под аватаркой
	var dn: String = g.meta.display_name(kind)
	var dfs := fit_size(dn, 136, 22)
	var dw: float = minf(150.0, g.font.get_string_size(dn, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs).x + 26.0)
	var dr := Rect2(72 - dw / 2.0, 124, dw, 34)
	if dr.position.x < 8:
		dr.position.x = 8
	_pill(dr, Color(0.1, 0.06, 0.2, 0.85))
	_text(Vector2(dr.position.x, dr.position.y + 25), dn, dfs, g.TEXT, dr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_counters(g.W - 20, 44)
	_lang_button(L.lang)
	g.forge_ui.draw_home_button()  # 0.12: вход в Кристальную кузницу
	g._draw_title(Vector2(g.W / 2.0, 200), 80, 6.0)
	# нижняя полоса с кнопками
	var by := H - 410.0  # 0.9: под «Играть» — цель «До следующей вещи» (assist_ui.gd)
	g.draw_polygon(PackedVector2Array([Vector2(0, by - 60), Vector2(g.W, by - 60), Vector2(g.W, H), Vector2(0, H)]),
		PackedColorArray([Color(0.04, 0.02, 0.1, 0), Color(0.04, 0.02, 0.1, 0), Color(0.04, 0.02, 0.1, 0.9), Color(0.04, 0.02, 0.1, 0.9)]))
	var hall: Dictionary = Meta.hall(g.max_level)
	var label := I18n.t("home_depth") % [Meta.hall_name(Meta.hall_index(g.max_level)), Meta.depth(g.max_level)]
	var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 48.0
	var lr := Rect2((g.W - lw) / 2.0, by - 6, lw, 44)
	_pill(lr, Color(0.08, 0.04, 0.16, 0.85))
	g.draw_circle(lr.position + Vector2(22, 22), 7, hall.col, true, -1.0, true)
	_ctext(g.W / 2.0 + 8, by + 26, label, 26, g.TEXT, lw)
	var pr: Rect2 = L.play
	var pulse := 1.0 + 0.03 * sin(g.t_total * 4.0)
	var pb := Rect2(pr.get_center() - pr.size * pulse / 2.0, pr.size * pulse)
	rects["play"] = pr
	g._rbox(pb.grow(6), Color(g.ACCENT, 0.25), 40)
	g._rbox(pb, g.ACCENT, 36)
	g._rbox(Rect2(pb.position + Vector2(8, 6), Vector2(pb.size.x - 16, pb.size.y * 0.4)), Color(1, 1, 1, 0.14), 30)
	_ctext(g.W / 2.0, pr.position.y + 70, I18n.t("play"), 56, DARK_TEXT)
	_ctext(g.W / 2.0, pr.position.y + 108, I18n.t("level_n") % g.max_level, 28, Color("#5A3A10"))
	# 0.15: три кнопки: Карта, Украсить, Гардероб (значок сверху, подпись снизу)
	var bw: float = (g.W - 40.0 - 2 * 12.0) / 3.0
	var names := ["map", "decorate", "wardrobe"]
	for i in 3:
		var br: Rect2 = L[names[i]]
		_button(names[i], br, "", false)
		var ic := br.position + Vector2(bw / 2.0, 36)
		match names[i]:
			"map": _map_icon(ic)
			"decorate": brush_icon(ic)
			"wardrobe": _hanger_icon(ic)
		var lbl := I18n.t(names[i])
		_text(Vector2(br.position.x, br.position.y + 92), lbl, fit_size(lbl, bw - 12, 28), g.TEXT, bw, HORIZONTAL_ALIGNMENT_CENTER)
	_toast(260)
	_fade_over(Rect2(0, 0, g.W, H))


## 0.17: где кнопки главного экрана (для рисования и для экскурсии по дому, scripts/home_tour.gd).
## avatar — аватарка вместе с именем под ней; avatar_btn — только кружок (касание).
func home_layout() -> Dictionary:
	var H: float = g.H
	var by := H - 410.0
	var bw: float = (g.W - 40.0 - 2 * 12.0) / 3.0
	var L := {
		"avatar_btn": Rect2(20, 20, 104, 104),
		"avatar": Rect2(8, 20, 136, 138),
		"lang": Rect2(140, 44, 116, 58),
		"shards": Rect2(g.W - 20 - 150, 44, 150, 58),
		"play": Rect2(100, by + 52, 520, 128),
		"forge": g.forge_ui.home_button_rect() if g.forge_ui else Rect2(),
		"trophies": g.trophy_ui._button_rect() if g.trophy_ui else Rect2(),
	}
	var names := ["map", "decorate", "wardrobe"]
	for i in 3:
		L[names[i]] = Rect2(20 + i * (bw + 12), H - 140, bw, 104)
	return L


func _map_icon(c: Vector2) -> void:
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -20), c + Vector2(-8, -26), c + Vector2(8, -20), c + Vector2(26, -26),
		c + Vector2(26, 22), c + Vector2(8, 28), c + Vector2(-8, 22), c + Vector2(-26, 28)]), Color("#E8D6A8"))
	g.draw_polyline(PackedVector2Array([c + Vector2(-18, 16), c + Vector2(-6, 2), c + Vector2(6, 8), c + Vector2(16, -12)]), Color("#C0392B"), 3.0, true)
	g.draw_circle(c + Vector2(16, -12), 5, Color("#C0392B"), true, -1.0, true)


## 0.15: значок «Украсить» — кисточка с каплей краски и звёздочкой
func brush_icon(c: Vector2) -> void:
	var a := Vector2(-20, 22)
	var b := Vector2(10, -8)
	g.draw_line(c + a, c + b, Color("#C98A5C"), 7.0, true)
	g.draw_line(c + b, c + b + Vector2(6, -6), Color("#D9DDE8"), 9.0, true)
	g.draw_colored_polygon(PackedVector2Array([c + b + Vector2(3, -9), c + b + Vector2(9, -3), c + Vector2(26, -24), c + Vector2(22, -28)]), Color("#FF5A7A"))
	g.draw_circle(c + Vector2(24, -26), 5, Color("#FF5A7A"), true, -1.0, true)
	g.draw_colored_polygon(_star(c + Vector2(-17, -15), 11, 4, 4), g.ACCENT)


func _hanger_icon(c: Vector2) -> void:
	g.draw_arc(c + Vector2(0, -16), 7, PI, TAU * 1.1, 10, g.TEXT, 4.0, true)
	g.draw_polyline(PackedVector2Array([c + Vector2(0, -9), c + Vector2(-28, 14), c + Vector2(28, 14), c + Vector2(0, -9)]), g.TEXT, 5.0, true)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 14), c + Vector2(16, 14), c + Vector2(22, 32), c + Vector2(-22, 32)]), Color("#FF5A7A"))


## true — касание обработано (кнопка, герой или место 2D-дома); false — мимо, его получает камера 3D-дома
func tap_home(pos: Vector2) -> bool:
	if _tap_lang(pos) or g.forge_ui.tap_home_button(pos):
		return true
	if rects.get("play", Rect2()).has_point(pos):
		g.play("click")
		g.start_level(g.max_level)
	elif rects.get("map", Rect2()).has_point(pos):
		g.play("click")
		open_map()
	elif rects.get("decorate", Rect2()).has_point(pos):
		g.play("click")
		g.decor_ui.open()  # 0.15: режим украшения комнаты
	elif rects.get("wardrobe", Rect2()).has_point(pos) or rects.get("avatar", Rect2()).has_point(pos):
		g.play("click")
		open_wardrobe("head" if tab == "home" else tab)
	elif rects.get("hero", Rect2()).has_point(pos):
		poke_hero()
		g.play("crystal", randf_range(0.9, 1.15), -6.0)
	else:
		for s in Catalog.spot_ids(g.meta.hero):
			if rects.get("spot_" + s, Rect2()).has_point(pos):
				g.play("click")
				g.decor_ui.open(s)  # 0.15: вещь в 2D-доме — режим украшения, это место выбрано
				return true
		return false
	return true


# ---------- Гардероб ----------

## focus_id (0.12) — открыть страницу вкладки, где эта вещь.
func open_wardrobe(t := "head", focus_id := "") -> void:
	if t == "home":
		# 0.15: украшения дома — в режиме украшения на экране «Дом» (выбрано место spot)
		tryon.clear()
		g.go_home()
		g.decor_ui.open(spot if Catalog.has_spot(_kind(), spot) else "", focus_id)
		return
	tab = t
	page = 0
	if focus_id != "" and t != "home":
		var i := _wr_items(_kind()).map(func(it): return it.id).find(focus_id)
		page = maxi(0, i) / PAGE_SIZE
	tryon.clear()
	# 0.14: вкладку «Дом» с экрана «Дом» открывает только «+» у места (кнопка «Гардероб» — другие вкладки)
	from_home_spot = t == "home" and g.state == g.State.HOME
	g._set_state(g.State.WARDROBE)


## Вкладки гардероба: слоты вещей и «Дом» (0.12: + спутник и сияние)
func wr_tabs() -> Array:
	var tabs := Meta.SLOTS.duplicate()
	tabs.append("home")
	return tabs


func _wr_items(kind: String) -> Array:
	if tab == "home":
		return Meta.decor_for(kind, spot)
	# 0.18: «Родной окрас» / «Без вещи» — всегда первая, бесплатная
	return [{"id": BARE, "slot": tab, "bare": true}] + Meta.items_in(tab, kind)


func _kind() -> String:
	return g.meta.hero if g.meta.hero != "" else "owl"


func page_count(n: int) -> int:
	return maxi(1, (n + PAGE_SIZE - 1) / PAGE_SIZE)


func _wr_layout() -> Dictionary:
	var H: float = g.H
	var card_h := 200.0
	var grid_y := H - 24.0 - card_h * 2 - 14.0
	var pager_y := grid_y - 58.0
	var tabs_y := pager_y - 74.0
	var chips_y := tabs_y - 76.0
	return {"grid_y": grid_y, "card_h": card_h, "tabs_y": tabs_y, "chips_y": chips_y, "pager_y": pager_y,
		"stage": Rect2(20, 122, 680, chips_y - 134.0)}


func draw_wardrobe() -> void:
	rects.clear()
	var L := _wr_layout()
	var kind: String = g.meta.hero if g.meta.hero != "" else "owl"
	_back_button()
	_text(Vector2(132, 84), I18n.t("wardrobe"), 46, g.TEXT)
	var shr := Rect2(g.W - 170, 38, 150, 58)
	_pill(shr, Color(0.1, 0.06, 0.2, 0.85))
	shard_icon(shr.position + Vector2(32, 29), 17)
	_text(shr.position + Vector2(58, 42), str(g.meta.shards), 34, g.CRYSTAL_COL)
	var st: Rect2 = L.stage
	g._rbox(st, Color(0.06, 0.035, 0.13, 0.9), 30)
	if tab == "home":
		var s := st.size.y / 740.0
		var x0 := (st.size.x / s - 720.0) / 2.0
		var view := Rect2(-x0, 160, 720 + 2 * x0, 740)
		var org := Vector2(st.get_center().x - 360.0 * s, st.position.y - view.position.y * s)
		var placed: Dictionary = tryon.placed(g.meta, kind)
		if g.home3d.showing_stage():
			# 0.12: 3D-дом в окне сцены: камера у выбранного места, примерка — с пульсирующим кольцом
			g.home3d.draw(g, st)
			focus = g.home3d.spot_screen(spot)
			if focus.x < 0.0:
				focus = st.get_center()
			for sp in Meta.SPOTS:
				var sc: Vector2 = g.home3d.spot_screen(sp)
				if sc.x >= 0.0:
					rects["spot_" + sp] = Rect2(sc - Vector2(50, 50), Vector2(100, 100))
		else:
			home.draw(g, kind, org, s, view, Meta.home_stage(g.max_level), placed, g.meta.outfit(), g.t_total, react, spot, false)
			focus = home.spot_screen(kind, spot)
			for sp in Meta.SPOTS:
				var sc: Vector2 = home.spot_screen(kind, sp)
				rects["spot_" + sp] = Rect2(sc - Vector2(50, 50), Vector2(100, 100))
		_text(Vector2(st.position.x + 18, st.position.y + 40), I18n.t("house_" + kind), 30, Color(g.TEXT, 0.8))
	else:
		for k in 5:
			g.draw_circle(st.get_center() + Vector2(0, 40), 260 - k * 45, Color(0.45, 0.25, 0.8, 0.05 + k * 0.015), true, -1.0, true)
		g.draw_colored_polygon(_ellipse(Vector2(st.get_center().x, st.end.y - 60), 210, 26), Color(0.2, 0.12, 0.36, 0.9))
		var sc: float = WR_SCALE.get(kind, 1.4) * (0.86 if Meta.item(tryon.outfit(g.meta).get("aura", "")).has("covers") else 1.0)
		var hp := Vector2(st.get_center().x, st.end.y - 60 - 112 * sc)
		hero.draw(g, kind, hp, sc, tryon.outfit(g.meta), g.t_total, react)
		rects["hero"] = Rect2(hp - Vector2(150, 170), Vector2(300, 320))
		focus = hp
	if tryon.active():
		_try_tag(st)
	_buy_fx()
	_fade_over(st)
	# что вылезло за сцену сверху — закрываем фоном, поверх шапка
	g.draw_rect(Rect2(0, 0, g.W, st.position.y), g.BG_TOP)
	_back_button()
	_text(Vector2(132, 84), I18n.t("wardrobe"), 46, g.TEXT)
	_pill(shr, Color(0.1, 0.06, 0.2, 0.85))
	shard_icon(shr.position + Vector2(32, 29), 17)
	_text(shr.position + Vector2(58, 42), str(g.meta.shards), 34, g.CRYSTAL_COL)
	# 0.12: кнопка Кристальной кузницы и счётчик коллекции
	var fr := Rect2(shr.position.x - 100, 38, 88, 58)
	rects["forge"] = fr
	g._rbox(fr, g.BTN, 22)
	g.draw_polyline(_rr_outline(fr.grow(-1), 21), Color("#9FF6FF", 0.45), 2.0, true)
	g.forge_ui.anvil_icon(fr.get_center() + Vector2(0, 2), 40)
	if g.meta.forge_ready_any(g.max_level):
		var pc := fr.position + Vector2(fr.size.x - 8, 6)
		var ps := 1.0 + 0.25 * sin(g.t_total * 8.0)
		g.draw_circle(pc, 15 * ps, Color(OK_COL, 0.3), true, -1.0, true)
		g.draw_circle(pc, 11, OK_COL, true, -1.0, true)
		g.draw_string(g.font, pc + Vector2(-11, 7), "!", HORIZONTAL_ALIGNMENT_CENTER, 22, 20, DARK_TEXT)
	if tab != "home":
		var col_lbl := I18n.t("collection") % [g.meta.collection_count(), Meta.collection_total(kind)]
		var cw0: float = g.font.get_string_size(col_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 30.0
		var cpr := Rect2(st.end.x - cw0 - 12, st.position.y + 12, cw0, 36)
		rects["collection"] = cpr
		_pill(cpr, Color(0.1, 0.06, 0.2, 0.85))
		_text(Vector2(cpr.position.x, cpr.position.y + 25), col_lbl, 20, Color("#FFD9F4"), cpr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(st.position.x + 18, st.position.y + 38), Meta.slot_name(tab), 28, Color(g.TEXT, 0.85))
		# 0.13: имя друга (кнопка «Имя») и мальчик / девочка — слева на сцене
		if not tryon.active():
			name_button(Rect2(st.position.x + 14, st.position.y + 56, 196, 48), kind)
			gender_toggle(Rect2(st.position.x + 14, st.position.y + 114, 124, 58), kind, false)
	# строка под сценой: герои или места для украшений
	if tab == "home":
		var n := Meta.SPOTS.size()
		var cw: float = (g.W - 40.0 - (n - 1) * 8.0) / n
		for i in n:
			var sp: String = Meta.SPOTS[i]
			var r := Rect2(20 + i * (cw + 8), L.chips_y, cw, 62)
			rects["chip_" + sp] = r
			var sel := sp == spot
			g._rbox(r, g.ACCENT if sel else g.BTN, 20)
			var has: bool = g.meta.placed_at(kind, sp) != ""
			if has and not sel:
				g.draw_circle(r.position + Vector2(r.size.x - 12, 12), 6, OK_COL, true, -1.0, true)
			var spn := Meta.spot_name(sp)
			_text(Vector2(r.position.x, r.position.y + 38), spn, fit_size(spn, r.size.x - 8, 17), DARK_TEXT if sel else g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var nh := Meta.HEROES.size()
		var hw: float = (g.W - 40.0 - (nh - 1) * 8.0) / nh
		for i in nh:
			var h: String = Meta.HEROES[i]
			var r := Rect2(20 + i * (hw + 8), L.chips_y, hw, 62)
			rects["chip_" + h] = r
			var sel := h == kind
			g._rbox(r, Color("#46307A") if sel else g.BTN, 22)
			if sel:
				g.draw_polyline(_rr_outline(r.grow(-1), 20), g.ACCENT, 3.0, true)
			# 0.12b: вещи — только свои, другие друзья в чипах без нарядов (0.13: но в своём виде — мальчик/девочка)
			hero.draw_avatar(g, h, r.position + Vector2(29, 31), 20, tryon.outfit(g.meta) if sel else g.meta.outfit_for(h), g.t_total, g.ACCENT if sel else g.DIM)
			var nm: String = g.meta.display_name(h)
			_text(Vector2(r.position.x + 59, r.position.y + 40), nm, fit_size(nm, r.size.x - 66, 24), g.ACCENT if sel else g.TEXT)
	# вкладки (0.12: значками — их восемь; название вкладки — на сцене)
	var tabs := wr_tabs()
	var tw: float = (g.W - 40.0 - (tabs.size() - 1) * 6.0) / tabs.size()
	for i in tabs.size():
		var tname: String = tabs[i]
		var r := Rect2(20 + i * (tw + 6), L.tabs_y, tw, 64)
		rects["tab_" + tname] = r
		var sel := tname == tab
		g._rbox(r, g.ACCENT if sel else Color("#2A1A4F"), 18)
		_tab_icon(tname, r.get_center(), DARK_TEXT if sel else g.TEXT)
	# сетка вещей по страницам
	var items: Array = _wr_items(kind)
	var pages := page_count(items.size())
	page = clampi(page, 0, pages - 1)
	_pager(L, pages)
	var cw2: float = (g.W - 40.0 - 2 * 14.0) / 3.0
	for j in PAGE_SIZE:
		var i := page * PAGE_SIZE + j
		if i >= items.size():
			break
		var it: Dictionary = items[i]
		var r := Rect2(20 + (j % 3) * (cw2 + 14), L.grid_y + (j / 3) * (L.card_h + 14), cw2, L.card_h)
		rects["item_" + it.id] = r
		_card(it, r, kind)
	if tryon.active():
		_try_panel(L, kind)
		_toast(st.position.y + 60)
	else:
		_toast(L.grid_y - 150)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(c + Vector2(cos(TAU * i / 32.0) * rx, sin(TAU * i / 32.0) * ry))
	return pts


## 0.12: строка страниц «‹  ● ○ ○  ›» над сеткой (стрелки — если страниц больше одной)
func _pager(L: Dictionary, pages: int) -> void:
	if pages <= 1:
		return
	var y: float = L.pager_y
	var lr := Rect2(20, y, 132, 46)
	var rr := Rect2(g.W - 152, y, 132, 46)
	rects["page_prev"] = lr
	rects["page_next"] = rr
	for k in 2:
		var r: Rect2 = [lr, rr][k]
		var on: bool = page > 0 if k == 0 else page < pages - 1
		g._rbox(r, g.BTN if on else Color(g.BTN, 0.4), 20)
		var c := r.get_center()
		var sx := -1.0 if k == 0 else 1.0
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * 14, 0), c + Vector2(-sx * 8, -13), c + Vector2(-sx * 8, 13)]), Color(g.TEXT, 1.0 if on else 0.3))
	for i in pages:
		var c := Vector2(g.W / 2.0 + (i - (pages - 1) / 2.0) * 30.0, y + 23)
		if i == page:
			g.draw_circle(c, 10, g.ACCENT, true, -1.0, true)
		else:
			g.draw_circle(c, 7, Color(g.TEXT, 0.3), true, -1.0, true)


## Значки вкладок гардероба
func _tab_icon(name: String, c: Vector2, col: Color) -> void:
	match name:
		"head":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 10), c + Vector2(2, -18), c + Vector2(16, 10)]), col)
			g.draw_circle(c + Vector2(2, -18), 5, col, true, -1.0, true)
			g.draw_rect(Rect2(c + Vector2(-19, 8), Vector2(38, 6)), col)
		"eyes":
			for sx in [-1.0, 1.0]:
				g.draw_arc(c + Vector2(sx * 11, 2), 9, 0, TAU, 18, col, 3.5, true)
			g.draw_line(c + Vector2(-3, 0), c + Vector2(3, 0), col, 3.0, true)
		"neck":
			for sx in [-1.0, 1.0]:
				g.draw_colored_polygon(PackedVector2Array([c, c + Vector2(sx * 18, -11), c + Vector2(sx * 18, 11)]), col)
			g.draw_circle(c, 5, col, true, -1.0, true)
		"back":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -16), c + Vector2(9, -16), c + Vector2(19, 16), c + Vector2(-19, 16)]), col)
			g.draw_circle(c + Vector2(0, -15), 4, Color("#FFC83A"), true, -1.0, true)
		"skin":
			g.draw_circle(c, 17, col, true, -1.0, true)
			var cols := [Color("#FF5FA8"), Color("#3FE0D0"), Color("#FFD23C"), Color("#B46CFF")]
			for k in 4:
				g.draw_circle(c + Vector2(cos(k * TAU / 4.0 - 0.6), sin(k * TAU / 4.0 - 0.6)) * 9.0, 4.5, cols[k], true, -1.0, true)
		"companion":
			g.draw_circle(c + Vector2(4, 3), 8, col, true, -1.0, true)
			g.draw_set_transform(c + Vector2(-5, -6), -0.5, Vector2(1, 0.55))
			g.draw_circle(Vector2.ZERO, 9, Color(col, 0.65), true, -1.0, true)
			g.draw_set_transform(c + Vector2(5, -9), 0.4, Vector2(1, 0.55))
			g.draw_circle(Vector2.ZERO, 9, Color(col, 0.65), true, -1.0, true)
			g.draw_set_transform(Vector2.ZERO)
			g.draw_circle(c + Vector2(4, 3), 3.5, Color("#FFE27A"), true, -1.0, true)
		"aura":
			Rarity.star4(g, c, 13, col)
			g.draw_arc(c, 19, 0, TAU, 28, Color(col, 0.6), 2.5, true)
		"home":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -2), c + Vector2(0, -18), c + Vector2(18, -2)]), col)
			g.draw_rect(Rect2(c + Vector2(-13, -3), Vector2(26, 19)), col)
			g.draw_rect(Rect2(c + Vector2(-4, 5), Vector2(8, 11)), Color("#2A1A4F") if col != DARK_TEXT else g.ACCENT)


## 0.12: значок набора на карточке (в цвете набора; 0.12b — свой рисунок у каждого набора героя)
func set_badge(n: int, c: Vector2, r: float) -> void:
	var info: Dictionary = Meta.set_info(n)
	if info.is_empty():
		return
	var col: Color = info.col
	g.draw_circle(c, r + 3, Color(0.06, 0.03, 0.12, 0.9), true, -1.0, true)
	g.draw_circle(c, r, Color(col, 0.28), true, -1.0, true)
	g.draw_arc(c, r, 0, TAU, 20, col, 2.0, true)
	var k := r
	match info.icon:
		"book":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.6, -k * 0.35), c + Vector2(0, -k * 0.2), c + Vector2(0, k * 0.5), c + Vector2(-k * 0.6, k * 0.35)]), col)
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.6, -k * 0.35), c + Vector2(0, -k * 0.2), c + Vector2(0, k * 0.5), c + Vector2(k * 0.6, k * 0.35)]), col.lightened(0.3))
		"moon":
			g.draw_circle(c, k * 0.55, col, true, -1.0, true)
			g.draw_circle(c + Vector2(k * 0.25, -k * 0.12), k * 0.45, Color(0.09, 0.05, 0.18), true, -1.0, true)
		"planet":
			g.draw_circle(c, k * 0.36, col, true, -1.0, true)
			g.draw_set_transform(c, -0.35, Vector2(1, 0.32))
			g.draw_arc(Vector2.ZERO, k * 0.68, 0, TAU, 20, col, 3.0, true)
			g.draw_set_transform(Vector2.ZERO)
		"star":
			g.draw_colored_polygon(_star(c, k * 0.68, k * 0.3, 5), col)
		"pearl":
			g.draw_circle(c, k * 0.45, col, true, -1.0, true)
			g.draw_circle(c + Vector2(-k * 0.15, -k * 0.18), k * 0.14, Color(1, 1, 1, 0.9), true, -1.0, true)
		"drop":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.65), c + Vector2(k * 0.42, k * 0.1), c + Vector2(0, k * 0.55), c + Vector2(-k * 0.42, k * 0.1)]), col)
			g.draw_circle(c + Vector2(0, k * 0.15), k * 0.4, col, true, -1.0, true)
		"ball":
			g.draw_circle(c, k * 0.5, col, true, -1.0, true)
			g.draw_arc(c + Vector2(-k * 0.55, 0), k * 0.45, -0.9, 0.9, 8, Color(1, 1, 1, 0.9), 1.6, true)
			g.draw_arc(c + Vector2(k * 0.55, 0), k * 0.45, PI - 0.9, PI + 0.9, 8, Color(1, 1, 1, 0.9), 1.6, true)
		"pine":
			for m in 2:
				g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.7 + m * k * 0.4), c + Vector2(k * 0.5, k * 0.0 + m * k * 0.4), c + Vector2(-k * 0.5, k * 0.0 + m * k * 0.4)]), col)
		"bolt":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.15, -k * 0.7), c + Vector2(-k * 0.4, k * 0.1), c + Vector2(0, k * 0.1), c + Vector2(-k * 0.15, k * 0.7), c + Vector2(k * 0.4, -k * 0.1), c + Vector2(0, -k * 0.1)]), col)
		"yarn":
			g.draw_circle(c, k * 0.5, col, true, -1.0, true)
			for m in 3:
				g.draw_arc(c, k * (0.18 + m * 0.12), -0.6 + m, 1.6 + m, 8, Color(0.2, 0.05, 0.2, 0.6), 1.2, true)
		"heart":
			var hp := PackedVector2Array()
			for i in 20:
				var tt := TAU * i / 20.0
				hp.append(c + Vector2(16.0 * pow(sin(tt), 3), -(13.0 * cos(tt) - 5.0 * cos(2 * tt) - 2.0 * cos(3 * tt) - cos(4 * tt)) - 2.0) * k * 0.035)
			g.draw_colored_polygon(hp, col)
		"glass":
			# 0.13: «Кот-детектив» — лупа
			g.draw_arc(c + Vector2(-k * 0.12, -k * 0.12), k * 0.34, 0, TAU, 18, col, k * 0.14, true)
			g.draw_line(c + Vector2(k * 0.13, k * 0.13), c + Vector2(k * 0.5, k * 0.5), col, k * 0.18, true)
		"daisy":
			# 0.13: «Цветочный пикник» — ромашка
			for m in 6:
				var ang := m * TAU / 6.0
				g.draw_circle(c + Vector2(cos(ang), sin(ang)) * k * 0.34, k * 0.19, col, true, -1.0, true)
			g.draw_circle(c, k * 0.2, Color("#FFD23C"), true, -1.0, true)
		"mask":
			for sx in [-1.0, 1.0]:
				g.draw_circle(c + Vector2(sx * k * 0.3, 0), k * 0.3, col, true, -1.0, true)
				g.draw_circle(c + Vector2(sx * k * 0.3, 0), k * 0.13, Color(0.09, 0.05, 0.18), true, -1.0, true)


func _star(c: Vector2, ro: float, ri: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		pts.append(c + Vector2(0, -(ro if i % 2 == 0 else ri)).rotated(i * PI / n))
	return pts


func _card(it: Dictionary, r: Rect2, kind: String) -> void:
	if it.get("bare", false):
		_bare_card(it.slot, r, kind)
		return
	var is_decor := it.has("home")
	var on: bool = g.meta.placed_at(kind, spot) == it.id if is_decor else g.meta.is_equipped(it.id)
	var own: bool = g.meta.is_owned(it.id)
	var lock: String = "" if own else Meta.lock_reason(it.id, g.total_stars(), g.max_level)
	var forge_item: bool = Meta.is_forge(it.id)
	var rar := "" if is_decor else Meta.rarity(it.id)
	var seed := float(it.id.hash() % 101) * 0.37
	g._rbox(r, Color("#3A2468") if on else Color("#24173F"), 22)
	if rar != "":
		Rarity.frame(g, r, rar, g.t_total, 22.0, seed)
	if on:
		g.draw_polyline(_rr_outline(r.grow(-7), 16), OK_COL, 3.0, true)
	var ic := r.position + Vector2(r.size.x / 2.0, 66)
	if lock != "":
		g.draw_circle(ic, 56, Color(0, 0, 0, 0.25), true, -1.0, true)
	elif rar != "":
		Rarity.icon_glow(g, rar, ic, 120, g.t_total, seed)
	if is_decor:
		home.draw_decor_icon(g, it.id, ic, 118, g.t_total)
	else:
		hero.draw_item_icon(g, it.id, it.slot, kind, ic, 120, g.t_total, g.meta.gender_of(kind))
	g.draw_set_transform(Vector2.ZERO)
	if rar != "":
		if lock == "" or own:
			Rarity.icon_fx(g, rar, ic, 120, g.t_total, seed, Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 128)))
		# камушек редкости в углу и значок набора
		var gc := r.position + Vector2(20, 20)
		var gcol := Rarity.frame_col(rar, g.t_total, seed)
		g.draw_colored_polygon(PackedVector2Array([gc + Vector2(0, -9), gc + Vector2(7, 0), gc + Vector2(0, 9), gc + Vector2(-7, 0)]), gcol)
		g.draw_colored_polygon(PackedVector2Array([gc + Vector2(0, -9), gc + Vector2(7, 0), gc + Vector2(0, -1)]), Color(1, 1, 1, 0.55))
		if Meta.set_of(it.id) > 0:
			set_badge(Meta.set_of(it.id), r.position + Vector2(r.size.x - 22, 22), 14.0)
	if lock != "":
		g._rbox(Rect2(r.position, Vector2(r.size.x, 132)), Color(0.08, 0.04, 0.15, 0.5), 22)
	if tryon.id == it.id:
		var pulse := 0.8 + 0.2 * sin(g.t_total * 5.0)
		g.draw_polyline(_rr_outline(r.grow(-2), 20), Color(g.ACCENT, pulse), 5.0, true)
		_badge(Vector2(r.get_center().x, r.position.y + 4), I18n.t("try_on"), 18)
	var nm := Meta.item_name(it.id, kind, g.meta.gender_of(kind))
	_text(Vector2(r.position.x, r.position.y + 154), nm, fit_size(nm, r.size.x - 10, 21), g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var sy := r.position.y + 186
	var cx := r.get_center().x
	if on:
		_ctext(cx, sy, I18n.t("card_placed") if is_decor else I18n.t("card_worn"), 24, OK_COL, r.size.x)
	elif own:
		_ctext(cx, sy, I18n.t("card_place") if is_decor else I18n.t("card_wear"), 24, g.ACCENT, r.size.x)
	elif forge_item and Meta.hall_done(int(it.hall), g.max_level):
		# 0.12: награда кузницы — не продаётся, куётся
		g.forge_ui.anvil_icon(Vector2(r.position.x + 40, sy - 10), 30)
		_ctext(cx + 16, sy, I18n.t("card_forge"), 24, Color("#9FF6FF"), r.size.x - 40)
	elif lock != "":
		_lock_icon(Vector2(r.position.x + 30, sy - 10), 16, g.DIM)
		var short := ""
		if it.has("stars"):
			short = "★ %d" % it.stars
		elif it.has("hall"):
			short = I18n.t("card_hall") % it.hall
		_ctext(cx + 14, sy, short, 24, g.DIM, r.size.x - 30)
	else:
		var price := str(it.price)
		var pw: float = g.font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		shard_icon(Vector2(cx - pw / 2.0 - 14, sy - 10), 13)
		_text(Vector2(cx - pw / 2.0 + 6, sy), price, 28, g.CRYSTAL_COL if g.meta.shards >= it.price else BAD_COL)


## 0.18: карточка «Родной окрас» (слот окраски) / «Без вещи» (другие слоты): выбрана, когда слот пуст
func _bare_card(slot: String, r: Rect2, kind: String) -> void:
	var on: bool = g.meta.equipped.get(slot, "") == ""
	g._rbox(r, Color("#3A2468") if on else Color("#24173F"), 22)
	if on:
		g.draw_polyline(_rr_outline(r.grow(-7), 16), OK_COL, 3.0, true)
	var ic := r.position + Vector2(r.size.x / 2.0, 66)
	if slot == "skin":
		# герой в своём настоящем цвете
		hero.draw_item_icon(g, "", "skin", kind, ic, 120, g.t_total, g.meta.gender_of(kind))
		g.draw_set_transform(Vector2.ZERO)
	else:
		g.draw_circle(ic, 44, Color(1, 1, 1, 0.06), true, -1.0, true)
		_tab_icon(slot, ic, Color(g.TEXT, 0.45))
		g.draw_arc(ic, 44, 0, TAU, 32, Color(g.TEXT, 0.55), 4.0, true)
		g.draw_line(ic + Vector2(-31, 31), ic + Vector2(31, -31), Color(g.TEXT, 0.55), 4.0, true)
	var nm := I18n.t("card_natural") if slot == "skin" else I18n.t("card_bare")
	_text(Vector2(r.position.x, r.position.y + 154), nm, fit_size(nm, r.size.x - 10, 21), g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var sy := r.position.y + 186
	if on:
		_ctext(r.get_center().x, sy, I18n.t("card_bare_on"), 24, OK_COL, r.size.x)
	else:
		_ctext(r.get_center().x, sy, I18n.t("card_restore") if slot == "skin" else I18n.t("card_take_off"), 24, g.ACCENT, r.size.x)


## 0.18: нажатие на «Родной окрас» / «Без вещи»: вещь слота снимается (остаётся купленной), примерка — тоже
func tap_bare(slot: String) -> void:
	tryon.clear()
	var was: String = g.meta.equipped.get(slot, "")
	if was == "":
		g.play("click", 0.9)
		return
	g.meta.unequip(slot)
	g.play("click")
	poke_hero()
	say(I18n.t("natural_back") if slot == "skin" else I18n.t("forge_took_off") % Meta.item_name(was, _kind(), g.meta.gender_of(_kind())))
	g._save()


func _rr_outline(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := home._rrect(r, rad)
	pts.append(pts[0])
	return pts


# ---------- Примерка и панель покупки ----------

## Плашка-ярлык по центру сверху (top — верхняя середина).
func _badge(top: Vector2, label: String, size: int) -> Rect2:
	var w: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 1.4
	var r := Rect2(top.x - w / 2.0, top.y, w, size * 1.7)
	g._rbox(r, g.ACCENT, int(r.size.y / 2.0))
	_text(Vector2(r.position.x, r.position.y + size * 1.2), label, size, DARK_TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return r


## Ярлык «Примерка» на сцене: над героем или над местом украшения.
func _try_tag(st: Rect2) -> void:
	var y: float = st.position.y + 14
	var x: float = st.get_center().x
	if tryon.is_decor():
		x = clampf(focus.x, st.position.x + 110, st.end.x - 110)
		y = clampf(focus.y - 130, st.position.y + 56, st.end.y - 60)
	_badge(Vector2(x, y), I18n.t("try_on"), 24)


## Панель подтверждения: название, цена, состояние, кнопки «Отмена» / «Купить за N».
## Закрывает строку героев/мест и вкладки (пока идёт примерка, они не нужны).
func _try_panel(L: Dictionary, kind: String) -> void:
	var it: Dictionary = Meta.item(tryon.id)
	var r := Rect2(14, L.chips_y - 20, g.W - 28, L.grid_y - 8 - (L.chips_y - 20))
	rects["try_panel"] = r
	g._rbox(r.grow(6), Color(0.02, 0.01, 0.06, 0.55), 34)
	g._rbox(r, Color("#2E1D58"), 30)
	g.draw_polyline(_rr_outline(r.grow(-2), 28), Color(g.ACCENT, 0.85), 3.0, true)
	# иконка
	var ic := r.position + Vector2(52, 50)
	g.draw_circle(ic, 36, Color(0.08, 0.04, 0.16, 0.9), true, -1.0, true)
	if it.has("home"):
		home.draw_decor_icon(g, tryon.id, ic, 62, g.t_total)
	else:
		hero.draw_item_icon(g, tryon.id, it.slot, kind, ic, 66, g.t_total, g.meta.gender_of(kind))
	g.draw_set_transform(Vector2.ZERO)
	# цена справа
	var price := str(tryon.price())
	var pw: float = g.font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var pr := Rect2(r.end.x - pw - 82, r.position.y + 12, pw + 64, 50)
	_pill(pr, Color(0.08, 0.04, 0.16, 0.9))
	var st: String = tryon.status(g.meta, g.total_stars(), g.max_level)
	shard_icon(pr.position + Vector2(28, 25), 15)
	_text(pr.position + Vector2(50, 37), price, 32, BAD_COL if st == "poor" else g.CRYSTAL_COL)
	# название и состояние
	var tx: float = r.position.x + 106
	var tw: float = pr.position.x - tx - 10
	var tnm := Meta.item_name(tryon.id, kind, g.meta.gender_of(kind))
	_text(Vector2(tx, r.position.y + 42), tnm, fit_size(tnm, tw, 30), g.TEXT, tw)
	var line := I18n.t("try_hint")
	var col: Color = g.DIM
	if not it.has("home"):
		# 0.12: редкость (и набор) — под названием, цветом редкости
		var rar := Meta.rarity(tryon.id)
		var rl := Meta.rarity_name(rar)
		if Meta.set_of(tryon.id) > 0:
			rl += " · " + Meta.set_title(Meta.set_of(tryon.id), g.meta.gender_of(kind))
		_text(Vector2(r.position.x + 16, r.position.y + 112), rl, fit_size(rl, r.size.x - 32, 20), Rarity.frame_col(rar, g.t_total), r.size.x - 32)
	if Meta.is_forge(tryon.id) and Meta.hall_done(int(it.hall), g.max_level):
		line = Meta.lock_reason(tryon.id, g.total_stars(), g.max_level)
		col = Color("#9FF6FF")
	elif st == "poor":
		var n: int = tryon.shortage(g.meta)
		line = I18n.t("poor_n") % [n, I18n.forms("shards_gen_forms", n)]
		col = BAD_COL
	elif st == "locked":
		line = Meta.lock_reason(tryon.id, g.total_stars(), g.max_level)
		col = Color("#FFB86B")
		_lock_icon(Vector2(tx + 11, r.position.y + 69), 12, col)
		tx += 30
	_text(Vector2(tx, r.position.y + 76), line, 22, col, r.end.x - tx - 20)
	# кнопки
	var by: float = r.end.y - 70
	_button("try_cancel", Rect2(r.position.x + 14, by, 230, 58), I18n.t("cancel"), false, 30)
	var br := Rect2(r.position.x + 258, by, r.size.x - 272, 58)
	if Meta.is_forge(tryon.id):
		# 0.12: награду кузницы не купить — кнопка ведёт в кузницу
		_button("try_forge", br, I18n.t("to_forge"), true, 30)
		return
	var ok := st == "ok"
	_button("try_buy", br, "", ok, 32, ok)
	var label := I18n.t("buy_for") % tryon.price()
	var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var x0: float = br.get_center().x - (lw + 40) / 2.0
	var tcol: Color = DARK_TEXT if ok else Color(g.TEXT, 0.45)
	_text(Vector2(x0, br.get_center().y + 11), label, 30, tcol)
	shard_icon(Vector2(x0 + lw + 24, br.get_center().y), 15)
	if not ok:
		g._rbox(br, Color(0.1, 0.06, 0.2, 0.35), 26)


## Короткий эффект покупки: вспышка, кольцо и разлетающиеся осколки.
func _buy_fx() -> void:
	if fx_t > 0.8:
		return
	var k := fx_t / 0.8
	var a := 1.0 - k
	g.draw_circle(fx_at, 40 + 140 * k, Color(1, 0.95, 0.7, 0.25 * a), true, -1.0, true)
	g.draw_arc(fx_at, 30 + 170 * k, 0, TAU, 48, Color(g.CRYSTAL_COL, a), 6.0 * a + 1.0, true)
	for i in 10:
		var ang := i * TAU / 10.0 + 0.3
		var p := fx_at + Vector2(cos(ang), sin(ang)) * (50 + 180 * k) + Vector2(0, 120 * k * k)
		shard_icon(p, 12 * a + 3)


## Снять примерку (кнопка «Отмена», касание мимо панели, «Назад» на телефоне).
## true — примерка была и снята.
func cancel_try() -> bool:
	if not tryon.active():
		return false
	tryon.clear()
	g.play("click", 0.9)
	return true


func _confirm_try() -> void:
	var id: String = tryon.id
	var decor_spot: String = tryon.spot if tryon.is_decor() else ""
	match tryon.confirm(g.meta, g.total_stars(), g.max_level):
		"bought", "owned":
			g.play("crystal")
			say(I18n.t("bought") % Meta.item_name(id, g.meta.hero, g.meta.gender_of(g.meta.hero)))
			poke_hero()
			fx_t = 0.0
			fx_at = focus
			g._save()
			if decor_spot != "" and from_home_spot:
				return_home_to(decor_spot)
		"poor":
			g.play("gameover", 1.3, -8.0)
		_:
			g.play("click", 0.7)
			say(Meta.lock_reason(id, g.total_stars(), g.max_level))


## 0.18: лента вещей (сетка карточек): касание здесь срабатывает при отпускании — свайп листает страницы
func strip_rect() -> Rect2:
	var L := _wr_layout()
	return Rect2(0, L.grid_y - 7, g.W, g.H - L.grid_y + 7)


## Касания гардероба от игры (scripts/game.gd): в ленте — через свайп, остальное — сразу
func wardrobe_down(idx: int, pos: Vector2) -> void:
	if strip_rect().has_point(pos):
		strip.press(idx, pos)
		return
	tap_wardrobe(pos)


func wardrobe_drag(idx: int, pos: Vector2) -> void:
	strip.move(idx, pos)


func wardrobe_up(idx: int, pos: Vector2) -> void:
	if not strip.active():
		return
	match strip.release(idx, pos):
		Swipe.TAP:
			tap_wardrobe(strip.start)
		Swipe.NEXT:
			flip_page(1)
		Swipe.PREV:
			flip_page(-1)


## Страница вещей вперёд (+1) / назад (-1); true — перелистнулась
func flip_page(dir: int) -> bool:
	var pages := page_count(_wr_items(_kind()).size())
	var p := clampi(page + dir, 0, pages - 1)
	if p == page:
		return false
	page = p
	g.play("click")
	return true


func tap_wardrobe(pos: Vector2) -> void:
	var on_card := false
	for n in rects:
		if String(n).begins_with("item_") and rects[n].has_point(pos):
			on_card = true
	if tryon.active() and not on_card:
		if rects.get("try_forge", Rect2()).has_point(pos):
			tryon.clear()
			g.play("click")
			g.forge_ui.open()
		elif rects.get("try_buy", Rect2()).has_point(pos):
			_confirm_try()
		elif rects.get("try_cancel", Rect2()).has_point(pos) or not rects.get("try_panel", Rect2()).has_point(pos):
			cancel_try()
		return
	if rects.get("back", Rect2()).has_point(pos):
		g.play("click")
		g.go_home()
		return
	if rects.get("forge", Rect2()).has_point(pos):
		g.play("click")
		g.forge_ui.open()
		return
	if tab != "home":
		# 0.13: имя и мальчик / девочка
		if rects.get("name", Rect2()).has_point(pos):
			g.play("click")
			g.notice_ui.ask_name(_kind())
			return
		if tap_gender(pos, _kind()):
			return
	for tname in wr_tabs():
		if rects.get("tab_" + tname, Rect2()).has_point(pos):
			g.play("click")
			if tname == "home":
				open_wardrobe("home")  # 0.15: вкладка «Дом» — режим украшения на экране «Дом»
				return
			if tab != tname:
				page = 0
			tab = tname
			return
	var kind0: String = g.meta.hero if g.meta.hero != "" else "owl"
	var pages := page_count(_wr_items(kind0).size())
	if rects.get("page_prev", Rect2()).has_point(pos) and page > 0:
		g.play("click")
		page -= 1
		return
	if rects.get("page_next", Rect2()).has_point(pos) and page < pages - 1:
		g.play("click")
		page += 1
		return
	for h in Meta.HEROES:
		if tab != "home" and rects.get("chip_" + h, Rect2()).has_point(pos):
			g.play("click")
			if g.meta.hero != h:
				request_switch(h)
			return
	if tab == "home":
		for sp in Meta.SPOTS:
			if rects.get("chip_" + sp, Rect2()).has_point(pos) or rects.get("spot_" + sp, Rect2()).has_point(pos):
				g.play("click")
				spot = sp
				page = 0
				return
	if rects.get("hero", Rect2()).has_point(pos) and tab != "home":
		poke_hero()
		g.play("crystal", randf_range(0.9, 1.15), -6.0)
		return
	var kind: String = g.meta.hero if g.meta.hero != "" else "owl"
	var items: Array = _wr_items(kind)
	for it in items:
		if rects.get("item_" + it.id, Rect2()).has_point(pos):
			tap_card(it.id, kind)
			return
	# 0.14: касание по пустому месту сцены (или шапки) — назад, откуда пришёл (домой)
	if is_empty_tap(pos):
		g.play("click")
		g.go_home()


## Пустое место гардероба: сцена или шапка, мимо кнопок (их касания обработаны раньше).
## Промежутки между карточками, вкладками и чипами — не «пусто»: промах по кнопке не уводит из гардероба.
func is_empty_tap(pos: Vector2) -> bool:
	if rects.get("collection", Rect2()).has_point(pos) or rects.get("hero", Rect2()).has_point(pos):
		return false
	var st: Rect2 = _wr_layout().stage
	return st.has_point(pos) or pos.y < st.position.y


## 0.14: после покупки / размещения украшения (гардероб открыт «+» с экрана «Дом») — домой,
## камера 3D-дома подлетает к месту новой вещи (в 2D-доме — просто дом).
func return_home_to(sp: String) -> void:
	from_home_spot = false
	if g.home3d and g.home3d.showing_stage():
		g.home3d.show_spot = sp
	g.go_home()


## Нажатие на карточку вещи / украшения (для текущей вкладки и места).
## Купленное — надеть/снять сразу; некупленное — примерка (повторное нажатие — снять примерку).
func tap_card(id: String, kind: String) -> void:
	if id == BARE:
		tap_bare(tab)
		return
	var res: String
	if tab == "home":
		res = g.meta.tap_decor(kind, spot, id)
	else:
		res = g.meta.tap_item(id)
	match res:
		"try":
			if tryon.id == id:
				cancel_try()
				return
			if tab == "home":
				tryon.start_decor(kind, spot, id)
			else:
				tryon.start_item(id)
			g.play("crystal", 1.25, -6.0)
			poke_hero()
		"on":
			tryon.clear()
			g.play("crystal")
			poke_hero()
			g._save()
			if tab == "home" and from_home_spot:
				return_home_to(spot)  # 0.14: «Разместить» купленное — сразу домой, к нему
		"off":
			tryon.clear()
			g.play("click")
			g._save()
		_:
			g.play("click", 0.7)
			say(Meta.lock_reason(id, g.total_stars(), g.max_level))


# ---------- Карта ----------

func node_y(n: int) -> float:
	var h := Meta.hall_index(n)
	var i := n - 1 - h * Meta.HALL_SIZE
	return MAP_TOP + h * (Meta.HALL_SIZE * NODE_GAP + HALL_HEAD) + HALL_HEAD + i * NODE_GAP


func node_x(n: int) -> float:
	return 360.0 + sin(n * 0.85) * 190.0


func hall_top(h: int) -> float:
	return MAP_TOP + h * (Meta.HALL_SIZE * NODE_GAP + HALL_HEAD)


func map_last() -> int:
	return maxi(Meta.LAST_LEVEL + 3, g.max_level + 2)


func _clamp_scroll() -> void:
	var content := node_y(map_last()) + 260.0
	map_scroll = clampf(map_scroll, 0.0, maxf(0.0, content - g.H))
	if map_scroll <= 0.0 or map_scroll >= content - g.H:
		map_vel = 0.0


func open_map() -> void:
	map_scroll = node_y(g.max_level) - g.H * 0.5
	map_vel = 0.0
	drag.clear()
	_clamp_scroll()
	g._set_state(g.State.MAP)


func draw_map() -> void:
	rects.clear()
	var H: float = g.H
	var off := -map_scroll
	var last := map_last()
	# полосы залов
	for h in Meta.HALLS.size():
		var y0 := hall_top(h) + off
		var y1 := (hall_top(h + 1) if h < Meta.HALL_COUNT else node_y(last) + 300.0) + off
		if y1 < 0 or y0 > H:
			continue
		var col: Color = Meta.HALLS[h].col
		g.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(g.W, y0), Vector2(g.W, y1), Vector2(0, y1)]),
			PackedColorArray([Color(col, 0.16), Color(col, 0.16), Color(col, 0.04), Color(col, 0.04)]))
		# кристаллы по краям зала
		for k in 6:
			var gy := y0 + 120 + k * 230.0
			if gy > y1 - 40:
				break
			var gx: float = 36.0 if k % 2 == 0 else g.W - 36.0
			var lit: bool = g.max_level > h * Meta.HALL_SIZE + k
			g.draw_circle(Vector2(gx, gy), 26, Color(col, 0.12 if lit else 0.03), true, -1.0, true)
			_gem(Vector2(gx, gy), 14, Color(col, 0.9 if lit else 0.25))
	# тропа
	for n in range(1, last):
		var a := Vector2(node_x(n), node_y(n) + off)
		var b := Vector2(node_x(n + 1), node_y(n + 1) + off)
		if maxf(a.y, b.y) < -60 or minf(a.y, b.y) > H + 60:
			continue
		var lit: bool = n + 1 <= g.max_level
		var col: Color = Meta.hall(n + 1).col
		var pts := PackedVector2Array()
		var c1 := a + Vector2(0, NODE_GAP * 0.45)
		var c2 := b - Vector2(0, NODE_GAP * 0.45)
		for i in 13:
			var s := i / 12.0
			pts.append(a.bezier_interpolate(c1, c2, b, s))
		if lit:
			g.draw_polyline(pts, Color(col, 0.25), 22.0, true)
			g.draw_polyline(pts, Color(col, 0.85), 8.0, true)
		else:
			for i in range(0, 13, 2):
				g.draw_circle(pts[i], 5, Color("#3A2D5C"), true, -1.0, true)
	# заголовки залов — поверх тропы
	for h in Meta.HALLS.size():
		var y0 := hall_top(h) + off
		if y0 + 140 < 0 or y0 > H:
			continue
		var col: Color = Meta.HALLS[h].col
		var first := h * Meta.HALL_SIZE + 1
		var sub := I18n.t("map_range") % [Meta.depth(first), Meta.depth(first + Meta.HALL_SIZE - 1)] if h < Meta.HALL_COUNT else I18n.t("map_below") % Meta.depth(Meta.LAST_LEVEL + 1)
		if h == Meta.HALL_COUNT and g.max_level <= Meta.LAST_LEVEL:
			sub = I18n.t("map_locked") % Meta.LAST_LEVEL
		g._rbox(Rect2(70, y0 + 30, 580, 110), Color(0.06, 0.035, 0.13, 0.85), 30)
		_shadow_text(g.W / 2.0, y0 + 80, Meta.hall_name(h), 44, col)
		_ctext(g.W / 2.0, y0 + 122, sub, 26, g.DIM)
	# точки уровней
	for n in range(1, last + 1):
		var c := Vector2(node_x(n), node_y(n) + off)
		if c.y < -80 or c.y > H + 80:
			continue
		var col: Color = Meta.hall(n).col
		var r := Rect2(c - Vector2(56, 56), Vector2(112, 112))
		if n == g.max_level:
			var pulse := 0.5 + 0.5 * sin(g.t_total * 3.0)
			g.draw_circle(c, 66 + 6 * pulse, Color(g.ACCENT, 0.18), true, -1.0, true)
			avatar(c, 50, g.ACCENT)
			var lab := Rect2(c + Vector2(-34, 46), Vector2(68, 38))
			_pill(lab, g.ACCENT)
			_ctext(c.x, c.y + 75, str(n), 26, DARK_TEXT, 68)
			rects["lvl_%d" % n] = r
		elif n < g.max_level:
			g.draw_circle(c, 52, Color(col, 0.16), true, -1.0, true)
			g.draw_circle(c, 40, col.darkened(0.45), true, -1.0, true)
			g.draw_arc(c, 40, 0, TAU, 40, col, 5.0, true)
			_ctext(c.x, c.y + 12, str(n), 34, g.TEXT, 90)
			var s: int = g.stars.get(n, 0)
			for i in 3:
				g._draw_star(c + Vector2((i - 1) * 26, 52), 11, i < s)
			rects["lvl_%d" % n] = r
		if n <= g.max_level:  # 0.18: значок цели (кротёнок, тайник) или огненного кристалла
			SpecialsDraw.map_badge(g, c, Levels.params(n))
		else:
			g.draw_circle(c, 36, Color("#1A1230"), true, -1.0, true)
			g.draw_arc(c, 36, 0, TAU, 36, Color("#3A2D5C"), 4.0, true)
			_ctext(c.x, c.y + 11, str(n), 30, Color(g.DIM, 0.45), 90)
	# шапка
	g.draw_rect(Rect2(0, 0, g.W, 122), g.BG_TOP)
	g.draw_polygon(PackedVector2Array([Vector2(0, 122), Vector2(g.W, 122), Vector2(g.W, 170), Vector2(0, 170)]),
		PackedColorArray([g.BG_TOP, g.BG_TOP, Color(g.BG_TOP, 0.0), Color(g.BG_TOP, 0.0)]))
	_back_button()
	_text(Vector2(132, 84), I18n.t("map"), 46, g.TEXT)
	_counters(g.W - 20, 40)
	# глубина текущего уровня
	var hall: Dictionary = Meta.hall(g.max_level)
	var label := I18n.t("map_depth") % [Meta.depth(g.max_level), Meta.hall_name(Meta.hall_index(g.max_level))]
	var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 50.0
	var lr := Rect2((g.W - lw) / 2.0, H - 84, lw, 56)
	_pill(lr, Color(0.06, 0.03, 0.12, 0.92))
	_ctext(g.W / 2.0, H - 46, label, 28, hall.col, lw)


func _gem(c: Vector2, r: float, col: Color) -> void:
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.7, -r * 0.2)]), col)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, -r * 0.05)]), Color(1, 1, 1, col.a * 0.5))


func map_down(idx: int, pos: Vector2) -> void:
	drag[idx] = {"start": pos, "last": pos, "moved": false, "t": Time.get_ticks_msec()}
	map_vel = 0.0


func map_drag(idx: int, pos: Vector2) -> void:
	if not drag.has(idx):
		return
	var d: Dictionary = drag[idx]
	var dy: float = pos.y - d.last.y
	map_scroll -= dy
	var now := Time.get_ticks_msec()
	var dt := maxf(1.0, now - d.t) / 1000.0
	map_vel = lerpf(map_vel, -dy / dt, 0.5)
	d.t = now
	d.last = pos
	if pos.distance_to(d.start) > 18:
		d.moved = true
	_clamp_scroll()


func map_up(idx: int, pos: Vector2) -> void:
	if not drag.has(idx):
		return
	var d: Dictionary = drag[idx]
	drag.erase(idx)
	if d.moved:
		return
	map_vel = 0.0
	if rects.get("back", Rect2()).has_point(pos):
		g.play("click")
		g.go_home()
		return
	for n in range(1, g.max_level + 1):
		if rects.get("lvl_%d" % n, Rect2()).has_point(pos):
			g.play("click")
			g.start_level(n)
			return


# ---------- Победа и поражение ----------

func draw_win() -> void:
	rects.clear()
	var H: float = g.H
	var st: float = g.state_time
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.05, 0.03, 0.1, 0.78))
	var y0 := H * 0.5 - 520.0
	var hop := absf(sin(st * 5.0)) * 10.0 * clampf(2.0 - st, 0.0, 1.0)
	avatar(Vector2(g.W / 2.0, y0 + 110 - hop), 78, g.ACCENT)
	_shadow_text(g.W / 2.0, y0 + 260, I18n.t("win_title") % g.level, 50, g.TEXT)
	for i in 3:
		var appear := clampf((st - 0.2 - i * 0.25) / 0.2, 0.0, 1.0)
		var r := 44.0 * (0.5 + 0.5 * appear) if i < g.last_stars else 44.0
		g._draw_star(Vector2(g.W / 2.0 + (i - 1) * 120, y0 + 340), r, i < g.last_stars and appear > 0.0)
	# 0.19: под звёздами — за сколько фигур дают 3 звезды и сколько поставлено (при 3 звёздах — похвала)
	if st > 0.2:
		StarGoal.draw_win_line(g, g.W / 2.0, y0 + 412, g.W - 60.0, 28)
	_ctext(g.W / 2.0, y0 + 452, I18n.t("win_stats") % [g.score, g.pieces_used], 26, g.DIM)
	# осколки
	var rw: Dictionary = g.last_reward
	var total: int = rw.get("total", 0)
	var k := clampf((st - 0.9) / 0.9, 0.0, 1.0)
	var shown := int(round(total * k))
	var box := Rect2(110, y0 + 480, 500, 170)
	g._rbox(box, Color(0.16, 0.1, 0.3, 0.95), 30)
	if st > 0.9:
		var bump := 1.0 + 0.25 * maxf(0.0, 1.0 - absf(st - 1.85) / 0.2)
		shard_icon(Vector2(box.position.x + 90, box.position.y + 64), 30 * bump)
		_text(Vector2(box.position.x + 140, box.position.y + 84), "+%d %s" % [shown, shards_word(shown)], int(46 * bump), g.CRYSTAL_COL)
		var parts: Array = []
		if rw.get("win", 0) > 0:
			parts.append(I18n.t("win_first" if rw.get("first", false) else "win_repeat") % rw.win)
		if rw.get("stars", 0) > 0:
			parts.append(I18n.t("win_stars") % rw.stars)
		if rw.get("chains", 0) > 0:
			parts.append(I18n.t("win_chains") % rw.chains)
		if rw.get("chest", 0) > 0:  # 0.18: осколки из янтарного тайника
			parts.append(I18n.t("win_chest") % rw.chest)
		var line := " · ".join(parts)  # 0.18: с тайником строка длиннее — шрифт ужимается по ширине
		_ctext(box.get_center().x, box.position.y + 136, line, g.assist_ui.fit(line, 24, box.size.x - 30) if g.assist_ui else 24, g.DIM, box.size.x - 20)
		if rw.get("gift", 0) > 0:  # 0.9: подарок новичку — ярлык на нижнем краю
			_badge(Vector2(box.get_center().x, box.end.y - 16), I18n.t("win_gift") % rw.gift, 22)
		# летящие искорки
		if st < 2.0:
			for i in 8:
				var a := i * TAU / 8.0 + st * 2.0
				var rr := 40.0 + (st - 0.9) * 120.0
				var p := Vector2(box.position.x + 90, box.position.y + 64) + Vector2(cos(a), sin(a)) * rr
				g.draw_circle(p, 4, Color(g.CRYSTAL_COL, clampf(2.0 - st, 0.0, 1.0)), true, -1.0, true)
	if st > 0.8:
		_button("next", Rect2(110, y0 + 700, 500, 120), I18n.t("next"), true, 46)
		_button("home", Rect2(110, y0 + 840, 500, 96), I18n.t("home"), false, 36)


static func shards_word(n: int) -> String:
	return I18n.forms("shards_forms", n)


func draw_lose() -> void:
	rects.clear()
	var H: float = g.H
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.05, 0.03, 0.1, 0.78))
	var y0 := H * 0.5 - 420.0
	avatar(Vector2(g.W / 2.0, y0 + 110), 70)
	_shadow_text(g.W / 2.0, y0 + 260, I18n.t("lose_title"), 54, g.TEXT)
	_ctext(g.W / 2.0, y0 + 330, g.goal_status(), 34, g.CRYSTAL_COL)  # 0.18: кристаллы, кротёнок или тайник
	_ctext(g.W / 2.0, y0 + 380, I18n.t("lose_hint"), 28, g.DIM)
	if g.state_time > 0.8:
		_button("retry", Rect2(110, y0 + 450, 500, 120), I18n.t("retry"), true, 46)
		_button("home", Rect2(110, y0 + 590, 500, 96), I18n.t("home"), false, 36)


func tap_end(pos: Vector2) -> void:
	if g.state_time <= 0.8:
		return
	if rects.get("next", Rect2()).has_point(pos):
		g.play("click")
		g.start_level(g.level + 1)
	elif rects.get("retry", Rect2()).has_point(pos):
		g.play("click")
		g.start_level(g.level)
	elif rects.get("home", Rect2()).has_point(pos):
		g.play("click")
		g.go_home()
