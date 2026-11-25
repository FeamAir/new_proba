extends "res://scripts/home3d/room.gd"
## Будка щенка в ночном саду — уличная сцена. Будка в центре, камера летает вокруг неё.
## Вокруг: трава, цветы, забор-штакетник, дерево с веткой (на ней — место «сверху»), скала со входом
## в кристальную пещеру, небо со звёздами и луной.
## Ступени богатства (Meta.home_stage):
##   0 — будка, забор, дерево, скала;  1 — фонарики на столбиках, табличка-косточка над входом, больше цветов;
##   2 — гирлянда-лампочки на заборе, кристаллы у пещеры ярче;  3 — радуга в небе и фейерверк.

const GROUND_R := 7.5
const FENCE_R := 4.3
const FENCE_A0 := deg_to_rad(128.0)
const FENCE_A1 := deg_to_rad(262.0)
const ROCK_A := deg_to_rad(302.0)
const TREE_A := deg_to_rad(208.0)

static var _geo := {}
var _sway: ShaderMaterial


func _init() -> void:
	kind = "puppy"
	hang_style = "rope"
	rope_len = 0.45
	hero_feet = Vector3(0, 0.2, 1.08)
	var tree_p := dir(TREE_A) * 3.3
	var branch := tree_p + (Vector3.ZERO - tree_p).normalized() * 1.6 + Vector3(0, 2.12, 0)
	spots = {
		"floor_l": {"pos": dir(deg_to_rad(148.0)) * 2.55, "yaw": face_center(deg_to_rad(148.0))},
		"floor_r": {"pos": dir(deg_to_rad(28.0)) * 2.6, "yaw": face_center(deg_to_rad(28.0))},
		"wall_l": {"pos": dir(deg_to_rad(172.0)) * (FENCE_R - 0.08) + Vector3(0, 0.62, 0), "yaw": face_center(deg_to_rad(172.0)),
			"mark": Vector3(0, 0.35, 0.3), "stand": Vector3(0, 0.05, 0.16)},
		"wall_r": {"pos": dir(deg_to_rad(318.0)) * 3.55 + Vector3(0, 0.95, 0), "yaw": face_center(deg_to_rad(318.0)),
			"mark": Vector3(0, 0.35, 0.3), "stand": Vector3(0, 0.06, 0.26)},
		"hang": {"pos": branch, "yaw": PI - TREE_A, "mark": Vector3(0, -0.8, 0)},
		"near": {"pos": Vector3(0.95, 0.0, 1.45), "yaw": 0.25, "mark": Vector3(0, 0.3, 0)},
	}
	for s in ["floor_l", "floor_r"]:
		spots[s]["mark"] = Vector3(0, 0.3, 0)


func _inside(p: Vector3) -> bool:
	if p.y < 0.25 or Vector2(p.x, p.z).length() > 6.0:
		return false
	# камера не залетает в дерево, его ветку и крону
	if p.y > 1.0:
		var a := Vector2(dir(TREE_A).x, dir(TREE_A).z) * 3.3
		var b := a * (1.0 - 1.75 / 3.3)
		var q := Vector2(p.x, p.z)
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if q.distance_to(a.lerp(b, t)) < 1.0:
			return false
	return true


func _setup_camera(c: Camera3D) -> void:
	c.home_pivot = Vector3(0, 0.66, 0.45)
	c.home_dist = 3.5
	c.home_pitch = 0.22
	c.dist_min = 1.6
	c.dist_max = 5.0
	c.pitch_min = 0.04
	c.pitch_max = 0.6
	c.yaw_limit = deg_to_rad(110.0)  # со спины будки щенка не видно


## Вокруг будки: на вещи у забора и скалы смотрим со стороны будки, на вещи у будки — снаружи
func _view_dir(at: Vector3, is_hero := false, _turn := 0.55) -> Vector3:
	if is_hero:
		return Vector3(0.3, 0, 1.0)
	var flat := Vector3(at.x, 0, at.z)
	if flat.length() < 2.0:
		return (flat.normalized() + Vector3(0, 0, 0.6)).normalized()
	return -flat.normalized().rotated(Vector3.UP, 0.35)


## На ветку смотрим сбоку (поперёк ветки, со стороны входа в будку) — не из будки
func _hang_view_dir(_at: Vector3) -> Vector3:
	var to_c := -dir(TREE_A)
	return Vector3(-to_c.z, 0, to_c.x)


# ---------- Окружение ----------

func _environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#140E2E")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7A6CC0")
	env.ambient_light_energy = 0.55 + 0.04 * stage
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("#2A2058")
	env.fog_density = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	world_env.environment = env
	add_child(world_env)


func _build_house(h: Node3D) -> void:
	_sway = Shaders.material("sway", {"amp": 0.05, "speed": 1.6})
	_sway.set_meta("merge", true)
	_sky(h)
	_ground(h)
	_fence(h)
	_tree(h)
	_rock(h)
	_doghouse(h)
	_garden(h)
	shader_swarm(h, "flies", 8 + stage * 6, {"center": Vector3(0, 1.4, 0), "spread": Vector3(3.6, 0.8, 3.6), "size": 0.05})
	if stage >= 3:
		shader_swarm(h, "fireworks", 28 * 3, {"sparks": 28.0, "size": 0.09}, 20.0)


# ---------- Небо, луна, земля ----------

func _sky(h: Node3D) -> void:
	var dome := put(h, sphere(24.0, 32), Shaders.material("sky_dome", {"rainbow": 1.0 if stage >= 3 else 0.0}), Vector3.ZERO)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.extra_cull_margin = 30.0
	var md := Vector3(0.55, 0.42, -0.72).normalized()
	var mp := md * 20.0
	put(h, sphere(1.1, 24), mat(Color("#FFF3C9"), 1.0, 1.7, false), mp)
	for cr in [[Vector3(-0.35, 0.3, 0.5), 0.25], [Vector3(0.3, -0.3, 0.5), 0.18]]:
		put(h, sphere(cr[1], 10), mat(Color("#EFDDA0"), 1.0, 1.3, false), mp + Basis.looking_at(-md) * (cr[0] as Vector3) - md * 0.8, Vector3.ZERO, Vector3(1, 1, 0.4))
	var hl := halo(h, mp - md * 1.2, 7.0, Color(1.0, 0.92, 0.65, 0.4))
	hl.material_override = hl.material_override.duplicate()
	(hl.material_override as StandardMaterial3D).disable_fog = true
	# лунный свет — единственный, кто даёт тени в высоком качестве
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#AFC0FF")
	moon.light_energy = 0.55
	moon.shadow_blur = 1.5
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 14.0
	h.add_child(moon)
	moon.look_at_from_position(md * 10.0, Vector3.ZERO, Vector3.UP)
	shadow_light = moon


func _ground(h: Node3D) -> void:
	if not _geo.has("ground"):
		_geo["ground"] = _ground_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["ground"]
	mi.material_override = vmat(1.0, 0.1)
	h.add_child(mi)
	# травинки колышутся (шейдер)
	if not _geo.has("blade"):
		_geo["blade"] = tube([Vector3(0, 0, 0), Vector3(0.01, 0.09, 0), Vector3(0.04, 0.2, 0)], 0.018, 0.002, 3)
	var xfs := []
	var cols := []
	var n := 260
	for i in n:
		var a := hash1(i, 81) * TAU
		var rr := 0.9 + sqrt(hash1(i, 82)) * 4.8
		var p := dir(a) * rr
		if Vector2(p.x, p.z + 0.1).length() < 1.1:
			continue
		xfs.append(Transform3D(Basis(Vector3.UP, hash1(i, 83) * TAU) * Basis.from_scale(Vector3.ONE * (0.8 + 0.8 * hash1(i, 84))), p + Vector3(0, _ground_h(p), 0)))
		cols.append(Color("#3F8A55").lerp(Color("#6FBF6A"), hash1(i, 85)))
	var mmi := scatter(h, _geo["blade"], _sway, xfs, cols)
	mmi.name = "grass"


static func _ground_h(p: Vector3) -> float:
	var r := Vector2(p.x, p.z).length()
	return 0.05 * sin(p.x * 1.3) * sin(p.z * 1.1) + 0.25 * smoothstep(5.0, 7.5, r)


func _ground_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 16
	var segs := 56
	var pts := []
	var cols := []
	for j in rings + 1:
		var rr := GROUND_R * pow(float(j) / rings, 1.15)
		var row := []
		var crow := []
		for i in segs + 1:
			var a := TAU * i / segs
			var p := dir(a) * rr
			p.y = _ground_h(p)
			row.append(p)
			var c := Color("#2E5A3A").lerp(Color("#3E7A48"), 0.5 + 0.5 * sin(a * 7.0 + rr * 2.0) * sin(rr * 1.3))
			c = c.lerp(Color("#1A2E2A"), smoothstep(4.5, 7.5, rr))
			if i == segs:
				c = crow[0]
			crow.append(c)
		pts.append(row)
		cols.append(crow)
	for j in rings:
		for i in segs:
			var A: Vector3 = pts[j][i]
			var B: Vector3 = pts[j][i + 1]
			var C: Vector3 = pts[j + 1][i + 1]
			var D: Vector3 = pts[j + 1][i]
			tri(st, A, B, C, Vector3.UP, cols[j][i], cols[j][i + 1], cols[j + 1][i + 1])
			if j > 0:
				tri(st, A, C, D, Vector3.UP, cols[j][i], cols[j + 1][i + 1], cols[j + 1][i])
	# дальние холмы — тёмное кольцо
	var hills := []
	for i in segs + 1:
		var a := TAU * i / segs
		hills.append([dir(a) * GROUND_R + Vector3(0, 0.25, 0), dir(a) * 14.0 + Vector3(0, 1.4 + 0.9 * sin(a * 3.0) + 0.5 * sin(a * 7.0), 0)])
	var hc := Color("#1D1645")
	for i in segs:
		tri(st, hills[i][0], hills[i + 1][0], hills[i + 1][1], Vector3.UP, hc, hc, hc)
		tri(st, hills[i][0], hills[i + 1][1], hills[i][1], Vector3.UP, hc, hc, hc)
	st.index()
	st.generate_normals()
	return st.commit()


# ---------- Забор ----------

func _fence(h: Node3D) -> void:
	var picket := Color("#D9CBE0")
	var len := (FENCE_A1 - FENCE_A0) * FENCE_R
	var n := int(len / 0.27)
	var xfs := []
	var tops := []
	for i in n + 1:
		var a := lerpf(FENCE_A0, FENCE_A1, float(i) / n)
		var p := dir(a) * FENCE_R
		var b := Basis(Vector3.UP, face_center(a))
		xfs.append(Transform3D(b, p + Vector3(0, 0.45, 0)))
		tops.append(Transform3D(b, p + Vector3(0, 0.95, 0)))
	scatter(h, box(Vector3(0.16, 0.9, 0.05)), mat(picket, 0.85), xfs)
	scatter(h, prism(Vector3(0.16, 0.1, 0.05)), mat(picket, 0.85), tops)
	# две перекладины — трубками по дуге
	for y in [0.3, 0.72]:
		var pts := []
		for i in 25:
			pts.append(dir(lerpf(FENCE_A0, FENCE_A1, i / 24.0)) * (FENCE_R + 0.05) + Vector3(0, y, 0))
		put(h, tube(pts, 0.03, 0.03, 4), mat(Color("#B8A6C8"), 0.9))
	# столбики по краям
	for a in [FENCE_A0, FENCE_A1]:
		put(h, cyl(0.07, 0.08, 1.15, 10), mat(Color("#B8A6C8"), 0.9), dir(a) * FENCE_R + Vector3(0, 0.57, 0))
		put(h, sphere(0.09, 10), mat(Color("#E9DFF0"), 0.9), dir(a) * FENCE_R + Vector3(0, 1.18, 0))
	if stage >= 2:
		# гирлянда-лампочки вдоль забора
		var pts := []
		for i in 49:
			var s := i / 48.0
			pts.append(dir(lerpf(FENCE_A0 + 0.05, FENCE_A1 - 0.05, s)) * (FENCE_R - 0.05) + Vector3(0, 1.05 - absf(sin(s * PI * 4.0)) * 0.14, 0))
		put(h, tube(pts, 0.008, 0.008, 4), mat(Color("#2A2040"), 0.9, 0.0, false))
		var bc := [Color("#FF6FA8"), Color("#FFD34D"), Color("#7FE3FF"), Color("#9CF58A")]
		for i in range(2, 48, 3):
			var b := put(h, sphere(0.04, 8), glow_mat(bc[i % 4], 2.0, true), (pts[i] as Vector3) + Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
			anim(b, "bulb", {"p": float(i), "e0": 1.5, "e1": 0.9})


# ---------- Дерево с веткой ----------

func _tree(h: Node3D) -> void:
	var base := dir(TREE_A) * 3.3
	var bark := mat(Color("#5B3A2E"), 0.95)
	var trunk := [base, base + Vector3(0.05, 1.2, 0.02), base + Vector3(-0.08, 2.4, 0.05), base + Vector3(0, 3.4, 0)]
	put(h, tube(trunk, 0.3, 0.17, 10), bark)
	# корни
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		put(h, tube(bez(base + Vector3(0, 0.3, 0), base + dir(a) * 0.4 + Vector3(0, 0.08, 0), base + dir(a) * 0.7), 0.13, 0.04, 6), bark)
	# ветка к будке — на ней место «сверху»
	var to_c := (Vector3.ZERO - base).normalized()
	var bp := bez(base + Vector3(0, 1.85, 0), base + to_c * 0.8 + Vector3(0, 2.2, 0), base + to_c * 1.75 + Vector3(0, 2.1, 0))
	put(h, tube(bp, 0.11, 0.05, 8), bark)
	for k in [4, 6, 8]:
		put(h, sphere(0.13, 8), mat(Color("#2F7A55"), 1.0), (bp[k] as Vector3) + Vector3(0, 0.08, 0), Vector3(0.3 * k, k, 0), Vector3(1.4, 0.6, 0.9))
	# крона — мягкие шары
	var leaf := [Color("#173A35"), Color("#1F4C40"), Color("#27604C"), Color("#2F7A55")]
	var blobs := [[Vector3(0, 3.3, 0), 1.0], [Vector3(0.7, 3.0, 0.3), 0.75], [Vector3(-0.7, 3.05, -0.2), 0.8], [Vector3(0.1, 3.0, -0.75), 0.75],
		[Vector3(-0.2, 3.85, 0.2), 0.7], [Vector3(0.3, 2.75, 0.75), 0.6], [Vector3(-0.6, 2.65, 0.55), 0.55]]
	for i in blobs.size():
		var b: Array = blobs[i]
		# крона сдвинута от ветки (за дерево), чтобы вещь на ветке была видна
		put(h, sphere(b[1], 16), mat(leaf[i % 4], 1.0), base + (b[0] as Vector3) + Vector3(0, 0.35, 0) - to_c * 0.35, Vector3(0, i, 0), Vector3(1.0, 0.85, 1.0))
	casters.append(h.get_child(h.get_child_count() - 1))
	features.append([base + Vector3(0, 2.6, 0), 3.0, "tree"])


# ---------- Скала со входом в пещеру ----------

func _rock(h: Node3D) -> void:
	var c := dir(ROCK_A) * 5.0
	var yaw := face_center(ROCK_A)
	var rk := node(h, c, yaw)
	var rock := [Color("#6A6498"), Color("#7A74A8"), Color("#706A9E")]
	var parts := [[Vector3(0, 0.6, -0.2), Vector3(2.2, 1.6, 1.3)], [Vector3(-1.3, 0.4, 0.1), Vector3(1.3, 1.1, 1.1)], [Vector3(1.4, 0.5, -0.1), Vector3(1.4, 1.3, 1.1)],
		[Vector3(0.2, 1.6, -0.4), Vector3(1.7, 1.1, 1.1)], [Vector3(-0.8, 1.3, -0.5), Vector3(1.0, 0.9, 0.9)], [Vector3(1.1, 1.4, -0.4), Vector3(0.9, 0.8, 0.9)]]
	for i in parts.size():
		var p: Array = parts[i]
		put(rk, sphere(1.0, 18), mat(rock[i % 3], 0.9), p[0], Vector3(0, i * 0.7, 0), p[1])
	# вход в пещеру — тёмная арка, внутри светятся кристаллы
	put(rk, sphere(0.62, 20), mat(Color("#0E0820"), 1.0, 0.0, false), Vector3(0, 0.45, 1.05), Vector3.ZERO, Vector3(1.0, 1.05, 0.35))
	put(rk, torus(0.55, 0.78, 28), mat(Color("#6E68A0"), 0.9), Vector3(0, 0.45, 1.08), Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 1.15))
	# мох на камнях сверху
	for m in [[Vector3(0.1, 2.15, -0.3), 0.6], [Vector3(-0.9, 1.75, -0.4), 0.45], [Vector3(1.2, 1.85, -0.3), 0.4]]:
		put(rk, sphere(m[1], 14), mat(Color("#3E7A58"), 1.0), m[0], Vector3.ZERO, Vector3(1.3, 0.35, 1.1))
	var cave := [Color("#B46CFF"), Color("#3FD0FF"), Color("#3DDC97"), Color("#FF8FD8")]
	var glow_k := 1.0 + 0.4 * stage
	for i in 3:
		var cp := Vector3(-0.25 + i * 0.25, 0.08, 1.0 - 0.1 * (i % 2))
		crystal_cluster(rk, cp, 0.55 + 0.1 * i, cave[i], 1.1 * glow_k, i)
	halo(rk, Vector3(0, 0.45, 1.2), 1.6, Color(0.5, 0.8, 1.0, 0.18 + 0.05 * stage))
	# кристаллы на краях арки (больше на поздних ступенях)
	var edge := 2 + stage * 2
	for i in edge:
		var a := lerpf(-2.4, 2.4, float(i) / maxf(1.0, edge - 1))
		var ep := Vector3(sin(a) * 0.8, 0.45 + cos(a) * 0.85, 1.15)
		var g := crystal(rk, ep, 0.22, 0.05, Vector3(0.4, 0, -a * 0.6), cave[i % 4], 1.2)
		anim(g, "pulse", {"p": float(i)})
	omni(rk, Vector3(0, 0.5, 1.5), Color("#8FC8FF"), 0.9 + 0.25 * stage, 3.2, "pulse")
	omni(h, c + dir(ROCK_A + PI) * 2.2 + Vector3(0, 2.0, 0), Color("#B8A8FF"), 0.5, 4.5)
	# уступ для украшения (место «стена» справа) — каменная полка на боку скалы
	features.append([c + dir(ROCK_A + PI) * 1.2 + Vector3(0, 0.6, 0), 2.6, "cave"])
	# дорожка из камешков от будки к пещере
	for i in 6:
		var s := (i + 1) / 7.0
		var p := Vector3(0.6, 0, 1.6).lerp(c + dir(ROCK_A + PI) * 1.4, s)
		put(h, cyl(0.2 - 0.01 * i, 0.22 - 0.01 * i, 0.05, 14), mat(Color("#7E7AA0"), 0.9), p + Vector3(0, 0.02 + _ground_h(p), 0), Vector3(0, i, 0), Vector3(1.0, 1.0, 0.75))


# ---------- Будка ----------

func _doghouse(h: Node3D) -> void:
	var d := node(h)
	casters.append(d)
	var wood := mat(Color("#C88A58"), 0.85)
	var wood_d := mat(Color("#9E6640"), 0.85)
	var W := 1.3
	var D := 1.35
	var H := 0.95
	put(d, box(Vector3(W, H, D)), wood, Vector3(0, H * 0.5, -0.1))
	# доски
	for i in 5:
		var y := 0.12 + i * 0.19
		put(d, box(Vector3(W + 0.02, 0.025, D + 0.02)), wood_d, Vector3(0, y, -0.1))
	# основание
	put(d, box(Vector3(W + 0.12, 0.08, D + 0.12)), mat(Color("#7A4A30"), 0.9), Vector3(0, 0.04, -0.1))
	# фронтон
	put(d, prism(Vector3(W, 0.6, 0.06)), wood, Vector3(0, H + 0.3, D * 0.5 - 0.1))
	put(d, prism(Vector3(W, 0.6, 0.06)), wood, Vector3(0, H + 0.3, -D * 0.5 - 0.1))
	# крыша — две наклонные доски от края стены до конька
	var roof := mat(Color("#E0596F"), 0.75)
	var roof_d := mat(Color("#B8445A"), 0.8)
	var ang := atan2(0.6, W * 0.5)
	var slope := Vector2(W * 0.5, 0.6).length() + 0.16
	var roof_l := mat(Color("#F07A8E"), 0.75)
	for sx in [-1.0, 1.0]:
		var nrm := Vector3(sx * sin(ang), cos(ang), 0)
		var eave := Vector3(sx * (W * 0.5 + 0.12), H - 0.1, -0.1)
		var ridge := Vector3(0, H + 0.62, -0.1)
		var r := put(d, box(Vector3(slope, 0.06, D + 0.3)), roof_d, (eave + ridge) * 0.5 + nrm * 0.02, Vector3(0, 0, -sx * ang))
		r.name = "roof"
		# черепица: 4 ряда, каждый чуть выше предыдущего, через один — светлее
		for k in 4:
			var t := (k + 0.5) / 4.0
			var c := eave.lerp(ridge, t) + nrm * (0.07 + 0.01 * (3 - k))
			put(d, box(Vector3(slope / 4.0 + 0.05, 0.05, D + 0.34)), roof if k % 2 == 0 else roof_l, c, Vector3(0, 0, -sx * ang + sx * 0.06))
	put(d, cyl(0.07, 0.07, D + 0.34, 10), roof_d, Vector3(0, H + 0.67, -0.1), Vector3(PI / 2.0, 0, 0))
	put(d, sphere(0.09, 12), mat(Color("#FFD34D"), 0.5, 0.6), Vector3(0, H + 0.74, D * 0.5 + 0.12))
	# круглый вход: тёмный, с тёплым светом изнутри
	put(d, cyl(0.36, 0.36, 0.04, 28), mat(Color("#1E1028"), 1.0, 0.0, false), Vector3(0, 0.42, D * 0.5 - 0.08), Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 1.15))
	put(d, box(Vector3(0.72, 0.4, 0.04)), mat(Color("#1E1028"), 1.0, 0.0, false), Vector3(0, 0.22, D * 0.5 - 0.08))
	var arch := []
	for i in 17:
		var a := lerpf(0.0, PI, i / 16.0)
		arch.append(Vector3(cos(a) * 0.4, 0.42 + sin(a) * 0.44, D * 0.5 - 0.06))
	arch.push_front(Vector3(0.4, 0.04, D * 0.5 - 0.06))
	arch.append(Vector3(-0.4, 0.04, D * 0.5 - 0.06))
	put(d, tube(arch, 0.06, 0.06, 6), mat(Color("#7A4A30"), 0.9))
	var warm := omni(d, Vector3(0, 0.45, D * 0.5 + 0.1), Color("#FFB547"), 0.55 + 0.15 * stage, 2.4, "slow")
	warm.name = "door_light"
	halo(d, Vector3(0, 0.4, D * 0.5 - 0.02), 1.1, Color(1.0, 0.7, 0.3, 0.25 + 0.05 * stage))
	if stage >= 1:
		# табличка-косточка над входом с отпечатком лапки
		var plate := node(d, Vector3(0, H + 0.18, D * 0.5 - 0.03))
		_bone(plate, 0.75, Color("#FFF3E0"))
		_paw(plate, Vector3(0, 0, 0.05), 0.5, Color("#C88A58"))
	# подушка у входа — на ней сидит щенок
	put(h, cyl(0.62, 0.66, 0.16, 32), mat(Color("#5E3C8A"), 0.95), Vector3(0, 0.08, 1.05), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	put(h, sphere(0.58, 24), mat(Color("#8C63D0"), 1.0, 0.0, false), Vector3(0, 0.14, 1.05), Vector3.ZERO, Vector3(1.0, 0.12, 0.66))
	var dots := []
	for i in 14:
		var a := TAU * i / 14.0
		dots.append(Transform3D(Basis(), Vector3(cos(a) * 0.63, 0.12, 1.05 + sin(a) * 0.44)))
	scatter(h, sphere(0.025, 6), mat(Color("#FFD34D"), 0.6, 0.4, false), dots)
	features.append([Vector3(0, 0.8, 0.2), 2.6, "doghouse"])


func _bone(parent: Node3D, k: float, col: Color) -> void:
	var m := mat(col, 0.7)
	put(parent, cyl(0.045 * k, 0.045 * k, 0.32 * k, 10), m, Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			put(parent, sphere(0.055 * k, 10), m, Vector3(sx * 0.17 * k, sy * 0.04 * k, 0))


func _paw(parent: Node3D, at: Vector3, k: float, col: Color) -> void:
	var m := mat(col, 0.8, 0.0, false)
	put(parent, sphere(0.05 * k, 10), m, at, Vector3.ZERO, Vector3(1.1, 0.9, 0.4))
	for i in 4:
		var a := lerpf(-0.9, 0.9, i / 3.0)
		put(parent, sphere(0.022 * k, 8), m, at + Vector3(sin(a) * 0.07 * k, 0.06 * k + cos(a) * 0.015 * k, 0), Vector3.ZERO, Vector3(1, 1.2, 0.4))


# ---------- Сад: цветы, кусты, фонарики ----------

func _garden(h: Node3D) -> void:
	var fl := [Color("#FF8FC8"), Color("#FFE27A"), Color("#B8A2FF"), Color("#FFFFFF"), Color("#FF8A5C")]
	var nf := 10 + stage * 8
	var stems := []
	var heads := []
	var hcols := []
	for i in nf:
		var a: float
		var rr: float
		if i % 2 == 0:
			a = lerpf(FENCE_A0 + 0.1, FENCE_A1 - 0.1, hash1(i, 91))
			rr = FENCE_R - 0.25 - 0.3 * hash1(i, 92)
		else:
			a = hash1(i, 93) * TAU
			rr = 1.6 + hash1(i, 94) * 2.2
		var p := dir(a) * rr
		if Vector2(p.x, p.z - 0.4).length() < 1.4:
			continue
		var near_spot := false
		for s in ["floor_l", "floor_r", "near"]:
			if Vector2(p.x - spots[s].pos.x, p.z - spots[s].pos.z).length() < 0.75:
				near_spot = true
		if near_spot:
			continue
		var hh := 0.22 + 0.15 * hash1(i, 95)
		p.y = _ground_h(p)
		stems.append(Transform3D(Basis.from_scale(Vector3(1, hh / 0.3, 1)), p + Vector3(0, hh * 0.5, 0)))
		heads.append(Transform3D(Basis(Vector3.UP, i), p + Vector3(0, hh, 0)))
		hcols.append(fl[i % fl.size()])
	scatter(h, cyl(0.008, 0.01, 0.3, 4), mat(Color("#3F8A55"), 0.9, 0.0, false), stems)
	# цветок: пять лепестков-шариков в одной сетке
	if not _geo.has("flower"):
		var st := SurfaceTool.new()
		for k in 5:
			var a := TAU * k / 5.0
			st.append_from(sphere(0.035, 8), 0, Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)), Vector3(cos(a) * 0.04, 0, sin(a) * 0.04)))
		st.append_from(sphere(0.025, 8), 0, Transform3D(Basis(), Vector3(0, 0.015, 0)))
		_geo["flower"] = st.commit()
	scatter(h, _geo["flower"], vmat(0.7, 0.3), heads, hcols)
	# кусты у забора
	for i in 6:
		var a := lerpf(FENCE_A0 + 0.15, FENCE_A1 - 0.15, (i + 0.5) / 6.0)
		if absf(angle_difference(a, deg_to_rad(172.0))) < 0.25 or absf(angle_difference(a, TREE_A)) < 0.2:
			continue
		var p := dir(a) * (FENCE_R - 0.4)
		put(h, sphere(0.38, 14), mat(Color("#245C44"), 1.0), p + Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
		put(h, sphere(0.25, 12), mat(Color("#2F7A55"), 1.0, 0.0, false), p + dir(a + PI / 2.0) * 0.3 + Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1.1, 0.8, 1.0))
	if stage >= 1:
		# садовые фонарики на столбиках
		for a in [deg_to_rad(128.0), deg_to_rad(-8.0)]:
			var p := dir(a) * 3.3
			put(h, cyl(0.035, 0.045, 1.1, 8), mat(Color("#3A2A55"), 0.7), p + Vector3(0, 0.55, 0))
			put(h, sphere(0.14, 16), glass(Color(1.0, 0.9, 0.55, 0.75), 1.6), p + Vector3(0, 1.2, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
			put(h, cyl(0.0, 0.17, 0.12, 12), mat(Color("#3A2A55"), 0.7), p + Vector3(0, 1.38, 0))
			put(h, sphere(0.06, 10), glow_mat(Color("#FFF2C0"), 3.0), p + Vector3(0, 1.2, 0))
			halo(h, p + Vector3(0, 1.2, 0), 1.0, Color(1.0, 0.85, 0.5, 0.35))
			omni(h, p + Vector3(0, 1.15, 0), Color("#FFD98A"), 0.7, 2.8, "flicker")
	# миска-лужица света от луны — нет; маленькие светящиеся грибы у скалы
	for i in 3:
		var p := dir(ROCK_A + 0.5 + i * 0.12) * (3.9 + 0.2 * i)
		put(h, cyl(0.02, 0.025, 0.1, 6), mat(Color("#F2E8FF"), 0.8, 0.0, false), p + Vector3(0, 0.05 + _ground_h(p), 0))
		put(h, hemi(0.06, 10), mat(Color("#7FF5E0"), 0.5, 0.9), p + Vector3(0, 0.1 + _ground_h(p), 0), Vector3.ZERO, Vector3(1, 1.8, 1))


## Полочка: на заборе — дощечка на кронштейнах; на скале — каменный уступ
## На скале (справа) нет забора — там любая вещь стоит на каменном уступе
func _is_flat(id: String, spot: String) -> bool:
	if spot == "wall_r":
		return false
	return super._is_flat(id, spot)


func _ledge(n: Node3D, spot: String) -> void:
	if spot == "wall_l":
		put(n, box(Vector3(0.62, 0.05, 0.3)), mat(Color("#B07A4E"), 0.85), Vector3(0, 0.0, 0.14))
		for sx in [-0.22, 0.22]:
			put(n, prism(Vector3(0.04, 0.16, 0.2), 0.0), mat(Color("#8A5A3A"), 0.85), Vector3(sx, -0.1, 0.1), Vector3(0, -PI / 2.0, 0))
	else:
		put(n, sphere(0.45, 16), mat(Color("#524C80"), 0.9), Vector3(0, -0.2, 0.06), Vector3.ZERO, Vector3(1.2, 0.5, 0.8))
		put(n, sphere(0.4, 14), mat(Color("#6E68A0"), 0.9, 0.0, false), Vector3(0, 0.0, 0.14), Vector3.ZERO, Vector3(1.1, 0.08, 0.72))


# ---------- Украшения ----------

func _decor(id: String, n: Node3D, sk: String) -> void:
	match id:
		"pup_ball": _d_ball(n)
		"pup_bone":
			var b := node(n, Vector3(0, 0.07, 0))
			b.rotation.y = 0.6
			_bone(b, 1.2, Color("#FFF6E8"))
			anim(b, "wiggle", {"amp": 0.15, "spd": 1.2})
		"pup_bowl": _d_bowl(n)
		"pup_sign": _d_sign(n, sk)
		"pup_flowerbed": _d_flowerbed(n)
		"pup_pinwheel": _d_pinwheel(n, sk)
		"pup_lamp": _d_lamp(n, sk)
		"pup_bed": _d_bed(n)
		"pup_kite": _d_kite(n)
		"pup_teddy": _d_teddy(n)


func _d_ball(n: Node3D) -> void:
	var b := node(n, Vector3(0, 0.15, 0))
	anim(b, "hop", {"h": 0.16, "spd": 2.6})
	var inner := node(b)
	anim(inner, "spin", {"axis": Vector3.RIGHT, "spd": 1.5})
	put(inner, sphere(0.15, 22), mat(Color("#FF5A6E"), 0.55))
	put(inner, torus(0.13, 0.155, 28), mat(Color("#FFF3E0"), 0.6, 0.0, false), Vector3.ZERO, Vector3(0.3, 0, 0.4))
	put(inner, extrude(star_poly(0.05, 0.022), 0.02), mat(Color("#FFD34D"), 0.5, 0.3, false), Vector3(0.05, 0.05, 0.135), Vector3(0, 0.3, 0))


func _d_bowl(n: Node3D) -> void:
	var prof := [Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.22, 0.05), Vector2(0.25, 0.16), Vector2(0.21, 0.16), Vector2(0.17, 0.06), Vector2(0.0, 0.06)]
	put(n, lathe(prof, 28), mat(Color("#3FA9F5"), 0.45))
	put(n, torus(0.205, 0.255, 28), mat(Color("#8FD6FF"), 0.45, 0.0, false), Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	var xfs := []
	for i in 22:
		var a := hash1(i, 3) * TAU
		var r := sqrt(hash1(i, 4)) * 0.17
		xfs.append(Transform3D(Basis.from_euler(Vector3(i, i * 2.0, 0)), Vector3(cos(a) * r, 0.1 + 0.03 * hash1(i, 5), sin(a) * r)))
	scatter(n, sphere(0.03, 6), mat(Color("#C27A3A"), 0.9, 0.0, false), xfs)
	var em := node(n, Vector3(0, 0.1, 0.235))
	em.rotation.x = -0.2
	_bone(em, 0.35, Color("#FFFFFF"))


func _d_sign(n: Node3D, sk: String) -> void:
	var top := Vector3(0, 0.75, 0.08)
	if sk != "wall":
		# на полочке / на земле — табличка на столбике
		put(n, cyl(0.03, 0.035, 0.8, 8), mat(Color("#8A5A3A"), 0.85), Vector3(0, 0.4, 0))
		put(n, box(Vector3(0.36, 0.04, 0.04)), mat(Color("#8A5A3A"), 0.85), Vector3(0, 0.78, 0))
		top = Vector3(0, 0.76, 0.03)
	else:
		put(n, cyl(0.025, 0.025, 0.08, 8), mat(Color("#8A8AA0"), 0.4), Vector3(0, 0.75, 0.05), Vector3(PI / 2.0, 0, 0))
	var sw := node(n, top)
	anim(sw, "wiggle", {"axis": Vector3.BACK, "amp": 0.06, "spd": 1.3})
	var rope := mat(Color("#C9B88A"), 1.0, 0.0, false)
	put(sw, tube([Vector3.ZERO, Vector3(-0.22, -0.17, 0)], 0.008, 0.008, 4), rope)
	put(sw, tube([Vector3.ZERO, Vector3(0.22, -0.17, 0)], 0.008, 0.008, 4), rope)
	put(sw, extrude(rrect_poly(0.56, 0.3, 0.07), 0.05), mat(Color("#D69A62"), 0.85), Vector3(0, -0.32, 0))
	var b := node(sw, Vector3(-0.08, -0.32, 0.035))
	_bone(b, 0.55, Color("#FFF6E8"))
	_paw(sw, Vector3(0.16, -0.33, 0.03), 0.9, Color("#7A4A30"))


func _d_flowerbed(n: Node3D) -> void:
	var box_m := mat(Color("#A8663E"), 0.85)
	put(n, box(Vector3(0.8, 0.22, 0.34)), box_m, Vector3(0, 0.11, 0))
	put(n, box(Vector3(0.84, 0.04, 0.38)), mat(Color("#C4845A"), 0.85), Vector3(0, 0.22, 0))
	put(n, box(Vector3(0.74, 0.03, 0.28)), mat(Color("#4A2E22"), 1.0, 0.0, false), Vector3(0, 0.215, 0))
	var cols := [Color("#FF6FA8"), Color("#FFD34D"), Color("#B48CFF"), Color("#FF8A5C"), Color("#FFFFFF")]
	for i in 7:
		var x := -0.3 + i * 0.1
		var z := -0.06 + 0.12 * (i % 2)
		var hh := 0.3 + 0.15 * hash1(i, 101)
		var f := node(n, Vector3(x, 0.22, z))
		anim(f, "sway", {"amp": 0.08, "spd": 1.4, "p": float(i)})
		put(f, cyl(0.008, 0.01, hh, 5), mat(Color("#3F8A55"), 0.9, 0.0, false), Vector3(0, hh * 0.5, 0))
		put(f, sphere(0.03, 8), mat(Color("#5BC27E"), 0.9, 0.0, false), Vector3(0.025, hh * 0.45, 0), Vector3(0, 0, -0.6), Vector3(1.4, 0.5, 0.8))
		var c: Color = cols[i % 5]
		for k in 5:
			var a := TAU * k / 5.0
			put(f, sphere(0.032, 8), mat(c, 0.7, 0.1, false), Vector3(cos(a) * 0.035, hh, sin(a) * 0.035), Vector3.ZERO, Vector3(1, 0.6, 1))
		put(f, sphere(0.025, 8), mat(Color("#FFB547"), 0.6, 0.2, false), Vector3(0, hh + 0.012, 0))


func _d_pinwheel(n: Node3D, sk: String) -> void:
	var base := Vector3(0, 0, 0.1) if sk == "wall" else Vector3.ZERO
	var stick_h := 0.62 if sk != "wall" else 0.55
	if sk == "wall":
		# прикручен к штакетине хомутиками
		for y in [0.15, 0.4]:
			put(n, torus(0.02, 0.035, 10), mat(Color("#8A8AA0"), 0.4, 0.0, false), base + Vector3(0, y, 0))
	put(n, cyl(0.014, 0.016, stick_h, 8), mat(Color("#E8D6B0"), 0.8), base + Vector3(0, stick_h * 0.5, 0))
	var hub := node(n, base + Vector3(0, stick_h, 0.04))
	var rot := node(hub)
	anim(rot, "spin", {"axis": Vector3.BACK, "spd": 3.0})
	var cols := [Color("#FF5A6E"), Color("#FFD34D"), Color("#3FD0FF"), Color("#7AE08A")]
	for i in 4:
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0.0), Vector2(0.15, 0.1)])
		var bl := put(rot, extrude(poly, 0.012), mat(cols[i], 0.6, 0.15), Vector3.ZERO, Vector3(0, 0.25, i * PI / 2.0))
		bl.name = "blade"
	put(hub, sphere(0.03, 10), mat(Color("#FFFFFF"), 0.6), Vector3(0, 0, 0.02))


func _d_lamp(n: Node3D, sk: String) -> void:
	var y0 := 0.0
	if sk == "floor":
		put(n, cyl(0.03, 0.04, 0.6, 8), mat(Color("#2E3A5A"), 0.7), Vector3(0, 0.3, 0))
		put(n, cyl(0.1, 0.12, 0.04, 12), mat(Color("#2E3A5A"), 0.7), Vector3(0, 0.02, 0))
		y0 = 0.6
	var frame := mat(Color("#2E3A5A"), 0.6)
	put(n, cyl(0.14, 0.16, 0.05, 12), frame, Vector3(0, y0 + 0.025, 0))
	put(n, sphere(0.15, 18), glass(Color(1.0, 0.92, 0.6, 0.6), 1.4), Vector3(0, y0 + 0.24, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
	for k in 4:
		var a := k * PI / 2.0
		put(n, tube(bez(Vector3(0, y0 + 0.05, 0) + dir(a) * 0.12, Vector3(0, y0 + 0.24, 0) + dir(a) * 0.19, Vector3(0, y0 + 0.44, 0) + dir(a) * 0.08, 6), 0.012, 0.012, 4), frame)
	put(n, cyl(0.0, 0.2, 0.14, 12), mat(Color("#2E3A5A"), 0.6), Vector3(0, y0 + 0.5, 0))
	put(n, torus(0.05, 0.075, 12), frame, Vector3(0, y0 + 0.6, 0), Vector3(PI / 2.0, 0, 0))
	var fl := put(n, sphere(0.06, 10), glow_mat(Color("#FFF8D8"), 3.0), Vector3(0, y0 + 0.23, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	anim(fl, "flame")
	omni(n, Vector3(0, y0 + 0.25, 0.1), Color("#FFD98A"), 1.0, 3.0, "flicker")
	halo(n, Vector3(0, y0 + 0.24, 0), 1.0, Color(1.0, 0.85, 0.5, 0.4))


func _d_bed(n: Node3D) -> void:
	put(n, torus(0.26, 0.48, 32), mat(Color("#3FA9A0"), 0.95), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.9, 0.8))
	put(n, cyl(0.36, 0.36, 0.08, 28), mat(Color("#2F8A82"), 0.95, 0.0, false), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	put(n, sphere(0.33, 22), mat(Color("#F4E6D4"), 1.0), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.0, 0.22, 0.8))
	var dots := []
	for i in 12:
		var a := TAU * i / 12.0
		dots.append(Transform3D(Basis(), Vector3(cos(a) * 0.48, 0.12, sin(a) * 0.38)))
	scatter(n, sphere(0.025, 6), mat(Color("#FFD34D"), 0.6, 0.3, false), dots)
	var pw := node(n, Vector3(0.1, 0.18, 0.02))
	pw.rotation.x = -PI / 2.0
	_paw(pw, Vector3.ZERO, 1.2, Color("#D8BFA4"))


func _d_kite(n: Node3D) -> void:
	var k := node(n, Vector3(0.9, 0.55, 0.3))
	anim(k, "drift", {"amp": Vector3(0.15, 0.12, 0.08), "tilt": 0.12})
	var q := [Vector2(0, 0.32), Vector2(0.24, 0.02), Vector2(0, -0.36), Vector2(-0.24, 0.02)]
	var cols := [Color("#FF5A6E"), Color("#FFD34D"), Color("#3FD0FF"), Color("#7AE08A")]
	for i in 4:
		var poly := PackedVector2Array([Vector2.ZERO, q[i], q[(i + 1) % 4]])
		put(k, extrude(poly, 0.015), mat(cols[i], 0.6, 0.15))
	put(k, tube([Vector3(0, 0.32, 0.01), Vector3(0, -0.36, 0.01)], 0.008, 0.008, 4), mat(Color("#5A3A2E"), 0.8, 0.0, false))
	put(k, tube([Vector3(-0.24, 0.02, 0.01), Vector3(0.24, 0.02, 0.01)], 0.008, 0.008, 4), mat(Color("#5A3A2E"), 0.8, 0.0, false))
	# хвост с бантиками
	var tail := node(k, Vector3(0, -0.36, 0))
	anim(tail, "wiggle", {"axis": Vector3.BACK, "amp": 0.3, "spd": 2.6})
	var tp := []
	for i in 9:
		var s := i / 8.0
		tp.append(Vector3(sin(s * 5.0) * 0.06 * s, -s * 0.55, 0))
	put(tail, tube(tp, 0.006, 0.006, 4), mat(Color("#F4E6D4"), 0.8, 0.0, false))
	var bc := [Color("#FF8FC8"), Color("#FFD34D"), Color("#7FE3FF")]
	for i in 3:
		var p: Vector3 = tp[2 + i * 3]
		for sx in [-1.0, 1.0]:
			put(tail, prism(Vector3(0.07, 0.05, 0.01)), mat(bc[i], 0.7, 0.1, false), p + Vector3(sx * 0.035, 0, 0), Vector3(0, 0, sx * PI / 2.0))
	# нитка от ветки к змею
	var line := []
	for i in 9:
		var s := i / 8.0
		line.append(Vector3(0.9, 0.55, 0.3) * s + Vector3(0, -sin(s * PI) * 0.12, 0))
	put(n, tube(line, 0.004, 0.004, 3), mat(Color("#F4F0FF"), 0.8, 0.0, false))


func _d_teddy(n: Node3D) -> void:
	var br := mat(Color("#B9805A"), 0.95)
	var lt := mat(Color("#E8C29A"), 0.95)
	put(n, sphere(0.16, 18), br, Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1.0, 1.05, 0.85))
	put(n, sphere(0.09, 14), lt, Vector3(0, 0.17, 0.1), Vector3.ZERO, Vector3(1.0, 1.1, 0.5))
	for sx in [-1.0, 1.0]:
		put(n, sphere(0.07, 12), br, Vector3(sx * 0.11, 0.05, 0.1), Vector3.ZERO, Vector3(1.0, 0.8, 1.2))
		put(n, sphere(0.04, 10), lt, Vector3(sx * 0.11, 0.05, 0.17), Vector3.ZERO, Vector3(1, 1, 0.4))
		put(n, sphere(0.06, 12), br, Vector3(sx * 0.15, 0.2, 0.05), Vector3(0, 0, sx * 0.5), Vector3(0.8, 1.4, 0.8))
	var head := node(n, Vector3(0, 0.38, 0))
	anim(head, "wiggle", {"axis": Vector3.BACK, "amp": 0.08, "spd": 1.5})
	put(head, sphere(0.13, 18), br, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 0.95))
	for sx in [-1.0, 1.0]:
		put(head, sphere(0.05, 10), br, Vector3(sx * 0.1, 0.1, -0.01))
		put(head, sphere(0.028, 8), lt, Vector3(sx * 0.1, 0.1, 0.02), Vector3.ZERO, Vector3(1, 1, 0.5))
		put(head, sphere(0.016, 8), mat(OUT, 0.3, 0.0, false), Vector3(sx * 0.05, 0.02, 0.115))
	put(head, sphere(0.055, 12), lt, Vector3(0, -0.035, 0.1), Vector3.ZERO, Vector3(1.1, 0.8, 0.7))
	put(head, sphere(0.02, 8), mat(OUT, 0.3, 0.0, false), Vector3(0, -0.02, 0.14))
	# бантик на шее
	for sx in [-1.0, 1.0]:
		put(n, prism(Vector3(0.08, 0.06, 0.03)), mat(Color("#FF4FA3"), 0.6, 0.0, false), Vector3(sx * 0.04, 0.29, 0.11), Vector3(0, 0, sx * PI / 2.0))
	put(n, sphere(0.02, 8), mat(Color("#FF4FA3"), 0.6, 0.0, false), Vector3(0, 0.29, 0.12))
