extends "res://scripts/home3d/room.gd"
## Уютный чердак котика: скошенный потолок с балками, дощатый пол, на задней стене — круглое окно
## на луну и кристальную пещеру в холме; в центре — плетёная корзинка-лежанка на ковре.
## Место «сверху» у котика — высокая полка на стене (вещь на ней стоит).
## Ступени богатства (Meta.home_stage):
##   0 — пустоватый чердак: коробки, сундук, лампочка;  1 — большой ковёр, книжная полка, цветок, подушки;
##   2 — гирлянда-огоньки по балкам и занавески;  3 — звёздный проектор: пятна звёзд по стенам и потолку.

const HW := 3.0
const HL := 3.4
const KW := 1.1
const RH := 4.0
const WIN_C := Vector3(0, 2.05, -HL)
const WIN_R := 0.62

static var _geo := {}
var _surf: ShaderMaterial
var _shell_mi: MeshInstance3D
var _shell_mat: ShaderMaterial


static func roof_y(x: float) -> float:
	return KW + (RH - KW) * (1.0 - clampf(absf(x) / HW, 0.0, 1.0))


func _init() -> void:
	kind = "kitten"
	hero_feet = Vector3(0, 0.27, 0.0)
	var back := -HL + 0.02
	spots = {
		"floor_l": {"pos": Vector3(-1.75, 0, -1.55), "yaw": 0.55},
		"floor_r": {"pos": Vector3(1.8, 0, -1.25), "yaw": -0.6},
		"wall_l": {"pos": Vector3(-1.7, 1.15, back), "yaw": 0.0, "mark": Vector3(0, 0.3, 0.3), "stand": Vector3(0, 0.04, 0.17)},
		"wall_r": {"pos": Vector3(1.95, 0.95, back), "yaw": 0.0, "mark": Vector3(0, 0.3, 0.3), "stand": Vector3(0, 0.04, 0.17)},
		"hang": {"pos": Vector3(1.05, 2.2, back), "yaw": 0.0, "mark": Vector3(0, 0.25, 0.25), "stand": Vector3(0, 0.04, 0.16)},
		"near": {"pos": Vector3(0.98, 0, 0.5), "yaw": -0.4, "mark": Vector3(0, 0.3, 0)},
	}
	for s in ["floor_l", "floor_r", "near"]:
		spots[s]["mark"] = Vector3(0, 0.3, 0)
	# 0.15: новые места (типы — scripts/decor_data/kitten.gd). Старое «сверху» — верхняя полка (тип shelf),
	# поэтому подвесы на балках (тип hang) — на нитке: hang_style = "rope".
	hang_style = "rope"
	rope_len = 0.5
	# подоконник круглого окна (по центру), низкая полка в левом углу, второе «рядом» — слева от корзинки
	spots["window"] = {"pos": Vector3(0.0, WIN_C.y - WIN_R - 0.08, back + 0.12), "yaw": 0.0, "mark": Vector3(0, 0.3, 0.1)}
	spots["shelf_low"] = {"pos": Vector3(-2.35, 0.6, back), "yaw": 0.0, "mark": Vector3(0, 0.3, 0.3), "stand": Vector3(0, 0.04, 0.17)}
	spots["near_2"] = {"pos": Vector3(-0.98, 0, 0.5), "yaw": 0.4, "mark": Vector3(0, 0.3, 0)}
	# пол впереди справа (у сундука), стена слева от окна
	spots["floor_front"] = {"pos": Vector3(1.35, 0, 1.6), "yaw": face_to(Vector3(1.35, 0, 1.6), Vector3(0, 0, 0.2)), "mark": Vector3(0, 0.3, 0)}
	spots["wall_back"] = {"pos": Vector3(-1.38, 2.12, back), "yaw": 0.0, "mark": Vector3(0, 0.3, 0.3), "stand": Vector3(0, 0.04, 0.17)}
	# большие места: у задней стены справа (под верхней полкой) и под скосом справа
	spots["big_back"] = {"pos": Vector3(0.95, 0, -2.8), "yaw": -0.12, "mark": Vector3(0, 0.5, 0)}
	spots["big_corner"] = {"pos": Vector3(2.2, 0, 0.1), "yaw": -PI / 2.0 + 0.15, "mark": Vector3(0, 0.5, 0)}
	# подвесы на задней затяжке
	spots["beam"] = {"pos": Vector3(-0.62, 2.98, -1.4), "yaw": 0.0, "mark": Vector3(0, -0.8, 0)}
	spots["beam_2"] = {"pos": Vector3(0.62, 2.98, -1.4), "yaw": 0.0, "mark": Vector3(0, -0.8, 0)}
	# 0.14: полка славы — застеклённая витрина у стены напротив окна (за спиной камеры в обычном обзоре)
	shelf_def = {"style": "kitten", "pos": Vector3(0, 0, HL - 0.02), "yaw": PI, "rows": [[1.0, 0.0], [1.47, 0.0]],
		"spacing": 0.34, "scale": 0.95, "depth": 0.36, "front_z": 0.19, "plaque_z": 0.165, "plaque_y": -0.035,
		"focus_d": 0.6, "view_d": 1.75}


func _inside(p: Vector3) -> bool:
	return absf(p.x) < HW - 0.45 and absf(p.z) < HL - 0.35 and p.y > 0.15 and p.y < roof_y(p.x) - 0.3


func _setup_camera(c: Camera3D) -> void:
	c.home_pivot = Vector3(0, 0.82, 0)
	c.home_dist = 2.55
	c.dist_max = 2.8


## 0.15: большие вещи (печка, барабаны, домик) — издалека, целиком
func focus_spot(spot: String) -> void:
	if spots.has(spot) and spot_kind(spot) == "big" and spot_focus.has(spot):
		var at: Vector3 = spot_focus[spot][0]
		cam.fly_to(at, _view_dir(at), maxf(float(spot_focus[spot][1]) * 1.3, 2.2), 0.25)
		return
	super.focus_spot(spot)


func _view_dir(at: Vector3, is_hero := false, turn := 0.55) -> Vector3:
	if is_hero:
		return cam.global_position - at
	if at.z < -HL + 0.6:
		# вещь на задней стене — смотрим из комнаты, чуть сбоку
		return Vector3(-at.x * 0.25, 0, 1.0).normalized()
	if absf(at.x) > 1.2:
		# вещь в углу на полу — смотрим спереди, мимо корзинки
		return Vector3(-signf(at.x) * 0.5, 0, 1.0).normalized()
	return super._view_dir(at, is_hero, turn)


# ---------- Окружение ----------

func _environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#140C22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8A6AA8")
	env.ambient_light_energy = 0.42 + 0.05 * stage
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("#3A2650")
	env.fog_density = 0.03
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	world_env.environment = env
	add_child(world_env)


func _build_house(h: Node3D) -> void:
	# 0.15: свой шейдер стен и пола (как «attic» + узоры стиля комнаты, зайчики диско-шара) — KIT_SHELL ниже
	_surf = _shader_mat("kit_shell", KIT_SHELL, {"stars": 1.0 if stage >= 3 else 0.0, "proj": Vector3(-0.9, 0.55, 0.9)})
	_surf.set_meta("merge", true)
	_shell(h)
	_beams(h)
	_window(h)
	_basket(h)
	_props(h)
	# лампочка под коньком — тёплый свет, тени в высоком качестве
	var cord := put(h, cyl(0.008, 0.008, 0.7, 4), mat(OUT, 1.0, 0.0, false), Vector3(0.3, RH - 0.45, 0.6))
	cord.name = "cord"
	put(h, cyl(0.04, 0.05, 0.06, 10), mat(Color("#3A2A55"), 0.6), Vector3(0.3, RH - 0.82, 0.6))
	put(h, sphere(0.07, 14), glow_mat(Color("#FFE9B0"), 2.6), Vector3(0.3, RH - 0.9, 0.6), Vector3.ZERO, Vector3(1, 1.2, 1))
	halo(h, Vector3(0.3, RH - 0.9, 0.6), 1.0, Color(1.0, 0.85, 0.5, 0.35))
	var bulb := omni(h, Vector3(0.3, RH - 0.95, 0.6), Color("#FFC27A"), 0.6 + 0.1 * stage, 6.0, "slow", true)
	shadow_light = bulb
	shader_swarm(h, "flies", 4 + stage * 3, {"center": Vector3(0, 2.2, -0.5), "spread": Vector3(1.6, 0.6, 1.6), "col": Color(1.0, 0.85, 0.6, 1.0), "size": 0.03})


# ---------- 0.15: стиль комнаты (пол и стены — одна сетка, свой материал с двумя оттенками) ----------

## apply_walls / apply_floor / apply_light — в конце файла (0.15: узоры и настроения)
func _shell_tint(param: String, c: Color) -> void:
	if _shell_mi == null:
		return
	if _shell_mat == null:
		_shell_mat = _surf.duplicate()
		_shell_mi.material_override = _shell_mat
	_shell_mat.set_shader_parameter(param, Vector3(c.r, c.g, c.b))


# ---------- Пол, стены, крыша ----------

func _shell(h: Node3D) -> void:
	if not _geo.has("shell"):
		_geo["shell"] = _shell_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["shell"]
	mi.material_override = _surf
	h.add_child(mi)
	# 0.15: пол и стены чердака — одна сетка; стиль красит их своим материалом (apply_walls / apply_floor ниже)
	_shell_mi = mi
	wall_parts.append(mi)


func _shell_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# пол: доски вдоль z
	var nx := 24
	var nz := 12
	for i in nx:
		var x0 := lerpf(-HW, HW, float(i) / nx)
		var x1 := lerpf(-HW, HW, float(i + 1) / nx)
		var pc := Color("#6E4A3C").lerp(Color("#84604A"), hash1(i, 1)).lerp(Color("#5E4036"), 0.3 * hash1(i, 2))
		for j in nz:
			var z0 := lerpf(-HL, HL, float(j) / nz)
			var z1 := lerpf(-HL, HL, float(j + 1) / nz)
			var c0 := pc.darkened(0.08 * hash1(i * 31 + j, 3))
			var seam := Color(pc.darkened(0.35))
			var A := Vector3(x0, 0, z0)
			var B := Vector3(x1, 0, z0)
			var C := Vector3(x1, 0, z1)
			var D := Vector3(x0, 0, z1)
			tri(st, A, B, C, Vector3.UP, seam, c0, c0)
			tri(st, A, C, D, Vector3.UP, seam, c0, seam)
	# низкие боковые стенки и скаты крыши: доски вдоль z
	for sx in [-1.0, 1.0]:
		var rows := 18
		for r in rows:
			# r: 0..3 — стенка (вертикаль), дальше — скат
			var p0: Vector3
			var p1: Vector3
			var t0 := float(r) / rows
			var t1 := float(r + 1) / rows
			p0 = _side_pt(sx, t0)
			p1 = _side_pt(sx, t1)
			var wall := t1 <= 0.2
			var base := Color("#8E6450") if wall else Color("#9C7660")
			var pc := base.lerp(base.lightened(0.12), hash1(r, 7 + int(sx)))
			var seam := pc.darkened(0.3)
			var n := Vector3(-sx, 0, 0) if wall else Vector3(-sx * (RH - KW) / HW, -1.0, 0).normalized()
			for j in nz:
				var z0 := lerpf(-HL, HL, float(j) / nz)
				var z1 := lerpf(-HL, HL, float(j + 1) / nz)
				var A := Vector3(p0.x, p0.y, z0)
				var B := Vector3(p1.x, p1.y, z0)
				var C := Vector3(p1.x, p1.y, z1)
				var D := Vector3(p0.x, p0.y, z1)
				tri(st, A, B, C, n, seam, pc, pc)
				tri(st, A, C, D, n, seam, pc, seam)
	# торцевые стены (фронтоны): обои в полоску; в задней — круглое окно
	for sz in [-1.0, 1.0]:
		var cols := 30
		var rows := 22
		for i in cols:
			var x0 := lerpf(-HW, HW, float(i) / cols)
			var x1 := lerpf(-HW, HW, float(i + 1) / cols)
			var stripe := (i % 4) < 2
			var wc := Color("#C8B0DA") if stripe else Color("#D6C2E4")
			for j in rows:
				var v0 := float(j) / rows
				var v1 := float(j + 1) / rows
				var A := Vector3(x0, roof_y(x0) * v0, sz * HL)
				var B := Vector3(x1, roof_y(x1) * v0, sz * HL)
				var C := Vector3(x1, roof_y(x1) * v1, sz * HL)
				var D := Vector3(x0, roof_y(x0) * v1, sz * HL)
				var ctr := (A + C) * 0.5
				if sz < 0.0 and Vector2(ctr.x - WIN_C.x, ctr.y - WIN_C.y).length() < WIN_R:
					continue
				var c := wc
				# панель-«вагонка» внизу
				if ctr.y < 0.55:
					c = Color("#8E5E4A").lerp(Color("#A06E54"), 0.5 + 0.5 * sin(i * 2.0))
				elif ctr.y < 0.62:
					c = Color("#E8D6F0")
				var n := Vector3(0, 0, -sz)
				tri(st, A, B, C, n, c, c, c)
				tri(st, A, C, D, n, c, c, c)
	st.index()
	st.generate_normals()
	return st.commit()


## Точка боковой стороны: t = 0..0.2 — низкая стенка (от пола до KW), 0.2..1 — скат до конька
static func _side_pt(sx: float, t: float) -> Vector3:
	if t <= 0.2:
		return Vector3(sx * HW, KW * t / 0.2, 0)
	var u := (t - 0.2) / 0.8
	return Vector3(sx * HW * (1.0 - u), lerpf(KW, RH, u), 0)


func _beams(h: Node3D) -> void:
	var beam := mat(Color("#6B4433"), 0.9)
	var ang := atan2(RH - KW, HW)
	var len := Vector2(HW, RH - KW).length()
	for k in 6:
		var z := lerpf(-HL + 0.2, HL - 0.2, k / 5.0)
		for sx in [-1.0, 1.0]:
			var mid := Vector3(sx * HW * 0.5, (KW + RH) * 0.5, z) + Vector3(-sx * sin(ang), -cos(ang), 0) * 0.08
			put(h, box(Vector3(len, 0.14, 0.14)), beam, mid, Vector3(0, 0, -sx * ang))
		put(h, box(Vector3(0.14, KW, 0.14)), beam, Vector3(-HW + 0.07, KW * 0.5, z))
		put(h, box(Vector3(0.14, KW, 0.14)), beam, Vector3(HW - 0.07, KW * 0.5, z))
	put(h, box(Vector3(0.18, 0.18, HL * 2.0)), beam, Vector3(0, RH - 0.12, 0))
	# поперечные балки-затяжки
	for z in [-1.4, 1.4]:
		var yy := 3.05
		var xw := HW * (1.0 - (yy - KW) / (RH - KW)) * 2.0
		put(h, box(Vector3(xw, 0.14, 0.14)), beam, Vector3(0, yy, z))
	if stage >= 2:
		# гирлянда-огоньки вдоль конька и по затяжкам
		var bc := [Color("#FFD34D"), Color("#FF8FC8"), Color("#7FE3FF"), Color("#B8A2FF")]
		for z in [-1.4, 1.4]:
			var xw := HW * (1.0 - (3.05 - KW) / (RH - KW))
			var pts := []
			for i in 25:
				var s := i / 24.0
				pts.append(Vector3(lerpf(-xw, xw, s), 2.96 - sin(s * PI) * 0.22, z + 0.09))
			put(h, tube(pts, 0.007, 0.007, 4), mat(Color("#2A2040"), 0.9, 0.0, false))
			for i in range(2, 24, 3):
				var b := put(h, sphere(0.035, 8), glow_mat(bc[(i / 3) % 4], 2.0, true), (pts[i] as Vector3) + Vector3(0, -0.04, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
				anim(b, "bulb", {"p": float(i) + z, "e0": 1.5, "e1": 0.9})


# ---------- Круглое окно на луну и пещеру ----------

func _window(h: Node3D) -> void:
	var frame := mat(Color("#7A4E38"), 0.85)
	put(h, torus(WIN_R - 0.02, WIN_R + 0.1, 40), frame, WIN_C + Vector3(0, 0, 0.03), Vector3(PI / 2.0, 0, 0), Vector3(1, 1.6, 1))
	put(h, box(Vector3(0.06, WIN_R * 2.0, 0.05)), frame, WIN_C + Vector3(0, 0, 0.01))
	put(h, box(Vector3(WIN_R * 2.0, 0.06, 0.05)), frame, WIN_C + Vector3(0, 0, 0.01))
	put(h, box(Vector3(1.6, 0.08, 0.26)), mat(Color("#8E5E46"), 0.85), WIN_C + Vector3(0, -WIN_R - 0.12, 0.1))
	var sky := Shaders.material("window_sky", {"aurora": 0.0, "cave": 1.0, "hill_y": 0.72})
	put(h, quad(Vector2(4.0, 3.0)), sky, WIN_C + Vector3(0, 0.4, -1.6))
	var mp := WIN_C + Vector3(0.28, 0.25, -1.3)
	put(h, sphere(0.2, 20), mat(Color("#FFF3C9"), 1.0, 1.6, false), mp)
	halo(h, mp + Vector3(0, 0, 0.1), 1.3, Color(1.0, 0.92, 0.65, 0.35))
	# лунный луч в комнату
	var ml := SpotLight3D.new()
	ml.light_color = Color("#9DB4FF")
	ml.light_energy = 1.6
	ml.spot_range = 7.0
	ml.spot_angle = 22.0
	ml.spot_attenuation = 0.7
	ml.position = WIN_C + Vector3(0.2, 0.5, -0.8)
	h.add_child(ml)
	ml.look_at_from_position(ml.position, Vector3(0.0, 0.0, -0.2), Vector3.UP)
	_moon_spot = ml
	features.append([WIN_C + Vector3(0, 0, 0.2), 1.6, "window"])
	if stage >= 2:
		# занавески по бокам окна
		for sx in [-1.0, 1.0]:
			var c := node(h, WIN_C + Vector3(sx * (WIN_R + 0.22), 0.0, 0.12))
			anim(c, "wiggle", {"axis": Vector3.BACK, "amp": 0.03, "spd": 0.7, "p": sx})
			for k in 3:
				put(c, cyl(0.07, 0.1, 1.45, 10), mat(Color("#FF9EC6").lerp(Color("#E87FAF"), k * 0.3), 0.95), Vector3(sx * k * 0.06 - sx * 0.06, -0.05, 0), Vector3(0, 0, 0))
			put(c, torus(0.08, 0.11, 12), mat(Color("#FFD34D"), 0.5, 0.0, false), Vector3(0, -0.1, 0), Vector3(0, 0, PI / 2.0), Vector3(1, 1.4, 1))
		put(h, cyl(0.025, 0.025, 2.2, 8), mat(Color("#C9A46A"), 0.5), WIN_C + Vector3(0, 0.78, 0.13), Vector3(0, 0, PI / 2.0))


# ---------- Корзинка-лежанка и ковёр ----------

func _basket(h: Node3D) -> void:
	var rug_r := 0.95 if stage == 0 else 1.2
	if stage == 0:
		put(h, cyl(rug_r, rug_r, 0.03, 40), mat(Color("#8C7AA8"), 1.0), Vector3(0, 0.015, 0))
	else:
		var rc := [Color("#6A4A8E"), Color("#E8A0C0"), Color("#8E72C0"), Color("#F2D2B0"), Color("#9AC8E0")]
		for k in rc.size():
			var rr := rug_r - k * 0.15
			put(h, cyl(rr, rr, 0.03, 48), mat(rc[k], 1.0, 0.0, k == 0), Vector3(0, 0.016 + k * 0.003, 0))
	var b := node(h)
	casters.append(b)
	if not _geo.has("basket"):
		var prof := [Vector2(0.0, 0.0), Vector2(0.45, 0.0), Vector2(0.55, 0.12), Vector2(0.6, 0.28), Vector2(0.52, 0.28), Vector2(0.46, 0.14), Vector2(0.0, 0.14)]
		_geo["basket"] = lathe(prof, 36)
	put(b, _geo["basket"], mat(Color("#C9925A"), 0.95))
	put(b, torus(0.53, 0.65, 36), mat(Color("#D9A86A"), 0.95), Vector3(0, 0.29, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	# плетёнка: тёмные поясочки
	for y in [0.07, 0.17]:
		put(b, torus(0.5 + y * 0.45, 0.56 + y * 0.45, 36), mat(Color("#A8723E"), 0.95, 0.0, false), Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	put(b, sphere(0.48, 24), mat(Color("#FFD9C8"), 1.0), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.18, 1.0))
	# плед, свисающий через край
	put(b, sphere(0.3, 16), mat(Color("#7FC8F0"), 1.0), Vector3(-0.42, 0.26, 0.3), Vector3(0, 0.6, 0.5), Vector3(1.0, 0.18, 0.7))
	features.append([Vector3(0, 0.5, 0), 1.5, "basket"])


# ---------- Вещи чердака по ступеням ----------

func _props(h: Node3D) -> void:
	# коробки и сундук — есть всегда
	var cb := mat(Color("#D9A066"), 0.9)
	var p0 := Vector3(-2.2, 0, 2.4)
	put(h, box(Vector3(0.6, 0.45, 0.5)), cb, p0 + Vector3(0, 0.225, 0), Vector3(0, 0.3, 0))
	put(h, box(Vector3(0.45, 0.35, 0.4)), mat(Color("#C98E58"), 0.9), p0 + Vector3(0.05, 0.62, 0.02), Vector3(0, -0.2, 0))
	put(h, box(Vector3(0.12, 0.452, 0.502)), mat(Color("#E8C890"), 0.9, 0.0, false), p0 + Vector3(0, 0.225, 0), Vector3(0, 0.3, 0))
	var tr := Vector3(2.15, 0, 2.3)
	put(h, box(Vector3(0.9, 0.45, 0.5)), mat(Color("#8A4E3A"), 0.85), tr + Vector3(0, 0.225, 0), Vector3(0, -0.4, 0))
	put(h, cyl(0.25, 0.25, 0.9, 16), mat(Color("#9E5A42"), 0.85), tr + Vector3(0, 0.45, 0), Vector3(0, -0.4, PI / 2.0), Vector3(1, 1, 0.45 / 0.5))
	for k in [-0.3, 0.3]:
		put(h, box(Vector3(0.05, 0.47, 0.52)), mat(Color("#FFCB45"), 0.4, 0.1), tr + Vector3(k * cos(0.4), 0.235, k * sin(0.4)), Vector3(0, -0.4, 0))
	if stage >= 1:
		# низкая книжная полка у стенки слева
		var sp := Vector3(-HW + 0.3, 0, 0.6)
		var shelf := mat(Color("#A0694C"), 0.85)
		put(h, box(Vector3(0.36, 0.8, 1.2)), shelf, sp + Vector3(0, 0.4, 0))
		var bc := [Color("#E0556F"), Color("#5FC8FF"), Color("#FFD34D"), Color("#3DDC97"), Color("#B48CFF"), Color("#FF8A5C")]
		for row in 2:
			var z := -0.5
			var i := 0
			while z < 0.48:
				var w := 0.06 + 0.04 * hash1(i + row * 9, 41)
				var hh := 0.22 + 0.1 * hash1(i + row * 9, 42)
				put(h, box(Vector3(0.22, hh, w)), mat(bc[(i + row) % 6], 0.7), sp + Vector3(0.1, 0.06 + row * 0.38 + hh * 0.5, z + w * 0.5))
				z += w + 0.012
				i += 1
		# цветок в горшке на полке
		put(h, lathe([Vector2(0, 0), Vector2(0.09, 0), Vector2(0.12, 0.16), Vector2(0, 0.16)], 14), mat(Color("#E07A5F"), 0.8), sp + Vector3(0.05, 0.8, 0.3))
		for k in 5:
			var a := TAU * k / 5.0
			put(h, sphere(0.08, 10), mat(Color("#5BC27E"), 0.9), sp + Vector3(0.05, 1.02, 0.3) + dir(a) * 0.07, Vector3(0.4, a, 0), Vector3(0.6, 1.2, 0.5))
		# подушки на полу
		put(h, sphere(0.28, 16), mat(Color("#FF9EC6"), 1.0), Vector3(-1.3, 0.12, 1.7), Vector3(0, 0.4, 0), Vector3(1.1, 0.4, 1.0))
		put(h, sphere(0.24, 16), mat(Color("#8C63D0"), 1.0), Vector3(-1.0, 0.3, 1.85), Vector3(0.4, 0.2, 0.3), Vector3(1.0, 0.45, 0.9))
	if stage >= 3:
		# звёздный проектор: шар-ночник на табуретке
		var pp := Vector3(-0.9, 0, 0.9)
		put(h, cyl(0.16, 0.18, 0.36, 14), mat(Color("#A0694C"), 0.85), pp + Vector3(0, 0.18, 0))
		var dome := node(h, pp + Vector3(0, 0.48, 0))
		anim(dome, "spin", {"spd": 0.3})
		put(dome, sphere(0.13, 20), mat(Color("#3A2A80"), 0.4, 0.6), Vector3.ZERO)
		for k in 8:
			var a := TAU * k / 8.0
			put(dome, extrude(star_poly(0.03, 0.013), 0.01), glow_mat(Color("#FFE9A0"), 2.5), Vector3(cos(a) * 0.125, 0.03 + 0.04 * sin(k * 2.0), sin(a) * 0.125), Vector3(0, -a + PI / 2.0, 0))
		put(h, cyl(0.12, 0.14, 0.06, 14), mat(Color("#FFD34D"), 0.4, 0.2), pp + Vector3(0, 0.38, 0))
		halo(h, pp + Vector3(0, 0.48, 0), 0.8, Color(0.6, 0.6, 1.0, 0.35))
		omni(h, pp + Vector3(0, 0.7, 0), Color("#9A8CFF"), 0.5, 3.0, "pulse")


## Полочка на стене: деревянная доска на кронштейнах (у места «сверху» — длиннее, высокая полка)
func _ledge(n: Node3D, spot: String) -> void:
	var w := 0.9 if spot == "hang" else 0.62
	put(n, box(Vector3(w, 0.05, 0.32)), mat(Color("#A0694C"), 0.85), Vector3(0, 0.0, 0.16))
	put(n, box(Vector3(w, 0.015, 0.02)), mat(Color("#FFD34D"), 0.5, 0.2, false), Vector3(0, 0.0, 0.325))
	for sx in [-w * 0.35, w * 0.35]:
		put(n, prism(Vector3(0.04, 0.18, 0.22), 0.0), mat(Color("#7A4E38"), 0.85), Vector3(sx, -0.115, 0.11), Vector3(0, -PI / 2.0, 0))


# ---------- Украшения ----------

func _decor(id: String, n: Node3D, sk: String) -> void:
	match id:
		"kit_yarn": _d_yarn(n, sk)
		"kit_mouse": _d_mouse(n)
		"kit_pillow": _d_pillow(n)
		"kit_picture": _d_picture(n)
		"kit_catnip": _d_catnip(n)
		"kit_box": _d_box(n)
		"kit_scratcher": _d_scratcher(n)
		"kit_lamp": _d_lamp(n)
		"kit_aquarium": _d_aquarium(n, sk)
		"kit_tree": _d_tree(n)
		# 0.15
		"kit_tea": _d_tea(n)
		"kit_windowseat": _d_windowseat(n)
		"kit_stove": _d_stove(n)
		"kit_headphones": _d_headphones(n, sk)
		"kit_poster": _d_poster(n)
		"kit_mic": _d_mic(n)
		"kit_beanbag": _d_beanbag(n)
		"kit_vinyl": _d_vinyl(n, sk)
		"kit_amp": _d_amp(n)
		"kit_disco": _d_disco(n)
		"kit_neon": _d_neon(n, sk)
		"kit_guitar": _d_guitar(n, sk)
		"kit_drums": _d_drums(n)
		"kit_paints": _d_paints(n, sk)
		"kit_vase": _d_vase(n, sk)
		"kit_cranes": _d_cranes(n)
		"kit_plants": _d_plants(n)
		"kit_starlamp": _d_starlamp(n, sk)
		"kit_easel": _d_easel(n)
		"kit_stainedglass": _d_stainedglass(n)


func _d_yarn(n: Node3D, sk := "floor") -> void:
	var b := node(n, Vector3(0, 0.15, 0))
	anim(b, "roll", {"dx": 0.06, "r": 0.15, "spd": 0.9})
	put(b, sphere(0.15, 22), mat(Color("#FF7FB4"), 0.95))
	for k in 4:
		put(b, torus(0.135, 0.155, 28), mat(Color("#D94F8A"), 0.95, 0.0, false), Vector3.ZERO, Vector3(k * 0.8, k * 1.3, 0.4 + k * 0.5))
	# спицы
	for sx in [-1.0, 1.0]:
		put(b, cyl(0.008, 0.008, 0.42, 6), mat(Color("#C9A46A"), 0.5, 0.0, false), Vector3(0, 0.05, 0), Vector3(0, 0, sx * 0.7))
		put(b, sphere(0.02, 8), mat(Color("#FFD34D"), 0.5, 0.0, false), Vector3(-sx * sin(sx * 0.7) * 0.21, 0.05 + cos(0.7) * 0.21, 0))
	# хвостик нитки по полу (0.15: на полке — свисает через край)
	var tp := []
	for i in 10:
		var s := i / 9.0
		if sk == "ledge":
			tp.append(Vector3(0.08 + s * 0.06, 0.01 - maxf(0.0, s - 0.35) * 0.35, 0.06 + minf(s, 0.4) * 0.25))
		else:
			tp.append(Vector3(0.12 + s * 0.4, 0.01, 0.08 + sin(s * 6.0) * 0.06))
	put(n, tube(tp, 0.012, 0.012, 4), mat(Color("#FF8FC8"), 0.95, 0.0, false))


func _d_mouse(n: Node3D) -> void:
	var grey := mat(Color("#B8B0C8"), 0.95)
	var m := node(n)
	m.rotation.y = 0.8
	put(m, sphere(0.12, 18), grey, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(0.75, 0.7, 1.2))
	put(m, sphere(0.05, 12), grey, Vector3(0, 0.1, 0.13), Vector3.ZERO, Vector3(0.9, 0.9, 1.3))
	put(m, sphere(0.018, 8), mat(Color("#FF7FA4"), 0.6, 0.0, false), Vector3(0, 0.1, 0.2))
	for sx in [-1.0, 1.0]:
		put(m, cyl(0.045, 0.045, 0.012, 14), grey, Vector3(sx * 0.06, 0.17, 0.08), Vector3(PI / 2.0, 0, sx * 0.3))
		put(m, cyl(0.03, 0.03, 0.014, 12), mat(Color("#FFA3BE"), 0.8, 0.0, false), Vector3(sx * 0.06, 0.17, 0.087), Vector3(PI / 2.0, 0, sx * 0.3))
		put(m, sphere(0.013, 6), mat(OUT, 0.3, 0.0, false), Vector3(sx * 0.032, 0.125, 0.16))
	var tail := node(m, Vector3(0, 0.06, -0.13))
	anim(tail, "wiggle", {"amp": 0.4, "spd": 2.2})
	var tp := []
	for i in 9:
		var s := i / 8.0
		tp.append(Vector3(sin(s * 5.0) * 0.05 * s, 0.03 * sin(s * PI), -s * 0.26))
	put(tail, tube(tp, 0.01, 0.005, 4), mat(Color("#FF9FC0"), 0.8, 0.0, false))


func _d_pillow(n: Node3D) -> void:
	put(n, sphere(0.32, 22), mat(Color("#7FC8F0"), 1.0), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.2, 0.32, 1.0))
	for c in [Vector3(-0.35, 0.08, -0.28), Vector3(0.35, 0.08, -0.28), Vector3(0.35, 0.08, 0.28), Vector3(-0.35, 0.08, 0.28)]:
		put(n, sphere(0.035, 8), mat(Color("#FFD34D"), 0.6, 0.0, false), c)
	var fish := extrude(_fish_poly(), 0.02)
	for i in 3:
		put(n, fish, mat(Color("#FFB547"), 0.7, 0.1, false), Vector3(-0.18 + i * 0.18, 0.2, -0.05 + 0.08 * (i % 2)), Vector3(-PI / 2.0 + 0.1, 0.3 * i, 0), Vector3.ONE * 0.9)


static func _fish_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := PI * 0.15 + (TAU - PI * 0.3) * i / 13.0
		pts.append(Vector2(-cos(a) * 0.07, sin(a) * 0.04))
	pts.append(Vector2(-0.12, 0.04))
	pts.append(Vector2(-0.12, -0.04))
	return pts


func _d_picture(n: Node3D) -> void:
	put(n, cyl(0.015, 0.015, 0.05, 6), mat(Color("#8A8AA0"), 0.4), Vector3(0, 0.95, 0.02), Vector3(PI / 2.0, 0, 0))
	var rope := mat(Color("#C9B88A"), 1.0, 0.0, false)
	put(n, tube([Vector3(0, 0.95, 0.04), Vector3(-0.24, 0.78, 0.04)], 0.005, 0.005, 3), rope)
	put(n, tube([Vector3(0, 0.95, 0.04), Vector3(0.24, 0.78, 0.04)], 0.005, 0.005, 3), rope)
	put(n, extrude(rrect_poly(0.62, 0.48, 0.05), 0.05), mat(Color("#E0A84E"), 0.5), Vector3(0, 0.55, 0.04))
	put(n, quad(Vector2(0.5, 0.36)), Shaders.material("picture_fish"), Vector3(0, 0.55, 0.068))


func _d_catnip(n: Node3D) -> void:
	put(n, lathe([Vector2(0, 0), Vector2(0.13, 0), Vector2(0.17, 0.24), Vector2(0, 0.24)], 18), mat(Color("#E07A5F"), 0.8))
	put(n, torus(0.15, 0.2, 18), mat(Color("#F09A7F"), 0.8), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	put(n, cyl(0.155, 0.155, 0.02, 16), mat(Color("#4A2E22"), 1.0, 0.0, false), Vector3(0, 0.24, 0))
	var pw := node(n, Vector3(0, 0.12, 0.155))
	pw.rotation.x = -0.15
	var pm := mat(Color("#FFE0D0"), 0.8, 0.0, false)
	put(pw, sphere(0.035, 8), pm, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.9, 0.3))
	for i in 4:
		var a := lerpf(-0.9, 0.9, i / 3.0)
		put(pw, sphere(0.015, 6), pm, Vector3(sin(a) * 0.05, 0.045 + cos(a) * 0.01, 0), Vector3.ZERO, Vector3(1, 1.2, 0.3))
	for i in 7:
		var a := lerpf(-1.0, 1.0, i / 6.0)
		var st := node(n, Vector3(0, 0.24, 0))
		st.rotation = Vector3(0.3 * sin(i * 2.1), i * 0.9, a * 0.6)
		anim(st, "sway", {"amp": 0.07, "spd": 1.2, "p": float(i)})
		var ln := 0.3 + 0.1 * (i % 2)
		put(st, cyl(0.008, 0.01, ln, 5), mat(Color("#3F9A5E"), 0.9, 0.0, false), Vector3(0, ln * 0.5, 0))
		put(st, sphere(0.07, 10), mat(Color("#6FD08E"), 0.9), Vector3(0, ln, 0), Vector3(0.3, 0, 0), Vector3(0.55, 0.3, 1.0))
		put(st, sphere(0.05, 10), mat(Color("#5BC27E"), 0.9, 0.0, false), Vector3(0, ln * 0.55, 0.03), Vector3(0.5, 0, 0), Vector3(0.5, 0.3, 1.0))


func _d_box(n: Node3D) -> void:
	var cb := mat(Color("#D9A066"), 0.9)
	var cbd := mat(Color("#C48C55"), 0.9)
	var W := 0.5
	var D := 0.4
	var H := 0.3
	put(n, box(Vector3(W, 0.03, D)), cbd, Vector3(0, 0.015, 0))
	for sx in [-1.0, 1.0]:
		put(n, box(Vector3(0.025, H, D)), cb, Vector3(sx * W * 0.5, H * 0.5, 0))
		put(n, box(Vector3(W, H, 0.025)), cb, Vector3(0, H * 0.5, sx * D * 0.5))
	# клапаны
	put(n, box(Vector3(W * 0.5, 0.02, D)), cbd, Vector3(-W * 0.5 - 0.1, H + 0.05, 0), Vector3(0, 0, 0.5))
	put(n, box(Vector3(W * 0.5, 0.02, D)), cbd, Vector3(W * 0.5 + 0.1, H + 0.05, 0), Vector3(0, 0, -0.5))
	put(n, box(Vector3(0.12, H, 0.03)), mat(Color("#E8C890"), 0.9, 0.0, false), Vector3(0, H * 0.5, D * 0.5 + 0.005))
	put(n, extrude(heart_poly(0.06), 0.01), mat(Color("#FF7FA4"), 0.7, 0.1, false), Vector3(0, H * 0.55, D * 0.5 + 0.022))
	# внутри — тёмный угол и ушки, которые иногда выглядывают
	put(n, box(Vector3(W - 0.05, 0.02, D - 0.05)), mat(Color("#3A2452"), 1.0, 0.0, false), Vector3(0, H * 0.55, 0))
	var ears := node(n, Vector3(0, H, 0))
	anim(ears, "peek", {"h": 0.14, "spd": 0.7})
	for sx in [-1.0, 1.0]:
		put(ears, prism(Vector3(0.1, 0.12, 0.04)), mat(Color("#8A7A9A"), 0.9), Vector3(sx * 0.08, 0.0, 0))
		put(ears, prism(Vector3(0.05, 0.07, 0.01)), mat(Color("#FFA3BE"), 0.9, 0.0, false), Vector3(sx * 0.08, -0.015, 0.022))
	ears.visible = false


func _d_scratcher(n: Node3D) -> void:
	var plush := mat(Color("#8C63D0"), 1.0)
	put(n, box(Vector3(0.6, 0.07, 0.6)), plush, Vector3(0, 0.035, 0))
	put(n, cyl(0.085, 0.085, 0.78, 14), mat(Color("#D9B88A"), 0.95), Vector3(0, 0.46, 0))
	for i in 12:
		put(n, torus(0.078, 0.095, 16), mat(Color("#B8945E"), 0.95, 0.0, false), Vector3(0, 0.12 + i * 0.062, 0), Vector3(0.05, 0, 0.05))
	put(n, box(Vector3(0.42, 0.07, 0.42)), plush, Vector3(0, 0.88, 0))
	var sw := node(n, Vector3(0.17, 0.85, 0.17))
	anim(sw, "pendulum", {"amp": 0.35, "spd": 2.0})
	put(sw, cyl(0.004, 0.004, 0.25, 3), mat(Color("#FFF0C0"), 0.9, 0.0, false), Vector3(0, -0.125, 0))
	put(sw, sphere(0.05, 12), mat(Color("#FFD34D"), 0.7), Vector3(0, -0.27, 0))


func _d_lamp(n: Node3D) -> void:
	put(n, cyl(0.17, 0.2, 0.05, 20), mat(Color("#3A2A55"), 0.6), Vector3(0, 0.025, 0))
	put(n, cyl(0.02, 0.02, 1.0, 8), mat(Color("#C9A46A"), 0.4), Vector3(0, 0.52, 0))
	var shade := lathe([Vector2(0.28, 0.0), Vector2(0.14, 0.3), Vector2(0.13, 0.3), Vector2(0.27, 0.0)], 24)
	var sm := mat(Color("#FFB0C8"), 0.9, 0.35)
	put(n, shade, sm, Vector3(0, 0.98, 0))
	put(n, torus(0.26, 0.3, 24), mat(Color("#FF7FA4"), 0.8, 0.0, false), Vector3(0, 0.98, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	for i in 6:
		var a := TAU * i / 6.0
		put(n, sphere(0.022, 6), mat(Color("#FFD34D"), 0.5, 0.2, false), Vector3(cos(a) * 0.29, 0.95, sin(a) * 0.29))
	put(n, sphere(0.07, 12), glow_mat(Color("#FFF2C8"), 3.0), Vector3(0, 1.02, 0))
	var l := omni(n, Vector3(0, 0.95, 0.1), Color("#FFC98A"), 1.0, 3.2, "slow")
	l.name = "lamp_light"
	halo(n, Vector3(0, 1.0, 0), 1.2, Color(1.0, 0.8, 0.55, 0.3))


func _d_aquarium(n: Node3D, _sk: String) -> void:
	put(n, cyl(0.16, 0.18, 0.05, 18), mat(Color("#8C63D0"), 0.7), Vector3(0, 0.025, 0))
	var c := Vector3(0, 0.25, 0)
	put(n, sphere(0.17, 22), mat(Color("#3F8FD8"), 0.2, 0.35, false), c + Vector3(0, -0.03, 0), Vector3.ZERO, Vector3(0.95, 0.75, 0.95))
	put(n, sphere(0.2, 24), glass(Color(0.75, 0.95, 1.0, 0.25), 0.15), c)
	put(n, torus(0.1, 0.13, 20), mat(Color("#BFF0FF"), 0.3, 0.1, false), c + Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	# галька и водоросли
	for i in 6:
		var a := TAU * i / 6.0
		put(n, sphere(0.03, 6), mat([Color("#FFD34D"), Color("#FF8FC8"), Color("#9FF6FF")][i % 3], 0.6, 0.0, false), c + Vector3(cos(a) * 0.08, -0.14, sin(a) * 0.08))
	for sx in [-0.06, 0.07]:
		var w := node(n, c + Vector3(sx, -0.14, -0.03))
		anim(w, "sway", {"amp": 0.15, "spd": 1.4, "p": sx * 20.0})
		put(w, tube([Vector3.ZERO, Vector3(0.01, 0.07, 0), Vector3(-0.01, 0.15, 0)], 0.012, 0.005, 4), mat(Color("#3FAF6E"), 0.8, 0.0, false))
	# рыбка плавает по кругу
	var f := node(n, c + Vector3(0, -0.02, 0))
	var fish := node(f, Vector3(0.09, 0, 0))
	anim(f, "spin", {"spd": 0.9})
	put(fish, sphere(0.04, 12), mat(Color("#FF8A3D"), 0.5, 0.3), Vector3.ZERO, Vector3.ZERO, Vector3(0.5, 0.75, 1.0))
	put(fish, prism(Vector3(0.05, 0.05, 0.01)), mat(Color("#FF8A3D"), 0.5, 0.3, false), Vector3(0, 0, -0.05), Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		put(fish, sphere(0.008, 6), mat(OUT, 0.3, 0.0, false), Vector3(sx * 0.018, 0.01, 0.025))
	for i in 3:
		var b := put(n, sphere(0.012, 6), glass(Color(0.9, 1.0, 1.0, 0.6), 0.3), c + Vector3(0.03, 0.0, 0.02))
		anim(b, "rise", {"h": 0.14, "spd": 0.6, "p": i / 3.0})
	halo(n, c, 0.7, Color(0.5, 0.9, 1.0, 0.2))


func _d_tree(n: Node3D) -> void:
	var post := mat(Color("#D9B88A"), 0.95)
	var plush := mat(Color("#9C7BDA"), 1.0)
	put(n, box(Vector3(0.75, 0.08, 0.5)), plush, Vector3(0, 0.04, 0))
	for x in [-0.2, 0.2]:
		put(n, cyl(0.06, 0.06, 1.2, 12), post, Vector3(x, 0.6, 0))
		for i in 14:
			put(n, torus(0.055, 0.068, 12), mat(Color("#B8945E"), 0.95, 0.0, false), Vector3(x, 0.12 + i * 0.075, 0))
	# домик с круглым входом
	put(n, box(Vector3(0.44, 0.34, 0.4)), plush, Vector3(-0.08, 0.5, 0))
	put(n, cyl(0.1, 0.1, 0.02, 18), mat(Color("#3A2452"), 1.0, 0.0, false), Vector3(-0.08, 0.48, 0.2), Vector3(PI / 2.0, 0, 0))
	# полки
	put(n, box(Vector3(0.42, 0.06, 0.38)), plush, Vector3(0.12, 0.86, 0))
	put(n, sphere(0.2, 16), mat(Color("#B89CF0"), 1.0), Vector3(-0.05, 1.24, 0), Vector3.ZERO, Vector3(1.6, 0.25, 1.0))
	var sw := node(n, Vector3(0.3, 0.83, 0.1))
	anim(sw, "pendulum", {"amp": 0.3, "spd": 2.2})
	put(sw, cyl(0.004, 0.004, 0.22, 3), mat(Color("#FFF0C0"), 0.9, 0.0, false), Vector3(0, -0.11, 0))
	put(sw, sphere(0.045, 12), mat(Color("#FF7FB4"), 0.7), Vector3(0, -0.24, 0))


# ---------- 0.15: новые украшения ----------
# Начало координат — точка места: на полу (floor / near / big), на полке или подоконнике ("ledge"),
# на стене ("wall", плоская вещь), точка подвеса на балке ("hang", своя верёвка — self_hung).
# +Z — в комнату. Поворот на месте делает каркас (room.gd).

## Короткая запись материала по цвету-строке
static func _m(c: String, rough := 0.85, emit := 0.0, outline := true) -> StandardMaterial3D:
	return mat(Color(c), rough, emit, outline)


static var _shaders := {}


## Свой шейдер (код — константа в этом файле): один Shader на игру, материал — новый
static func _shader_mat(key: String, code: String, params := {}) -> ShaderMaterial:
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = code
		_shaders[key] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Пар / дымок: полупрозрачные шарики поднимаются и тают
func _steam(parent: Node3D, p: Vector3, n := 3, h := 0.25, col := Color(1, 1, 1, 0.55), size := 0.025) -> void:
	for i in n:
		var b := put(parent, sphere(size, 8), glass(col, 0.4), p)
		anim(b, "rise", {"h": h, "spd": 0.45, "p": float(i) / n})


## Нота (проигрыватель): головка, штиль, флажок; светится
func _note(parent: Node3D, p: Vector3, col: Color) -> Node3D:
	var nt := node(parent, p)
	var m := mat(col, 0.5, 1.6, false)
	put(nt, sphere(0.03, 10), m, Vector3.ZERO, Vector3(0, 0, 0.4), Vector3(1.3, 0.9, 0.5))
	put(nt, cyl(0.006, 0.006, 0.11, 4), m, Vector3(0.033, 0.055, 0))
	put(nt, prism(Vector3(0.04, 0.05, 0.01), 0.0), m, Vector3(0.05, 0.095, 0), Vector3(0, 0, -0.5))
	return nt


## Молния (плоская фигура) высотой h
static func _bolt_poly(h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0.12, 0.5), Vector2(-0.22, 0.02), Vector2(-0.02, 0.02), Vector2(-0.14, -0.5),
		Vector2(0.24, 0.06), Vector2(0.03, 0.06)])
	for i in pts.size():
		pts[i] *= h
	return pts


## Ритм: быстрое увеличение на каждую долю и мягкий спад (динамики, барабаны)
static func _beat(t: float, ph := 0.0) -> float:
	return exp(-fposmod(t * 2.0 + ph, 1.0) * 8.0)


func _a_beat(nd: Node3D, t: float, a: Dictionary) -> void:
	var s := 1.0 + float(a.get("amp", 0.1)) * _beat(t, float(a.get("p", 0.0)))
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis.from_scale(Vector3(s, s, 1.0 + (s - 1.0) * 2.0)), (a.base as Transform3D).origin)


## Светящиеся материалы по очереди ярче / тусклее
func _a_mats_twinkle(_nd: Node3D, t: float, a: Dictionary) -> void:
	var ms: Array = a.mats
	for i in ms.size():
		(ms[i] as StandardMaterial3D).emission_energy_multiplier = float(a.e0) + float(a.e1) * sin(t * float(a.get("spd", 2.2)) + i * TAU / ms.size())


func _d_tea(n: Node3D) -> void:
	put(n, extrude(rrect_poly(0.42, 0.22, 0.05), 0.02), _m("#C98A5A", 0.8), Vector3(0, 0.01, 0), Vector3(-PI / 2.0, 0, 0))
	# чайник
	var tp := node(n, Vector3(-0.08, 0.02, -0.01))
	var body := _m("#7FD8C8", 0.5)
	put(tp, lathe([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.09, 0.04), Vector2(0.095, 0.08), Vector2(0.07, 0.13), Vector2(0.0, 0.135)], 18), body)
	put(tp, sphere(0.035, 10), _m("#FFFFFF", 0.5), Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	put(tp, sphere(0.014, 8), _m("#FF8FC8", 0.5, 0.0, false), Vector3(0, 0.165, 0))
	put(tp, tube(bez(Vector3(0.07, 0.05, 0), Vector3(0.13, 0.06, 0), Vector3(0.15, 0.12, 0), 6), 0.016, 0.009, 6), body)
	put(tp, torus(0.035, 0.05, 12), body, Vector3(-0.1, 0.08, 0), Vector3(PI / 2.0, 0, 0))
	var dots := []
	for i in 8:
		var a := TAU * i / 8.0
		dots.append(Transform3D(Basis(), Vector3(cos(a) * 0.094, 0.07 + 0.02 * (i % 2), sin(a) * 0.094)))
	scatter(tp, sphere(0.01, 6), _m("#FFFFFF", 0.6, 0.0, false), dots)
	_steam(tp, Vector3(0.155, 0.13, 0), 3, 0.2)
	# две чашки на блюдцах и печенье
	for c in [[Vector3(0.1, 0.02, 0.05), "#FF9EC6"], [Vector3(0.15, 0.02, -0.05), "#FFE27A"]]:
		var cp: Vector3 = c[0]
		put(n, cyl(0.045, 0.04, 0.01, 14), _m("#FFFFFF", 0.5), cp + Vector3(0, 0.005, 0))
		put(n, cyl(0.03, 0.022, 0.045, 14), _m(c[1], 0.5), cp + Vector3(0, 0.032, 0))
		put(n, cyl(0.026, 0.026, 0.004, 12), _m("#8A5A3A", 0.3, 0.0, false), cp + Vector3(0, 0.053, 0))
		put(n, torus(0.012, 0.018, 8), _m(c[1], 0.5, 0.0, false), cp + Vector3(0.032, 0.032, 0), Vector3(PI / 2.0, 0, 0))
	for i in 3:
		var kp := Vector3(0.02 + i * 0.035, 0.024 + i * 0.008, -0.07)
		put(n, cyl(0.025, 0.025, 0.01, 12), _m("#E8A860", 0.8), kp, Vector3(0.3, 0, 0.1 * i))
		put(n, sphere(0.006, 4), _m("#5A3020", 0.8, 0.0, false), kp + Vector3(0.008, 0.007, 0.005))


func _d_windowseat(n: Node3D) -> void:
	put(n, capsule(0.09, 1.1), _m("#B8A2FF", 1.0), Vector3(0, 0.08, -0.02), Vector3(0, 0, PI / 2.0), Vector3(1, 1, 1.25))
	for i in 5:
		put(n, torus(0.085, 0.095, 14), _m("#9C84E8", 1.0, 0.0, false), Vector3(-0.4 + i * 0.2, 0.08, -0.02), Vector3(0, 0, PI / 2.0), Vector3(1, 1, 1.25))
	# подушки
	for c in [[Vector3(-0.36, 0.2, -0.04), "#FF9EC6", 0.4], [Vector3(0.33, 0.2, -0.05), "#FFE27A", -0.35]]:
		put(n, sphere(0.12, 14), _m(c[1], 1.0), c[0], Vector3(0.2, 0, c[2]), Vector3(1.0, 0.9, 0.45))
		put(n, sphere(0.018, 6), _m("#FFFFFF", 0.7, 0.0, false), (c[0] as Vector3) + Vector3(0, 0, 0.055))
	put(n, extrude(heart_poly(0.09), 0.05), _m("#FF6F9A", 0.9), Vector3(0.05, 0.2, -0.03), Vector3(-0.15, 0, 0))
	# книжка
	put(n, box(Vector3(0.16, 0.03, 0.11)), _m("#5FC8FF", 0.7), Vector3(-0.12, 0.185, 0.02), Vector3(0, 0.4, 0))
	put(n, box(Vector3(0.15, 0.025, 0.1)), _m("#FFFFFF", 0.9, 0.0, false), Vector3(-0.12, 0.186, 0.02), Vector3(0, 0.4, 0))
	# вязаный плед свисает с подоконника и покачивается
	var pl := node(n, Vector3(0.12, 0.13, 0.08))
	anim(pl, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.07, "spd": 0.9})
	put(pl, box(Vector3(0.44, 0.04, 0.12)), _m("#FF8FB1", 1.0), Vector3(0, 0, 0.02))
	put(pl, box(Vector3(0.44, 0.34, 0.03)), _m("#FF8FB1", 1.0), Vector3(0, -0.18, 0.08), Vector3(0.12, 0, 0))
	for k in 3:
		put(pl, box(Vector3(0.445, 0.04, 0.032)), _m("#FFF1DC", 1.0, 0.0, false), Vector3(0, -0.07 - k * 0.1, 0.075 + k * 0.012), Vector3(0.12, 0, 0))
	for k in 5:
		put(pl, sphere(0.022, 6), _m("#FFF1DC", 1.0, 0.0, false), Vector3(-0.18 + k * 0.09, -0.36, 0.1))


## Печка-буржуйка (★): огонь в окошке, тёплый свет, чайник с паром, дымок, корзина с дровами
func _d_stove(n: Node3D) -> void:
	var iron := _m("#3E3656", 0.5)
	var brass := _m("#E0B050", 0.35, 0.15)
	# коврик-полукруг перед печкой
	put(n, cyl(0.55, 0.55, 0.015, 32), _m("#E8705A", 0.95, 0.0, false), Vector3(0, 0.008, 0.25), Vector3.ZERO, Vector3(1.0, 1, 0.75))
	put(n, cyl(0.45, 0.45, 0.016, 32), _m("#FFC27A", 0.95, 0.0, false), Vector3(0, 0.01, 0.25), Vector3.ZERO, Vector3(1.0, 1, 0.75))
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		put(n, cyl(0.03, 0.04, 0.12, 8), iron, dir(a) * 0.2 + Vector3(0, 0.06, 0))
	put(n, cyl(0.3, 0.3, 0.04, 24), iron, Vector3(0, 0.13, 0))
	put(n, lathe([Vector2(0, 0.14), Vector2(0.26, 0.14), Vector2(0.31, 0.3), Vector2(0.33, 0.48), Vector2(0.3, 0.66), Vector2(0.23, 0.74), Vector2(0, 0.75)], 24), iron)
	for y in [0.2, 0.68]:
		put(n, torus(0.26 if y > 0.5 else 0.27, 0.3 if y > 0.5 else 0.31, 24), brass, Vector3(0, y, 0))
	put(n, cyl(0.24, 0.26, 0.04, 24), brass, Vector3(0, 0.77, 0))
	# окошко с огнём
	var door := Vector3(0, 0.44, 0.31)
	put(n, torus(0.1, 0.13, 20), brass, door, Vector3(PI / 2.0, 0, 0))
	var fire := put(n, cyl(0.1, 0.1, 0.01, 20), glow_mat(Color("#FF7A2A"), 2.6, true), door + Vector3(0, 0, -0.005), Vector3(PI / 2.0, 0, 0))
	anim(fire, "bulb", {"e0": 2.4, "e1": 0.6, "spd": 9.0})
	for i in 3:
		var f := node(n, door + Vector3(-0.04 + i * 0.04, -0.06, 0.003))
		anim(f, "flame", {"p": float(i) * 1.7})
		put(f, cyl(0.0, 0.03 - 0.005 * (i % 2), 0.1 - 0.02 * (i % 2), 6), glow_mat(Color("#FFE08A"), 3.2), Vector3(0, 0.05, 0))
	for k in 4:
		var a := k * PI / 4.0
		put(n, box(Vector3(0.006, 0.2, 0.006)), _m("#2A2440", 0.5, 0.0, false), door + Vector3(0, 0, 0.012), Vector3(0, 0, a))
	put(n, sphere(0.02, 8), brass, door + Vector3(0.12, 0, 0.02))
	halo(n, door + Vector3(0, 0, 0.12), 0.8, Color(1.0, 0.55, 0.2, 0.45))
	omni(n, door + Vector3(0, 0.05, 0.35), Color("#FF9A4A"), 1.3, 3.4, "flicker")
	# чайник на плите
	var kt := node(n, Vector3(0.08, 0.79, 0.02))
	put(kt, lathe([Vector2(0, 0), Vector2(0.09, 0), Vector2(0.1, 0.05), Vector2(0.07, 0.11), Vector2(0, 0.12)], 16), _m("#4FB8C8", 0.4))
	put(kt, tube(bez(Vector3(0.08, 0.04, 0), Vector3(0.14, 0.06, 0), Vector3(0.16, 0.11, 0), 6), 0.016, 0.009, 5), _m("#4FB8C8", 0.4))
	put(kt, tube(bez(Vector3(-0.05, 0.11, 0), Vector3(0, 0.19, 0), Vector3(0.05, 0.11, 0), 6), 0.008, 0.008, 4), _m("#2A2440", 0.5))
	_steam(kt, Vector3(0.165, 0.12, 0), 3, 0.25)
	# труба: вверх и в стену
	var pipe := _m("#2E2844", 0.45)
	put(n, cyl(0.06, 0.06, 0.72, 14), pipe, Vector3(-0.09, 1.14, -0.06))
	put(n, sphere(0.065, 12), pipe, Vector3(-0.09, 1.5, -0.06))
	put(n, cyl(0.06, 0.06, 0.5, 14), pipe, Vector3(-0.09, 1.5, -0.31), Vector3(PI / 2.0, 0, 0))
	for y in [0.9, 1.25]:
		put(n, torus(0.058, 0.072, 14), brass, Vector3(-0.09, y, -0.06))
	_steam(n, Vector3(-0.09, 1.56, -0.06), 3, 0.35, Color(0.75, 0.72, 0.85, 0.45), 0.035)
	# корзина с дровами
	var bk := Vector3(0.48, 0, 0.05)
	put(n, cyl(0.15, 0.13, 0.2, 14), _m("#C9925A", 0.95), bk + Vector3(0, 0.1, 0))
	put(n, torus(0.135, 0.165, 14), _m("#A8723E", 0.95, 0.0, false), bk + Vector3(0, 0.2, 0))
	for i in 3:
		put(n, cyl(0.04, 0.04, 0.3, 8), _m("#8A5A3A", 0.9), bk + Vector3(-0.06 + i * 0.06, 0.24 + 0.02 * (i % 2), 0), Vector3(0.3 * (i - 1), 0, PI / 2.0 - 0.15))
		put(n, cyl(0.035, 0.035, 0.302, 8), _m("#E8C28A", 0.9, 0.0, false), bk + Vector3(-0.06 + i * 0.06, 0.24 + 0.02 * (i % 2), 0), Vector3(0.3 * (i - 1), 0, PI / 2.0 - 0.15))


## Наушники с кошачьими ушками (ушки светятся)
func _d_headphones(n: Node3D, sk: String) -> void:
	var y := 0.17
	if sk == "ledge":
		put(n, cyl(0.06, 0.07, 0.03, 12), _m("#3A2A55", 0.5), Vector3(0, 0.015, 0))
		put(n, cyl(0.012, 0.012, 0.14, 6), _m("#E0B050", 0.35), Vector3(0, 0.08, 0))
	else:
		put(n, cyl(0.13, 0.15, 0.04, 16), _m("#3A2A55", 0.5), Vector3(0, 0.02, 0))
		put(n, cyl(0.016, 0.016, 0.4, 6), _m("#E0B050", 0.35), Vector3(0, 0.22, 0))
		y = 0.42
	var hp := node(n, Vector3(0, y, 0))
	anim(hp, "bob", {"amp": 0.008, "spd": 2.0})
	var arc := []
	for i in 13:
		var a := lerpf(0.0, PI, i / 12.0)
		arc.append(Vector3(cos(a) * 0.12, sin(a) * 0.12, 0))
	put(hp, tube(arc, 0.02, 0.02, 6), _m("#FF8FC8", 0.6))
	var ear := glow_mat(Color("#FF6FB4"), 1.4, true)
	anim(node(hp), "call", {"f": _a_mats_twinkle, "mats": [ear], "e0": 1.3, "e1": 0.8, "spd": 2.5})
	for sx in [-1.0, 1.0]:
		var ep := Vector3(sx * 0.075, 0.1, 0)
		put(hp, prism(Vector3(0.09, 0.1, 0.035)), _m("#FFFFFF", 0.7), ep + Vector3(0, 0.04, 0), Vector3(0, 0, -sx * 0.45))
		put(hp, prism(Vector3(0.055, 0.065, 0.04)), ear, ep + Vector3(sx * 0.004, 0.038, 0.004), Vector3(0, 0, -sx * 0.45))
		put(hp, cyl(0.07, 0.07, 0.05, 16), _m("#FFFFFF", 0.6), Vector3(sx * 0.13, -0.02, 0), Vector3(0, 0, PI / 2.0))
		put(hp, cyl(0.055, 0.055, 0.01, 16), _m("#FF8FC8", 0.6, 0.2, false), Vector3(sx * 0.157, -0.02, 0), Vector3(0, 0, PI / 2.0))
		var pw := node(hp, Vector3(sx * 0.163, -0.02, 0))
		pw.rotation.y = sx * PI / 2.0
		put(pw, sphere(0.018, 8), _m("#FFFFFF", 0.7, 0.0, false), Vector3(0, -0.008, 0), Vector3.ZERO, Vector3(1.1, 0.9, 0.3))
		for k in 3:
			put(pw, sphere(0.008, 6), _m("#FFFFFF", 0.7, 0.0, false), Vector3((k - 1) * 0.015, 0.014, 0), Vector3.ZERO, Vector3(1, 1.2, 0.3))


## Постер с молнией: тёмный лист, большая молния, звёзды, уголки на скотче (нижний уголок отклеивается)
func _d_poster(n: Node3D) -> void:
	var c := Vector3(0, 0.5, 0.02)
	put(n, box(Vector3(0.5, 0.68, 0.008)), _m("#3A2066", 0.9), c)
	put(n, box(Vector3(0.46, 0.64, 0.004)), _m("#5A2E8E", 0.9, 0.0, false), c + Vector3(0, 0, 0.005))
	put(n, extrude(_bolt_poly(0.5), 0.014), _m("#FFD34D", 0.5, 0.6), c + Vector3(0.0, 0.02, 0.012))
	put(n, extrude(_bolt_poly(0.56), 0.008), _m("#FF4FA3", 0.6, 0.3, false), c + Vector3(0.02, 0.0, 0.006))
	var stars := []
	for p in [Vector2(-0.16, 0.24), Vector2(0.17, 0.2), Vector2(-0.14, -0.2), Vector2(0.15, -0.25), Vector2(0.18, 0.02)]:
		stars.append(Transform3D(Basis(), c + Vector3(p.x, p.y, 0.01)))
	scatter(n, extrude(star_poly(0.03, 0.013), 0.006), _m("#FFFFFF", 0.5, 0.5, false), stars)
	for p in [Vector2(-0.24, 0.33), Vector2(0.24, 0.33), Vector2(-0.24, -0.33)]:
		put(n, box(Vector3(0.1, 0.035, 0.004)), _m("#F4EAD8", 0.9, 0.0, false), c + Vector3(p.x, p.y, 0.012), Vector3(0, 0, 0.7 * signf(p.x) * signf(p.y)))
	var corner := node(n, c + Vector3(0.25, -0.34, 0.01))
	anim(corner, "wiggle", {"axis": Vector3(1, 1, 0).normalized(), "amp": 0.35, "spd": 1.2})
	put(corner, prism(Vector3(0.1, 0.1, 0.006), 1.0), _m("#F4EAD8", 0.9, 0.0, false), Vector3(-0.05, 0.05, 0), Vector3(0, 0, PI))


func _d_mic(n: Node3D) -> void:
	var dark := _m("#2A2440", 0.45)
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		put(n, tube([Vector3(0, 0.12, 0), dir(a) * 0.22 + Vector3(0, 0.01, 0)], 0.012, 0.012, 5), dark)
	put(n, cyl(0.014, 0.014, 0.85, 8), _m("#D8DCEC", 0.25), Vector3(0, 0.5, 0))
	var top := node(n, Vector3(0, 0.92, 0))
	anim(top, "pendulum", {"amp": 0.08, "spd": 1.4})
	put(top, sphere(0.025, 8), dark)
	var mic := node(top, Vector3(0, 0.02, 0.02))
	mic.rotation.x = -0.6
	put(mic, cyl(0.025, 0.018, 0.16, 12), dark, Vector3(0, 0.08, 0))
	put(mic, torus(0.024, 0.032, 14), glow_mat(Color("#FF4FA3"), 2.0), Vector3(0, 0.16, 0))
	put(mic, sphere(0.05, 16), _m("#D8DCEC", 0.3), Vector3(0, 0.2, 0))
	put(mic, torus(0.045, 0.053, 16), _m("#9A9AB8", 0.3, 0.0, false), Vector3(0, 0.2, 0))
	# провод по полу
	var cp := []
	for i in 12:
		var u := i / 11.0
		cp.append(Vector3(0.02 + sin(u * 7.0) * 0.12 * u, 0.012 + (1.0 - u) * 0.1, 0.05 + u * 0.35))
	put(n, tube(cp, 0.008, 0.008, 4), _m("#1E1836", 0.6, 0.0, false))
	put(n, extrude(_bolt_poly(0.08), 0.01), _m("#FFD34D", 0.5, 0.4, false), Vector3(0, 0.55, 0.016))


## Кресло-мешок: чёрное, с молнией, мягко «дышит»
func _d_beanbag(n: Node3D) -> void:
	var b := node(n)
	anim(b, "pulse", {"amp": 0.015, "spd": 1.2})
	put(b, sphere(0.38, 22), _m("#2A2440", 0.95), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	put(b, sphere(0.3, 18), _m("#3A3256", 0.95, 0.0, false), Vector3(0, 0.33, -0.04), Vector3(-0.3, 0, 0), Vector3(1.0, 0.35, 0.9))
	put(b, sphere(0.2, 14), _m("#2A2440", 0.95), Vector3(0, 0.42, -0.22), Vector3.ZERO, Vector3(1.4, 0.8, 0.6))
	var bolt := node(b, Vector3(0.0, 0.24, 0.355))
	bolt.rotation.x = -0.25
	put(bolt, extrude(_bolt_poly(0.3), 0.02), _m("#FFD34D", 0.5, 0.45, false))
	put(b, torus(0.33, 0.38, 28), _m("#FF4FA3", 0.8, 0.0, false), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.4, 1))


## Проигрыватель: пластинка крутится, тонарм, ноты; на полу — на тумбе с пластинками
func _d_vinyl(n: Node3D, sk: String) -> void:
	var b := n
	if sk != "ledge":
		put(n, box(Vector3(0.52, 0.46, 0.38)), _m("#A0694C", 0.85), Vector3(0, 0.23, 0))
		put(n, box(Vector3(0.46, 0.36, 0.01)), _m("#7A4E38", 0.9, 0.0, false), Vector3(0, 0.22, 0.19))
		var cols := ["#FF4FA3", "#3FE0FF", "#FFD34D", "#7AE08A", "#B48CFF"]
		for i in 5:
			put(n, box(Vector3(0.02, 0.28, 0.27)), _m(cols[i], 0.7), Vector3(-0.17 + i * 0.075, 0.2, 0.03), Vector3(0, 0, 0.08 * (i - 2)))
		b = node(n, Vector3(0, 0.46, 0))
	put(b, box(Vector3(0.44, 0.09, 0.34)), _m("#C98A5A", 0.7), Vector3(0, 0.045, 0))
	put(b, box(Vector3(0.445, 0.02, 0.345)), _m("#2A2440", 0.6, 0.0, false), Vector3(0, 0.07, 0))
	var disc := node(b, Vector3(-0.05, 0.095, 0))
	anim(disc, "spin", {"spd": 3.5})
	put(disc, cyl(0.14, 0.14, 0.008, 28), _m("#1E1836", 0.25))
	for r in [0.1, 0.125]:
		put(disc, torus(r - 0.003, r, 28), _m("#3A3456", 0.3, 0.0, false), Vector3(0, 0.005, 0), Vector3.ZERO, Vector3(1, 0.2, 1))
	put(disc, cyl(0.045, 0.045, 0.01, 18), _m("#FF4FA3", 0.6), Vector3(0, 0.002, 0))
	put(disc, extrude(star_poly(0.025, 0.011), 0.004), _m("#FFD34D", 0.5, 0.3, false), Vector3(0.0, 0.008, 0), Vector3(-PI / 2.0, 0, 0))
	# тонарм
	put(b, cyl(0.02, 0.022, 0.03, 10), _m("#D8DCEC", 0.25), Vector3(0.16, 0.105, -0.11))
	put(b, tube([Vector3(0.16, 0.12, -0.11), Vector3(0.12, 0.125, 0.02), Vector3(0.05, 0.11, 0.06)], 0.006, 0.006, 4), _m("#D8DCEC", 0.25))
	put(b, box(Vector3(0.03, 0.015, 0.04)), _m("#2A2440", 0.5), Vector3(0.05, 0.105, 0.065))
	for i in 2:
		put(b, cyl(0.015, 0.015, 0.012, 8), _m("#FFD34D", 0.4, 0.3), Vector3(0.15 + i * 0.03, 0.095, 0.12))
	var cols2 := [Color("#FF6FC8"), Color("#3FE0FF"), Color("#FFE27A")]
	for i in 3:
		var nt := _note(b, Vector3(-0.1 + i * 0.08, 0.14, 0.0), cols2[i])
		anim(nt, "rise", {"h": 0.42, "spd": 0.3, "p": i / 3.0})


## Колонки: два кабинета, динамики качают в ритм, огоньки
func _d_amp(n: Node3D) -> void:
	var cab := _m("#2A2440", 0.6)
	var trim := _m("#FF4FA3", 0.6, 0.0, false)
	put(n, box(Vector3(0.5, 0.46, 0.32)), cab, Vector3(0, 0.23, 0))
	put(n, box(Vector3(0.38, 0.26, 0.28)), cab, Vector3(-0.02, 0.6, -0.01), Vector3(0, 0.12, 0))
	for y in [0.005, 0.455]:
		put(n, box(Vector3(0.51, 0.02, 0.33)), trim, Vector3(0, y + 0.005, 0))
	for p in [Vector3(-0.12, 0.23, 0.161), Vector3(0.12, 0.23, 0.161)]:
		var sp := node(n, p)
		anim(sp, "call", {"f": _a_beat, "p": p.x, "amp": 0.12})
		put(sp, cyl(0.095, 0.095, 0.01, 22), _m("#1E1836", 0.4), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
		put(sp, torus(0.085, 0.1, 22), _m("#D8DCEC", 0.3, 0.0, false), Vector3(0, 0, 0.005), Vector3(PI / 2.0, 0, 0))
		put(sp, sphere(0.04, 12), _m("#FF4FA3", 0.5, 0.4, false), Vector3(0, 0, 0.008), Vector3.ZERO, Vector3(1, 1, 0.5))
	var top := node(n, Vector3(-0.02, 0.6, -0.01))
	top.rotation.y = 0.12
	for i in 4:
		put(top, cyl(0.016, 0.016, 0.02, 10), _m("#E0B050", 0.35), Vector3(-0.12 + i * 0.07, 0.06, 0.145), Vector3(PI / 2.0, 0, 0))
	var leds := []
	for i in 6:
		leds.append(glow_mat([Color("#3FE0FF"), Color("#7AE08A"), Color("#FFE27A")][i / 2], 2.4, true))
		put(top, box(Vector3(0.03, 0.015, 0.006)), leds[i], Vector3(-0.1 + i * 0.04, -0.05, 0.142))
	anim(node(top), "call", {"f": _a_vu, "mats": leds})
	put(top, extrude(_bolt_poly(0.12), 0.008), _m("#FFD34D", 0.5, 0.4, false), Vector3(0.14, 0.0, 0.145))
	# провод
	put(n, tube(bez(Vector3(0.25, 0.1, 0.0), Vector3(0.45, 0.0, 0.1), Vector3(0.35, 0.01, 0.35), 8), 0.008, 0.008, 4), _m("#1E1836", 0.6, 0.0, false))


## Индикатор громкости: огоньки загораются по ритму
func _a_vu(_nd: Node3D, t: float, a: Dictionary) -> void:
	var ms: Array = a.mats
	var lvl := _beat(t) * 6.0 + 1.5 * absf(sin(t * 3.1))
	for i in ms.size():
		(ms[i] as StandardMaterial3D).emission_energy_multiplier = 2.6 if i < lvl else 0.15


## Диско-шар: зеркальные плитки (одна сетка, свой шейдер с бликами), вращается; зайчики — на стенах (шейдер комнаты)
const KIT_TILES := """
shader_type spatial;
render_mode cull_back;
varying float id;
void vertex() { id = float(INSTANCE_ID); }
void fragment() {
	float h = fract(sin(id * 12.9898) * 43758.5453);
	float tw = pow(max(0.0, sin(TIME * (1.5 + h * 2.0) + h * 40.0)), 12.0);
	ALBEDO = COLOR.rgb * 0.55;
	METALLIC = 0.9;
	ROUGHNESS = 0.18;
	EMISSION = COLOR.rgb * (0.15 + tw * 3.5);
}
"""


func _d_disco(n: Node3D) -> void:
	put(n, cyl(0.03, 0.04, 0.05, 10), _m("#E0B050", 0.35), Vector3(0, 0.4, 0))
	var ball := node(n, Vector3(0, 0.2, 0))
	anim(ball, "spin", {"spd": 0.6})
	ball.name = "disco_ball"
	put(ball, sphere(0.18, 16), _m("#3A3456", 0.4, 0.0, false))
	var xfs := []
	var cols := []
	var pal := [Color("#E8ECFF"), Color("#C8D0F0"), Color("#FFB0E0"), Color("#A0F0FF"), Color("#FFFFFF")]
	var rows := 9
	for r in rows:
		var lat := lerpf(-PI / 2.0 + 0.25, PI / 2.0 - 0.25, float(r) / (rows - 1))
		var nn := maxi(4, int(round(18 * cos(lat))))
		for k in nn:
			var lon := TAU * (k + 0.5 * (r % 2)) / nn
			var nrm := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var b := Basis.looking_at(nrm, Vector3.UP if absf(nrm.y) < 0.99 else Vector3.RIGHT)
			xfs.append(Transform3D(b, nrm * 0.183))
			cols.append(pal[(r * 7 + k * 3) % pal.size()])
	scatter(ball, box(Vector3(0.045, 0.045, 0.012)), _shader_mat("kit_tiles", KIT_TILES), xfs, cols)
	halo(n, Vector3(0, 0.2, 0), 0.9, Color(0.9, 0.7, 1.0, 0.3))


func _d_neon(n: Node3D, sk: String) -> void:
	var g := node(n)
	if sk == "ledge":
		put(n, box(Vector3(0.36, 0.04, 0.1)), _m("#2A2440", 0.5), Vector3(0, 0.02, 0))
		g.position = Vector3(0, -0.04, 0.0)
		g.scale = Vector3.ONE * 0.8
	var pink := glow_mat(Color("#FF4FA3"), 3.0, true)
	var yel := glow_mat(Color("#FFE27A"), 2.6, true)
	var bolt := []
	for v in _bolt_poly(0.62):
		bolt.append(Vector3(v.x, v.y, 0))
	bolt.append(bolt[0])
	put(g, tube(bolt, 0.016, 0.016, 6), pink, Vector3(0, 0.45, 0.06))
	# подставки-держатели
	for p in [Vector2(0.07, 0.3), Vector2(-0.08, -0.25), Vector2(0.1, -0.02)]:
		put(g, cyl(0.008, 0.008, 0.06, 4), _m("#C0C4D8", 0.3, 0.0, false), Vector3(p.x, 0.45 + p.y, 0.03), Vector3(PI / 2.0, 0, 0))
	for p in [Vector2(-0.22, 0.22), Vector2(0.24, -0.12)]:
		var s := []
		for v in star_poly(0.06, 0.026):
			s.append(Vector3(v.x, v.y, 0))
		s.append(s[0])
		put(g, tube(s, 0.009, 0.009, 4), yel, Vector3(p.x, 0.45 + p.y, 0.06))
	halo(g, Vector3(0, 0.45, 0.12), 0.9, Color(1.0, 0.3, 0.7, 0.35))
	var blink := node(g)
	anim(blink, "call", {"f": _a_neon, "mats": [pink, yel]})


## Неон: молния мигает сериями, звёзды — мягко пульсируют
func _a_neon(_nd: Node3D, t: float, a: Dictionary) -> void:
	var ms: Array = a.mats
	var u := fposmod(t, 3.4)
	var on := 1.0
	if u > 2.4 and u < 3.1:
		on = 0.12 if fposmod(u * 8.0, 1.0) < 0.5 else 1.0
	(ms[0] as StandardMaterial3D).emission_energy_multiplier = 3.0 * on + 0.2 * sin(t * 29.0)
	(ms[1] as StandardMaterial3D).emission_energy_multiplier = 2.0 + 0.8 * sin(t * 2.0)


## Электрогитара в форме молнии: на стене — на крючке, рядом с героем — на стойке; струны дрожат
func _d_guitar(n: Node3D, sk: String) -> void:
	var g := node(n)
	if sk == "wall":
		put(n, cyl(0.012, 0.012, 0.06, 6), _m("#C0C4D8", 0.3), Vector3(0, 0.88, 0.03), Vector3(PI / 2.0, 0, 0))
		g.position = Vector3(0, 0.08, 0.05)
	else:
		# стойка
		var st := _m("#2A2440", 0.5)
		for sx in [-1.0, 1.0]:
			put(n, tube([Vector3(sx * 0.12, 0.0, 0.1), Vector3(0, 0.12, 0.0), Vector3(sx * 0.12, 0.0, -0.12)], 0.01, 0.01, 4), st)
		put(n, tube([Vector3(0, 0.12, 0.0), Vector3(0, 0.62, -0.1)], 0.01, 0.01, 4), st)
		g.position = Vector3(0, 0.08, 0.02)
		g.rotation.x = -0.18
	var body := PackedVector2Array([Vector2(0.06, 0.4), Vector2(-0.2, 0.08), Vector2(-0.04, 0.08), Vector2(-0.16, -0.22),
		Vector2(0.2, 0.12), Vector2(0.04, 0.12), Vector2(0.16, 0.4)])
	put(g, extrude(body, 0.06), _m("#FF4FA3", 0.45), Vector3(0, 0.1, 0))
	put(g, extrude(_bolt_poly(0.28), 0.064), _m("#FFF1DC", 0.6, 0.0, false), Vector3(0.0, 0.18, 0.0))
	put(g, box(Vector3(0.05, 0.5, 0.025)), _m("#C98A5A", 0.7), Vector3(0.02, 0.72, 0.01))
	for i in 5:
		put(g, box(Vector3(0.052, 0.006, 0.027)), _m("#E0B050", 0.3, 0.0, false), Vector3(0.02, 0.55 + i * 0.08, 0.011))
	# голова с кошачьими ушками
	put(g, box(Vector3(0.09, 0.1, 0.03)), _m("#2A2440", 0.5), Vector3(0.02, 1.01, 0.01))
	for sx in [-1.0, 1.0]:
		put(g, prism(Vector3(0.04, 0.05, 0.03)), _m("#FF4FA3", 0.5), Vector3(0.02 + sx * 0.03, 1.08, 0.01))
	var strings := node(g, Vector3(0.02, 0.55, 0.035))
	anim(strings, "call", {"f": _a_strings})
	for i in 4:
		put(strings, box(Vector3(0.003, 0.95, 0.003)), _m("#F4F7FF", 0.3, 0.3, false), Vector3(-0.015 + i * 0.01, 0.0, 0))
	for i in 2:
		put(g, box(Vector3(0.07, 0.025, 0.012)), _m("#1E1836", 0.4), Vector3(0.02, 0.2 + i * 0.07, 0.035))
	for i in 3:
		put(g, cyl(0.014, 0.014, 0.012, 8), _m("#E0B050", 0.3), Vector3(0.1 + 0.01 * i, 0.08 + i * 0.04, 0.03), Vector3(PI / 2.0, 0, 0))


func _a_strings(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t, 2.4)
	var w := 1.0 + 1.6 * exp(-u * 3.0) * absf(sin(t * 60.0))
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis.from_scale(Vector3(w, 1, w)), (a.base as Transform3D).origin)


## Барабаны (★): бочка с лапкой, малый, томы, тарелки; палочки отбивают ритм; цветные прожекторы
func _d_drums(n: Node3D) -> void:
	var shell := _m("#FF4FA3", 0.35)
	var head := _m("#FFF6EE", 0.7)
	var gold := _m("#E8C050", 0.3, 0.2)
	var chrome := _m("#D8DCEC", 0.25)
	put(n, cyl(0.85, 0.85, 0.02, 36), _m("#5A2E8E", 0.95, 0.0, false), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1.0, 1, 0.8))
	put(n, cyl(0.75, 0.75, 0.022, 36), _m("#7A44B0", 0.95, 0.0, false), Vector3(0, 0.011, 0), Vector3.ZERO, Vector3(1.0, 1, 0.8))
	# бочка
	var bd := Vector3(0, 0.27, 0.05)
	put(n, cyl(0.26, 0.26, 0.26, 26), shell, bd, Vector3(PI / 2.0, 0, 0))
	for z in [-0.13, 0.13]:
		put(n, torus(0.245, 0.275, 26), gold, bd + Vector3(0, 0, z), Vector3(PI / 2.0, 0, 0))
	put(n, cyl(0.245, 0.245, 0.01, 26), head, bd + Vector3(0, 0, 0.13), Vector3(PI / 2.0, 0, 0))
	var pw := node(n, bd + Vector3(0, -0.02, 0.137))
	var pm := _m("#FF4FA3", 0.6, 0.2, false)
	put(pw, sphere(0.07, 12), pm, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.9, 0.2))
	for i in 4:
		var a := lerpf(-0.9, 0.9, i / 3.0)
		put(pw, sphere(0.03, 8), pm, Vector3(sin(a) * 0.1, 0.09 + cos(a) * 0.02, 0), Vector3.ZERO, Vector3(1, 1.2, 0.2))
	var bass := node(n, bd)
	anim(bass, "call", {"f": _a_beat, "p": 0.0, "amp": 0.05})
	# томы на бочке, малый барабан и напольный том
	var drums := [[Vector3(-0.12, 0.62, 0.0), 0.1, 0.11, Vector3(0.35, 0, 0.2)], [Vector3(0.14, 0.62, 0.0), 0.1, 0.11, Vector3(0.35, 0, -0.2)],
		[Vector3(0.38, 0.5, 0.22), 0.14, 0.09, Vector3(0.15, 0, 0)], [Vector3(-0.42, 0.36, 0.18), 0.15, 0.26, Vector3.ZERO]]
	for i in drums.size():
		var d: Array = drums[i]
		var dn := node(n, d[0])
		dn.rotation = d[3]
		var r: float = d[1]
		var hh: float = d[2]
		put(dn, cyl(r, r, hh, 20), shell)
		put(dn, cyl(r - 0.008, r - 0.008, 0.008, 20), head, Vector3(0, hh * 0.5, 0))
		put(dn, torus(r - 0.008, r + 0.012, 20), gold, Vector3(0, hh * 0.5, 0))
		if i >= 2:
			put(n, cyl(0.008, 0.008, (d[0] as Vector3).y, 5), chrome, (d[0] as Vector3) * Vector3(1, 0.5, 1) + Vector3(0.0, -hh * 0.3, 0))
	# тарелки: хай-хэт и крэш (крэш качается от удара), блестят
	var cym := glow_mat(Color("#F2C84A"), 0.35, true)
	cym.roughness = 0.25
	cym.metallic = 0.6
	var hh_p := Vector3(0.55, 0.0, -0.05)
	put(n, cyl(0.009, 0.009, 0.78, 5), chrome, hh_p + Vector3(0, 0.39, 0))
	for y in [0.76, 0.8]:
		put(n, cyl(0.13, 0.13, 0.008, 22), cym, hh_p + Vector3(0, y, 0))
	var cr_p := Vector3(-0.4, 0.0, -0.18)
	put(n, cyl(0.009, 0.009, 1.0, 5), chrome, cr_p + Vector3(0, 0.5, 0))
	var crash := node(n, cr_p + Vector3(0, 1.02, 0))
	crash.rotation.z = 0.25
	anim(crash, "call", {"f": _a_crash})
	put(crash, cyl(0.02, 0.19, 0.03, 24), cym)
	anim(node(n), "call", {"f": _a_cymbal_shine, "mat": cym})
	# палочки (невидимый барабанщик): по очереди бьют по малому и тому
	for i in 2:
		var sp := node(n, [Vector3(0.25, 0.78, -0.1), Vector3(-0.05, 0.86, -0.3)][i])
		sp.rotation.y = [0.5, -0.2][i]
		anim(sp, "call", {"f": _a_stick, "p": 0.5 * i})
		put(sp, cyl(0.008, 0.011, 0.36, 6), _m("#F2D2A0", 0.7), Vector3(0, 0, 0.18), Vector3(PI / 2.0, 0, 0))
		put(sp, sphere(0.014, 6), _m("#F2D2A0", 0.7, 0.0, false), Vector3(0, 0, 0.36))
	# табурет
	put(n, cyl(0.13, 0.13, 0.06, 16), _m("#2A2440", 0.6), Vector3(0.05, 0.42, -0.45))
	put(n, cyl(0.02, 0.03, 0.4, 6), chrome, Vector3(0.05, 0.2, -0.45))
	# прожекторы: цветные лучи сверху водят по сцене
	var beam_cols := [Color(1.0, 0.3, 0.7, 0.16), Color(0.3, 0.9, 1.0, 0.14), Color(1.0, 0.85, 0.3, 0.12)]
	for i in 3:
		var bp := node(n, Vector3(-0.5 + i * 0.5, 1.75, -0.35))
		anim(bp, "wiggle", {"axis": Vector3.BACK, "amp": 0.35, "spd": 0.7, "p": float(i) * 2.0})
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_color = beam_cols[i]
		m.disable_fog = true
		var cone := put(bp, cyl(0.03, 0.42, 1.7, 16), m, Vector3(0, -0.85, 0.15), Vector3(-0.15, 0, 0))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		put(bp, cyl(0.05, 0.07, 0.1, 10), _m("#2A2440", 0.5), Vector3(0, 0.03, 0))
		put(bp, cyl(0.045, 0.045, 0.01, 10), glow_mat(Color(beam_cols[i], 1.0), 3.0), Vector3(0, -0.025, 0))
	halo(n, Vector3(0, 0.6, 0.1), 2.0, Color(1.0, 0.4, 0.8, 0.12))


## Палочка: на долю — удар вниз, потом подъём
func _a_stick(nd: Node3D, t: float, a: Dictionary) -> void:
	var hit := _beat(t, float(a.p))
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis(Vector3.RIGHT, 0.05 + 0.65 * hit + 0.05 * sin(t * 4.0 + float(a.p) * PI)), (a.base as Transform3D).origin)


func _a_crash(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t * 0.5, 2.0)
	var w := 0.22 * exp(-u * 2.5) * sin(u * 18.0)
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis(Vector3.RIGHT, w), (a.base as Transform3D).origin)


func _a_cymbal_shine(_nd: Node3D, t: float, a: Dictionary) -> void:
	(a.mat as StandardMaterial3D).emission_energy_multiplier = 0.3 + 1.4 * _beat(t, 0.0)


## Палитра и кисти: кисточка покачивается; рядом с героем — на табуретке
func _d_paints(n: Node3D, sk: String) -> void:
	var b := n
	if sk != "ledge":
		put(n, cyl(0.17, 0.17, 0.04, 18), _m("#C98A5A", 0.8), Vector3(0, 0.36, 0))
		for i in 3:
			var a := TAU * i / 3.0
			put(n, tube([Vector3(0, 0.34, 0) + dir(a) * 0.1, Vector3(0, 0, 0) + dir(a) * 0.16], 0.014, 0.014, 4), _m("#A0694C", 0.85))
		b = node(n, Vector3(0, 0.38, 0))
	var pal := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pal.append(Vector2(cos(a) * 0.15, sin(a) * 0.11) + (Vector2(-0.03, 0.0) if i > 9 and i < 15 else Vector2.ZERO))
	put(b, extrude(pal, 0.015), _m("#E8C28A", 0.7), Vector3(-0.03, 0.01, 0.0), Vector3(-PI / 2.0, 0, 0.3))
	put(b, cyl(0.022, 0.022, 0.017, 10), _m("#8A5A3A", 0.9, 0.0, false), Vector3(-0.1, 0.012, 0.03))
	var blobs := ["#FF4FA3", "#3FE0FF", "#FFD34D", "#7AE08A", "#B48CFF"]
	for i in 5:
		var a := 0.6 + i * 0.55
		put(b, sphere(0.022, 8), mat(Color(blobs[i]), 0.4, 0.15), Vector3(-0.03 + cos(a) * 0.09, 0.02, sin(a) * 0.065), Vector3.ZERO, Vector3(1.2, 0.45, 1.0))
	# стаканчик с кистями
	var jar := Vector3(0.13, 0.0, -0.04)
	put(b, cyl(0.04, 0.036, 0.1, 14), glass(Color(0.7, 0.9, 1.0, 0.45), 0.1), jar + Vector3(0, 0.05, 0))
	put(b, cyl(0.035, 0.035, 0.04, 14), mat(Color("#7AB8FF"), 0.3, 0.2, false), jar + Vector3(0, 0.025, 0))
	for i in 3:
		var br := node(b, jar + Vector3(-0.01 + i * 0.012, 0.02, 0.0))
		br.rotation.z = -0.25 + i * 0.25
		if i == 1:
			anim(br, "wiggle", {"axis": Vector3.BACK, "amp": 0.18, "spd": 1.3})
		put(br, cyl(0.006, 0.006, 0.2, 5), _m(["#C98A5A", "#FF8FC8", "#5FC8FF"][i], 0.6), Vector3(0, 0.1, 0))
		put(br, cyl(0.005, 0.009, 0.035, 6), _m("#D8DCEC", 0.3, 0.0, false), Vector3(0, 0.215, 0))
		put(br, cyl(0.0, 0.01, 0.04, 6), mat(Color(blobs[i]), 0.5, 0.2, false), Vector3(0, 0.25, 0), Vector3(PI, 0, 0))


## Глиняная ваза: кривоватая, с цветком (на полу — большая, с веткой из трёх цветков)
func _d_vase(n: Node3D, sk: String) -> void:
	var k := 1.0 if sk == "ledge" else 1.7
	var v := node(n)
	v.scale = Vector3.ONE * k
	v.rotation.z = 0.06
	if not _geo.has("vase"):
		_geo["vase"] = lathe([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.09, 0.04), Vector2(0.1, 0.09), Vector2(0.075, 0.15), Vector2(0.045, 0.19),
			Vector2(0.05, 0.22), Vector2(0.062, 0.235), Vector2(0.0, 0.2)], 14)
	put(v, _geo["vase"], _m("#D9774A", 0.85))
	put(v, torus(0.093, 0.104, 14), _m("#7FD8C8", 0.7, 0.0, false), Vector3(0, 0.085, 0), Vector3(0.05, 0, -0.04))
	var dots := []
	for i in 6:
		var a := TAU * i / 6.0
		dots.append(Transform3D(Basis(), Vector3(cos(a) * 0.098, 0.05, sin(a) * 0.098)))
	scatter(v, sphere(0.01, 6), _m("#FFF1DC", 0.7, 0.0, false), dots)
	var count := 1 if sk == "ledge" else 3
	for i in count:
		var st := node(v, Vector3(0.0, 0.2, 0.0))
		st.rotation = Vector3(0.0, i * 2.1, (i - 1) * 0.35 if count > 1 else 0.08)
		anim(st, "sway", {"amp": 0.06, "spd": 1.0, "p": float(i)})
		var hh := 0.22 + 0.04 * i
		put(st, cyl(0.005, 0.006, hh, 5), _m("#3F9A5E", 0.9, 0.0, false), Vector3(0, hh * 0.5, 0))
		put(st, sphere(0.025, 8), _m("#5BC27E", 0.9), Vector3(0.02, hh * 0.5, 0), Vector3(0, 0, -0.6), Vector3(1.4, 0.4, 0.7))
		var fh := node(st, Vector3(0, hh, 0))
		fh.rotation.x = -0.4
		var pc: Color = [Color("#FFFFFF"), Color("#FF9EC6"), Color("#FFE27A")][i]
		for p in 7:
			var a := TAU * p / 7.0
			put(fh, sphere(0.018, 6), mat(pc, 0.7, 0.1, false), Vector3(cos(a) * 0.024, 0, sin(a) * 0.024), Vector3.ZERO, Vector3(1.2, 0.4, 0.7))
		put(fh, sphere(0.014, 6), _m("#FFB547", 0.6, 0.0, false), Vector3(0, 0.006, 0))


## Бумажные журавлики: мобиль на балке — крестовина вращается, журавлики качаются
func _crane(parent: Node3D, col: Color) -> void:
	var m := mat(col, 0.8)
	put(parent, prism(Vector3(0.06, 0.04, 0.09)), m, Vector3.ZERO, Vector3(PI, 0, 0))
	for sx in [-1.0, 1.0]:
		var w := node(parent, Vector3(sx * 0.01, 0.0, 0))
		anim(w, "wiggle", {"axis": Vector3.BACK, "amp": 0.25, "spd": 2.2, "p": sx})
		put(w, extrude(PackedVector2Array([Vector2(0, 0.0), Vector2(sx * 0.11, 0.04), Vector2(sx * 0.02, -0.04)]), 0.004), m, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	put(parent, cyl(0.002, 0.008, 0.08, 4), m, Vector3(0, 0.03, 0.06), Vector3(-0.8, 0, 0))
	put(parent, cyl(0.0, 0.008, 0.02, 4), m, Vector3(0, 0.06, 0.09), Vector3(PI / 2.0 + 0.4, 0, 0))
	put(parent, cyl(0.002, 0.008, 0.08, 4), m, Vector3(0, 0.03, -0.06), Vector3(0.8, 0, 0))


func _d_cranes(n: Node3D) -> void:
	var thread := _m("#F4EAD8", 1.0, 0.0, false)
	put(n, cyl(0.002, 0.002, 0.25, 3), thread, Vector3(0, -0.125, 0))
	var cross := node(n, Vector3(0, -0.25, 0))
	anim(cross, "spin", {"spd": 0.3})
	put(cross, sphere(0.02, 8), _m("#E0B050", 0.4), Vector3.ZERO)
	for i in 2:
		put(cross, cyl(0.007, 0.007, 0.56, 6), _m("#C98A5A", 0.8), Vector3.ZERO, Vector3(PI / 2.0, i * PI / 2.0, 0))
	var cols := [Color("#FF9EC6"), Color("#9FE8D8"), Color("#FFE27A"), Color("#9FD8FF"), Color("#C8B0FF")]
	for i in 5:
		var a := i * PI / 2.0
		var p := Vector3(cos(a), 0, sin(a)) * 0.27 if i < 4 else Vector3.ZERO
		var ln := 0.18 + 0.08 * (i % 2) + (0.16 if i == 4 else 0.0)
		put(cross, cyl(0.0015, 0.0015, ln, 3), thread, p + Vector3(0, -ln * 0.5, 0))
		var c := node(cross, p + Vector3(0, -ln - 0.02, 0))
		c.rotation.y = a + PI / 2.0
		anim(c, "bob", {"amp": 0.015, "spd": 1.3, "p": float(i)})
		_crane(c, cols[i])


## Цветы в горшках: суккулент, высокое растение с листьями, ампельный цветок со свисающими плетями
func _d_plants(n: Node3D) -> void:
	var pots := [[Vector3(-0.2, 0, 0.0), "#F4F0FA", "#7FB8F0"], [Vector3(0.0, 0, -0.02), "#D9774A", "#F09A6A"], [Vector3(0.2, 0, 0.01), "#FFD34D", "#FFF1DC"]]
	for i in 3:
		var p: Vector3 = pots[i][0]
		put(n, lathe([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.065, 0.1), Vector2(0.0, 0.1)], 14), _m(pots[i][1], 0.7), p)
		put(n, torus(0.058, 0.072, 14), _m(pots[i][2], 0.7, 0.0, false), p + Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		put(n, cyl(0.058, 0.058, 0.01, 12), _m("#4A2E22", 1.0, 0.0, false), p + Vector3(0, 0.097, 0))
	# суккулент
	var sp: Vector3 = pots[0][0] + Vector3(0, 0.1, 0)
	for k in 9:
		var a := TAU * k / 9.0
		put(n, sphere(0.03, 8), _m("#7FD0A0", 0.8), sp + Vector3(cos(a) * 0.03, 0.02, sin(a) * 0.03), Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), Vector3(0.7, 1.3, 0.5))
	put(n, sphere(0.025, 8), _m("#9FE8B8", 0.8), sp + Vector3(0, 0.035, 0))
	# высокое — листья колышутся
	var tp: Vector3 = pots[1][0] + Vector3(0, 0.1, 0)
	for k in 6:
		var lf := node(n, tp)
		lf.rotation = Vector3(0.0, k * 1.05, 0.35 + 0.1 * (k % 2))
		anim(lf, "sway", {"amp": 0.08, "spd": 1.1, "p": float(k)})
		put(lf, cyl(0.004, 0.005, 0.2, 4), _m("#3F9A5E", 0.9, 0.0, false), Vector3(0, 0.1, 0))
		put(lf, sphere(0.05, 8), _m("#4FB868", 0.85), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(0.5, 1.2, 0.18))
	# ампельный: плети свисают за край, розовые цветочки
	var hp: Vector3 = pots[2][0] + Vector3(0, 0.1, 0)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var vine := node(n, hp)
		anim(vine, "sway", {"amp": 0.04, "spd": 0.9, "p": float(k) * 1.3})
		var pts := [Vector3.ZERO, dir(a) * 0.08 + Vector3(0, 0.03, 0), dir(a) * 0.11 + Vector3(0, -0.08, 0), dir(a) * 0.12 + Vector3(0, -0.18, 0)]
		put(vine, tube(pts, 0.004, 0.003, 4), _m("#3F9A5E", 0.9, 0.0, false))
		for j in 3:
			var q: Vector3 = pts[j + 1]
			put(vine, sphere(0.022, 6), _m("#5BC27E", 0.85, 0.0, false), q, Vector3.ZERO, Vector3(1.0, 0.5, 0.8))
			if j % 2 == 0:
				put(vine, sphere(0.016, 6), mat(Color("#FF8FC8"), 0.6, 0.2, false), q + Vector3(0.01, 0.015, 0.01))


## Звёздный проектор: купол со звёздами вращается; звёзды на потолке рисует шейдер комнаты
func _d_starlamp(n: Node3D, sk: String) -> void:
	var b := n
	if sk != "ledge":
		put(n, cyl(0.17, 0.19, 0.04, 18), _m("#A0694C", 0.85), Vector3(0, 0.38, 0))
		put(n, cyl(0.03, 0.04, 0.36, 8), _m("#A0694C", 0.85), Vector3(0, 0.18, 0))
		put(n, cyl(0.14, 0.16, 0.03, 16), _m("#A0694C", 0.85), Vector3(0, 0.015, 0))
		b = node(n, Vector3(0, 0.4, 0))
	put(b, cyl(0.11, 0.13, 0.07, 18), _m("#FFD34D", 0.4, 0.2), Vector3(0, 0.035, 0))
	var dome := node(b, Vector3(0, 0.15, 0))
	dome.name = "star_dome"
	anim(dome, "spin", {"spd": 0.3})
	put(dome, sphere(0.12, 20), _m("#3A2A80", 0.4, 0.6))
	var xfs := []
	for k in 10:
		var a := TAU * k / 10.0
		var y := 0.03 + 0.05 * sin(k * 2.0)
		var nrm := Vector3(cos(a) * 0.115, y, sin(a) * 0.115)
		xfs.append(Transform3D(Basis(Vector3.UP, -a + PI / 2.0), nrm))
	scatter(dome, extrude(star_poly(0.028, 0.012), 0.01), glow_mat(Color("#FFE9A0"), 2.5), xfs)
	put(dome, extrude(star_poly(0.04, 0.018), 0.012), glow_mat(Color("#FFE9A0"), 2.8), Vector3(0, 0.125, 0), Vector3(-PI / 2.0, 0, 0))
	halo(b, Vector3(0, 0.15, 0), 0.8, Color(0.6, 0.6, 1.0, 0.35))


## Картина на мольберте «дорисовывается»: три картинки сменяют друг друга (свой шейдер), кисть ходит по холсту
const KIT_CANVAS := """
shader_type spatial;
uniform float period = 7.0;
float sd_ell(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float sd_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a, e1 = c - b, e2 = a - c;
	vec2 v0 = p - a, v1 = p - b, v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))), vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}
vec3 picture(int k, vec2 p, float aa) {
	vec3 ink = vec3(0.16, 0.1, 0.25);
	vec3 c;
	if (k == 0) {
		// рыбка в море
		c = mix(vec3(0.45, 0.75, 1.0), vec3(0.25, 0.5, 0.9), p.y + 0.5);
		float f = sd_ell(p, vec2(-0.05, 0.0), vec2(0.22, 0.14));
		f = min(f, sd_tri(p, vec2(0.12, 0.0), vec2(0.32, 0.13), vec2(0.32, -0.13)));
		c = mix(c, ink, smoothstep(aa, -aa, f - 0.02));
		c = mix(c, vec3(1.0, 0.55, 0.25), smoothstep(aa, -aa, f));
		c = mix(c, ink, smoothstep(aa, -aa, length(p - vec2(-0.16, 0.03)) - 0.025));
		for (int i = 0; i < 3; i++) {
			float b = length(p - vec2(-0.3 + float(i) * 0.04, 0.12 + float(i) * 0.1)) - 0.025 - 0.008 * float(i);
			c = mix(c, vec3(0.9, 0.97, 1.0), smoothstep(aa, -aa, abs(b) - 0.006));
		}
	} else if (k == 1) {
		// мордочка котика
		c = vec3(1.0, 0.85, 0.9);
		float h = sd_ell(p, vec2(0.0, -0.05), vec2(0.26, 0.21));
		h = min(h, sd_tri(p, vec2(-0.24, 0.05), vec2(-0.2, 0.33), vec2(-0.05, 0.14)));
		h = min(h, sd_tri(p, vec2(0.24, 0.05), vec2(0.2, 0.33), vec2(0.05, 0.14)));
		c = mix(c, ink, smoothstep(aa, -aa, h - 0.02));
		c = mix(c, vec3(1.0, 0.72, 0.4), smoothstep(aa, -aa, h));
		for (int s = -1; s <= 1; s += 2) {
			c = mix(c, ink, smoothstep(aa, -aa, sd_ell(p, vec2(float(s) * 0.09, 0.0), vec2(0.035, 0.05))));
			c = mix(c, vec3(1.0, 0.55, 0.65), smoothstep(aa, -aa, sd_ell(p, vec2(float(s) * 0.14, -0.1), vec2(0.04, 0.025))));
		}
		c = mix(c, vec3(1.0, 0.45, 0.6), smoothstep(aa, -aa, sd_tri(p, vec2(-0.025, -0.06), vec2(0.025, -0.06), vec2(0.0, -0.09))));
	} else {
		// домик под луной
		c = mix(vec3(0.15, 0.12, 0.4), vec3(0.35, 0.25, 0.6), p.y + 0.5);
		c = mix(c, vec3(1.0, 0.95, 0.7), smoothstep(aa, -aa, length(p - vec2(0.22, 0.25)) - 0.08));
		c = mix(c, vec3(0.3, 0.7, 0.45), smoothstep(aa, -aa, p.y + 0.22));
		float hs = max(abs(p.x + 0.05) - 0.14, abs(p.y + 0.12) - 0.12);
		c = mix(c, vec3(1.0, 0.8, 0.55), smoothstep(aa, -aa, hs));
		c = mix(c, vec3(0.9, 0.35, 0.45), smoothstep(aa, -aa, sd_tri(p, vec2(-0.23, 0.0), vec2(0.13, 0.0), vec2(-0.05, 0.17))));
		c = mix(c, vec3(1.0, 0.9, 0.4), smoothstep(aa, -aa, max(abs(p.x + 0.05) - 0.035, abs(p.y + 0.12) - 0.035)));
	}
	return c;
}
void fragment() {
	vec2 p = UV - 0.5;
	p.y = -p.y;
	float aa = fwidth(p.x) * 1.3;
	float t = TIME / period;
	int k = int(mod(floor(t), 3.0));
	float u = fract(t);
	// мазки кисти: картина проявляется рядами (зигзагом), в конце немного стоит готовой
	float row = floor((0.5 - p.y) * 6.0);
	float along = mod(row, 2.0) < 0.5 ? (p.x + 0.5) : (0.5 - p.x);
	float prog = (row + along) / 6.0;
	float shown = step(prog, u * 1.35);
	vec3 canvas = vec3(0.98, 0.96, 0.92);
	vec3 col = mix(canvas, picture(k, p, aa), shown);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = col * 0.08;
}
"""


func _d_easel(n: Node3D) -> void:
	var wood := _m("#C98A5A", 0.8)
	for sx in [-1.0, 1.0]:
		put(n, tube([Vector3(sx * 0.22, 0.0, 0.1), Vector3(sx * 0.04, 1.2, 0.0)], 0.018, 0.016, 5), wood)
	put(n, tube([Vector3(0, 0.0, -0.32), Vector3(0, 1.1, -0.02)], 0.016, 0.014, 5), wood)
	put(n, box(Vector3(0.5, 0.03, 0.08)), wood, Vector3(0, 0.48, 0.07))
	put(n, box(Vector3(0.52, 0.02, 0.02)), _m("#A0694C", 0.85, 0.0, false), Vector3(0, 0.5, 0.1))
	var cv := node(n, Vector3(0, 0.75, 0.05))
	cv.rotation.x = -0.08
	put(cv, box(Vector3(0.5, 0.42, 0.025)), _m("#F4EAD8", 0.9), Vector3.ZERO)
	put(cv, quad(Vector2(0.46, 0.38)), _shader_mat("kit_canvas", KIT_CANVAS), Vector3(0, 0, 0.014))
	put(cv, box(Vector3(0.52, 0.025, 0.04)), wood, Vector3(0, 0.22, 0.0))
	# кисть ходит по холсту зигзагом (в такт шейдеру)
	var br := node(cv, Vector3(0, 0, 0.05))
	anim(br, "call", {"f": _a_brush})
	put(br, cyl(0.006, 0.006, 0.2, 5), _m("#FF8FC8", 0.6), Vector3(0.05, 0.07, 0.03), Vector3(0.5, 0, -0.6))
	put(br, cyl(0.0, 0.01, 0.035, 6), mat(Color("#3FE0FF"), 0.5, 0.3, false), Vector3(0.0, 0.0, 0.0), Vector3(0.5 + PI, 0, -0.6))
	# баночки с краской у ножек
	for i in 3:
		var p := Vector3(-0.2 + i * 0.1, 0.0, 0.25)
		put(n, cyl(0.035, 0.035, 0.06, 12), _m("#FFFFFF", 0.6), p + Vector3(0, 0.03, 0))
		put(n, cyl(0.032, 0.032, 0.004, 12), mat([Color("#FF4FA3"), Color("#FFD34D"), Color("#3FE0FF")][i], 0.4, 0.3, false), p + Vector3(0, 0.061, 0))


func _a_brush(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t / 7.0, 1.0) * 1.35
	var prog := clampf(u, 0.0, 1.0) * 6.0
	var row := floorf(minf(prog, 5.99))
	var along := prog - row
	var x := (along - 0.5) if int(row) % 2 == 0 else (0.5 - along)
	var y := 0.5 - (row + 0.5) / 6.0
	var o: Vector3 = (a.base as Transform3D).origin
	nd.position = o + Vector3(x * 0.42, y * 0.36, 0.0)
	nd.visible = u < 1.02


## Витражное окно (★): стекло-витраж в круглом окне, цветные лучи на пол меняют цвет
const KIT_STAINED := """
shader_type spatial;
render_mode cull_disabled;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
vec3 glass_col(vec2 p, float t) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float seg = floor((a + 3.14159) / 6.28318 * 8.0);
	float ring = r < 0.32 ? 0.0 : (r < 0.7 ? 1.0 : 2.0);
	float h = fract(seg * 0.125 + ring * 0.37 + t * 0.03);
	vec3 c = hue(h) * 0.75 + 0.25;
	if (r < 0.16) c = vec3(1.0, 0.85, 0.35);
	return c;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float t = TIME;
	{
		float r = length(p);
		float a = atan(p.y, p.x);
		float aa = fwidth(r) * 1.5;
		vec3 c = glass_col(p, t);
		float lead = smoothstep(aa, -aa, abs(fract((a + 3.14159) / 6.28318 * 8.0 + 0.5) - 0.5) * r * 6.28318 / 8.0 - 0.012);
		lead = max(lead, smoothstep(aa, -aa, abs(r - 0.32) - 0.014));
		lead = max(lead, smoothstep(aa, -aa, abs(r - 0.7) - 0.014));
		lead = max(lead, smoothstep(aa, -aa, abs(r - 0.16) - 0.012));
		c = mix(c, vec3(0.12, 0.08, 0.18), lead);
		if (r > 1.0) discard;
		ALBEDO = c * 0.4;
		EMISSION = c * (1.3 + 0.25 * sin(t * 1.5)) * (1.0 - lead);
		ROUGHNESS = 0.2;
	}
}
"""


func _d_stainedglass(n: Node3D) -> void:
	# вещь всегда смотрит в комнату и стоит в окне, даже если её повернули: снимаем поворот места
	var fix := node(n)
	fix.rotation.y = -n.rotation.y
	var wc := Vector3(0, WIN_R + 0.08, -0.115)
	var disc := put(fix, quad(Vector2(WIN_R * 2.0, WIN_R * 2.0)), _shader_mat("kit_stained", KIT_STAINED), wc)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(fix, torus(WIN_R - 0.03, WIN_R + 0.04, 40), _m("#E0B050", 0.35, 0.2), wc + Vector3(0, 0, 0.02), Vector3(PI / 2.0, 0, 0))
	put(fix, torus(0.07, 0.1, 16), _m("#E0B050", 0.35, 0.2), wc + Vector3(0, 0, 0.02), Vector3(PI / 2.0, 0, 0))
	halo(fix, wc + Vector3(0, 0, 0.2), 2.2, Color(1.0, 0.8, 0.95, 0.22))
	# лучи: от окна к пятну на полу (две «плоскости» крест-накрест), цвет — витража
	var floor_p := Vector3(0, -(WIN_C.y - WIN_R - 0.08) + 0.012, 2.0)
	var bm := _shader_mat("kit_patch", KIT_PATCH)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := wc
	for k in 2:
		var side := Vector3(1, 0, 0) if k == 0 else Vector3(0.0, 0.55, 0.0)
		var w0 := WIN_R * 0.85
		var w1 := 0.75
		var a := top - side * w0
		var b := top + side * w0
		var c := floor_p + Vector3(1, 0, 0) * w1 * (1.0 if k == 0 else 0.0) + (Vector3(0, 0, 0.45) if k == 1 else Vector3.ZERO)
		var d := floor_p - Vector3(1, 0, 0) * w1 * (1.0 if k == 0 else 0.0) - (Vector3(0, 0, 0.45) if k == 1 else Vector3.ZERO)
		for v in [[a, Vector2(0, 0), 0.5], [b, Vector2(1, 0), 0.5], [c, Vector2(1, 1), 0.0], [a, Vector2(0, 0), 0.5], [c, Vector2(1, 1), 0.0], [d, Vector2(0, 1), 0.0]]:
			st.set_color(Color(1, 1, 1, v[2]))
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var beam_mi := put(fix, st.commit(), _beam_mat())
	beam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# пятно на полу: витраж, растянутый по полу
	var patch := put(fix, quad(Vector2(1.6, 1.25)), bm, floor_p, Vector3(-PI / 2.0, 0, 0))
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Пятно витража на полу: прибавляется к картинке, к краю тает, цвета — как у стекла
const KIT_PATCH := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float seg = floor((a + 3.14159) / 6.28318 * 8.0);
	float ring = r < 0.32 ? 0.0 : (r < 0.7 ? 1.0 : 2.0);
	vec3 c = hue(fract(seg * 0.125 + ring * 0.37 + TIME * 0.03)) * 0.75 + 0.25;
	if (r < 0.16) { c = vec3(1.0, 0.85, 0.35); }
	ALBEDO = c * smoothstep(1.0, 0.6, r) * 0.38;
}
"""


## Луч света: прибавляется к картинке, тает к полу, цвет медленно меняется
const KIT_BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	float seg = floor(UV.x * 5.0);
	vec3 c = hue(fract(seg * 0.2 + TIME * 0.03)) * 0.6 + 0.4;
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	ALBEDO = c * COLOR.a * edge * 0.32;
}
"""


func _beam_mat() -> ShaderMaterial:
	return _shader_mat("kit_beam", KIT_BEAM)


# ---------- 0.15: стиль комнаты — узоры стен и пола, настроения света ----------
# Пол и стены чердака — одна сетка со своим шейдером (KIT_SHELL): узор выбирается параметром (обои в цветочек,
# кирпич, ночное небо; вязаный коврик, шахматная плитка, брызги краски). Свет — свои огоньки / лучи (узлы
# строятся при первом выборе). Звёзды проектора и зайчики диско-шара рисует тот же шейдер стен.

const KIT_SHELL := """
shader_type spatial;
uniform float stars = 0.0;
uniform vec3 proj = vec3(0.0, 0.6, 0.0);
uniform float rough = 0.9;
uniform vec3 wall_tint = vec3(1.0);
uniform vec3 floor_tint = vec3(1.0);
uniform float wall_mode = 0.0;
uniform float floor_mode = 0.0;
uniform float disco = 0.0;
uniform vec3 disco_p = vec3(0.0, 2.3, -1.4);
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec3 floral(vec2 uv, float aa) {
	vec3 base = mix(vec3(0.97, 0.84, 0.88), vec3(1.0, 0.93, 0.87), step(0.5, fract(uv.x * 2.2)));
	vec2 g = uv * 2.2;
	if (mod(floor(g.y), 2.0) > 0.5) { g.x += 0.5; }
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	float r = length(f);
	float a = atan(f.y, f.x);
	vec3 pc = h < 0.25 ? vec3(1.0, 0.58, 0.72) : (h < 0.5 ? vec3(1.0, 0.74, 0.52) : (h < 0.75 ? vec3(0.76, 0.64, 1.0) : vec3(0.58, 0.8, 1.0)));
	vec2 lf = f - vec2(0.17, -0.15);
	lf = vec2(lf.x * 0.8 + lf.y * 0.6, -lf.x * 0.6 + lf.y * 0.8);
	float leaf = length(lf / vec2(0.11, 0.05)) - 1.0;
	vec3 c = mix(base, vec3(0.45, 0.75, 0.5), smoothstep(0.08, -0.08, leaf));
	float pet = r - 0.16 * (0.72 + 0.28 * cos(5.0 * a + h * 6.0));
	c = mix(c, pc * 0.75, smoothstep(aa * 2.2, -aa * 2.2, pet - 0.012));
	c = mix(c, pc, smoothstep(aa * 2.2, -aa * 2.2, pet));
	c = mix(c, vec3(1.0, 0.85, 0.35), smoothstep(aa * 2.2, -aa * 2.2, r - 0.045));
	vec2 dd = fract(g + 0.5) - 0.5;
	c = mix(c, vec3(1.0, 0.75, 0.82), smoothstep(aa * 2.2, -aa * 2.2, length(dd) - 0.025));
	return c;
}
vec3 brick(vec2 uv, float aa) {
	float row = floor(uv.y / 0.12);
	float x = uv.x / 0.27 + 0.5 * mod(row, 2.0);
	vec2 id = vec2(floor(x), row);
	float fx = fract(x);
	float fy = fract(uv.y / 0.12);
	float h = hash(id);
	vec3 b = mix(vec3(0.78, 0.38, 0.32), vec3(0.92, 0.55, 0.42), h);
	if (h > 0.86) { b = vec3(0.95, 0.68, 0.6); }
	b *= 0.92 + 0.08 * hash(floor(uv * 40.0));
	float m = max(smoothstep(0.045, 0.02, fx) + smoothstep(0.955, 0.98, fx), smoothstep(0.1, 0.06, fy));
	return mix(b, vec3(0.88, 0.82, 0.8), clamp(m, 0.0, 1.0));
}
vec3 night(vec2 uv, float aa, out vec3 em) {
	vec3 c = mix(vec3(0.07, 0.07, 0.22), vec3(0.2, 0.11, 0.36), smoothstep(0.0, 3.8, uv.y));
	vec2 g = uv * 7.0;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	em = vec3(0.0);
	if (h > 0.55) {
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float d = length(f - o * 0.6);
		float tw = 0.55 + 0.45 * sin(TIME * (1.0 + h * 2.0) + h * 40.0);
		float s = smoothstep(0.06 + 0.06 * hash(id + 1.3), 0.0, d);
		vec2 q = abs(f - o * 0.6);
		s += smoothstep(0.02, 0.0, min(q.x, q.y)) * smoothstep(0.25, 0.0, max(q.x, q.y)) * step(0.9, h);
		vec3 sc = mix(vec3(1.0, 0.92, 0.65), vec3(0.65, 0.8, 1.0), fract(h * 7.0));
		c += sc * s * 0.6;
		em = sc * s * tw * 1.6;
	}
	return c;
}
void fragment() {
	vec3 n = normalize(wn);
	bool is_floor = wp.y < 0.03 && n.y > 0.7;
	bool gable = abs(n.z) > 0.7;
	bool side = abs(n.x) > 0.7;
	vec3 col = COLOR.rgb;
	vec3 em = vec3(0.0);
	float rgh = rough;
	if (is_floor) {
		vec2 uv = wp.xz;
		float aa = fwidth(uv.x);
		if (floor_mode > 0.5 && floor_mode < 1.5) {
			// вязаный коврик во весь пол (по краю — доски)
			vec2 e = abs(uv) - vec2(2.35, 2.75);
			float edge = length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - 0.25;
			if (edge < 0.0) {
				vec2 g = uv * vec2(9.0, 7.0);
				vec2 f = fract(g);
				float band = floor(uv.y * 1.6);
				vec3 pal[5] = vec3[5](vec3(1.0, 0.62, 0.74), vec3(0.98, 0.93, 0.84), vec3(0.6, 0.86, 0.76), vec3(0.76, 0.66, 0.96), vec3(1.0, 0.76, 0.56));
				vec3 yc = pal[int(mod(band + 50.0, 5.0))];
				if (edge > -0.18) { yc = vec3(0.86, 0.45, 0.62); }
				vec2 p1 = f - vec2(0.3, 0.5);
				p1 = vec2(p1.x * 0.88 + p1.y * 0.47, -p1.x * 0.47 + p1.y * 0.88);
				vec2 p2 = f - vec2(0.7, 0.5);
				p2 = vec2(p2.x * 0.88 - p2.y * 0.47, p2.x * 0.47 + p2.y * 0.88);
				float d = min(length(p1 / vec2(0.2, 0.46)), length(p2 / vec2(0.2, 0.46)));
				col = yc * (0.62 + 0.38 * smoothstep(1.05, 0.2, d));
				rgh = 1.0;
			}
		} else if (floor_mode > 1.5 && floor_mode < 2.5) {
			// шахматная плитка
			vec2 t = uv / 0.5;
			vec2 f = fract(t);
			float ch = mod(floor(t.x) + floor(t.y), 2.0);
			vec3 tc = ch < 0.5 ? vec3(0.96, 0.92, 0.86) : vec3(0.52, 0.4, 0.68);
			tc *= 0.94 + 0.06 * hash(floor(t));
			float gr = smoothstep(0.035, 0.02, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
			float bev = smoothstep(0.12, 0.0, min(f.x, f.y)) * 0.08;
			col = mix(tc + bev, vec3(0.32, 0.26, 0.38), gr);
			rgh = 0.35;
		} else if (floor_mode > 2.5) {
			// брызги краски на досках
			vec2 g = uv / 0.9;
			vec2 id = floor(g);
			vec2 f = fract(g) - 0.5;
			float h = hash(id);
			if (h > 0.25) {
				vec2 o = (vec2(hash(id + 2.3), hash(id + 5.1)) - 0.5) * 0.3;
				vec2 q = f - o;
				float a = atan(q.y, q.x);
				float rad = (0.1 + 0.12 * hash(id + 9.0)) * (1.0 + 0.22 * sin(a * 7.0 + h * 20.0) + 0.1 * sin(a * 13.0 + h * 9.0));
				float bl = length(q) - rad;
				for (int i = 0; i < 4; i++) {
					float ang = h * 30.0 + float(i) * 1.7;
					vec2 dp = o + vec2(cos(ang), sin(ang)) * (rad + 0.05 + 0.06 * hash(id + float(i)));
					bl = min(bl, length(f - dp) - 0.02 - 0.015 * hash(id + float(i) + 4.0));
				}
				vec3 pc = hue(fract(h * 5.3)) * 0.75 + 0.3;
				col = mix(col, pc, smoothstep(aa * 2.0, -aa * 2.0, bl));
				rgh = mix(rgh, 0.4, smoothstep(aa * 2.0, -aa * 2.0, bl));
			}
		}
		col *= floor_tint;
	} else {
		vec2 uv = gable ? wp.xy : vec2(wp.z, wp.y);
		float aa = fwidth(uv.x) + fwidth(uv.y);
		bool paper = (gable && wp.y > 0.62) || side;
		if (wall_mode > 0.5 && wall_mode < 1.5 && paper) {
			col = floral(uv, aa);
		} else if (wall_mode > 1.5 && wall_mode < 2.5 && paper) {
			col = brick(uv, aa);
		} else if (wall_mode > 2.5 && (paper || !gable)) {
			vec3 e2;
			col = night(vec2(uv.x, wp.y + (gable || side ? 0.0 : 0.4)), aa, e2);
			em += e2;
		}
		col *= wall_tint;
	}
	ALBEDO = col;
	ROUGHNESS = rgh;
	SPECULAR = is_floor && floor_mode > 1.5 && floor_mode < 2.5 ? 0.45 : 0.15;
	// звёздный проектор (ступень 3 или звёздный проектор-украшение)
	if (stars > 0.0) {
		vec3 d = normalize(wp - proj);
		float facing = smoothstep(0.25, 0.6, dot(n, -d)) * step(0.4, wp.y);
		float a = TIME * 0.04;
		d = vec3(d.x * cos(a) - d.z * sin(a), d.y, d.x * sin(a) + d.z * cos(a));
		vec3 g = d * 7.0;
		vec3 id = floor(g);
		vec3 f = fract(g) - 0.5;
		float h = fract(sin(dot(id, vec3(127.1, 311.7, 74.7))) * 43758.5453);
		vec3 o = vec3(fract(h * 13.7), fract(h * 71.3), fract(h * 37.9)) - 0.5;
		float dd = length(f - o * 0.5);
		float sz = 0.1 + 0.1 * fract(h * 5.3);
		float tw = 0.7 + 0.3 * sin(TIME * 2.0 + h * 30.0);
		vec3 sc = mix(vec3(1.0, 0.92, 0.6), vec3(0.6, 0.8, 1.0), fract(h * 3.1));
		float s = step(0.4, h) * smoothstep(sz, sz * 0.3, dd) * tw;
		em += sc * s * stars * facing * 2.2 + vec3(0.25, 0.18, 0.45) * stars * 0.1;
	}
	// зайчики диско-шара: цветные пятнышки бегут по стенам и полу
	if (disco > 0.0) {
		vec3 d = normalize(wp - disco_p);
		float facing = smoothstep(0.1, 0.5, dot(n, -d));
		float rot = TIME * 0.6;
		float lon = atan(d.z, d.x) + rot;
		float lat = asin(clamp(d.y, -1.0, 1.0));
		vec2 g = vec2(lon * 6.0, lat * 6.0);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id);
		float s = step(0.45, h) * smoothstep(0.16, 0.09, length(f));
		vec3 sc = hue(fract(h * 7.0)) * 0.85 + 0.25;
		em += sc * s * facing * disco * 1.1 * smoothstep(7.0, 1.5, length(wp - disco_p));
	}
	EMISSION = em;
}
"""

const KIT_WALL_MODE := {"kit_walls_beams": 0.0, "kit_walls_floral": 1.0, "kit_walls_brick": 2.0, "kit_walls_night": 3.0}
const KIT_FLOOR_MODE := {"kit_floor_planks": 0.0, "kit_floor_knit": 1.0, "kit_floor_checker": 2.0, "kit_floor_paint": 3.0}

var _light_nodes := {}
var _hq_counts := {}
var _moon_spot: Light3D
var _fx_disco: Node3D
var _fx_lamp: Node3D


func apply_walls(id: String) -> void:
	_shell_tint("wall_tint", Catalog.room_item(id).get("tint", Color(1, 1, 1)))
	_shell_param("wall_mode", KIT_WALL_MODE.get(id, 0.0))


func apply_floor(id: String) -> void:
	_shell_tint("floor_tint", Catalog.room_item(id).get("tint", Color(1, 1, 1)))
	_shell_param("floor_mode", KIT_FLOOR_MODE.get(id, 0.0))


func _shell_param(param: String, v: Variant) -> void:
	if _shell_mat:
		_shell_mat.set_shader_parameter(param, v)


## Свет: лампа под коньком и лунный луч из окна меняют силу; у каждого настроения — свои огоньки
const KIT_LAMP_K := {"kit_light_lamp": [1.0, 1.0], "kit_light_moon": [0.45, 1.9], "kit_light_fairy": [0.8, 0.8], "kit_light_neon": [0.55, 0.9]}


func apply_light(id: String) -> void:
	var k: Array = KIT_LAMP_K.get(id, [1.0, 1.0])
	var pair := [[shadow_light, k[0]], [_moon_spot, k[1]]]
	for p in pair:
		var l: Light3D = p[0]
		if l == null:
			continue
		if not l.has_meta("e_orig"):
			l.set_meta("e_orig", l.get_meta("e0") if l.has_meta("e0") else l.light_energy)
		l.set_meta("e0", float(l.get_meta("e_orig")) * float(p[1]))
	super.apply_light(id)
	if id != "kit_light_lamp" and not _light_nodes.has(id):
		var root := node(_house)
		root.name = "light_" + id
		var saved := anims
		anims = []
		match id:
			"kit_light_moon": _light_moon(root)
			"kit_light_fairy": _light_fairy(root)
			"kit_light_neon": _light_neon(root)
		var moving := []
		for a in anims:
			moving.append(a.n)
		merge_static(root, moving)
		saved.append_array(anims)
		anims = saved
		_light_nodes[id] = root
	for key in _light_nodes:
		(_light_nodes[key] as Node3D).visible = key == id
	_apply_hq()


func set_quality(hq: bool) -> void:
	super.set_quality(hq)
	_apply_hq()


## Простое качество: огоньков и пылинок — вдвое меньше
func _apply_hq() -> void:
	for mmi in _hq_counts:
		if is_instance_valid(mmi):
			var full: int = _hq_counts[mmi]
			(mmi as MultiMeshInstance3D).multimesh.visible_instance_count = full if high else full / 2


## Луч из окна (прибавляется к картинке, тает к полу)
func _ray(root: Node3D, from: Vector3, to: Vector3, w0: float, w1: float, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var side := Vector3(1, 0, 0) if k == 0 else (to - from).cross(Vector3(1, 0, 0)).normalized()
		var a := from - side * w0
		var b := from + side * w0
		var c := to + side * w1
		var d := to - side * w1
		for v in [[a, 0.0, 1.0], [b, 1.0, 1.0], [c, 1.0, 0.0], [a, 0.0, 1.0], [c, 1.0, 0.0], [d, 0.0, 0.0]]:
			st.set_color(Color(col, v[2]))
			st.set_uv(Vector2(v[1], 0))
			st.add_vertex(v[0])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	var mi := put(root, st.commit(), m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Лунный свет: широкий голубой луч из окна на пол и пылинки в нём
func _light_moon(root: Node3D) -> void:
	_ray(root, WIN_C + Vector3(0, 0, 0.05), Vector3(0.1, 0.01, -0.6), WIN_R * 0.8, 0.9, Color(0.55, 0.7, 1.0, 0.22))
	var patch := put(root, cyl(0.85, 0.85, 0.005, 32), glass(Color(0.6, 0.75, 1.0, 0.18), 0.6), Vector3(0.1, 0.012, -0.6), Vector3.ZERO, Vector3(1.0, 1, 0.75))
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sw := shader_swarm(root, "flies", 14, {"center": Vector3(0.05, 1.1, -1.9), "spread": Vector3(0.6, 0.7, 1.0), "col": Color(0.7, 0.85, 1.0, 1.0), "size": 0.018})
	_hq_counts[sw] = 14


## Гирлянда: по коньку, по обеим затяжкам, по краю низких стен и вокруг окна; три группы мигают по очереди
func _light_fairy(root: Node3D) -> void:
	var lines := []
	for z in [-1.4, 1.4]:
		var xw := HW * (1.0 - (3.05 - KW) / (RH - KW))
		var pts := []
		for i in 25:
			var s := i / 24.0
			pts.append(Vector3(lerpf(-xw, xw, s), 2.94 - sin(s * PI) * 0.2, z + 0.1))
		lines.append(pts)
	for sx in [-1.0, 1.0]:
		var pts := []
		for i in 33:
			var s := i / 32.0
			pts.append(Vector3(sx * (HW - 0.12), KW + 0.02 - absf(sin(s * PI * 6.0)) * 0.12, lerpf(-HL + 0.2, HL - 0.2, s)))
		lines.append(pts)
	var ridge := []
	for i in 33:
		var s := i / 32.0
		ridge.append(Vector3(0.12 * sin(s * PI * 5.0), RH - 0.3 - absf(sin(s * PI * 5.0)) * 0.1, lerpf(-HL + 0.3, HL - 0.3, s)))
	lines.append(ridge)
	var ring := []
	for i in 29:
		var a := TAU * i / 28.0
		ring.append(WIN_C + Vector3(cos(a) * (WIN_R + 0.2), sin(a) * (WIN_R + 0.2), 0.06))
	lines.append(ring)
	var wire := mat(Color("#2A2040"), 0.9, 0.0, false)
	var groups := [[], [], []]
	var k := 0
	for pts in lines:
		put(root, tube(pts, 0.006, 0.006, 3), wire)
		for i in range(1, pts.size() - 1, 2):
			groups[k % 3].append(Transform3D(Basis.from_scale(Vector3(1, 1.3, 1)), (pts[i] as Vector3) + Vector3(0, -0.035, 0)))
			k += 1
	var bc := [Color("#FFE27A"), Color("#FF8FC8"), Color("#9FF0FF")]
	var mats := []
	for g in 3:
		var m := glow_mat(bc[g], 2.4, true)
		mats.append(m)
		var mmi := scatter(root, sphere(0.032, 8), m, groups[g])
		_hq_counts[mmi] = groups[g].size()
	anim(node(root), "call", {"f": _a_mats_twinkle, "mats": mats, "e0": 2.0, "e1": 1.3})
	# звёздочки-подвески под затяжками
	for i in 4:
		var p := Vector3(-0.9 + i * 0.6, 2.6 - 0.12 * (i % 2), 1.4 if i % 2 == 0 else -1.4)
		var st := node(root, p)
		anim(st, "pendulum", {"amp": 0.1, "spd": 1.2, "p": float(i)})
		put(st, cyl(0.002, 0.002, 0.3, 3), mat(Color("#F4EAD8"), 1.0, 0.0, false), Vector3(0, 0.15, 0))
		put(st, extrude(star_poly(0.07, 0.03), 0.02), glow_mat(Color("#FFE9A0"), 2.2), Vector3.ZERO)
	halo(root, Vector3(0, 2.6, 0), 3.0, Color(1.0, 0.8, 0.6, 0.08))


## Неон и прожекторы: неоновое кольцо вокруг окна, полосы по низким стенам, лучи прожекторов водят по комнате
func _light_neon(root: Node3D) -> void:
	var pink := glow_mat(Color("#FF4FA3"), 2.8, true)
	var cyan := glow_mat(Color("#3FE0FF"), 2.8, true)
	var ring := []
	for i in 41:
		var a := TAU * i / 40.0
		ring.append(WIN_C + Vector3(cos(a) * (WIN_R + 0.17), sin(a) * (WIN_R + 0.17), 0.05))
	put(root, tube(ring, 0.018, 0.018, 5), pink)
	for sx in [-1.0, 1.0]:
		put(root, tube([Vector3(sx * (HW - 0.05), KW - 0.04, -HL + 0.1), Vector3(sx * (HW - 0.05), KW - 0.04, HL - 0.1)], 0.016, 0.016, 5), cyan)
		put(root, tube([Vector3(sx * (HW - 0.05), 0.08, -HL + 0.1), Vector3(sx * (HW - 0.05), 0.08, HL - 0.1)], 0.014, 0.014, 5), pink)
	# молния-зигзаг на задней стене под окном
	var zz := []
	for v in [Vector2(-1.9, 0.75), Vector2(-1.2, 0.95), Vector2(-0.7, 0.72), Vector2(0.0, 0.98), Vector2(0.7, 0.72), Vector2(1.2, 0.95), Vector2(1.9, 0.75)]:
		zz.append(Vector3(v.x, v.y, -HL + 0.04))
	put(root, tube(zz, 0.014, 0.014, 5), cyan)
	anim(node(root), "call", {"f": _a_neon_room, "mats": [pink, cyan]})
	# прожекторы под коньком
	var cols := [Color(1.0, 0.3, 0.75, 0.08), Color(0.3, 0.85, 1.0, 0.08), Color(0.7, 0.4, 1.0, 0.07)]
	for i in 3:
		var bp := node(root, Vector3(-1.0 + i * 1.0, RH - 0.55, -0.6 + 0.6 * (i % 2)))
		anim(bp, "wiggle", {"axis": Vector3.BACK, "amp": 0.5, "spd": 0.55 + 0.1 * i, "p": float(i) * 2.1})
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_color = cols[i]
		m.disable_fog = true
		var cone := put(bp, cyl(0.04, 0.6, 3.0, 16), m, Vector3(0, -1.5, 0))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		put(bp, cyl(0.07, 0.09, 0.14, 10), mat(Color("#2A2440"), 0.5), Vector3(0, 0.05, 0))
		put(bp, cyl(0.06, 0.06, 0.01, 10), glow_mat(Color(cols[i], 1.0), 3.0), Vector3(0, -0.025, 0))
	var sw := shader_swarm(root, "flies", 12, {"center": Vector3(0, 1.8, 0), "spread": Vector3(1.8, 0.8, 2.0), "col": Color(1.0, 0.5, 0.9, 1.0), "size": 0.025})
	_hq_counts[sw] = 12


func _a_neon_room(_nd: Node3D, t: float, a: Dictionary) -> void:
	var ms: Array = a.mats
	(ms[0] as StandardMaterial3D).emission_energy_multiplier = 2.6 + 0.4 * sin(t * 2.0)
	var u := fposmod(t, 4.0)
	(ms[1] as StandardMaterial3D).emission_energy_multiplier = 0.2 if (u > 3.0 and fposmod(u * 7.0, 1.0) < 0.5) else 2.8


# ---------- 0.15: эффекты украшений на стенах (зайчики диско-шара, звёзды проектора) ----------

func _place(spot: String) -> void:
	super._place(spot)
	if built:
		_refresh_fx()


func _refresh_fx() -> void:
	_fx_disco = null
	_fx_lamp = null
	for s in spot_nodes:
		var n = spot_nodes[s]
		if not is_instance_valid(n):
			continue
		match placed.get(s, ""):
			"kit_disco": _fx_disco = (n as Node).find_child("disco_ball", true, false)
			"kit_starlamp": _fx_lamp = (n as Node).find_child("star_dome", true, false)
	_shell_param("disco", 1.0 if _fx_disco else 0.0)
	_shell_param("stars", 1.0 if (_fx_lamp or stage >= 3) else 0.0)
	if _fx_lamp:
		_shell_param("proj", _fx_lamp.global_position)
	elif stage >= 3:
		_shell_param("proj", Vector3(-0.9, 0.55, 0.9))


func _process(delta: float) -> void:
	super._process(delta)
	if _fx_disco and is_instance_valid(_fx_disco):
		_shell_param("disco_p", _fx_disco.global_position)
