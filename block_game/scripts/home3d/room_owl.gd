extends "res://scripts/home3d/room.gd"
## Дупло совёнка в 3D (развитие прототипа 0.11): круглая комната внутри дерева, стены — кора,
## пол — гнездо из соломы и мха, окно-дупло на ночное небо с луной, в центре гнездо героя.
## Ступени богатства (Meta.home_stage):
##   0 — простое дупло, немного светлячков;  1 — светящиеся грибы у стен, больше грибов-полочек;
##   2 — корешки с кристаллами под потолком;  3 — северное сияние в окне, кристаллы в коре, рой светлячков.

const R := 3.0
const WALL_H := 3.4
const TOP_H := 4.9
const WIN_ANG := -PI / 2.0
const WIN_Y := 2.15
const WIN_HALF_ANG := 0.33
const WIN_HALF_H := 0.78

## Готовые сетки стен и пола: считаются один раз за игру (дорого), дальше берутся из памяти
static var _geo := {}
## 0.15: что меняет стиль комнаты (стены / пол / свет)
var _leaves: MultiMeshInstance3D
var _sky: ShaderMaterial
var _warm: OmniLight3D
var _moon: SpotLight3D
var _style_nodes := {}


static func wall_r(y: float) -> float:
	if y <= WALL_H:
		return R * (1.0 + 0.04 * sin(y / WALL_H * PI) - 0.05 * y / WALL_H)
	var s := clampf((y - WALL_H) / (TOP_H - WALL_H), 0.0, 1.0)
	return R * 0.95 * sqrt(maxf(0.0, 1.0 - s * s))


func _init() -> void:
	kind = "owl"
	hang_style = "rope"
	rope_len = 0.55
	hero_feet = Vector3(0, 0.38, 0)
	# 0.15: 16 мест (типы — scripts/decor_data/owl.gd). Камера смотрит с +Z на окно (−Z); полка славы — у стены +Z.
	# Задняя дуга (видна сразу): окно, над окном — wall_back, по бокам — большие места, стены, пол, три подвеса;
	# передние боковые стены (видны при повороте) — полки-трутовики; пол спереди справа — floor_front.
	# [угол°, тип, радиус (пол/подвес) или 0 (стена), высота]
	var defs := {
		"floor_l": [195.0, "floor", 2.05, 0.0], "floor_r": [-15.0, "floor", 2.05, 0.0],
		"wall_l": [-151.0, "wall", 0.0, 1.55], "wall_r": [-29.0, "wall", 0.0, 1.55],
		"hang": [-62.0, "hang", 0.95, 3.62], "near": [28.0, "near", 1.12, 0.0],
		"window": [-90.0, "window", 0.0, 0.0],
		"big_back": [-127.0, "big", 2.2, 0.02], "big_corner": [-53.0, "big", 2.2, 0.02],
		"wall_back": [-90.0, "wall", 0.0, 3.12],
		"shelf_l": [158.0, "shelf", 0.0, 1.5], "shelf_r": [22.0, "shelf", 0.0, 1.5],
		"hang_l": [-150.0, "hang", 1.55, 3.5], "hang_r": [-10.0, "hang", 1.55, 3.5],
		"floor_front": [55.0, "floor", 1.95, 0.0], "near_2": [152.0, "near", 1.12, 0.0],
	}
	for s in defs:
		var d: Array = defs[s]
		var a := deg_to_rad(d[0])
		var k: String = d[1]
		var y: float = d[3]
		var sp := {"yaw": face_center(a), "mark": Vector3(0, 0.3, 0), "stand": Vector3(0, 0.07, 0.24)}
		match k:
			"wall", "shelf":
				sp.pos = dir(a) * (wall_r(y) - 0.04) + Vector3(0, y, 0)
				sp.mark = Vector3(0, 0.3, 0.32)
			"hang":
				sp.pos = dir(a) * d[2] + Vector3(0, y, 0)
				sp.mark = Vector3(0, -0.85, 0)
			"window":
				sp.pos = dir(a) * (wall_r(WIN_Y) - 0.22) + Vector3(0, WIN_Y - WIN_HALF_H + 0.11, 0)
				sp.mark = Vector3(0, 0.3, 0.1)
				sp.erase("stand")
			"big":
				sp.pos = dir(a) * d[2] + Vector3(0, y, 0)
				sp.mark = Vector3(0, 0.6, 0)
			_:
				sp.pos = dir(a) * d[2] + Vector3(0, y, 0)
		spots[s] = sp
	# 0.14: полка славы — на стене напротив окна (за спиной камеры в обычном обзоре; места украшений не занимает)
	shelf_def = {"style": "owl", "pos": dir(PI / 2.0) * R, "yaw": face_center(PI / 2.0), "room_r": R,
		"rows": [[1.2, wall_r(1.2) - 0.06], [1.78, wall_r(1.78) - 0.06]], "spacing": 0.42, "scale": 1.15, "depth": 0.34,
		"plaque_z": 0.205, "plaque_y": -0.03, "focus_d": 0.72, "view_d": 2.0}


## 0.15: угол места на полу/стене близко к углу a (украшения дома — грибы, мох, корни — их обходят)
func _near_spot(a: float, kinds: Array, tol: float) -> bool:
	for s in spots:
		if not kinds.has(Catalog.spot_kind(s, kind)):
			continue
		var p: Vector3 = spots[s].pos
		if Vector2(p.x, p.z).length() > 1.5 and absf(angle_difference(a, atan2(p.z, p.x))) < tol:
			return true
	return false


func _inside(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < R - 0.3 and p.y < TOP_H - 0.9 and p.y > 0.12


func _setup_camera(c: Camera3D) -> void:
	c.home_pivot = Vector3(0, 0.95, 0)
	c.home_dist = 2.45
	c.dist_max = 2.6


# ---------- Окружение ----------

func _environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#120B24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6E5AA8")
	env.ambient_light_energy = 0.42 + 0.06 * stage
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("#3A2766")
	env.fog_density = 0.045
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	world_env.environment = env
	add_child(world_env)


func _build_house(h: Node3D) -> void:
	_walls(h)
	_floor(h)
	_window(h)
	_nest(h)
	_details(h)
	# тёплый свет из глубины дупла (растёт со ступенью); он же даёт тени в высоком качестве
	var warm := omni(h, Vector3(0.6, 2.9, 1.2), Color("#FFB866"), 0.35 + 0.12 * stage, 5.0, "slow", true)
	shadow_light = warm
	_warm = warm
	_hang_roots(h)
	# светлячки
	shader_swarm(h, "flies", 8 + stage * 6, {"center": Vector3(0, 2.5, 0), "spread": Vector3(1.9, 0.9, 1.9)})


# ---------- Стены-кора ----------

func _walls(h: Node3D) -> void:
	if not _geo.has("walls"):
		_geo["walls"] = _wall_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["walls"]
	mi.material_override = vmat(0.95, 0.15)
	h.add_child(mi)
	wall_parts.append(mi)  # 0.15: стиль «стены» красит кору
	# грибы-трутовики на стенах — маленькие «полочки» для уюта (больше на поздних ступенях)
	# 0.15: грибы стоят между местами украшений (не налезают на полки, стены и большие вещи)
	var n_f := 3 if stage == 0 else 5
	for k in n_f:
		var a: float = deg_to_rad([48.0, 132.0, -172.0, -6.0, 64.0][k])
		var hy: float = [1.0, 1.0, 2.5, 2.45, 2.3][k]
		var f := node(h, dir(a) * (wall_r(hy) - 0.02) + Vector3(0, hy, 0), face_center(a))
		for q in 2:
			var off := Vector3((q - 0.5) * 0.22, -q * 0.16, 0)
			var sz := 1.0 - q * 0.3
			put(f, sphere(0.2 * sz, 16), mat(Color("#C98A5C"), 0.9), off + Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.3, 0.5, 0.9))
			put(f, sphere(0.19 * sz, 16), mat(Color("#F2D7A8"), 0.9, 0.0, false), off + Vector3(0, 0.035, 0), Vector3.ZERO, Vector3(1.3, 0.36, 0.88))
	# сучки-дупляшки в коре
	for k in 3:
		var a: float = [WIN_ANG + 1.5, WIN_ANG + 4.0, WIN_ANG + 5.0][k]
		var hy: float = [2.9, 1.8, 3.1][k]
		var f := node(h, dir(a) * (wall_r(hy) - 0.03) + Vector3(0, hy, 0), face_center(a))
		put(f, torus(0.07, 0.15, 18), mat(Color("#8A5A44"), 0.9), Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 1.4))
		put(f, sphere(0.08, 12), mat(Color("#2A1620"), 1.0, 0.0, false), Vector3(0, 0, -0.02), Vector3.ZERO, Vector3(1.0, 1.4, 0.4))


func _wall_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_seg := 150
	var ys := []
	var y := -0.05
	while y < WALL_H:
		ys.append(y)
		y += 0.13
	for j in 10:
		ys.append(WALL_H + (TOP_H - WALL_H) * sin((j + 1) / 10.0 * PI / 2.0))
	var dark := Color("#3E2620")
	var mid := Color("#6B4433")
	var light := Color("#93644A")
	var grid := []
	var cols := []
	for j in ys.size():
		var row := []
		var crow := []
		var yy: float = ys[j]
		for i in n_seg + 1:
			var a := TAU * i / n_seg
			var w := sin(a * 41.0 + 1.3 * sin(yy * 1.4 + a * 5.0) + 0.6 * sin(yy * 3.1 + a * 2.0)) * 0.75 + 0.25 * sin(a * 97.0 + yy * 2.0)
			var ridge := signf(w) * pow(absf(w), 0.55)
			var crack := smoothstep(0.82, 1.0, sin(yy * 6.5 + a * 9.0 + 2.0 * sin(a * 3.0))) * smoothstep(0.0, 0.6, ridge)
			var r := wall_r(yy) * (1.0 + (0.028 * ridge - 0.012 * crack) * clampf(1.0 - (yy - WALL_H) / 1.2, 0.0, 1.0))
			row.append(Vector3(cos(a) * r, yy, sin(a) * r))
			var c := dark.lerp(mid, smoothstep(-0.7, 0.1, ridge)).lerp(light, smoothstep(0.5, 1.0, ridge) * 0.8)
			c = c.lerp(dark, crack * 0.8)
			var moss := clampf(1.0 - yy / 0.45, 0.0, 1.0) * (0.55 + 0.45 * sin(a * 5.0 + 1.3))
			c = c.lerp(Color("#4E7A3E"), clampf(moss, 0.0, 0.8))
			c = c.darkened(clampf((yy - 2.6) / 3.0, 0.0, 0.45))
			if i == n_seg:
				c = crow[0]
			crow.append(c)
		grid.append(row)
		cols.append(crow)
	for j in ys.size() - 1:
		for i in n_seg:
			var a0 := TAU * (i + 0.5) / n_seg
			var yc: float = (ys[j] + ys[j + 1]) * 0.5
			var da := angle_difference(a0, WIN_ANG) / WIN_HALF_ANG
			var dy := (yc - WIN_Y) / WIN_HALF_H
			if da * da + dy * dy < 1.0:
				continue
			var A: Vector3 = grid[j][i]
			var B: Vector3 = grid[j][i + 1]
			var C: Vector3 = grid[j + 1][i + 1]
			var D: Vector3 = grid[j + 1][i]
			var inward := -Vector3(cos(a0), 0, sin(a0))
			tri(st, A, D, C, inward, cols[j][i], cols[j + 1][i], cols[j + 1][i + 1])
			tri(st, A, C, B, inward, cols[j][i], cols[j + 1][i + 1], cols[j][i + 1])
	st.index()
	st.generate_normals()
	return st.commit()


# ---------- Пол-гнездо ----------

func _floor(h: Node3D) -> void:
	if not _geo.has("floor"):
		_geo["floor"] = _floor_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["floor"]
	mi.material_override = vmat(1.0, 0.1)
	h.add_child(mi)
	floor_parts.append(mi)  # 0.15: стиль «пол»
	# опавшие листики по полу (MultiMesh — дёшево)
	var xfs := []
	var leaf_cols := [Color("#C98A3E"), Color("#B5603A"), Color("#D6AE55"), Color("#7FA552"), Color("#A85A5E")]
	for i in 55:
		var a := hash1(i, 1) * TAU
		var rr := 1.05 + hash1(i, 2) * 1.55
		var b := Basis(Vector3.UP, hash1(i, 3) * TAU) * Basis(Vector3.RIGHT, 0.15 * (hash1(i, 4) - 0.5)) * Basis.from_scale(Vector3(0.6, 0.12, 1.0) * (0.8 + 0.5 * hash1(i, 6)))
		xfs.append(Transform3D(b, dir(a) * rr + Vector3(0, 0.025 + 0.18 * pow(rr / R, 4.0), 0)))
	_leaves = scatter(h, sphere(0.05, 8), vmat(0.9, 0.2), xfs, leaf_cols)
	# мягкие кочки мха у стен
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		if _near_spot(a, ["floor", "big"], 0.38):
			continue
		var p := dir(a) * (R - 0.35) + Vector3(0, 0.12, 0)
		put(h, sphere(0.32, 14), mat(Color("#5E9A4A"), 1.0, 0.0, false), p, Vector3.ZERO, Vector3(1.0, 0.45, 0.8))
		put(h, sphere(0.2, 12), mat(Color("#77B65A"), 1.0, 0.0, false), p + Vector3(0.15, 0.08, 0.1), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))


func _floor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var segs := 64
	var pts := []
	var cols := []
	for j in rings + 1:
		var rr := (R + 0.15) * j / rings
		var row := []
		var crow := []
		for i in segs + 1:
			var a := TAU * i / segs
			var hh := 0.0
			if j > 0:
				hh = 0.03 * sin(a * 7.0 + j * 1.3) * sin(j * 0.9) + 0.18 * pow(float(j) / rings, 4.0)
			row.append(Vector3(cos(a) * rr, hh, sin(a) * rr))
			var straw := Color("#B88A56").lerp(Color("#D9B276"), 0.5 + 0.5 * sin(a * 9.0 + j * 2.1))
			var moss := smoothstep(0.65, 1.0, float(j) / rings) * (0.5 + 0.5 * sin(a * 4.0 + 0.7))
			var c := straw.lerp(Color("#5E8E45"), moss * 0.85)
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
	st.index()
	st.generate_normals()
	return st.commit()


# ---------- Окно-дупло с ночным небом ----------

func _window(h: Node3D) -> void:
	var out := dir(WIN_ANG)
	var yaw := face_center(WIN_ANG)
	var wr := wall_r(WIN_Y)
	var rim := put(h, torus(0.86, 1.12, 40), mat(Color("#7B5141"), 0.9), out * (wr * 0.975) + Vector3(0, WIN_Y, 0))
	rim.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(WIN_HALF_ANG * wr + 0.04, 1.0, WIN_HALF_H + 0.04))
	put(h, sphere(0.5, 16), mat(Color("#8E5E46"), 0.9), out * (wr - 0.12) + Vector3(0, WIN_Y - WIN_HALF_H + 0.02, 0), Vector3(0, yaw, 0), Vector3(1.55, 0.2, 0.7))
	var sky := Shaders.material("window_sky", {"aurora": 1.0 if stage >= 3 else 0.0, "cave": 0.0})
	_sky = sky
	var sk := put(h, quad(Vector2(6.0, 4.6)), sky, out * (R + 2.4) + Vector3(0, WIN_Y + 0.6, 0))
	sk.rotation.y = yaw
	var moon_p := out * (R + 2.0) + Vector3(0, WIN_Y + 0.42, 0) + dir(WIN_ANG + PI / 2.0) * 0.45
	put(h, sphere(0.36, 24), mat(Color("#FFF3C9"), 1.0, 1.6, false), moon_p)
	for cr in [[Vector3(-0.12, 0.1, 0.0), 0.08], [Vector3(0.1, -0.1, 0.0), 0.06]]:
		var cp: Vector3 = moon_p - out * 0.3 + Basis(Vector3.UP, yaw) * (cr[0] as Vector3)
		put(h, sphere(cr[1], 10), mat(Color("#EFDDA0"), 1.0, 1.2, false), cp, Vector3.ZERO, Vector3(1, 1, 0.4))
	halo(h, moon_p - out * 0.05, 2.2, Color(1.0, 0.92, 0.65, 0.35))
	for i in 7:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := out * (R + 0.5 + hash1(i, 2) * 0.6) + Vector3(0, WIN_Y + 0.9 - hash1(i, 1) * 0.6, 0) + dir(WIN_ANG + PI / 2.0) * side * (0.7 + hash1(i, 3) * 0.6)
		put(h, sphere(0.35 + hash1(i, 4) * 0.25, 12), mat(Color("#1F4C40").lerp(Color("#27604C"), hash1(i, 5)), 1.0, 0.0, false), p, Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	# плющ над окном
	for i in 9:
		var s := i / 8.0
		var p := out * (wr - 0.18) + Vector3(0, WIN_Y + WIN_HALF_H + 0.1 - sin(s * PI) * 0.25, 0) + dir(WIN_ANG + PI / 2.0) * lerpf(-0.95, 0.95, s)
		put(h, sphere(0.085, 8), mat(Color("#3FAF6E")), p, Vector3(0.3 * i, yaw, 0.5), Vector3(1.0, 0.45, 0.7))
	# лунный луч из окна на пол
	var moon_light := SpotLight3D.new()
	moon_light.light_color = Color("#9DB4FF")
	moon_light.light_energy = 2.0
	moon_light.spot_range = 7.0
	moon_light.spot_angle = 24.0
	moon_light.spot_attenuation = 0.6
	moon_light.position = out * (R + 0.8) + Vector3(0, WIN_Y + 1.1, 0)
	h.add_child(moon_light)
	_moon = moon_light
	moon_light.look_at_from_position(moon_light.position, Vector3(0.3, 0.0, 0.4) - out * 0.3, Vector3.UP)
	features.append([out * (wr - 0.1) + Vector3(0, WIN_Y, 0), 1.7, "window"])


# ---------- Гнездо в центре ----------

func _nest(h: Node3D) -> void:
	# вязаный коврик под гнездом — с первой ступени
	if stage >= 1:
		var rug_cols := [Color("#7A4E62"), Color("#A9735A"), Color("#C28C66"), Color("#9A6A8A")]
		for k in rug_cols.size():
			var rr := 1.3 - k * 0.1
			put(h, cyl(rr, rr + 0.02, 0.05, 48), mat(rug_cols[k], 1.0, 0.0, k == 0), Vector3(0, 0.035 + k * 0.004, 0))
		var tassels := []
		for k in 24:
			var a := TAU * k / 24.0
			tassels.append(Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(1.0, 0.6, 1.0)), dir(a) * 1.35 + Vector3(0, 0.035, 0)))
		scatter(h, sphere(0.04, 8), mat(Color("#E0B07A"), 1.0, 0.0, false), tassels)
	var n := node(h)
	casters.append(n)
	put(n, torus(0.38, 0.8, 36), mat(Color("#9A6E42"), 1.0), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	put(n, cyl(0.5, 0.45, 0.16, 24), mat(Color("#7A5233"), 1.0, 0.0, false), Vector3(0, 0.1, 0))
	put(n, sphere(0.44, 20), mat(Color("#D8C0A6"), 1.0), Vector3(0, 0.26, 0), Vector3.ZERO, Vector3(1.0, 0.32, 1.0))
	for k in 3:
		put(n, sphere(0.06, 10), mat(Color("#FFF6EA"), 1.0, 0.0, false), Vector3(cos(k * 2.1) * 0.32, 0.38, sin(k * 2.1) * 0.3), Vector3(0.2, k * 1.3, 0.3), Vector3(0.45, 0.22, 1.3))
	var xfs := []
	var cols := []
	for i in 110:
		var a := hash1(i, 7) * TAU
		var phi := lerpf(-0.6, 2.4, hash1(i, 8))
		var p := dir(a) * (0.59 + cos(phi) * 0.215) + Vector3(0, 0.2 + sin(phi) * 0.17, 0)
		var tangent := Vector3(-sin(a), 0, cos(a))
		var tilt := (hash1(i, 10) - 0.5) * 0.7
		var fwd := (tangent + Vector3(0, tilt, 0)).normalized()
		var b := Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		xfs.append(Transform3D(b, p))
		cols.append(Color("#E0B474").lerp(Color("#7A5141"), hash1(i, 12)))
	scatter(n, cyl(0.016, 0.016, 0.42, 5), vmat(1.0, 0.1), xfs, cols)
	put(n, sphere(0.09, 10), mat(Color("#F7F0FF")), Vector3(0.5, 0.42, 0.42), Vector3(0.3, 0.6, 0.9), Vector3(0.5, 0.25, 1.4))


# ---------- Детали по ступеням ----------

func _details(h: Node3D) -> void:
	# корни, выходящие из стен по полу
	for i in 5:
		var a := deg_to_rad([-90.0, 14.0, 96.0, 126.0, -38.0][i])  # 0.15: мимо мест на полу
		var base := dir(a) * (R - 0.15)
		var pts := bez(base + Vector3(0, 0.25, 0), dir(a + 0.1) * (R - 0.7) + Vector3(0, 0.1, 0), dir(a + 0.18) * (R - 1.15) + Vector3(0, 0.03, 0))
		put(h, tube(pts, 0.12, 0.035, 9), mat(Color("#6B4433"), 0.95))
	if stage >= 1:
		# светящиеся грибочки у подножия стен
		for i in 4:
			var a := WIN_ANG + 1.4 + i * 1.2
			var g := node(h, dir(a) * (wall_r(0.2) - 0.35) + Vector3(0, 0.12, 0), face_center(a))
			for k in 3:
				var kk := 0.45 + 0.25 * hash1(i * 3 + k, 51)
				_mushroom(g, Vector3((k - 1) * 0.14, 0, hash1(i + k, 52) * 0.1), kk, [Color("#7FF5E0"), Color("#C38BFF"), Color("#FFB547")][(i + k) % 3])
			halo(g, Vector3(0, 0.2, 0.05), 0.8, Color(0.6, 0.9, 1.0, 0.22))
		omni(h, dir(WIN_ANG + 3.2) * 2.0 + Vector3(0, 0.4, 0), Color("#8FE6FF"), 0.5, 2.6, "pulse")
	if stage >= 2:
		# корешки с кристаллами свисают с потолка
		var gem_cols := [Color("#B46CFF"), Color("#3FD0FF"), Color("#3DDC97"), Color("#FF8FD8"), Color("#FFD34D")]
		for i in 5:
			var a := WIN_ANG + 0.9 + i * 1.15
			var rr := 1.7 + hash1(i, 41) * 0.5
			var top := dir(a) * rr + Vector3(0, 3.75, 0)
			var ln := 0.55 + hash1(i, 42) * 0.5
			var prev := top
			var chain := [top]
			for k in 4:
				prev = prev + Vector3(sin(i + k * 1.7) * 0.05, -ln / 4.0, cos(i * 2.0 + k) * 0.05)
				chain.append(prev)
			put(h, tube(chain, 0.03, 0.015, 5), mat(Color("#7A5141"), 0.95, 0.0, false))
			var c: Color = gem_cols[i]
			var g := crystal(h, prev + Vector3(0, -0.02, 0), 0.2, 0.05, Vector3(PI, 0, 0), c, 1.0)
			anim(g, "pulse", {"p": float(i)})
			halo(h, prev + Vector3(0, -0.1, 0), 0.5, Color(c, 0.35))
	if stage >= 3:
		# кристаллы, проросшие в коре
		var cc := [Color("#B46CFF"), Color("#3FD0FF"), Color("#FF8FD8"), Color("#3DDC97")]
		for i in 5:
			var a := deg_to_rad([-178.0, 40.0, 66.0, 118.0, 140.0][i])
			var hy := 0.6 + hash1(i, 61) * 2.2
			var p := dir(a) * (wall_r(hy) - 0.04) + Vector3(0, hy, 0)
			var g := node(h, p, face_center(a))
			crystal_cluster(g, Vector3.ZERO, 0.55, cc[i % 4], 1.1, i)
			g.rotation.x = 1.2
			halo(h, p - dir(a) * 0.12, 0.6, Color(cc[i % 4], 0.3))
		# звёздочки «из картона» на нитках под сводом — мерцают
		for i in 7:
			var a := TAU * i / 7.0 + 0.4
			var rr := 0.9 + 0.7 * hash1(i, 71)
			var top := dir(a) * rr + Vector3(0, 3.9, 0)
			var ln := 0.5 + 0.6 * hash1(i, 72)
			put(h, cyl(0.005, 0.005, ln, 3), mat(Color("#C9B88A"), 1.0, 0.0, false), top - Vector3(0, ln * 0.5, 0))
			var st := put(h, extrude(star_poly(0.09, 0.04), 0.03), glow_mat(Color("#FFE58A"), 1.6, true), top - Vector3(0, ln + 0.08, 0))
			anim(st, "spin", {"spd": 0.6 + 0.3 * hash1(i, 73), "p": float(i)})
			var sb := st
			anim(sb, "bulb", {"p": float(i) * 2.0, "e0": 1.4, "e1": 0.8, "spd": 1.3})
			halo(h, top - Vector3(0, ln + 0.08, 0), 0.45, Color(1.0, 0.9, 0.5, 0.3))


func _mushroom(parent: Node3D, pos: Vector3, k: float, col: Color) -> void:
	put(parent, cyl(0.045 * k, 0.06 * k, 0.26 * k, 10), mat(Color("#F2E8FF")), pos + Vector3(0, 0.13 * k, 0))
	put(parent, hemi(0.16 * k, 18), mat(col, 0.5, 0.7), pos + Vector3(0, 0.25 * k, 0), Vector3.ZERO, Vector3(1, 2.2, 1))
	for i in 4:
		var a := i * 1.7
		put(parent, sphere(0.022 * k, 6), mat(Color.WHITE, 0.8, 0.6, false), pos + Vector3(cos(a) * 0.09 * k, 0.32 * k, sin(a) * 0.09 * k))


## Полочка на стене — гриб-трутовик
func _ledge(n: Node3D, _spot: String) -> void:
	put(n, sphere(0.42, 20), mat(Color("#E9C79A")), Vector3(0, 0, 0.18), Vector3.ZERO, Vector3(1.2, 0.18, 0.8))
	put(n, sphere(0.4, 20), mat(Color("#C98A5C"), 0.9, 0.0, false), Vector3(0, -0.025, 0.17), Vector3.ZERO, Vector3(1.22, 0.12, 0.82))


# ---------- Украшения ----------

func _decor(id: String, n: Node3D, sk: String) -> void:
	match id:
		"owl_nest": _d_nest(n)
		"owl_lantern": _d_lantern(n)
		"owl_garland": _d_garland(n)
		"owl_mushrooms": _d_mushrooms(n)
		"owl_birdhouse": _d_birdhouse(n)
		"owl_books": _d_books(n)
		"owl_swing": _d_swing(n)
		"owl_hammock": _d_hammock(n, sk)
		"owl_moon": _d_moon(n)
		"owl_nightlight": _d_nightlight(n)
		_: _new_decor(id, n, sk)


## Гнёздышко-коврик с яичком (яичко иногда покачивается)
func _d_nest(n: Node3D) -> void:
	put(n, cyl(0.36, 0.38, 0.04, 32), mat(Color("#B98A52"), 1.0), Vector3(0, 0.02, 0))
	put(n, torus(0.2, 0.36, 28), mat(Color("#C99A5C"), 1.0), Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	put(n, cyl(0.24, 0.24, 0.05, 24), mat(Color("#F4E6D2"), 1.0, 0.0, false), Vector3(0, 0.06, 0))
	var xfs := []
	for i in 40:
		var a := hash1(i, 3) * TAU
		var p := dir(a) * (0.28 + 0.05 * hash1(i, 4)) + Vector3(0, 0.08 + 0.05 * hash1(i, 5), 0)
		xfs.append(Transform3D(Basis.looking_at(Vector3(-sin(a), (hash1(i, 6) - 0.5) * 0.8, cos(a)).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0), p))
	scatter(n, cyl(0.01, 0.01, 0.2, 4), vmat(1.0, 0.1), xfs, [Color("#E0B474"), Color("#9A6E42"), Color("#C59A5C")])
	var egg := node(n, Vector3(0.02, 0.09, 0))
	put(egg, sphere(0.09, 18), mat(Color("#F7F0FF"), 0.6), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(0.85, 1.15, 0.85))
	for i in 5:
		put(egg, sphere(0.014, 6), mat(Color("#9FC8FF"), 0.8, 0.0, false), Vector3(cos(i * 1.3) * 0.07, 0.07 + i * 0.022, sin(i * 1.3) * 0.07))
	anim(egg, "call", {"f": _egg_wobble})
	put(n, sphere(0.07, 10), mat(Color("#F3D6FF")), Vector3(-0.2, 0.1, 0.12), Vector3(0.3, 0.6, 0.9), Vector3(0.5, 0.22, 1.5))


func _d_lantern(n: Node3D) -> void:
	var frame := mat(Color("#3A2A55"), 0.6)
	put(n, cyl(0.17, 0.2, 0.07, 16), frame, Vector3(0, 0.035, 0))
	put(n, cyl(0.15, 0.15, 0.34, 16), glass(Color(1.0, 0.86, 0.45, 0.5), 1.2), Vector3(0, 0.24, 0))
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		put(n, cyl(0.016, 0.016, 0.36, 6), frame, Vector3(cos(a) * 0.155, 0.24, sin(a) * 0.155))
	put(n, cyl(0.02, 0.21, 0.13, 16), frame, Vector3(0, 0.47, 0))
	put(n, torus(0.06, 0.09, 16), frame, Vector3(0, 0.58, 0), Vector3(PI / 2.0, 0, 0))
	var flame := put(n, sphere(0.06, 12), glow_mat(Color("#FFE27A"), 4.0), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
	anim(flame, "flame")
	# светлячки внутри фонарика (как в 2D)
	for i in 3:
		var f := put(n, sphere(0.014, 6), glow_mat(Color("#FFFBC0"), 3.0), Vector3(0.06, 0.24, 0))
		anim(f, "orbit", {"r": 0.07, "spd": 1.6 + i * 0.4, "p": i * 2.1})
	omni(n, Vector3(0, 0.26, 0), Color("#FFB866"), 1.2, 3.6, "flicker")
	halo(n, Vector3(0, 0.25, 0), 0.9, Color(1.0, 0.8, 0.4, 0.4))


func _d_garland(n: Node3D) -> void:
	var pts := []
	for i in 41:
		var s := i / 40.0
		pts.append(Vector3(lerpf(-0.95, 0.95, s), -sin(s * PI) * 0.4, 0.0))
	put(n, tube(pts, 0.014, 0.014, 5), mat(Color("#3E9E62"), 0.9, 0.0, false))
	var cols := [Color("#FF4D6D"), Color("#FFD34D"), Color("#B46CFF"), Color("#7FE3FF"), Color("#FF8FD8")]
	var caps := []
	var k := 0
	for i in range(3, 40, 4):
		var p: Vector3 = pts[i] + Vector3(0, -0.07, 0)
		var b := put(n, sphere(0.05, 10), glow_mat(cols[k % cols.size()], 2.2, true), p, Vector3.ZERO, Vector3(1, 1.25, 1))
		anim(b, "bulb", {"p": float(k)})
		caps.append(Transform3D(Basis(), p + Vector3(0, 0.065, 0)))
		k += 1
	scatter(n, cyl(0.025, 0.025, 0.03, 8), mat(Color("#3A2A55"), 0.6, 0.0, false), caps)
	var leaves := []
	for i in range(0, 41, 2):
		leaves.append(Transform3D(Basis.from_euler(Vector3(0.3 * i, 0.7 * i, 0.2)) * Basis.from_scale(Vector3(1.0, 0.4, 0.6)), (pts[i] as Vector3) + Vector3(0, 0.02, 0)))
	scatter(n, sphere(0.05, 8), mat(Color("#5BC27E"), 0.9, 0.0, false), leaves)
	for x in [-0.95, 0.95]:
		put(n, sphere(0.05, 8), mat(Color("#9A6A44")), Vector3(x, 0, 0))
	anim(n, "pendulum", {"amp": 0.03, "spd": 0.9})


func _d_mushrooms(n: Node3D) -> void:
	_mushroom(n, Vector3(-0.18, 0, 0.02), 0.85, Color("#7FF5E0"))
	_mushroom(n, Vector3(0.14, 0, -0.06), 1.2, Color("#C38BFF"))
	_mushroom(n, Vector3(0.02, 0, 0.18), 0.65, Color("#FFB547"))
	omni(n, Vector3(0, 0.45, 0.2), Color("#B88BFF"), 0.8, 2.2, "pulse")
	halo(n, Vector3(0, 0.3, 0), 1.0, Color(0.75, 0.55, 1.0, 0.28))


func _d_birdhouse(n: Node3D) -> void:
	put(n, cyl(0.04, 0.05, 0.3, 8), mat(Color("#6B4433")), Vector3(0, 0.12, 0.12), Vector3(PI / 2.0, 0, 0))
	var body := node(n, Vector3(0, 0.48, 0.25))
	put(body, box(Vector3(0.42, 0.46, 0.38)), mat(Color("#E7B26A"), 0.8))
	put(body, prism(Vector3(0.6, 0.3, 0.46)), mat(Color("#E0556F"), 0.7), Vector3(0, 0.38, 0))
	put(body, cyl(0.085, 0.085, 0.04, 16), mat(Color("#2A1A3A"), 1.0, 0.0, false), Vector3(0, 0.04, 0.19), Vector3(PI / 2.0, 0, 0))
	put(body, cyl(0.015, 0.015, 0.16, 6), mat(Color("#8A5A3A")), Vector3(0, -0.12, 0.24), Vector3(PI / 2.0, 0, 0))
	# птенчик выглядывает из круглого входа
	var chick := node(body, Vector3(0, 0.04, 0.16))
	put(chick, sphere(0.07, 14), mat(Color("#FFD86B"), 0.7), Vector3.ZERO)
	put(chick, prism(Vector3(0.04, 0.035, 0.04)), mat(Color("#FF8A3D"), 0.6, 0.0, false), Vector3(0, -0.01, 0.07), Vector3(-PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		put(chick, sphere(0.013, 6), mat(OUT, 0.5, 0.0, false), Vector3(sx * 0.03, 0.02, 0.06))
	anim(chick, "peek", {"h": 0.09, "spd": 0.55})
	put(body, sphere(0.035, 8), glow_mat(Color("#FFE27A"), 3.0), Vector3(0.12, 0.5, 0.05))


func _d_books(n: Node3D) -> void:
	var cols := [Color("#E0556F"), Color("#5FC8FF"), Color("#FFD34D"), Color("#3DDC97")]
	var x := -0.3
	for i in 4:
		var hh: float = [0.3, 0.26, 0.32, 0.22][i]
		var w: float = [0.08, 0.07, 0.09, 0.075][i]
		var tilt := 0.0 if i < 3 else -0.35
		put(n, box(Vector3(w, hh, 0.2)), mat(cols[i], 0.7), Vector3(x + w * 0.5 + (0.04 if i == 3 else 0.0), hh * 0.5, 0), Vector3(0, 0, tilt))
		put(n, box(Vector3(w * 0.7, 0.02, 0.202)), mat(Color(1, 1, 1), 0.7, 0.0, false), Vector3(x + w * 0.5 + (0.04 if i == 3 else 0.0), hh * 0.75, 0), Vector3(0, 0, tilt))
		x += w + 0.01
	put(n, cyl(0.04, 0.045, 0.14, 12), mat(Color("#FFF3E0")), Vector3(0.2, 0.07, 0.02))
	var fl := put(n, sphere(0.03, 10), glow_mat(Color("#FFD34D"), 5.0), Vector3(0.2, 0.18, 0.02), Vector3.ZERO, Vector3(1, 1.6, 1))
	anim(fl, "flame", {"p": 1.3})
	halo(n, Vector3(0.2, 0.19, 0.02), 0.45, Color(1.0, 0.75, 0.35, 0.45))


func _d_swing(n: Node3D) -> void:
	var sw := node(n)
	anim(sw, "swing", {"amp": 0.22, "spd": 1.5})
	var rope := mat(Color("#C9B88A"), 1.0, 0.0, false)
	var L := 1.05
	for sx in [-0.28, 0.28]:
		put(sw, cyl(0.01, 0.01, L, 4), rope, Vector3(sx, -L * 0.5, 0))
		put(n, sphere(0.04, 8), mat(Color("#9A6A44")), Vector3(sx, 0, 0))
	put(sw, box(Vector3(0.72, 0.05, 0.22)), mat(Color("#9A6A44"), 0.8), Vector3(0, -L, 0))
	for sx in [-0.28, 0.28]:
		put(sw, sphere(0.07, 10), mat(Color("#3FAF6E")), Vector3(sx, -L + 0.05, 0), Vector3(0, 0.5, 0), Vector3(1.2, 0.5, 0.8))
	# подушечка на сиденье
	put(sw, sphere(0.14, 14), mat(Color("#F3D6FF"), 1.0), Vector3(0, -L + 0.07, 0), Vector3.ZERO, Vector3(1.4, 0.35, 0.9))


## Гамак: на полу — между двумя столбиками; на стене — на двух колышках
func _d_hammock(n: Node3D, sk: String) -> void:
	var w := 0.72
	var top := 0.66
	var z := 0.0 if sk != "wall" else 0.22
	if sk == "wall":
		for sx in [-w, w]:
			put(n, cyl(0.03, 0.035, 0.26, 8), mat(Color("#7A5141")), Vector3(sx, top, 0.1), Vector3(PI / 2.0, 0, 0))
	else:
		for sx in [-w, w]:
			put(n, cyl(0.04, 0.05, top + 0.08, 10), mat(Color("#7A5141")), Vector3(sx, (top + 0.08) * 0.5, 0))
			put(n, sphere(0.05, 10), mat(Color("#9A6A44")), Vector3(sx, top + 0.1, 0))
	var hm := node(n, Vector3(0, top, z))
	anim(hm, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.12, "spd": 1.1})
	hm.add_child(_cloth_mesh(w * 2.0, 0.5, 0.36))
	put(hm, sphere(0.1, 12), mat(Color("#F3D6FF")), Vector3(-0.3, -0.18, 0), Vector3(0, 0, -0.2), Vector3(1.4, 0.6, 1.0))
	for sx in [-1.0, 1.0]:
		var pts := [Vector3(sx * w, 0, 0), Vector3(sx * (w - 0.08), -0.04, 0.12), Vector3(sx * (w - 0.08), -0.04, -0.12)]
		put(hm, tube([pts[0], pts[1]], 0.006, 0.006, 4), mat(Color("#C9B88A"), 1.0, 0.0, false))
		put(hm, tube([pts[0], pts[2]], 0.006, 0.006, 4), mat(Color("#C9B88A"), 1.0, 0.0, false))


## Ткань гамака: провисающая полоса с полосками (двусторонняя)
func _cloth_mesh(w: float, d: float, sag: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 16
	var nz := 4
	var rows := []
	for i in nx + 1:
		var s := float(i) / nx
		var row := []
		for j in nz + 1:
			var u := float(j) / nz
			var x := lerpf(-w * 0.5 + 0.08, w * 0.5 - 0.08, s)
			var y := -sin(s * PI) * sag - sin(u * PI) * 0.04 * sin(s * PI)
			var zz := lerpf(-d * 0.5, d * 0.5, u) * (0.35 + 0.65 * sin(s * PI))
			row.append(Vector3(x, y, zz))
		rows.append(row)
	for i in nx:
		var c := Color("#3FAF6E") if (i / 2) % 2 == 0 else Color("#8FE0A8")
		for j in nz:
			var A: Vector3 = rows[i][j]
			var B: Vector3 = rows[i + 1][j]
			var C: Vector3 = rows[i + 1][j + 1]
			var D: Vector3 = rows[i][j + 1]
			tri(st, A, B, C, Vector3.UP, c, c, c)
			tri(st, A, C, D, Vector3.UP, c, c, c)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi


func _d_moon(n: Node3D) -> void:
	var rope := mat(Color("#C9B88A"), 1.0, 0.0, false)
	put(n, cyl(0.008, 0.008, 0.3, 4), rope, Vector3(0, -0.15, 0))
	var sw := node(n, Vector3(0, -0.3, 0))
	anim(sw, "call", {"f": _mobile_turn})
	put(sw, cyl(0.025, 0.025, 1.0, 8), mat(Color("#9A6A44")), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	put(sw, cyl(0.006, 0.006, 0.36, 4), rope, Vector3(0, -0.18, 0))
	var moon := put(sw, extrude(crescent_poly(0.26), 0.08), mat(Color("#FFE58A"), 0.6, 0.6), Vector3(0, -0.6, 0))
	anim(moon, "wiggle", {"amp": 0.5, "spd": 0.9})
	halo(sw, Vector3(0, -0.6, 0), 0.9, Color(1.0, 0.92, 0.6, 0.25))
	for s in [[-0.45, 0.42, 0.13], [0.45, 0.3, 0.1]]:
		put(sw, cyl(0.006, 0.006, s[1], 4), rope, Vector3(s[0], -s[1] * 0.5, 0))
		var st := put(sw, extrude(star_poly(s[2], s[2] * 0.45), 0.06), mat(Color("#FFD34D"), 0.6, 0.7), Vector3(s[0], -s[1] - s[2], 0))
		anim(st, "wiggle", {"amp": 0.5, "spd": 0.9, "p": s[0] * 3.0})


func _d_nightlight(n: Node3D) -> void:
	put(n, cyl(0.26, 0.3, 0.1, 20), mat(Color("#4A3B6B"), 0.7), Vector3(0, 0.05, 0))
	var g := node(n)
	crystal(g, Vector3(0, 0.08, 0), 0.62, 0.09, Vector3.ZERO, Color("#8FEFFF"), 0.9)
	crystal(g, Vector3(-0.12, 0.08, 0.02), 0.4, 0.07, Vector3(0, 0, 0.35), Color("#6FD8FF"), 0.8)
	crystal(g, Vector3(0.12, 0.08, -0.02), 0.46, 0.075, Vector3(0.1, 0, -0.3), Color("#B48CFF"), 0.8)
	anim(g, "pulse")
	omni(n, Vector3(0, 0.45, 0.1), Color("#7FE3FF"), 1.1, 2.8, "pulse")
	halo(n, Vector3(0, 0.4, 0), 1.2, Color(0.5, 0.9, 1.0, 0.3))


func _egg_wobble(nd: Node3D, t: float, a: Dictionary) -> void:
	var w := sin(t * 9.0) * 0.18 * clampf(sin(t * 0.6) * 4.0 - 3.0, 0.0, 1.0)
	nd.transform = Transform3D(Basis(Vector3.BACK, w), a.base.origin)


func _mobile_turn(nd: Node3D, t: float, a: Dictionary) -> void:
	nd.transform = Transform3D(Basis.from_euler(Vector3(0.05 * sin(t * 0.8), t * 0.25, 0.06 * sin(t * 1.1))), a.base.origin)


# ---------- 0.15: сучки-корешки на своде (точки подвеса мест «сверху») ----------

func _hang_roots(h: Node3D) -> void:
	for s in spots:
		if Catalog.spot_kind(s, kind) != "hang":
			continue
		var p: Vector3 = spots[s].pos
		var rr := Vector2(p.x, p.z).length()
		var top_y := WALL_H + (TOP_H - WALL_H) * sqrt(maxf(0.0, 1.0 - pow(rr / (R * 0.95), 2.0))) + 0.1
		var side := Vector3(p.z, 0, -p.x).normalized() * 0.12 if rr > 0.2 else Vector3(0.12, 0, 0)
		var pts := bez(Vector3(p.x, top_y, p.z) + side, p + Vector3(0, (top_y - p.y) * 0.5, 0) - side, p + Vector3(0, 0.04, 0), 8)
		vp(h, ptube(pts, 0.07, 0.035, 6), Color("#6B4433"))
		vp(h, sphere(0.06, 10), Color("#7A5141"), p + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.2))
		vp(h, sphere(0.045, 8), Color("#5E9A4A"), p + Vector3(0.05, 0.08, 0.02), Vector3.ZERO, Vector3(1.4, 0.6, 1.0), false)


# ---------- 0.15: стиль комнаты (стены / пол / свет) ----------
## Стены и пол: свой шейдер поверх цвета коры / соломы (узор считается на видеокарте, сетка та же).
## Первый (бесплатный) вариант — исходный материал. Свет: оттенок окружения (базово) + своё настроение:
## тёплая лампа, рой светлячков, северное сияние на своде и в окне.

func apply_walls(id: String) -> void:
	var mode := ["owl_walls_bark", "owl_walls_moss", "owl_walls_starry", "owl_walls_runes"].find(id)
	_swap_mat(wall_parts, "owl_walls", OWL_WALLS, maxi(mode, 0))
	_style_extra("walls_moss", mode == 1, _moss_tufts)


func apply_floor(id: String) -> void:
	var mode := ["owl_floor_leaves", "owl_floor_rug", "owl_floor_stars", "owl_floor_roots"].find(id)
	_swap_mat(floor_parts, "owl_floor", OWL_FLOOR, maxi(mode, 0))
	if _leaves:
		_leaves.visible = mode <= 0 or mode == 3


func apply_light(id: String) -> void:
	super.apply_light(id)
	var mode := ["owl_light_moon", "owl_light_lamp", "owl_light_firefly", "owl_light_aurora"].find(id)
	if env and not _env0.is_empty() and mode > 0:
		# своё настроение: рассеянный свет и дымка (оттенок из каталога — для 2D-дома)
		env.ambient_light_color = [Color(), Color(0.6, 0.5, 0.48), Color(0.34, 0.46, 0.4), Color(0.3, 0.46, 0.62)][mode]
		env.fog_light_color = [Color(), Color(0.42, 0.24, 0.16), Color(0.14, 0.26, 0.2), Color(0.1, 0.28, 0.36)][mode]
	# лунный луч из окна и тёплый свет дупла — по настроению (оттенок ламп из каталога их не трогает)
	if _moon and _moon.has_meta("e0"):
		_moon.light_color = [Color("#9DB4FF"), Color("#B8A8FF"), Color("#A8E0C8"), Color("#8FF0E0")][maxi(mode, 0)]
		_moon.light_energy = float(_moon.get_meta("e0")) * [1.0, 0.45, 0.7, 0.9][maxi(mode, 0)]
	if _warm and _warm.has_meta("e0"):
		_warm.light_color = [Color("#FFB866"), Color("#FFB060"), Color("#D8F0A0"), Color("#B0E8F0")][maxi(mode, 0)]
		var e: float = float(_warm.get_meta("e0")) * [1.0, 1.5, 0.45, 0.4][maxi(mode, 0)]
		_warm.light_energy = e
		for l in lights:
			if l[0] == _warm:
				l[1] = e
	if env:
		var bg: Color = [Color("#120B24"), Color("#2A1410"), Color("#0C1A16"), Color("#06141C")][maxi(mode, 0)]
		env.background_color = bg
	if _sky:
		_sky.set_shader_parameter("aurora", 1.0 if (mode == 3 or stage >= 3) else 0.0)
		var tops := [Vector3(0.043, 0.031, 0.15), Vector3(0.10, 0.04, 0.12), Vector3(0.02, 0.06, 0.12), Vector3(0.01, 0.04, 0.09)]
		var bots := [Vector3(0.19, 0.13, 0.38), Vector3(0.55, 0.25, 0.22), Vector3(0.3, 0.24, 0.4), Vector3(0.06, 0.2, 0.25)]
		_sky.set_shader_parameter("top_col", tops[maxi(mode, 0)])
		_sky.set_shader_parameter("bot_col", bots[maxi(mode, 0)])
	_style_extra("light_flies", mode == 2, _firefly_swarm)
	_style_extra("light_aurora", mode == 3, _aurora_veil)
	_style_extra("light_lamp", mode == 1, _lamp_glow)


## Заменить материал деталей: mode 0 — исходный (meta "m0"), иначе — свой шейдер с режимом mode (кэш)
func _swap_mat(parts: Array, name: String, code: String, mode: int) -> void:
	for p in parts:
		if not is_instance_valid(p):
			continue
		var g3 := p as GeometryInstance3D
		if g3 == null:
			continue
		if not g3.has_meta("m0"):
			g3.set_meta("m0", g3.material_override)
		if mode == 0:
			g3.material_override = g3.get_meta("m0")
			continue
		var key := name + str(mode)
		if not _style_mats.has(key):
			_style_mats[key] = smat(name, code, {"mode": mode}, false)
		var m: ShaderMaterial = _style_mats[key]
		m.set_shader_parameter("lite", 0.0 if high else 1.0)
		g3.material_override = m


static var _style_mats := {}


## Дополнительные детали стиля: строятся при первом включении, дальше просто прячутся / показываются
func _style_extra(key: String, on: bool, build: Callable) -> void:
	if on and not _style_nodes.has(key):
		var n := node(self)
		n.name = "style_" + key
		var saved := anims
		anims = []
		build.call(n)
		var moving := []
		for a in anims:
			moving.append(a.n)
		merge_static(n, moving)
		_style_nodes[key] = n
		n.set_meta("anims", anims)
		anims = saved
	if _style_nodes.has(key):
		var n: Node3D = _style_nodes[key]
		n.visible = on
		if on and not spot_anims.has("_" + key):
			spot_anims["_" + key] = n.get_meta("anims")
		elif not on:
			spot_anims.erase("_" + key)
		_style_quality(key, n)


func _style_quality(key: String, n: Node3D) -> void:
	if key == "light_flies":
		var mmi := n.get_child(0) as MultiMeshInstance3D
		if mmi:
			mmi.multimesh.visible_instance_count = -1 if high else 26


func set_quality(hq: bool) -> void:
	super.set_quality(hq)
	for m in _style_mats.values():
		(m as ShaderMaterial).set_shader_parameter("lite", 0.0 if hq else 1.0)
	for k in _style_nodes:
		_style_quality(k, _style_nodes[k])


## Мшистые стены: мягкие кочки мха и свисающие пряди у стен (одна сетка)
func _moss_tufts(n: Node3D) -> void:
	var xfs := []
	var cols := []
	for i in 46:
		var a := hash1(i, 91) * TAU
		var hy := 0.25 + pow(hash1(i, 92), 1.6) * 3.0
		if absf(angle_difference(a, WIN_ANG)) < 0.45 and absf(hy - WIN_Y) < 1.0:
			continue
		if absf(angle_difference(a, PI / 2.0)) < 0.45 and hy < 2.2:
			continue  # полка славы
		var p := dir(a) * (wall_r(hy) - 0.03) + Vector3(0, hy, 0)
		var b := Basis(Vector3.UP, face_center(a)) * Basis.from_scale(Vector3(1.4, 0.7, 0.45) * (0.7 + 0.6 * hash1(i, 93)))
		xfs.append(Transform3D(b, p))
		cols.append(Color("#6FB04A").lerp(Color("#A8D86A"), hash1(i, 94)))
	scatter(n, sphere(0.16, 10), vmat(1.0, 0.1), xfs, cols)
	# свисающие пряди мха под сводом
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		if absf(angle_difference(a, PI / 2.0)) < 0.4:
			continue
		var top := dir(a) * (wall_r(3.3) - 0.08) + Vector3(0, 3.35, 0)
		var ln := 0.4 + 0.5 * hash1(i, 95)
		put(n, ptube(bez(top, top + Vector3(0, -ln * 0.5, 0) - dir(a) * 0.08, top + Vector3(0.03, -ln, 0) - dir(a) * 0.05, 6), 0.04, 0.012, 5, Color("#5E9A4A")),
			Shaders.material("sway", {"amp": 0.04, "speed": 0.8}))


## Светлячки: рой огоньков по всему дуплу (одна сетка-шейдер)
func _firefly_swarm(n: Node3D) -> void:
	shader_swarm(n, "flies", 56, {"center": Vector3(0, 1.6, 0), "spread": Vector3(2.4, 1.25, 2.4), "col": Color(0.75, 1.0, 0.35, 1.0), "size": 0.034})


## Северное сияние: переливающиеся ленты на своде (одна полупрозрачная сетка)
func _aurora_veil(n: Node3D) -> void:
	var mi := put(n, hemi(2.72, 40), smat("owl_aurora", OWL_AURORA, {}, false), Vector3(0, WALL_H - 0.05, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Тёплая лампа: абажур под сводом с мягким сиянием (без лишних источников света — светит сама)
func _lamp_glow(n: Node3D) -> void:
	var top := Vector3(0.0, 4.75, 0.0)
	put(n, cyl(0.008, 0.008, 0.6, 4), mat(Color("#C9B88A"), 1.0, 0.0, false), top - Vector3(0, 0.3, 0))
	var g := node(n, top - Vector3(0, 0.6, 0))
	anim(g, "pendulum", {"amp": 0.03, "spd": 0.7})
	vp(g, lathe([Vector2(0.06, 0.0), Vector2(0.24, -0.04), Vector2(0.3, -0.2), Vector2(0.0, -0.21)], 24), Color("#F0A04B"), Vector3(0, 0.0, 0))
	put(g, sphere(0.07, 12), glow_mat(Color("#FFE2A0"), 4.0), Vector3(0, -0.2, 0))
	halo(g, Vector3(0, -0.24, 0), 1.6, Color(1.0, 0.7, 0.35, 0.4))
	bake(g)


const OWL_WALLS := """
shader_type spatial;
uniform int mode = 1;
uniform float lite = 0.0;
varying vec3 wp;
void vertex() { wp = VERTEX; }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float glyph(vec2 f, float hh) {
	float d = seg(f, vec2(0.5, 0.1), vec2(0.5, 0.9));
	if (fract(hh * 2.0) > 0.5) d = min(d, seg(f, vec2(0.5, 0.78), vec2(0.84, 0.5)));
	if (fract(hh * 4.0) > 0.5) d = min(d, seg(f, vec2(0.5, 0.55), vec2(0.16, 0.3)));
	if (fract(hh * 8.0) > 0.5) d = min(d, seg(f, vec2(0.5, 0.9), vec2(0.18, 0.64)));
	if (fract(hh * 16.0) > 0.5) d = min(d, seg(f, vec2(0.5, 0.32), vec2(0.82, 0.12)));
	else d = min(d, seg(f, vec2(0.5, 0.62), vec2(0.82, 0.86)));
	return smoothstep(0.085, 0.04, d);
}
void fragment() {
	vec3 c = COLOR.rgb;
	vec3 em = vec3(0.0);
	float ang = atan(wp.x, -wp.z);
	vec2 cu = vec2(ang * 2.95, wp.y);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	if (mode == 1) {
		float n = vn(cu * 2.1) * 0.6 + vn(cu * 5.3 + 3.0) * 0.4;
		float m = smoothstep(0.44, 0.6, n * 0.9 + (1.8 - wp.y) * 0.12 + (0.32 - lum) * 0.6);
		vec3 moss = mix(vec3(0.14, 0.32, 0.08), vec3(0.34, 0.55, 0.16), vn(cu * 11.0) * 0.7 + 0.3 * vn(cu * 31.0));
		c = mix(c * vec3(0.85, 0.95, 0.75), moss, m);
		if (lite < 0.5) {
			vec2 g = cu * 6.0;
			vec2 id = floor(g);
			vec2 f = fract(g) - 0.5;
			float hh = h21(id);
			if (hh > 0.86 && m > 0.45) {
				float d = length(f - (vec2(h21(id + 2.0), h21(id + 5.0)) - 0.5) * 0.5);
				vec3 fc = hh > 0.95 ? vec3(1.0, 0.55, 0.65) : vec3(1.0, 0.86, 0.35);
				c = mix(c, fc, smoothstep(0.16, 0.1, d));
				em += fc * smoothstep(0.12, 0.0, d) * 0.25;
			}
		}
	} else if (mode == 2) {
		vec3 paint = mix(vec3(0.035, 0.04, 0.16), vec3(0.09, 0.06, 0.25), smoothstep(0.0, 3.6, wp.y));
		c = paint * (0.75 + lum * 2.2);
		vec2 g = cu * vec2(2.0, 2.4);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float hh = h21(id);
		vec2 q = f - (vec2(h21(id + 3.1), h21(id + 7.7)) - 0.5) * 0.5;
		float tw = 0.55 + 0.45 * sin(TIME * (0.8 + 2.0 * hh) + hh * 40.0);
		if (hh > 0.5) {
			float sz = 0.1 + 0.1 * h21(id + 1.7);
			float d = length(q);
			float cross_ = smoothstep(0.022, 0.0, min(abs(q.x), abs(q.y))) * smoothstep(sz * 2.2, 0.0, d);
			float core = smoothstep(sz * 0.55, 0.0, d);
			float s = max(core, cross_);
			vec3 gold = vec3(1.0, 0.78, 0.35);
			c = mix(c, gold, s * 0.9);
			em += gold * s * tw * 1.5;
		} else if (hh < 0.05) {
			float d1 = length(q) - 0.2;
			float d2 = length(q - vec2(0.09, 0.06)) - 0.17;
			float cr = smoothstep(0.015, 0.0, d1) * smoothstep(0.0, 0.015, d2);
			c = mix(c, vec3(1.0, 0.9, 0.55), cr);
			em += vec3(1.0, 0.85, 0.45) * cr * 0.9;
		}
		if (lite < 0.5) {
			vec2 g2 = cu * 7.0;
			vec2 id2 = floor(g2);
			float h2 = h21(id2 + 11.0);
			if (h2 > 0.82) {
				float d = length(fract(g2) - 0.5 - (vec2(h21(id2 + 1.0), h21(id2 + 2.0)) - 0.5) * 0.6);
				em += vec3(0.75, 0.8, 1.0) * smoothstep(0.08, 0.0, d) * (0.5 + 0.5 * sin(TIME * 2.0 + h2 * 30.0));
			}
		}
	} else if (mode == 3) {
		c = c * vec3(0.55, 0.62, 0.7) + vec3(0.02, 0.03, 0.05);
		float pulse = 0.55 + 0.45 * sin(TIME * 1.4 - ang * 3.0);
		vec3 rc = vec3(0.25, 1.0, 0.85);
		float rune = 0.0;
		for (int b = 0; b < 2; b++) {
			float y0 = b == 0 ? 0.95 : 2.62;
			float hb = 0.38;
			if (wp.y > y0 - hb * 0.5 && wp.y < y0 + hb * 0.5) {
				vec2 g = vec2(cu.x / 0.3, (wp.y - (y0 - hb * 0.5)) / hb);
				float cid = floor(g.x);
				float hh = h21(vec2(cid, float(b) * 7.0));
				rune = max(rune, glyph(vec2(fract(g.x), g.y), hh));
			}
			float edge = smoothstep(0.02, 0.0, abs(wp.y - (y0 + 0.24))) + smoothstep(0.02, 0.0, abs(wp.y - (y0 - 0.24)));
			rune = max(rune, edge * 0.6);
		}
		if (lite < 0.5) {
			float v = vn(vec2(cu.x * 1.3, wp.y * 0.8) + vec2(0.0, TIME * 0.05));
			float vein = smoothstep(0.03, 0.0, abs(v - 0.5)) * smoothstep(1.4, 1.8, wp.y) * smoothstep(2.3, 2.0, wp.y);
			rune = max(rune, vein * 0.5);
		}
		c = mix(c, rc * 0.4, rune * 0.7);
		em += rc * rune * pulse * 1.15;
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	EMISSION = em;
}
"""

const OWL_FLOOR := """
shader_type spatial;
uniform int mode = 1;
uniform float lite = 0.0;
varying vec3 wp;
void vertex() { wp = VERTEX; }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
vec3 band_col(float i) {
	float m = mod(i, 5.0);
	if (m < 1.0) return vec3(0.55, 0.25, 0.17);
	if (m < 2.0) return vec3(0.80, 0.68, 0.5);
	if (m < 3.0) return vec3(0.68, 0.5, 0.2);
	if (m < 4.0) return vec3(0.32, 0.46, 0.38);
	return vec3(0.48, 0.3, 0.42);
}
void fragment() {
	vec3 c = COLOR.rgb;
	vec3 em = vec3(0.0);
	float r = length(wp.xz);
	float a = atan(wp.z, wp.x);
	if (mode == 1) {
		float rr = 2.55;
		if (r < rr) {
			float w = 0.15;
			float bi = floor(r / w);
			float t = fract(r / w);
			float dirn = mod(bi, 2.0) < 1.0 ? 1.0 : -1.0;
			float braid = 0.5 + 0.5 * sin(a * (24.0 + bi * 9.0) * dirn + t * 6.2831);
			vec3 bc = band_col(bi);
			c = bc * (0.72 + 0.4 * braid) * (0.8 + 0.2 * sin(t * 3.1416));
			c = mix(c, c * 0.55, smoothstep(0.42, 0.5, abs(t - 0.5)));
		} else if (r < rr + 0.12) {
			float fr = step(0.5, fract(a * 60.0));
			c = mix(c, vec3(0.80, 0.62, 0.36), fr * smoothstep(rr + 0.12, rr, r));
		}
	} else if (mode == 2) {
		float rr = 2.45;
		if (r < rr) {
			vec3 navy = mix(vec3(0.015, 0.02, 0.08), vec3(0.04, 0.035, 0.14), vn(wp.xz * 1.5));
			c = navy;
			float ring = smoothstep(0.03, 0.0, abs(r - rr + 0.12)) + smoothstep(0.015, 0.0, abs(r - rr + 0.22));
			vec3 gold = vec3(0.95, 0.7, 0.3);
			c = mix(c, gold * 0.7, ring);
			em += gold * ring * 0.4;
			vec2 g = wp.xz * 2.2;
			vec2 id = floor(g);
			vec2 f = fract(g);
			vec2 o = vec2(h21(id), h21(id + 4.0)) * 0.6 + 0.2;
			float hh = h21(id + 9.0);
			float tw = 0.6 + 0.4 * sin(TIME * (1.0 + hh * 2.0) + hh * 30.0);
			float d = length(f - o);
			float star = smoothstep(0.07, 0.0, d);
			float sp = smoothstep(0.018, 0.0, min(abs(f.x - o.x), abs(f.y - o.y))) * smoothstep(0.16, 0.0, d);
			float lines = 0.0;
			if (hh > 0.45) {
				vec2 on = vec2(1.0, 0.0) + vec2(h21(id + vec2(1.0, 0.0)), h21(id + vec2(1.0, 0.0) + 4.0)) * 0.6 + 0.2;
				lines = max(lines, smoothstep(0.012, 0.0, seg(f, o, on)));
			}
			if (hh < 0.55) {
				vec2 on = vec2(0.0, 1.0) + vec2(h21(id + vec2(0.0, 1.0)), h21(id + vec2(0.0, 1.0) + 4.0)) * 0.6 + 0.2;
				lines = max(lines, smoothstep(0.012, 0.0, seg(f, o, on)));
			}
			c = mix(c, vec3(1.0, 0.92, 0.7), max(star, sp) * 0.9);
			c = mix(c, gold * 0.5, lines * 0.6);
			em += vec3(1.0, 0.9, 0.6) * max(star, sp) * tw * 1.3 + gold * lines * 0.25;
		}
	} else if (mode == 3) {
		c = c * vec3(0.45, 0.42, 0.4);
		vec2 p = wp.xz * 1.1;
		vec2 warp = vec2(vn(p * 1.3 + 7.0), vn(p * 1.3 + 3.0)) * 1.4;
		float n = vn(p * 1.6 + warp);
		float ridge = 1.0 - abs(2.0 * n - 1.0);
		float vein = smoothstep(0.93, 0.985, ridge);
		float fine = 0.0;
		if (lite < 0.5) {
			float n2 = vn(p * 4.2 + warp * 2.0);
			fine = smoothstep(0.95, 0.99, 1.0 - abs(2.0 * n2 - 1.0)) * 0.55;
		}
		float pulse = 0.55 + 0.45 * sin(r * 3.2 - TIME * 1.6);
		float v = max(vein, fine) * smoothstep(0.75, 1.1, r);
		vec3 gc = mix(vec3(0.2, 1.0, 0.75), vec3(0.45, 0.8, 1.0), vn(p * 0.5));
		c = mix(c, vec3(0.28, 0.18, 0.12), smoothstep(0.7, 0.86, ridge) * 0.7);
		c = mix(c, gc * 0.35, v);
		em += gc * v * pulse * 1.15;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	EMISSION = em;
}
"""

const OWL_AURORA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float a = atan(lp.z, lp.x);
	float el = clamp(lp.y / 2.72, 0.0, 1.0);
	float acc = 0.0;
	vec3 col = vec3(0.0);
	for (int j = 0; j < 3; j++) {
		float fj = float(j);
		float center = 0.35 + 0.18 * fj + 0.08 * sin(a * (2.0 + fj) + TIME * (0.25 + 0.1 * fj) + fj * 2.0);
		float band = smoothstep(0.16, 0.0, abs(el - center)) * smoothstep(-0.2, 0.05, el - center + 0.06);
		float rays = 0.75 + 0.25 * sin(a * 23.0 + TIME * 0.5 + fj * 3.0 + 2.0 * sin(a * 4.0 + TIME * 0.3));
		vec3 c = mix(vec3(0.2, 1.0, 0.55), vec3(0.55, 0.45, 1.0), fj * 0.5 + 0.25 * sin(a * 3.0 + TIME * 0.4));
		col += c * band * rays;
	}
	ALBEDO = col * 0.42 * smoothstep(0.05, 0.25, el);
}
"""


# ---------- 0.15: новые украшения ----------
## Все строятся от точки места (+Z — в комнату). sk: floor / near / big — на полу, wall — висит на стене
## (плоские), ledge — стоит на полочке-трутовике или на подоконнике, hang — на нитке (или своя верёвка).
## Неподвижное склеивается в 2–4 сетки (vp / gm / gl), двигается немногое; свет — свечение и сияние, свои
## источники света — только у самых «тёплых» вещей (свечи, шкаф с лампой, котёл, обсерватория).

const WOOD := Color("#9A6A44")
const WOOD_D := Color("#6B4433")
const WOOD_L := Color("#C99A6A")
const BRASS := Color("#E8B44E")
const CREAM := Color("#FFF3E0")


func _new_decor(id: String, n: Node3D, sk: String) -> bool:
	match id:
		"owl_candles": _d_candles(n)
		"owl_tea": _d_tea(n)
		"owl_clock": _d_clock(n)
		"owl_armchair": _d_armchair(n)
		"owl_bookcase": _d_bookcase(n)
		"owl_starmap": _d_starmap(n)
		"owl_globe": _d_globe(n, sk)
		"owl_comet": _d_comet(n)
		"owl_planets": _d_planets(n)
		"owl_telescope": _d_telescope(n, sk)
		"owl_observatory": _d_observatory(n)
		"owl_mortar": _d_mortar(n, sk)
		"owl_herbs": _d_herbs(n, sk)
		"owl_wreath": _d_wreath(n, sk)
		"owl_fireflies": _d_fireflies(n)
		"owl_potions": _d_potions(n)
		"owl_crystals": _d_crystals(n, sk)
		"owl_staff": _d_staff(n, sk)
		"owl_spellbook": _d_spellbook(n)
		"owl_cauldron": _d_cauldron(n, sk)
		_: return false
	return true


## Свечи на спиле: три разной высоты, огоньки мерцают, тёплое сияние
func _d_candles(n: Node3D) -> void:
	vp(n, cyl(0.2, 0.21, 0.045, 20), WOOD, Vector3(0, 0.022, 0))
	vp(n, cyl(0.18, 0.18, 0.006, 20), WOOD_L, Vector3(0, 0.046, 0), Vector3.ZERO, Vector3.ONE, false)
	vp(n, torus(0.1, 0.12, 20), Color("#D9B07A"), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.3, 1), false)
	var cs := [[Vector3(-0.07, 0, -0.04), 0.27, 0.048, Color("#FFF1D6")], [Vector3(0.08, 0, -0.03), 0.19, 0.042, Color("#FFE0E6")], [Vector3(0.0, 0, 0.09), 0.12, 0.04, Color("#FFF1D6")]]
	var i := 0
	for c in cs:
		var p: Vector3 = c[0] + Vector3(0, 0.048, 0)
		var hh: float = c[1]
		var r: float = c[2]
		vp(n, cyl(r, r * 1.04, hh, 14), c[3], p + Vector3(0, hh * 0.5, 0))
		vp(n, sphere(r * 0.95, 12), c[3], p + Vector3(0, hh, 0), Vector3.ZERO, Vector3(1, 0.25, 1), false)
		for k in 3:
			var a := k * 2.1 + i * 0.9
			vp(n, sphere(0.016, 6), (c[3] as Color).lightened(0.3), p + Vector3(cos(a) * r, hh - 0.035 - 0.02 * k, sin(a) * r), Vector3.ZERO, Vector3(1, 2.4, 1), false)
		vp(n, cyl(0.004, 0.004, 0.03, 4), Color("#3A2A2A"), p + Vector3(0, hh + 0.015, 0), Vector3.ZERO, Vector3.ONE, false)
		var fl := put(n, sphere(0.024, 10), glow_mat(Color("#FFD46B"), 5.0), p + Vector3(0, hh + 0.05, 0), Vector3.ZERO, Vector3(1, 1.8, 1))
		anim(fl, "flame", {"p": i * 1.7})
		i += 1
	halo(n, Vector3(0, 0.3, 0.02), 0.8, Color(1.0, 0.72, 0.32, 0.45))
	omni(n, Vector3(0, 0.36, 0.12), Color("#FFB866"), 0.55, 1.9, "flicker")


## Чайный столик-спил: чайник в горошек, две чашки, печенье; из носика поднимаются тающие шарики пара
func _d_tea(n: Node3D) -> void:
	vp(n, cyl(0.11, 0.15, 0.3, 12), WOOD_D, Vector3(0, 0.15, 0))
	for k in 3:
		var a := k * TAU / 3.0 + 0.4
		vp(n, capsule(0.04, 0.2), WOOD_D, dir(a) * 0.15 + Vector3(0, 0.03, 0), Vector3(0, -a, PI / 2.0 - 0.25), Vector3(1, 1, 1))
	vp(n, cyl(0.37, 0.37, 0.08, 28), Color("#A86F45"), Vector3(0, 0.34, 0))
	vp(n, cyl(0.345, 0.345, 0.01, 28), Color("#E8C48E"), Vector3(0, 0.384, 0), Vector3.ZERO, Vector3.ONE, false)
	vp(n, torus(0.2, 0.215, 28), Color("#C99A6A"), Vector3(0, 0.389, 0), Vector3.ZERO, Vector3(1, 0.2, 1), false)
	vp(n, torus(0.09, 0.105, 20), Color("#C99A6A"), Vector3(0, 0.389, 0), Vector3.ZERO, Vector3(1, 0.2, 1), false)
	# чайник
	var pot := node(n, Vector3(-0.07, 0.39, -0.05))
	vp(pot, lathe([Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.045), Vector2(0.118, 0.1), Vector2(0.08, 0.15), Vector2(0.0, 0.158)], 20), Color("#6FB6E6"))
	vp(pot, cyl(0.055, 0.07, 0.03, 16), Color("#5FA0D0"), Vector3(0, 0.16, 0))
	vp(pot, sphere(0.025, 8), Color("#FFD34D"), Vector3(0, 0.19, 0))
	vp(pot, ptube([Vector3(0.1, 0.06, 0), Vector3(0.17, 0.1, 0), Vector3(0.2, 0.16, 0)], 0.026, 0.014, 6), Color("#6FB6E6"))
	vp(pot, torus(0.035, 0.05, 14), Color("#5FA0D0"), Vector3(-0.12, 0.08, 0), Vector3(PI / 2.0, 0, 0))
	for k in 9:
		var a := k * 0.7
		var y := 0.03 + 0.012 * (k % 4) * 2.0
		vp(pot, sphere(0.013, 6), CREAM, Vector3(cos(a) * 0.118, y + 0.02, sin(a) * 0.118), Vector3.ZERO, Vector3(1, 1, 0.5), false)
	# чашки
	for c in [[Vector3(0.17, 0.39, 0.1), Color("#FF9EB5")], [Vector3(-0.05, 0.39, 0.2), Color("#FFD36B")]]:
		var cp: Vector3 = c[0]
		vp(n, cyl(0.075, 0.065, 0.012, 16), CREAM, cp + Vector3(0, 0.006, 0))
		vp(n, lathe([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.055, 0.05), Vector2(0.058, 0.075), Vector2(0.0, 0.075)], 16), c[1], cp + Vector3(0, 0.012, 0))
		vp(n, cyl(0.05, 0.05, 0.004, 14), Color("#B5703A"), cp + Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)
		vp(n, torus(0.017, 0.027, 10), c[1], cp + Vector3(0.06, 0.05, 0), Vector3(PI / 2.0, 0, 0))
	# печенье на тарелочке
	vp(n, cyl(0.08, 0.07, 0.01, 16), CREAM, Vector3(0.12, 0.395, -0.15))
	for k in 3:
		vp(n, cyl(0.03, 0.03, 0.012, 12), Color("#D9A05A"), Vector3(0.12 + (k - 1) * 0.035, 0.41 + 0.005 * k, -0.15 + 0.02 * (k % 2)), Vector3(0.2, 0, 0.1 * k), Vector3.ONE, false)
	# пар: шарики поднимаются из носика и тают
	var tip := pot.position + Vector3(0.2, 0.17, 0)
	for k in 3:
		var b := put(n, sphere(0.028, 8), gl(0.5, 0.4), tip, Vector3.ZERO, Vector3.ONE)
		anim(b, "rise", {"h": 0.32, "spd": 0.3, "p": k / 3.0})


## Часы с маятником (висят на стене): циферблат-«совиная мордочка», стрелки идут, маятник качается
func _d_clock(n: Node3D) -> void:
	var c := Vector3(0, 0.5, 0.06)
	vp(n, box(Vector3(0.16, 0.36, 0.05)), WOOD_D, Vector3(0, 0.2, 0.025))
	vp(n, cyl(0.24, 0.24, 0.07, 32), WOOD, c, Vector3(PI / 2.0, 0, 0))
	vp(n, torus(0.2, 0.235, 32), BRASS, c + Vector3(0, 0, 0.035), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	vp(n, cyl(0.2, 0.2, 0.02, 32), CREAM, c + Vector3(0, 0, 0.03), Vector3(PI / 2.0, 0, 0), Vector3.ONE, false)
	for k in 12:
		var a := TAU * k / 12.0
		var big := k % 3 == 0
		vp(n, sphere(0.018 if big else 0.01, 6), Color("#3A2A55"), c + Vector3(sin(a) * 0.16, cos(a) * 0.16, 0.042), Vector3.ZERO, Vector3(1, 1, 0.4), false)
	for sx in [-1.0, 1.0]:
		vp(n, prism(Vector3(0.13, 0.15, 0.06)), WOOD, c + Vector3(sx * 0.15, 0.23, 0), Vector3(0, 0, -sx * 0.35))
		vp(n, sphere(0.022, 8), BRASS, c + Vector3(sx * 0.16, -0.25, 0.02), Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(n, sphere(0.022, 8), Color("#3A2A55"), c + Vector3(0, 0, 0.048), Vector3.ZERO, Vector3(1, 1, 0.5), false)
	var hm := node(n, c + Vector3(0, 0, 0.046))
	vp(hm, box(Vector3(0.018, 0.13, 0.008)), Color("#3A2A55"), Vector3(0, 0.055, 0), Vector3.ZERO, Vector3.ONE, false)
	anim(hm, "spin", {"axis": Vector3.BACK, "spd": -0.35})
	var hh := node(n, c + Vector3(0, 0, 0.05))
	vp(hh, box(Vector3(0.024, 0.085, 0.008)), Color("#E0556F"), Vector3(0, 0.035, 0), Vector3.ZERO, Vector3.ONE, false)
	anim(hh, "spin", {"axis": Vector3.BACK, "spd": -0.03, "p": 2.0})
	var pend := node(n, c + Vector3(0, -0.2, 0.085))
	vp(pend, cyl(0.008, 0.008, 0.28, 5), BRASS, Vector3(0, -0.14, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
	vp(pend, cyl(0.055, 0.055, 0.02, 18), BRASS, Vector3(0, -0.3, 0), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	bake(pend)
	anim(pend, "wiggle", {"axis": Vector3.BACK, "amp": 0.32, "spd": 2.4})


## Кресло-пенёк: зелёная подушка, клетчатый плед, книжка на сиденье
func _d_armchair(n: Node3D) -> void:
	vp(n, cyl(0.3, 0.34, 0.36, 18), Color("#7A5141"), Vector3(0, 0.18, 0))
	for k in 10:
		var a := TAU * k / 10.0
		vp(n, box(Vector3(0.05, 0.34, 0.03)), WOOD_D, dir(a) * 0.32 + Vector3(0, 0.18, 0), Vector3(0, -a + PI / 2.0, 0), Vector3.ONE, false)
	vp(n, cyl(0.3, 0.3, 0.02, 18), Color("#E8C48E"), Vector3(0, 0.36, 0), Vector3.ZERO, Vector3.ONE, false)
	# спинка — высокая часть пня сзади
	vp(n, cyl(0.31, 0.34, 0.78, 18), Color("#7A5141"), Vector3(0, 0.39, -0.2), Vector3.ZERO, Vector3(1.0, 1.0, 0.38))
	vp(n, sphere(0.31, 16), Color("#8A5A44"), Vector3(0, 0.78, -0.2), Vector3.ZERO, Vector3(1.0, 0.35, 0.38))
	for sx in [-1.0, 1.0]:
		vp(n, sphere(0.12, 12), Color("#7A5141"), Vector3(sx * 0.28, 0.45, -0.02), Vector3.ZERO, Vector3(0.7, 0.6, 1.6))
	# подушки
	vp(n, sphere(0.27, 18), Color("#5DBB63"), Vector3(0, 0.42, 0.03), Vector3.ZERO, Vector3(1.0, 0.28, 0.95))
	vp(n, sphere(0.24, 16), Color("#7FD088"), Vector3(0, 0.6, -0.1), Vector3(-0.25, 0, 0), Vector3(1.0, 0.72, 0.3))
	for k in 4:
		vp(n, sphere(0.022, 6), Color("#3F8E4A"), Vector3((k % 2 - 0.5) * 0.24, 0.48 + 0.12 * int(k / 2), -0.02 - 0.03 * int(k / 2)), Vector3.ZERO, Vector3.ONE, false)
	# плед, переброшенный через подлокотник
	var pl := node(n, Vector3(0.27, 0.5, 0.02))
	pl.rotation = Vector3(0, 0, -0.35)
	vp(pl, box(Vector3(0.05, 0.36, 0.36)), Color("#E0556F"), Vector3.ZERO)
	for k in 3:
		vp(pl, box(Vector3(0.052, 0.36, 0.035)), CREAM, Vector3(0, 0, -0.12 + k * 0.12), Vector3.ZERO, Vector3.ONE, false)
		vp(pl, box(Vector3(0.052, 0.035, 0.36)), CREAM, Vector3(0, -0.12 + k * 0.12, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in 6:
		vp(pl, sphere(0.014, 6), CREAM, Vector3(0.0, -0.21, -0.15 + k * 0.06), Vector3.ZERO, Vector3(1, 2.5, 1), false)
	# книжка на сиденье
	vp(n, box(Vector3(0.16, 0.035, 0.12)), Color("#5FC8FF"), Vector3(-0.1, 0.5, 0.12), Vector3(0, 0.4, 0))
	vp(n, box(Vector3(0.15, 0.025, 0.112)), CREAM, Vector3(-0.1, 0.502, 0.12), Vector3(0, 0.4, 0), Vector3(1.0, 1.0, 1.0), false)
	# грибок у ножки
	vp(n, cyl(0.02, 0.025, 0.08, 8), CREAM, Vector3(0.3, 0.04, 0.2))
	vp(n, hemi(0.06, 12), Color("#FF7A5C"), Vector3(0.3, 0.08, 0.2), Vector3.ZERO, Vector3(1, 1.3, 1))


## ★ Книжный шкаф до свода: цветные корешки, лесенка, книга выдвигается и задвигается, лампа с тёплым светом
func _d_bookcase(n: Node3D) -> void:
	var W := 0.98
	var H := 1.86
	var D := 0.4
	var wood := Color("#8A5A3A")
	var g := node(n, Vector3(0, 0, -0.05))
	for sx in [-1.0, 1.0]:
		vp(g, box(Vector3(0.08, H, D)), wood, Vector3(sx * (W * 0.5 - 0.04), H * 0.5, 0))
		vp(g, sphere(0.06, 10), WOOD_D, Vector3(sx * (W * 0.5 - 0.04), 0.03, D * 0.35), Vector3.ZERO, Vector3(1.2, 0.6, 1.2))
	vp(g, box(Vector3(W, H, 0.04)), Color("#5A3A2A"), Vector3(0, H * 0.5, -D * 0.5 + 0.02), Vector3.ZERO, Vector3.ONE, false)
	# арка-корона с круглым окошком и совиными глазками
	var crown := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		crown.append(Vector2(cos(a), sin(a)) * (W * 0.5 + 0.03))
	vp(g, extrude(crown, D), wood, Vector3(0, H, 0))
	vp(g, cyl(0.15, 0.15, 0.03, 24), Color("#3A2440"), Vector3(0, H + 0.2, D * 0.5), Vector3(PI / 2.0, 0, 0), Vector3.ONE, false)
	vp(g, torus(0.14, 0.18, 24), BRASS, Vector3(0, H + 0.2, D * 0.5 + 0.005), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	var eyes := node(g, Vector3(0, H + 0.2, D * 0.5 + 0.02))
	for sx in [-1.0, 1.0]:
		vp(eyes, sphere(0.045, 10), Color("#FFD34D"), Vector3(sx * 0.055, 0, 0), Vector3.ZERO, Vector3(1, 1, 0.4), false)
		vp(eyes, sphere(0.02, 8), Color("#1E1236"), Vector3(sx * 0.055, 0, 0.015), Vector3.ZERO, Vector3(1, 1, 0.4), false)
	bake(eyes)
	anim(eyes, "blink_eye", {"p": 0.7})
	# полки
	var levels := [0.1, 0.52, 0.94, 1.36]
	for y in levels:
		vp(g, box(Vector3(W - 0.12, 0.045, D - 0.04)), WOOD_L, Vector3(0, y, 0.0))
		vp(g, box(Vector3(W - 0.1, 0.03, 0.03)), wood, Vector3(0, y - 0.005, D * 0.5 - 0.01), Vector3.ZERO, Vector3.ONE, false)
	vp(g, box(Vector3(W - 0.12, 0.045, D - 0.04)), WOOD_L, Vector3(0, H - 0.02, 0.0))
	var pal := [Color("#E0556F"), Color("#5FC8FF"), Color("#FFD34D"), Color("#3DDC97"), Color("#B46CFF"), Color("#FF9E5C"), Color("#2F6FB0"), Color("#F3D6FF")]
	var slide_done := false
	for li in levels.size():
		var y: float = levels[li] + 0.0225
		var x := -W * 0.5 + 0.1
		var bi := 0
		while x < W * 0.5 - 0.12:
			var hh := 0.22 + 0.12 * hash1(li * 31 + bi, 3)
			var w := 0.045 + 0.03 * hash1(li * 31 + bi, 4)
			var col: Color = pal[(li * 3 + bi) % pal.size()]
			if li == 3 and x > 0.05:
				break  # место для лампы
			if hash1(li * 31 + bi, 5) > 0.86 and x < W * 0.5 - 0.3:
				# стопка лёжа
				for k in 3:
					vp(g, box(Vector3(0.2, 0.045, 0.24)), pal[(li + k + bi) % pal.size()], Vector3(x + 0.1, y + 0.023 + k * 0.047, 0.02), Vector3(0, 0.1 * (k - 1), 0))
				x += 0.22
			elif li == 1 and bi == 3 and not slide_done:
				var sl := node(g, Vector3(x + w * 0.5, y + hh * 0.5, 0.02))
				vp(sl, box(Vector3(w, hh, 0.26)), Color("#E0556F"), Vector3.ZERO)
				vp(sl, box(Vector3(w + 0.004, 0.025, 0.262)), BRASS, Vector3(0, hh * 0.3, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
				vp(sl, sphere(0.014, 6), Color("#FFD34D"), Vector3(0, 0.0, 0.132), Vector3.ZERO, Vector3(1, 1, 0.4), false)
				bake(sl)
				anim(sl, "call", {"f": _book_slide})
				slide_done = true
				x += w + 0.006
			else:
				var tilt := 0.0
				if hash1(li * 31 + bi, 6) > 0.82:
					tilt = 0.22
				vp(g, box(Vector3(w, hh, 0.26)), col, Vector3(x + w * 0.5 + tilt * hh * 0.5, y + hh * 0.5, 0.02), Vector3(0, 0, -tilt))
				vp(g, box(Vector3(w + 0.004, 0.022, 0.262)), col.lightened(0.45), Vector3(x + w * 0.5 + tilt * hh * 0.5, y + hh * 0.72, 0.02), Vector3(0, 0, -tilt), Vector3.ONE, false)
				x += w + 0.006 + tilt * hh
			bi += 1
	# лампа на верхней полке
	var lamp := Vector3(0.24, levels[3] + 0.025, 0.04)
	vp(g, cyl(0.05, 0.065, 0.03, 14), BRASS, lamp + Vector3(0, 0.015, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(g, cyl(0.012, 0.012, 0.16, 6), BRASS, lamp + Vector3(0, 0.1, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
	put(g, lathe([Vector2(0.13, 0.0), Vector2(0.06, 0.12), Vector2(0.0, 0.125)], 20), mat(Color("#FFB866"), 0.7, 1.4), lamp + Vector3(0, 0.15, 0))
	put(g, sphere(0.04, 10), glow_mat(Color("#FFF0C0"), 5.0), lamp + Vector3(0, 0.15, 0))
	halo(g, lamp + Vector3(0, 0.18, 0.05), 1.1, Color(1.0, 0.75, 0.38, 0.45))
	omni(g, lamp + Vector3(0, 0.2, 0.35), Color("#FFB866"), 0.9, 2.8, "slow")
	# совёнок-статуэтка и глобус на полках
	vp(g, sphere(0.07, 12), Color("#B48CFF"), Vector3(0.36, levels[2] + 0.1, 0.05), Vector3.ZERO, Vector3(1, 1.15, 0.9))
	for sx in [-1.0, 1.0]:
		vp(g, prism(Vector3(0.04, 0.05, 0.03)), Color("#B48CFF"), Vector3(0.36 + sx * 0.04, levels[2] + 0.19, 0.05), Vector3(0, 0, -sx * 0.3), Vector3.ONE, false)
		vp(g, sphere(0.02, 8), Color("#FFD34D"), Vector3(0.36 + sx * 0.028, levels[2] + 0.12, 0.11), Vector3.ZERO, Vector3(1, 1, 0.5), false)
	# лесенка, приставленная справа
	var lad := node(g, Vector3(W * 0.5 + 0.06, 0, D * 0.5 + 0.12))
	lad.rotation = Vector3(-0.17, 0, 0.0)
	for sx in [-1.0, 1.0]:
		vp(lad, cyl(0.022, 0.022, 1.72, 8), WOOD_L, Vector3(sx * 0.14, 0.86, 0))
	for k in 6:
		vp(lad, cyl(0.016, 0.016, 0.28, 6), WOOD, Vector3(0, 0.2 + k * 0.28, 0), Vector3(0, 0, PI / 2.0))
	# горшок с плющом на короне
	vp(g, cyl(0.08, 0.06, 0.1, 14), Color("#D9785A"), Vector3(-0.32, H + 0.08, 0.05))
	var ivy := bez(Vector3(-0.36, H + 0.13, 0.12), Vector3(-0.52, H + 0.05, 0.2), Vector3(-0.5, H - 0.7, 0.22), 10)
	vp(g, ptube(ivy, 0.012, 0.008, 4), Color("#2F8F4E"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for k in range(1, 10):
		vp(g, sphere(0.04, 8), Color("#3FAF6E").lerp(Color("#7FD088"), hash1(k, 8)), (ivy[k] as Vector3) + Vector3(0.02 * ((k % 2) * 2 - 1), 0, 0.02), Vector3(0.3 * k, 0.5 * k, 0), Vector3(1.0, 0.45, 0.7), false)


func _book_slide(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := clampf(sin(t * 0.7) * 2.5 - 1.2, 0.0, 1.0)
	nd.transform = Transform3D(Basis(Vector3.RIGHT, -0.15 * u), a.base.origin + Vector3(0, 0.02 * u, 0.13 * u))


## Карта созвездий: тёмный свиток на шнурке, звёзды-линии мигают по очереди (рисует шейдер)
func _d_starmap(n: Node3D) -> void:
	var c := Vector3(0, 0.42, 0.05)
	var q := put(n, quad(Vector2(0.62, 0.66)), smat("owl_starmap", OWL_STARMAP, {}, false), c + Vector3(0, 0, 0.012))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp(n, box(Vector3(0.62, 0.66, 0.02)), Color("#1C2050"), c)
	for sy in [-1.0, 1.0]:
		vp(n, cyl(0.035, 0.035, 0.7, 12), Color("#2C3470"), c + Vector3(0, sy * 0.34, 0.012), Vector3(0, 0, PI / 2.0))
		for sx in [-1.0, 1.0]:
			vp(n, sphere(0.032, 8), BRASS, c + Vector3(sx * 0.36, sy * 0.34, 0.012), Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(n, ptube([c + Vector3(-0.3, 0.35, 0.02), Vector3(0, 0.88, 0.02), c + Vector3(0.3, 0.35, 0.02)], 0.006, 0.006, 4), Color("#C9B88A"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	vp(n, sphere(0.025, 8), BRASS, Vector3(0, 0.88, 0.02), Vector3.ZERO, Vector3.ONE, true, 0.35)
	halo(n, c + Vector3(0, 0, 0.05), 0.9, Color(0.55, 0.65, 1.0, 0.16))


## Звёздный глобус: синий шар в светящихся точках вращается; на полу — на высокой треноге
func _d_globe(n: Node3D, sk: String) -> void:
	var floor_ := sk != "ledge"
	var k := 1.35 if floor_ else 1.0
	var top := 0.0
	if floor_:
		for i in 3:
			var a := TAU * i / 3.0 + 0.3
			vp(n, ptube([dir(a) * 0.24 + Vector3(0, 0.0, 0), dir(a) * 0.12 + Vector3(0, 0.3, 0), Vector3(0, 0.5, 0)], 0.022, 0.018, 6), WOOD)
			vp(n, sphere(0.03, 8), BRASS, dir(a) * 0.24 + Vector3(0, 0.015, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
		top = 0.5
	else:
		vp(n, cyl(0.1, 0.12, 0.045, 18), BRASS, Vector3(0, 0.022, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
		vp(n, cyl(0.016, 0.02, 0.08, 8), BRASS, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
		top = 0.11
	var c := Vector3(0, top + 0.17 * k, 0)
	var tilt := node(n, c)
	tilt.rotation.z = 0.4
	vp(tilt, torus(0.165 * k, 0.185 * k, 32), BRASS, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	vp(tilt, cyl(0.008, 0.008, 0.42 * k, 4), BRASS, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, 0.35)
	var spin := node(tilt)
	put(spin, sphere(0.15 * k, 24), mat(Color("#2F3FA8"), 0.5, 0.35, true, Color("#3A50D0")))
	for i in 34:
		var u := hash1(i, 11) * 2.0 - 1.0
		var a := hash1(i, 12) * TAU
		var p := Vector3(sqrt(1.0 - u * u) * cos(a), u, sqrt(1.0 - u * u) * sin(a)) * 0.151 * k
		vp(spin, sphere(0.009 * k * (1.0 + hash1(i, 13)), 5), Color("#FFF2B0") if i % 4 else Color("#9FE8FF"), p, Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		var a := 0.6 + i * 1.9
		var u := 0.3 - i * 0.35
		var p0 := Vector3(sqrt(1.0 - u * u) * cos(a), u, sqrt(1.0 - u * u) * sin(a)) * 0.152 * k
		var p1 := Vector3(sqrt(1.0 - u * u) * cos(a + 0.5), u + 0.2, sqrt(1.0 - u * u) * sin(a + 0.5)) * 0.152 * k
		vp(spin, ptube(bez(p0, (p0 + p1) * 0.55, p1, 4), 0.004 * k, 0.004 * k, 3), Color("#FFE58A"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	_glowify(spin, Color("#FFF2B0"))
	bake(spin)
	anim(spin, "spin", {"spd": 0.45})
	halo(n, c, 0.75 * k, Color(0.45, 0.6, 1.0, 0.3))


## Сделать светящимися детали группы цвета col (точки-звёзды, окошки): материал — gm (одна сетка на все)
func _glowify(g: Node3D, col: Color, energy := 2.2) -> void:
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override is StandardMaterial3D and _mesh_col(m.mesh) == col:
			m.material_override = gm(energy)


static func _mesh_col(m: Mesh) -> Color:
	if m == null or m.get_surface_count() == 0:
		return Color(0, 0, 0, 0)
	var arr := m.surface_get_arrays(0)
	var cols = arr[Mesh.ARRAY_COLOR]
	if cols == null or (cols as PackedColorArray).is_empty():
		return Color(0, 0, 0, 0)
	return (cols as PackedColorArray)[0]


## Комета в банке: светящийся шарик с хвостом бегает по кругу
func _d_comet(n: Node3D) -> void:
	vp(n, cyl(0.13, 0.14, 0.03, 20), WOOD, Vector3(0, 0.015, 0))
	put(n, cyl(0.115, 0.115, 0.26, 20), gl(0.22, 0.05), Vector3(0, 0.16, 0))
	vp(n, cyl(0.1, 0.1, 0.008, 18), Color("#2C3470"), Vector3(0, 0.035, 0), Vector3.ZERO, Vector3.ONE, false)
	vp(n, cyl(0.085, 0.09, 0.05, 16), Color("#C98A5C"), Vector3(0, 0.31, 0))
	vp(n, torus(0.088, 0.1, 18), Color("#C9B88A"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	vp(n, sphere(0.02, 8), Color("#FFD34D"), Vector3(0.06, 0.34, 0.05), Vector3.ZERO, Vector3.ONE, false)
	var orb := node(n, Vector3(0, 0.16, 0))
	orb.rotation.x = 0.35
	var spin := node(orb)
	for i in 6:
		var a := -i * 0.32
		var r := 0.065
		var s := 0.03 * (1.0 - i * 0.14)
		vp(spin, sphere(s, 10), Color("#FFFFFF").lerp(Color("#7FE3FF"), i / 5.0), Vector3(cos(a) * r, 0, sin(a) * r), Vector3.ZERO, Vector3.ONE, false)
	for mi in spin.get_children():
		(mi as MeshInstance3D).material_override = gm(3.2)
	bake(spin)
	anim(spin, "spin", {"spd": -2.6})
	halo(n, Vector3(0, 0.16, 0), 0.6, Color(0.6, 0.9, 1.0, 0.42))


## Модель планет: под нитью — солнце, вокруг на спицах пять планет кружат с разной скоростью
func _d_planets(n: Node3D) -> void:
	var c := Vector3(0, 0.2, 0)
	vp(n, torus(0.02, 0.035, 12), BRASS, Vector3(0, 0.5, 0), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	vp(n, cyl(0.01, 0.01, 0.28, 5), BRASS, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
	put(n, sphere(0.07, 16), glow_mat(Color("#FFD34D"), 2.6), c)
	halo(n, c, 0.6, Color(1.0, 0.85, 0.4, 0.45))
	var defs := [[0.17, 0.035, Color("#7FE3FF"), 1.1, 0.0], [0.26, 0.045, Color("#FF8FA0"), 0.7, 2.0], [0.36, 0.05, Color("#B46CFF"), 0.45, 4.0]]
	var i := 0
	for d in defs:
		var r: float = d[0]
		var g := node(n, c)
		vp(g, cyl(0.004, 0.004, r, 3), BRASS, Vector3(r * 0.5, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.35)
		vp(g, sphere(d[1], 14), d[2], Vector3(r, 0, 0))
		if i == 2:
			vp(g, torus(0.065, 0.085, 20), Color("#FFE58A"), Vector3(r, 0, 0), Vector3(0.5, 0, 0.3), Vector3(1, 0.15, 1), false)
		if i == 1:
			vp(g, cyl(0.004, 0.004, r * 0.8, 3), BRASS, Vector3(-r * 0.4, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.35)
			vp(g, sphere(0.03, 12), Color("#3DDC97"), Vector3(-r * 0.8, 0, 0))
		bake(g)
		anim(g, "spin", {"spd": d[3], "p": d[4]})
		i += 1
	vp(n, torus(0.255, 0.265, 40), BRASS, c, Vector3.ZERO, Vector3(1, 0.3, 1), false, 0.35)


## Телескоп: латунная труба на треноге медленно поворачивается к луне; на подоконнике — настольный
func _d_telescope(n: Node3D, sk: String) -> void:
	var small := sk == "ledge"
	var k := 0.55 if small else 1.0
	var hh := 0.72 * k
	for i in 3:
		var a := TAU * i / 3.0 + PI / 2.0
		vp(n, ptube([dir(a) * 0.28 * k, dir(a) * 0.12 * k + Vector3(0, hh * 0.6, 0), Vector3(0, hh, 0)], 0.022 * k, 0.016 * k, 6), WOOD)
		vp(n, sphere(0.028 * k, 8), BRASS, dir(a) * 0.28 * k + Vector3(0, 0.012, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(n, sphere(0.05 * k, 12), BRASS, Vector3(0, hh, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
	var head := node(n, Vector3(0, hh + 0.04 * k, 0))
	var tube_ := node(head)
	tube_.rotation.x = 0.75
	var L := 0.78 * k
	vp(tube_, cyl(0.065 * k, 0.08 * k, L, 20), BRASS, Vector3.ZERO, Vector3(-PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	vp(tube_, cyl(0.09 * k, 0.09 * k, 0.06 * k, 20), Color("#2C3470"), Vector3(0, 0, -L * 0.5), Vector3(-PI / 2.0, 0, 0))
	vp(tube_, cyl(0.07 * k, 0.07 * k, 0.012 * k, 20), Color("#9FE8FF"), Vector3(0, 0, -L * 0.5 - 0.03 * k), Vector3(-PI / 2.0, 0, 0), Vector3.ONE, false, 0.2)
	vp(tube_, cyl(0.035 * k, 0.035 * k, 0.14 * k, 12), Color("#2C3470"), Vector3(0, 0, L * 0.5 + 0.06 * k), Vector3(-PI / 2.0, 0, 0))
	for z in [-0.18, 0.12]:
		vp(tube_, torus(0.075 * k, 0.09 * k, 20), Color("#C48A2A"), Vector3(0, 0, z * k), Vector3(PI / 2.0, 0, 0), Vector3.ONE, false, 0.35)
	vp(tube_, extrude(star_poly(0.04 * k, 0.018 * k), 0.01), Color("#FFE58A"), Vector3(0, 0.082 * k, 0.0), Vector3(-PI / 2.0, 0, 0), Vector3.ONE, false)
	bake(tube_)
	anim(head, "call", {"f": _scope_turn})


func _scope_turn(nd: Node3D, t: float, a: Dictionary) -> void:
	nd.transform = Transform3D(Basis(Vector3.UP, PI + 0.35 * sin(t * 0.23)) * Basis(Vector3.RIGHT, 0.08 * sin(t * 0.31 + 1.0)), a.base.origin)


## ★ Мини-обсерватория: белый купол медленно поворачивается, створка открывает щель, выдвигается телескоп,
## вверх уходит голубой луч с искрами
func _d_observatory(n: Node3D) -> void:
	var wall := Color("#E9E6FF")
	vp(n, cyl(0.5, 0.53, 0.1, 28), Color("#8A7FA8"), Vector3(0, 0.05, 0))
	for k in 14:
		var a := TAU * k / 14.0
		vp(n, box(Vector3(0.2, 0.08, 0.06)), Color("#9C92BC").lerp(Color("#7A6F98"), hash1(k, 3)), dir(a) * 0.5 + Vector3(0, 0.05, 0), Vector3(0, -a + PI / 2.0, 0), Vector3.ONE, false)
	vp(n, cyl(0.42, 0.44, 0.72, 28), wall, Vector3(0, 0.46, 0))
	vp(n, torus(0.41, 0.47, 32), Color("#B9B0E0"), Vector3(0, 0.82, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	# дверь, ступеньки, окошки
	vp(n, box(Vector3(0.22, 0.32, 0.04)), Color("#5A3A6A"), Vector3(0, 0.26, 0.425))
	vp(n, cyl(0.11, 0.11, 0.04, 16), Color("#5A3A6A"), Vector3(0, 0.42, 0.425), Vector3(PI / 2.0, 0, 0))
	vp(n, sphere(0.02, 8), BRASS, Vector3(0.07, 0.27, 0.45), Vector3.ZERO, Vector3.ONE, false, 0.35)
	for k in 2:
		vp(n, box(Vector3(0.3 - k * 0.06, 0.05, 0.12)), Color("#9C92BC"), Vector3(0, 0.125 + k * 0.05, 0.5 - k * 0.04))
	for a in [-0.75, 0.75, 2.3, -2.3]:
		var p := dir(PI / 2.0 + a) * 0.43 + Vector3(0, 0.58, 0)
		vp(n, sphere(0.05, 10), Color("#FFD27A"), p, Vector3(0, -(PI / 2.0 + a) + PI / 2.0, 0), Vector3(1, 1.3, 0.4), false)
	_glowify(n, Color("#FFD27A"), 2.6)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		vp(n, extrude(star_poly(0.045, 0.02), 0.012), Color("#FFD34D"), dir(a) * 0.445 + Vector3(0, 0.3 + 0.12 * (k % 2), 0), Vector3(0, -a + PI / 2.0, 0), Vector3.ONE, false)
	# купол (медленно поворачивается)
	var dome := node(n, Vector3(0, 0.84, 0))
	vp(dome, hemi(0.44, 28), Color("#F7F8FF"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true, 0.4)
	vp(dome, sphere(0.448, 28), Color("#262A5A"), Vector3.ZERO, Vector3.ZERO, Vector3(0.17, 1.0, 1.0), false)
	vp(dome, cyl(0.012, 0.012, 0.22, 5), BRASS, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
	vp(dome, extrude(star_poly(0.07, 0.03), 0.02), Color("#FFD34D"), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3.ONE, true, 0.4)
	# створка: сдвигается вбок, открывая щель
	var shutter := node(dome)
	vp(shutter, sphere(0.452, 28), Color("#DCDDF2"), Vector3.ZERO, Vector3.ZERO, Vector3(0.18, 1.0, 1.0), false)
	bake(shutter)
	anim(shutter, "call", {"f": _shutter})
	# телескоп выдвигается из щели и смотрит в небо
	var scope := node(dome, Vector3(0, 0.12, 0))
	scope.rotation.x = -0.55
	var sc := node(scope)
	vp(sc, cyl(0.055, 0.07, 0.5, 16), BRASS, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(sc, torus(0.06, 0.08, 16), Color("#C48A2A"), Vector3(0, 0.4, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
	var beam := put(sc, cyl(0.2, 0.05, 1.1, 16), smat("owl_beam", BEAM, {"col": Color(0.45, 0.8, 1.0, 0.5)}, false), Vector3(0, 1.05, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sparks := []
	for i in 4:
		var sp := put(sc, sphere(0.022, 6), glow_mat(Color("#BFF0FF"), 4.0), Vector3(0.04 * (i - 1.5), 0.55, 0.02 * (i % 2)))
		anim(sp, "rise", {"h": 1.0, "spd": 0.32, "p": i / 4.0})
		sparks.append(sp)
	halo(sc, Vector3(0, 0.55, 0), 0.55, Color(0.5, 0.85, 1.0, 0.5))
	bake(sc, sparks)
	anim(sc, "call", {"f": _scope_out})
	bake(dome, [shutter, scope])
	anim(dome, "spin", {"spd": 0.12})
	omni(n, Vector3(0, 1.4, 0.4), Color("#8FD8FF"), 0.7, 2.6, "pulse")


func _shutter(nd: Node3D, t: float, a: Dictionary) -> void:
	var o := clampf(sin(t * 0.45) * 2.0 + 0.6, 0.0, 1.0)
	nd.transform = Transform3D(Basis(Vector3.UP, o * 0.42), a.base.origin)


func _scope_out(nd: Node3D, t: float, a: Dictionary) -> void:
	var o := clampf(sin(t * 0.45) * 2.0 + 0.2, 0.0, 1.0)
	nd.transform = Transform3D(Basis.from_scale(Vector3(1, 0.3 + 0.7 * o, 1)), a.base.origin)
	nd.visible = o > 0.05


## Ступка с пестиком (пестик покачивается); «рядом» — стоит на пеньке
func _d_mortar(n: Node3D, sk: String) -> void:
	var y := 0.0
	var k := 0.85 if sk == "ledge" else 1.15
	if sk != "ledge":
		vp(n, cyl(0.17, 0.2, 0.26, 14), Color("#7A5141"), Vector3(0, 0.13, 0))
		vp(n, cyl(0.165, 0.165, 0.01, 14), Color("#E8C48E"), Vector3(0, 0.262, 0), Vector3.ZERO, Vector3.ONE, false)
		vp(n, hemi(0.05, 10), Color("#FF7A5C"), Vector3(0.17, 0.1, 0.1), Vector3.ZERO, Vector3(1, 1.2, 1))
		vp(n, cyl(0.015, 0.02, 0.08, 6), CREAM, Vector3(0.17, 0.05, 0.1))
		y = 0.265
	var g := node(n, Vector3(0, y, 0))
	g.scale = Vector3.ONE * k
	vp(g, lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.13, 0.04), Vector2(0.145, 0.1), Vector2(0.13, 0.125), Vector2(0.11, 0.115), Vector2(0.07, 0.06), Vector2(0.0, 0.055)], 20), Color("#A3ACB0"))
	vp(g, cyl(0.1, 0.1, 0.01, 16), Color("#7FD86A"), Vector3(0, 0.07, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		var a := i * 2.0 + 0.5
		vp(g, sphere(0.035, 8), Color("#3FAF6E").lerp(Color("#9AD86A"), i * 0.4), Vector3(cos(a) * 0.07, 0.11, sin(a) * 0.07), Vector3(0.6, a, 0.3), Vector3(1.6, 0.4, 0.7), false)
	vp(g, sphere(0.02, 6), Color("#B46CFF"), Vector3(0.11, 0.0, 0.1), Vector3.ZERO, Vector3.ONE, false)
	vp(g, sphere(0.016, 6), Color("#FF8FD8"), Vector3(0.14, 0.0, 0.05), Vector3.ZERO, Vector3.ONE, false)
	var pe := node(g, Vector3(0, 0.07, 0))
	vp(pe, capsule(0.026, 0.27), Color("#C7CDD0"), Vector3(0.06, 0.1, 0), Vector3(0, 0, -0.5))
	bake(pe)
	anim(pe, "wiggle", {"axis": Vector3.BACK, "amp": 0.22, "spd": 1.3})


## Сушёные травы: пучки на верёвке (сверху — на палочке на своей бечёвке; на стене — между двух колышков)
func _d_herbs(n: Node3D, sk: String) -> void:
	var g := node(n)
	var y := 0.0
	var z := 0.0
	if sk == "hang":
		vp(n, sphere(0.03, 8), WOOD_D, Vector3.ZERO)
		vp(g, ptube([Vector3(-0.3, -0.32, 0), Vector3(0, 0, 0), Vector3(0.3, -0.32, 0)], 0.007, 0.007, 4), Color("#C9B88A"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		vp(g, cyl(0.022, 0.022, 0.72, 8), WOOD, Vector3(0, -0.33, 0), Vector3(0, 0, PI / 2.0))
		y = -0.33
	else:
		z = 0.07
		y = 0.62
		for sx in [-0.32, 0.32]:
			vp(n, cyl(0.022, 0.026, 0.12, 8), WOOD_D, Vector3(sx, y, 0.06), Vector3(PI / 2.0, 0, 0))
		vp(g, ptube(bez(Vector3(-0.32, y, z + 0.06), Vector3(0, y - 0.1, z + 0.06), Vector3(0.32, y, z + 0.06), 8), 0.007, 0.007, 4), Color("#C9B88A"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var cols := [[Color("#5E9A4A"), Color("#B48CFF")], [Color("#7FB85A"), Color("#FFD34D")], [Color("#4E8A3A"), Color("#FF9EB5")], [Color("#8FC86A"), Color("#FFFFFF")]]
	for i in 4:
		var x := -0.24 + i * 0.16
		var top := Vector3(x, y, 0.0)
		if sk != "hang":
			var s0 := (x + 0.32) / 0.64
			top = Vector3(x, y - 0.2 * s0 * (1.0 - s0), z + 0.06)
		vp(g, torus(0.018, 0.03, 10), Color("#C9B88A"), top + Vector3(0, -0.04, 0), Vector3.ZERO, Vector3.ONE, false)
		for s in 5:
			var off := Vector3((s - 2) * 0.016, 0, (s % 2) * 0.015)
			vp(g, cyl(0.005, 0.005, 0.2, 3), Color("#6B8E3A"), top + off + Vector3(0, -0.1, 0), Vector3(0, 0, (s - 2) * 0.12), Vector3.ONE, false)
			vp(g, sphere(0.04, 7), (cols[i][0] as Color).lerp(Color("#A8D070"), s * 0.15), top + off * 2.4 + Vector3(0, -0.2 - 0.03 * (s % 3), 0), Vector3(s, s * 0.7, 0), Vector3(0.8, 1.7, 0.8), false)
			if s % 2 == 0:
				vp(g, sphere(0.02, 6), cols[i][1], top + off * 2.6 + Vector3(0, -0.27 - 0.02 * s, 0.02), Vector3.ZERO, Vector3.ONE, false)
	bake(g)
	anim(g, "pendulum", {"amp": 0.035, "spd": 0.8})


## Венок из листьев с ягодками; время от времени падает листик
func _d_wreath(n: Node3D, sk: String) -> void:
	var c := Vector3(0, 0.36, 0.07) if sk != "ledge" else Vector3(0, 0.25, 0)
	var g := node(n, c)
	if sk == "ledge":
		g.rotation.x = -0.18
		vp(n, cyl(0.12, 0.13, 0.025, 14), WOOD, Vector3(0, 0.012, 0))
	else:
		vp(n, cyl(0.012, 0.012, 0.08, 5), WOOD_D, Vector3(0, 0.6, 0.04), Vector3(PI / 2.0, 0, 0))
		vp(n, ptube([Vector3(-0.1, 0.5, 0.07), Vector3(0, 0.6, 0.08), Vector3(0.1, 0.5, 0.07)], 0.006, 0.006, 4), Color("#E0556F"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	vp(g, torus(0.15, 0.22, 28), Color("#3F7A3A"), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	var greens := [Color("#4E9A4A"), Color("#6FBF5A"), Color("#8FCB6A"), Color("#D9A13A"), Color("#C9603A")]
	for i in 22:
		var a := TAU * i / 22.0
		var r := 0.185 + 0.03 * sin(i * 2.3)
		vp(g, sphere(0.06, 8), greens[i % greens.size()] if i % 7 else greens[3 + i % 2], Vector3(cos(a) * r, sin(a) * r, 0.03 + 0.01 * (i % 2)), Vector3(0, 0, a + 0.6), Vector3(1.6, 0.6, 0.35), false)
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var r := 0.17 + 0.05 * hash1(i, 3)
		vp(g, sphere(0.022, 8), Color("#E83A50") if i % 3 else Color("#6A5ACD"), Vector3(cos(a) * r, sin(a) * r, 0.065))
	# бантик снизу
	for sx in [-1.0, 1.0]:
		vp(g, prism(Vector3(0.09, 0.07, 0.03)), Color("#FFB86B"), Vector3(sx * 0.05, -0.2, 0.06), Vector3(0, 0, sx * PI / 2.0))
		vp(g, box(Vector3(0.025, 0.1, 0.012)), Color("#FFB86B"), Vector3(sx * 0.03, -0.26, 0.055), Vector3(0, 0, sx * 0.3), Vector3.ONE, false)
	vp(g, sphere(0.022, 8), Color("#FF9E4C"), Vector3(0, -0.2, 0.07))
	# падающий листик
	var leaf := node(g, Vector3(0.12, -0.14, 0.08))
	vp(leaf, sphere(0.04, 8), Color("#D9A13A"), Vector3.ZERO, Vector3.ZERO, Vector3(1.6, 0.6, 0.3))
	bake(leaf)
	anim(leaf, "call", {"f": _leaf_fall})


func _leaf_fall(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t * 0.22, 1.0)
	var fall := smoothstep(0.35, 1.0, u)
	var o: Vector3 = a.base.origin + Vector3(0.06 * sin(u * 18.0) * fall, -0.45 * fall, 0.05 * fall)
	nd.transform = Transform3D(Basis(Vector3.BACK, 0.8 * sin(u * 14.0) * fall) * Basis.from_scale(Vector3.ONE * (1.0 - smoothstep(0.85, 1.0, u))), o)


## Банка светлячков: шесть огоньков летают внутри (две подвижные группы), тряпичная крышка
func _d_fireflies(n: Node3D) -> void:
	vp(n, cyl(0.1, 0.105, 0.02, 18), Color("#C9D8C0"), Vector3(0, 0.01, 0))
	put(n, cyl(0.1, 0.1, 0.24, 20), gl(0.2, 0.05), Vector3(0, 0.14, 0))
	vp(n, sphere(0.12, 16), Color("#E0556F"), Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.0, 0.32, 1.0))
	for k in 8:
		var a := TAU * k / 8.0
		vp(n, sphere(0.02, 6), CREAM, dir(a) * 0.1 + Vector3(0, 0.27, 0), Vector3.ZERO, Vector3.ONE, false)
	vp(n, torus(0.098, 0.11, 18), Color("#C9B88A"), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	vp(n, torus(0.06, 0.075, 16), Color("#9A9A9A"), Vector3(0, 0.33, 0), Vector3(PI / 2.0, 0, 0), Vector3(1, 1.3, 1), false, 0.35)
	for gi in 2:
		var g := node(n, Vector3(0, 0.13 + gi * 0.03, 0))
		for i in 3:
			var a := TAU * i / 3.0 + gi
			vp(g, sphere(0.016, 6), Color("#E8FF7A"), Vector3(cos(a) * (0.035 + 0.025 * gi), (i - 1) * 0.04, sin(a) * (0.035 + 0.025 * gi)), Vector3.ZERO, Vector3.ONE, false)
		for mi in g.get_children():
			(mi as MeshInstance3D).material_override = gm(4.0, 5.0, 0.6)
		bake(g)
		anim(g, "spin", {"spd": 1.3 if gi == 0 else -0.9, "p": gi * 1.5})
	halo(n, Vector3(0, 0.14, 0), 0.7, Color(0.8, 1.0, 0.4, 0.4))


## Бутылочки зелий: четыре разные, жидкость светится пульсом (одна сетка на все бутылки)
func _d_potions(n: Node3D) -> void:
	var defs := [
		[Vector3(-0.17, 0, -0.02), [Vector2(0, 0), Vector2(0.06, 0), Vector2(0.085, 0.05), Vector2(0.07, 0.11), Vector2(0.022, 0.135), Vector2(0.022, 0.19), Vector2(0, 0.19)], Color("#B46CFF"), 0.1],
		[Vector3(-0.04, 0, 0.03), [Vector2(0, 0), Vector2(0.045, 0), Vector2(0.048, 0.2), Vector2(0.02, 0.24), Vector2(0.018, 0.29), Vector2(0, 0.29)], Color("#3DDC97"), 0.19],
		[Vector3(0.09, 0, -0.03), [Vector2(0, 0), Vector2(0.08, 0), Vector2(0.03, 0.13), Vector2(0.022, 0.18), Vector2(0, 0.18)], Color("#FF8FD8"), 0.07],
		[Vector3(0.19, 0, 0.05), [Vector2(0, 0), Vector2(0.03, 0), Vector2(0.032, 0.12), Vector2(0, 0.12)], Color("#FFB547"), 0.1],
	]
	vp(n, box(Vector3(0.5, 0.02, 0.2)), WOOD, Vector3(0.01, 0.01, 0.0))
	var i := 0
	for d in defs:
		var p: Vector3 = d[0] + Vector3(0, 0.02, 0)
		var prof: Array = d[1]
		var col: Color = d[2]
		put(n, lathe(prof, 16, Color(0.85, 0.95, 1.0)), gl(0.22, 0.0), p)
		var inner := []
		for v in prof:
			inner.append(Vector2(maxf(0.0, (v as Vector2).x - 0.008), minf((v as Vector2).y, d[3])))
		put(n, lathe(inner, 14, col), gm(2.0, 1.6 + i * 0.4, 0.45), p + Vector3(0, 0.006, 0))
		var top: float = (prof[prof.size() - 1] as Vector2).y
		vp(n, cyl(0.022, 0.018, 0.04, 8), Color("#C98A5C"), p + Vector3(0, top + 0.015, 0))
		if i == 3:
			vp(n, extrude(heart_poly(0.045), 0.02), Color("#FF5C8A"), p + Vector3(0, top + 0.06, 0))
		elif i != 2:
			vp(n, box(Vector3(0.05, 0.035, 0.005)), CREAM, p + Vector3(0, 0.06, (prof[1] as Vector2).x + 0.005), Vector3.ZERO, Vector3.ONE, false)
		i += 1
	halo(n, Vector3(0, 0.12, 0.05), 0.75, Color(0.7, 0.5, 1.0, 0.3))


## Друза кристаллов: фиолетовые призмы переливаются (свой шейдер — одна сетка на все призмы)
func _d_crystals(n: Node3D, sk: String) -> void:
	var k := 0.75 if sk == "ledge" else 1.3
	vp(n, sphere(0.2 * k, 12), Color("#6E6A80"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.3, 0.45, 1.0))
	vp(n, sphere(0.1 * k, 10), Color("#8A86A0"), Vector3(0.18 * k, 0.02, 0.06 * k), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	var m := smat("owl_shimmer", SHIMMER, {"energy": 1.1})
	var defs := [[Vector3(0, 0.04, 0), 0.5, 0.075, Vector3(0.05, 0, 0.0), Color("#B46CFF")], [Vector3(-0.1, 0.04, 0.04), 0.34, 0.06, Vector3(0.15, 0, 0.45), Color("#D08CFF")],
		[Vector3(0.1, 0.04, -0.02), 0.38, 0.065, Vector3(-0.2, 0, -0.4), Color("#8A5CFF")], [Vector3(0.03, 0.04, 0.11), 0.24, 0.05, Vector3(0.55, 0, 0.1), Color("#FF8FD8")],
		[Vector3(-0.06, 0.04, -0.1), 0.28, 0.05, Vector3(-0.5, 0, 0.2), Color("#9FE8FF")], [Vector3(0.16, 0.03, 0.08), 0.18, 0.04, Vector3(0.3, 0, -0.7), Color("#C38BFF")]]
	for d in defs:
		var c := node(n, (d[0] as Vector3) * k)
		c.rotation = d[3]
		var h: float = d[1] * k
		var r: float = d[2] * k
		put(c, vc(cyl(r, r * 0.9, h * 0.72, 6), d[4]), m, Vector3(0, h * 0.36, 0))
		put(c, vc(cyl(0.0, r, h * 0.28, 6), d[4]), m, Vector3(0, h * 0.86, 0))
	halo(n, Vector3(0, 0.25 * k, 0), 0.8 * k, Color(0.75, 0.5, 1.0, 0.3))


## Волшебный посох: кристалл наверху вращается и светится; на стене — на двух колышках, рядом — в камне
func _d_staff(n: Node3D, sk: String) -> void:
	var g := node(n)
	var L := 1.05
	if sk == "wall":
		g.position = Vector3(0, 0.02, 0.1)
		g.rotation.z = -0.32
		L = 0.86
		for y in [0.2, 0.6]:
			vp(n, cyl(0.018, 0.022, 0.12, 6), WOOD_D, Vector3(-sin(-0.32) * y, cos(0.32) * y + 0.02, 0.05), Vector3(PI / 2.0, 0, 0))
	else:
		vp(n, sphere(0.16, 12), Color("#7A7690"), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.2, 0.5, 1.0))
		vp(n, sphere(0.1, 10), Color("#5E9A4A"), Vector3(0.08, 0.08, 0.05), Vector3.ZERO, Vector3(1.2, 0.45, 1.0), false)
	var pts := []
	for i in 9:
		var s := i / 8.0
		pts.append(Vector3(0.02 * sin(s * 9.0), s * L, 0.02 * cos(s * 7.0)))
	vp(g, ptube(pts, 0.028, 0.022, 7), Color("#8A5A3A"))
	for i in 3:
		var a := TAU * i / 3.0
		vp(g, ptube(bez(Vector3(0, L - 0.02, 0), dir(a) * 0.08 + Vector3(0, L + 0.06, 0), dir(a) * 0.03 + Vector3(0, L + 0.17, 0), 5), 0.016, 0.008, 5), Color("#8A5A3A"))
	vp(g, torus(0.026, 0.04, 12), Color("#E0556F"), Vector3(0, L - 0.12, 0), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	vp(g, ptube([Vector3(0.03, L - 0.12, 0), Vector3(0.06, L - 0.22, 0.02), Vector3(0.05, L - 0.32, 0.03)], 0.012, 0.006, 4), Color("#E0556F"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	vp(g, sphere(0.03, 8), Color("#6FBF5A"), Vector3(-0.04, L - 0.15, 0.02), Vector3(0, 0, 0.5), Vector3(1.6, 0.6, 0.6), false)
	var cr := node(g, Vector3(0, L + 0.1, 0))
	crystal(cr, Vector3(0, -0.08, 0), 0.2, 0.05, Vector3.ZERO, Color("#5FF0C8"), 1.6)
	bake(cr)
	anim(cr, "spin", {"spd": 1.4})
	halo(g, Vector3(0, L + 0.1, 0), 0.6, Color(0.4, 1.0, 0.8, 0.45))


## Книга заклинаний на подставке: страницы листаются, руны светятся, вверх летят искорки
func _d_spellbook(n: Node3D) -> void:
	for r in [0.0, PI / 2.0]:
		vp(n, box(Vector3(0.38, 0.05, 0.07)), WOOD_D, Vector3(0, 0.025, 0), Vector3(0, r + 0.4, 0))
	vp(n, cyl(0.04, 0.055, 0.52, 10), WOOD, Vector3(0, 0.28, 0))
	vp(n, torus(0.04, 0.065, 12), Color("#7A5141"), Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	var top := node(n, Vector3(0, 0.56, 0.0))
	top.rotation.x = 0.42
	vp(top, box(Vector3(0.46, 0.035, 0.32)), WOOD, Vector3.ZERO)
	vp(top, box(Vector3(0.46, 0.05, 0.03)), WOOD_D, Vector3(0, 0.02, 0.16))
	vp(top, box(Vector3(0.44, 0.02, 0.3)), Color("#5A2E7A"), Vector3(0, 0.03, 0))
	for sx in [-1.0, 1.0]:
		vp(top, box(Vector3(0.2, 0.035, 0.27)), CREAM, Vector3(sx * 0.105, 0.055, 0), Vector3(0, 0, sx * 0.06))
		for k in 4:
			var w := 0.05 + 0.08 * hash1(k, int(sx + 3))
			vp(top, box(Vector3(w, 0.004, 0.014)), Color("#7FD86A"), Vector3(sx * 0.105 + (w - 0.1) * 0.3, 0.075 + 0.006 * (1 if sx > 0 else 0), -0.08 + k * 0.05), Vector3(0, 0, sx * 0.06), Vector3.ONE, false)
	vp(top, torus(0.03, 0.045, 14), Color("#7FD86A"), Vector3(0.105, 0.08, 0.075), Vector3.ZERO, Vector3(1, 0.3, 1), false)
	for mi in top.get_children():
		var m := mi as MeshInstance3D
		if _mesh_col(m.mesh) == Color("#7FD86A"):
			m.material_override = gm(2.4, 1.8, 0.4)
	vp(top, box(Vector3(0.02, 0.01, 0.2)), Color("#E0556F"), Vector3(0.04, 0.07, 0.17), Vector3.ZERO, Vector3.ONE, false)
	var page := node(top, Vector3(0, 0.072, 0))
	vp(page, box(Vector3(0.19, 0.004, 0.26)), Color("#FFF8EA"), Vector3(0.095, 0, 0), Vector3.ZERO, Vector3.ONE, false)
	bake(page)
	anim(page, "call", {"f": _page_turn})
	for i in 4:
		var sp := put(top, sphere(0.014, 6), glow_mat(Color("#C8FF8A"), 4.0), Vector3(-0.1 + i * 0.07, 0.08, -0.04 + 0.03 * (i % 2)))
		anim(sp, "rise", {"h": 0.38, "spd": 0.4, "p": i / 4.0})
	halo(top, Vector3(0, 0.12, 0), 0.75, Color(0.6, 1.0, 0.45, 0.35))


func _page_turn(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t * 0.3, 1.0)
	var ang := PI * smoothstep(0.2, 0.7, u)
	nd.transform = Transform3D(Basis(Vector3.BACK, ang * 0.98), a.base.origin + Vector3(0, 0.03 * sin(ang), 0))
	nd.visible = u < 0.9


## ★ Котёл зелий: зелёная жидкость бурлит, пузыри лопаются, пар меняет цвет, снизу светятся угли
func _d_cauldron(n: Node3D, sk: String) -> void:
	var k := 1.3 if sk == "big" else 0.85
	var g := node(n)
	g.scale = Vector3.ONE * k
	var iron := Color("#3B3654")
	# угли и поленья
	vp(g, cyl(0.36, 0.38, 0.05, 16), Color("#5E5872"), Vector3(0, 0.025, 0))
	for k2 in 8:
		var a := TAU * k2 / 8.0
		vp(g, sphere(0.07, 8), Color("#8A86A0").lerp(Color("#6E6A80"), hash1(k2, 2)), dir(a) * 0.36 + Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.2, 0.7, 1.0))
	for a in [0.4, -0.5]:
		vp(g, capsule(0.04, 0.4), WOOD_D, Vector3(0, 0.08, 0), Vector3(0, a, PI / 2.0))
	for k2 in 6:
		var a := TAU * k2 / 6.0
		vp(g, sphere(0.035, 6), Color("#FF7A2A").lerp(Color("#FFD34D"), hash1(k2, 4)), dir(a) * 0.12 + Vector3(0, 0.07, 0), Vector3.ZERO, Vector3.ONE, false)
	for mi in g.get_children():
		var m := mi as MeshInstance3D
		var cc := _mesh_col(m.mesh)
		if cc.r > 0.9 and cc.g < 0.9:
			m.material_override = gm(3.0, 3.0, 0.4)
	for k2 in 3:
		var f := put(g, cyl(0.0, 0.05, 0.14, 8), glow_mat(Color("#FF9E3A"), 3.5), dir(k2 * 2.1) * 0.06 + Vector3(0, 0.13, 0))
		anim(f, "flame", {"p": k2 * 1.3})
	# котёл
	vp(g, lathe([Vector2(0.0, 0.12), Vector2(0.18, 0.13), Vector2(0.31, 0.22), Vector2(0.36, 0.36), Vector2(0.33, 0.5), Vector2(0.29, 0.55), Vector2(0.27, 0.56)], 24), iron, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true, 0.45)
	vp(g, torus(0.26, 0.32, 28), Color("#4A4566"), Vector3(0, 0.56, 0), Vector3.ZERO, Vector3(1, 0.7, 1), true, 0.45)
	for k2 in 3:
		var a := TAU * k2 / 3.0 + 0.5
		vp(g, capsule(0.035, 0.2), iron, dir(a) * 0.24 + Vector3(0, 0.12, 0), Vector3(0, -a, 0.3))
	for sx in [-1.0, 1.0]:
		vp(g, torus(0.05, 0.07, 14), Color("#4A4566"), Vector3(sx * 0.35, 0.47, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, true, 0.45)
	# руна на боку
	vp(g, torus(0.05, 0.065, 16), Color("#7FD86A"), Vector3(0, 0.36, 0.355), Vector3(PI / 2.0 - 0.2, 0, 0), Vector3.ONE, false)
	for mi in g.get_children():
		var m := mi as MeshInstance3D
		if _mesh_col(m.mesh) == Color("#7FD86A"):
			m.material_override = gm(2.0, 2.0, 0.5)
	# жидкость (свой шейдер — водоворот и пятна)
	put(g, cyl(0.285, 0.285, 0.02, 28), smat("owl_brew", BREW, {}, false), Vector3(0, 0.54, 0))
	for i in 5:
		var b := put(g, sphere(0.035 + 0.01 * (i % 2), 8), glow_mat(Color("#9CFF6A"), 1.8), dir(i * 1.3) * (0.08 + 0.03 * i) + Vector3(0, 0.55, 0))
		anim(b, "rise", {"h": 0.12, "spd": 0.7 + 0.1 * i, "p": i / 5.0})
	# пар меняет цвет
	var steam := StandardMaterial3D.new()
	steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam.albedo_color = Color(0.6, 1.0, 0.6, 0.45)
	steam.emission_enabled = true
	steam.emission = Color(0.4, 1.0, 0.5)
	steam.emission_energy_multiplier = 0.7
	steam.roughness = 1.0
	for i in 4:
		var s := put(g, sphere(0.08, 10), steam, dir(i * 1.7) * 0.06 + Vector3(0, 0.6, 0))
		anim(s, "rise", {"h": 0.55, "spd": 0.22, "p": i / 4.0})
	anim(node(n), "call", {"f": _steam_col.bind(steam)})
	if sk == "big":
		# черпак и ингредиенты рядом
		var ladle := node(g, Vector3(0.12, 0.55, -0.05))
		vp(ladle, cyl(0.014, 0.014, 0.5, 6), WOOD, Vector3(0, 0.2, 0), Vector3(0, 0, -0.35))
		bake(ladle)
		anim(ladle, "wiggle", {"axis": Vector3.UP, "amp": 0.6, "spd": 0.5})
		vp(g, cyl(0.06, 0.06, 0.16, 12), Color("#C98A5C"), Vector3(-0.45, 0.08, 0.2))
		vp(g, sphere(0.06, 10), Color("#7FD86A"), Vector3(-0.45, 0.2, 0.2), Vector3.ZERO, Vector3(1, 0.5, 1), false)
		put(g, lathe([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.06, 0.07), Vector2(0.02, 0.11), Vector2(0.02, 0.14), Vector2(0, 0.14)], 12, Color("#FF8FD8")), gm(1.8, 2.0, 0.4), Vector3(0.45, 0.0, 0.22))
		_mushroom(g, Vector3(-0.38, 0.0, -0.15), 0.6, Color("#7FF5E0"))
	halo(g, Vector3(0, 0.62, 0), 1.0, Color(0.5, 1.0, 0.45, 0.4))
	halo(g, Vector3(0, 0.1, 0.1), 0.6, Color(1.0, 0.55, 0.2, 0.4))
	omni(n, Vector3(0, 0.75 * k, 0.25), Color("#8CFF7A"), 0.9, 2.6, "pulse")


func _steam_col(_nd: Node3D, t: float, _a: Dictionary, m: StandardMaterial3D) -> void:
	var c := Color.from_hsv(fposmod(0.33 + 0.12 * sin(t * 0.35) + 0.25 * (0.5 + 0.5 * sin(t * 0.17)), 1.0), 0.45, 1.0)
	m.albedo_color = Color(c, 0.42)
	m.emission = c


const OWL_STARMAP := """
shader_type spatial;
render_mode cull_back;
const vec2 P[14] = vec2[14](vec2(0.18, 0.25), vec2(0.28, 0.2), vec2(0.38, 0.27), vec2(0.45, 0.2), vec2(0.36, 0.38),
	vec2(0.6, 0.55), vec2(0.7, 0.45), vec2(0.8, 0.52), vec2(0.74, 0.66), vec2(0.62, 0.7),
	vec2(0.2, 0.6), vec2(0.3, 0.72), vec2(0.22, 0.84), vec2(0.4, 0.82));
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = vec2(UV.x, UV.y * 1.06);
	vec3 c = mix(vec3(0.05, 0.06, 0.2), vec3(0.1, 0.08, 0.3), UV.y);
	float b = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	vec3 gold = vec3(1.0, 0.75, 0.3);
	float frame = smoothstep(0.012, 0.0, abs(b - 0.045));
	vec3 em = gold * frame * 0.5;
	c = mix(c, gold * 0.6, frame);
	vec2 g = UV * vec2(18.0, 20.0);
	vec2 id = floor(g);
	if (h21(id) > 0.8) {
		float d = length(fract(g) - 0.5);
		em += vec3(0.8, 0.85, 1.0) * smoothstep(0.12, 0.0, d) * (0.5 + 0.5 * sin(TIME * 2.0 + h21(id) * 40.0));
	}
	float seq = mod(TIME * 1.6, 16.0);
	for (int i = 0; i < 14; i++) {
		vec2 p = P[i];
		float on = smoothstep(1.5, 0.0, abs(seq - float(i)));
		float d = length(UV - p);
		float star = smoothstep(0.022 + 0.012 * on, 0.0, d);
		float cr = smoothstep(0.004, 0.0, min(abs(UV.x - p.x), abs(UV.y - p.y))) * smoothstep(0.05 + 0.03 * on, 0.0, d);
		em += vec3(1.0, 0.92, 0.65) * max(star, cr) * (0.9 + 2.2 * on);
		c = mix(c, vec3(1.0, 0.95, 0.75), star);
		if (i != 4 && i != 9 && i != 13) {
			float l = smoothstep(0.004, 0.0, seg(UV, P[i], P[i + 1]));
			em += gold * l * (0.35 + 0.8 * on);
		}
	}
	float mo = length(UV - vec2(0.82, 0.2));
	float moon = smoothstep(0.075, 0.068, mo) * smoothstep(0.055, 0.062, length(UV - vec2(0.85, 0.18)));
	em += vec3(1.0, 0.9, 0.6) * moon * 1.2;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = em;
}
"""

const SHIMMER := """
shader_type spatial;
uniform float energy = 1.1;
varying vec3 lp;
void vertex() { lp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float ph = TIME * 0.7 + lp.y * 5.0 + lp.x * 3.0 + lp.z * 2.0;
	vec3 shift = 0.55 + 0.45 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + ph * 0.12));
	vec3 c = mix(base, base * shift * 1.8, 0.5);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = c * 0.7;
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
	EMISSION = c * energy * (0.65 + 0.35 * sin(ph * 1.7)) + vec3(0.9, 0.8, 1.0) * fres * 0.5;
}
"""

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.45, 0.8, 1.0, 0.5);
void fragment() {
	float v = UV.y;
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.4);
	float flick = 0.75 + 0.25 * sin(TIME * 3.0 + UV.x * 18.0 - v * 6.0);
	ALBEDO = col.rgb * col.a * smoothstep(0.0, 0.5, v) * edge * flick;
}
"""

const BREW := """
shader_type spatial;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 p = lp.xz / 0.285;
	float r = length(p);
	float a = atan(p.y, p.x);
	float sw = sin(a * 3.0 + r * 9.0 - TIME * 2.2) * 0.5 + 0.5;
	float spots = smoothstep(0.75, 0.95, sin(p.x * 13.0 + TIME * 1.3) * sin(p.y * 11.0 - TIME * 1.1));
	vec3 c = mix(vec3(0.12, 0.7, 0.18), vec3(0.55, 1.0, 0.35), sw * 0.7 + spots * 0.6);
	ALBEDO = c * 0.4;
	EMISSION = c * (1.3 + 0.4 * sin(TIME * 2.0));
	ROUGHNESS = 0.3;
}
"""


# ---------- 0.15: «игрушечные» детали с цветом в вершинах ----------
## Неподвижные детали вещи с одним материалом склеиваются в одну сетку (merge_static). Раньше у каждого цвета
## был свой материал — вещь из 8 цветов давала 8+ вызовов отрисовки; здесь цвет хранится в вершинах сетки,
## материалов всего несколько (матовый / блестящий, с обводкой / без), и вещь рисуется за 2–4 вызова.
static var _vc_cache := {}
static var _tm_cache := {}
static var _sh_cache := {}


## Копия сетки с цветом в вершинах (кэш: одна копия на сетку и цвет)
static func vc(m: Mesh, col: Color) -> ArrayMesh:
	var key := [m, col]
	if _vc_cache.has(key):
		return _vc_cache[key]
	var arr := m.surface_get_arrays(0)
	var cols := PackedColorArray()
	cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(col)
	arr[Mesh.ARRAY_COLOR] = cols
	# у всех — индексы: иначе при склейке с индексированными сетками (шар, коробка) трубки пропадают
	if arr[Mesh.ARRAY_INDEX] == null:
		var idx := PackedInt32Array()
		idx.resize(cols.size())
		for i in cols.size():
			idx[i] = i
		arr[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_vc_cache[key] = out
	return out


## Материал «игрушки» с цветом из вершин (как kit.mat: бархатный край, тёмная обводка)
static func tm(outline := true, rough := 0.85) -> StandardMaterial3D:
	var key := [outline, rough]
	if _tm_cache.has(key):
		return _tm_cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic_specular = 0.25 if rough > 0.5 else 0.6
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if outline:
		m.next_pass = outline_mat()
	_tm_cache[key] = m
	return m


## Деталь с цветом в вершинах (outline — обводка; rough < 0.5 — блестящая: латунь, стекло, лак)
func vp(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, outline := true, rough := 0.85) -> MeshInstance3D:
	return put(parent, vc(mesh, col), tm(outline, rough), pos, rot, scl)


## Свой шейдер (кэш на всю игру); материал с пометкой merge — склеивается с такими же деталями вещи
static func smat(name: String, code: String, params := {}, merge := true) -> ShaderMaterial:
	if not _sh_cache.has(name):
		var s := Shader.new()
		s.code = code
		_sh_cache[name] = s
	var m := ShaderMaterial.new()
	m.shader = _sh_cache[name]
	for k in params:
		m.set_shader_parameter(k, params[k])
	if merge:
		m.set_meta("merge", true)
	return m


static var _gm_cache := {}


## Светящийся материал с цветом из вершин: энергия, пульс (скорость; 0 — ровно), сдвиг фазы по месту детали.
## Все светящиеся неподвижные детали вещи одной энергии — один вызов отрисовки, даже разных цветов.
static func gm(energy := 2.0, pulse := 0.0, amp := 0.35) -> ShaderMaterial:
	var key := [energy, pulse, amp]
	if _gm_cache.has(key):
		return _gm_cache[key]
	var m := smat("glowvc", GLOW_VC, {"energy": energy, "pulse": pulse, "amp": amp})
	_gm_cache[key] = m
	return m


static var _gl_cache := {}


## Прозрачное стекло с цветом из вершин (бутылки, банки): склеивается в одну сетку на вещь
static func gl(alpha := 0.35, emit := 0.0) -> ShaderMaterial:
	var key := [alpha, emit]
	if _gl_cache.has(key):
		return _gl_cache[key]
	var m := smat("glassvc", GLASS_VC, {"alpha": alpha, "emit": emit})
	_gl_cache[key] = m
	return m


## Склеить детали подвижной группы (она двигается целиком; keep — вложенные подвижные узлы)
func bake(g: Node3D, keep := []) -> void:
	merge_static(g, keep)


const GLOW_VC := """
shader_type spatial;
uniform float energy = 2.0;
uniform float pulse = 0.0;
uniform float amp = 0.35;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float ph = dot(floor(lp * 9.0), vec3(1.7, 2.3, 1.1));
	float k = pulse > 0.0 ? 1.0 - amp + amp * sin(TIME * pulse + ph) : 1.0;
	ALBEDO = c * 0.35;
	ROUGHNESS = 0.4;
	EMISSION = c * energy * k;
}
"""

const GLASS_VC := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform float alpha = 0.35;
uniform float emit = 0.0;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = c;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	EMISSION = c * emit + vec3(0.9, 0.95, 1.0) * fres * 0.35;
	ALPHA = clamp(alpha + fres * 0.45, 0.0, 1.0);
}
"""


## Трубка по точкам без перекрутов (рамка переносится вдоль трубки — вертикальные волнистые трубки не
## «схлопываются», как у kit.tube). UV.y — доля длины (для шейдера «sway»). Сетка с индексами.
static func ptube(pts: Array, r0: float, r1: float, sides := 6, col := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var f0: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var side := f0.cross(Vector3.UP if absf(f0.y) < 0.9 else Vector3.RIGHT).normalized()
	for i in n:
		var p: Vector3 = pts[i]
		var fwd: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		side = (side - fwd * side.dot(fwd)).normalized()
		var up := side.cross(fwd).normalized()
		var r := lerpf(r0, r1, float(i) / (n - 1))
		for k in sides + 1:
			var a := TAU * k / sides
			var d := side * cos(a) + up * sin(a)
			st.set_color(col)
			st.set_uv(Vector2(float(k) / sides, float(i) / (n - 1)))
			st.set_normal(d)
			st.add_vertex(p + d * r)
	var ring := sides + 1
	for i in n - 1:
		for k in sides:
			var a0 := i * ring + k
			var b0 := (i + 1) * ring + k
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	var m := st.commit()
	return _fix_winding(m)


## Если треугольники трубки смотрят внутрь — развернуть (одна проверка на первом треугольнике)
static func _fix_winding(m: ArrayMesh) -> ArrayMesh:
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.size() < 3:
		return m
	var a := v[idx[0]]
	var b := v[idx[1]]
	var c := v[idx[2]]
	if (b - a).cross(c - a).dot(nr[idx[0]] + nr[idx[1]] + nr[idx[2]]) > 0.0:
		for i in range(0, idx.size(), 3):
			var t := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = t
		arr[Mesh.ARRAY_INDEX] = idx
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return out
	return m
