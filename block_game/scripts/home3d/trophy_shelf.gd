extends "res://scripts/home3d/trophy_art3d.gd"
## Полка славы в 3D-доме (Cascado 0.14): 10 мест (2 ряда по 5: залы 1–5 сверху, 6–10 снизу).
## Полученный кубок стоит на подставке, у непройденного зала — полупрозрачный силуэт и номер.
## У каждого дома своя полка:
##   owl     — резная деревянная полка-корень на стене дупла: две изогнутые доски по стене, корни-кронштейны,
##             мох, светящиеся грибочки, сверху — арка из корня с листиками;
##   axolotl — каменная ниша грота: две изогнутые каменные полки, тёмная ниша, кораллы по бокам, ракушки и жемчуг;
##   puppy   — деревянный стенд «доска почёта» в саду: столбики, две полки, розовая крыша как у будки, косточка;
##   kitten  — застеклённая витрина на чердаке: шкафчик с дверцами, бархатная спинка, стекло, лампочка сверху.
## Свет — только свечение (emission) и «ореолы»; ламп-источников нет. Неподвижное склеивается.
## Начало координат — точка у стены на полу, +Z — в комнату.

## Описание полки (задаёт комната, room.gd shelf_def):
##   style; rows — [[высота, радиус стены], ...] (радиус 0 — прямая полка); room_r — расстояние до центра комнаты
##   (для изогнутой); spacing — шаг мест; scale — масштаб кубков; depth — глубина полки
var def := {}
var style := "owl"
var done: Array = []
## Скрытые (ещё не «появившиеся») кубки — вместо них силуэт, пока не начнётся показ
var hidden: Array = []
## Кубок, который крутится на подставке (камера подлетела к нему); 0 — нет
var spin_hall := 0
var high := true
## Показ появления: зал -> время начала (с)
var appear := {}
var k := 1.0
var slots := []
var content: Node3D
var frame_n: Node3D
var labels := {}
var _t := 0.0
var _fx := []
var built := false


func setup(d: Dictionary, dn: Array, hq: bool) -> void:
	def = d
	style = d.get("style", "owl")
	k = d.get("scale", 1.0)
	done = dn.duplicate()
	high = hq
	high_fx = hq


func build() -> void:
	build_frame()
	fill()


## 0.19: полка без кубков (постройка дома по шагам, scripts/home3d/home_loader.gd); кубки — fill()
func build_frame() -> void:
	_layout()
	frame_n = node(self)
	frame_n.name = "frame"
	var saved := anims
	anims = []
	match style:
		"owl": _frame_owl(frame_n)
		"axolotl": _frame_axolotl(frame_n)
		"puppy": _frame_puppy(frame_n)
		"kitten": _frame_kitten(frame_n)
	var mv := []
	for a in anims:
		mv.append(a.n)
	merge_static(frame_n, mv)
	saved.append_array(anims)
	anims = saved


func fill() -> void:
	_fill()
	built = true


## Места: {pos: основание кубка (локально), yaw, row}
func _layout() -> void:
	slots = []
	var rows: Array = def.get("rows", [[1.2, 0.0], [1.7, 0.0]])
	var sp: float = def.get("spacing", 0.36)
	var depth: float = def.get("depth", 0.3)
	var room_r: float = def.get("room_r", 0.0)
	# верхний ряд (залы 1–5) — тот, что выше
	var top := 1 if float(rows[1][0]) > float(rows[0][0]) else 0
	for n in range(1, 11):
		var row := top if n <= 5 else 1 - top
		var col := (n - 1) % 5
		var y: float = rows[row][0]
		var rr: float = rows[row][1]
		if rr > 0.0:
			var th := (col - 2) * sp / rr
			var r_in := rr - depth * 0.5
			slots.append({"pos": Vector3(r_in * sin(th), y, room_r - r_in * cos(th)), "yaw": -th, "row": row})
		else:
			slots.append({"pos": Vector3((col - 2) * sp, y, def.get("front_z", depth * 0.5)), "yaw": 0.0, "row": row})


func set_done(dn: Array, hid: Array) -> void:
	if dn == done and hid == hidden:
		return
	done = dn.duplicate()
	hidden = hid.duplicate()
	if built:
		_fill()


func set_high(hq: bool) -> void:
	if hq == high:
		return
	high = hq
	high_fx = hq
	if built:
		_fill()


func set_spin(n: int) -> void:
	if n == spin_hall:
		return
	spin_hall = n
	if built:
		_fill()


## Показать появление кубков (с блеском): они перестают быть скрытыми
func reveal(halls: Array) -> void:
	for i in halls.size():
		appear[halls[i]] = _t + 0.35 + i * 0.45
		hidden.erase(halls[i])
	if built:
		_fill()


func has_trophy(n: int) -> bool:
	return done.has(n) and not hidden.has(n)


# ---------- Наполнение: кубки, силуэты, таблички ----------

func _fill() -> void:
	if content != null:
		remove_child(content)
		content.queue_free()
	# анимации рамки (грибочки и т. п.) остаются; анимации кубков — заново
	var keep := []
	for a in anims:
		if is_instance_valid(a.n) and frame_n.is_ancestor_of(a.n):
			keep.append(a)
	anims = keep
	moving = []
	labels = {}
	content = node(self)
	content.name = "trophies"
	for n in range(1, 11):
		var s: Dictionary = slots[n - 1]
		var sn := node(content, s.pos, s.yaw)
		sn.name = "slot_%d" % n
		_stand(sn, n)
		var tn := node(sn)
		tn.scale = Vector3.ONE * k
		tn.name = "trophy_%d" % n
		if has_trophy(n):
			trophy(tn, n)
			if n == spin_hall:
				anim(tn, "wiggle", {"amp": 0.55, "spd": 0.7})
				moving.append(tn)
			if appear.has(n):
				moving.append(tn)
				tn.scale = Vector3.ONE * 0.001
		else:
			trophy(tn, n, true, _ghost_tint(n))
		_plaque(sn, n)
	merge_static(content, moving)
	# у каждой движущейся детали — свои неподвижные части тоже склеены
	for mv in moving:
		if is_instance_valid(mv):
			var inner := moving.filter(func(o): return o != mv and is_instance_valid(o) and (mv as Node).is_ancestor_of(o))
			merge_static(mv, inner)


func _ghost_tint(n: int) -> Color:
	return Color(0.75, 0.78, 1.0)


## Подставка под кубок (своя у каждого дома)
func _stand(sn: Node3D, n: int) -> void:
	var have := has_trophy(n)
	match style:
		"owl":
			part(sn, cyl(0.075 * k, 0.085 * k, 0.025, 10), "enamel", Color("#7A5141") if have else Color("#5A3A30"), Vector3(0, 0.0125, 0))
		"axolotl":
			part(sn, sphere(0.085 * k, 12), "enamel", Color("#F2D6E6") if have else Color("#9FB8C4"), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.25, 0.9))
		"puppy":
			part(sn, cyl(0.07 * k, 0.075 * k, 0.03, 12), "enamel", Color("#E0596F") if have else Color("#9E6640"), Vector3(0, 0.015, 0))
		"kitten":
			part(sn, cyl(0.072 * k, 0.08 * k, 0.03, 16), "velvet", Color("#5E2A7A") if have else Color("#3A2650"), Vector3(0, 0.015, 0))


## Табличка: золотая (кубок есть) — название зала; у силуэта — номер зала
func _plaque(sn: Node3D, n: int) -> void:
	var have := has_trophy(n)
	var fz: float = def.get("plaque_z", 0.12)
	var py: float = def.get("plaque_y", -0.03)
	part(sn, box(Vector3(0.15, 0.04, 0.008)), "metal" if have else "enamel", Color("#E8B84A") if have else Color("#8A7AA0"), Vector3(0, py, fz))
	var l := Label3D.new()
	l.text = Meta.hall_name(n - 1) if have else str(n)
	l.font_size = 34 if have else 60
	l.pixel_size = 0.00042 if have else 0.0005
	l.outline_size = 0
	l.modulate = Color("#3A2208") if have else Color("#F2ECFF")
	l.width = 330.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = Vector3(0, py, fz + 0.0055)
	# издалека табличек не видно — не рисуем (экономия); у полки — видно
	l.visibility_range_end = 2.9
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sn.add_child(l)
	labels[n] = l


# ---------- Где что (для камеры и касаний) ----------

## Центр кубка зала n (мир)
func slot_center(n: int) -> Vector3:
	var s: Dictionary = slots[clampi(n, 1, 10) - 1]
	return to_global(s.pos + Vector3(0, TROPHY_H * k * 0.5, 0))


## Откуда смотреть на кубок n (мир, горизонтально): «лицом» к кубку
func slot_dir(n: int) -> Vector3:
	var s: Dictionary = slots[clampi(n, 1, 10) - 1]
	return (global_transform.basis * Basis(Vector3.UP, s.yaw) * Vector3(0, 0, 1)).normalized()


func center() -> Vector3:
	var a := slot_center(3)
	var b := slot_center(8)
	return (a + b) * 0.5


func facing() -> Vector3:
	return (global_transform.basis * Vector3(0, 0, 1)).normalized()


# ---------- Анимация появления ----------

func _process(delta: float) -> void:
	_t += delta
	if content == null:
		return
	for n in appear.keys():
		var tn := content.get_node_or_null("slot_%d/trophy_%d" % [n, n]) as Node3D
		var u: float = (_t - appear[n]) / 0.9
		if tn == null:
			continue
		if u < 0.0:
			tn.scale = Vector3.ONE * 0.001
			continue
		if u >= 1.0:
			tn.scale = Vector3.ONE * k
			appear.erase(n)
			continue
		if not tn.has_meta("burst"):
			tn.set_meta("burst", true)
			_burst(tn.get_parent() as Node3D, n)
		# пружинка: растёт с небольшим «перелётом»
		var e := 1.0 - pow(1.0 - u, 3.0) + sin(u * PI) * 0.18
		tn.scale = Vector3.ONE * k * maxf(0.001, e)
		tn.rotation.y = (1.0 - u) * 2.5
	for i in range(_fx.size() - 1, -1, -1):
		var f: Dictionary = _fx[i]
		var u: float = (_t - f.t0) / f.life
		var raw = f.n  # 0.16: узел мог удалиться (дом перестроен при смене героя) — проверяем до присвоения типу
		if u >= 1.0 or not is_instance_valid(raw):
			if is_instance_valid(raw):
				raw.queue_free()
			_fx.remove_at(i)
			continue
		var nd: Node3D = raw
		if f.kind == "flash":
			nd.scale = Vector3.ONE * (0.5 + 2.6 * sin(u * PI * 0.5))
			var mi := nd as MeshInstance3D
			(mi.material_override as StandardMaterial3D).albedo_color.a = (1.0 - u) * 0.9
		else:
			nd.position = f.p0 + f.v * u
			nd.scale = Vector3.ONE * (1.0 - u)
			nd.rotation.z += delta * 6.0


## Вспышка и разлетающиеся звёздочки при появлении кубка
func _burst(sn: Node3D, n: int) -> void:
	var c := Vector3(0, TROPHY_H * k * 0.55, 0.03)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _halo_tex
	m.albedo_color = Color(Trophies2D.glow_color(n).lightened(0.4), 0.9)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if _halo_tex == null:
		halo(sn, c, 0.01, Color(1, 1, 1, 0)).queue_free()
		m.albedo_texture = _halo_tex
	var fl := put(sn, quad(Vector2(0.45, 0.45)), m, c)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx.append({"n": fl, "t0": _t, "life": 0.9, "kind": "flash"})
	var star := extrude(star_poly(0.03, 0.012), 0.006)
	for i in 8 if high else 4:
		var a := TAU * i / (8 if high else 4) + 0.3
		var st := put(sn, star, glow_mat(Color("#FFF2A8"), 2.0), c)
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx.append({"n": st, "t0": _t, "life": 0.8 + 0.2 * hash1(i, n), "kind": "star", "p0": c, "v": Vector3(cos(a) * 0.22, sin(a) * 0.2 + 0.08, 0.06)})


const Trophies2D := preload("res://scripts/trophies.gd")
const Meta := preload("res://scripts/meta.gd")


# ---------- Полки по домам ----------

## Изогнутая доска по стене (сектор кольца) толщиной th, от радиуса r_wall внутрь на depth
func _arc_board(parent: Node3D, room_r: float, r_wall: float, depth: float, half: float, y: float, th: float, kind: String, col: Color, lip := 0.0) -> void:
	var key := ["arcb", room_r, r_wall, depth, half, th]
	var mesh: ArrayMesh
	if _tm.has(key):
		mesh = _tm[key]
	else:
		var pts := PackedVector2Array()
		var n := 16
		for i in n + 1:
			var a := lerpf(-half, half, float(i) / n)
			pts.append(Vector2(r_wall * sin(a), room_r - r_wall * cos(a)))
		for i in range(n, -1, -1):
			var a := lerpf(-half, half, float(i) / n)
			var r := r_wall - depth * (1.0 - 0.12 * pow(absf(a) / half, 4.0))
			pts.append(Vector2(r * sin(a), room_r - r * cos(a)))
		mesh = extrude(pts, th)
		_tm[key] = mesh
	part(parent, mesh, kind, col, Vector3(0, y - th * 0.5, 0), Vector3(PI / 2.0, 0, 0))
	if lip > 0.0:
		# скруглённый передний край — трубка по дуге
		var key2 := ["arcl", room_r, r_wall, depth, half, lip]
		var lm: ArrayMesh
		if _tm.has(key2):
			lm = _tm[key2]
		else:
			var lp := []
			for i in 17:
				var a := lerpf(-half, half, i / 16.0)
				var r := r_wall - depth * (1.0 - 0.12 * pow(absf(a) / half, 4.0))
				lp.append(Vector3(r * sin(a), 0, room_r - r * cos(a)))
			lm = tube(lp, lip, lip, 8)
			_tm[key2] = lm
		part(parent, lm, kind, col.lightened(0.08), Vector3(0, y - th * 0.5, 0))


## Дупло: полка-корень
func _frame_owl(f: Node3D) -> void:
	var room_r: float = def.room_r
	var rows: Array = def.rows
	var depth: float = def.depth
	var wood := Color("#8A5A3C")
	var dark := Color("#5E3A2A")
	var moss := Color("#5E8F45")
	var half := 1.1 / room_r
	for r in rows:
		_arc_board(f, room_r, r[1] + 0.03, depth + 0.03, half, r[0], 0.055, "enamel", wood, 0.032)
		# кронштейны-корни под доской
		for sx in [-0.62, 0.0, 0.62]:
			var a: float = sx / room_r
			var w: Vector3 = Vector3((r[1] - 0.06) * sin(a), r[0] - 0.24, room_r - (r[1] - 0.06) * cos(a))
			var tip: Vector3 = Vector3((r[1] - depth * 0.8) * sin(a), r[0] - 0.05, room_r - (r[1] - depth * 0.8) * cos(a))
			var mid: Vector3 = Vector3((r[1] - 0.1) * sin(a), r[0] - 0.06, room_r - (r[1] - 0.1) * cos(a))
			part(f, tube(bez(w, mid, tip, 7), 0.04, 0.022, 7), "enamel", dark)
		# мох на краях доски
		for e in [-1.0, 1.0]:
			var a: float = e * (half - 0.04)
			var rr: float = r[1] - depth * 0.5
			var mp := Vector3(rr * sin(a), r[0] + 0.01, room_r - rr * cos(a))
			part(f, sphere(0.09, 10), "velvet", moss, mp, Vector3.ZERO, Vector3(1.3, 0.38, 1.6))
			part(f, sphere(0.06, 8), "velvet", moss.lightened(0.15), mp + Vector3(e * -0.08, 0.005, 0.03), Vector3.ZERO, Vector3(1.2, 0.4, 1.0))
	# боковые корни-стойки от пола до арки и арка сверху
	var top_y: float = rows[1][0] + 0.5
	var r_top: float = rows[1][1]
	for e in [-1.0, 1.0]:
		var a: float = e * (half + 0.05)
		var pts := []
		for i in 9:
			var u := i / 8.0
			var y := lerpf(0.0, top_y, u)
			var rr: float = lerpf(rows[0][1], r_top, u) - 0.1 - 0.05 * sin(u * PI)
			var aa: float = a - e * 0.02 * sin(u * 5.0)
			pts.append(Vector3(rr * sin(aa), y, room_r - rr * cos(aa)))
		part(f, tube(pts, 0.07, 0.04, 8), "enamel", dark)
	var arch := []
	for i in 13:
		var u := i / 12.0
		var a := lerpf(-(half + 0.05), half + 0.05, u)
		var rr: float = r_top - 0.14
		arch.append(Vector3(rr * sin(a), top_y + 0.16 * sin(u * PI), room_r - rr * cos(a)))
	part(f, tube(arch, 0.045, 0.045, 7), "enamel", dark)
	# листики на арке и светящиеся грибочки на концах полок
	var leaf := _leaf_poly()
	for i in 7:
		var u := (i + 0.5) / 7.0
		var a := lerpf(-(half + 0.05), half + 0.05, u)
		var rr: float = r_top - 0.19
		var lp := Vector3(rr * sin(a), top_y + 0.16 * sin(u * PI) + 0.02, room_r - rr * cos(a))
		var ln := node(f, lp, -a)
		ln.rotation.z = 0.6 if i % 2 == 0 else 2.5
		ln.scale = Vector3.ONE * 3.2
		flat(ln, leaf, 2.0, "enamel", Color("#6FB24E") if i % 2 == 0 else Color("#4E9A3E"), Vector3.ZERO, Vector3.ZERO, "leaf")
	var cols := [Color("#7FF5E0"), Color("#C38BFF"), Color("#FFB547")]
	for ri in 2:
		for e in [-1.0, 1.0]:
			var a: float = e * (half - 0.02)
			var rr: float = rows[ri][1] - 0.1
			var base := Vector3(rr * sin(a), rows[ri][0] + 0.02, room_r - rr * cos(a))
			for q in 2:
				var mp := base + Vector3(e * -0.07 * q, 0, 0.05 * q)
				var kk := 0.55 - q * 0.15
				part(f, cyl(0.02 * kk, 0.028 * kk, 0.12 * kk, 8), "enamel", Color("#F2E8FF"), mp + Vector3(0, 0.06 * kk, 0))
				part(f, hemi(0.07 * kk, 12), "glow_soft", cols[(ri + q) % 3], mp + Vector3(0, 0.11 * kk, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
	# табличка-герб наверху: звезда в венке
	var crest := node(f, Vector3(0, top_y + 0.2, room_r - (r_top - 0.2)))
	part(crest, extrude(star_poly(0.09, 0.04), 0.03), "metal", Color("#FFD34D"))
	part(crest, torus(0.1, 0.125, 24), "enamel", Color("#4E9A3E"), Vector3(0, 0, -0.01), Vector3(PI / 2.0, 0, 0))


## Грот: каменная ниша
func _frame_axolotl(f: Node3D) -> void:
	var room_r: float = def.room_r
	var rows: Array = def.rows
	var depth: float = def.depth
	var stone := Color("#A9CFC8")
	var half := 1.08 / room_r
	# тёмная ниша за кубками (изогнутая панель)
	var key := ["niche", room_r, rows[0][1]]
	var nm: ArrayMesh
	if _tm.has(key):
		nm = _tm[key]
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y0: float = rows[0][0] - 0.12
		var y1: float = rows[1][0] + 0.52
		var n := 16
		for i in n:
			for j in 6:
				var a0 := lerpf(-half, half, float(i) / n)
				var a1 := lerpf(-half, half, float(i + 1) / n)
				var ya := lerpf(y0, y1, j / 6.0)
				var yb := lerpf(y0, y1, (j + 1) / 6.0)
				var rr: float = rows[0][1] - 0.01
				var A := Vector3(rr * sin(a0), ya, room_r - rr * cos(a0))
				var B := Vector3(rr * sin(a1), ya, room_r - rr * cos(a1))
				var C := Vector3(rr * sin(a1), yb, room_r - rr * cos(a1))
				var D := Vector3(rr * sin(a0), yb, room_r - rr * cos(a0))
				var nrm := Vector3(-sin(a0), 0, cos(a0))
				tri(st, A, B, C, nrm, Color.WHITE, Color.WHITE, Color.WHITE)
				tri(st, A, C, D, nrm, Color.WHITE, Color.WHITE, Color.WHITE)
		st.generate_normals()
		nm = st.commit()
		_tm[key] = nm
	part(f, nm, "velvet", Color("#0E4A62"))
	for r in rows:
		_arc_board(f, room_r, r[1] + 0.02, depth + 0.02, half, r[0], 0.08, "enamel", stone, 0.045)
		# ракушки и жемчужинки по краю полки между кубками
		for i in 6:
			var a: float = (i - 2.5) * float(def.spacing) / float(r[1])
			var rr: float = r[1] - depth - 0.02
			var p := Vector3(rr * sin(a), r[0] - 0.035, room_r - rr * cos(a))
			if i % 2 == 0:
				part(f, hemi(0.035, 12), "enamel", Color("#FFC2D6"), p, Vector3(PI / 2.0, -a, 0), Vector3(1.0, 0.5, 1.0))
			else:
				part(f, sphere(0.02, 10), "metal", Color("#F4F0FF"), p)
		# камешки-опоры
		for sx in [-0.7, 0.0, 0.7]:
			var a: float = sx / room_r
			var rr: float = r[1] - 0.06
			part(f, sphere(0.09, 10), "enamel", stone.darkened(0.15), Vector3(rr * sin(a), r[0] - 0.1, room_r - rr * cos(a)), Vector3(0, a, 0), Vector3(1.2, 0.8, 0.7))
	# каменная арка-рамка: валуны по краям и сверху
	var top_y: float = rows[1][0] + 0.55
	for i in 13:
		var u := i / 12.0
		var a := lerpf(-(half + 0.06), half + 0.06, u)
		var y := top_y + 0.1 * sin(u * PI)
		var rr: float = rows[1][1] - 0.05
		part(f, sphere(0.11 + 0.03 * hash1(i, 3), 10), "enamel", stone.darkened(0.08 * hash1(i, 4)), Vector3(rr * sin(a), y, room_r - rr * cos(a)), Vector3(0, a, 0), Vector3(1.3, 0.9, 0.8))
	# кораллы по бокам
	for e in [-1.0, 1.0]:
		var a: float = e * (half + 0.1)
		var rr: float = rows[0][1] - 0.12
		var base := Vector3(rr * sin(a), 0.0, room_r - rr * cos(a))
		var col := Color("#FF7FA8") if e < 0.0 else Color("#FF9A5C")
		for b in 4:
			var h := 0.9 + 0.45 * hash1(b, 7 + int(e))
			var bend := Vector3(e * -0.12 * (b - 1.5), 0, 0.05 * b)
			var pts := bez(base + Vector3(0.03 * b * e, 0, 0), base + bend + Vector3(0, h * 0.5, 0), base + bend * 1.8 + Vector3(0, h, 0), 7)
			part(f, tube(pts, 0.04, 0.02, 7), "enamel", col.lightened(0.08 * b))
			part(f, sphere(0.03, 8), "enamel", col.lightened(0.3), pts[pts.size() - 1])
	# ракушки и жемчужины на краях полок, морская звезда наверху
	for ri in 2:
		for e in [-1.0, 1.0]:
			var a: float = e * (half - 0.05)
			var rr: float = rows[ri][1] - depth * 0.45
			var p := Vector3(rr * sin(a), rows[ri][0] + 0.005, room_r - rr * cos(a))
			part(f, hemi(0.06, 14), "enamel", Color("#FFD3E0"), p, Vector3(0, a + 0.4, 0), Vector3(1.0, 0.6, 0.85))
			part(f, sphere(0.022, 10), "metal", Color("#FFFFFF"), p + Vector3(e * -0.07, 0.02, 0.02))
	var star_n := node(f, Vector3(0, top_y + 0.12, room_r - (rows[1][1] - 0.2)))
	part(star_n, extrude(star_poly(0.12, 0.05), 0.04), "enamel", Color("#FFB547"))
	part(star_n, sphere(0.018, 8), "metal", Color("#FFFFFF"), Vector3(0, 0, 0.025))


## Сад щенка: деревянный стенд «доска почёта»
func _frame_puppy(f: Node3D) -> void:
	var rows: Array = def.rows
	var sp: float = def.spacing
	var w := sp * 5.0 + 0.16
	var wood := Color("#C88A58")
	var dark := Color("#9E6640")
	var top_y: float = rows[1][0] + 0.42
	# стойки, задняя доска, полки
	for sx in [-1.0, 1.0]:
		part(f, box(Vector3(0.09, top_y + 0.05, 0.09)), "enamel", dark, Vector3(sx * w * 0.5, (top_y + 0.05) * 0.5, 0.06))
	for i in 7:
		var y := 0.15 + i * (top_y - 0.15) / 6.5
		part(f, box(Vector3(w - 0.04, (top_y - 0.15) / 6.5 - 0.012, 0.03)), "enamel", wood if i % 2 == 0 else wood.darkened(0.06), Vector3(0, y + (top_y - 0.15) / 13.0, 0.0))
	for r in rows:
		part(f, box(Vector3(w + 0.04, 0.045, 0.24)), "enamel", wood.lightened(0.05), Vector3(0, r[0] - 0.0225, 0.13))
		part(f, box(Vector3(w + 0.04, 0.02, 0.02)), "metal", Color("#FFD34D"), Vector3(0, r[0] - 0.03, 0.255))
	# крыша как у будки
	var ang := 0.42
	var rl := (w * 0.5 + 0.14) / cos(ang)
	for sx in [-1.0, 1.0]:
		part(f, box(Vector3(rl, 0.05, 0.36)), "enamel", Color("#E0596F"), Vector3(sx * rl * 0.5 * cos(ang), top_y + 0.05 + rl * 0.5 * sin(ang), 0.08), Vector3(0, 0, -sx * ang))
		for q in 3:
			var u := (q + 0.5) / 3.0
			part(f, box(Vector3(rl / 3.0, 0.03, 0.38)), "enamel", Color("#F07A8E") if q % 2 == 0 else Color("#B8445A"), Vector3(sx * rl * u * cos(ang), top_y + 0.085 + rl * u * sin(ang), 0.08), Vector3(0, 0, -sx * ang))
	part(f, prism(Vector3(w, rl * sin(ang) * 0.98, 0.03)), "enamel", wood, Vector3(0, top_y + 0.05 + rl * sin(ang) * 0.49, 0.0))
	# косточка-герб на фронтоне
	var bn := node(f, Vector3(0, top_y + 0.16, 0.03))
	part(bn, capsule(0.035, 0.2), "enamel", Color("#FFF3E0"), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			part(bn, sphere(0.035, 10), "enamel", Color("#FFF3E0"), Vector3(sx * 0.1, sy * 0.03, 0))
	part(bn, extrude(star_poly(0.03, 0.013), 0.012), "metal", Color("#FFD34D"), Vector3(0, 0, 0.035))
	# цветочки у подножия
	for sx in [-1.0, 1.0]:
		for q in 3:
			var p := Vector3(sx * (w * 0.5 + 0.12 + 0.08 * q), 0, 0.14 + 0.06 * (q % 2))
			part(f, cyl(0.006, 0.006, 0.18 + 0.05 * q, 4), "enamel", Color("#4E9A3E"), p + Vector3(0, 0.09 + 0.025 * q, 0))
			part(f, sphere(0.035, 8), "enamel", [Color("#FFD34D"), Color("#FF9EC6"), Color("#9FD8FF")][q], p + Vector3(0, 0.18 + 0.05 * q, 0), Vector3.ZERO, Vector3(1, 0.6, 1))


## Чердак: застеклённая витрина
func _frame_kitten(f: Node3D) -> void:
	var rows: Array = def.rows
	var sp: float = def.spacing
	var w := sp * 5.0 + 0.14
	var d := 0.36
	var wood := Color("#A0694C")
	var dark := Color("#7A4E38")
	var gold := Color("#FFD34D")
	var top_y: float = rows[1][0] + 0.45
	var low: float = rows[0][0] - 0.06
	# ножки, нижний шкафчик с дверцами
	for sx in [-1.0, 1.0]:
		for sz in [0.04, d - 0.04]:
			part(f, cyl(0.025, 0.018, 0.12, 8), "enamel", dark, Vector3(sx * (w * 0.5 - 0.05), 0.06, sz))
	part(f, box(Vector3(w, low - 0.12, d)), "enamel", wood, Vector3(0, 0.12 + (low - 0.12) * 0.5, d * 0.5))
	for sx in [-1.0, 1.0]:
		part(f, box(Vector3(w * 0.5 - 0.06, low - 0.2, 0.02)), "enamel", wood.lightened(0.08), Vector3(sx * w * 0.25, 0.12 + (low - 0.12) * 0.5, d + 0.005))
		part(f, sphere(0.018, 8), "metal", gold, Vector3(sx * 0.06, 0.12 + (low - 0.12) * 0.55, d + 0.025))
	# корпус витрины: бока, верх, бархатная спинка, полки
	for sx in [-1.0, 1.0]:
		part(f, box(Vector3(0.05, top_y - low + 0.05, d)), "enamel", wood, Vector3(sx * (w * 0.5 - 0.025), low + (top_y - low) * 0.5, d * 0.5))
	part(f, box(Vector3(w, 0.05, d)), "enamel", wood, Vector3(0, top_y, d * 0.5))
	part(f, box(Vector3(w + 0.08, 0.04, d + 0.06)), "enamel", dark, Vector3(0, top_y + 0.045, d * 0.5 + 0.01))
	part(f, box(Vector3(w - 0.1, top_y - low, 0.02)), "velvet", Color("#4A1E66"), Vector3(0, low + (top_y - low) * 0.5, 0.02))
	for r in rows:
		part(f, box(Vector3(w - 0.08, 0.03, d - 0.04)), "enamel", wood.lightened(0.04), Vector3(0, r[0] - 0.015, d * 0.5))
		part(f, box(Vector3(w - 0.08, 0.012, 0.012)), "metal", gold, Vector3(0, r[0] - 0.02, d - 0.02))
	# золотой кант по краю и стекло спереди
	for sx in [-1.0, 1.0]:
		part(f, box(Vector3(0.014, top_y - low, 0.014)), "metal", gold, Vector3(sx * (w * 0.5 - 0.05), low + (top_y - low) * 0.5, d))
	var gl := put(f, quad(Vector2(w - 0.1, top_y - low - 0.04)), glass_mat(), Vector3(0, low + (top_y - low) * 0.5, d + 0.004))
	gl.mesh = painted(quad(Vector2(w - 0.1, top_y - low - 0.04)), Color(0.75, 0.85, 1.0, 0.08))
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# блики на стекле
	for i in 2:
		var sl := put(f, painted(quad(Vector2(0.05 - i * 0.02, top_y - low - 0.2)), Color(1, 1, 1, 0.12)), glass_mat(), Vector3(-w * 0.3 + i * 0.09, low + (top_y - low) * 0.5, d + 0.006), Vector3(0, 0, 0.25))
		sl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# лампочка-абажур сверху (светится сама)
	var lp := Vector3(0, top_y + 0.065, d * 0.45)
	part(f, cyl(0.012, 0.012, 0.1, 6), "metal", gold, lp + Vector3(0, 0.05, 0))
	part(f, lathe([Vector2(0.12, 0.0), Vector2(0.07, 0.12), Vector2(0.0, 0.12)], 18), "enamel", Color("#FF9EC6"), lp + Vector3(0, 0.1, 0))
	part(f, sphere(0.04, 10), "glow", Color("#FFE9A0"), lp + Vector3(0, 0.1, 0))
	if high_fx:
		halo(f, lp + Vector3(0, 0.08, 0.05), 0.5, Color(1.0, 0.85, 0.5, 0.35))
	# кошачьи ушки на карнизе
	for sx in [-1.0, 1.0]:
		part(f, prism(Vector3(0.12, 0.1, 0.04)), "enamel", dark, Vector3(sx * (w * 0.5 - 0.12), top_y + 0.115, d * 0.5))
