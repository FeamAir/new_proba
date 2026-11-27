extends SceneTree
## Тесты версии 0.12: 3D-дома всех четырёх героев (scripts/home3d/).
##   каждый дом строится без ошибок на всех ступенях; все 40 украшений ставятся на все свои места;
##   места украшений, метки «+», кольцо примерки; переключение качества;
##   экран «Дом»: вход строит 3D, уход на уровень освобождает, возврат строит заново;
##   тап по месту открывает гардероб на вкладке «Дом»; save.cfg не портится.
## Запуск: godot --headless --path block_game -s tests/test_v012.gd
## (без экрана 3D не рисуется, но строится и считается: Home3D.force = true)

var failed := 0
var frame := 0
var g
var had_save := false
var save_bytes := PackedByteArray()
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const Home3D := preload("res://scripts/home3d/home3d.gd")
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
	Home3D.force = true
	g = load("res://scripts/game.gd").new()
	root.add_child(g)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	I18n.set_lang("ru")
	g.tut.enabled = false
	g.assist.track = false
	_test_rooms()
	_test_all_decor()
	_test_quality_room()
	_test_screen(g)
	_test_quality_setting(g)
	if had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(save_bytes)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
	return true


func _new_room(kind: String, stage: int, placed: Dictionary, hq := true) -> Node3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 640)
	vp.own_world_3d = true
	root.add_child(vp)
	var r = Home3D.ROOMS[kind].new()
	r.setup(kind, stage, placed, {"head": "bow"}, hq)
	vp.add_child(r)
	r.build()
	return r


func _drop(r: Node3D) -> void:
	var vp := r.get_parent()
	root.remove_child(vp)
	vp.free()


## Набор украшений: на каждое место — первое подходящее (для проверки «всё сразу»)
func _full(kind: String) -> Dictionary:
	var d := {}
	var used := []
	for spot in Meta.SPOTS:
		for it in Meta.decor_for(kind, spot):
			if not used.has(it.id):
				d[spot] = it.id
				used.append(it.id)
				break
	return d


func _test_rooms() -> void:
	for kind in Meta.HEROES:
		for stage in 4:
			var placed := _full(kind)
			var r = _new_room(kind, stage, placed)
			var ok: bool = r.built and r.cam != null and r.hero_sprite != null and r.env != null
			var spots_ok := true
			for spot in Meta.SPOTS:
				if not r.spots.has(spot):
					spots_ok = false
					continue
				var p: Vector3 = r.spot_point(spot)
				if not p.is_finite() or p.length() > 12.0:
					spots_ok = false
				if placed.has(spot) and not (r.spot_nodes.has(spot) and r.spot_focus.has(spot)):
					spots_ok = false
			check(ok and spots_ok, "%s, ступень %d: дом построен, 6 мест, украшения стоят (%d шт.)" % [kind, stage, placed.size()])
			if stage == 3:
				# все места пустые — вне режима украшения меток нет (0.15), в режиме — видны все метки «+»
				r.set_placed({})
				var marks := 0
				for spot in r.markers:
					if r.markers[spot].visible:
						marks += 1
				check(marks == 0, "%s: вне режима украшения меток «+» нет" % kind)
				r.set_markers(true)
				for spot in r.markers:
					if r.markers[spot].visible:
						marks += 1
				check(marks == r.spot_list().size() and marks >= 6, "%s: в режиме украшения пустые места показаны метками «+» (%d)" % [kind, marks])
				r.set_placed({"near": placed.get("near", "")})
				check(not r.markers["near"].visible and r.markers["floor_l"].visible, "%s: на занятом месте метки нет" % kind)
				# примерка: кольцо на месте
				r.set_highlight("floor_l")
				check(r.ring.visible and r.ring.position.distance_to(r.spot_point("floor_l")) < 0.01, "%s: кольцо примерки стоит на месте" % kind)
				# все места в пределах комнаты (камера до них долетает)
				var inside := true
				for spot in Meta.SPOTS:
					var p: Vector3 = r.spot_point(spot)
					if Vector2(p.x, p.z).length() > 6.5 or p.y < -0.1 or p.y > 4.6:
						inside = false
				check(inside, "%s: места украшений внутри сцены" % kind)
				# анимации идут без ошибок
				for i in 20:
					r._process(0.05)
				check(r._t > 0.9, "%s: анимации считаются" % kind)
			_drop(r)


func _test_all_decor() -> void:
	var total := 0
	var bad := []
	for kind in Meta.HEROES:
		var r = _new_room(kind, 2, {})
		for it in Meta.DECOR:
			if it.home != kind:
				continue
			for spot in Meta.SPOTS:
				if not it.spots.has(Meta.spot_kind(spot)):
					continue
				r.set_placed({spot: it.id})
				var n = r.spot_nodes.get(spot)
				var meshes := 0
				if n != null:
					meshes = n.find_children("*", "GeometryInstance3D", true, false).size()
				if meshes < 2 or not r.spot_focus.has(spot):
					bad.append("%s@%s" % [it.id, spot])
				total += 1
				r._process(0.03)
		_drop(r)
	check(bad.is_empty(), "все 40 украшений строятся на всех своих местах (%d вариантов) %s" % [total, str(bad)])
	var ids := []
	for it in Meta.DECOR:
		ids.append(it.id)
	check(ids.size() >= 40, "в каталоге не меньше 40 украшений (старые на месте, 0.15 — новые)")


func _test_quality_room() -> void:
	var r = _new_room("owl", 3, _full("owl"))
	check(r.env.glow_enabled and r.shadow_light.shadow_enabled, "высокое качество: сияние и тень включены")
	r.set_quality(false)
	var shadows := 0
	for l in r.find_children("*", "Light3D", true, false):
		if l.shadow_enabled:
			shadows += 1
	check(not r.env.glow_enabled and shadows == 0 and r.card_vp.size.x < 512, "простое качество: без сияния и теней, картинка героя меньше")
	r.set_quality(true)
	check(r.env.glow_enabled and r.shadow_light.shadow_enabled and r.card_vp.size.x == 512, "обратно высокое")
	_drop(r)


func _step(gm, sec: float) -> void:
	var t := 0.0
	while t < sec:
		gm.home3d._process(0.05)
		if gm.home3d.room:
			gm.home3d.room._process(0.05)
			gm.home3d.room.cam._process(0.05)
		t += 0.05


func _test_screen(gm) -> void:
	var h = gm.home3d
	check(h != null and h.is_3d(), "менеджер 3D-дома создан, 3D включено (force)")
	h.quality_manual = true
	gm.meta.set_hero("owl")
	gm.max_level = 35  # 3 зала — ступень 2
	gm.go_home()
	_step(gm, 0.2)
	check(h.showing() and h.kind == "owl" and h.stage == 2, "на экране «Дом» показан 3D-дом совёнка, ступень 2")
	check(h.vp.size == Vector2i(720, int(gm.H)) and h.vp.msaa_3d == Viewport.MSAA_4X, "картинка на весь экран, сглаживание ×4")
	var builds: int = h.builds
	# уход на уровень — 3D освобождается
	gm.start_level(1)
	_step(gm, 0.1)
	check(h.room == null and h.vp == null and h.get_child_count() == 0, "во время уровня 3D освобождено")
	gm._set_state(gm.State.PAUSED)
	_step(gm, 0.1)
	check(h.room == null, "в паузе уровня 3D нет")
	gm.go_home()
	_step(gm, 0.2)
	check(h.showing() and h.builds == builds + 1, "возврат домой строит дом заново")
	# карта — дом на паузе (не рисуется)
	gm.screens.open_map()
	_step(gm, 0.1)
	check(h.room != null and h.mode == "idle" and h.vp.render_target_update_mode == SubViewport.UPDATE_DISABLED and h.room.process_mode == Node.PROCESS_MODE_DISABLED, "на карте дом стоит на паузе")
	gm.go_home()
	_step(gm, 0.1)
	check(h.showing() and h.builds == builds + 1, "с карты домой — без перестройки")
	# тап по герою — реакция
	var hp: Vector2 = h.room.cam.unproject_position(h.room.hero_center())
	h.room.card.react = 99.0
	h.room.cam.tapped.emit(hp)
	check(h.room.card.react < 0.5, "тап по герою — он реагирует")
	# 0.15: тап по месту в режиме украшения: место выбрано, камера летит к нему, панель — для этого места
	gm.meta.decor_placed["owl"] = {}
	gm.decor_ui.open()
	_step(gm, 0.1)
	var target := ""
	var sp := Vector2.ZERO
	for s in ["floor_r", "wall_r", "near", "floor_l", "wall_l"]:
		var q: Vector2 = h.room.spot_screen(s)
		if q.x > 40 and q.x < 680 and q.y > 260 and q.y < gm.H - 480:
			target = s
			sp = q
			break
	check(target != "", "хотя бы одно место видно на экране с камеры по умолчанию")
	if target != "":
		var c: Dictionary = h.room.pick(sp)
		check(c.get("spot", "") == target, "под пальцем — место «%s»" % target)
		h.room.cam.tapped.emit(sp)
		check(h.room.cam.focused, "камера подлетает к месту")
		_step(gm, 0.7)
		check(gm.state == gm.State.HOME and gm.decor_ui.active and gm.decor_ui.spot == target, "режим украшения: выбрано это место")
		_step(gm, 0.2)
		check(h.showing() and h.room.highlight == target and h.room.ring.visible, "3D-дом на весь экран, кольцо на месте")
		# примерка украшения видна в 3D на месте
		var it: Dictionary = Meta.decor_for("owl", target)[0]
		gm.decor_ui.tap_item(it.id)
		_step(gm, 0.1)
		check(h.room.placed.get(target, "") == it.id and h.room.spot_nodes.has(target), "примерка «%s» показана в 3D" % it.id)
		gm.decor_ui.tryon.clear()
		_step(gm, 0.1)
		check(h.room.placed.get(target, "") == "", "примерка снята — место снова пустое")
		var ss: Vector2 = h.spot_screen(target)
		check(gm.decor_ui.view_rect().grow(60).has_point(ss), "место на экране — в видимой части дома (над панелью)")
		gm.decor_ui.close()
		gm.screens.open_wardrobe("head")
		_step(gm, 0.1)
		check(h.mode == "idle", "гардероб — дом на паузе")
	# смена героя: плавный переход в его дом
	for k in ["axolotl", "puppy", "kitten"]:
		gm.meta.set_hero(k)
		gm.go_home()
		_step(gm, 0.1)
		check(h.showing() and h.kind == k and h.fade > 0.3, "смена героя: %s — новый дом из затемнения" % k)
	_step(gm, 1.0)
	check(h.fade == 0.0, "затемнение уходит")
	# касание кнопки «Играть» не крутит камеру и запускает уровень
	gm.go_home()
	_step(gm, 0.1)
	var yaw0: float = h.room.cam.yaw
	gm.screens.rects["map"] = Rect2(40, gm.H - 140, 310, 104)  # как в draw_home (без экрана рисования нет)
	gm._touch_down(0, gm.screens.rects["map"].get_center())
	check(gm.state == gm.State.MAP and not h.room.cam.is_touching(), "кнопка интерфейса не уходит в камеру")
	gm.go_home()
	_step(gm, 0.1)
	gm._touch_down(0, Vector2(360, 560))
	for i in 6:
		gm._touch_drag(0, Vector2(360 - i * 30, 560), Vector2(-30, 0))
	gm._touch_up(0, Vector2(180, 560))
	# 0.18: если камера уже у полки (показ новых кубков), палец поворачивает «голову» — обзор от первого лица
	var turned: bool = absf(h.room.cam.look_yaw) > 0.3 if h.room.cam.look_mode else absf(h.room.cam.yaw - yaw0) > 0.3
	check(turned, "палец по сцене крутит камеру")
	gm.meta.set_hero("owl")


func _test_quality_setting(gm) -> void:
	var h = gm.home3d
	gm.go_home()
	_step(gm, 0.1)
	h.set_quality("high", true)
	_step(gm, 0.1)
	check(h.quality == "high" and h.vp.msaa_3d == Viewport.MSAA_4X, "качество: высокое")
	h.cycle_quality()
	_step(gm, 0.1)
	check(h.quality == "simple" and h.vp.msaa_3d == Viewport.MSAA_DISABLED and h.vp.size.x == int(720 * 0.75) and not h.room.env.glow_enabled, "качество: простое (без MSAA и сияния, картинка 0,75)")
	h.cycle_quality()
	_step(gm, 0.1)
	check(h.quality == "2d" and not h.showing() and h.room == null, "качество: 2D — прежний 2D-дом, 3D освобождено")
	gm._save()
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	check(cfg.get_value("settings", "graphics", "") == "2d" and cfg.get_value("settings", "graphics_manual", false) == true, "выбор качества сохраняется в save.cfg [settings]")
	h.quality = "high"
	gm._load()
	check(h.quality == "2d", "и загружается")
	h.cycle_quality()
	_step(gm, 0.1)
	check(h.quality == "high" and h.showing(), "по кругу снова высокое, 3D-дом на месте")
	# автовыбор: при низком FPS в первые секунды — простое качество (если игрок не выбирал сам)
	h.quality_manual = false
	h._auto_done = false
	h._home_time = 0.0
	h._fps_time = 0.0
	h._fps_frames = 0
	for i in 40:
		h._watch_fps(0.1)  # 10 кадров в секунду
	check(h.quality == "simple", "автовыбор: низкий FPS — простое качество")
	h.set_quality("high", true)
	# старое сохранение без настройки — высокое
	var old := ConfigFile.new()
	h.load_from(old)
	check(h.quality == "high" and not h.quality_manual, "старое сохранение: качество высокое, автовыбор разрешён")
	# 3D недоступно — 2D-дом
	h.unavailable = true
	_step(gm, 0.1)
	check(not h.showing() and h.room == null, "3D недоступно — показывается 2D-дом")
	h.unavailable = false
