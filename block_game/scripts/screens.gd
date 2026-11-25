extends RefCounted
## Экраны мета-слоя Cascado (0.6, четыре друга — 0.9): выбор героя, дом, гардероб (вещи и украшения дома),
## карта-путешествие, экраны победы и поражения. Рисуют на узле игры (g — scripts/game.gd)
## и обрабатывают касания на этих экранах. Правила уровня — в game.gd, данные — в meta.gd.

const Meta := preload("res://scripts/meta.gd")
const Hero := preload("res://scripts/hero.gd")
const Home := preload("res://scripts/home.gd")
const I18n := preload("res://scripts/i18n.gd")
const TryOn := preload("res://scripts/tryon.gd")

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
	_shadow_text(g.W / 2.0, 150 + oy, I18n.t("pick_title"), 64, g.TEXT)
	_ctext(g.W / 2.0, 205 + oy, I18n.t("pick_sub"), 28, g.DIM)
	# четыре друга — сетка 2×2
	for i in Meta.HEROES.size():
		var kind: String = Meta.HEROES[i]
		var r := Rect2(24 + (i % 2) * 344, 236 + oy + (i / 2) * 318, 328, 304)
		rects["hero_" + kind] = r
		var sel := pick_choice == kind
		if sel:
			g._rbox(r.grow(8), Color(g.ACCENT, 0.3 + 0.1 * sin(g.t_total * 4.0)), 40)
		g._rbox(r, Color("#2A1A4F") if not sel else Color("#3A2468"), 34)
		var glow: Color = PICK_GLOW.get(kind, Color("#B46CFF"))
		for k in 4:
			g.draw_circle(r.position + Vector2(r.size.x / 2.0, 120), 112 - k * 22, Color(glow, 0.05 + k * 0.02), true, -1.0, true)
		var sc: float = PICK_SCALE.get(kind, 0.64)
		hero.draw(g, kind, r.position + Vector2(r.size.x / 2.0, 140), sc, {}, g.t_total + i * 1.7, react if sel else 99.0)
		var nm := Meta.hero_name(kind)
		_ctext(r.get_center().x, r.end.y - 50, nm, fit_size(nm, r.size.x - 20, 36), g.ACCENT if sel else g.TEXT, r.size.x)
		var lv := I18n.t("pick_lives_" + kind)
		_ctext(r.get_center().x, r.end.y - 16, lv, fit_size(lv, r.size.x - 16, 22), g.DIM, r.size.x)
	_button("ok", Rect2(160, 900 + oy, 400, 120), I18n.t("pick_ok"), true, 50, pick_choice != "")
	_ctext(g.W / 2.0, 1076 + oy, I18n.t("pick_hint"), 26, g.DIM)
	_lang_button(Rect2(g.W - 136, 24 + oy * 0.5, 116, 58))
	_toast(1120 + oy)


func tap_pick(pos: Vector2) -> void:
	if _tap_lang(pos):
		return
	for kind in Meta.HEROES:
		if rects.get("hero_" + kind, Rect2()).has_point(pos):
			pick_choice = kind
			poke_hero()
			g.play("crystal")
			return
	if rects.get("ok", Rect2()).has_point(pos) and pick_choice != "":
		g.meta.set_hero(pick_choice)
		g._save()
		g.play("levelup")
		fade = 1.0
		g.go_home()


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
	var placed: Dictionary = g.meta.decor_placed.get(kind, {})
	if g.home3d.showing():
		# 0.12: 3D-дом (scripts/home3d/); касания мимо кнопок крутят камеру, тап по месту / герою — там же
		g.home3d.draw(g, Rect2(0, 0, g.W, H))
	else:
		# запасной 2D-дом: 3D недоступно или выбрано «Графика: 2D»
		home.draw(g, kind, hv[0], 1.0, hv[1], Meta.home_stage(g.max_level), placed, g.meta.outfit(), g.t_total, react, "", true)
		var ha: Array = Home.HERO_AT[kind]
		rects["hero"] = Rect2(hv[0] + ha[0] - Vector2(110, 130), Vector2(220, 240))
		for s in Meta.SPOTS:
			rects["spot_" + s] = Rect2(home.spot_screen(kind, s) - Vector2(60, 60), Vector2(120, 120))
	# верхняя полоса
	g.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(g.W, 0), Vector2(g.W, 250), Vector2(0, 250)]),
		PackedColorArray([Color(0.04, 0.02, 0.1, 0.75), Color(0.04, 0.02, 0.1, 0.75), Color(0.04, 0.02, 0.1, 0), Color(0.04, 0.02, 0.1, 0)]))
	avatar(Vector2(72, 72), 48)
	rects["avatar"] = Rect2(20, 20, 104, 104)
	_counters(g.W - 20, 44)
	_lang_button(Rect2(140, 44, 116, 58))
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
	var pr := Rect2(100, by + 52, 520, 128)
	var pulse := 1.0 + 0.03 * sin(g.t_total * 4.0)
	var pb := Rect2(pr.get_center() - pr.size * pulse / 2.0, pr.size * pulse)
	rects["play"] = pr
	g._rbox(pb.grow(6), Color(g.ACCENT, 0.25), 40)
	g._rbox(pb, g.ACCENT, 36)
	g._rbox(Rect2(pb.position + Vector2(8, 6), Vector2(pb.size.x - 16, pb.size.y * 0.4)), Color(1, 1, 1, 0.14), 30)
	_ctext(g.W / 2.0, pr.position.y + 70, I18n.t("play"), 56, DARK_TEXT)
	_ctext(g.W / 2.0, pr.position.y + 108, I18n.t("level_n") % g.max_level, 28, Color("#5A3A10"))
	_button("map", Rect2(40, H - 140, 310, 104), "", false)
	_button("wardrobe", Rect2(370, H - 140, 310, 104), "", false)
	_map_icon(Vector2(100, H - 88))
	_text(Vector2(140, H - 74), I18n.t("map"), 38, g.TEXT)
	_hanger_icon(Vector2(430, H - 88))
	_text(Vector2(470, H - 74), I18n.t("wardrobe"), 36, g.TEXT)
	_toast(260)
	_fade_over(Rect2(0, 0, g.W, H))


func _map_icon(c: Vector2) -> void:
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -20), c + Vector2(-8, -26), c + Vector2(8, -20), c + Vector2(26, -26),
		c + Vector2(26, 22), c + Vector2(8, 28), c + Vector2(-8, 22), c + Vector2(-26, 28)]), Color("#E8D6A8"))
	g.draw_polyline(PackedVector2Array([c + Vector2(-18, 16), c + Vector2(-6, 2), c + Vector2(6, 8), c + Vector2(16, -12)]), Color("#C0392B"), 3.0, true)
	g.draw_circle(c + Vector2(16, -12), 5, Color("#C0392B"), true, -1.0, true)


func _hanger_icon(c: Vector2) -> void:
	g.draw_arc(c + Vector2(0, -16), 7, PI, TAU * 1.1, 10, g.TEXT, 4.0, true)
	g.draw_polyline(PackedVector2Array([c + Vector2(0, -9), c + Vector2(-28, 14), c + Vector2(28, 14), c + Vector2(0, -9)]), g.TEXT, 5.0, true)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 14), c + Vector2(16, 14), c + Vector2(22, 32), c + Vector2(-22, 32)]), Color("#FF5A7A"))


## true — касание обработано (кнопка, герой или место 2D-дома); false — мимо, его получает камера 3D-дома
func tap_home(pos: Vector2) -> bool:
	if _tap_lang(pos):
		return true
	if rects.get("play", Rect2()).has_point(pos):
		g.play("click")
		g.start_level(g.max_level)
	elif rects.get("map", Rect2()).has_point(pos):
		g.play("click")
		open_map()
	elif rects.get("wardrobe", Rect2()).has_point(pos) or rects.get("avatar", Rect2()).has_point(pos):
		g.play("click")
		open_wardrobe("head" if tab == "home" else tab)
	elif rects.get("hero", Rect2()).has_point(pos):
		poke_hero()
		g.play("crystal", randf_range(0.9, 1.15), -6.0)
	else:
		for s in Meta.SPOTS:
			if rects.get("spot_" + s, Rect2()).has_point(pos):
				g.play("click")
				spot = s
				open_wardrobe("home")
				return true
		return false
	return true


# ---------- Гардероб ----------

func open_wardrobe(t := "head") -> void:
	tab = t
	tryon.clear()
	g._set_state(g.State.WARDROBE)


func _wr_layout() -> Dictionary:
	var H: float = g.H
	var card_h := 200.0
	var grid_y := H - 24.0 - card_h * 2 - 14.0
	var tabs_y := grid_y - 80.0
	var chips_y := tabs_y - 76.0
	return {"grid_y": grid_y, "card_h": card_h, "tabs_y": tabs_y, "chips_y": chips_y,
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
		var sc: float = WR_SCALE.get(kind, 1.4)
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
			_text(Vector2(r.position.x, r.position.y + 38), Meta.spot_name(sp), 17, DARK_TEXT if sel else g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
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
			hero.draw_avatar(g, h, r.position + Vector2(29, 31), 20, tryon.outfit(g.meta), g.t_total, g.ACCENT if sel else g.DIM)
			var nm := Meta.hero_name(h)
			_text(Vector2(r.position.x + 59, r.position.y + 40), nm, fit_size(nm, r.size.x - 66, 24), g.ACCENT if sel else g.TEXT)
	# вкладки
	var tabs := Meta.SLOTS.duplicate()
	tabs.append("home")
	var tw: float = (g.W - 40.0 - (tabs.size() - 1) * 8.0) / tabs.size()
	for i in tabs.size():
		var tname: String = tabs[i]
		var r := Rect2(20 + i * (tw + 8), L.tabs_y, tw, 64)
		rects["tab_" + tname] = r
		var sel := tname == tab
		g._rbox(r, g.ACCENT if sel else Color("#2A1A4F"), 18)
		var label: String = I18n.t("tab_home") if tname == "home" else Meta.slot_name(tname)
		_text(Vector2(r.position.x, r.position.y + 41), label, 22, DARK_TEXT if sel else g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# сетка вещей
	var items: Array = Meta.decor_for(kind, spot) if tab == "home" else Meta.items_in(tab)
	var cw2: float = (g.W - 40.0 - 2 * 14.0) / 3.0
	for i in mini(items.size(), 6):
		var it: Dictionary = items[i]
		var r := Rect2(20 + (i % 3) * (cw2 + 14), L.grid_y + (i / 3) * (L.card_h + 14), cw2, L.card_h)
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


func _card(it: Dictionary, r: Rect2, kind: String) -> void:
	var is_decor := it.has("home")
	var on: bool = g.meta.placed_at(kind, spot) == it.id if is_decor else g.meta.is_equipped(it.id)
	var own: bool = g.meta.is_owned(it.id)
	var lock: String = "" if own else Meta.lock_reason(it.id, g.total_stars(), g.max_level)
	g._rbox(r, Color("#3A2468") if on else Color("#24173F"), 22)
	if on:
		g.draw_polyline(_rr_outline(r.grow(-2), 20), OK_COL, 4.0, true)
	var ic := r.position + Vector2(r.size.x / 2.0, 66)
	if lock != "":
		g.draw_circle(ic, 56, Color(0, 0, 0, 0.25), true, -1.0, true)
	if is_decor:
		home.draw_decor_icon(g, it.id, ic, 118, g.t_total)
	else:
		hero.draw_item_icon(g, it.id, it.slot, kind, ic, 120, g.t_total)
	g.draw_set_transform(Vector2.ZERO)
	if lock != "":
		g._rbox(Rect2(r.position, Vector2(r.size.x, 132)), Color(0.08, 0.04, 0.15, 0.5), 22)
	if tryon.id == it.id:
		var pulse := 0.8 + 0.2 * sin(g.t_total * 5.0)
		g.draw_polyline(_rr_outline(r.grow(-2), 20), Color(g.ACCENT, pulse), 5.0, true)
		_badge(Vector2(r.get_center().x, r.position.y + 4), I18n.t("try_on"), 18)
	var nm := Meta.item_name(it.id, kind)
	_text(Vector2(r.position.x, r.position.y + 154), nm, fit_size(nm, r.size.x - 10, 21), g.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var sy := r.position.y + 186
	var cx := r.get_center().x
	if on:
		_ctext(cx, sy, I18n.t("card_placed") if is_decor else I18n.t("card_worn"), 24, OK_COL, r.size.x)
	elif own:
		_ctext(cx, sy, I18n.t("card_place") if is_decor else I18n.t("card_wear"), 24, g.ACCENT, r.size.x)
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
		hero.draw_item_icon(g, tryon.id, it.slot, kind, ic, 66, g.t_total)
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
	_text(Vector2(tx, r.position.y + 42), Meta.item_name(tryon.id, kind), 30, g.TEXT, tw)
	var line := I18n.t("try_hint")
	var col: Color = g.DIM
	if st == "poor":
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
	match tryon.confirm(g.meta, g.total_stars(), g.max_level):
		"bought", "owned":
			g.play("crystal")
			say(I18n.t("bought") % Meta.item_name(id, g.meta.hero))
			poke_hero()
			fx_t = 0.0
			fx_at = focus
			g._save()
		"poor":
			g.play("gameover", 1.3, -8.0)
		_:
			g.play("click", 0.7)
			say(Meta.lock_reason(id, g.total_stars(), g.max_level))


func tap_wardrobe(pos: Vector2) -> void:
	var on_card := false
	for n in rects:
		if String(n).begins_with("item_") and rects[n].has_point(pos):
			on_card = true
	if tryon.active() and not on_card:
		if rects.get("try_buy", Rect2()).has_point(pos):
			_confirm_try()
		elif rects.get("try_cancel", Rect2()).has_point(pos) or not rects.get("try_panel", Rect2()).has_point(pos):
			cancel_try()
		return
	if rects.get("back", Rect2()).has_point(pos):
		g.play("click")
		g.go_home()
		return
	var tabs := Meta.SLOTS.duplicate()
	tabs.append("home")
	for tname in tabs:
		if rects.get("tab_" + tname, Rect2()).has_point(pos):
			g.play("click")
			tab = tname
			return
	for h in Meta.HEROES:
		if tab != "home" and rects.get("chip_" + h, Rect2()).has_point(pos):
			if g.meta.hero != h:
				g.meta.set_hero(h)
				fade = 1.0
				poke_hero()
				g._save()
			g.play("click")
			return
	if tab == "home":
		for sp in Meta.SPOTS:
			if rects.get("chip_" + sp, Rect2()).has_point(pos) or rects.get("spot_" + sp, Rect2()).has_point(pos):
				g.play("click")
				spot = sp
				return
	if rects.get("hero", Rect2()).has_point(pos) and tab != "home":
		poke_hero()
		g.play("crystal", randf_range(0.9, 1.15), -6.0)
		return
	var kind: String = g.meta.hero if g.meta.hero != "" else "owl"
	var items: Array = Meta.decor_for(kind, spot) if tab == "home" else Meta.items_in(tab)
	for it in items:
		if rects.get("item_" + it.id, Rect2()).has_point(pos):
			tap_card(it.id, kind)
			return


## Нажатие на карточку вещи / украшения (для текущей вкладки и места).
## Купленное — надеть/снять сразу; некупленное — примерка (повторное нажатие — снять примерку).
func tap_card(id: String, kind: String) -> void:
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
	_ctext(g.W / 2.0, y0 + 430, I18n.t("win_stats") % [g.score, g.pieces_used], 30, g.DIM)
	# осколки
	var rw: Dictionary = g.last_reward
	var total: int = rw.get("total", 0)
	var k := clampf((st - 0.9) / 0.9, 0.0, 1.0)
	var shown := int(round(total * k))
	var box := Rect2(110, y0 + 470, 500, 170)
	g._rbox(box, Color(0.16, 0.1, 0.3, 0.95), 30)
	if st > 0.9:
		var bump := 1.0 + 0.25 * maxf(0.0, 1.0 - absf(st - 1.85) / 0.2)
		shard_icon(Vector2(box.position.x + 90, box.position.y + 64), 30 * bump)
		_text(Vector2(box.position.x + 140, box.position.y + 84), "+%d %s" % [shown, shards_word(shown)], int(46 * bump), g.CRYSTAL_COL)
		var parts: Array = []
		if rw.get("win", 0) > 0:
			parts.append(I18n.t("win_first" if rw.get("win", 0) == Meta.WIN_FIRST else "win_repeat") % rw.win)
		if rw.get("stars", 0) > 0:
			parts.append(I18n.t("win_stars") % rw.stars)
		if rw.get("chains", 0) > 0:
			parts.append(I18n.t("win_chains") % rw.chains)
		_ctext(box.get_center().x, box.position.y + 136, " · ".join(parts), 24, g.DIM, box.size.x - 20)
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
		_button("next", Rect2(110, y0 + 690, 500, 120), I18n.t("next"), true, 46)
		_button("home", Rect2(110, y0 + 830, 500, 96), I18n.t("home"), false, 36)


static func shards_word(n: int) -> String:
	return I18n.forms("shards_forms", n)


func draw_lose() -> void:
	rects.clear()
	var H: float = g.H
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.05, 0.03, 0.1, 0.78))
	var y0 := H * 0.5 - 420.0
	avatar(Vector2(g.W / 2.0, y0 + 110), 70)
	_shadow_text(g.W / 2.0, y0 + 260, I18n.t("lose_title"), 54, g.TEXT)
	_ctext(g.W / 2.0, y0 + 330, I18n.t("lose_crystals") % [g.crystals_total - g.crystals_left, g.crystals_total], 34, g.CRYSTAL_COL)
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
