extends RefCounted
## Cascado 0.19: постройка 3D-дома по частям и «прогрев» шейдеров за экраном загрузки.
##
## Почему: при первом показе дома видеокарта телефона собирает (компилирует) шейдеры — для каждого вида
## материала несколько программ (обычный проход, тени, доп. свет). Раньше всё это делалось в ОДНОМ кадре
## вместе с постройкой сеток — экран замирал на 5–10 секунд (жалоба закрытого теста).
## Теперь (scripts/home3d/home3d.gd, game.gd):
##   1) сначала рисуется экран загрузки (scripts/loading_ui.gd) — в кадре, где нажали «Вперёд», тяжёлой работы нет;
##   2) постройка — по шагу за кадр (room.build_steps(): комната, герой, склейка, украшения, полка, кубки, камера);
##   3) прогрев: всё в доме скрывается и показывается группами — за кадр одна НОВАЯ группа материалов
##      (одинаковые по шейдеру материалы — вместе), картинка маленькая (WARM_SIZE), камера сверху видит весь дом.
##      Каждый кадр собирает лишь несколько программ, экран загрузки между ними обновляется;
##   4) всё возвращается как было, дом показывается из затемнения (как раньше).
## Повторная постройка того же дома в этом запуске (возврат с уровня) — без прогрева: шейдеры уже собраны.
## На диске шейдеры кэширует сам Godot (rendering/shader_compiler/shader_cache/enabled) — при втором запуске
## игры прогрев проходит заметно быстрее (программы читаются из кэша, а не собираются).

## Картинка во время прогрева (шейдеры от размера не зависят, а рисовать маленькую — дёшево)
const WARM_SIZE := Vector2i(90, 160)
## Сколько миллисекунд за кадр можно тратить на шаги постройки (минимум — один шаг за кадр)
const BUDGET_MS := 12.0
## Кадр прогрева быстрее этого (мс) — значит, новых шейдеров почти не было: в следующий раз — больше групп
const FAST_MS := 40.0

## Какие дома уже прогреты в этом запуске игры: "герой|ступень|качество"
static var warmed := {}

var h                     # scripts/home3d/home3d.gd
var kind := ""
var stage := 0
var quality := "high"
var vp: SubViewport
var room
var rewarm := false       # только прогрев (сменилось качество): дом уже стоит (h.room / h.vp)
var phase := "build"      # build / warm / done
var steps: Array = []
var step_i := 0
var groups: Array = []    # шаги прогрева: {"items": [GeometryInstance3D], "op": "show" (показать) / "shadow" (вернуть тень)}
var group_i := 0
var per_frame := 1        # сколько групп показывать за кадр (растёт, если кадры быстрые)
var frames := 0
var build_ms := 0.0
var warm_ms := 0.0
var _vis := {}            # GeometryInstance3D -> исходная видимость
var _shadow := {}         # GeometryInstance3D -> исходная настройка тени (тень — отдельным кадром)
var _cam: Camera3D
var _last_us := 0
var _need_warm := true


static func key(k: String, st: int, q: String) -> String:
	return "%s|%d|%s" % [k, st, q]


static func is_warmed(k: String, st: int, q: String) -> bool:
	return warmed.has(key(k, st, q))


func _init(home, k: String, st: int, q: String, only_warm := false) -> void:
	h = home
	kind = k
	stage = st
	quality = q
	rewarm = only_warm
	_need_warm = not is_warmed(k, st, q)
	if rewarm:
		vp = h.vp
		room = h.room
	else:
		steps = [_step_create]


## Доля готового 0..1 (полоска на экране загрузки): постройка — первая четверть, прогрев — остальное
func progress() -> float:
	if phase == "done":
		return 1.0
	var b := float(step_i) / maxf(9.0, steps.size())
	if not _need_warm:
		return clampf(b, 0.0, 0.99)
	if phase == "build":
		return clampf(0.25 * b, 0.0, 0.25)
	return clampf(0.25 + 0.75 * float(group_i) / maxf(1.0, groups.size()), 0.25, 0.99)


func done() -> bool:
	return phase == "done"


## Прогрев нужен (дом в этом запуске ещё не показывался с таким качеством)
func needs_warm() -> bool:
	return _need_warm


## Один кадр работы. true — всё готово.
func step() -> bool:
	frames += 1
	var now := Time.get_ticks_usec()
	var last_frame_ms := (now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if phase == "build":
		var t0 := Time.get_ticks_usec()
		while step_i < steps.size():
			(steps[step_i] as Callable).call()
			step_i += 1
			if (Time.get_ticks_usec() - t0) / 1000.0 >= BUDGET_MS:
				break
		build_ms += (Time.get_ticks_usec() - t0) / 1000.0
		if step_i >= steps.size():
			if _need_warm:
				_warm_begin()
			else:
				_finish()
		return phase == "done"
	if phase == "warm":
		var t1 := Time.get_ticks_usec()
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # могли поставить на паузу (карта посреди прогрева)
		room.process_mode = Node.PROCESS_MODE_INHERIT
		if group_i > 0:
			# прошлый кадр с новыми группами был быстрым — шейдеры уже есть (кэш на диске): быстрее вперёд
			if last_frame_ms > 0.0 and last_frame_ms < FAST_MS:
				per_frame = mini(per_frame * 2, 64)
			else:
				per_frame = 1
		if group_i < groups.size():
			for i in per_frame:
				if group_i >= groups.size():
					break
				var gr: Dictionary = groups[group_i]
				for gi in gr.items:
					if not is_instance_valid(gi):
						continue
					if gr.op == "show":
						(gi as GeometryInstance3D).visible = true
					elif _shadow.has(gi):
						(gi as GeometryInstance3D).cast_shadow = _shadow[gi]
				group_i += 1
		else:
			_warm_end()
			_finish()
		warm_ms += (Time.get_ticks_usec() - t1) / 1000.0
	return phase == "done"


## Отменить (ушли с экрана посреди загрузки): своё освободить, при прогреве — вернуть дом как был
func cancel() -> void:
	if phase == "warm":
		_warm_end()
	if not rewarm and vp != null and is_instance_valid(vp):
		if vp.get_parent():
			vp.get_parent().remove_child(vp)
		vp.queue_free()
	vp = null
	room = null
	phase = "done"


# ---------- Постройка ----------

func _step_create() -> void:
	vp = SubViewport.new()
	vp.name = "Home3DViewport"
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.gui_disable_input = true
	vp.handle_input_locally = false
	vp.audio_listener_enable_3d = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = WARM_SIZE
	h.add_child(vp)
	room = h.make_room(kind, stage)
	room.process_mode = Node.PROCESS_MODE_DISABLED  # пока строится — не считается
	vp.add_child(room)
	steps.append_array(room.build_steps())


func _finish() -> void:
	if room != null:
		room.process_mode = Node.PROCESS_MODE_INHERIT
	warmed[key(kind, stage, quality)] = true
	phase = "done"


# ---------- Прогрев шейдеров ----------

## Подпись материала «для шейдера»: что меняет код шейдера (флаги, режимы, есть ли текстуры), без цветов и чисел
static func mat_sig(m: Material) -> String:
	var out := ""
	var guard := 0
	while m != null and guard < 4:
		guard += 1
		if m is ShaderMaterial:
			var sh: Shader = (m as ShaderMaterial).shader
			out += "S%d;" % (sh.get_instance_id() if sh else 0)
		elif m is BaseMaterial3D:
			var s := "B"
			for p in m.get_property_list():
				var t: int = p.type
				if t == TYPE_BOOL or (t == TYPE_INT and p.name != "render_priority"):
					s += str(int(m.get(p.name)))
				elif t == TYPE_OBJECT and String(p.name).ends_with("_texture"):
					s += "1" if m.get(p.name) != null else "0"
			out += s + ";"
		else:
			out += m.get_class() + ";"
		m = m.next_pass
	return out


static func gi_sig(gi: GeometryInstance3D) -> String:
	var s := "%s|%d|" % [gi.get_class(), gi.cast_shadow]
	if gi is SpriteBase3D:
		var sp := gi as SpriteBase3D
		return s + "sprite%d%d%d%d%d" % [sp.billboard, int(sp.shaded), sp.alpha_cut, int(sp.transparent), int(sp.double_sided)]
	if gi.material_override:
		return s + mat_sig(gi.material_override)
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	if mesh:
		for i in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if gi is MeshInstance3D and (gi as MeshInstance3D).get_surface_override_material(i):
				m = (gi as MeshInstance3D).get_surface_override_material(i)
			s += mat_sig(m) if m else "-;"
	return s


func _warm_begin() -> void:
	phase = "warm"
	room.process_mode = Node.PROCESS_MODE_INHERIT  # картонка героя должна нарисоваться
	vp.size = WARM_SIZE
	vp.msaa_3d = Viewport.MSAA_4X if quality == "high" else Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# всё скрыть, запомнить, как было; первая встреча «вида» материала — своя группа, повторы — одной группой в конце
	var seen := {}
	var rest := []
	var box := AABB()
	var first := true
	for n in room.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var sg := gi_sig(gi)  # до того, как тень выключена на время прогрева
		_vis[gi] = gi.visible
		gi.visible = false
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			# проход тени — своя программа: собирается следующим кадром (кадры короче)
			_shadow[gi] = gi.cast_shadow
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if seen.has(sg):
			rest.append(gi)
		else:
			seen[sg] = true
			_add_group([gi])
		if gi is VisualInstance3D:
			var b: AABB = gi.global_transform * gi.get_aabb()
			if b.size.length() < 40.0:
				box = b if first else box.merge(b)
				first = false
	if not rest.is_empty():
		_add_group(rest)
	# камера сверху: весь дом в кадре — шейдеры собираются для всего, а не только для того, что видно из обзора
	_cam = Camera3D.new()
	_cam.name = "warm_cam"
	_cam.fov = 75.0
	_cam.near = 0.05
	_cam.far = 200.0
	room.add_child(_cam)
	var c := box.get_center()
	var r := maxf(2.0, box.size.length() * 0.5)
	_cam.look_at_from_position(c + Vector3(0, r * 1.6 + 1.0, 0.01), c, Vector3(0, 0, -1))
	_cam.current = true


func _add_group(items: Array) -> void:
	groups.append({"items": items, "op": "show"})
	if items.any(func(gi): return _shadow.has(gi)):
		groups.append({"items": items, "op": "shadow"})


func _warm_end() -> void:
	for gi in _shadow:
		if is_instance_valid(gi):
			(gi as GeometryInstance3D).cast_shadow = _shadow[gi]
	_shadow.clear()
	for gi in _vis:
		if is_instance_valid(gi):
			(gi as GeometryInstance3D).visible = _vis[gi]
	_vis.clear()
	if _cam != null and is_instance_valid(_cam):
		_cam.current = false
		_cam.get_parent().remove_child(_cam)
		_cam.queue_free()
	_cam = null
	if room != null and room.cam != null:
		room.cam.current = true
