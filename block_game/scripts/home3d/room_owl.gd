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
	var defs := {
		"floor_l": [deg_to_rad(205.0), 2.05, 0.0], "floor_r": [deg_to_rad(-25.0), 2.1, 0.0],
		"wall_l": [deg_to_rad(222.0), 0.0, 1.62], "wall_r": [deg_to_rad(-50.0), 0.0, 1.45],
		"hang": [deg_to_rad(-140.0), 1.45, 3.55], "near": [deg_to_rad(28.0), 1.12, 0.0],
	}
	for s in defs:
		var d: Array = defs[s]
		var a: float = d[0]
		var r: float = d[1]
		var mark := Vector3(0, 0.3, 0)
		if s.begins_with("wall"):
			r = wall_r(d[2]) - 0.04
			mark = Vector3(0, 0.3, 0.32)
		elif s == "hang":
			mark = Vector3(0, -0.85, 0)
		spots[s] = {"pos": dir(a) * r + Vector3(0, d[2], 0), "yaw": face_center(a), "mark": mark, "stand": Vector3(0, 0.07, 0.24)}
	# 0.14: полка славы — на стене напротив окна (за спиной камеры в обычном обзоре; места украшений не занимает)
	shelf_def = {"style": "owl", "pos": dir(PI / 2.0) * R, "yaw": face_center(PI / 2.0), "room_r": R,
		"rows": [[1.2, wall_r(1.2) - 0.06], [1.78, wall_r(1.78) - 0.06]], "spacing": 0.42, "scale": 1.15, "depth": 0.34,
		"plaque_z": 0.205, "plaque_y": -0.03, "focus_d": 0.72, "view_d": 2.0}


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
	# грибы-трутовики на стенах — маленькие «полочки» для уюта (больше на поздних ступенях)
	var n_f := 3 if stage == 0 else 5
	for k in n_f:
		var a: float = [WIN_ANG + 2.2, WIN_ANG + 3.8, WIN_ANG + 5.6, WIN_ANG + 2.55, WIN_ANG + 4.6][k]
		var hy: float = [1.1, 0.8, 1.3, 2.5, 2.2][k]
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
	# опавшие листики по полу (MultiMesh — дёшево)
	var xfs := []
	var leaf_cols := [Color("#C98A3E"), Color("#B5603A"), Color("#D6AE55"), Color("#7FA552"), Color("#A85A5E")]
	for i in 55:
		var a := hash1(i, 1) * TAU
		var rr := 1.05 + hash1(i, 2) * 1.55
		var b := Basis(Vector3.UP, hash1(i, 3) * TAU) * Basis(Vector3.RIGHT, 0.15 * (hash1(i, 4) - 0.5)) * Basis.from_scale(Vector3(0.6, 0.12, 1.0) * (0.8 + 0.5 * hash1(i, 6)))
		xfs.append(Transform3D(b, dir(a) * rr + Vector3(0, 0.025 + 0.18 * pow(rr / R, 4.0), 0)))
	scatter(h, sphere(0.05, 8), vmat(0.9, 0.2), xfs, leaf_cols)
	# мягкие кочки мха у стен
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var skip := false
		for s in ["floor_l", "floor_r"]:
			var sp: Vector3 = spots[s].pos
			if absf(angle_difference(a, atan2(sp.z, sp.x))) < 0.35:
				skip = true
		if skip:
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
		var a := 0.6 + i * 1.25
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
			var a := deg_to_rad([5.0, 50.0, 124.0, 145.0, 175.0][i])
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
