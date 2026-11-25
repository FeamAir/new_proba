extends RefCounted
## Версия 0.9: рисование и касания для помощи и удержания (данные — scripts/assist.gd):
##  - экран поражения с предложением «Подсказка кристалла» (после 2 проигрышей подряд);
##  - цель на главном экране «До следующей вещи: N» с полоской и значок на «Гардеробе»;
##  - номер версии в паузе и скрытый экран статистики для тестировщиков
##    (5 касаний по номеру версии): таблица по уровням и кнопка «Скопировать» (CSV).
## Рисует на узле игры g (scripts/game.gd), общие элементы берёт у g.screens.

const Meta := preload("res://scripts/meta.gd")
const I18n := preload("res://scripts/i18n.gd")
const Assist := preload("res://scripts/assist.gd")

const DARK_TEXT := Color("#2A1A0A")
const OK_COL := Color("#3DDC97")
const TAPS_TO_OPEN := 5
const ROWS_PER_PAGE := 25

var g
var rects := {}
var stats_open := false
var stats_page := 0
var ver_taps := 0
var ver_last := 0.0
var copied_t := 0.0


func _init(game) -> void:
	g = game


func update(delta: float) -> void:
	copied_t = maxf(0.0, copied_t - delta)


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.9"))


## Размер шрифта, при котором строка помещается в ширину (не меньше 16).
func fit(text: String, size: int, width: float) -> int:
	while size > 16 and g.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


# ---------- Поражение: предложение помощи ----------

func offers(lvl: int) -> bool:
	return g.assist.offer_rows(lvl) > 0


func draw_lose() -> void:
	rects.clear()
	var H: float = g.H
	var sc = g.screens
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.05, 0.03, 0.1, 0.78))
	var y0 := H * 0.5 - 520.0
	sc.avatar(Vector2(g.W / 2.0, y0 + 110), 70)
	sc._shadow_text(g.W / 2.0, y0 + 250, I18n.t("lose_title"), 54, g.TEXT)
	sc._ctext(g.W / 2.0, y0 + 312, I18n.t("lose_crystals") % [g.crystals_total - g.crystals_left, g.crystals_total], 34, g.CRYSTAL_COL)
	# карточка помощи
	var rows: int = g.assist.offer_rows(g.level)
	var box := Rect2(50, y0 + 360, 620, 330)
	var pulse := 0.5 + 0.5 * sin(g.t_total * 3.0)
	g._rbox(box.grow(6), Color(g.CRYSTAL_COL, 0.18 + 0.12 * pulse), 40)
	g._rbox(box, Color("#2E1D58"), 34)
	_boost_icon(box.position + Vector2(84, 92), 46)
	sc._text(Vector2(box.position.x + 150, box.position.y + 70), I18n.t("boost_title"), 38, g.CRYSTAL_COL, box.size.x - 170)
	sc._text(Vector2(box.position.x + 150, box.position.y + 112), I18n.t("boost_free"), 24, OK_COL, box.size.x - 170)
	var desc := I18n.t("boost_desc_1") if rows == 1 else I18n.t("boost_desc_2")
	sc._ctext(box.get_center().x, box.position.y + 184, desc, fit(desc, 28, box.size.x - 40), g.TEXT, box.size.x - 40)
	sc._ctext(box.get_center().x, box.position.y + 222, I18n.t("boost_why") % g.assist.streak.get(g.level, 0), 22, g.DIM, box.size.x - 40)
	if g.state_time > 0.8:
		sc._button("boost", Rect2(box.position.x + 30, box.end.y - 90, box.size.x - 60, 70), I18n.t("boost_yes"), true, 34)
		rects["boost"] = sc.rects["boost"]
		sc._button("retry", Rect2(110, box.end.y + 30, 500, 96), I18n.t("boost_no"), false, 32)
		rects["retry"] = sc.rects["retry"]
		sc._button("home", Rect2(110, box.end.y + 146, 500, 86), I18n.t("home"), false, 32)
		rects["home"] = sc.rects["home"]


## Иконка «кристалл со стрелкой вниз» (ряд камня уходит).
func _boost_icon(c: Vector2, r: float) -> void:
	g.draw_circle(c, r * 1.25, Color(g.CRYSTAL_COL, 0.12), true, -1.0, true)
	g.screens.shard_icon(c + Vector2(0, -r * 0.25), r * 0.7)
	for i in 3:
		g._rbox(Rect2(c.x - r * 0.95 + i * r * 0.66, c.y + r * 0.62, r * 0.58, r * 0.38), Color(g.STONE_COL, 0.55), 5)
	g.draw_line(c + Vector2(-r, r * 0.81), c + Vector2(r, r * 0.81), Color(g.CRYSTAL_COL, 0.9), 3.0, true)


## true — касание обработано экраном помощи.
func tap_lose(pos: Vector2) -> bool:
	if not offers(g.level):
		return false
	if g.state_time <= 0.8:
		return true
	if rects.get("boost", Rect2()).has_point(pos):
		g.play("crystal")
		g.assist.accept(g.level)
		g.start_level(g.level)
	elif rects.get("retry", Rect2()).has_point(pos):
		g.play("click")
		g.start_level(g.level)
	elif rects.get("home", Rect2()).has_point(pos):
		g.play("click")
		g.go_home()
	return true


# ---------- Главный экран: цель ----------

func goal() -> Dictionary:
	var hero: String = g.meta.hero if g.meta.hero != "" else "owl"
	return Assist.next_goal(g.meta, hero, g.total_stars(), g.max_level)


## Рисуется поверх главного экрана (после screens.draw_home): под кнопкой «Играть».
func draw_home_goal() -> void:
	rects.erase("goal")
	var gl := goal()
	var play: Rect2 = g.screens.rects.get("play", Rect2())
	if gl.is_empty() or play.size.x <= 0:
		return
	var sc = g.screens
	var r := Rect2(play.position.x, play.end.y + 14, play.size.x, 54)
	rects["goal"] = r
	g._rbox(r, Color(0.08, 0.04, 0.16, 0.88), 27)
	var name := Meta.item_name(gl.id)
	if gl.ready:
		var pulse := 0.5 + 0.5 * sin(g.t_total * 5.0)
		g._rbox(r, Color(OK_COL, 0.12 + 0.12 * pulse), 27)
		sc.shard_icon(r.position + Vector2(32, 27), 14)
		sc._ctext(r.get_center().x + 14, r.position.y + 37, I18n.t("goal_ready") % name, 26, OK_COL, r.size.x - 70)
	else:
		sc.shard_icon(r.position + Vector2(32, 22), 12)
		var label := I18n.t("goal_next") % [gl.need, I18n.forms("shards_forms", gl.need)]
		sc._text(Vector2(r.position.x + 56, r.position.y + 31), label, fit(label, 23, r.size.x - 150), g.TEXT, r.size.x - 140)
		sc._text(Vector2(r.position.x, r.position.y + 31), "%d/%d" % [gl.have, gl.price], 22, g.CRYSTAL_COL, r.size.x - 22, HORIZONTAL_ALIGNMENT_RIGHT)
		var bar := Rect2(r.position.x + 56, r.position.y + 38, r.size.x - 78, 8)
		g._rbox(bar, Color(1, 1, 1, 0.12), 4)
		var k := clampf(float(gl.have) / maxf(1.0, gl.price), 0.0, 1.0)
		if k > 0.0:
			g._rbox(Rect2(bar.position, Vector2(maxf(8.0, bar.size.x * k), bar.size.y)), g.CRYSTAL_COL, 4)
	# мигающий значок на «Гардеробе», когда хватает
	var wr: Rect2 = sc.rects.get("wardrobe", Rect2())
	if gl.ready and wr.size.x > 0:
		var c := wr.position + Vector2(wr.size.x - 16, 14)
		var s := 1.0 + 0.25 * sin(g.t_total * 8.0)
		g.draw_circle(c, 20 * s, Color(OK_COL, 0.3), true, -1.0, true)
		g.draw_circle(c, 15, OK_COL, true, -1.0, true)
		g.draw_string(g.font, c + Vector2(-15, 9), "!", HORIZONTAL_ALIGNMENT_CENTER, 30, 26, DARK_TEXT)


## Касание цели — гардероб сразу на нужной вкладке.
func tap_home(pos: Vector2) -> bool:
	if not rects.get("goal", Rect2()).has_point(pos):
		return false
	var gl := goal()
	if gl.is_empty():
		return false
	g.play("click")
	if gl.home != "":
		var it := Meta.item(gl.id)
		for s in Meta.SPOTS:
			if it.spots.has(Meta.spot_kind(s)):
				g.screens.spot = s
				break
		g.screens.open_wardrobe("home")
	else:
		g.screens.open_wardrobe(gl.slot, gl.id)
	return true


# ---------- Пауза: версия и скрытая статистика ----------

func version_rect() -> Rect2:
	var y: float = g.menu_buttons["menu"].end.y + 16.0 if g.menu_buttons.has("menu") else g.H - 96.0
	return Rect2(g.W / 2.0 - 140, y, 280, 60)


func draw_pause_version() -> void:
	var r := version_rect()
	g.draw_string(g.font, Vector2(r.position.x, r.position.y + 38), "Cascado v" + version(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(g.DIM, 0.7))


## Касание в паузе. true — обработано (номер версии или экран статистики).
func tap_pause(pos: Vector2) -> bool:
	if stats_open:
		_tap_stats(pos)
		return true
	if not version_rect().has_point(pos):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - ver_last > 1.5:
		ver_taps = 0
	ver_last = now
	ver_taps += 1
	if ver_taps >= TAPS_TO_OPEN:
		ver_taps = 0
		open_stats()
	return true


func open_stats() -> void:
	stats_open = true
	stats_page = 0
	g.play("click")


func pages() -> int:
	return maxi(1, ceili(g.assist.levels.size() / float(ROWS_PER_PAGE)))


func draw_stats() -> void:
	rects.clear()
	var H: float = g.H
	var sc = g.screens
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.04, 0.02, 0.09))
	sc._ctext(g.W / 2.0, 90, I18n.t("stats_title"), 44, g.TEXT)
	sc._ctext(g.W / 2.0, 130, I18n.t("stats_sub") + "  ·  v" + version(), 22, g.DIM)
	var cols := [I18n.t("stats_level"), I18n.t("stats_tries"), I18n.t("stats_losses"), I18n.t("stats_wins"), I18n.t("stats_best"), I18n.t("stats_help")]
	var xs := [20.0, 133.0, 246.0, 359.0, 472.0, 585.0]
	var ws := [113.0, 113.0, 113.0, 113.0, 113.0, 113.0]
	var y := 190.0
	g._rbox(Rect2(20, y - 34, g.W - 40, 48), Color("#2A1A4F"), 14)
	for i in cols.size():
		sc._text(Vector2(xs[i], y), cols[i], fit(cols[i], 20, ws[i] - 6), g.ACCENT, ws[i], HORIZONTAL_ALIGNMENT_CENTER)
	var ks: Array = g.assist.sorted_levels()
	stats_page = clampi(stats_page, 0, pages() - 1)
	var from := stats_page * ROWS_PER_PAGE
	y += 44.0
	if ks.is_empty():
		sc._ctext(g.W / 2.0, y + 40, I18n.t("stats_empty"), 28, g.DIM)
	for j in range(from, mini(ks.size(), from + ROWS_PER_PAGE)):
		var n: int = ks[j]
		var r: Dictionary = g.assist.levels[n]
		if (j - from) % 2 == 0:
			g.draw_rect(Rect2(20, y - 26, g.W - 40, 34), Color(1, 1, 1, 0.04))
		var vals := [str(n), str(r.tries), str(r.losses), str(r.wins), str(r.best) if r.best > 0 else "–", str(r.help)]
		for i in vals.size():
			var col: Color = g.TEXT
			if i == 2 and r.losses >= 3:
				col = Color("#FF6B8A")
			elif i == 5 and r.help > 0:
				col = g.CRYSTAL_COL
			sc._text(Vector2(xs[i], y), vals[i], 24, col, ws[i], HORIZONTAL_ALIGNMENT_CENTER)
		y += 34.0
	var by := H - 230.0
	for k in ["st_prev", "st_next", "st_copy", "st_close"]:
		sc.rects.erase(k)
	if pages() > 1:
		sc._button("st_prev", Rect2(40, by - 90, 140, 70), "‹", false, 40)
		sc._button("st_next", Rect2(g.W - 180, by - 90, 140, 70), "›", false, 40)
		sc._ctext(g.W / 2.0, by - 44, "%d / %d" % [stats_page + 1, pages()], 26, g.DIM)
	sc._button("st_copy", Rect2(110, by, 500, 96), I18n.t("stats_copied") if copied_t > 0.0 else I18n.t("stats_copy"), true, 36)
	sc._button("st_close", Rect2(110, by + 110, 500, 84), I18n.t("stats_close"), false, 32)
	for k in ["st_prev", "st_next", "st_copy", "st_close"]:
		if sc.rects.has(k):
			rects[k] = sc.rects[k]


func _tap_stats(pos: Vector2) -> void:
	if rects.get("st_copy", Rect2()).has_point(pos):
		DisplayServer.clipboard_set(g.assist.csv())
		copied_t = 2.0
		g.play("crystal")
	elif rects.get("st_close", Rect2()).has_point(pos):
		stats_open = false
		g.play("click")
	elif rects.get("st_prev", Rect2()).has_point(pos):
		stats_page = maxi(0, stats_page - 1)
	elif rects.get("st_next", Rect2()).has_point(pos):
		stats_page = mini(pages() - 1, stats_page + 1)
