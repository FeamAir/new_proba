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
## 0.15: места на заборе и большие места (углы по кругу, как у забора)
const WALL_L_A := deg_to_rad(150.0)
const WALL_2_A := deg_to_rad(196.0)
const FENCE_TOP_A := deg_to_rad(228.0)
const BIG_BACK_A := deg_to_rad(240.0)
const BIG_SIDE_A := deg_to_rad(176.0)

static var _geo := {}
var _sway: ShaderMaterial
## 0.15: стиль сада — варианты забора / земли / света (узлы строятся при первом выборе и потом только
## показываются / прячутся), небо, луна, трава и цветы (их прячет площадка с разметкой)
var _wall_nodes := {}
var _floor_nodes := {}
var _light_nodes := {}
var _sky_mat: ShaderMaterial
var _moon_nodes: Array = []
var _grass: MultiMeshInstance3D
var _grass_xf: Array = []
var _grass_col: Array = []
var _garden_mm: Array = []
var _hq_counts := {}


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
		"wall_l": {"pos": dir(WALL_L_A) * (FENCE_R - 0.08) + Vector3(0, 0.62, 0), "yaw": face_center(WALL_L_A),
			"mark": Vector3(0, 0.35, 0.3), "stand": Vector3(0, 0.05, 0.16)},
		"wall_r": {"pos": dir(deg_to_rad(318.0)) * 3.55 + Vector3(0, 0.95, 0), "yaw": face_center(deg_to_rad(318.0)),
			"mark": Vector3(0, 0.35, 0.3), "stand": Vector3(0, 0.06, 0.26)},
		"hang": {"pos": branch, "yaw": PI - TREE_A, "mark": Vector3(0, -0.8, 0)},
		"near": {"pos": Vector3(0.95, 0.0, 1.45), "yaw": 0.25, "mark": Vector3(0, 0.3, 0)},
	}
	for s in ["floor_l", "floor_r"]:
		spots[s]["mark"] = Vector3(0, 0.3, 0)
	# 0.15: новые места (типы — scripts/decor_data/puppy.gd). Камера ходит спереди и по бокам (±110°),
	# поэтому всё — слева у забора, у будки и впереди; справа — стенд кубков, скала и дорожка.
	spots["near_2"] = {"pos": Vector3(-0.95, 0.0, 1.45), "yaw": -0.25, "mark": Vector3(0, 0.3, 0)}
	spots["tree"] = {"pos": tree_p + (Vector3.ZERO - tree_p).normalized() * 0.85 + Vector3(0, 2.06, 0), "yaw": PI - TREE_A,
		"mark": Vector3(0, -0.8, 0)}
	# трава впереди справа (у дорожки), между «рядом» и «полом справа»
	spots["floor_front"] = {"pos": Vector3(1.35, 0, 2.6), "yaw": face_to(Vector3(1.35, 0, 2.6), Vector3(0, 0, 0.6)), "mark": Vector3(0, 0.3, 0)}
	# большие места: у забора за будкой слева и у забора слева (напротив стенда кубков)
	# "view" — откуда смотреть при подлёте (мимо будки, дерева и фонарей)
	spots["big_back"] = {"pos": dir(BIG_BACK_A) * 3.0, "yaw": face_to(dir(BIG_BACK_A) * 3.0, Vector3(0.6, 0, 1.0)), "mark": Vector3(0, 0.5, 0),
		"view": Vector3(-0.25, 0, 1.0)}
	spots["big_side"] = {"pos": dir(BIG_SIDE_A) * 3.1, "yaw": face_to(dir(BIG_SIDE_A) * 3.1, Vector3(0.4, 0, 1.6)), "mark": Vector3(0, 0.5, 0),
		"view": Vector3(0.85, 0, 0.55)}
	# второе место на заборе (за большим местом сбоку), стенка будки справа, крыша будки, полочка на заборе
	spots["wall_2"] = {"pos": dir(WALL_2_A) * (FENCE_R - 0.08) + Vector3(0, 0.62, 0), "yaw": face_center(WALL_2_A),
		"mark": Vector3(0, 0.35, 0.3), "stand": Vector3(0, 0.05, 0.16)}
	spots["house_wall"] = {"pos": Vector3(0.66, 0.5, -0.12), "yaw": PI / 2.0, "mark": Vector3(0, 0.3, 0.25), "stand": Vector3(0, 0.05, 0.17)}
	spots["roof"] = {"pos": Vector3(0, 1.69, -0.3), "yaw": 0.0, "mark": Vector3(0, 0.3, 0.1), "stand": Vector3(0, 0.04, 0.0)}
	spots["fence_top"] = {"pos": dir(FENCE_TOP_A) * (FENCE_R - 0.08) + Vector3(0, 0.98, 0), "yaw": face_center(FENCE_TOP_A),
		"mark": Vector3(0, 0.3, 0.2), "stand": Vector3(0, 0.05, 0.12)}
	# 0.14: полка славы — деревянный стенд «доска почёта» в саду справа от будки (не загораживает скалу с местом «стена справа»)
	var sp_pos := Vector3(3.1, 0, -0.45)
	shelf_def = {"style": "puppy", "pos": sp_pos, "yaw": face_to(sp_pos, Vector3(-0.3, 0, 2.6)), "rows": [[0.52, 0.0], [0.94, 0.0]],
		"spacing": 0.3, "scale": 0.82, "depth": 0.24, "front_z": 0.13, "plaque_z": 0.135, "plaque_y": -0.03,
		"focus_d": 0.54, "view_d": 1.75}


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
	if flat.length() < 1.0 and at.y > 1.4:
		return Vector3(0.3, 0, 1.0)  # 0.15: крыша будки — спереди
	if flat.length() < 2.0:
		return (flat.normalized() + Vector3(0, 0, 0.6)).normalized()
	return -flat.normalized().rotated(Vector3.UP, 0.35)


## 0.15: большие вещи (беседка, палатка, рампа) — издалека и чуть сверху, чтобы были видны целиком
func focus_spot(spot: String) -> void:
	if spots.has(spot) and spot_kind(spot) == "big" and spot_focus.has(spot):
		var at: Vector3 = spot_focus[spot][0]
		cam.fly_to(at, spots[spot].get("view", _view_dir(at)), maxf(float(spot_focus[spot][1]) * 1.35, 2.7), 0.32)
		return
	super.focus_spot(spot)


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
	# 0.15: своё небо (как sky_dome, но с цветами под стиль «свет»: закат, праздник, неон)
	_sky_mat = _shader_mat("pup_sky", PUP_SKY, {"rainbow": 1.0 if stage >= 3 else 0.0})
	var dome := put(h, sphere(24.0, 32), _sky_mat, Vector3.ZERO)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.extra_cull_margin = 30.0
	var md := Vector3(0.55, 0.42, -0.72).normalized()
	var mp := md * 20.0
	var moon_n := node(h)
	moon_n.name = "moon"
	_moon_nodes.append(moon_n)
	anim(moon_n, "bob", {"amp": 0.0})  # не склеивать с домом: на закате луну прячем
	put(moon_n, sphere(1.1, 24), mat(Color("#FFF3C9"), 1.0, 1.7, false), mp)
	for cr in [[Vector3(-0.35, 0.3, 0.5), 0.25], [Vector3(0.3, -0.3, 0.5), 0.18]]:
		put(moon_n, sphere(cr[1], 10), mat(Color("#EFDDA0"), 1.0, 1.3, false), mp + Basis.looking_at(-md) * (cr[0] as Vector3) - md * 0.8, Vector3.ZERO, Vector3(1, 1, 0.4))
	var hl := halo(h, mp - md * 1.2, 7.0, Color(1.0, 0.92, 0.65, 0.4))
	_moon_nodes.append(hl)
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
	floor_parts.append(mi)  # 0.15: стиль «пол» — земля и трава
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
	_grass = mmi
	_grass_xf = xfs
	_grass_col = cols


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
	# 0.15: стиль «стены» у щенка — забор (штакетник — свой узел, другие заборы строятся при выборе) и будка
	var fr := node(h)
	fr.name = "fence_picket"
	_wall_nodes["pup_walls_picket"] = fr
	wall_parts.append(fr)
	scatter(fr, box(Vector3(0.16, 0.9, 0.05)), mat(picket, 0.85), xfs)
	scatter(fr, prism(Vector3(0.16, 0.1, 0.05)), mat(picket, 0.85), tops)
	# две перекладины — трубками по дуге
	for y in [0.3, 0.72]:
		var pts := []
		for i in 25:
			pts.append(dir(lerpf(FENCE_A0, FENCE_A1, i / 24.0)) * (FENCE_R + 0.05) + Vector3(0, y, 0))
		put(fr, tube(pts, 0.03, 0.03, 4), mat(Color("#B8A6C8"), 0.9))
	# столбики по краям
	for a in [FENCE_A0, FENCE_A1]:
		put(fr, cyl(0.07, 0.08, 1.15, 10), mat(Color("#B8A6C8"), 0.9), dir(a) * FENCE_R + Vector3(0, 0.57, 0))
		put(fr, sphere(0.09, 10), mat(Color("#E9DFF0"), 0.9), dir(a) * FENCE_R + Vector3(0, 1.18, 0))
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
	wall_parts.push_front(d)  # 0.15: будку стиль «забор» слегка подкрашивает (первая в списке — для тестов стиля)
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
		for s in ["floor_l", "floor_r", "near", "near_2", "floor_front", "big_back", "big_side"]:
			var rr2 := 1.25 if s.begins_with("big") else 0.75
			if Vector2(p.x - spots[s].pos.x, p.z - spots[s].pos.z).length() < rr2:
				near_spot = true
		if near_spot:
			continue
		var hh := 0.22 + 0.15 * hash1(i, 95)
		p.y = _ground_h(p)
		stems.append(Transform3D(Basis.from_scale(Vector3(1, hh / 0.3, 1)), p + Vector3(0, hh * 0.5, 0)))
		heads.append(Transform3D(Basis(Vector3.UP, i), p + Vector3(0, hh, 0)))
		hcols.append(fl[i % fl.size()])
	_garden_mm.append([scatter(h, cyl(0.008, 0.01, 0.3, 4), mat(Color("#3F8A55"), 0.9, 0.0, false), stems), stems])
	# цветок: пять лепестков-шариков в одной сетке
	if not _geo.has("flower"):
		var st := SurfaceTool.new()
		for k in 5:
			var a := TAU * k / 5.0
			st.append_from(sphere(0.035, 8), 0, Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)), Vector3(cos(a) * 0.04, 0, sin(a) * 0.04)))
		st.append_from(sphere(0.025, 8), 0, Transform3D(Basis(), Vector3(0, 0.015, 0)))
		_geo["flower"] = st.commit()
	_garden_mm.append([scatter(h, _geo["flower"], vmat(0.7, 0.3), heads, hcols), heads])
	# кусты у забора
	# 0.15: кусты — между местами у забора (большие вещи и полочки не загораживают)
	for ad in [137.0, 161.0, 219.0, 253.0]:
		var a := deg_to_rad(ad)
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
	var wood := mat(Color("#B07A4E"), 0.85)
	var wood_d := mat(Color("#8A5A3A"), 0.85)
	match spot:
		"wall_r":
			put(n, sphere(0.45, 16), mat(Color("#524C80"), 0.9), Vector3(0, -0.2, 0.06), Vector3.ZERO, Vector3(1.2, 0.5, 0.8))
			put(n, sphere(0.4, 14), mat(Color("#6E68A0"), 0.9, 0.0, false), Vector3(0, 0.0, 0.14), Vector3.ZERO, Vector3(1.1, 0.08, 0.72))
		"roof":
			# дощечка-подставка на коньке крыши: лежит на обоих скатах
			put(n, box(Vector3(0.56, 0.045, 0.36)), wood, Vector3(0, 0.02, 0))
			put(n, box(Vector3(0.58, 0.015, 0.02)), mat(Color("#FFD34D"), 0.5, 0.2, false), Vector3(0, 0.02, 0.185))
			for sx in [-1.0, 1.0]:
				put(n, prism(Vector3(0.27, 0.25, 0.3), 1.0 if sx > 0.0 else 0.0), wood_d, Vector3(sx * 0.135, -0.125, 0), Vector3(PI, 0, 0))
		"fence_top", "house_wall":
			put(n, box(Vector3(0.6, 0.05, 0.28)), wood, Vector3(0, 0.0, 0.13))
			put(n, box(Vector3(0.62, 0.015, 0.02)), mat(Color("#FFD34D"), 0.5, 0.2, false), Vector3(0, 0.0, 0.275))
			for sx in [-0.21, 0.21]:
				put(n, prism(Vector3(0.04, 0.16, 0.2), 0.0), wood_d, Vector3(sx, -0.1, 0.1), Vector3(0, -PI / 2.0, 0))
		_:
			put(n, box(Vector3(0.62, 0.05, 0.3)), wood, Vector3(0, 0.0, 0.14))
			for sx in [-0.22, 0.22]:
				put(n, prism(Vector3(0.04, 0.16, 0.2), 0.0), wood_d, Vector3(sx, -0.1, 0.1), Vector3(0, -PI / 2.0, 0))


# ---------- Украшения ----------

func _decor(id: String, n: Node3D, sk: String) -> void:
	# 0.15: на стенке будки места меньше, чем на заборе: плоские вещи — чуть меньше и ниже (под скатом крыши)
	if sk == "wall" and _spot_of(n) == "house_wall":
		n = node(n, Vector3(0, -0.12, 0.02))
		n.scale = Vector3.ONE * 0.72
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
		# 0.15
		"pup_sunflowers": _d_sunflowers(n, sk)
		"pup_picnic": _d_picnic(n)
		"pup_birdbath": _d_birdbath(n)
		"pup_gazebo": _d_gazebo(n)
		"pup_pennants": _d_pennants(n, sk)
		"pup_binoculars": _d_binoculars(n, sk)
		"pup_backpack": _d_backpack(n)
		"pup_trailmap": _d_trailmap(n, sk)
		"pup_canoe": _d_canoe(n, sk)
		"pup_tent": _d_tent(n, sk)
		"pup_campfire": _d_campfire(n, sk)
		"pup_cones": _d_cones(n, sk)
		"pup_spray": _d_spray(n)
		"pup_headphones": _d_headphones(n, sk)
		"pup_skateboard": _d_skateboard(n)
		"pup_hoop": _d_hoop(n, sk)
		"pup_graffiti": _d_graffiti(n, sk)
		"pup_boombox": _d_boombox(n, sk)
		"pup_neon": _d_neon(n, sk)
		"pup_ramp": _d_ramp(n)


## Место, на котором строится вещь (узел «spot_<место>» выше по дереву)
func _spot_of(n: Node) -> String:
	var p := n
	while p != null and p != self:
		if String(p.name).begins_with("spot_"):
			return String(p.name).substr(5)
		p = p.get_parent()
	return ""


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


# ---------- 0.15: новые украшения ----------
# Начало координат — точка места: на земле (floor / near / big), на полочке ("ledge") или на заборе ("wall",
# плоская вещь). +Z — в сад (к будке). Поворот на месте делает каркас (room.gd).

## Короткая запись материала по цвету-строке (кэш mat() общий на все комнаты)
static func _m(c: String, rough := 0.85, emit := 0.0, outline := true) -> StandardMaterial3D:
	return mat(Color(c), rough, emit, outline)


## Подсолнух: головка из двух колец лепестков и серединки (кольца — одна сетка на все подсолнухи)
func _sunflower_head(parent: Node3D, k: float) -> void:
	if not _geo.has("sf_petals"):
		for key in ["sf_petals", "sf_petals2"]:
			var st := SurfaceTool.new()
			var nn := 13
			for i in nn:
				var a := TAU * (i + (0.5 if key == "sf_petals2" else 0.0)) / nn
				var r := 0.1 if key == "sf_petals" else 0.085
				var b := Basis(Vector3.BACK, a - PI / 2.0) * Basis.from_scale(Vector3(0.4, 1.0, 0.16))
				st.append_from(sphere(0.055, 8), 0, Transform3D(b, Vector3(cos(a) * r, sin(a) * r, -0.004 if key == "sf_petals" else 0.0)))
			_geo[key] = st.commit()
	var h := node(parent)
	h.scale = Vector3.ONE * k
	put(h, _geo["sf_petals"], _m("#FFC93C", 0.7, 0.12))
	put(h, _geo["sf_petals2"], _m("#FFA928", 0.7, 0.0, false))
	put(h, cyl(0.07, 0.075, 0.035, 16), _m("#6B3F22", 0.95), Vector3(0, 0, 0.012), Vector3(PI / 2.0, 0, 0))
	put(h, sphere(0.055, 12), _m("#8A5432", 0.95, 0.0, false), Vector3(0, 0, 0.025), Vector3.ZERO, Vector3(1, 1, 0.35))


func _d_sunflowers(n: Node3D, sk: String) -> void:
	var base := n
	var k := 1.0
	if sk == "ledge":
		put(n, lathe([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.13, 0.15), Vector2(0.145, 0.17), Vector2(0.0, 0.17)], 18), _m("#D9774A", 0.8))
		put(n, torus(0.12, 0.155, 18), _m("#F09A6A", 0.8), Vector3(0, 0.165, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		put(n, cyl(0.125, 0.125, 0.02, 16), _m("#4A2E22", 1.0, 0.0, false), Vector3(0, 0.16, 0))
		_paw(n, Vector3(0, 0.09, 0.125), 0.7, Color("#FFF1DC"))
		base = node(n, Vector3(0, 0.16, 0))
		k = 0.5
	else:
		put(n, sphere(0.3, 14), _m("#4A3A2A", 1.0, 0.0, false), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.2, 0.85))
	var hs := [1.0, 0.82, 0.66]
	var offs := [Vector3(-0.1, 0, -0.04), Vector3(0.13, 0, -0.06), Vector3(0.02, 0, 0.11)]
	var stem := _m("#3F8A55", 0.9, 0.0, false)
	var leaf := _m("#5BC27E", 0.9)
	for i in 3:
		var hh: float = hs[i] * (0.62 if sk == "ledge" else 1.0)
		var st := node(base, (offs[i] as Vector3) * k * 1.6)
		anim(st, "sway", {"amp": 0.04, "spd": 0.9, "p": float(i) * 1.7})
		put(st, tube(bez(Vector3.ZERO, Vector3(0.04, hh * 0.5, 0), Vector3(0, hh, 0), 5), 0.02, 0.013, 5), stem)
		for side in [-1.0, 1.0]:
			put(st, sphere(0.07, 10), leaf, Vector3(side * 0.06, hh * (0.4 if side < 0 else 0.6), 0), Vector3(0, 0, side * 0.7), Vector3(1.1, 0.35, 0.6))
		var hd := node(st, Vector3(0, hh, 0.01))
		anim(hd, "wiggle", {"axis": Vector3.UP, "amp": 0.45, "spd": 0.32, "p": float(i) * 2.1})
		var tilt := node(hd)
		tilt.rotation.x = -0.35
		_sunflower_head(tilt, 1.15 if sk != "ledge" else 0.9)


func _d_picnic(n: Node3D) -> void:
	# плед в клетку
	put(n, extrude(rrect_poly(1.0, 0.8, 0.06), 0.02), _m("#FFF4E6", 0.95), Vector3(0, 0.012, 0), Vector3(-PI / 2.0, 0, 0))
	var sq := []
	for i in 5:
		for j in 4:
			if (i + j) % 2 == 0:
				sq.append(Transform3D(Basis(), Vector3(-0.4 + i * 0.2, 0.024, -0.3 + j * 0.2)))
	scatter(n, box(Vector3(0.19, 0.006, 0.19)), _m("#E8505B", 0.95, 0.0, false), sq)
	# корзинка: крышка подпрыгивает
	var bk := node(n, Vector3(-0.24, 0.02, -0.14))
	bk.rotation.y = 0.25
	put(bk, box(Vector3(0.36, 0.2, 0.25)), _m("#C98A4A", 0.95), Vector3(0, 0.1, 0))
	for y in [0.05, 0.12]:
		put(bk, box(Vector3(0.365, 0.025, 0.255)), _m("#A8692F", 0.95, 0.0, false), Vector3(0, y, 0))
	put(bk, tube(bez(Vector3(-0.13, 0.2, 0), Vector3(0, 0.42, 0), Vector3(0.13, 0.2, 0), 7), 0.014, 0.014, 5), _m("#A8692F", 0.9))
	put(bk, sphere(0.06, 10), _m("#FF5A5A", 0.6), Vector3(0.08, 0.2, 0.02))
	var lid := node(bk, Vector3(0, 0.2, -0.125))
	anim(lid, "hinge", {"axis": Vector3.RIGHT, "ang": 0.55, "spd": 1.3})
	put(lid, box(Vector3(0.38, 0.035, 0.26)), _m("#E0A260", 0.95), Vector3(0, 0.018, 0.128))
	put(lid, box(Vector3(0.39, 0.036, 0.04)), _m("#E8505B", 0.8, 0.0, false), Vector3(0, 0.02, 0.128))
	# тарелки, бутерброд, кексик, чашки
	var plate := _m("#FFFFFF", 0.5)
	for pp in [Vector3(0.22, 0.03, 0.08), Vector3(-0.02, 0.03, 0.22)]:
		put(n, cyl(0.1, 0.085, 0.018, 20), plate, pp)
		put(n, torus(0.085, 0.1, 20), _m("#7FC8F0", 0.5, 0.0, false), pp + Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	var sw := Vector3(0.22, 0.04, 0.08)
	put(n, box(Vector3(0.12, 0.025, 0.09)), _m("#F2C27A"), sw + Vector3(0, 0.01, 0), Vector3(0, 0.4, 0))
	put(n, box(Vector3(0.13, 0.012, 0.1)), _m("#7AD06A", 0.9, 0.0, false), sw + Vector3(0, 0.028, 0), Vector3(0, 0.45, 0))
	put(n, box(Vector3(0.12, 0.025, 0.09)), _m("#F2C27A"), sw + Vector3(0, 0.045, 0), Vector3(0, 0.4, 0))
	var cp := Vector3(-0.02, 0.04, 0.22)
	put(n, cyl(0.04, 0.03, 0.05, 12), _m("#7FC8F0", 0.8), cp + Vector3(0, 0.025, 0))
	put(n, sphere(0.045, 12), _m("#FF9EC6", 0.8), cp + Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	put(n, sphere(0.016, 8), _m("#E8303B", 0.5, 0.0, false), cp + Vector3(0, 0.1, 0))
	for c in [[Vector3(0.3, 0.02, -0.18), "#FFB0C8"], [Vector3(0.17, 0.02, -0.26), "#9FD8FF"]]:
		put(n, cyl(0.035, 0.03, 0.08, 12), _m(c[1], 0.6), (c[0] as Vector3) + Vector3(0, 0.04, 0))
		put(n, torus(0.02, 0.03, 10), _m(c[1], 0.6, 0.0, false), (c[0] as Vector3) + Vector3(0.04, 0.045, 0), Vector3(PI / 2.0, 0, 0))


func _d_birdbath(n: Node3D) -> void:
	var stone := _m("#B9B4D6", 0.9)
	put(n, lathe([Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, 0.05), Vector2(0.1, 0.1), Vector2(0.07, 0.45), Vector2(0.1, 0.55),
		Vector2(0.3, 0.62), Vector2(0.34, 0.7), Vector2(0.3, 0.72), Vector2(0.0, 0.66)], 24), stone)
	put(n, torus(0.06, 0.1, 16), _m("#9A94C0", 0.9, 0.0, false), Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	put(n, cyl(0.295, 0.295, 0.01, 28), mat(Color("#6FC8F0"), 0.15, 0.35), Vector3(0, 0.685, 0))
	var rip := put(n, torus(0.1, 0.12, 24), mat(Color("#BFEFFF"), 0.2, 0.6, false), Vector3(0, 0.692, 0), Vector3.ZERO, Vector3(1, 0.15, 1))
	anim(rip, "pulse", {"amp": 0.6, "spd": 1.6})
	# мох и цветочки у подножия
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		put(n, sphere(0.05, 8), mat([Color("#FF8FC8"), Color("#FFE27A"), Color("#B8A2FF")][i % 3], 0.7, 0.1, false), dir(a) * 0.24 + Vector3(0, 0.05, 0))
		put(n, sphere(0.07, 8), _m("#3F8A55", 1.0, 0.0, false), dir(a + 0.4) * 0.25 + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	# птичка прыгает по краю
	var bird := node(n, Vector3(0, 0.72, 0))
	anim(bird, "call", {"f": _a_birdhop})
	var body := _m("#5FB8FF", 0.7)
	put(bird, sphere(0.055, 14), body, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(0.85, 0.85, 1.2))
	put(bird, sphere(0.04, 10), _m("#FFF1DC", 0.8, 0.0, false), Vector3(0, 0.04, 0.03), Vector3.ZERO, Vector3(0.8, 0.8, 0.8))
	put(bird, sphere(0.04, 12), body, Vector3(0, 0.11, 0.045))
	put(bird, cyl(0.0, 0.014, 0.03, 6), _m("#FFB547", 0.6, 0.0, false), Vector3(0, 0.105, 0.09), Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		put(bird, sphere(0.008, 6), mat(OUT, 0.3, 0.0, false), Vector3(sx * 0.022, 0.12, 0.076))
		put(bird, sphere(0.03, 8), _m("#3F8FD8", 0.7, 0.0, false), Vector3(sx * 0.045, 0.055, -0.005), Vector3.ZERO, Vector3(0.4, 0.8, 1.2))
	put(bird, prism(Vector3(0.05, 0.06, 0.012)), _m("#3F8FD8", 0.7, 0.0, false), Vector3(0, 0.06, -0.075), Vector3(-PI / 2.0 - 0.4, 0, 0))


## Птичка: прыжками по краю поилки, иногда наклоняется попить
func _a_birdhop(nd: Node3D, t: float, a: Dictionary) -> void:
	var step := t * 1.4
	var i := floorf(step)
	var u := step - i
	var drinking := fposmod(i, 7.0) >= 5.0
	var ang := (i - floorf(i / 7.0) * 2.0 + (0.0 if drinking else smoothstep(0.0, 0.45, u))) * 0.45
	var hop := 0.0 if drinking else sin(u * PI) * 0.05
	var drink := sin(u * PI) * 0.6 if drinking else 0.0
	var p := Vector3(cos(ang) * 0.29, hop, sin(ang) * 0.29)
	nd.transform = Transform3D(Basis(Vector3.UP, -ang) * Basis(Vector3.RIGHT, drink), (a.base as Transform3D).origin + p)


## Беседка (★): шестигранная, белые столбики, розовая крыша, гирлянда огоньков, внутри качели
func _d_gazebo(n: Node3D) -> void:
	var R := 0.78
	var white := _m("#F4F0FA", 0.8)
	var trim := _m("#FFD1E0", 0.8)
	var roof := _m("#FF8FB1", 0.75)
	put(n, cyl(R + 0.1, R + 0.13, 0.12, 6), _m("#E2D8F0", 0.85), Vector3(0, 0.06, 0), Vector3(0, PI / 6.0, 0))
	put(n, cyl(R + 0.02, R + 0.02, 0.01, 6), _m("#C9A0DC", 0.9, 0.0, false), Vector3(0, 0.125, 0), Vector3(0, PI / 6.0, 0))
	put(n, box(Vector3(0.62, 0.06, 0.24)), _m("#E2D8F0", 0.85), Vector3(0, 0.03, R + 0.18))
	var tops := []
	for i in 6:
		var a := i * PI / 3.0
		var p := Vector3(cos(a), 0, sin(a)) * R * 0.92
		put(n, cyl(0.035, 0.045, 1.25, 8), white, p + Vector3(0, 0.75, 0))
		put(n, sphere(0.05, 8), trim, p + Vector3(0, 1.38, 0))
		tops.append(p + Vector3(0, 1.36, 0))
	# перила по бокам и сзади (спереди — вход)
	for i in 6:
		var mid := i * PI / 3.0 + PI / 6.0
		if absf(angle_difference(mid, PI / 2.0)) < 0.3:
			continue
		var p0: Vector3 = (tops[i] as Vector3) * Vector3(1, 0, 1)
		var p1: Vector3 = (tops[(i + 1) % 6] as Vector3) * Vector3(1, 0, 1)
		put(n, tube([p0 + Vector3(0, 0.5, 0), p1 + Vector3(0, 0.5, 0)], 0.018, 0.018, 5), white)
		for k in 3:
			put(n, cyl(0.012, 0.012, 0.36, 5), white, p0.lerp(p1, (k + 1) / 4.0) + Vector3(0, 0.31, 0))
	# крыша
	put(n, cyl(R + 0.3, R + 0.3, 0.06, 6), trim, Vector3(0, 1.4, 0))
	put(n, cyl(0.02, R + 0.28, 0.6, 6), roof, Vector3(0, 1.72, 0))
	var ribs := []
	for i in 6:
		var a := i * PI / 3.0
		ribs.append(Transform3D(Basis(), Vector3(cos(a), 0, sin(a)) * (R + 0.3) + Vector3(0, 1.4, 0)))
		put(n, tube([Vector3(cos(a), 0, sin(a)) * (R + 0.28) + Vector3(0, 1.43, 0), Vector3(0, 2.02, 0)], 0.02, 0.012, 4), _m("#FFFFFF", 0.7, 0.0, false))
	# фестоны по краю крыши
	var sc := []
	for i in 6:
		var a0 := i * PI / 3.0
		var a1 := a0 + PI / 3.0
		for k in 4:
			var u := (k + 0.5) / 4.0
			var p := (Vector3(cos(a0), 0, sin(a0)).lerp(Vector3(cos(a1), 0, sin(a1)), u)) * (R + 0.3)
			sc.append(Transform3D(Basis.from_scale(Vector3(1, 0.7, 1)), p + Vector3(0, 1.36, 0)))
	scatter(n, sphere(0.045, 8), trim, sc)
	scatter(n, sphere(0.05, 8), roof, ribs)
	put(n, sphere(0.07, 12), _m("#FFD34D", 0.4, 0.4), Vector3(0, 2.07, 0))
	var star := put(n, extrude(star_poly(0.09, 0.04), 0.03), glow_mat(Color("#FFE27A"), 1.6), Vector3(0, 2.24, 0))
	anim(star, "spin", {"spd": 0.8})
	# гирлянда огоньков под краем крыши: провисает от столбика к столбику; три группы мигают по очереди
	var wire := []
	var bulbs := [[], [], []]
	for i in 6:
		var p0: Vector3 = tops[i]
		var p1: Vector3 = tops[(i + 1) % 6]
		for k in 7:
			var u := k / 6.0
			var q := p0.lerp(p1, u) + Vector3(0, -sin(u * PI) * 0.14, 0)
			wire.append(q)
			if k % 2 == 1:
				bulbs[(i + k) % 3].append(Transform3D(Basis.from_scale(Vector3(1, 1.3, 1)), q + Vector3(0, -0.04, 0)))
	put(n, tube(wire, 0.006, 0.006, 3), mat(Color("#2A2040"), 0.9, 0.0, false))
	var bc := [Color("#FFE27A"), Color("#FF8FC8"), Color("#9FF0FF")]
	var mats := []
	for g in 3:
		var m := glow_mat(bc[g], 2.4, true)
		mats.append(m)
		scatter(n, sphere(0.035, 8), m, bulbs[g])
	var blink := node(n)
	anim(blink, "call", {"f": _a_mats_twinkle, "mats": mats, "e0": 2.0, "e1": 1.2})
	halo(n, Vector3(0, 1.1, 0), 2.2, Color(1.0, 0.75, 0.85, 0.16))
	# качели внутри
	var sw := node(n, Vector3(0, 1.38, 0.05))
	anim(sw, "swing", {"amp": 0.16, "spd": 1.3})
	for sx in [-0.2, 0.2]:
		put(sw, cyl(0.008, 0.008, 0.82, 4), _m("#C9B88A", 1.0, 0.0, false), Vector3(sx, -0.41, 0))
	put(sw, box(Vector3(0.5, 0.04, 0.2)), _m("#C98A4A", 0.85), Vector3(0, -0.83, 0))
	put(sw, sphere(0.2, 14), _m("#FF9EC6", 1.0), Vector3(0, -0.78, 0), Vector3.ZERO, Vector3(1.15, 0.25, 0.5))
	put(sw, extrude(heart_poly(0.11), 0.05), _m("#FF4F8A", 0.8), Vector3(0.1, -0.68, -0.03), Vector3(-0.2, 0, 0))
	# цветы в горшках у входа
	for sx in [-1.0, 1.0]:
		var fp := Vector3(sx * 0.42, 0.0, R + 0.28)
		put(n, lathe([Vector2(0, 0), Vector2(0.08, 0), Vector2(0.1, 0.14), Vector2(0, 0.14)], 12), _m("#D9774A", 0.8), fp)
		for k in 4:
			var a := TAU * k / 4.0
			put(n, sphere(0.05, 8), mat([Color("#FF6FA8"), Color("#FFFFFF")][k % 2], 0.7, 0.1, false), fp + Vector3(cos(a) * 0.05, 0.19, sin(a) * 0.05))
		put(n, sphere(0.07, 8), _m("#3F8A55", 1.0, 0.0, false), fp + Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1, 0.6, 1))


## Несколько светящихся материалов по очереди ярче / тусклее (огоньки гирлянды — одна сетка на группу)
func _a_mats_twinkle(_nd: Node3D, t: float, a: Dictionary) -> void:
	var ms: Array = a.mats
	for i in ms.size():
		(ms[i] as StandardMaterial3D).emission_energy_multiplier = float(a.e0) + float(a.e1) * sin(t * 2.2 + i * TAU / ms.size())


static func _flag_poly() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.06, 0), Vector2(0.06, 0), Vector2(0, -0.13)])


func _d_pennants(n: Node3D, sk: String) -> void:
	var cols := ["#FF5A6E", "#FFD34D", "#3FC8B8", "#FF8A3D", "#9C7BFF"]
	var rope := _m("#E8D6B0", 1.0, 0.0, false)
	if not _geo.has("flag"):
		_geo["flag"] = extrude(_flag_poly(), 0.01)
	var flag: Mesh = _geo["flag"]
	if sk == "hang":
		# обруч с флажками на трёх верёвочках, медленно вращается
		var ring := node(n, Vector3(0, -0.42, 0))
		anim(ring, "spin", {"spd": 0.35})
		for i in 3:
			var a := TAU * i / 3.0
			put(n, tube([Vector3.ZERO, Vector3(cos(a) * 0.3, -0.42, sin(a) * 0.3)], 0.005, 0.005, 3), rope)
		put(ring, torus(0.29, 0.32, 28), _m("#C98A4A", 0.85))
		for i in 10:
			var a := TAU * i / 10.0
			var f := node(ring, Vector3(cos(a) * 0.305, -0.01, sin(a) * 0.305))
			f.rotation.y = -a + PI / 2.0
			anim(f, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.22, "spd": 2.6, "p": float(i)})
			put(f, flag, _m(cols[i % 5], 0.8))
		put(ring, sphere(0.05, 10), _m("#FFD34D", 0.5, 0.3), Vector3(0, -0.12, 0))
		put(ring, cyl(0.004, 0.004, 0.12, 3), rope, Vector3(0, -0.06, 0))
		return
	# на заборе: провисающая нитка между двумя гвоздиками
	var pts := []
	for i in 13:
		var u := i / 12.0
		pts.append(Vector3(lerpf(-0.52, 0.52, u), 0.44 - sin(u * PI) * 0.1, 0.03))
	put(n, tube(pts, 0.006, 0.006, 3), rope)
	for sx in [-0.52, 0.52]:
		put(n, sphere(0.018, 6), _m("#8A8AA0", 0.4, 0.0, false), Vector3(sx, 0.44, 0.03))
	for i in 7:
		var p: Vector3 = pts[1 + i * 10 / 6]
		var f := node(n, p + Vector3(0, -0.005, 0.01))
		anim(f, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.3, "spd": 2.4, "p": float(i) * 0.8})
		put(f, flag, _m(cols[i % 5], 0.8))


func _d_binoculars(n: Node3D, sk: String) -> void:
	var y := 0.13
	if sk == "ledge":
		put(n, cyl(0.06, 0.07, 0.04, 12), _m("#8A5A3A", 0.85), Vector3(0, 0.02, 0))
		put(n, cyl(0.015, 0.015, 0.09, 6), _m("#3A2A55", 0.6), Vector3(0, 0.08, 0))
	else:
		y = 0.46
		for i in 3:
			var a := TAU * i / 3.0 + 0.5
			put(n, tube([Vector3(0, 0.44, 0), dir(a) * 0.2], 0.012, 0.016, 5), _m("#8A5A3A", 0.85))
		put(n, cyl(0.03, 0.035, 0.05, 10), _m("#3A2A55", 0.6), Vector3(0, 0.44, 0))
	var head := node(n, Vector3(0, y, 0))
	anim(head, "wiggle", {"axis": Vector3.UP, "amp": 0.7, "spd": 0.3})
	var tilt := node(head)
	tilt.rotation.x = -0.55  # к звёздам
	var body := _m("#2E6A50", 0.7)
	for sx in [-1.0, 1.0]:
		put(tilt, cyl(0.045, 0.04, 0.16, 14), body, Vector3(sx * 0.055, 0.03, 0.02), Vector3(PI / 2.0, 0, 0))
		put(tilt, cyl(0.05, 0.05, 0.03, 14), _m("#1E1836", 0.6), Vector3(sx * 0.055, 0.03, 0.11), Vector3(PI / 2.0, 0, 0))
		put(tilt, cyl(0.04, 0.04, 0.005, 14), mat(Color("#9FE8FF"), 0.1, 0.9, false), Vector3(sx * 0.055, 0.03, 0.127), Vector3(PI / 2.0, 0, 0))
		put(tilt, cyl(0.028, 0.03, 0.05, 10), _m("#1E1836", 0.6), Vector3(sx * 0.055, 0.03, -0.075), Vector3(PI / 2.0, 0, 0))
	put(tilt, box(Vector3(0.06, 0.03, 0.08)), _m("#FFB547", 0.6), Vector3(0, 0.03, 0.0))
	put(tilt, tube(bez(Vector3(-0.1, 0.03, 0.0), Vector3(0, -0.12, 0.0), Vector3(0.1, 0.03, 0.0), 7), 0.007, 0.007, 4), _m("#FF8A3D", 0.8, 0.0, false))


func _d_backpack(n: Node3D) -> void:
	var green := _m("#4F9A5E", 0.9)
	var dark := _m("#3A7A48", 0.9)
	put(n, sphere(0.2, 18), green, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.0, 1.3, 0.72))
	put(n, sphere(0.19, 16), dark, Vector3(0, 0.43, 0.01), Vector3(0.1, 0, 0), Vector3(1.02, 0.45, 0.78))
	put(n, sphere(0.13, 14), _m("#FF8A3D", 0.9), Vector3(0, 0.2, 0.12), Vector3.ZERO, Vector3(1.0, 0.75, 0.45))
	_paw(n, Vector3(0, 0.2, 0.18), 0.9, Color("#FFF1DC"))
	for sx in [-0.07, 0.07]:
		put(n, box(Vector3(0.03, 0.2, 0.02)), _m("#FFD34D", 0.6, 0.0, false), Vector3(sx, 0.4, 0.15), Vector3(-0.35, 0, 0))
	# скатка сверху
	put(n, cyl(0.07, 0.07, 0.4, 14), _m("#E8505B", 0.9), Vector3(0, 0.6, -0.02), Vector3(0, 0, PI / 2.0))
	for sx in [-0.12, 0.12]:
		put(n, torus(0.065, 0.078, 14), _m("#3A2A55", 0.7, 0.0, false), Vector3(sx, 0.6, -0.02), Vector3(0, 0, PI / 2.0))
	# фляжка сбоку и котелок на карабине (покачивается)
	put(n, cyl(0.045, 0.045, 0.16, 12), _m("#3FA9F5", 0.5), Vector3(-0.2, 0.2, 0.0))
	put(n, cyl(0.02, 0.02, 0.03, 8), _m("#1E1836", 0.6), Vector3(-0.2, 0.3, 0.0))
	var pot := node(n, Vector3(0.2, 0.33, 0.0))
	anim(pot, "pendulum", {"amp": 0.18, "spd": 1.6})
	put(pot, torus(0.012, 0.02, 8), _m("#8A8AA0", 0.4, 0.0, false), Vector3(0, -0.01, 0), Vector3(PI / 2.0, 0, 0))
	put(pot, tube(bez(Vector3(-0.07, -0.08, 0), Vector3(0, 0.02, 0), Vector3(0.07, -0.08, 0), 6), 0.006, 0.006, 4), _m("#8A8AA0", 0.4, 0.0, false))
	put(pot, lathe([Vector2(0, -0.16), Vector2(0.06, -0.16), Vector2(0.075, -0.13), Vector2(0.075, -0.07), Vector2(0, -0.07)], 16), _m("#C0C4D8", 0.35))
	# лямки сзади
	for sx in [-0.08, 0.08]:
		put(n, tube(bez(Vector3(sx, 0.45, -0.13), Vector3(sx * 1.3, 0.28, -0.22), Vector3(sx, 0.1, -0.12), 6), 0.02, 0.02, 4), dark)


## Тропа на карте (в координатах доски)
const TRAIL := [Vector2(-0.24, -0.15), Vector2(-0.14, -0.08), Vector2(-0.16, 0.03), Vector2(-0.04, 0.08), Vector2(0.06, -0.02),
	Vector2(0.16, 0.02), Vector2(0.2, 0.12)]


func _d_trailmap(n: Node3D, sk: String) -> void:
	var b := node(n, Vector3(0, 0.3, 0.0))
	if sk == "ledge":
		# на уступе — на подставке-мольбертике
		b.position = Vector3(0, 0.3, -0.02)
		b.rotation.x = -0.18
		b.scale = Vector3.ONE * 0.8
		for sx in [-0.2, 0.2]:
			put(n, cyl(0.014, 0.016, 0.34, 6), _m("#8A5A3A", 0.85), Vector3(sx, 0.16, 0.03), Vector3(0.18, 0, 0))
		put(n, cyl(0.012, 0.012, 0.36, 6), _m("#8A5A3A", 0.85), Vector3(0, 0.15, -0.1), Vector3(-0.35, 0, 0))
	put(b, extrude(rrect_poly(0.72, 0.52, 0.04), 0.04), _m("#8A5A3A", 0.85), Vector3(0, 0, 0.02))
	put(b, box(Vector3(0.64, 0.44, 0.012)), _m("#F3E3B5", 0.95), Vector3(0, 0, 0.042))
	var z := 0.05
	# горы со снежными шапками, ёлочки, озеро
	for m in [[Vector2(0.12, 0.12), 0.16], [Vector2(0.22, 0.09), 0.12]]:
		var mp: Vector2 = m[0]
		var ms: float = m[1]
		put(b, prism(Vector3(ms, ms * 0.9, 0.01)), _m("#9A94C0", 0.9, 0.0, false), Vector3(mp.x, mp.y, z))
		put(b, prism(Vector3(ms * 0.38, ms * 0.34, 0.012)), _m("#FFFFFF", 0.9, 0.0, false), Vector3(mp.x, mp.y + ms * 0.28, z + 0.002))
	for tp in [Vector2(-0.22, 0.1), Vector2(-0.18, 0.15), Vector2(-0.26, 0.15), Vector2(0.03, -0.13)]:
		put(b, prism(Vector3(0.05, 0.07, 0.01)), _m("#3F8A55", 0.9, 0.0, false), Vector3(tp.x, tp.y, z))
	put(b, sphere(0.07, 12), _m("#6FC8F0", 0.5, 0.15, false), Vector3(0.06, -0.12, z), Vector3.ZERO, Vector3(1.3, 0.65, 0.08))
	# пунктир тропы
	var dots := []
	for i in TRAIL.size() - 1:
		var a: Vector2 = TRAIL[i]
		var c: Vector2 = TRAIL[i + 1]
		for k in 3:
			var q := a.lerp(c, (k + 0.5) / 3.0)
			dots.append(Transform3D(Basis(), Vector3(q.x, q.y, z)))
	scatter(b, sphere(0.009, 6), _m("#E8505B", 0.7, 0.0, false), dots)
	# старт — косточка, финиш — флажок со звездой
	var t0: Vector2 = TRAIL[0]
	var st := node(b, Vector3(t0.x, t0.y, z + 0.005))
	_bone(st, 0.3, Color("#FFFFFF"))
	var fin: Vector2 = TRAIL[TRAIL.size() - 1]
	put(b, cyl(0.004, 0.004, 0.08, 4), _m("#3A2A55", 0.6, 0.0, false), Vector3(fin.x, fin.y + 0.03, z + 0.004))
	put(b, extrude(star_poly(0.025, 0.011), 0.008), _m("#FFD34D", 0.5, 0.4, false), Vector3(fin.x + 0.025, fin.y + 0.06, z + 0.004))
	# огонёк ползёт по тропе
	var dot := node(b, Vector3(0, 0, z + 0.012))
	put(dot, sphere(0.018, 10), glow_mat(Color("#FFF2A0"), 3.0))
	halo(dot, Vector3.ZERO, 0.16, Color(1.0, 0.9, 0.5, 0.6))
	anim(dot, "call", {"f": _a_trail})
	# кнопки-гвоздики
	for c in [Vector2(-0.3, 0.2), Vector2(0.3, 0.2), Vector2(-0.3, -0.2), Vector2(0.3, -0.2)]:
		put(b, sphere(0.014, 6), _m("#FF5A6E", 0.5, 0.0, false), Vector3(c.x, c.y, z))


func _a_trail(nd: Node3D, t: float, a: Dictionary) -> void:
	var nseg := TRAIL.size() - 1
	var u := fposmod(t * 0.18, 1.15)
	var f := clampf(u, 0.0, 1.0) * nseg
	var i := mini(int(f), nseg - 1)
	var q: Vector2 = (TRAIL[i] as Vector2).lerp(TRAIL[i + 1], f - i)
	var o: Vector3 = (a.base as Transform3D).origin
	nd.transform = Transform3D(Basis.from_scale(Vector3.ONE * (1.0 + 0.25 * sin(t * 7.0))), Vector3(q.x, q.y, o.z))


func _d_canoe(n: Node3D, sk: String) -> void:
	var y := 0.24
	# козлы-подставки
	for sx in [-0.5, 0.5]:
		for sz in [-1.0, 1.0]:
			put(n, box(Vector3(0.04, 0.3, 0.04)), _m("#8A5A3A", 0.85), Vector3(sx, 0.13, sz * 0.12), Vector3(sz * 0.45, 0, 0))
		put(n, box(Vector3(0.06, 0.04, 0.34)), _m("#A8723E", 0.85), Vector3(sx, 0.25, 0))
	var c := node(n, Vector3(0, y + 0.03, 0))
	c.rotation.z = 0.04
	if not _geo.has("canoe_out"):
		_geo["canoe_out"] = lathe([Vector2(0, 0), Vector2(0.25, 0.015), Vector2(0.42, 0.07), Vector2(0.5, 0.18), Vector2(0.52, 0.27), Vector2(0.48, 0.27)], 28)
		_geo["canoe_in"] = lathe([Vector2(0.48, 0.27), Vector2(0.45, 0.19), Vector2(0.37, 0.1), Vector2(0.22, 0.06), Vector2(0, 0.05)], 28)
	var hull_k := Vector3(1.7, 1.0, 0.56)
	put(c, _geo["canoe_out"], _m("#E0503F", 0.7), Vector3.ZERO, Vector3.ZERO, hull_k)
	put(c, _geo["canoe_in"], _m("#B07A4E", 0.9, 0.0, false), Vector3.ZERO, Vector3.ZERO, hull_k)
	put(c, torus(0.47, 0.53, 36), _m("#F4E6D4", 0.8), Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.7, 0.45, 0.56))
	put(c, torus(0.5, 0.515, 36), _m("#FFFFFF", 0.8, 0.0, false), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.71, 0.6, 0.57))
	for sx in [-0.38, 0.38]:
		put(c, box(Vector3(0.07, 0.03, 0.46)), _m("#C98A4A", 0.85), Vector3(sx, 0.22, 0))
	for sx in [-1.0, 1.0]:
		put(c, sphere(0.04, 8), _m("#FFD34D", 0.5, 0.2), Vector3(sx * 0.86, 0.29, 0))
	var pw := node(c, Vector3(0.0, 0.13, 0.27))
	pw.rotation.x = -0.3
	_paw(pw, Vector3.ZERO, 1.4, Color("#FFF1DC"))
	# весло на боку
	var pd := node(n, Vector3(0.35, 0.0, 0.42))
	pd.rotation = Vector3(0, 0.2, -0.95)
	put(pd, cyl(0.016, 0.016, 0.95, 6), _m("#C98A4A", 0.85), Vector3(0, 0.47, 0))
	put(pd, sphere(0.1, 12), _m("#F4B45A", 0.85), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(0.75, 1.5, 0.15))
	put(pd, sphere(0.025, 6), _m("#E0503F", 0.7, 0.0, false), Vector3(0, 0.95, 0))
	# флажок на носу
	put(c, cyl(0.006, 0.006, 0.25, 4), _m("#3A2A55", 0.6, 0.0, false), Vector3(0.82, 0.4, 0))
	var fl := node(c, Vector3(0.82, 0.5, 0))
	anim(fl, "flag", {})
	put(fl, extrude(PackedVector2Array([Vector2(0, 0.04), Vector2(0.13, 0.0), Vector2(0, -0.04)]), 0.008), _m("#FFD34D", 0.7, 0.1, false))
	if sk == "big":
		# на большом месте — спасательный круг и моток верёвки
		put(n, torus(0.1, 0.17, 20), _m("#FFFFFF", 0.7), Vector3(-0.75, 0.06, 0.4), Vector3.ZERO, Vector3(1, 1.3, 1))
		for k in 4:
			var a := k * PI / 2.0 + 0.4
			put(n, box(Vector3(0.06, 0.07, 0.1)), _m("#E8505B", 0.8, 0.0, false), Vector3(-0.75, 0.065, 0.4) + dir(a) * 0.135, Vector3(0, -a, 0))
		put(n, torus(0.05, 0.12, 16), _m("#E8D6B0", 1.0), Vector3(0.75, 0.03, -0.35), Vector3.ZERO, Vector3(1, 1.4, 1))


func _d_tent(n: Node3D, sk: String) -> void:
	var W := 1.3
	var H := 1.0
	var D := 1.3
	put(n, box(Vector3(W + 0.3, 0.02, D + 0.25)), _m("#2F6A4E", 1.0, 0.0, false), Vector3(0, 0.01, 0))
	put(n, prism(Vector3(W, H, D)), _m("#F29A4A", 0.85), Vector3(0, H * 0.5 + 0.02, 0))
	put(n, box(Vector3(W + 0.01, 0.07, D + 0.01)), _m("#3FB8A8", 0.85, 0.0, false), Vector3(0, 0.07, 0))
	# вход: тёплый свет изнутри
	var door := PackedVector2Array([Vector2(-0.33, 0), Vector2(0.33, 0), Vector2(0, 0.68)])
	put(n, extrude(door, 0.01), _m("#3A2440", 1.0, 0.0, false), Vector3(0, 0.02, D * 0.5 + 0.004))
	var glow := put(n, extrude(PackedVector2Array([Vector2(-0.26, 0), Vector2(0.26, 0), Vector2(0, 0.52)]), 0.01), glow_mat(Color("#FFB347"), 1.5, true), Vector3(0, 0.025, D * 0.5 + 0.008))
	anim(glow, "bulb", {"e0": 1.4, "e1": 0.25, "spd": 3.1})
	put(n, sphere(0.05, 10), glow_mat(Color("#FFF2C0"), 3.0), Vector3(0, 0.2, D * 0.5 - 0.05))
	halo(n, Vector3(0, 0.3, D * 0.5 + 0.1), 1.1, Color(1.0, 0.7, 0.35, 0.3))
	# откинутый полог колышется
	for sx in [-1.0, 1.0]:
		var f := node(n, Vector3(0, 0.02, D * 0.5 + 0.015))
		anim(f, "wiggle", {"axis": Vector3.UP, "amp": 0.1, "spd": 1.1, "p": sx})
		var poly := PackedVector2Array([Vector2(0, 0.69), Vector2(sx * 0.36, 0.0), Vector2(sx * 0.5, 0.06)])
		put(f, extrude(poly, 0.012), _m("#FFB870", 0.85))
		put(f, torus(0.02, 0.03, 8), _m("#8A5A3A", 0.8, 0.0, false), Vector3(sx * 0.38, 0.12, 0.01))
	# стойки, растяжки, колышки
	for sz in [-1.0, 1.0]:
		put(n, cyl(0.015, 0.015, 0.14, 6), _m("#8A5A3A", 0.85), Vector3(0, H + 0.08, sz * (D * 0.5 + 0.01)))
		for sx in [-1.0, 1.0]:
			var peg := Vector3(sx * (W * 0.5 + 0.35), 0.03, sz * (D * 0.5 + 0.15))
			put(n, tube([Vector3(0, H + 0.08, sz * (D * 0.5 + 0.01)), peg], 0.004, 0.004, 3), _m("#E8D6B0", 1.0, 0.0, false))
			put(n, cyl(0.012, 0.006, 0.08, 4), _m("#C0C4D8", 0.4, 0.0, false), peg)
	put(n, cyl(0.006, 0.006, 0.16, 4), _m("#3A2A55", 0.6, 0.0, false), Vector3(0, H + 0.2, D * 0.5 + 0.01))
	var fl := node(n, Vector3(0, H + 0.26, D * 0.5 + 0.01))
	anim(fl, "flag", {"p": 1.0})
	put(fl, extrude(PackedVector2Array([Vector2(0, 0.05), Vector2(0.17, 0.0), Vector2(0, -0.05)]), 0.008), _m("#3FB8A8", 0.7, 0.1, false))
	# коврик-лапка у входа
	put(n, cyl(0.2, 0.2, 0.015, 20), _m("#8E6CC8", 0.95, 0.0, false), Vector3(0, 0.025, D * 0.5 + 0.3), Vector3.ZERO, Vector3(1.3, 1, 0.8))
	var pw := node(n, Vector3(0, 0.04, D * 0.5 + 0.3))
	pw.rotation.x = -PI / 2.0
	_paw(pw, Vector3.ZERO, 1.6, Color("#FFF1DC"))
	if sk == "big":
		# фонарик на колышке у входа
		var lp := Vector3(W * 0.5 + 0.12, 0, D * 0.5 + 0.12)
		put(n, cyl(0.012, 0.012, 0.45, 6), _m("#3A2A55", 0.6), lp + Vector3(0, 0.22, 0))
		put(n, sphere(0.06, 10), glass(Color(1.0, 0.9, 0.55, 0.75), 1.6), lp + Vector3(0, 0.5, 0))
		put(n, sphere(0.03, 8), glow_mat(Color("#FFF2C0"), 3.0), lp + Vector3(0, 0.5, 0))


## Костёр (★): камни по кругу, брёвна шалашиком, пламя, искры, тёплый свет, зефирка на палочке
func _d_campfire(n: Node3D, sk: String) -> void:
	var st := []
	var st2 := []
	for i in 10:
		var a := TAU * i / 10.0
		var xf := Transform3D(Basis(Vector3.UP, a * 1.7) * Basis.from_scale(Vector3(1.25, 0.75, 1.0)), dir(a) * 0.4 + Vector3(0, 0.05, 0))
		if i % 2 == 0:
			st.append(xf)
		else:
			st2.append(xf)
	scatter(n, sphere(0.09, 10), _m("#8E88B8", 0.9), st)
	scatter(n, sphere(0.09, 10), _m("#A9A3CF", 0.9), st2)
	put(n, cyl(0.34, 0.34, 0.02, 20), _m("#3A2A30", 1.0, 0.0, false), Vector3(0, 0.01, 0))
	# угли
	var em := put(n, sphere(0.2, 14), glow_mat(Color("#FF5A2A"), 1.6, true), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 0.2, 1))
	anim(em, "bulb", {"e0": 1.5, "e1": 0.5, "spd": 2.0})
	# брёвна шалашиком
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var lg := node(n, dir(a) * 0.16 + Vector3(0, 0.12, 0))
		lg.rotation = Vector3(0, -a, 0)
		var inner := node(lg)
		inner.rotation.z = 0.95
		put(inner, cyl(0.045, 0.05, 0.36, 10), _m("#7A4A30", 0.9), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
		put(inner, cyl(0.04, 0.04, 0.01, 10), _m("#E8C28A", 0.9, 0.0, false), Vector3(-0.181, 0, 0), Vector3(0, 0, PI / 2.0))
	# пламя — конусы (дрожат), искры летят вверх
	var fire := node(n, Vector3(0, 0.08, 0))
	var fl := [[0.17, 0.5, "#FF7A1A", 2.2], [0.12, 0.38, "#FFC23A", 2.6], [0.065, 0.24, "#FFF4B0", 3.2]]
	for i in fl.size():
		var f: Array = fl[i]
		var c := node(fire)
		anim(c, "flame", {"p": float(i) * 1.3})
		put(c, cyl(0.0, f[0], f[1], 10), glow_mat(Color(f[2]), f[3]), Vector3(0, float(f[1]) * 0.5, 0))
	for i in 3:
		var a := TAU * i / 3.0
		var c := node(fire, dir(a) * 0.1)
		c.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
		anim(c, "flame", {"p": float(i) * 2.0 + 0.5})
		put(c, cyl(0.0, 0.07, 0.25, 8), glow_mat(Color("#FF9A2A"), 2.4), Vector3(0, 0.12, 0))
	for i in 6:
		var sp := put(n, sphere(0.014, 6), glow_mat(Color("#FFD27A"), 3.5), Vector3(0.05 * cos(i * 2.0), 0.35, 0.05 * sin(i * 2.0)))
		anim(sp, "rise", {"h": 0.9, "spd": 0.45 + 0.05 * i, "p": i / 6.0})
	halo(n, Vector3(0, 0.3, 0), 1.7, Color(1.0, 0.6, 0.25, 0.35))
	omni(n, Vector3(0, 0.5, 0.15), Color("#FFA24A"), 1.4, 3.6, "flicker")
	# зефирка на палочке
	var stick := node(n, Vector3(0.55, 0.0, 0.3))
	stick.rotation.y = face_to(Vector3(0.55, 0, 0.3), Vector3.ZERO)
	var s2 := node(stick)
	s2.rotation.x = 0.95
	anim(s2, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.05, "spd": 1.2})
	put(s2, cyl(0.008, 0.01, 0.62, 5), _m("#A8723E", 0.85), Vector3(0, 0.31, 0))
	put(s2, cyl(0.035, 0.035, 0.06, 12), _m("#FFF6EE", 0.9), Vector3(0, 0.62, 0))
	put(s2, cyl(0.036, 0.036, 0.015, 12), _m("#E8A860", 0.9, 0.0, false), Vector3(0, 0.6, 0))
	# брёвна-скамейки
	var seats := [Vector3(-0.85, 0, 0.15)] if sk != "big" else [Vector3(-0.85, 0, 0.15), Vector3(0.1, 0, -0.85)]
	for p in seats:
		var lg := node(n, p)
		lg.rotation.y = face_to(p, Vector3.ZERO) + PI / 2.0
		put(lg, cyl(0.12, 0.12, 0.62, 14), _m("#8A5A3A", 0.9), Vector3(0, 0.12, 0), Vector3(0, 0, PI / 2.0))
		for sx in [-1.0, 1.0]:
			put(lg, cyl(0.105, 0.105, 0.012, 14), _m("#E8C28A", 0.9, 0.0, false), Vector3(sx * 0.31, 0.12, 0), Vector3(0, 0, PI / 2.0))
	if sk == "big":
		# котелок на треноге
		var tp := Vector3(0.62, 0, -0.45)
		for i in 3:
			var a := TAU * i / 3.0
			put(n, tube([tp + Vector3(0, 0.55, 0), tp + dir(a) * 0.2], 0.012, 0.012, 4), _m("#3A2A55", 0.6))
		put(n, lathe([Vector2(0, 0.18), Vector2(0.1, 0.18), Vector2(0.12, 0.25), Vector2(0.1, 0.33), Vector2(0, 0.33)], 16), _m("#3A3A55", 0.5), tp)


## Конус для скейт-парка
func _cone(parent: Node3D, p: Vector3) -> Node3D:
	var c := node(parent, p)
	put(c, box(Vector3(0.24, 0.03, 0.24)), _m("#E85A1E", 0.7), Vector3(0, 0.015, 0))
	put(c, cyl(0.018, 0.1, 0.32, 14), _m("#FF7A2E", 0.65), Vector3(0, 0.19, 0))
	for y in [0.13, 0.24]:
		var r := lerpf(0.1, 0.018, (y - 0.03) / 0.32) + 0.004
		put(c, cyl(r - 0.012, r, 0.04, 14), _m("#FFFFFF", 0.6, 0.0, false), Vector3(0, y, 0))
	return c


func _d_cones(n: Node3D, sk: String) -> void:
	var g := node(n)
	if sk == "ledge":
		g.scale = Vector3.ONE * 0.6
	_cone(g, Vector3(-0.18, 0, -0.06))
	_cone(g, Vector3(0.17, 0, -0.08))
	# третий падает и встаёт (поворот вокруг переднего края основания)
	var pv := node(g, Vector3(0.0, 0, 0.27))
	anim(pv, "call", {"f": _a_cone_fall})
	_cone(pv, Vector3(0, 0, -0.12))


func _a_cone_fall(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t, 6.0)
	var ang := 0.0
	if u < 0.6:
		ang = pow(u / 0.6, 2.0) * 1.45
	elif u < 2.2:
		ang = 1.45 - 0.08 * absf(sin((u - 0.6) * 9.0)) * exp(-(u - 0.6) * 3.0)
	elif u < 3.0:
		ang = 1.45 * (1.0 - smoothstep(2.2, 3.0, u))
	else:
		ang = -0.12 * sin((u - 3.0) * 10.0) * exp(-(u - 3.0) * 4.0)
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis(Vector3.RIGHT, ang), (a.base as Transform3D).origin)


func _d_spray(n: Node3D) -> void:
	var cols := ["#FF4FA3", "#3FE0FF", "#FFD34D", "#7AE08A"]
	var ps := [Vector3(-0.17, 0, -0.03), Vector3(-0.05, 0, 0.04), Vector3(0.07, 0, -0.04), Vector3(0.19, 0, 0.03)]
	# брызги краски на полочке
	for i in 4:
		var r := 0.06 + 0.02 * (i % 2)
		put(n, cyl(r, r, 0.006, 14), mat(Color(cols[(i + 1) % 4]), 0.6, 0.25, false), (ps[i] as Vector3) + Vector3(0.05, 0.003, 0.04), Vector3.ZERO, Vector3(1.3, 1, 0.8))
	for i in 4:
		var c := node(n, ps[i])
		if i == 2:
			anim(c, "call", {"f": _a_shake})
		var cm := _m(cols[i], 0.4)
		put(c, cyl(0.038, 0.038, 0.16, 14), cm, Vector3(0, 0.08, 0))
		put(c, cyl(0.02, 0.038, 0.035, 14), _m("#D8DCEC", 0.3), Vector3(0, 0.177, 0))
		put(c, cyl(0.016, 0.016, 0.03, 10), cm, Vector3(0, 0.205, 0))
		put(c, cyl(0.039, 0.039, 0.03, 14), _m("#FFFFFF", 0.5, 0.0, false), Vector3(0, 0.07, 0))
		if i % 2 == 0:
			put(c, extrude(star_poly(0.018, 0.008), 0.004), _m("#FFFFFF", 0.5, 0.2, false), Vector3(0, 0.12, 0.038))
		else:
			put(c, extrude(_bolt_poly(0.05), 0.004), _m("#1E1836", 0.5, 0.0, false), Vector3(0, 0.12, 0.038))
	# облачко краски над баллончиком, который трясут
	for i in 3:
		var m := put(n, sphere(0.022, 8), mat(Color(cols[2]), 0.6, 1.2, false), (ps[2] as Vector3) + Vector3(0.0, 0.23, 0.01))
		anim(m, "rise", {"h": 0.22, "spd": 0.7, "p": i / 3.0})


## Трясут баллончик: пара быстрых качков, потом пауза
func _a_shake(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t, 3.0)
	var w := sin(u * 22.0) * 0.18 * (1.0 - smoothstep(0.6, 1.1, u)) if u < 1.1 else 0.0
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis(Vector3.BACK, w), (a.base as Transform3D).origin + Vector3(0, absf(w) * 0.1, 0))


## Молния (плоская фигура) высотой h
static func _bolt_poly(h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0.12, 0.5), Vector2(-0.22, 0.02), Vector2(-0.02, 0.02), Vector2(-0.14, -0.5),
		Vector2(0.24, 0.06), Vector2(0.03, 0.06)])
	for i in pts.size():
		pts[i] *= h
	return pts


func _d_headphones(n: Node3D, sk: String) -> void:
	var y := 0.2
	if sk == "ledge":
		put(n, cyl(0.06, 0.07, 0.03, 12), _m("#2A2440", 0.5), Vector3(0, 0.015, 0))
		put(n, cyl(0.012, 0.012, 0.18, 6), _m("#C0C4D8", 0.3), Vector3(0, 0.1, 0))
	else:
		put(n, cyl(0.12, 0.14, 0.04, 16), _m("#2A2440", 0.5), Vector3(0, 0.02, 0))
		put(n, cyl(0.015, 0.015, 0.36, 6), _m("#C0C4D8", 0.3), Vector3(0, 0.2, 0))
		y = 0.38
	var hp := node(n, Vector3(0, y, 0))
	anim(hp, "bob", {"amp": 0.008, "spd": 2.0})
	var arc := []
	for i in 13:
		var a := lerpf(0.0, PI, i / 12.0)
		arc.append(Vector3(cos(a) * 0.12, sin(a) * 0.12, 0))
	put(hp, tube(arc, 0.018, 0.018, 6), _m("#3F7AE0", 0.6))
	put(hp, sphere(0.04, 10), _m("#FF4FA3", 0.8), Vector3(0, 0.125, 0), Vector3.ZERO, Vector3(1.6, 0.6, 0.9))
	var cols := [Color("#3FE0FF"), Color("#FF4FA3")]
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		put(hp, cyl(0.065, 0.065, 0.05, 16), _m("#2A2440", 0.5), Vector3(sx * 0.13, -0.02, 0), Vector3(0, 0, PI / 2.0))
		put(hp, cyl(0.06, 0.06, 0.02, 16), _m("#FFFFFF", 0.8, 0.0, false), Vector3(sx * 0.1, -0.02, 0), Vector3(0, 0, PI / 2.0))
		var led := put(hp, torus(0.038, 0.05, 16), glow_mat(cols[i], 2.2, true), Vector3(sx * 0.157, -0.02, 0), Vector3(0, 0, PI / 2.0))
		anim(led, "bulb", {"e0": 2.0, "e1": 1.2, "spd": 3.0, "p": float(i) * 2.0})
		put(hp, extrude(_bolt_poly(0.05), 0.006), _m("#FFD34D", 0.5, 0.4, false), Vector3(sx * 0.163, -0.02, 0), Vector3(0, sx * PI / 2.0, 0))


## Скейт: доска с загнутыми концами, колёса (крутятся)
func _skate(parent: Node3D, spin_wheels := true) -> Node3D:
	var b := node(parent)
	var deck := _m("#FF8A3D", 0.6)
	put(b, extrude(rrect_poly(0.5, 0.17, 0.07), 0.02), deck, Vector3(0, 0.09, 0), Vector3(-PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		put(b, extrude(rrect_poly(0.13, 0.17, 0.07), 0.02), deck, Vector3(sx * 0.3, 0.11, 0), Vector3(-PI / 2.0, 0, -sx * 0.35))
	put(b, box(Vector3(0.46, 0.004, 0.15)), _m("#2A2440", 0.9, 0.0, false), Vector3(0, 0.1, 0))
	put(b, extrude(_bolt_poly(0.13), 0.004), _m("#FFD34D", 0.5, 0.35, false), Vector3(0.02, 0.103, 0), Vector3(-PI / 2.0, 0, PI / 2.0))
	var stars := []
	for k in 2:
		stars.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.15 + k * 0.32, 0.103, 0.045 - k * 0.09)))
	scatter(b, extrude(star_poly(0.022, 0.01), 0.004), _m("#FFFFFF", 0.5, 0.3, false), stars)
	for sx in [-0.17, 0.17]:
		put(b, box(Vector3(0.05, 0.03, 0.15)), _m("#C0C4D8", 0.3), Vector3(sx, 0.065, 0))
		for sz in [-0.085, 0.085]:
			var w := node(b, Vector3(sx, 0.04, sz))
			if spin_wheels:
				anim(w, "spin", {"axis": Vector3.BACK, "spd": 7.0})
			put(w, cyl(0.032, 0.032, 0.03, 12), _m("#7AE8C8", 0.5), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
			put(w, sphere(0.01, 6), _m("#FFFFFF", 0.5, 0.0, false), Vector3(0.017, 0.0, signf(sz) * 0.016))
	return b


func _d_skateboard(n: Node3D) -> void:
	# доска стоит одним концом на кирпиче, колёса крутятся в воздухе
	put(n, box(Vector3(0.12, 0.08, 0.2)), _m("#D9774A", 0.9), Vector3(0.22, 0.04, 0))
	var b := node(n, Vector3(-0.04, -0.03, 0))
	b.rotation.z = 0.2
	anim(b, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.04, "spd": 1.4})
	_skate(b)


func _d_hoop(n: Node3D, sk: String) -> void:
	var h := node(n)
	if sk == "ledge":
		# на уступе — стойка с маленьким щитом
		put(n, cyl(0.07, 0.08, 0.04, 12), _m("#2A2440", 0.5), Vector3(0, 0.02, 0))
		put(n, cyl(0.018, 0.018, 0.5, 6), _m("#C0C4D8", 0.3), Vector3(0, 0.27, -0.03))
		h.position = Vector3(0, 0.05, -0.03)
		h.scale = Vector3.ONE * 0.65
	put(h, extrude(rrect_poly(0.66, 0.46, 0.05), 0.03), _m("#3F7AE0", 0.6), Vector3(0, 0.5, 0.02))
	put(h, extrude(rrect_poly(0.6, 0.4, 0.04), 0.012), _m("#F4F7FF", 0.6), Vector3(0, 0.5, 0.04))
	for p in [[Vector3(0, 0.51, 0.048), Vector3(0.2, 0.012, 0.004)], [Vector3(0, 0.39, 0.048), Vector3(0.2, 0.012, 0.004)],
			[Vector3(-0.094, 0.45, 0.048), Vector3(0.012, 0.13, 0.004)], [Vector3(0.094, 0.45, 0.048), Vector3(0.012, 0.13, 0.004)]]:
		put(h, box(p[1]), _m("#FF6A2A", 0.6, 0.0, false), p[0])
	put(h, extrude(star_poly(0.04, 0.018), 0.006), _m("#FFD34D", 0.5, 0.3, false), Vector3(-0.22, 0.62, 0.05))
	_paw(h, Vector3(0.22, 0.6, 0.05), 0.75, Color("#FF4FA3"))
	put(h, box(Vector3(0.06, 0.05, 0.1)), _m("#C0C4D8", 0.3), Vector3(0, 0.33, 0.09))
	var rim := Vector3(0, 0.33, 0.24)
	put(h, torus(0.1, 0.118, 24), _m("#FF6A2A", 0.5), rim)
	var net := _m("#FFFFFF", 0.9, 0.0, false)
	for i in 8:
		var a := TAU * i / 8.0
		put(h, tube([rim + dir(a) * 0.105, rim + dir(a + 0.5) * 0.07 + Vector3(0, -0.16, 0)], 0.004, 0.004, 3), net)
	put(h, torus(0.066, 0.074, 16), net, rim + Vector3(0, -0.16, 0))
	put(h, torus(0.083, 0.091, 16), net, rim + Vector3(0, -0.08, 0))
	# мяч иногда залетает в кольцо
	var ball := node(h, rim)
	anim(ball, "call", {"f": _a_hoop_ball})
	var inner := node(ball)
	anim(inner, "spin", {"axis": Vector3.RIGHT, "spd": 6.0})
	put(inner, sphere(0.065, 14), _m("#FF7A2E", 0.6))
	put(inner, torus(0.063, 0.068, 16), _m("#2A2440", 0.6, 0.0, false), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	ball.visible = false


func _a_hoop_ball(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t, 6.0)
	var o: Vector3 = (a.base as Transform3D).origin
	if u > 2.0:
		nd.visible = false
		return
	nd.visible = true
	var p: Vector3
	if u < 1.3:
		var s := u / 1.3
		var A := Vector3(0.45, -0.25, 0.75)
		var C := Vector3(0.12, 0.75, 0.45)
		var B := Vector3(0, 0.12, 0)
		p = A.lerp(C, s).lerp(C.lerp(B, s), s)
	else:
		var s := (u - 1.3) / 0.7
		p = Vector3(0, 0.12 - s * s * 0.9, 0)
	nd.position = o + p


## Граффити: свой шейдер (лапка, звёзды, молния, подтёки; цвета переливаются). Без букв.
const GRAFFITI := """
shader_type spatial;
render_mode cull_disabled;
uniform float shift = 0.0;
float sd_ell(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float sd_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
float sd_seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a; vec2 ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	p.y = -p.y;
	float aa = fwidth(p.x) * 1.5;
	float blob = sd_ell(p, vec2(0.0, 0.03), vec2(0.72, 0.36)) + 0.025 * sin(atan(p.y, p.x) * 7.0 + 1.0);
	for (int i = 0; i < 5; i++) {
		float x = -0.48 + float(i) * 0.24 + 0.04 * sin(float(i) * 3.1);
		float len = 0.06 + 0.08 * fract(float(i) * 0.618);
		blob = min(blob, sd_seg(p, vec2(x, -0.2), vec2(x, -0.3 - len)) - 0.02);
		blob = min(blob, length(p - vec2(x, -0.3 - len)) - 0.03);
	}
	float t = TIME * 0.06 + shift;
	vec3 bg = mix(hue(t + p.x * 0.35), hue(t + 0.33 + p.y * 0.5), 0.5) * 0.8 + 0.12;
	float a_bg = smoothstep(aa, -aa, blob);
	float edge = smoothstep(aa, -aa, abs(blob) - 0.016);
	vec3 col = bg;
	vec3 ink = vec3(0.12, 0.07, 0.2);
	vec2 q = p - vec2(-0.32, -0.02);
	float paw = sd_ell(q, vec2(0.0, -0.05), vec2(0.13, 0.1));
	paw = min(paw, sd_ell(q, vec2(-0.13, 0.08), vec2(0.045, 0.06)));
	paw = min(paw, sd_ell(q, vec2(-0.05, 0.15), vec2(0.045, 0.06)));
	paw = min(paw, sd_ell(q, vec2(0.05, 0.15), vec2(0.045, 0.06)));
	paw = min(paw, sd_ell(q, vec2(0.13, 0.08), vec2(0.045, 0.06)));
	col = mix(col, ink, smoothstep(aa, -aa, paw - 0.02));
	col = mix(col, vec3(1.0, 0.97, 0.92), smoothstep(aa, -aa, paw));
	vec2 b = p - vec2(0.34, 0.02);
	float bolt = min(sd_seg(b, vec2(0.08, 0.24), vec2(-0.07, 0.0)), sd_seg(b, vec2(-0.07, 0.0), vec2(0.07, 0.0)));
	bolt = min(bolt, sd_seg(b, vec2(0.07, 0.0), vec2(-0.07, -0.24)));
	col = mix(col, ink, smoothstep(aa, -aa, bolt - 0.05));
	col = mix(col, hue(t + 0.5) * 0.5 + 0.5, smoothstep(aa, -aa, bolt - 0.03));
	float st = sd_star(p - vec2(0.04, 0.17), 0.08, 0.45);
	st = min(st, sd_star((p - vec2(0.06, -0.13)) * 1.6, 0.08, 0.45) / 1.6);
	st = min(st, sd_star((p - vec2(-0.6, 0.2)) * 2.0, 0.08, 0.45) / 2.0);
	col = mix(col, ink, smoothstep(aa, -aa, st - 0.012));
	col = mix(col, vec3(1.0, 0.86, 0.25), smoothstep(aa, -aa, st));
	col = mix(col, ink, edge);
	if (a_bg + edge < 0.02) { discard; }
	ALBEDO = col;
	ROUGHNESS = 0.7;
	EMISSION = col * 0.22;
}
"""

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


func _d_graffiti(n: Node3D, sk: String) -> void:
	if sk == "ledge":
		# на уступе — расписанный щит, прислонённый к скале
		var bd := node(n, Vector3(0, 0.0, -0.06))
		bd.rotation.x = -0.22
		put(bd, box(Vector3(0.62, 0.42, 0.03)), _m("#8E88B8", 0.9), Vector3(0, 0.22, 0))
		put(bd, quad(Vector2(0.58, 0.38)), _shader_mat("graffiti", GRAFFITI), Vector3(0, 0.22, 0.017))
		return
	put(n, quad(Vector2(1.04, 0.66)), _shader_mat("graffiti", GRAFFITI), Vector3(0, 0.3, 0.035))
	# наклейки-звёздочки поверх росписи (объёмные) и баночка краски внизу
	for sp in [[Vector3(-0.42, 0.52, 0.045), "#FFD34D"], [Vector3(0.44, 0.1, 0.045), "#3FE0FF"]]:
		put(n, extrude(star_poly(0.045, 0.02), 0.012), _m(sp[1], 0.5, 0.4, false), sp[0], Vector3(0, 0, 0.3))


## Нота (для магнитофона): головка, штиль, флажок
func _note(parent: Node3D, p: Vector3, col: Color) -> Node3D:
	var nt := node(parent, p)
	var m := mat(col, 0.5, 1.6, false)
	put(nt, sphere(0.03, 10), m, Vector3.ZERO, Vector3(0, 0, 0.4), Vector3(1.3, 0.9, 0.5))
	put(nt, cyl(0.006, 0.006, 0.11, 4), m, Vector3(0.033, 0.055, 0))
	put(nt, prism(Vector3(0.04, 0.05, 0.01), 0.0), m, Vector3(0.05, 0.095, 0), Vector3(0, 0, -0.5))
	return nt


func _d_boombox(n: Node3D, sk: String) -> void:
	var g := node(n)
	if sk == "ledge":
		g.scale = Vector3.ONE * 0.68
	else:
		# на земле — на деревянном ящике
		put(n, box(Vector3(0.5, 0.18, 0.3)), _m("#C98A4A", 0.85), Vector3(0, 0.09, 0))
		put(n, box(Vector3(0.51, 0.03, 0.31)), _m("#A8692F", 0.85, 0.0, false), Vector3(0, 0.09, 0))
		g.position = Vector3(0, 0.18, 0)
	put(g, extrude(rrect_poly(0.56, 0.3, 0.06), 0.16), _m("#3F7AE0", 0.6), Vector3(0, 0.15, 0))
	put(g, box(Vector3(0.5, 0.02, 0.17)), _m("#FF4FA3", 0.6, 0.0, false), Vector3(0, 0.29, 0))
	for sx in [-1.0, 1.0]:
		var sp := node(g, Vector3(sx * 0.16, 0.14, 0.08))
		anim(sp, "call", {"f": _a_beat, "p": sx})
		put(sp, cyl(0.085, 0.085, 0.02, 20), _m("#2A2440", 0.6), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
		put(sp, torus(0.075, 0.092, 20), _m("#D8DCEC", 0.3, 0.0, false), Vector3(0, 0, 0.01), Vector3(PI / 2.0, 0, 0))
		put(sp, sphere(0.04, 12), _m("#FF4FA3", 0.6, 0.3, false), Vector3(0, 0, 0.012), Vector3.ZERO, Vector3(1, 1, 0.5))
	put(g, box(Vector3(0.13, 0.08, 0.01)), _m("#1E1836", 0.2), Vector3(0, 0.16, 0.082))
	for sx in [-0.03, 0.03]:
		var reel := node(g, Vector3(sx, 0.16, 0.087))
		anim(reel, "spin", {"axis": Vector3.BACK, "spd": 3.0})
		put(reel, cyl(0.018, 0.018, 0.006, 8), _m("#FFFFFF", 0.5, 0.0, false), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
		put(reel, box(Vector3(0.03, 0.006, 0.008)), _m("#1E1836", 0.5, 0.0, false), Vector3(0, 0, 0.004))
	var bcol := [Color("#FFD34D"), Color("#7AE08A"), Color("#3FE0FF"), Color("#FF5A6E")]
	for i in 4:
		put(g, box(Vector3(0.035, 0.02, 0.04)), mat(bcol[i], 0.5, 0.3, false), Vector3(-0.06 + i * 0.04, 0.3, 0.02))
	put(g, tube(bez(Vector3(-0.2, 0.3, 0), Vector3(0, 0.46, 0), Vector3(0.2, 0.3, 0), 7), 0.016, 0.016, 5), _m("#2A2440", 0.5))
	put(g, cyl(0.004, 0.004, 0.3, 4), _m("#C0C4D8", 0.3, 0.0, false), Vector3(0.24, 0.42, -0.05), Vector3(0, 0, -0.4))
	put(g, sphere(0.012, 6), _m("#FF4FA3", 0.5, 0.6, false), Vector3(0.3, 0.56, -0.05))
	var cols := [Color("#FF6FC8"), Color("#3FE0FF"), Color("#FFE27A")]
	for i in 3:
		var nt := _note(g, Vector3(-0.12 + i * 0.12, 0.36, 0.04), cols[i])
		anim(nt, "rise", {"h": 0.45, "spd": 0.32, "p": i / 3.0})


## Динамик «качает»: быстрое расширение на каждую долю и мягкий спад
func _a_beat(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t * 2.0 + float(a.p) * 0.25, 1.0)
	var s := 1.0 + 0.1 * exp(-u * 8.0)
	nd.transform = Transform3D((a.base as Transform3D).basis * Basis.from_scale(Vector3(s, s, 1.0 + (s - 1.0) * 2.0)), (a.base as Transform3D).origin)


## Замкнутая петля (для неоновых трубок)
static func _loop(c: Vector2, r: Vector2, nn := 16) -> Array:
	var out := []
	for i in nn + 1:
		var a := TAU * i / nn
		out.append(Vector3(c.x + cos(a) * r.x, c.y + sin(a) * r.y, 0))
	return out


func _d_neon(n: Node3D, sk: String) -> void:
	var g := node(n)
	if sk == "ledge":
		# на полке — на двух ножках
		for sx in [-0.18, 0.18]:
			put(n, box(Vector3(0.05, 0.04, 0.14)), _m("#2A2440", 0.5), Vector3(sx, 0.02, 0))
		g.position = Vector3(0, -0.04, -0.02)
		g.scale = Vector3.ONE * 0.75
	put(g, extrude(rrect_poly(0.66, 0.5, 0.06), 0.03), _m("#231C3E", 0.6), Vector3(0, 0.3, 0.02))
	for c in [Vector2(-0.29, 0.52), Vector2(0.29, 0.52), Vector2(-0.29, 0.08), Vector2(0.29, 0.08)]:
		put(g, sphere(0.012, 6), _m("#C0C4D8", 0.3, 0.0, false), Vector3(c.x, c.y, 0.04))
	var pink := glow_mat(Color("#FF4FA3"), 3.0, true)
	var cyan := glow_mat(Color("#3FE0FF"), 3.0, true)
	var z := 0.05
	var paw := node(g, Vector3(-0.12, 0.27, z))
	put(paw, tube(_loop(Vector2(0, -0.04), Vector2(0.075, 0.06), 18), 0.011, 0.011, 5), pink)
	for tc in [Vector2(-0.085, 0.05), Vector2(-0.03, 0.1), Vector2(0.03, 0.1), Vector2(0.085, 0.05)]:
		put(paw, tube(_loop(tc, Vector2(0.025, 0.032), 10), 0.009, 0.009, 4), pink)
	var bolt := []
	for v in _bolt_poly(0.32):
		bolt.append(Vector3(v.x, v.y, 0))
	bolt.append(bolt[0])
	put(g, tube(bolt, 0.01, 0.01, 5), cyan, Vector3(0.15, 0.3, z))
	halo(g, Vector3(-0.1, 0.3, 0.1), 0.7, Color(1.0, 0.3, 0.7, 0.35))
	halo(g, Vector3(0.15, 0.3, 0.1), 0.6, Color(0.2, 0.9, 1.0, 0.3))
	var blink := node(g)
	anim(blink, "call", {"f": _a_neon_blink, "mats": [pink, cyan]})


## Неон: лапка горит ровно с лёгким дрожанием, молния мигает сериями
func _a_neon_blink(_nd: Node3D, t: float, a: Dictionary) -> void:
	var ms: Array = a.mats
	(ms[0] as StandardMaterial3D).emission_energy_multiplier = 2.8 + 0.25 * sin(t * 31.0) * sin(t * 7.0)
	var u := fposmod(t, 3.2)
	var on := 1.0
	if u > 2.2 and u < 2.9:
		on = 0.15 if fposmod(u * 8.0, 1.0) < 0.5 else 1.0
	(ms[1] as StandardMaterial3D).emission_energy_multiplier = 3.0 * on


## Рампа (★): полутруба, по ней сам катается скейт
const RAMP_FLAT := 0.32
const RAMP_R := 0.62
const RAMP_Y0 := 0.08


static func _ramp_y(x: float) -> float:
	var ax := absf(x)
	if ax <= RAMP_FLAT:
		return RAMP_Y0
	var d := minf(ax - RAMP_FLAT, RAMP_R * 0.97)
	return RAMP_Y0 + RAMP_R - sqrt(RAMP_R * RAMP_R - d * d)


static func _ramp_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nn := 40
	var xe := RAMP_FLAT + RAMP_R * 0.97
	var D := 0.45
	for i in nn:
		var x0 := lerpf(-xe, xe, float(i) / nn)
		var x1 := lerpf(-xe, xe, float(i + 1) / nn)
		var a := Vector3(x0, _ramp_y(x0), -D)
		var b := Vector3(x1, _ramp_y(x1), -D)
		var c := Vector3(x1, _ramp_y(x1), D)
		var d := Vector3(x0, _ramp_y(x0), D)
		var nrm := Vector3(-(_ramp_y(x1) - _ramp_y(x0)), x1 - x0, 0).normalized()
		# середина темнее, края светлее; у верха — белая полоса
		var mx := absf((x0 + x1) * 0.5)
		var col := Color("#4F8BEA") if mx < RAMP_FLAT + 0.2 else Color("#6FA6F5")
		if mx > xe - 0.06:
			col = Color("#E8F0FF")
		tri(st, a, b, c, nrm, col, col, col)
		tri(st, a, c, d, nrm, col, col, col)
	st.index()
	st.generate_normals()
	return st.commit()


func _d_ramp(n: Node3D) -> void:
	var xe := RAMP_FLAT + RAMP_R * 0.97
	var top := _ramp_y(xe)
	if not _geo.has("ramp"):
		_geo["ramp"] = _ramp_mesh()
		# боковина: фигура под профилем (с площадками по краям)
		var poly := PackedVector2Array()
		for i in 41:
			var x := lerpf(-xe, xe, i / 40.0)
			poly.append(Vector2(x, _ramp_y(x)))
		poly.append(Vector2(xe + 0.22, top))
		poly.append(Vector2(xe + 0.22, 0.0))
		poly.append(Vector2(-xe - 0.22, 0.0))
		poly.append(Vector2(-xe - 0.22, top))
		_geo["ramp_side"] = extrude(poly, 0.05)
	put(n, _geo["ramp"], vmat(0.6, 0.3))
	for sz in [-1.0, 1.0]:
		put(n, _geo["ramp_side"], _m("#F2C27A", 0.85), Vector3(0, 0, sz * 0.47))
		# на боковинах — молнии, звёзды и лапка
		var deco := node(n, Vector3(0, 0, sz * 0.5))
		deco.rotation.y = 0.0 if sz > 0.0 else PI
		put(deco, extrude(_bolt_poly(0.34), 0.012), _m("#FF4FA3", 0.5, 0.3, false), Vector3(-0.66, 0.4, 0))
		put(deco, extrude(_bolt_poly(0.34), 0.012), _m("#3FE0FF", 0.5, 0.3, false), Vector3(0.66, 0.4, 0))
		for sp in [Vector3(-0.22, 0.04, 0), Vector3(0.24, 0.04, 0), Vector3(0.0, 0.03, 0.002)]:
			put(deco, extrude(star_poly(0.035, 0.016), 0.012), _m("#FFD34D", 0.5, 0.3, false), sp)
		_paw(deco, Vector3(1.02, 0.36, 0.01), 1.2, Color("#FFFFFF"))
	for sx in [-1.0, 1.0]:
		# площадки наверху, трубы-края, перила, флажки-молнии
		put(n, box(Vector3(0.24, 0.04, 0.98)), _m("#C98A4A", 0.85), Vector3(sx * (xe + 0.11), top - 0.02, 0))
		put(n, cyl(0.022, 0.022, 0.96, 10), _m("#D8DCEC", 0.25), Vector3(sx * xe, top + 0.01, 0), Vector3(PI / 2.0, 0, 0))
		for sz in [-0.42, 0.42]:
			put(n, cyl(0.012, 0.012, 0.3, 6), _m("#2A2440", 0.5), Vector3(sx * (xe + 0.2), top + 0.15, sz))
		put(n, cyl(0.014, 0.014, 0.86, 6), _m("#FF4FA3", 0.5), Vector3(sx * (xe + 0.2), top + 0.3, 0), Vector3(PI / 2.0, 0, 0))
		var fp := Vector3(sx * (xe + 0.2), top + 0.3, -0.42)
		put(n, cyl(0.008, 0.008, 0.34, 4), _m("#2A2440", 0.5, 0.0, false), fp + Vector3(0, 0.17, 0))
		var fl := node(n, fp + Vector3(0, 0.3, 0))
		fl.rotation.y = 0.0 if sx < 0 else PI
		anim(fl, "flag", {"p": sx})
		put(fl, extrude(PackedVector2Array([Vector2(0, 0.06), Vector2(0.2, 0.0), Vector2(0, -0.06)]), 0.008), mat(Color("#FFD34D") if sx < 0 else Color("#3FE0FF"), 0.6, 0.3, false))
	# лапка на дне полутрубы
	var pw := node(n, Vector3(0, RAMP_Y0 + 0.003, 0.2))
	pw.rotation.x = -PI / 2.0
	_paw(pw, Vector3.ZERO, 2.2, Color("#FFD34D"))
	# скейт катается туда-сюда; за ним — искорки-звёздочки
	var ride := node(n)
	anim(ride, "call", {"f": _a_ramp_ride, "lag": 0.0})
	var b := _skate(ride)
	b.position.y = -0.035
	for i in 3:
		var sp := node(n)
		anim(sp, "call", {"f": _a_ramp_ride, "lag": 0.12 + i * 0.1, "spark": true})
		put(sp, extrude(star_poly(0.03 - i * 0.006, 0.013 - i * 0.003), 0.006), glow_mat(Color("#FFE27A"), 2.6), Vector3(0, 0.07, 0))


func _a_ramp_ride(nd: Node3D, t: float, a: Dictionary) -> void:
	var tt := t - float(a.lag)
	var xe := RAMP_FLAT + RAMP_R * 0.93
	var x := xe * sin(tt * 1.7)
	var y := _ramp_y(x)
	var dx := 0.01
	var slope := atan2(_ramp_y(x + dx) - _ramp_y(x - dx), 2.0 * dx)
	var b := Basis(Vector3.BACK, slope)
	if a.get("spark", false):
		b = Basis(Vector3.UP, tt * 3.0)
	nd.transform = Transform3D(b, Vector3(x, y, 0.0))


# ---------- 0.15: стиль сада — забор, земля, свет ----------
# Каждый вариант — свой узел (строится при первом выборе, дальше только показывается). Будку забор слегка
# подкрашивает (чтобы будка и забор смотрелись вместе). В простом качестве россыпей (цветы, хвоя, плющ) — вдвое меньше.

## Небо сада: как sky_dome (scripts/home3d/shaders.gd), но цвета, звёзды и «солнце у горизонта» — параметры
const PUP_SKY := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, depth_draw_never;
uniform float rainbow = 0.0;
uniform vec3 top_col = vec3(0.035, 0.025, 0.12);
uniform vec3 low_col = vec3(0.16, 0.11, 0.34);
uniform vec3 band_col = vec3(0.30, 0.18, 0.42);
uniform float band = 0.6;
uniform float stars = 1.0;
uniform vec3 sun_dir = vec3(-0.35, 0.06, -1.0);
uniform vec3 sun_col = vec3(1.0, 0.6, 0.3);
uniform float sun = 0.0;
uniform float party = 0.0;
varying vec3 dir;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { dir = normalize(VERTEX); }
void fragment() {
	vec3 d = normalize(dir);
	float y = d.y;
	vec3 c = mix(low_col, top_col, smoothstep(-0.05, 0.6, y));
	c = mix(c, band_col, smoothstep(0.25, 0.0, y) * band);
	vec3 sd = normalize(sun_dir);
	float sa = max(dot(d, sd), 0.0);
	c += sun_col * sun * (pow(sa, 6.0) * 0.55 + pow(sa, 60.0) * 0.6) * smoothstep(-0.1, 0.05, y);
	vec2 sp = vec2(atan(d.z, d.x) * 30.0, y * 40.0);
	vec2 id = floor(sp);
	vec2 f = fract(sp) - 0.5;
	float h = hash(id);
	if (h > 0.8 && y > 0.05) {
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float dd = length(f - o * 0.6);
		float tw = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 50.0);
		vec3 sc = mix(vec3(1.0, 0.95, 0.8), clamp(abs(mod(h * 37.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0), party);
		c += sc * smoothstep(0.05 + 0.1 * hash(id + 1.3), 0.0, dd) * tw * 1.4 * stars * smoothstep(0.05, 0.3, y + (1.0 - sun) * 0.3);
	}
	if (rainbow > 0.0) {
		vec3 ax = normalize(vec3(-0.35, -0.12, -1.0));
		float a = acos(clamp(dot(d, ax), -1.0, 1.0));
		float r = (a - 0.62) / 0.12;
		if (r > 0.0 && r < 1.0 && y > -0.02) {
			vec3 rb = clamp(abs(mod(r * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
			float e = smoothstep(0.0, 0.15, r) * smoothstep(1.0, 0.85, r) * smoothstep(-0.02, 0.15, y);
			c = mix(c, rb, e * 0.45 * rainbow);
		}
	}
	ALBEDO = c;
}
"""

## Роспись бетонной стены: полосы-волны, лапки, звёзды, молнии, подтёки (UV: x — метры вдоль забора, y — высота)
const PUP_MURAL := """
shader_type spatial;
uniform float rough = 0.8;
float sd_ell(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float sd_seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a; vec2 ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
float sd_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 ink = vec3(0.13, 0.08, 0.22);
	if (uv.y < -0.5) {
		// обратная сторона и торцы — простой бетон
		ALBEDO = vec3(0.42, 0.4, 0.5);
		ROUGHNESS = 0.95;
	} else if (uv.y > 1.15) {
		ALBEDO = vec3(0.62, 0.6, 0.72);
		ROUGHNESS = 0.9;
	} else {
		float aa = fwidth(uv.x) * 1.2;
		float seg = floor(uv.x / 1.7);
		vec3 pal[5] = vec3[5](vec3(1.0, 0.55, 0.72), vec3(0.35, 0.82, 0.86), vec3(1.0, 0.82, 0.35), vec3(0.62, 0.5, 0.95), vec3(0.5, 0.85, 0.5));
		vec3 base = pal[int(mod(seg, 5.0))];
		vec3 base2 = pal[int(mod(seg + 2.0, 5.0))];
		// волна второго цвета внизу
		float wave = uv.y - (0.32 + 0.08 * sin(uv.x * 3.1 + seg));
		vec3 col = mix(base2, base, smoothstep(-aa, aa, wave));
		col = mix(col, ink, smoothstep(aa * 1.5, 0.0, abs(wave) - 0.012));
		// фигуры: по одной на участок — лапка / звезда / молния
		vec2 c = vec2((seg + 0.5) * 1.7, 0.66);
		vec2 q = uv - c;
		float kind = mod(seg, 3.0);
		float sh;
		if (kind < 0.5) {
			sh = sd_ell(q, vec2(0.0, -0.06), vec2(0.17, 0.13));
			sh = min(sh, sd_ell(q, vec2(-0.17, 0.1), vec2(0.06, 0.08)));
			sh = min(sh, sd_ell(q, vec2(-0.06, 0.2), vec2(0.06, 0.08)));
			sh = min(sh, sd_ell(q, vec2(0.06, 0.2), vec2(0.06, 0.08)));
			sh = min(sh, sd_ell(q, vec2(0.17, 0.1), vec2(0.06, 0.08)));
		} else if (kind < 1.5) {
			sh = sd_star(q, 0.22, 0.45);
		} else {
			sh = min(sd_seg(q, vec2(0.1, 0.25), vec2(-0.09, 0.0)), sd_seg(q, vec2(-0.09, 0.0), vec2(0.09, 0.0)));
			sh = min(sh, sd_seg(q, vec2(0.09, 0.0), vec2(-0.09, -0.25))) - 0.04;
		}
		vec3 fill = kind < 0.5 ? vec3(1.0, 0.97, 0.92) : (kind < 1.5 ? vec3(1.0, 0.88, 0.3) : vec3(0.3, 0.95, 1.0));
		col = mix(col, ink, smoothstep(aa, -aa, sh - 0.025));
		col = mix(col, fill, smoothstep(aa, -aa, sh));
		// маленькие звёздочки и точки
		vec2 c2 = vec2((seg + 0.12 + 0.76 * hash(seg)) * 1.7, 0.92 - 0.1 * hash(seg + 3.0));
		float st = sd_star(uv - c2, 0.06, 0.45);
		col = mix(col, ink, smoothstep(aa, -aa, st - 0.012));
		col = mix(col, vec3(1.0), smoothstep(aa, -aa, st));
		// подтёки краски сверху
		float dx = fract(uv.x * 2.3) - 0.5;
		float dl = 0.06 + 0.12 * hash(floor(uv.x * 2.3));
		float drip = max(abs(dx) - 0.035, (1.08 - uv.y) - dl);
		col = mix(col, base * 0.75, smoothstep(aa, -aa, drip));
		// бетонная фактура
		col *= 0.93 + 0.07 * hash(floor(uv.x * 40.0) + floor(uv.y * 40.0) * 57.0);
		ALBEDO = col;
		ROUGHNESS = rough;
		EMISSION = col * 0.12;
	}
}
"""

## Площадка: асфальт с крапинками, линии, звёзды и лапка (UV — координаты x, z в саду)
const PUP_COURT := """
shader_type spatial;
uniform vec2 center = vec2(0.2, 0.55);
uniform float radius = 3.25;
float sd_ell(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float sd_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 w = UV;
	vec2 p = w - center;
	float r = length(p);
	float aa = fwidth(r) * 1.3;
	vec3 asph = vec3(0.24, 0.24, 0.34);
	vec3 col = asph * (0.9 + 0.2 * hash(floor(w * 30.0)));
	col += vec3(0.1) * step(0.97, hash(floor(w * 55.0)));
	vec3 white = vec3(0.92, 0.94, 1.0);
	vec3 yel = vec3(1.0, 0.82, 0.3);
	vec3 cy = vec3(0.3, 0.9, 1.0);
	// внешняя линия и центральный круг
	col = mix(col, white, smoothstep(aa, -aa, abs(r - (radius - 0.22)) - 0.035));
	col = mix(col, yel, smoothstep(aa, -aa, abs(r - 1.45) - 0.03) * step(0.5, fract(atan(p.y, p.x) * 6.0 / 3.14159)));
	col = mix(col, white, smoothstep(aa, -aa, abs(p.x) - 0.03) * step(1.45, r) * step(r, radius - 0.22));
	// лапка впереди и звёзды по кругу
	vec2 q = (w - vec2(0.0, 2.35)) * vec2(1.0, -1.0);
	float paw = sd_ell(q, vec2(0.0, -0.1), vec2(0.32, 0.25));
	paw = min(paw, sd_ell(q, vec2(-0.32, 0.2), vec2(0.11, 0.14)));
	paw = min(paw, sd_ell(q, vec2(-0.11, 0.38), vec2(0.11, 0.14)));
	paw = min(paw, sd_ell(q, vec2(0.11, 0.38), vec2(0.11, 0.14)));
	paw = min(paw, sd_ell(q, vec2(0.32, 0.2), vec2(0.11, 0.14)));
	col = mix(col, cy, smoothstep(aa, -aa, paw) * 0.9);
	for (int i = 0; i < 5; i++) {
		float a = 0.6 + float(i) * 1.257;
		vec2 c = center + vec2(cos(a), sin(a)) * 2.4;
		col = mix(col, yel, smoothstep(aa, -aa, sd_star(w - c, 0.2, 0.45)));
	}
	// край площадки растворяется в траве
	float edge = smoothstep(radius, radius - 0.12, r);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	EMISSION = col * 0.05;
	ALPHA = edge;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## Хвойный ковёр: рыжие и бурые хвоинки штрихами, пятнами (между пятнами видна трава)
const PUP_NEEDLES := """
shader_type spatial;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 w = UV;
	float r = length(w);
	float n = vnoise(w * 0.9) * 0.65 + vnoise(w * 2.3) * 0.35;
	float mask = n + 0.22 * smoothstep(1.3, 2.6, r) - 0.18 * smoothstep(4.6, 5.5, r);
	vec3 col = mix(vec3(0.5, 0.28, 0.15), vec3(0.7, 0.42, 0.2), vnoise(w * 4.0));
	for (int k = 0; k < 2; k++) {
		vec2 g = w * (14.0 + float(k) * 9.0);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + float(k) * 7.1);
		float a = h * 6.2831;
		vec2 d = vec2(cos(a), sin(a));
		float t = clamp(dot(f, d), -0.45, 0.45);
		float line = length(f - d * t);
		vec3 nc = mix(vec3(0.85, 0.55, 0.25), vec3(0.4, 0.24, 0.12), hash(id + 3.3));
		col = mix(col, nc, smoothstep(0.09, 0.03, line));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	ALPHA = smoothstep(0.42, 0.5, mask);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""


## Окошки дальнего города (неон): светятся сами, цвет — из цвета экземпляра
const PUP_WINDOWS := """
shader_type spatial;
render_mode unshaded, fog_disabled;
void fragment() {
	float tw = 0.75 + 0.25 * sin(TIME * 1.3 + COLOR.r * 40.0);
	ALBEDO = COLOR.rgb * 1.6 * tw;
}
"""

const PUP_WALL_TINT := {"pup_walls_picket": Color(1, 1, 1), "pup_walls_logs": Color(0.92, 0.85, 0.8),
	"pup_walls_ivy": Color(0.95, 1.02, 0.95), "pup_walls_paint": Color(1.08, 0.97, 1.1)}


func apply_walls(id: String) -> void:
	if not _wall_nodes.has(id):
		var root := node(_house)
		root.name = "fence_" + id
		var saved := _begin_build()
		match id:
			"pup_walls_logs": _fence_logs(root)
			"pup_walls_ivy": _fence_ivy(root)
			"pup_walls_paint": _fence_mural(root)
		_end_build(root, saved)
		_wall_nodes[id] = root
	for k in _wall_nodes:
		(_wall_nodes[k] as Node3D).visible = k == id
	_tint_parts([wall_parts[0]], PUP_WALL_TINT.get(id, Color(1, 1, 1)), "tint")
	_apply_hq()


func apply_floor(id: String) -> void:
	super.apply_floor(id)  # земля — оттенок из каталога
	if id != "pup_floor_lawn" and not _floor_nodes.has(id):
		var root := node(_house)
		root.name = "ground_" + id
		var saved := _begin_build()
		match id:
			"pup_floor_meadow": _ground_meadow(root)
			"pup_floor_pine": _ground_pine(root)
			"pup_floor_court": _ground_court(root)
		_end_build(root, saved)
		_floor_nodes[id] = root
	for k in _floor_nodes:
		(_floor_nodes[k] as Node3D).visible = k == id
	# трава: свой цвет у каждого варианта; на площадке травы и цветов нет
	var gc := {"pup_floor_meadow": [Color("#5FAF5A"), Color("#A8D86A")], "pup_floor_pine": [Color("#4A6A3A"), Color("#7A7A3E")]}
	if _grass:
		var mm := _grass.multimesh
		var cc: Array = gc.get(id, [])
		for i in _grass_xf.size():
			var xf: Transform3D = _grass_xf[i]
			if id == "pup_floor_court" and _in_court(xf.origin, 0.15):
				xf = Transform3D(Basis.from_scale(Vector3.ONE * 0.001), xf.origin)
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, _grass_col[i] if cc.is_empty() else (cc[0] as Color).lerp(cc[1], hash1(i, 85)))
	for g in _garden_mm:
		var mm2: MultiMesh = (g[0] as MultiMeshInstance3D).multimesh
		var list: Array = g[1]
		for i in list.size():
			var xf: Transform3D = list[i]
			if id == "pup_floor_court" and _in_court(xf.origin, 0.1):
				xf = Transform3D(Basis.from_scale(Vector3.ONE * 0.001), xf.origin)
			mm2.set_instance_transform(i, xf)
	_apply_hq()


const COURT_C := Vector2(0.2, 0.55)
const COURT_R := 3.25


static func _in_court(p: Vector3, margin: float) -> bool:
	return Vector2(p.x, p.z).distance_to(COURT_C) < COURT_R + margin


## Настроение света: небо, луна, свои огоньки. Яркость и оттенок ламп — как в каталоге (room.gd)
const PUP_SKIES := {
	"pup_light_stars": {"top_col": Vector3(0.035, 0.025, 0.12), "low_col": Vector3(0.16, 0.11, 0.34), "band_col": Vector3(0.3, 0.18, 0.42),
		"band": 0.6, "stars": 1.0, "sun": 0.0, "party": 0.0},
	"pup_light_sunset": {"top_col": Vector3(0.12, 0.08, 0.3), "low_col": Vector3(0.85, 0.42, 0.42), "band_col": Vector3(1.0, 0.66, 0.36),
		"band": 0.9, "stars": 0.35, "sun": 1.0, "party": 0.0, "sun_col": Vector3(1.0, 0.62, 0.3)},
	"pup_light_party": {"top_col": Vector3(0.07, 0.03, 0.16), "low_col": Vector3(0.4, 0.14, 0.46), "band_col": Vector3(0.62, 0.24, 0.55),
		"band": 0.7, "stars": 1.3, "sun": 0.0, "party": 1.0},
	"pup_light_neon": {"top_col": Vector3(0.015, 0.02, 0.08), "low_col": Vector3(0.05, 0.22, 0.38), "band_col": Vector3(0.55, 0.12, 0.5),
		"band": 0.8, "stars": 0.6, "sun": 0.55, "party": 0.0, "sun_col": Vector3(0.9, 0.2, 0.8)},
}


func apply_light(id: String) -> void:
	super.apply_light(id)
	var sky: Dictionary = PUP_SKIES.get(id, PUP_SKIES["pup_light_stars"])
	if _sky_mat:
		for k in sky:
			_sky_mat.set_shader_parameter(k, sky[k])
	for m in _moon_nodes:
		(m as Node3D).visible = id != "pup_light_sunset"
	if id != "pup_light_stars" and not _light_nodes.has(id):
		var root := node(_house)
		root.name = "light_" + id
		var saved := _begin_build()
		match id:
			"pup_light_sunset": _light_sunset(root)
			"pup_light_party": _light_party(root)
			"pup_light_neon": _light_neon(root)
		_end_build(root, saved)
		_light_nodes[id] = root
	for k in _light_nodes:
		(_light_nodes[k] as Node3D).visible = k == id
	_apply_hq()


## Сборка узла варианта: свои анимации — в общий список дома, неподвижное склеивается
func _begin_build() -> Array:
	var saved := anims
	anims = []
	return saved


func _end_build(root: Node3D, saved: Array) -> void:
	var moving := []
	for a in anims:
		moving.append(a.n)
	merge_static(root, moving)
	saved.append_array(anims)
	anims = saved
	if built:
		_shadow_casters()


func set_quality(hq: bool) -> void:
	super.set_quality(hq)
	_apply_hq()


## Простое качество: россыпи (цветы луга, хвоя, плющ, окна города) — вдвое реже
func _apply_hq() -> void:
	for mmi in _hq_counts:
		if is_instance_valid(mmi):
			var full: int = _hq_counts[mmi]
			(mmi as MultiMeshInstance3D).multimesh.visible_instance_count = full if high else full / 2


func _hq_scatter(parent: Node3D, mesh: Mesh, m: Material, xfs: Array, cols := []) -> MultiMeshInstance3D:
	var mmi := scatter(parent, mesh, m, xfs, cols)
	_hq_counts[mmi] = xfs.size()
	return mmi


## Точки вдоль забора: угол a, радиус r
func _fence_arc(step: float, r: float) -> Array:
	var out := []
	var nn := int((FENCE_A1 - FENCE_A0) * r / step)
	for i in nn + 1:
		out.append(lerpf(FENCE_A0, FENCE_A1, float(i) / nn))
	return out


## Частокол из брёвен: брёвна с заострёнными верхушками, верёвочная обвязка
func _fence_logs(root: Node3D) -> void:
	var r := 4.34
	var logs := [[], []]
	var tops := [[], []]
	var rings := []
	var i := 0
	for a in _fence_arc(0.2, r):
		var p := dir(a) * r
		var hh := 1.0 + 0.18 * hash1(i, 31)
		var b := Basis(Vector3.UP, face_center(a) + hash1(i, 32))
		logs[i % 2].append(Transform3D(b * Basis.from_scale(Vector3(1, hh, 1)), p + Vector3(0, hh * 0.5, 0)))
		tops[i % 2].append(Transform3D(b, p + Vector3(0, hh + 0.09, 0)))
		rings.append(Transform3D(Basis(Vector3.UP, face_center(a)) * Basis(Vector3.RIGHT, PI / 2.0), p + Vector3(0, hh + 0.005, 0) + dir(a + PI) * 0.0))
		i += 1
	scatter(root, cyl(0.1, 0.1, 1.0, 9), mat(Color("#9A6A44"), 0.95), logs[0])
	scatter(root, cyl(0.1, 0.1, 1.0, 9), mat(Color("#8A5C3A"), 0.95), logs[1])
	scatter(root, cyl(0.0, 0.1, 0.18, 9), mat(Color("#C89A66"), 0.9), tops[0])
	scatter(root, cyl(0.0, 0.1, 0.18, 9), mat(Color("#B88A58"), 0.9), tops[1])
	# верёвка в два ряда и столбы-брёвна по краям
	for y in [0.32, 0.8]:
		var pts := []
		for k in 33:
			pts.append(dir(lerpf(FENCE_A0, FENCE_A1, k / 32.0)) * (r - 0.1) + Vector3(0, y, 0))
		put(root, tube(pts, 0.018, 0.018, 4), mat(Color("#D8C08A"), 1.0))
	for a in [FENCE_A0, FENCE_A1]:
		put(root, cyl(0.14, 0.15, 1.5, 10), mat(Color("#7A4A30"), 0.95), dir(a) * r + Vector3(0, 0.75, 0))
		put(root, cyl(0.0, 0.15, 0.24, 10), mat(Color("#B88A58"), 0.9), dir(a) * r + Vector3(0, 1.62, 0))
		put(root, sphere(0.05, 8), mat(Color("#FFD34D"), 0.6, 0.6, false), dir(a) * (r - 0.15) + Vector3(0, 1.3, 0))


## Каменная ограда с плющом: камни в три ряда, плоские камни сверху, плющ свисает пятнами
func _fence_ivy(root: Node3D) -> void:
	var r := 4.38
	var groups := [[], [], []]
	var i := 0
	for row in 3:
		var y := 0.14 + row * 0.27
		var off := 0.5 if row % 2 == 1 else 0.0
		var nn := int((FENCE_A1 - FENCE_A0) * r / 0.44)
		for k in nn:
			var a := lerpf(FENCE_A0, FENCE_A1, (k + off) / nn)
			var b := Basis(Vector3.UP, face_center(a)) * Basis.from_scale(Vector3(1.12 + 0.12 * hash1(i, 41), 0.68 + 0.08 * hash1(i, 42), 0.7))
			groups[i % 3].append(Transform3D(b, dir(a) * r + Vector3(0, y, 0)))
			i += 1
	var sc := [Color("#8E88B0"), Color("#A49EC4"), Color("#7C769E")]
	for g in 3:
		scatter(root, sphere(0.2, 10), mat(sc[g], 0.95), groups[g])
	var caps := []
	var nc := int((FENCE_A1 - FENCE_A0) * r / 0.5)
	for k in nc:
		var a := lerpf(FENCE_A0, FENCE_A1, (k + 0.5) / nc)
		caps.append(Transform3D(Basis(Vector3.UP, face_center(a)), dir(a) * r + Vector3(0, 0.9, 0)))
	scatter(root, box(Vector3(0.5, 0.08, 0.36)), mat(Color("#B8B2D8"), 0.9), caps)
	# плющ: листья свисают с верха пятнами
	var leaves := []
	var lc := []
	var greens := [Color("#3E9A58"), Color("#58B868"), Color("#7AD07A"), Color("#2F7A4A")]
	var fl := []
	for patch in 12:
		var a0 := lerpf(FENCE_A0 + 0.08, FENCE_A1 - 0.08, (patch + 0.5) / 12.0 + 0.02 * sin(patch * 3.0))
		var w := 0.45 + 0.3 * hash1(patch, 51)
		for k in 40:
			var u := hash1(patch * 40 + k, 52)
			var a := a0 + (u - 0.5) * w / r
			var hang := pow(hash1(patch * 40 + k, 53), 0.7) * (0.45 + 0.35 * hash1(patch, 54))
			var p := dir(a) * (r - 0.16) + Vector3(0, 0.95 - hang, 0)
			var b := Basis(Vector3.UP, face_center(a)) * Basis(Vector3.BACK, hash1(k, 55) * 6.0) * Basis.from_scale(Vector3(1.0, 1.0, 0.3))
			leaves.append(Transform3D(b, p))
			lc.append(greens[(patch + k) % 4])
			if k % 9 == 0:
				fl.append(Transform3D(Basis(), p + dir(a + PI) * 0.03))
	_hq_scatter(root, sphere(0.065, 6), vmat(0.9, 0.2), leaves, lc)
	scatter(root, sphere(0.025, 6), mat(Color("#FFE9F4"), 0.7, 0.3, false), fl)
	for a in [FENCE_A0, FENCE_A1]:
		put(root, box(Vector3(0.36, 1.1, 0.36)), mat(Color("#9A94C0"), 0.9), dir(a) * r + Vector3(0, 0.55, 0), Vector3(0, face_center(a), 0))
		put(root, box(Vector3(0.44, 0.08, 0.44)), mat(Color("#B8B2D8"), 0.9), dir(a) * r + Vector3(0, 1.14, 0), Vector3(0, face_center(a), 0))


## Цветная бетонная стена: одна дуга с росписью (свой шейдер), сверху — карниз
func _fence_mural(root: Node3D) -> void:
	var r0 := 4.26
	var r1 := 4.42
	var H := 1.12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nn := 60
	var len := 0.0
	for i in nn:
		var a0 := lerpf(FENCE_A0, FENCE_A1, float(i) / nn)
		var a1 := lerpf(FENCE_A0, FENCE_A1, float(i + 1) / nn)
		var l1 := len + (a1 - a0) * r0
		var f0 := dir(a0) * r0
		var f1 := dir(a1) * r0
		var b0 := dir(a0) * r1
		var b1 := dir(a1) * r1
		var nf := -dir((a0 + a1) * 0.5)
		# лицевая сторона (роспись)
		_quad_uv(st, f0, f1, f1 + Vector3(0, H, 0), f0 + Vector3(0, H, 0), nf, Vector2(len, 0), Vector2(l1, 0), Vector2(l1, H), Vector2(len, H))
		# верх и обратная сторона
		_quad_uv(st, f0 + Vector3(0, H, 0), f1 + Vector3(0, H, 0), b1 + Vector3(0, H, 0), b0 + Vector3(0, H, 0), Vector3.UP, Vector2(0, 2), Vector2(0, 2), Vector2(0, 2), Vector2(0, 2))
		_quad_uv(st, b0, b1, b1 + Vector3(0, H, 0), b0 + Vector3(0, H, 0), -nf, Vector2(0, -1), Vector2(0, -1), Vector2(0, -1), Vector2(0, -1))
		len = l1
	for a in [FENCE_A0, FENCE_A1]:
		var t := dir(a + PI / 2.0) * (1.0 if a == FENCE_A0 else -1.0)
		var f := dir(a) * r0
		var b := dir(a) * r1
		_quad_uv(st, f, b, b + Vector3(0, H, 0), f + Vector3(0, H, 0), -t, Vector2(0, -1), Vector2(0, -1), Vector2(0, -1), Vector2(0, -1))
	st.generate_normals()
	var mi := put(root, st.commit(), _shader_mat("pup_mural", PUP_MURAL))
	mi.name = "mural"
	# карниз сверху
	var pts := []
	for k in 41:
		pts.append(dir(lerpf(FENCE_A0, FENCE_A1, k / 40.0)) * ((r0 + r1) * 0.5) + Vector3(0, H + 0.02, 0))
	put(root, tube(pts, 0.1, 0.1, 4), mat(Color("#8E8AA8"), 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.35, 1))


static func _quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	var vs := [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]
	if (b - a).cross(c - a).dot(nrm) > 0.0:
		vs = [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]
	for v in vs:
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Точка на земле сада, свободная от мест украшений, дорожки и будки
func _free_ground(i: int, salt: int, r0 := 1.2, r1 := 4.9) -> Vector3:
	for tries in 6:
		var a := hash1(i * 7 + tries, salt) * TAU
		var rr := r0 + sqrt(hash1(i * 7 + tries, salt + 1)) * (r1 - r0)
		var p := dir(a) * rr
		if Vector2(p.x, p.z - 0.3).length() < 1.35:
			continue
		var ok := true
		for s in ["floor_l", "floor_r", "near", "near_2", "floor_front", "big_back", "big_side"]:
			var rad := 1.15 if s.begins_with("big") else 0.55
			if Vector2(p.x - spots[s].pos.x, p.z - spots[s].pos.z).length() < rad:
				ok = false
		if Vector2(p.x - shelf_def.pos.x, p.z - shelf_def.pos.z).length() < 0.7:
			ok = false
		if ok:
			p.y = _ground_h(p)
			return p
	return Vector3(0, -5, 0)


## Цветочный луг: россыпь цветов (одна сетка на всех), ромашки и люпины
func _ground_meadow(root: Node3D) -> void:
	var heads := []
	var cols := []
	var pal := [Color("#FF8FC8"), Color("#FFE27A"), Color("#B8A2FF"), Color("#FFFFFF"), Color("#FF8A5C"), Color("#8FD8FF")]
	for i in 240:
		var p := _free_ground(i, 301)
		var hh := 0.08 + 0.12 * hash1(i, 303)
		heads.append(Transform3D(Basis(Vector3.UP, i) * Basis.from_scale(Vector3.ONE * (0.8 + 0.5 * hash1(i, 304))), p + Vector3(0, hh, 0)))
		cols.append(pal[i % pal.size()])
	_hq_scatter(root, _geo["flower"], vmat(0.7, 0.3), heads, cols)
	# ромашки покрупнее
	if not _geo.has("daisy"):
		var st := SurfaceTool.new()
		for k in 9:
			var a := TAU * k / 9.0
			st.append_from(sphere(0.03, 6), 0, Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(1.0, 0.35, 0.5)), Vector3(cos(a) * 0.045, 0, sin(a) * 0.045)))
		_geo["daisy"] = st.commit()
	var dz := []
	var cz := []
	for i in 50:
		var p := _free_ground(i, 311, 1.4, 4.6)
		var hh := 0.2 + 0.1 * hash1(i, 313)
		dz.append(Transform3D(Basis(Vector3.UP, i) * Basis(Vector3.RIGHT, 0.25), p + Vector3(0, hh, 0)))
		cz.append(Transform3D(Basis.from_scale(Vector3(1, 0.6, 1)), p + Vector3(0, hh + 0.01, 0)))
	_hq_scatter(root, _geo["daisy"], mat(Color("#FFFFFF"), 0.7, 0.15, false), dz)
	_hq_scatter(root, sphere(0.025, 6), mat(Color("#FFC93C"), 0.6, 0.2, false), cz)
	# люпины: свечки лиловых и розовых цветков
	var lp := [[], []]
	for i in 26:
		var p := _free_ground(i, 321, 2.2, 4.4)
		lp[i % 2].append(Transform3D(Basis.from_scale(Vector3(1, 1.0 + 0.4 * hash1(i, 322), 1)), p + Vector3(0, 0.2, 0)))
	scatter(root, cyl(0.012, 0.045, 0.32, 6), mat(Color("#B48CFF"), 0.7, 0.1, false), lp[0])
	scatter(root, cyl(0.012, 0.045, 0.32, 6), mat(Color("#FF8FC8"), 0.7, 0.1, false), lp[1])
	# бабочки
	for i in 3:
		var b := node(root, Vector3(-1.5 + i * 1.6, 0.6 + 0.2 * i, 2.0 - i * 1.5))
		anim(b, "drift", {"amp": Vector3(0.6, 0.15, 0.5), "tilt": 0.3, "p": float(i) * 2.0})
		for sx in [-1.0, 1.0]:
			var wing := node(b)
			anim(wing, "wiggle", {"axis": Vector3.BACK, "amp": 0.7, "spd": 9.0, "p": float(i) + (0.0 if sx > 0 else PI)})
			put(wing, sphere(0.04, 8), mat([Color("#FFD34D"), Color("#FF8FC8"), Color("#8FD8FF")][i], 0.6, 0.4, false), Vector3(sx * 0.035, 0, 0), Vector3.ZERO, Vector3(1.0, 0.15, 0.8))


## Лесная хвоя и шишки: хвоинки (одна сетка), шишки, грибочки, веточки
func _ground_pine(root: Node3D) -> void:
	var nd := []
	var nc := []
	# ковёр из хвои: пятнами по саду (свой шейдер), сверху — отдельные хвоинки
	if not _geo.has("needle_bed"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 18
		var segs := 64
		var pts := []
		for j in rings + 1:
			var row := []
			for i in segs + 1:
				var p := dir(TAU * i / segs) * lerpf(1.05, 5.6, float(j) / rings)
				p.y = _ground_h(p) + 0.01
				row.append(p)
			pts.append(row)
		for j in rings:
			for i in segs:
				var A: Vector3 = pts[j][i]
				var B: Vector3 = pts[j][i + 1]
				var C: Vector3 = pts[j + 1][i + 1]
				var D: Vector3 = pts[j + 1][i]
				_quad_uv(st, A, B, C, D, Vector3.UP, Vector2(A.x, A.z), Vector2(B.x, B.z), Vector2(C.x, C.z), Vector2(D.x, D.z))
		st.generate_normals()
		_geo["needle_bed"] = st.commit()
	put(root, _geo["needle_bed"], _shader_mat("pup_needles", PUP_NEEDLES))
	var pal := [Color("#E0904A"), Color("#C8743A"), Color("#A8B04A"), Color("#F0B060")]
	for i in 700:
		var p := _free_ground(i, 401, 0.9, 5.4)
		var b := Basis(Vector3.UP, hash1(i, 402) * TAU) * Basis(Vector3.BACK, (hash1(i, 403) - 0.5) * 0.4)
		nd.append(Transform3D(b, p + Vector3(0, 0.015, 0)))
		nc.append(pal[i % 4])
	_hq_scatter(root, box(Vector3(0.15, 0.012, 0.012)), vmat(0.9, 0.1), nd, nc)
	# подушки мха и папоротники
	for i in 10:
		var p := _free_ground(i, 441, 1.6, 4.6)
		put(root, sphere(0.22, 10), mat(Color("#5E9A48"), 1.0), p, Vector3.ZERO, Vector3(1.3, 0.3, 1.0))
	for i in 8:
		var p := _free_ground(i, 451, 2.0, 4.3)
		for k in 5:
			var a := TAU * k / 5.0 + i
			put(root, tube(bez(p, p + dir(a) * 0.12 + Vector3(0, 0.22, 0), p + dir(a) * 0.3 + Vector3(0, 0.12, 0), 5), 0.03, 0.005, 3), mat(Color("#3E8A4A"), 0.9, 0.0, false))
	# шишки: тело и чешуйки (два кольца)
	if not _geo.has("cone"):
		_geo["cone"] = lathe([Vector2(0, 0), Vector2(0.03, 0.01), Vector2(0.05, 0.05), Vector2(0.045, 0.1), Vector2(0.02, 0.14), Vector2(0, 0.15)], 10)
	var cs := []
	for i in 36:
		var p := _free_ground(i, 411, 1.3, 4.8)
		cs.append(Transform3D(Basis(Vector3.UP, i) * Basis(Vector3.BACK, PI / 2.0 - 0.2), p + Vector3(0, 0.05, 0)))
	scatter(root, _geo["cone"], mat(Color("#8A5432"), 0.9), cs)
	# грибочки и веточки
	for i in 7:
		var p := _free_ground(i, 421, 1.8, 4.3)
		put(root, cyl(0.02, 0.025, 0.08, 6), mat(Color("#F4EAD8"), 0.8, 0.0, false), p + Vector3(0, 0.04, 0))
		put(root, hemi(0.055, 10), mat(Color("#E8505B"), 0.6), p + Vector3(0, 0.08, 0))
	for i in 9:
		var p := _free_ground(i, 431, 1.5, 4.8)
		var a := hash1(i, 432) * TAU
		put(root, tube([p + Vector3(0, 0.02, 0) - dir(a) * 0.2, p + Vector3(0, 0.03, 0) + dir(a) * 0.2], 0.014, 0.01, 4), mat(Color("#6B4433"), 0.9))


## Площадка с разметкой: асфальтовый круг по земле (свой шейдер), трава внутри прячется
func _ground_court(root: Node3D) -> void:
	if not _geo.has("court"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 16
		var segs := 64
		var pts := []
		for j in rings + 1:
			var row := []
			for i in segs + 1:
				var p := Vector3(COURT_C.x, 0, COURT_C.y) + dir(TAU * i / segs) * (COURT_R * float(j) / rings)
				p.y = _ground_h(p) + 0.014
				row.append(p)
			pts.append(row)
		for j in rings:
			for i in segs:
				var A: Vector3 = pts[j][i]
				var B: Vector3 = pts[j][i + 1]
				var C: Vector3 = pts[j + 1][i + 1]
				var D: Vector3 = pts[j + 1][i]
				_quad_uv(st, A, B, C, D, Vector3.UP, Vector2(A.x, A.z), Vector2(B.x, B.z), Vector2(C.x, C.z), Vector2(D.x, D.z))
		st.generate_normals()
		_geo["court"] = st.commit()
	put(root, _geo["court"], _shader_mat("pup_court", PUP_COURT, {"center": COURT_C, "radius": COURT_R}))
	# бортик-кольцо из резиновых плиток
	put(root, torus(COURT_R - 0.02, COURT_R + 0.08, 64), mat(Color("#3F7AE0"), 0.8), Vector3(COURT_C.x, 0.02, COURT_C.y), Vector3.ZERO, Vector3(1, 0.4, 1))


## Летний закат: низкое солнце у горизонта, тёплые лучи, мошки-огоньки золотые
func _light_sunset(root: Node3D) -> void:
	var sd := Vector3(-0.35, 0.06, -1.0).normalized()
	put(root, sphere(1.6, 24), mat(Color("#FFB347"), 1.0, 2.2, false), sd * 20.0)
	var hl := halo(root, sd * 19.0, 12.0, Color(1.0, 0.55, 0.25, 0.45))
	hl.material_override = hl.material_override.duplicate()
	(hl.material_override as StandardMaterial3D).disable_fog = true
	shader_swarm(root, "flies", 10, {"center": Vector3(0, 1.0, 0.5), "spread": Vector3(3.6, 0.6, 3.0), "col": Color(1.0, 0.75, 0.4, 1.0), "size": 0.04})


## Праздничные огоньки: гирлянды над садом (три группы мигают по очереди), бумажные фонарики, цветные искорки
func _light_party(root: Node3D) -> void:
	var lines := [[Vector3(-1.75, 2.35, -1.0), Vector3(0, 1.78, 0.42), 0.35], [Vector3(0, 1.72, -0.72), Vector3(2.5, 2.3, -3.4), 0.4],
		[Vector3(-2.55, 2.5, -1.7), Vector3(-0.75, 1.25, -4.18), 0.3], [Vector3(-2.65, 1.2, 3.38), Vector3(-1.75, 2.3, -0.9), 0.45]]
	var groups := [[], [], [], []]
	var wire := mat(Color("#2A2040"), 0.9, 0.0, false)
	var k := 0
	for ln in lines:
		var a: Vector3 = ln[0]
		var b: Vector3 = ln[1]
		var pts := []
		for i in 17:
			var u := i / 16.0
			pts.append(a.lerp(b, u) + Vector3(0, -sin(u * PI) * float(ln[2]), 0))
		put(root, tube(pts, 0.007, 0.007, 3), wire)
		for i in range(1, 16):
			groups[k % 4].append(Transform3D(Basis.from_scale(Vector3(1, 1.35, 1)), (pts[i] as Vector3) + Vector3(0, -0.05, 0)))
			k += 1
	var bc := [Color("#FF6FA8"), Color("#FFD34D"), Color("#7FE3FF"), Color("#9CF58A")]
	var mats := []
	for g in 4:
		var m := glow_mat(bc[g], 2.6, true)
		mats.append(m)
		scatter(root, sphere(0.045, 8), m, groups[g])
	var tw := node(root)
	anim(tw, "call", {"f": _a_mats_twinkle, "mats": mats, "e0": 2.2, "e1": 1.4})
	# бумажные фонарики на первой гирлянде
	var lc := [Color("#FF8FC8"), Color("#FFE27A"), Color("#9FF0FF")]
	for i in 3:
		var u := 0.25 + i * 0.25
		var a: Vector3 = lines[0][0]
		var b: Vector3 = lines[0][1]
		var p := a.lerp(b, u) + Vector3(0, -sin(u * PI) * 0.35 - 0.2, 0)
		var ln := node(root, p + Vector3(0, 0.2, 0))
		anim(ln, "pendulum", {"amp": 0.08, "spd": 1.3, "p": float(i)})
		put(ln, cyl(0.003, 0.003, 0.12, 3), wire, Vector3(0, -0.06, 0))
		put(ln, sphere(0.11, 14), glass(Color(lc[i], 0.85), 1.6), Vector3(0, -0.22, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
		put(ln, cyl(0.05, 0.05, 0.03, 10), mat(Color("#2A2040"), 0.6), Vector3(0, -0.12, 0))
		put(ln, sphere(0.05, 8), glow_mat(Color(lc[i]).lightened(0.5), 2.4), Vector3(0, -0.22, 0))
	# цветные искорки
	var cc := [Color(1.0, 0.45, 0.75, 1.0), Color(0.45, 0.9, 1.0, 1.0), Color(1.0, 0.9, 0.4, 1.0)]
	for i in 3:
		var sw := shader_swarm(root, "flies", 8, {"center": Vector3(0.3 * i - 0.3, 1.5, 0.3), "spread": Vector3(3.2, 0.9, 3.2), "col": cc[i], "size": 0.05})
		if i > 0:
			_hq_counts[sw] = 8


## Неон улицы: силуэт далёкого города с огоньками окон, неоновые трубки по забору и по краю крыши будки
func _light_neon(root: Node3D) -> void:
	var bl := []
	var win := []
	var wc := []
	var pal := [Color("#3FE0FF"), Color("#FF4FA3"), Color("#FFE27A"), Color("#B48CFF")]
	var i := 0
	var a := deg_to_rad(195.0)
	while a < deg_to_rad(345.0):
		var w := 0.9 + 1.2 * hash1(i, 501)
		var hh := 1.6 + 3.2 * hash1(i, 502)
		var rr := 15.5 + 1.5 * hash1(i, 503)
		var p := dir(a) * rr
		var b := Basis(Vector3.UP, face_center(a))
		bl.append(Transform3D(b * Basis.from_scale(Vector3(w, hh, 0.8)), p + Vector3(0, hh * 0.5 + 0.6, 0)))
		for row in int(hh / 0.55):
			for col in int(w / 0.4):
				if hash1(i * 31 + row * 7 + col, 504) < 0.45:
					continue
				var lp := Vector3((col + 0.5) * 0.4 - w * 0.5 + 0.0, 0.9 + row * 0.55, 0.42)
				win.append(Transform3D(b, p + b * lp))
				wc.append(pal[(i + row + col) % 4])
		a += (w + 0.3) / rr
		i += 1
	var bmi := scatter(root, box(Vector3(1, 1, 1)), mat(Color("#120C2A"), 1.0, 0.0, false), bl)
	bmi.extra_cull_margin = 30.0
	var wm := _shader_mat("pup_windows", PUP_WINDOWS)
	var wmi := _hq_scatter(root, quad(Vector2(0.22, 0.28)), wm, win, wc)
	wmi.extra_cull_margin = 30.0
	# неон по забору (розовый) и по фронтону будки (голубой)
	var pink := glow_mat(Color("#FF4FA3"), 2.6, true)
	var cyan := glow_mat(Color("#3FE0FF"), 2.6, true)
	var pts := []
	for k in 41:
		pts.append(dir(lerpf(FENCE_A0 + 0.02, FENCE_A1 - 0.02, k / 40.0)) * (FENCE_R - 0.1) + Vector3(0, 1.08, 0))
	put(root, tube(pts, 0.016, 0.016, 5), pink)
	put(root, tube([Vector3(-0.78, 0.86, 0.63), Vector3(0, 1.64, 0.63), Vector3(0.78, 0.86, 0.63)], 0.018, 0.018, 5), cyan)
	put(root, tube(_loop(Vector2(0, 0.42), Vector2(0.5, 0.53), 20).slice(0, 11), 0.015, 0.015, 5), pink, Vector3(0, 0.0, 0.69))
	var tw := node(root)
	anim(tw, "call", {"f": _a_neon_blink, "mats": [cyan, pink]})
	shader_swarm(root, "flies", 12, {"center": Vector3(0, 1.3, 0.4), "spread": Vector3(3.4, 0.8, 3.2), "col": Color(0.4, 0.95, 1.0, 1.0), "size": 0.045})
