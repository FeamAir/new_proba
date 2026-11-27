extends RefCounted
## Кубки на экранах Cascado (0.14):
##   * экран победы после последнего уровня зала (10, 20, … 100) — «Новый кубок!»: кубок в рамке, лучи,
##     искры; через пару секунд (или по касанию) карточка уменьшается в плашку внизу, кнопки доступны;
##   * экран «Дом» — кнопка «Кубки» (слева под аватаркой): в 3D камера летит к полке славы (ещё раз — обратно),
##     в запасном 2D-доме открывается полка славы с 2D-кубками; подпись, когда камера у кубка или у полки;
##   * запасной 2D-дом: при возвращении с новым кубком полка открывается сама (один раз).
## Рисунки кубков — scripts/trophies.gd; данные (какие кубки есть, даты) — scripts/meta.gd.
## 0.18: у полки в 3D — обзор от первого лица: палец поворачивает «голову» (scripts/home3d/orbit_camera.gd),
##   тап по кубку — его название в подписи, тап мимо из режима полки не выводит; кнопки «Прямо» (взгляд в
##   середину полки) и «Закрыть». На полке 2D — стрелки в подписи и свайп по полке (тап — при отпускании пальца).

const Meta := preload("res://scripts/meta.gd")
const I18n := preload("res://scripts/i18n.gd")
const Trophies := preload("res://scripts/trophies.gd")
const Swipe := preload("res://scripts/swipe.gd")

const GOLD := Color("#FFD36B")
const PANEL := Color(0.09, 0.05, 0.18, 0.92)
const DARK := Color("#2A1A0A")
## Сколько секунд кубок показывается крупно на экране победы
const CEREMONY := 2.6

var g
## Кубок за последнюю победу (номер зала; 0 — без кубка)
var win_trophy := 0
var rects := {}
## Запасной 2D-дом: открыта ли полка славы, выбранный кубок, время открытия, новые (появляются с блеском)
var panel_open := false
var panel_sel := 0
var panel_t := 0.0
var panel_new: Array = []
var _skip := false
var _auto_done := false
## 0.18: свайп по полке 2D
var strip = Swipe.new()


func _init(game) -> void:
	g = game


# ---------- Экран победы ----------

## После победы: номер зала, если за неё вручён кубок (Meta.award_trophy), иначе 0
func on_win(n: int) -> void:
	win_trophy = n
	_skip = false
	if n > 0:
		_auto_done = false  # запасной 2D-дом: полка с новым кубком откроется сама
	if n > 0 and g.has_method("play"):
		g.play("crystal", 1.3, -2.0)


## Крупный показ идёт (касания по кнопкам победы пока не проходят — касание пропускает показ)
func ceremony() -> bool:
	return win_trophy > 0 and not _skip and g.state_time < CEREMONY + 0.5


func tap_win(pos: Vector2) -> bool:
	if ceremony():
		_skip = true
		return true
	return false


func draw_win() -> void:
	if win_trophy <= 0:
		return
	var st: float = g.state_time
	var H: float = g.H
	var n := win_trophy
	# 0..1: крупная карточка уезжает в плашку внизу
	var k := 1.0 if _skip else clampf((st - CEREMONY) / 0.5, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var big_c := Vector2(g.W / 2.0, H * 0.5 - 60.0)
	var small_c := Vector2(150, minf(H - 116.0, H * 0.5 + 520.0 + 108.0))
	if k < 1.0:
		var a := (1.0 - k)
		g.draw_rect(Rect2(0, 0, g.W, H), Color(0.04, 0.02, 0.09, 0.9 * a))
		var appear := clampf(st / 0.45, 0.0, 1.0)
		var pop := 1.0 - pow(1.0 - appear, 3.0) + 0.12 * sin(appear * PI)
		var c := big_c.lerp(small_c, k)
		var s := lerpf(340.0, 150.0, k) * pop
		_frame(Rect2(c - Vector2(300, 300) * pop * (1.0 - k * 0.6), Vector2(600, 640) * pop * (1.0 - k * 0.6)), Trophies.glow_color(n), a)
		Trophies.draw_rays(g, n, c, s * 0.95, g.t_total, a)
		Trophies.draw(g, n, c, s, g.t_total)
		_sparkles(c, s, st, a)
		if pop > 0.6:
			var ta := a * clampf((pop - 0.6) / 0.3, 0.0, 1.0)
			_ribbon(Vector2(c.x, c.y - 300 * pop + 6), I18n.t("trophy_new"), ta)
			_ctext(c.x, c.y + 230, Meta.trophy_name(n), 44, Color(GOLD, ta))
			_ctext(c.x, c.y + 274, I18n.t("trophy_for") % Meta.hall_name(n - 1), 26, Color(g.TEXT, ta))
			_ctext(c.x, c.y + 312, I18n.t("trophy_on_shelf"), 24, Color(g.DIM, ta))
	if k > 0.0:
		# плашка внизу экрана победы
		var r := Rect2(24, small_c.y - 92, g.W - 48, 184)
		var a := k
		g._rbox(r, Color(PANEL, 0.95 * a), 28)
		g.draw_polyline(_rr(r.grow(-3), 25), Color(Trophies.glow_color(n).lightened(0.3), 0.8 * a), 3.0, true)
		Trophies.draw_rays(g, n, small_c, 120, g.t_total, a * 0.8)
		Trophies.draw(g, n, small_c, 150, g.t_total)
		var tx := 252.0
		_text(Vector2(tx, r.position.y + 58), I18n.t("trophy_new"), 30, Color(GOLD, a), g.W - tx - 40)
		_text(Vector2(tx, r.position.y + 104), Meta.trophy_name(n), _fit(Meta.trophy_name(n), g.W - tx - 40, 36), Color(g.TEXT, a), g.W - tx - 40)
		_text(Vector2(tx, r.position.y + 146), I18n.t("trophy_on_shelf"), _fit(I18n.t("trophy_on_shelf"), g.W - tx - 40, 22), Color(g.DIM, a), g.W - tx - 40)


func _frame(r: Rect2, col: Color, a: float) -> void:
	if r.size.x < 20:
		return
	g._rbox(r, Color(0.1, 0.05, 0.2, a), 40)
	g._rbox(r.grow(-14), Color(col.darkened(0.55), 0.35 * a), 30)
	g.draw_polyline(_rr(r.grow(-4), 36), Color(GOLD, 0.95 * a), 4.0, true)
	g.draw_polyline(_rr(r.grow(-14), 28), Color(col.lightened(0.35), 0.6 * a), 2.0, true)
	for cx in [r.position.x + 18, r.end.x - 18]:
		for cy in [r.position.y + 18, r.end.y - 18]:
			_diamond(Vector2(cx, cy), 9, Color(col.lightened(0.2), a))


func _ribbon(c: Vector2, label: String, a: float) -> void:
	var fs := 40
	var w: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 90.0
	var r := Rect2(c.x - w / 2.0, c.y - 34, w, 68)
	for sx in [-1.0, 1.0]:
		var e: float = c.x + sx * w / 2.0
		g.draw_colored_polygon(PackedVector2Array([Vector2(e - sx * 20, c.y - 22), Vector2(e + sx * 34, c.y - 22), Vector2(e + sx * 18, c.y + 8),
			Vector2(e + sx * 34, c.y + 38), Vector2(e - sx * 20, c.y + 38)]), Color("#C9862A", a))
	g._rbox(r, Color(GOLD, a), 18)
	g._rbox(Rect2(r.position + Vector2(6, 5), Vector2(r.size.x - 12, 20)), Color(1, 1, 1, 0.25 * a), 12)
	g.draw_string(g.font, Vector2(r.position.x, c.y + 14), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(DARK, a))


func _sparkles(c: Vector2, s: float, st: float, a: float) -> void:
	for i in 12:
		var ph := fposmod(st * 0.6 + i / 12.0, 1.0)
		var ang := i * 2.4 + 0.3
		var p := c + Vector2(cos(ang), sin(ang)) * s * (0.35 + 0.65 * ph)
		var r := 9.0 * sin(ph * PI)
		_star(p, r, Color(1, 0.95, 0.75, a * (1.0 - ph)))


# ---------- Экран «Дом» ----------

func _button_rect() -> Rect2:
	return Rect2(22, 174, 100, 100)


func draw_home() -> void:
	rects.clear()
	var h = g.home3d
	var in3d: bool = h != null and h.showing()
	var cnt := Meta.trophy_count(g.max_level)
	var pend: Array = g.meta.trophies_pending(g.max_level)
	# 2D-дом: полка открывается сама, если есть новые кубки (один раз за вход)
	if not in3d and not pend.is_empty() and not panel_open and not _auto_done and g.state_time > 0.8:
		_auto_done = true
		open_panel()
	# кнопка «Кубки»
	var r := _button_rect()
	rects["trophies"] = r
	var lit: bool = (in3d and (h.shelf_focus or h.trophy_focus > 0)) or panel_open
	if not pend.is_empty() and not in3d:
		var pulse := 0.5 + 0.5 * sin(g.t_total * 5.0)
		g._rbox(r.grow(5 + 3 * pulse), Color(g.ACCENT, 0.3), 32)
	g._rbox(r, Color(0.1, 0.06, 0.2, 0.85) if not lit else Color(0.3, 0.2, 0.05, 0.9), 28)
	g.draw_polyline(_rr(r.grow(-1), 27), Color(GOLD, 0.55), 2.0, true)
	var icon := cnt if cnt > 0 else 1
	Trophies.draw(g, icon, r.get_center() + Vector2(0, -12), 60, g.t_total, cnt == 0, Color(1, 1, 1, 0.3))
	_ctext(r.get_center().x, r.end.y - 9, "%d/%d" % [cnt, Meta.HALL_COUNT], 20, GOLD if cnt > 0 else g.TEXT, r.size.x)
	if in3d:
		_caption_3d(h)
		if h.shelf_focus and not h.revealing():
			_shelf_controls(h)
	if panel_open:
		_draw_panel()


## Подпись у кубка / у полки / во время показа новых кубков
func _caption_3d(h) -> void:
	var n: int = h.trophy_focus
	var r := Rect2(70, 262, g.W - 140, 112)
	if h.revealing():
		var halls: Array = h.reveal_halls
		var a := clampf(h.reveal_t / 0.4, 0.0, 1.0) * clampf((h.REVEAL_LEN + 0.45 * halls.size() - h.reveal_t) / 0.5, 0.0, 1.0)
		if a <= 0.0:
			return
		_cap_box(r, a, Trophies.glow_color(halls[halls.size() - 1]))
		if halls.size() == 1:
			_ctext(r.get_center().x, r.position.y + 46, I18n.t("trophy_new"), 32, Color(GOLD, a), r.size.x)
			_ctext(r.get_center().x, r.position.y + 90, Meta.trophy_name(halls[0]), _fit(Meta.trophy_name(halls[0]), r.size.x - 30, 34), Color(g.TEXT, a), r.size.x)
		else:
			_ctext(r.get_center().x, r.position.y + 46, I18n.t("trophy_shelf"), 32, Color(GOLD, a), r.size.x)
			_ctext(r.get_center().x, r.position.y + 90, "%d / %d" % [Meta.trophy_count(g.max_level), Meta.HALL_COUNT], 34, Color(g.TEXT, a), r.size.x)
		return
	r.size.y = 98  # 0.18: в обзоре полки подпись ниже — больше места для полки
	if n > 0:
		var have: bool = Meta.trophy_count(g.max_level) >= n
		_cap_box(r, 1.0, Trophies.glow_color(n) if have else Color(0.6, 0.6, 0.8))
		var nm := Meta.trophy_name(n)
		_ctext(r.get_center().x, r.position.y + 42, nm, _fit(nm, r.size.x - 30, 36), GOLD if have else Color(0.85, 0.85, 0.95), r.size.x)
		var sub := ""
		if have:
			sub = "%s · %s" % [Meta.hall_name(n - 1), g.meta.trophy_done_text(n)]
		else:
			sub = I18n.t("trophy_locked") % n
		_ctext(r.get_center().x, r.position.y + 80, sub, _fit(sub, r.size.x - 30, 25), g.TEXT, r.size.x)
	elif h.shelf_focus:
		_cap_box(r, 1.0, GOLD)
		_ctext(r.get_center().x, r.position.y + 42, I18n.t("trophy_shelf"), 36, GOLD, r.size.x)
		var sub := "%d / %d · %s" % [Meta.trophy_count(g.max_level), Meta.HALL_COUNT, I18n.t("trophy_tap")]
		_ctext(r.get_center().x, r.position.y + 80, sub, _fit(sub, r.size.x - 30, 25), g.TEXT, r.size.x)


## 0.18: кнопки у полки в 3D под подписью: «Прямо» и «Закрыть»; пока игрок не повернул голову — подсказка
func _shelf_controls(h) -> void:
	var R := shelf_rects()
	rects["sh_center"] = R.sh_center
	_pill_button(R.sh_center, I18n.t("shelf_center"))
	rects["sh_close"] = R.sh_close
	_pill_button(R.sh_close, "✕  " + I18n.t("shelf_close"))
	if not h.room.cam.look_used:
		var hint := I18n.t("shelf_hint")
		var hfs := _fit(hint, g.W - 120, 23)
		var hw: float = g.font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x + 36.0
		g._rbox(Rect2(g.W / 2.0 - hw / 2.0, 432, hw, 30), Color(PANEL, 0.7), 15)
		_ctext(g.W / 2.0, 454, hint, hfs, Color(g.TEXT, 0.9), g.W)


## Где кнопки полки 3D (для рисования, касаний и тестов)
func shelf_rects() -> Dictionary:
	return {
		"sh_center": Rect2(84, 370, 290, 56),
		"sh_close": Rect2(386, 370, 250, 56),
	}


func _pill_button(r: Rect2, label: String) -> void:
	g._rbox(r, Color(0.1, 0.06, 0.2, 0.85), 24)
	g.draw_polyline(_rr(r.grow(-1), 23), Color(GOLD, 0.55), 2.0, true)
	g.draw_string(g.font, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 10), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _fit(label, r.size.x - 24, 28), g.TEXT)


## 0.18: касание кнопок полки 3D; true — обработано
func _tap_shelf_3d(pos: Vector2) -> bool:
	var h = g.home3d
	if h == null or not h.showing() or not h.in_shelf() or h.revealing():
		return false
	var R := shelf_rects()
	if R.sh_center.has_point(pos):
		h.look_center()
		return true
	if R.sh_close.has_point(pos):
		h.close_shelf()
		return true
	return false


func _cap_box(r: Rect2, a: float, col: Color) -> void:
	g._rbox(r, Color(PANEL, 0.9 * a), 26)
	g.draw_polyline(_rr(r.grow(-2), 24), Color(col.lightened(0.3), 0.75 * a), 2.5, true)


## 0.18: касание на экране «Дом» (от игры): полка 2D открыта — ждём отпускания (тап или свайп)
func press(idx: int, pos: Vector2) -> bool:
	if not panel_open:
		return false
	strip.press(idx, pos)
	return true


func release(idx: int, pos: Vector2) -> void:
	if not strip.active():
		return
	var res: int = strip.release(idx, pos)
	if not panel_open:
		return
	match res:
		Swipe.TAP:
			tap_home(strip.start)
		Swipe.NEXT:
			step_panel(1)
		Swipe.PREV:
			step_panel(-1)


## 0.18: полка 2D: соседний кубок (+1 / -1, по кругу 1…10)
func step_panel(dir: int) -> void:
	var n := panel_sel
	if n == 0:
		n = 0 if dir > 0 else 11
	panel_sel = wrapi(n + dir, 1, 11)
	g.play("crystal", 1.2 if panel_sel <= Meta.trophy_count(g.max_level) else 0.8, -4.0)


func tap_home(pos: Vector2) -> bool:
	if panel_open:
		_tap_panel(pos)
		return true
	if _tap_shelf_3d(pos):
		return true
	if rects.get("trophies", _button_rect()).has_point(pos):
		var h = g.home3d
		if h != null and h.showing():
			h.focus_shelf()
		else:
			g.play("click")
			open_panel()
		return true
	return false


## Кнопка «Назад» телефона: закрыть полку 2D
func back() -> bool:
	if panel_open:
		panel_open = false
		return true
	var h = g.home3d
	if h != null and h.showing() and h.in_shelf():
		h.close_shelf()  # 0.18: у полки 3D — к обзору дома
		return true
	return false


# ---------- Полка славы в запасном 2D-доме ----------

func open_panel() -> void:
	panel_open = true
	panel_t = g.t_total
	panel_new = g.meta.trophies_pending(g.max_level)
	panel_sel = panel_new[panel_new.size() - 1] if not panel_new.is_empty() else 0
	if not panel_new.is_empty():
		g.meta.mark_trophies_seen(g.max_level)
		if g.has_method("_save"):
			g._save()
		g.play("levelup", 1.15, -4.0)


func _panel_rect() -> Rect2:
	return Rect2(28, maxf(180.0, g.H * 0.5 - 420.0), g.W - 56, 820)


## Цвета полки по дому героя: [доска, кромка, фон]
func _shelf_cols() -> Array:
	match g.meta.hero:
		"axolotl": return [Color("#8FB9C4"), Color("#5E8F9C"), Color("#0E3A52")]
		"puppy": return [Color("#C88A58"), Color("#E0596F"), Color("#1E2A4A")]
		"kitten": return [Color("#A0694C"), Color("#FFD34D"), Color("#2E1640")]
	return [Color("#8A5A3C"), Color("#5E8F45"), Color("#2A1830")]


func _slot_center(n: int) -> Vector2:
	var pr := _panel_rect()
	var row := 0 if n <= 5 else 1
	var col := (n - 1) % 5
	return Vector2(pr.position.x + 66 + col * ((pr.size.x - 132) / 4.0), pr.position.y + 230 + row * 250)


func _draw_panel() -> void:
	var pr := _panel_rect()
	var cols := _shelf_cols()
	g.draw_rect(Rect2(0, 0, g.W, g.H), Color(0.03, 0.02, 0.07, 0.7))
	g._rbox(pr, Color(cols[2], 0.97), 34)
	g.draw_polyline(_rr(pr.grow(-3), 31), Color(GOLD, 0.8), 3.0, true)
	_ribbon(Vector2(pr.get_center().x, pr.position.y + 10), I18n.t("trophy_shelf"), 1.0)
	_ctext(pr.get_center().x, pr.position.y + 86, "%d / %d" % [Meta.trophy_count(g.max_level), Meta.HALL_COUNT], 26, g.DIM, pr.size.x)
	var cnt := Meta.trophy_count(g.max_level)
	for row in 2:
		var y := pr.position.y + 230 + row * 250 + 84
		var plank := Rect2(pr.position.x + 18, y, pr.size.x - 36, 26)
		g._rbox(Rect2(plank.position + Vector2(0, 10), plank.size), Color(0, 0, 0, 0.35), 10)
		g._rbox(plank, cols[0], 10)
		g._rbox(Rect2(plank.position, Vector2(plank.size.x, 8)), Color(cols[0].lightened(0.25)), 6)
		g.draw_line(plank.position + Vector2(10, 22), Vector2(plank.end.x - 10, plank.position.y + 22), cols[1], 3.0, true)
	for n in range(1, 11):
		var c := _slot_center(n)
		var have := n <= cnt
		rects["slot_%d" % n] = Rect2(c - Vector2(62, 100), Vector2(124, 190))
		if n == panel_sel:
			g._rbox(Rect2(c - Vector2(60, 98), Vector2(120, 186)), Color(1, 1, 1, 0.08), 18)
		var appear := 1.0
		var idx := panel_new.find(n)
		if idx >= 0:
			var u: float = (g.t_total - panel_t - 0.3 - idx * 0.35) / 0.6
			appear = clampf(u, 0.0, 1.0)
			if u > 0.0 and u < 1.6:
				Trophies.draw_rays(g, n, c, 110 * clampf(u, 0.0, 1.0), g.t_total, clampf(1.6 - u, 0.0, 1.0))
		if have and appear > 0.0:
			var pop := 1.0 - pow(1.0 - appear, 3.0) + 0.15 * sin(appear * PI)
			Trophies.draw(g, n, c, 150 * pop, g.t_total)
		elif not have:
			Trophies.draw(g, n, c, 150, g.t_total, true, Color(0.8, 0.82, 1.0, 0.18))
		# табличка с номером зала
		var pl := Rect2(c.x - 24, c.y + 92, 48, 26)
		g._rbox(pl, Color("#E8B84A") if have else Color(0.5, 0.45, 0.65, 0.8), 8)
		g.draw_string(g.font, Vector2(pl.position.x, pl.position.y + 20), str(n), HORIZONTAL_ALIGNMENT_CENTER, pl.size.x, 20, DARK if have else g.TEXT)
	# подпись выбранного кубка
	var cap := Rect2(pr.position.x + 24, pr.end.y - 200, pr.size.x - 48, 110)
	# 0.18: стрелки ◀ ▶ — соседний кубок (и свайп по полке)
	for k in 2:
		var name: String = ["p_prev", "p_next"][k]
		var ar := Rect2(cap.position.x - 14 if k == 0 else cap.end.x - 62, cap.position.y + 15, 76, 80)
		rects[name] = ar
		var c := ar.get_center()
		var sx := -1.0 if k == 0 else 1.0
		g.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * 16, 0), c + Vector2(-sx * 10, -18), c + Vector2(-sx * 10, 18)]), Color(GOLD, 0.9))
	cap = cap.grow_individual(-58, 0, -58, 0)
	if panel_sel > 0:
		var have := panel_sel <= cnt
		_cap_box(cap, 1.0, Trophies.glow_color(panel_sel) if have else Color(0.6, 0.6, 0.8))
		var nm := Meta.trophy_name(panel_sel)
		_ctext(cap.get_center().x, cap.position.y + 46, nm, _fit(nm, cap.size.x - 30, 34), GOLD if have else Color(0.85, 0.85, 0.95), cap.size.x)
		var sub: String = ("%s · %s" % [Meta.hall_name(panel_sel - 1), g.meta.trophy_done_text(panel_sel)]) if have else (I18n.t("trophy_locked") % panel_sel)
		_ctext(cap.get_center().x, cap.position.y + 88, sub, _fit(sub, cap.size.x - 30, 24), g.TEXT, cap.size.x)
	else:
		_ctext(cap.get_center().x, cap.position.y + 66, I18n.t("trophy_tap"), 26, g.DIM, cap.size.x)
	# закрыть
	var cl := Rect2(pr.get_center().x - 130, pr.end.y - 76, 260, 60)
	rects["close"] = cl
	g._rbox(cl, g.BTN, 22)
	g.draw_string(g.font, Vector2(cl.position.x, cl.position.y + 41), I18n.t("name_done"), HORIZONTAL_ALIGNMENT_CENTER, cl.size.x, 30, g.TEXT)


func _tap_panel(pos: Vector2) -> void:
	if rects.get("close", Rect2()).has_point(pos) or not _panel_rect().has_point(pos):
		g.play("click")
		panel_open = false
		return
	if rects.get("p_prev", Rect2()).has_point(pos):
		step_panel(-1)
		return
	if rects.get("p_next", Rect2()).has_point(pos):
		step_panel(1)
		return
	for n in range(1, 11):
		if rects.get("slot_%d" % n, Rect2()).has_point(pos):
			panel_sel = n
			g.play("crystal", 1.2 if n <= Meta.trophy_count(g.max_level) else 0.8, -4.0)
			return


# ---------- Мелочи рисования ----------

func _text(p: Vector2, s: String, size: int, col: Color, w := -1.0) -> void:
	g.draw_string(g.font, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)


func _ctext(cx: float, y: float, s: String, size: int, col: Color, w := 700.0) -> void:
	g.draw_string(g.font, Vector2(cx - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _fit(s: String, w: float, size: int) -> int:
	var fs := size
	while fs > 14 and g.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	return fs


func _rr(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for q in 4:
		for i in 7:
			var a := -PI / 2.0 + q * PI / 2.0 + i * (PI / 2.0) / 6.0
			pts.append(cs[q] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	return pts


func _diamond(c: Vector2, r: float, col: Color) -> void:
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)


func _star(c: Vector2, r: float, col: Color) -> void:
	if r < 0.5:
		return
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.2, -r * 0.2), c + Vector2(r, 0), c + Vector2(r * 0.2, r * 0.2),
		c + Vector2(0, r), c + Vector2(-r * 0.2, r * 0.2), c + Vector2(-r, 0), c + Vector2(-r * 0.2, -r * 0.2)]), col)
