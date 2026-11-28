extends SceneTree
## Тесты 0.19: экран загрузки 3D-дома (жалоба закрытого теста: после выбора друга экран замирал на 5–10 с).
##   выбор друга -> «Вперёд»: сразу экран «Строим домик» (без тяжёлой работы в этом кадре), дом строится
##   по шагам (scripts/home3d/home_loader.gd) и прогревается группами материалов, переход заканчивается;
##   касания во время загрузки не нажимают невидимые кнопки, после загрузки кнопки работают;
##   смена качества — «Настраиваем графику» (только прогрев), смена друга в гардеробе — загрузка в окне сцены;
##   уход посреди загрузки — ничего не остаётся висеть; повторная постройка без прогрева;
##   общий шейдер у светящихся и обычных деталей (kit.mat); тексты экрана на en и ru.
## Запуск: godot --headless --path block_game -s tests/test_v019_loading.gd

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
const HomeLoader := preload("res://scripts/home3d/home_loader.gd")
const Kit := preload("res://scripts/home3d/kit.gd")
const SAVE := "user://save.cfg"


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE)
	save_bytes = FileAccess.get_file_as_bytes(SAVE) if had_save else PackedByteArray()
	if had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Home3D.force = true
	Home3D.stage_load = 1  # как на телефоне: по частям, с экраном загрузки
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Ждать, пока дом загрузится (не дольше max кадров); вернуть, сколько кадров шла загрузка
func _until_loaded(max_frames := 600) -> int:
	var n := 0
	while g.home3d.loader != null and n < max_frames:
		await process_frame
		n += 1
	return n


func _tap(p: Vector2) -> void:
	g._touch_down(0, p)
	g._touch_up(0, p)


func _run() -> void:
	await _frames(3)
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	_test_texts()
	_test_shared_shader()
	await _test_first_pick()
	await _test_quality_rewarm()
	await _test_rebuild_no_warm()
	await _test_cancel()
	await _test_wardrobe_switch()
	_finish()


func _test_texts() -> void:
	print("— тексты экрана загрузки")
	for l in ["en", "ru"]:
		for k in ["loading_home", "loading_gfx"]:
			check(I18n.has_in(l, k), "%s: есть строка %s" % [l, k])
	I18n.set_lang("en")
	check(I18n.t("loading_home") == "Building your home", "en: «Building your home»")
	I18n.set_lang("ru")
	check(I18n.t("loading_home") == "Строим домик", "ru: «Строим домик»")


func _test_shared_shader() -> void:
	print("— меньше шейдеров: светящиеся и обычные детали — один шейдер")
	var a := Kit.mat(Color(0.3, 0.5, 0.9))
	var b := Kit.mat(Color(1.0, 0.8, 0.2), 0.5, 2.5)
	var c := Kit.mat(Color(0.2, 0.9, 0.4), 0.85, 0.0, false)
	check(HomeLoader.mat_sig(a) == HomeLoader.mat_sig(b), "kit.mat без свечения и со свечением — одна подпись шейдера")
	check(a.emission == Color(0, 0, 0) and a.emission_energy_multiplier == 0.0, "у несветящегося свечение чёрное и ×0 (картинка не меняется)")
	check(HomeLoader.mat_sig(a) != HomeLoader.mat_sig(c), "с обводкой и без — разные (обводка — свой проход)")


func _test_first_pick() -> void:
	print("— первый запуск: выбор друга -> экран загрузки -> дом")
	check(g.meta.hero == "", "герой ещё не выбран")
	g.go_home()
	await _frames(2)
	check(g.state == g.State.PICK_HERO, "экран выбора друга")
	var hr: Rect2 = g.screens.rects.get("hero_puppy", Rect2())
	check(hr.has_area(), "карточка щенка на экране")
	_tap(hr.get_center())
	await _frames(2)
	var ok: Rect2 = g.screens.rects.get("ok", Rect2())
	check(ok.has_area(), "кнопка «Вперёд»")
	HomeLoader.warmed.clear()
	_tap(ok.get_center())
	check(g.state == g.State.HOME and g.meta.hero == "puppy", "после «Вперёд» — экран «Дом», выбран щенок")
	await process_frame
	var h = g.home3d
	check(h.loading() and h.loader != null, "сразу экран загрузки")
	check(h.loader.step_i == 0 and h.loader.vp == null, "в первом кадре тяжёлой работы нет (дом ещё не начат)")
	check(h.load_text_key() == "loading_home", "надпись «Строим домик»")
	check(not h.showing() and h.room == null, "дом пока не показан (недостроенный не рисуется)")
	await process_frame
	check(not g.screens.rects.has("play"), "во время загрузки кнопки главного экрана не рисуются")
	# касание туда, где будет «Играть», во время загрузки не запускает уровень
	var L: Dictionary = g.screens.home_layout()
	_tap(L.play.get_center())
	await process_frame
	check(g.state == g.State.HOME, "касание во время загрузки не нажимает «Играть»")
	var p0: float = h.load_progress()
	var seen_warm := false
	var mono := true
	var last := p0
	var n := 0
	while h.loader != null and n < 600:
		if h.loader.phase == "warm":
			seen_warm = true
		var p: float = h.load_progress()
		if p + 0.0001 < last:
			mono = false
		last = p
		if n == 5:
			check(g.state_time < 0.2, "пока грузится, время экрана «Дом» стоит")
		await process_frame
		n += 1
	check(h.loader == null, "загрузка закончилась (кадров: %d)" % n)
	check(n >= 4, "загрузка шла несколько кадров (по частям), а не одним")
	check(seen_warm, "был прогрев шейдеров")
	check(mono and p0 >= 0.0 and last <= 1.0, "полоска готовности растёт от 0 до 1")
	check(h.showing() and h.kind == "puppy" and h.room.built, "дом щенка показан")
	check(h.last_load.get("groups", 0) >= 3, "прогрев — несколько групп материалов (%d)" % h.last_load.get("groups", 0))
	check(h.room.cam.current, "камера дома снова главная (камеры прогрева нет)")
	check(h.room.find_children("warm_cam", "", true, false).is_empty(), "камера прогрева убрана")
	var ok_vis := true
	for spot in h.room.markers:
		if h.room.markers[spot].visible:
			ok_vis = false
	check(ok_vis and not h.room.ring.visible, "метки мест и кольцо снова скрыты (видимость вернулась)")
	check(h.vp.size == Vector2i(720, int(g.H)), "картинка дома — снова во весь экран")
	check(h.load_fade > 0.0, "экран загрузки плавно гаснет поверх дома")
	check(HomeLoader.is_warmed("puppy", h.stage, h.quality), "дом отмечен как прогретый")
	var w := 0
	while h.load_fade > 0.0 and w < 5000:
		await process_frame
		w += 1
	check(h.load_fade == 0.0, "и погас")
	check(g.screens.rects.has("play"), "кнопки главного экрана нарисованы")
	_tap(g.screens.rects["play"].get_center())
	check(g.state == g.State.PLAYING, "после загрузки касание «Играть» работает (ввод не потерян)")
	await _frames(2)
	check(h.room == null and h.loader == null, "во время уровня 3D освобождено")


func _test_quality_rewarm() -> void:
	print("— смена качества: «Настраиваем графику», дом не перестраивается")
	var h = g.home3d
	g.go_home()
	await process_frame
	await _until_loaded()
	check(h.showing(), "снова дома")
	var builds: int = h.builds
	h.set_quality("simple")
	check(h.loader != null and h.loader.rewarm, "другое качество — прогрев его шейдеров")
	await process_frame
	check(h.loading() and h.load_text_key() == "loading_gfx", "надпись «Настраиваем графику»")
	var n: int = await _until_loaded()
	check(h.loader == null and h.showing(), "прогрев закончился (кадров: %d), дом на экране" % n)
	check(h.builds == builds and h.room.built, "дом тот же (не перестраивался)")
	check(not h.room.high and h.vp.msaa_3d == Viewport.MSAA_DISABLED, "качество — простое")
	h.set_quality("simple")
	check(h.loader == null, "то же качество — ничего не делается")


func _test_rebuild_no_warm() -> void:
	print("— возврат с уровня: дом строится заново по частям, но без прогрева")
	var h = g.home3d
	g.start_level(1)
	await _frames(2)
	check(h.room == null, "на уровне 3D нет")
	g.go_home()
	await process_frame
	check(h.loading(), "экран загрузки (коротко)")
	var n: int = await _until_loaded()
	check(h.showing() and not h.last_load.get("warm", true), "дом показан без прогрева (кадров: %d)" % n)
	check(n < 20, "быстро — за несколько кадров")


func _test_cancel() -> void:
	print("— уход посреди загрузки")
	var h = g.home3d
	g.start_level(1)
	await _frames(2)
	g.go_home()
	await _frames(2)
	check(h.loader != null, "загрузка идёт")
	g.screens.open_map()
	await _frames(2)
	check(h.loader == null and h.room == null and h.get_child_count() == 0, "ушли на карту — загрузка отменена, ничего не висит")
	g.go_home()
	await process_frame
	await _until_loaded()
	check(h.showing() and h.kind == "puppy", "домой — дом построен")


func _test_wardrobe_switch() -> void:
	print("— смена друга в гардеробе: новый дом — с экраном загрузки")
	var h = g.home3d
	g.screens.open_wardrobe("head")
	await _frames(3)
	check(g.state == g.State.WARDROBE and h.mode == "idle", "гардероб: дом на паузе")
	g.screens.request_switch("kitten")
	if g.notice_ui.active():
		g.notice_ui.back()
	await _frames(2)
	check(h.loader == null and h.kind == "puppy", "в гардеробе новый дом не строится (не виден)")
	g.go_home()
	await process_frame
	check(h.loading() and h.loader.kind == "kitten", "домой — экран загрузки, строится дом котика")
	await _until_loaded()
	check(h.showing() and h.kind == "kitten", "дом котика показан")
	# окно сцены гардероба (вкладка «Дом», режим stage): загрузка рисуется в окне
	g.screens.open_wardrobe("head")
	await _frames(2)
	g.screens.request_switch("owl")
	if g.notice_ui.active():
		g.notice_ui.back()
	g.screens.tab = "home"
	await process_frame
	await process_frame
	check(h.loader != null and h.loader.kind == "owl" and h.loading(), "в окне сцены: дом совёнка грузится")
	check(not h.showing_stage(), "недостроенный дом в окне не рисуется (там экран загрузки)")
	await _until_loaded()
	check(h.showing_stage() and h.kind == "owl", "дом совёнка в окне сцены")
	var sr: Rect2 = g.screens._wr_layout().stage
	var k: float = 1.0 if h.quality == "high" else Home3D.SIMPLE_SCALE
	check(h.vp.size == Vector2i(int(sr.size.x * k), int(sr.size.y * k)), "картинка — по размеру окна сцены")


func _finish() -> void:
	Home3D.stage_load = -1
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
