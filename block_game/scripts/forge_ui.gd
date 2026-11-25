extends RefCounted
## Cascado 0.12: экран «Кристальная кузница». Ведёт мастер-филин Ух (рисунок — hero.gd, draw_master).
## 0.12b: всё — для ТЕКУЩЕГО героя. Вверху — главная цель: его супер-эксклюзив и три гнезда для
## легендарных вещей. Ниже — 3 карточки его наборов:
## тёмный силуэт награды с «?», ячейки вещей рецепта (силуэт → цвет, когда вещь куплена),
## кнопки «Примерить» (5 секунд) и «Сковать за N». Вещи при ковке не тратятся (правила — meta.gd).
## Ковка — анимация ~3 с (касание пропускает): вещи слетаются на наковальню, кружатся, сливаются
## в кристалл, он трескается, вспышка цветом редкости, награда выплывает, герой её сразу надевает.
##
## Силуэты рисуются в отдельный узел с тёмным modulate (sil), знаки «?» — в узел поверх (top):
## так любая вещь превращается в тёмную тень без отдельных картинок.

const Meta := preload("res://scripts/meta.gd")
const I18n := preload("res://scripts/i18n.gd")
const Rarity := preload("res://scripts/rarity.gd")

const DARK_TEXT := Color("#2A1A0A")
const OK_COL := Color("#3DDC97")
const BAD_COL := Color("#FF6B8A")
const SIL_COL := Color(0.09, 0.05, 0.2, 0.96)
const CARD_TOP := 452.0
const GOAL_H := 320.0
## Масштаб героя-цели (супер-эксклюзив) в шапке кузницы
const GOAL_SC := 0.5
const ANIM_TIME := 3.2
const TRY_TIME := 5.0

var g
var rects := {}
var sil: Node2D        # силуэты (тёмный modulate)
var top: Node2D        # знаки «?» поверх силуэтов
var _sil_q: Array = []
var _top_q: Array = []
var anim_id := ""      # что сейчас куётся ("" — нет)
var anim_t := 0.0
var anim_from: Array = []  # откуда слетаются вещи (экранные точки)
var result := false    # после ковки: показ награды на герое
var try_id := ""       # примерка нескованной награды
var try_t := 0.0
var confetti: Array = []
var react := 99.0
var result_t := 0.0
var _result_id := ""   # что сковано (показ на герое после анимации)


func _init(game) -> void:
	g = game
	sil = Node2D.new()
	sil.modulate = SIL_COL
	sil.draw.connect(_draw_sil)
	top = Node2D.new()
	top.draw.connect(_draw_top)
	g.add_child(sil)
	g.add_child(top)
	sil.visible = false
	top.visible = false


func kind() -> String:
	return g.meta.hero if g.meta.hero != "" else "owl"


## 0.13: пол героя (для названий вещей и рисунков)
func _gen() -> String:
	return g.meta.gender_of(kind())


func open() -> void:
	anim_id = ""
	result = false
	try_id = ""
	confetti.clear()
	g._set_state(g.State.FORGE)


func back() -> void:
	if anim_id != "" or result:
		_finish()
		return
	if try_id != "":
		try_id = ""
		return
	g.play("click")
	g.go_home()


func update(delta: float) -> void:
	var on: bool = g.state == g.State.FORGE
	react += delta
	result_t += delta
	if anim_id != "":
		anim_t += delta
		if anim_t >= ANIM_TIME:
			_to_result()
	if try_id != "":
		try_t += delta
		if try_t >= TRY_TIME:
			try_id = ""
	for c in confetti:
		c.p += c.v * delta
		c.v.y += 520.0 * delta
		c.rot += c.spin * delta
		c.life -= delta
	confetti = confetti.filter(func(c): return c.life > 0.0)
	var show_sil := on and anim_id == "" and not result and try_id == ""
	sil.visible = show_sil
	top.visible = show_sil
	if show_sil:
		sil.queue_redraw()
		top.queue_redraw()


# ---------- Рисование ----------

func _sc():
	return g.screens


func draw() -> void:
	rects.clear()
	_sil_q.clear()
	_top_q.clear()
	var sc = _sc()
	var H: float = g.H
	# шапка
	sc._back_button()
	var title := I18n.t("forge_title")
	sc._text(Vector2(132, 82), title, sc.fit_size(title, 380, 40), g.TEXT)
	var shr := Rect2(g.W - 170, 38, 150, 58)
	sc._pill(shr, Color(0.1, 0.06, 0.2, 0.85))
	sc.shard_icon(shr.position + Vector2(32, 29), 17)
	sc._text(shr.position + Vector2(58, 42), str(g.meta.shards), 34, g.CRYSTAL_COL)
	rects["back"] = sc.rects.get("back", Rect2())
	_draw_goal()
	var sets := Meta.hero_sets(kind())
	for i in sets.size():
		_draw_set_card(sets[i], Rect2(20, CARD_TOP + i * card_step(), 680, card_step() - 12))
	if try_id != "":
		_draw_try()
	if anim_id != "":
		_draw_anim()
	elif result:
		_draw_result()
	_draw_confetti()
	sc._toast(H - 120)


func card_step() -> float:
	return (g.H - 14.0 - CARD_TOP) / 3.0


## Главная цель: мастер Ух, его подсказка, силуэт супер-эксклюзива героя и три гнезда легенд
func _draw_goal() -> void:
	var sc = _sc()
	var r := Rect2(20, 122, 680, GOAL_H)
	g._rbox(r, Color(0.07, 0.04, 0.15, 0.92), 30)
	var t: float = g.t_total
	# кузнечный отсвет
	Rarity.soft_disc(g, Vector2(500, 300), 190, Color(0.7, 0.45, 1.0, 0.22))
	# мастер Ух
	sc.hero.draw_master(g, Vector2(104, 362), 0.56, t, react)
	rects["master"] = Rect2(30, 260, 150, 170)
	# реплика
	var line := _master_line()
	var br := Rect2(36, 136, 290, 96)
	g._rbox(br, Color("#F4EEFF"), 22)
	g.draw_colored_polygon(PackedVector2Array([Vector2(96, 230), Vector2(124, 230), Vector2(100, 252)]), Color("#F4EEFF"))
	g.draw_multiline_string(g.font, br.position + Vector2(14, 36), line, HORIZONTAL_ALIGNMENT_CENTER, br.size.x - 28, 22, 3, Color("#2A1A4F"))
	# супер-эксклюзив героя
	var rc: Dictionary = Meta.super_recipe(kind())
	var wid: String = rc.id
	var st: String = g.meta.forge_status(wid, g.max_level)
	var wc := Vector2(500, 300)
	sc._ctext(wc.x, 156, I18n.t("forge_goal"), 22, Color("#FFD9F4"), 330)
	var wn := Meta.item_name(wid, kind(), _gen())
	sc._ctext(wc.x, 188, wn, sc.fit_size(wn, 330, 30), Color.from_hsv(fposmod(t * 0.15, 1.0), 0.35, 1.0), 340)
	var ir := Rect2(wc - Vector2(150, 100), Vector2(300, 200))
	var hp := wc + Vector2(0, 14)
	if st == "done":
		Rarity.soft_disc(g, wc + Vector2(0, 20), 130, Color.from_hsv(fposmod(t * 0.2, 1.0), 0.5, 1.0, 0.35))
		sc.hero.draw(g, kind(), hp, GOAL_SC, g.meta.look(kind()).merged({"aura": wid}), t, react)
	else:
		var ready := st in ["ok", "poor"]
		Rarity.soft_disc(g, wc + Vector2(0, 18), 120, Color(0.75, 0.55, 1.0, 0.5 + (0.25 * sin(t * 4.0) if ready else 0.0)))
		_sil_q.append(["hero", wid, hp, GOAL_SC])
		_top_q.append(["?", wc + Vector2(70, -40), 50])
	rects["super_try"] = ir
	# гнёзда трёх легенд или кнопка ковки
	if st == "ok" or st == "poor":
		_forge_button("forge_0", Rect2(wc.x - 130, 382, 260, 54), wid, st)
	elif st != "done":
		var have: int = g.meta.recipe_have(wid)
		for i in 3:
			var p := Vector2(wc.x - 60 + i * 60, 398)
			var lid: String = rc.needs[i]
			var lit: bool = g.meta.is_owned(lid)
			var col: Color = Meta.set_info(Meta.set_of(lid)).col
			g.draw_circle(p, 22, Color(col, 0.25) if lit else Color(0.2, 0.14, 0.36), true, -1.0, true)
			if lit:
				_gem(p, 14, col)
			else:
				g.draw_arc(p, 15, 0, TAU, 20, Color(col, 0.4), 2.0, true)
		sc._ctext(wc.x, 438, I18n.t("forge_legends") % have, 19, g.DIM, 320)


func _master_line() -> String:
	var sup: String = Meta.super_recipe(kind()).id
	if g.meta.forged.has(sup):
		return I18n.t("forge_say_all")
	if g.meta.forge_ready_any(g.max_level):
		return I18n.t("forge_say_ready")
	if g.meta.legends_forged() >= 2:
		return I18n.t("forge_say_super")
	if _gen() == "girl" and I18n.has("forge_say_start_%s_girl" % kind()):
		return I18n.t("forge_say_start_%s_girl" % kind())
	return I18n.t("forge_say_start_" + kind())


func _gem(c: Vector2, r: float, col: Color) -> void:
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)]), col)
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.15)]), col.lightened(0.5))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.15), c + Vector2(0, r)]), col.lightened(0.15))
	g.draw_circle(c + Vector2(-r * 0.25, -r * 0.4), r * 0.15, Color(1, 1, 1, 0.9), true, -1.0, true)


## Карточка набора n (номер в Meta.SETS): награда (силуэт / цвет) слева, справа — название,
## пять ячеек рецепта, строка состояния и кнопки «Примерить» / «Сковать за N»
func _draw_set_card(n: int, r: Rect2) -> void:
	var sc = _sc()
	var t: float = g.t_total
	var rc: Dictionary = Meta.recipe_for_set(n)
	var rid: String = rc.id
	var info: Dictionary = Meta.set_info(n)
	var scol: Color = info.col
	var st: String = g.meta.forge_status(rid, g.max_level)
	var rar := Meta.rarity(rid)
	g._rbox(r, Color("#24173F"), 24)
	g._rbox(Rect2(r.position, Vector2(8, r.size.y)).grow_individual(0, -14, 0, -14), Color(scol, 0.8), 4)
	if st == "done":
		Rarity.frame(g, r, rar, t, 24.0, n)
	elif st == "ok":
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		g.draw_polyline(sc._rr_outline(r.grow(-2), 22), Color(g.ACCENT, 0.5 + 0.5 * pulse), 4.0, true)
	rects["card_%d" % n] = r
	# награда
	var ic := r.position + Vector2(96, r.size.y * 0.52)
	var rad := minf(74.0, r.size.y * 0.36)
	var it: Dictionary = Meta.item(rid)
	if st == "done":
		Rarity.icon_glow(g, rar, ic, rad * 2.0, t, n)
		sc.hero.draw_item_icon(g, rid, it.slot, kind(), ic, rad * (1.5 if it.slot == "back" else 2.0), t, _gen())
		Rarity.icon_fx(g, rar, ic, rad * 2.0, t, n, Rect2(ic - Vector2(rad, rad), Vector2(rad, rad) * 2.0))
	else:
		var ready := st == "ok" or st == "poor"
		var pulse := 0.5 + 0.5 * sin(t * 4.0 + n)
		if ready:
			Rarity.soft_disc(g, ic, rad + 26 + pulse * 6, Color(1.0, 0.82, 0.35, 0.45 + 0.2 * pulse))
		g.draw_circle(ic, rad, Color("#4A3A86") if ready else Color("#3A2D66"), true, -1.0, true)
		g.draw_arc(ic, rad, 0, TAU, 40, Color(Rarity.col(rar), 0.55 + (0.45 * pulse if ready else 0.0)), 3.0, true)
		_sil_q.append([it.slot, rid, ic, rad * (1.4 if it.slot == "back" else 1.9)])
		_top_q.append(["?", ic + Vector2(rad * 0.62, -rad * 0.55), 36])
	var tx := r.position.x + 188
	var nm := Meta.set_title(n, _gen())
	sc._text(Vector2(tx, r.position.y + 44), nm, sc.fit_size(nm, r.end.x - tx - 20, 30), scol)
	var locked := st == "hall"
	# ячейки рецепта
	var needs: Array = rc.needs
	var cs := 84.0 if r.size.y > 240.0 else 64.0
	cs = minf(cs, (r.end.x - tx - 20 - 4 * 8) / needs.size())
	var cy := r.position.y + 62
	for i in needs.size():
		var nid: String = needs[i]
		var cr := Rect2(tx + i * (cs + 8), cy, cs, cs)
		var own: bool = g.meta.is_owned(nid)
		g._rbox(cr, Color(scol, 0.22) if own else Color("#3A2D66"), 16)
		var ni: Dictionary = Meta.item(nid)
		var isz := cs * (0.74 if ni.slot == "back" else 0.94)
		if own:
			g.draw_polyline(sc._rr_outline(cr.grow(-1), 15), Color(scol, 0.9), 2.0, true)
			sc.hero.draw_item_icon(g, nid, ni.slot, kind(), cr.get_center(), isz, t, _gen())
			g.draw_set_transform(Vector2.ZERO)
			g.draw_circle(cr.end - Vector2(7, 7), 9, OK_COL, true, -1.0, true)
			g.draw_polyline(PackedVector2Array([cr.end - Vector2(12, 7), cr.end - Vector2(8, 3), cr.end - Vector2(2, 11)]), DARK_TEXT, 2.2, true)
		else:
			_sil_q.append([ni.slot, nid, cr.get_center(), isz])
		rects["need_%d_%d" % [n, i]] = cr
	# строка состояния
	var have: int = g.meta.recipe_have(rid)
	var line := ""
	var lcol: Color = g.DIM
	if locked:
		line = I18n.t("forge_hall_hint") % int(info.hall)
	elif st == "done":
		line = Meta.item_name(rid, kind(), _gen()) + " · " + Meta.rarity_name(rar)
		lcol = Rarity.col(rar)
	else:
		line = I18n.t("forge_have") % [have, needs.size()] + " · " + I18n.t("forge_keep")
		if have == needs.size():
			line = Meta.item_name(rid, kind(), _gen()) + " · " + Meta.rarity_name(rar)
			lcol = Rarity.col(rar)
	sc._text(Vector2(tx, cy + cs + 34), line, sc.fit_size(line, r.end.x - tx - 16, 21), lcol)
	# кнопки внизу справа
	var by := r.end.y - 74
	if locked:
		g._rbox(r, Color(0.05, 0.02, 0.1, 0.45), 24)
		var lr := Rect2(r.end.x - 196, by, 176, 58)
		sc._pill(lr, Color(0.1, 0.06, 0.2, 0.9))
		sc._lock_icon(lr.position + Vector2(38, 30), 18, g.DIM)
		sc._text(Vector2(lr.position.x + 64, lr.position.y + 39), I18n.t("forge_hall") % int(info.hall), 27, g.TEXT)
	elif st == "done":
		var dr := Rect2(r.end.x - 196, by, 176, 56)
		sc._pill(dr, Color(OK_COL, 0.18))
		sc._ctext(dr.get_center().x, dr.position.y + 37, I18n.t("forge_done"), 26, OK_COL, dr.size.x)
		rects["wear_%d" % n] = dr
	else:
		var tr := Rect2(tx, by + 2, 170, 56)
		rects["try_%d" % n] = tr
		g._rbox(tr, g.BTN, 24)
		g.draw_polyline(sc._rr_outline(tr.grow(-1), 23), Color(g.TEXT, 0.25), 2.0, true)
		sc._ctext(tr.get_center().x, tr.position.y + 37, I18n.t("forge_try"), sc.fit_size(I18n.t("forge_try"), 156, 25), g.TEXT, tr.size.x)
		_forge_button("forge_%d" % n, Rect2(r.end.x - 226, by, 206, 60), rid, st)
	if st == "ok":
		sc._badge(Vector2(r.position.x + 96, r.position.y - 6), I18n.t("forge_can"), 16)


## Кнопка «Сковать за N»: активна, когда всё собрано и хватает осколков
func _forge_button(name: String, br: Rect2, rid: String, st: String) -> void:
	var sc = _sc()
	rects[name] = br
	var ok := st == "ok"
	var cost := int(Meta.recipe(rid).cost)
	if ok:
		var pulse := 0.5 + 0.5 * sin(g.t_total * 5.0)
		g._rbox(br.grow(4 + 3 * pulse), Color(g.ACCENT, 0.25), 30)
	g._rbox(br, g.ACCENT if ok else Color(g.BTN, 0.9), 24)
	g._rbox(Rect2(br.position + Vector2(5, 4), Vector2(br.size.x - 10, br.size.y * 0.42)), Color(1, 1, 1, 0.1), 20)
	var label := I18n.t("forge_btn") % cost
	var fs: int = sc.fit_size(label, br.size.x - 44, 24)
	var lw: float = g.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = br.get_center().x - (lw + 30) / 2.0
	var tcol: Color = DARK_TEXT if ok else (BAD_COL if st == "poor" else Color(g.TEXT, 0.45))
	sc._text(Vector2(x0, br.get_center().y + fs * 0.36), label, fs, tcol)
	sc.shard_icon(Vector2(x0 + lw + 17, br.get_center().y), 12)


# ---------- Силуэты ----------

func _draw_sil() -> void:
	var sc = _sc()
	for q in _sil_q:
		var slot: String = q[0]
		var id: String = q[1]
		if slot == "hero":
			# 0.12b: главная цель — силуэт героя целиком в супер-эксклюзиве
			sc.hero.draw(sil, kind(), q[2], q[3], g.meta.look(kind()).merged({"aura": id}), 0.0)
		else:
			sc.hero.draw_item_icon(sil, id, slot, kind(), q[2], q[3], 0.0, _gen())
		sil.draw_set_transform(Vector2.ZERO)


func _draw_top() -> void:
	for q in _top_q:
		var c: Vector2 = q[1]
		var s: int = q[2]
		var pulse := 0.85 + 0.15 * sin(g.t_total * 3.0)
		top.draw_circle(c, s * 0.48, Color(0.1, 0.06, 0.22, 0.85), true, -1.0, true)
		top.draw_arc(c, s * 0.48, 0, TAU, 24, Color("#B9A4FF", 0.8), 2.0, true)
		top.draw_string(g.font, c + Vector2(-s, s * 0.34), "?", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.9 * pulse), Color("#E8DDFF"))


# ---------- Касания ----------

func tap(pos: Vector2) -> void:
	if anim_id != "":
		anim_t = ANIM_TIME  # касание пропускает анимацию
		_to_result()
		return
	if result:
		if rects.get("great", Rect2()).has_point(pos) or result_t > 0.8:
			_finish()
		return
	if try_id != "":
		try_id = ""
		g.play("click", 0.9)
		return
	if rects.get("back", Rect2()).has_point(pos):
		back()
		return
	if rects.get("master", Rect2()).has_point(pos):
		react = 0.0
		g.play("crystal", 0.8, -6.0)
		_sc().say(_master_line())
		return
	var sets := Meta.hero_sets(kind())
	for n in [0] + sets:
		var rid: String = Meta.super_recipe(kind()).id if n == 0 else Meta.recipe_for_set(n).id
		if rects.get("forge_%d" % n, Rect2()).has_point(pos):
			_try_forge(rid, n)
			return
		if rects.get("try_%d" % n, Rect2()).has_point(pos):
			start_try(rid)
			return
		if rects.get("wear_%d" % n, Rect2()).has_point(pos):
			if g.meta.equip(rid):
				g._save()
				g.play("crystal")
				_sc().say(I18n.t("card_worn") + ": " + Meta.item_name(rid, kind(), _gen()))
			return
	var sup: String = Meta.super_recipe(kind()).id
	if rects.get("super_try", Rect2()).has_point(pos):
		if g.meta.forged.has(sup):
			g.meta.equip(sup)
			g._save()
			g.play("crystal")
		else:
			start_try(sup)
		return
	for n in sets:
		if rects.get("card_%d" % n, Rect2()).has_point(pos):
			var st: String = g.meta.forge_status(Meta.recipe_for_set(n).id, g.max_level)
			g.play("click", 0.8)
			if st == "hall":
				_sc().say(I18n.t("forge_hall_hint") % int(Meta.set_info(n).hall))
			elif st == "items":
				_sc().say(I18n.t("forge_need_items"))
			return


func start_try(rid: String) -> void:
	try_id = rid
	try_t = 0.0
	react = 0.0
	g.play("crystal", 1.25, -4.0)


func _try_forge(rid: String, n: int) -> void:
	var st: String = g.meta.forge_status(rid, g.max_level)
	match st:
		"ok":
			pass
		"poor":
			var need := int(Meta.recipe(rid).cost) - int(g.meta.shards)
			g.play("gameover", 1.3, -8.0)
			_sc().say(I18n.t("poor_n") % [need, I18n.forms("shards_gen_forms", need)])
			return
		"items":
			g.play("click", 0.7)
			_sc().say(I18n.t("forge_need_items"))
			return
		_:
			g.play("click", 0.7)
			return
	# откуда слетаются вещи: из ячеек карточки (или гнёзд легенд для Крыльев)
	anim_from.clear()
	var needs: Array = Meta.recipe(rid).needs
	for i in needs.size():
		var cr: Rect2 = rects.get("need_%d_%d" % [n, i], Rect2(Vector2(500 - 60 + i * 60, 398), Vector2.ZERO))
		anim_from.append(cr.get_center() if cr.size.x > 0 else cr.position)
	if g.meta.forge(rid, g.max_level) != "forged":
		return
	g._save()
	anim_id = rid
	anim_t = 0.0
	g.play("levelup", 0.9)


func _to_result() -> void:
	if anim_id == "":
		return
	result = true
	result_t = 0.0
	react = 0.0  # герой радуется: конёк делает сальто, крылья взмахивают
	g.play("crystal", 1.1)
	_sc().poke_hero()
	_spawn_confetti()
	_result_id = anim_id
	anim_id = ""


func _finish() -> void:
	anim_id = ""
	result = false
	g.play("click")


func _spawn_confetti() -> void:
	var cols := [Color("#FFD23C"), Color("#FF5FA8"), Color("#3FE0D0"), Color("#B46CFF"), Color("#C6F04A"), Color.WHITE]
	for i in 90:
		var ang := randf_range(-PI * 0.95, -PI * 0.05)
		var sp := randf_range(380, 900)
		confetti.append({"p": Vector2(360 + randf_range(-60, 60), 560), "v": Vector2(cos(ang), sin(ang)) * sp,
			"col": cols[i % cols.size()], "life": randf_range(1.6, 2.8), "rot": randf() * TAU, "spin": randf_range(-9, 9), "s": randf_range(6, 12)})


func _draw_confetti() -> void:
	for c in confetti:
		var a := clampf(c.life / 0.5, 0.0, 1.0)
		var d: Vector2 = Vector2(cos(c.rot), sin(c.rot)) * c.s
		var e := Vector2(-d.y, d.x) * 0.45
		g.draw_colored_polygon(PackedVector2Array([c.p - d - e, c.p + d - e, c.p + d + e, c.p - d + e]), Color(c.col, a))


# ---------- Анимация ковки ----------

## Кристальная наковальня (центр рабочей поверхности — c)
func _anvil(c: Vector2, glow: float) -> void:
	Rarity.soft_disc(g, c + Vector2(0, 10), 190, Color(0.6, 0.4, 1.0, 0.25 + 0.35 * glow))
	var base := PackedVector2Array([c + Vector2(-60, 120), c + Vector2(60, 120), c + Vector2(40, 70), c + Vector2(-40, 70)])
	g.draw_colored_polygon(base, Color("#3A2D5C"))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-28, 70), c + Vector2(28, 70), c + Vector2(18, 30), c + Vector2(-18, 30)]), Color("#4A3B6B"))
	var topp := PackedVector2Array([c + Vector2(-110, 0), c + Vector2(-60, -6), c + Vector2(90, -6), c + Vector2(118, 4), c + Vector2(90, 30), c + Vector2(-70, 30)])
	g.draw_colored_polygon(topp, Color("#7FE3FF"))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-110, 0), c + Vector2(-60, -6), c + Vector2(90, -6), c + Vector2(118, 4)]), Color("#D8FBFF"))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-70, 30), c + Vector2(90, 30), c + Vector2(80, 14), c + Vector2(-60, 14)]), Color("#3FA8D0"))
	var ol := topp.duplicate()
	ol.append(topp[0])
	g.draw_polyline(ol, Color("#1E5A7A"), 3.0, true)
	g.draw_line(c + Vector2(-40, 6), c + Vector2(40, 6), Color(1, 1, 1, 0.6), 3.0, true)


func _draw_anim() -> void:
	var sc = _sc()
	var H: float = g.H
	var t := anim_t
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.03, 0.015, 0.08, 0.92))
	var c := Vector2(360, H * 0.5 + 40)
	var rar := Meta.rarity(_anim_or_result())
	var rcol := Rarity.col(rar) if rar != "super" else Color.from_hsv(fposmod(g.t_total * 0.4, 1.0), 0.6, 1.0)
	var glow := clampf((t - 0.8) / 1.2, 0.0, 1.0)
	_anvil(c + Vector2(0, 40), glow)
	var spot := c + Vector2(0, -30)
	var needs: Array = Meta.recipe(anim_id).needs
	var n := needs.size()
	# 1) вещи слетаются (0..0.8), 2) кружатся и сходятся (0.8..1.7)
	if t < 1.7:
		for i in n:
			var from: Vector2 = anim_from[i] if i < anim_from.size() else Vector2(360, 300)
			var ang := i * TAU / n + maxf(0.0, t - 0.8) * 7.0
			var orbit_r := 120.0 * (1.0 - smoothstep(0.8, 1.7, t))
			var orbit := spot + Vector2(cos(ang), sin(ang) * 0.45) * orbit_r
			var k := smoothstep(0.0, 0.8, t)
			var p := from.lerp(orbit, k) + Vector2(0, -sin(k * PI) * 120.0)
			var s := 70.0 * (1.0 - smoothstep(1.2, 1.7, t) * 0.7)
			g.draw_circle(p, s * 0.55, Color(rcol, 0.25), true, -1.0, true)
			var it: Dictionary = Meta.item(needs[i])
			sc.hero.draw_item_icon(g, needs[i], it.slot, kind(), p, s, g.t_total, _gen())
			g.draw_set_transform(Vector2.ZERO)
	# 3) светящийся кристалл (1.5..2.6), трещины (2.2..2.6)
	if t > 1.5 and t < 2.65:
		var k := smoothstep(1.5, 1.9, t)
		var r := 46.0 * k
		var pulse := 0.5 + 0.5 * sin(t * 18.0)
		Rarity.soft_disc(g, spot, r * 3.0, Color(rcol, 0.45 + 0.2 * pulse))
		var cr := PackedVector2Array([spot + Vector2(0, -r * 1.4), spot + Vector2(r * 0.8, -r * 0.2), spot + Vector2(0, r * 1.1), spot + Vector2(-r * 0.8, -r * 0.2)])
		g.draw_colored_polygon(cr, rcol.lerp(Color.WHITE, 0.35))
		g.draw_colored_polygon(PackedVector2Array([cr[0], cr[1], spot + Vector2(0, -r * 0.1)]), Color(1, 1, 1, 0.7))
		g.draw_colored_polygon(PackedVector2Array([spot + Vector2(0, -r * 0.1), cr[1], cr[2]]), Color(rcol.darkened(0.2), 0.8))
		if t > 2.2:
			var ck := smoothstep(2.2, 2.6, t)
			for j in 6:
				var a := j * TAU / 6.0 + 0.4
				var pts := PackedVector2Array([spot])
				var q := spot
				for m in 3:
					q += Vector2(cos(a + (m % 2) * 0.5 - 0.25), sin(a + (m % 2) * 0.5 - 0.25)) * r * 0.45 * ck
					pts.append(q)
				g.draw_polyline(pts, Color(1, 1, 1, 0.95), 3.0, true)
		Rarity.star4(g, spot + Vector2(-r * 0.3, -r * 0.6), 14.0 * pulse * k, Color.WHITE)
	# 4) вспышка цветом редкости (2.6..2.9)
	if t > 2.55 and t < 3.0:
		var f := 1.0 - absf(t - 2.7) / 0.3
		g.draw_rect(Rect2(0, 0, g.W, H), Color(rcol.lerp(Color.WHITE, 0.5), 0.75 * clampf(f, 0.0, 1.0)))
		for j in 12:
			var a := j * TAU / 12.0
			g.draw_line(spot, spot + Vector2(cos(a), sin(a)) * 400.0 * (t - 2.55) / 0.45, Color(1, 1, 1, 0.6 * clampf(f, 0.0, 1.0)), 6.0, true)
	# 5) награда выплывает в рамке (2.7..3.2)
	if t > 2.7:
		var k := smoothstep(2.7, 3.2, t)
		_reward_frame(spot + Vector2(0, -60 * k), 170.0 * (0.6 + 0.4 * k), _anim_or_result())
	sc._ctext(g.W / 2.0, H - 60, I18n.t("forge_skip"), 22, Color(g.DIM, 0.8))


func _anim_or_result() -> String:
	return anim_id if anim_id != "" else _result_id


## Награда в рамке редкости
func _reward_frame(c: Vector2, s: float, rid: String) -> void:
	var sc = _sc()
	var rar := Meta.rarity(rid)
	var r := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	g._rbox(r, Color("#24173F"), 28)
	Rarity.frame(g, r, rar, g.t_total, 28.0)
	var it: Dictionary = Meta.item(rid)
	sc.hero.draw_item_icon(g, rid, it.slot, kind(), c, s * 0.8, g.t_total, _gen())
	g.draw_set_transform(Vector2.ZERO)
	Rarity.icon_fx(g, rar, c, s * 0.8, g.t_total, 1.0, r.grow(-6))


## После ковки: герой сразу в награде, конфетти, кнопка «Ура!»
func _draw_result() -> void:
	var sc = _sc()
	var H: float = g.H
	var rid := _result_id
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.03, 0.015, 0.08, 0.92))
	var rar := Meta.rarity(rid)
	var rcol := Rarity.col(rar) if rar != "super" else Color.from_hsv(fposmod(g.t_total * 0.2, 1.0), 0.5, 1.0)
	var y0 := H * 0.5 - 520.0
	Rarity.soft_disc(g, Vector2(360, y0 + 450), 330, Color(rcol, 0.4))
	var hero_sc := 1.2 if not Meta.item(rid).has("covers") else 1.0
	sc.hero.draw(g, kind(), Vector2(360, y0 + 480), hero_sc, g.meta.outfit(), g.t_total, react)
	var title := I18n.t("forge_got") % Meta.item_name(rid, kind(), _gen())
	sc._shadow_text(g.W / 2.0, y0 + 140, title, sc.fit_size(title, 660, 44), g.TEXT, 700)
	var rn := Meta.rarity_name(rar)
	var w: float = g.font.get_string_size(rn, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 50
	var pr := Rect2(360 - w / 2.0, y0 + 168, w, 44)
	sc._pill(pr, Color(0.08, 0.04, 0.16, 0.9))
	g.draw_polyline(sc._rr_outline(pr, 22), rcol, 3.0, true)
	sc._ctext(360, y0 + 200, rn, 26, rcol, w)
	sc._ctext(360, y0 + 770, I18n.t("forge_keep"), 24, g.DIM)
	sc._button("great", Rect2(160, y0 + 810, 400, 110), I18n.t("forge_great"), true, 46)
	rects["great"] = sc.rects["great"]


## Примерка нескованной награды на 5 секунд
func _draw_try() -> void:
	var sc = _sc()
	var H: float = g.H
	g.draw_rect(Rect2(0, 0, g.W, H), Color(0.03, 0.015, 0.08, 0.92))
	var y0 := H * 0.5 - 480.0
	var it: Dictionary = Meta.item(try_id)
	var o: Dictionary = g.meta.outfit()
	Meta.put_on(o, try_id)
	var rar := Meta.rarity(try_id)
	var rcol := Rarity.col(rar)
	Rarity.soft_disc(g, Vector2(360, y0 + 450), 330, Color(rcol, 0.35))
	sc.hero.draw(g, kind(), Vector2(360, y0 + 470), 1.2 if not it.has("covers") else 1.0, o, g.t_total, react)
	var nm := Meta.item_name(try_id, kind(), _gen())
	sc._shadow_text(g.W / 2.0, y0 + 110, nm, sc.fit_size(nm, 660, 46), rcol.lerp(Color.WHITE, 0.3), 700)
	var left := ceili(TRY_TIME - try_t)
	var lbl := I18n.t("forge_try_left") % left
	sc._badge(Vector2(360, y0 + 136), lbl, 24)
	var bar := Rect2(160, y0 + 790, 400, 12)
	g._rbox(bar, Color(1, 1, 1, 0.15), 6)
	g._rbox(Rect2(bar.position, Vector2(bar.size.x * clampf(1.0 - try_t / TRY_TIME, 0.0, 1.0), bar.size.y)), g.ACCENT, 6)
	sc._ctext(360, y0 + 850, I18n.t("tut_tap"), 24, g.DIM)


# ---------- Кнопка входа на главном экране и в гардеробе ----------

## Значок наковальни (центр c, размер s)
func anvil_icon(c: Vector2, s: float) -> void:
	var k := s / 40.0
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -6) * k, c + Vector2(-12, -10) * k, c + Vector2(18, -10) * k, c + Vector2(24, -6) * k, c + Vector2(16, 2) * k, c + Vector2(-14, 2) * k]), Color("#9FF6FF"))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -6) * k, c + Vector2(-12, -10) * k, c + Vector2(18, -10) * k, c + Vector2(24, -6) * k]), Color("#E8FDFF"))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 2) * k, c + Vector2(6, 2) * k, c + Vector2(8, 10) * k, c + Vector2(-8, 10) * k]), Color("#6E5C96"))
	g.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 10) * k, c + Vector2(14, 10) * k, c + Vector2(16, 16) * k, c + Vector2(-16, 16) * k]), Color("#8A78B4"))
	Rarity.star4(g, c + Vector2(12, -18) * k, 6 * k * (0.7 + 0.3 * sin(g.t_total * 4.0)), Color("#FFE27A"))


## Кнопка «Кузница» на главном экране (справа под счётчиками). Метка «Можно сковать!» — когда готово.
func draw_home_button() -> void:
	var sc = _sc()
	var r := Rect2(g.W - 128, 118, 108, 108)
	sc.rects["forge"] = r
	var ready: bool = g.meta.forge_ready_any(g.max_level)
	if ready:
		var pulse := 0.5 + 0.5 * sin(g.t_total * 5.0)
		g._rbox(r.grow(5 + 3 * pulse), Color(g.ACCENT, 0.3), 34)
	g._rbox(r, Color(0.1, 0.06, 0.2, 0.85), 30)
	g.draw_polyline(sc._rr_outline(r.grow(-1), 29), Color("#9FF6FF", 0.5), 2.0, true)
	anvil_icon(r.get_center() + Vector2(0, -10), 46)
	var lbl := I18n.t("forge")
	sc._ctext(r.get_center().x, r.end.y - 12, lbl, sc.fit_size(lbl, r.size.x - 8, 20), g.TEXT, r.size.x)
	if ready:
		sc._badge(Vector2(r.get_center().x - 40, r.end.y + 4), I18n.t("forge_can"), 16)


func tap_home_button(pos: Vector2) -> bool:
	if not _sc().rects.get("forge", Rect2()).has_point(pos):
		return false
	g.play("click")
	open()
	return true
