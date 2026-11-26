extends RefCounted
## Версия 0.17: экскурсия по главному экрану («Дом»).
## В стиле обучения (scripts/tutorial.gd): затемнение с «окном» на кнопке, рука-указатель,
## одна короткая фраза; касание — следующий шаг, кнопка «Пропустить» в углу (напротив окна).
## Когда: первый раз на главном экране после первой победы (max_level > 1), один раз.
## Старые игроки с прогрессом (в save.cfg нет [tour]) тоже видят её один раз — можно пропустить.
## Пройдена или пропущена — флаг [tour] done = true в user://save.cfg.
## Повтор: пункт паузы «Обучение» (replay()) — экскурсия покажется при следующем возвращении домой.
## Пока экскурсия на экране, касания не доходят ни до кнопок, ни до камеры 3D-дома (game.gd).

const I18n := preload("res://scripts/i18n.gd")
const Tutorial := preload("res://scripts/tutorial.gd")

## Шаги: id — ключ прямоугольника в Screens.home_layout(), текст — "tour_<id>".
const STEPS := ["shards", "wardrobe", "decorate", "forge", "map", "trophies", "avatar", "lang", "play"]
const MIN_T := 0.35   # касание раньше — случайное, не листает
const START_DELAY := 0.7  # секунд на главном экране до начала (затухание перехода)
const HAND_LEN := 128.0   # длина руки-указателя от кончика пальца
const GAP := 150.0        # от окна до облачка (между ними рука)
const HALF := 640.0       # верх / низ экрана (кнопки сверху и снизу 1280 px главного экрана)

var enabled := true
var done := false
var step := -1        # номер шага на экране (-1 — экскурсии нет)
var t := 0.0          # секунд на экране текущего шага
var opened_t := 0.0   # секунд с начала экскурсии (появление затемнения)


func active() -> bool:
	return step >= 0


func cur_id() -> String:
	return STEPS[step] if active() else ""


## Пора ли начать: главный экран, ничего другого не открыто, первая победа уже была.
func should_start(g) -> bool:
	if not enabled or done or active() or not g.tut.enabled:
		return false
	if g.state != g.State.HOME or g.max_level <= 1 or g.meta.hero == "" or g.state_time < START_DELAY:
		return false
	if g.decor_ui and g.decor_ui.active:
		return false
	if g.notice_ui and (g.notice_ui.active() or g.notice_ui.hint_showing()):
		return false
	if g.trophy_ui and g.trophy_ui.panel_open:
		return false
	if g.home3d and g.home3d.showing() and g.home3d.revealing():
		return false  # сначала — показ нового кубка на полке
	if not g.meta.trophies_pending(g.max_level).is_empty() and g.state_time < 8.0:
		return false  # новый кубок ещё не показан — дать показу начаться
	return true


func update(g, delta: float) -> void:
	if active():
		if g.state != g.State.HOME:
			step = -1  # ушли с главного экрана (не по касанию) — начнётся заново в следующий раз
			return
		t += delta
		opened_t += delta
	elif should_start(g):
		start()


func start() -> void:
	step = 0
	t = 0.0
	opened_t = 0.0


## Касание во время экскурсии. Всегда «съедается» (не доходит до кнопок и 3D-камеры).
func tap(g, pos: Vector2) -> bool:
	if not active():
		return false
	if skip_rect(g).has_point(pos):
		g.play("click")
		finish(g)
		return true
	if t < MIN_T:
		return true
	if step >= STEPS.size() - 1:
		var on_play: bool = target(g, "play").has_point(pos)
		finish(g)
		if on_play:
			g.play("click")
			g.start_level(g.max_level)  # последний шаг — «Играть»: касание по кнопке сразу начинает уровень
		return true
	g.play("click")
	step += 1
	t = 0.0
	return true


## Пропустить / закончить: больше не показывать.
func finish(g) -> void:
	step = -1
	done = true
	g._save()


## Кнопка «Назад» телефона — пропустить экскурсию.
func back(g) -> bool:
	if not active():
		return false
	finish(g)
	return true


## Повтор (пункт паузы «Обучение»): покажется при следующем возвращении домой.
func replay() -> void:
	done = false
	step = -1


# ---------- Сохранение: [tour] done ----------

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tour", "done", done)


## Нет раздела (новый игрок или старое сохранение) — экскурсия ещё впереди.
func load_from(cfg: ConfigFile) -> void:
	step = -1
	var v = cfg.get_value("tour", "done", false)
	done = v is bool and v


# ---------- Где что на экране ----------

## Окно шага на экране (с небольшим запасом вокруг кнопки).
func target(g, id: String) -> Rect2:
	var L: Dictionary = g.screens.home_layout()
	var r: Rect2 = L.get(id, Rect2())
	if r.size.x <= 0:
		return Rect2()
	return r.grow(8)


## «Пропустить» — в углу напротив окна шага (окно сверху — внизу справа, и наоборот).
func skip_rect(g) -> Rect2:
	var w := 200.0
	var h := 66.0
	var r := target(g, cur_id()) if active() else Rect2()
	var skip_on_top: bool = r.size.y > 0 and not hand_up(r)
	# сверху — в самом углу; снизу — над нижней полосой кнопок
	var y: float = 30.0 if skip_on_top else g.H - 140.0 - h - 22.0
	return Rect2(g.W - w - 20.0, y, w, h)


## Рука указывает на край кнопки снаружи и не закрывает ни значок, ни подпись:
## кнопка в верхней половине — рука снизу (палец вверх), в нижней — сверху (палец вниз).
func hand_up(r: Rect2) -> bool:
	return r.get_center().y < HALF


func hand_point(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.end.y + 2.0) if hand_up(r) else Vector2(r.get_center().x, r.position.y - 2.0)


## Примерный прямоугольник руки (для проверок: не закрывает окно и облачко).
func hand_box(r: Rect2) -> Rect2:
	var p := hand_point(r)
	return Rect2(p.x - 60.0, p.y, 120.0, HAND_LEN) if hand_up(r) else Rect2(p.x - 60.0, p.y - HAND_LEN, 120.0, HAND_LEN)


## Облачко: под окном (окно в верхней половине; ниже руки) или над ним.
func bubble_rect(g, r: Rect2, text: String) -> Rect2:
	var w := 640.0
	var th: float = g.font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w - 60.0, 34).y
	var h := th + 100.0
	var y: float
	if hand_up(r):
		y = r.end.y + GAP
	else:
		y = r.position.y - h - GAP
	y = clampf(y, 24.0, g.H - h - 24.0)
	return Rect2((g.W - w) / 2.0, y, w, h)


# ---------- Рисование ----------

func draw(g) -> void:
	if not active():
		return
	var id := cur_id()
	var r := target(g, id)
	var a := clampf(opened_t / 0.3, 0.0, 1.0)
	Tutorial.dim(g, [r], 0.72 * a)
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	g.draw_rect(r, Color(g.ACCENT, (0.45 + 0.45 * pulse) * a), false, 4.0)
	# облачко с фразой, точки шагов и «Нажми, чтобы продолжить»
	var text := I18n.t("tour_" + id)
	var b := bubble_rect(g, r, text)
	g._rbox(b.grow(5), Color(g.ACCENT, 0.35 * a), 34)
	g._rbox(b, Color(0.16, 0.09, 0.3, 0.97 * a), 30)
	var th: float = g.font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, b.size.x - 60.0, 34).y
	g.draw_multiline_string(g.font, Vector2(b.position.x + 30, b.position.y + 50), text, HORIZONTAL_ALIGNMENT_CENTER, b.size.x - 60.0, 34, -1, Color(g.TEXT, a))
	var fy := b.position.y + 24.0 + th + 34.0
	var n := STEPS.size()
	for i in n:
		var c := Vector2(b.position.x + 44 + i * 20, fy - 7)
		g.draw_circle(c, 6.0 if i == step else 4.5, Color(g.ACCENT, a) if i <= step else Color(1, 1, 1, 0.25 * a), true, -1.0, true)
	var sub := I18n.t("tour_end" if step == n - 1 else "tour_next")
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
	g.draw_string(g.font, Vector2(b.position.x + 44 + n * 20, fy), sub, HORIZONTAL_ALIGNMENT_RIGHT, b.end.x - 30 - (b.position.x + 44 + n * 20), 22, Color(g.DIM, a * blink))
	# рука нажимает на кнопку
	var at := hand_point(r)
	var k := fmod(t, 1.1) / 1.1
	var press := clampf(1.0 - absf(k - 0.3) / 0.15, 0.0, 1.0)
	if k > 0.3:
		var rk := (k - 0.3) / 0.7
		g.draw_arc(at, 14 + 46 * rk, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - rk) * a), 4.0, true)
	Tutorial.hand(g, at, press, 0.0 if hand_up(r) else PI)
	# «Пропустить»
	var s := skip_rect(g)
	g._rbox(s, Color(0.1, 0.06, 0.2, 0.92 * a), 33)
	g.draw_polyline(g.screens._rr_outline(s.grow(-1), 32), Color(1, 1, 1, 0.35 * a), 2.0, true)
	var lbl := I18n.t("tour_skip")
	var fs: int = g.screens.fit_size(lbl, s.size.x - 24, 28)
	g.draw_string(g.font, Vector2(s.position.x, s.get_center().y + fs * 0.36), lbl, HORIZONTAL_ALIGNMENT_CENTER, s.size.x, fs, Color(g.TEXT, a))
