extends Node
## 3D-дом на экране «Дом» и в гардеробе (вкладка «Дом») — Cascado 0.12.
## Отдельный мир 3D рисуется в SubViewport; его картинка рисуется на экране игры (game.gd) первой,
## а кнопки, счётчики и надписи — поверх, как раньше.
##
## Жизненный цикл (по состоянию игры):
##   заставка — дом строится заранее и пару кадров рисуется невидимо: «прогрев» шейдеров;
##   «Дом» — рисуется на весь экран; гардероб, вкладка «Дом» — в окне сцены, камера у выбранного места;
##   карта, гардероб (другие вкладки), выбор героя — дом стоит на паузе (не рисуется, не считается);
##   уровень (игра, пауза, победа, поражение) — 3D полностью освобождается.
## Качество: "high" (тени, сияние, сглаживание MSAA ×4, полное разрешение),
##   "simple" (без теней и сияния, без MSAA, картинка 0,75), "2d" — прежний 2D-дом (scripts/home.gd).
## Если 3D недоступно (нет видеокарты, сервер без экрана) — 2D-дом. Если игра дважды подряд закрылась
## аварийно в первую секунду показа 3D-дома («предохранитель»), включается «Графика: 2D» — игрок может
## вернуть 3D в паузе.

const Meta := preload("res://scripts/meta.gd")
const ROOMS := {
	"owl": preload("res://scripts/home3d/room_owl.gd"),
	"axolotl": preload("res://scripts/home3d/room_axolotl.gd"),
	"puppy": preload("res://scripts/home3d/room_puppy.gd"),
	"kitten": preload("res://scripts/home3d/room_kitten.gd"),
}
const QUALITIES := ["high", "simple", "2d"]
const SIMPLE_SCALE := 0.75
## Ниже этого среднего FPS в первые секунды показа дома — автоматически «простое» качество
const AUTO_FPS := 40.0
const GUARD_PATH := "user://home3d_guard.cfg"
## Сколько секунд после касания места камера летит к нему, прежде чем открыть гардероб
const OPEN_DELAY := 0.5

## Для тестов: строить 3D даже без экрана (headless)
static var force := false

var g                       # узел игры (scripts/game.gd)
var vp: SubViewport
var room                    # scripts/home3d/room_*.gd
var mode := "off"           # off / prewarm / home / stage / idle
var kind := ""
var stage := -1
var quality := "high"
var quality_manual := false
var unavailable := false    # 3D нельзя: всегда 2D
var fade := 0.0             # затемнение при смене дома (1 — темно)
var builds := 0             # сколько раз строился дом (для тестов и замеров)
var last_build_ms := 0.0

var _pending_spot := ""
## 0.14: при возврате из гардероба на экран «Дом» камера летит к этому месту (новое украшение), а не к герою
var show_spot := ""
var _pending_t := 0.0
var _stage_spot := ""
var _auto_done := false
var _fps_time := 0.0
var _fps_frames := 0
var _home_time := 0.0
var _frames_ok := 0
var _guard_armed := false
var _prewarm_frames := 0


var _guard_tripped := false


func setup(game) -> void:
	g = game
	unavailable = not _available()
	if not unavailable and not force:
		var cfg := ConfigFile.new()
		_guard_tripped = cfg.load(GUARD_PATH) == OK and int(cfg.get_value("guard", "fails", 0)) >= 2


func _available() -> bool:
	if force:
		return true
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_driver_name() in ["", "dummy"]:
		return false
	return true


## «Предохранитель»: started — 3D начинает показываться (+1 к счётчику), иначе — всё хорошо (сброс)
func _guard(started: bool) -> void:
	if force:
		return
	var cfg := ConfigFile.new()
	cfg.load(GUARD_PATH)
	var fails := int(cfg.get_value("guard", "fails", 0))
	cfg.set_value("guard", "fails", fails + 1 if started else 0)
	cfg.save(GUARD_PATH)


## Игрок сам закрыл или свернул игру в первую секунду — это не авария
func _notification(what: int) -> void:
	if _guard_armed and what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]:
		_guard_armed = false
		_guard(false)


# ---------- Настройка качества (сохраняется в save.cfg, раздел [settings]) ----------

func load_from(cfg: ConfigFile) -> void:
	var q = cfg.get_value("settings", "graphics", "high")
	quality = q if q is String and QUALITIES.has(q) else "high"
	quality_manual = bool(cfg.get_value("settings", "graphics_manual", false))
	if _guard_tripped:
		# 3D дважды подряд не пережило первую секунду — безопасный 2D-дом (вернуть 3D можно в паузе)
		_guard_tripped = false
		quality = "2d"
		_guard(false)


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("settings", "graphics", quality)
	cfg.set_value("settings", "graphics_manual", quality_manual)


## Кнопка в паузе: высокое -> простое -> 2D -> высокое
func cycle_quality() -> String:
	var i := QUALITIES.find(quality)
	set_quality(QUALITIES[(i + 1) % QUALITIES.size()], true)
	return quality


func set_quality(q: String, manual := false) -> void:
	if not QUALITIES.has(q):
		return
	quality = q
	if manual:
		quality_manual = true
	if q == "2d":
		_free()
		return
	if room:
		room.set_quality(q == "high")
		_apply_viewport()


func is_3d() -> bool:
	return not unavailable and quality != "2d"


# ---------- Что показываем ----------

## Дом в 3D на весь экран «Дом» (иначе — 2D-дом)
func showing() -> bool:
	return is_3d() and room != null and mode == "home"


## Дом в 3D в окне гардероба (вкладка «Дом»)
func showing_stage() -> bool:
	return is_3d() and room != null and mode == "stage"


func _wanted() -> String:
	if not is_3d() or g == null:
		return "off"
	var S = g.State
	match g.state:
		S.SPLASH:
			return "prewarm" if g.meta.hero != "" else "off"
		S.HOME:
			return "home" if g.meta.hero != "" else "off"
		S.WARDROBE:
			return "stage" if g.screens.tab == "home" else "idle"
		S.MAP, S.PICK_HERO:
			return "idle" if room != null else "off"
	return "off"


func _process(delta: float) -> void:
	if g == null:
		return
	var want := _wanted()
	if want == "off":
		if room != null:
			_free()
		mode = "off"
		return
	if want == "idle":
		if room != null:
			_pause(true)
		mode = "idle"
		return
	var k: String = g.meta.hero
	var st: int = Meta.home_stage(g.max_level)
	var prev := mode
	if room == null or k != kind or st != stage:
		_build(k, st)
		if want != "prewarm":
			# смена дома / вход после уровня: из темноты, камера плавно влетает
			fade = 1.0
			room.cam.intro()
	elif prev == "prewarm" and want == "home":
		fade = 0.7
		room.cam.intro()
	mode = want
	_pause(false)
	_apply_viewport()
	_sync(delta)
	fade = maxf(0.0, fade - delta * 2.2)
	if mode == "prewarm":
		_prewarm_frames += 1
	if mode == "home":
		_watch_fps(delta)
	# предохранитель: дом показан и прожил секунду — значит, 3D на этом телефоне работает
	if mode in ["home", "stage"]:
		_frames_ok += 1
		if _guard_armed and _frames_ok > 45:
			_guard_armed = false
			_guard(false)


func _build(k: String, st: int) -> void:
	_free()
	if not ROOMS.has(k):
		return
	if not _guard_armed and builds == 0:
		_guard_armed = true
		_guard(true)
	var t0 := Time.get_ticks_usec()
	vp = SubViewport.new()
	vp.name = "Home3DViewport"
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.gui_disable_input = true
	vp.handle_input_locally = false
	vp.audio_listener_enable_3d = false
	add_child(vp)
	room = ROOMS[k].new()
	room.setup(k, st, g.meta.decor_placed.get(k, {}), g.meta.outfit(), quality == "high")
	vp.add_child(room)
	room.build()
	room.cam.tapped.connect(_on_tap)
	room.cam.double_tapped.connect(_on_double_tap)
	kind = k
	stage = st
	builds += 1
	_stage_spot = ""
	_pending_spot = ""
	_home_time = 0.0
	_frames_ok = 0
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_apply_viewport()


func _free() -> void:
	if vp != null:
		remove_child(vp)
		vp.queue_free()
	vp = null
	room = null
	kind = ""
	stage = -1
	if mode != "off":
		mode = "off"


func _pause(on: bool) -> void:
	if vp == null:
		return
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS
	room.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		room.cam.release_all()


## Размер картинки, сглаживание — по качеству и месту показа
func _apply_viewport() -> void:
	if vp == null:
		return
	var r := target_rect()
	var k := 1.0 if quality == "high" else SIMPLE_SCALE
	var sz := Vector2i(maxi(64, int(r.size.x * k)), maxi(64, int(r.size.y * k)))
	if vp.size != sz:
		vp.size = sz
	vp.msaa_3d = Viewport.MSAA_4X if quality == "high" else Viewport.MSAA_DISABLED
	room.cam.px_scale = float(sz.x) / maxf(1.0, r.size.x)
	# на весь экран интерфейс закрывает верх и низ: опускаем «горизонт», чтобы герой был в середине видимой части
	room.cam.v_offset = -0.42 if mode != "stage" else 0.0


## Где на экране игры картинка 3D
func target_rect() -> Rect2:
	if mode == "stage" and g.screens.has_method("_wr_layout"):
		return g.screens._wr_layout().stage
	return Rect2(0, 0, g.W, g.H)


## Украшения, наряд, метки и кольцо примерки — каждый кадр (дёшево: меняется только то, что изменилось)
func _sync(delta: float) -> void:
	var sc = g.screens
	if mode == "stage":
		room.set_placed(sc.tryon.placed(g.meta, kind))
		if room.highlight != sc.spot:
			room.set_highlight(sc.spot)
		if _stage_spot != sc.spot:
			_stage_spot = sc.spot
			room.focus_spot(sc.spot)
		room.cam.idle_sway = 0.12
	else:
		room.set_placed(g.meta.decor_placed.get(kind, {}))
		if room.highlight != "":
			room.set_highlight("")
		if show_spot != "" and mode == "home":
			room.focus_spot(show_spot)
			show_spot = ""
			_stage_spot = ""
		elif _stage_spot != "":
			_stage_spot = ""
			if _pending_spot == "":
				room.cam.fly_home()
		room.cam.idle_sway = 0.0
	room.set_markers(true)
	room.set_outfit(g.meta.outfit())
	if _pending_spot != "":
		_pending_t -= delta
		if _pending_t <= 0.0:
			var s := _pending_spot
			_pending_spot = ""
			if mode == "home":
				g.play("click")
				sc.spot = s
				sc.open_wardrobe("home")


# ---------- Рисование ----------

func draw(ci: CanvasItem, r: Rect2) -> void:
	if vp == null:
		return
	ci.draw_texture_rect(vp.get_texture(), r, false)
	if fade > 0.0:
		ci.draw_rect(r, Color(0.05, 0.03, 0.1, fade))


## Где место украшения на экране игры (для касаний в гардеробе); за камерой — (-1, -1)
func spot_screen(spot: String) -> Vector2:
	if room == null or vp == null:
		return Vector2(-1, -1)
	var p: Vector2 = room.spot_screen(spot)
	if p.x < 0.0:
		return p
	var r := target_rect()
	var q := r.position + p * r.size / Vector2(vp.size)
	if not r.has_point(q):
		return Vector2(-1, -1)
	return q


# ---------- Касания (только на экране «Дом», мимо кнопок) ----------

func _to_vp(pos: Vector2) -> Vector2:
	var r := target_rect()
	return (pos - r.position) * Vector2(vp.size) / r.size


func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	if room == null or vp == null:
		return
	if pressed:
		if not showing():
			return
		# новое касание отменяет отложенное открытие гардероба (второй тап двойного — это «подлёт»)
		_pending_spot = ""
	room.cam.touch(idx, _to_vp(pos), pressed)


func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not showing():
		return
	var k := float(vp.size.x) / target_rect().size.x
	room.cam.drag(idx, _to_vp(pos), rel * k)


func _on_tap(p: Vector2) -> void:
	if mode != "home":
		return
	var c: Dictionary = room.pick(p, 110.0 * room.cam.px_scale)
	if c.is_empty():
		return
	if c.type == "hero":
		room.poke_hero()
		g.play("crystal", randf_range(0.9, 1.15), -6.0)
	elif c.type == "spot":
		# камера подлетает к месту, потом открывается выбор украшения (вкладка «Дом» гардероба)
		room.focus_spot(c.spot)
		_pending_spot = c.spot
		_pending_t = OPEN_DELAY


func _on_double_tap(p: Vector2) -> void:
	if mode != "home":
		return
	_pending_spot = ""
	var c: Dictionary = room.pick(p, 130.0 * room.cam.px_scale)
	if c.is_empty() or room.is_focused_on(c.at) or (c.get("spot", "") != "" and room.cam.focused and room.cam.goal_pivot.distance_to(room.spot_focus.get(c.spot, [c.at])[0]) < 0.05):
		room.cam.fly_home()
		return
	room.focus(c)


# ---------- Автовыбор качества по FPS ----------

func _watch_fps(delta: float) -> void:
	_home_time += delta
	if _auto_done or quality_manual or quality != "high":
		return
	# первая секунда — не считаем (строится, грузится)
	if _home_time < 1.0:
		return
	_fps_time += delta
	_fps_frames += 1
	if _fps_time >= 2.5:
		_auto_done = true
		var fps := _fps_frames / _fps_time
		if fps < AUTO_FPS:
			set_quality("simple")
			if g.has_method("_save"):
				g._save()


## Для тестов и замеров
func debug_info() -> Dictionary:
	return {"mode": mode, "kind": kind, "stage": stage, "built": room != null, "builds": builds,
		"vp": vp.size if vp else Vector2i.ZERO, "quality": quality, "build_ms": last_build_ms}
