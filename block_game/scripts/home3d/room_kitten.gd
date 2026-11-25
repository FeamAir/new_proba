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


static func roof_y(x: float) -> float:
	return KW + (RH - KW) * (1.0 - clampf(absf(x) / HW, 0.0, 1.0))


func _init() -> void:
	kind = "kitten"
	hang_style = "shelf"
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
	_surf = Shaders.material("attic", {"stars": 1.0 if stage >= 3 else 0.0, "proj": Vector3(-0.9, 0.55, 0.9)})
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


# ---------- Пол, стены, крыша ----------

func _shell(h: Node3D) -> void:
	if not _geo.has("shell"):
		_geo["shell"] = _shell_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["shell"]
	mi.material_override = _surf
	h.add_child(mi)


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
		"kit_yarn": _d_yarn(n)
		"kit_mouse": _d_mouse(n)
		"kit_pillow": _d_pillow(n)
		"kit_picture": _d_picture(n)
		"kit_catnip": _d_catnip(n)
		"kit_box": _d_box(n)
		"kit_scratcher": _d_scratcher(n)
		"kit_lamp": _d_lamp(n)
		"kit_aquarium": _d_aquarium(n, sk)
		"kit_tree": _d_tree(n)


func _d_yarn(n: Node3D) -> void:
	var b := node(n, Vector3(0, 0.15, 0))
	anim(b, "roll", {"dx": 0.06, "r": 0.15, "spd": 0.9})
	put(b, sphere(0.15, 22), mat(Color("#FF7FB4"), 0.95))
	for k in 4:
		put(b, torus(0.135, 0.155, 28), mat(Color("#D94F8A"), 0.95, 0.0, false), Vector3.ZERO, Vector3(k * 0.8, k * 1.3, 0.4 + k * 0.5))
	# спицы
	for sx in [-1.0, 1.0]:
		put(b, cyl(0.008, 0.008, 0.42, 6), mat(Color("#C9A46A"), 0.5, 0.0, false), Vector3(0, 0.05, 0), Vector3(0, 0, sx * 0.7))
		put(b, sphere(0.02, 8), mat(Color("#FFD34D"), 0.5, 0.0, false), Vector3(-sx * sin(sx * 0.7) * 0.21, 0.05 + cos(0.7) * 0.21, 0))
	# хвостик нитки по полу
	var tp := []
	for i in 10:
		var s := i / 9.0
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
