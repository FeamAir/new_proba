extends "res://scripts/home3d/room.gd"
## Подводный грот аксолотля в 3D: круглая пещера из гладких камней, сверху — окно на поверхность
## воды, откуда падают лучи света; на песчаном дне бегут блики-каустика, поднимаются пузырьки,
## колышутся водоросли, светятся кристаллы. В центре — мягкая подушка из морской губки, над ней
## покачивается аксолотль.
## Ступени богатства (Meta.home_stage):
##   0 — камни, немного водорослей и кристаллов;  1 — актинии и ракушки на песке, больше водорослей;
##   2 — светящиеся самоцветы на стенах и медуза;  3 — стайка светящихся рыбок кружит под сводом.

const R := 3.2
const WALL_H := 2.4
const TOP_H := 3.75
const HOLE := 0.95

static var _geo := {}
var _sway: ShaderMaterial


static func wall_r(y: float) -> float:
	if y <= WALL_H:
		return R * (1.0 + 0.05 * sin(y / WALL_H * PI) - 0.04 * y / WALL_H)
	var s := clampf((y - WALL_H) / (TOP_H - WALL_H), 0.0, 1.0)
	return lerpf(R * 0.96, HOLE, s * s * (3.0 - 2.0 * s))


func _init() -> void:
	kind = "axolotl"
	hang_style = "rope"
	rope_len = 0.7
	hero_feet = Vector3(0, 0.5, 0)
	hero_bob = 0.045
	var defs := {
		"floor_l": [deg_to_rad(200.0), 2.1, 0.0], "floor_r": [deg_to_rad(-20.0), 2.2, 0.0],
		"wall_l": [deg_to_rad(218.0), 0.0, 1.3], "wall_r": [deg_to_rad(-42.0), 0.0, 1.15],
		"hang": [deg_to_rad(-120.0), 0.62, TOP_H + 0.02], "near": [deg_to_rad(32.0), 1.08, 0.0],
	}
	for s in defs:
		var d: Array = defs[s]
		var a: float = d[0]
		var r: float = d[1]
		var mark := Vector3(0, 0.3, 0)
		if s.begins_with("wall"):
			r = wall_r(d[2]) - 0.05
			mark = Vector3(0, 0.3, 0.34)
		elif s == "hang":
			mark = Vector3(0, -1.05, 0)
		spots[s] = {"pos": dir(a) * r + Vector3(0, d[2], 0), "yaw": face_center(a), "mark": mark, "stand": Vector3(0, 0.04, 0.24)}
	# 0.15: места-заготовки (типы — scripts/decor_data/axolotl.gd): уступ на стене слева (выше «стены слева»),
	# большое место у дальней стены, второе «рядом» — слева от героя
	var sa := deg_to_rad(240.0)
	spots["ledge_l"] = {"pos": dir(sa) * (wall_r(1.6) - 0.05) + Vector3(0, 1.6, 0), "yaw": face_center(sa), "mark": Vector3(0, 0.3, 0.34),
		"stand": Vector3(0, 0.04, 0.24)}
	var ba := deg_to_rad(275.0)
	spots["big_back"] = {"pos": dir(ba) * 2.3, "yaw": face_center(ba), "mark": Vector3(0, 0.45, 0)}
	var na := deg_to_rad(148.0)
	spots["near_2"] = {"pos": dir(na) * 1.08, "yaw": face_center(na), "mark": Vector3(0, 0.3, 0)}
	# 0.14: полка славы — каменная ниша напротив входа камеры (за спиной камеры в обычном обзоре)
	shelf_def = {"style": "axolotl", "pos": dir(PI / 2.0) * R, "yaw": face_center(PI / 2.0), "room_r": R,
		"rows": [[1.28, wall_r(1.28) - 0.04], [1.78, wall_r(1.78) - 0.04]], "spacing": 0.37, "scale": 1.0, "depth": 0.3,
		"plaque_z": 0.205, "plaque_y": -0.035, "focus_d": 0.64, "view_d": 1.9}
	trophy_light = 1.05


func _inside(p: Vector3) -> bool:
	var rr := Vector2(p.x, p.z).length()
	return (rr < R - 0.85 or (rr < R - 0.5 and p.y < 2.2 and p.z > 1.5)) and p.y > 0.15 and p.y < 3.15


func _setup_camera(c: Camera3D) -> void:
	c.home_pivot = Vector3(0, 0.95, 0)
	c.home_dist = 2.5
	c.dist_max = 2.7


# ---------- Окружение ----------

func _environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0A2A44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7FB8CC")
	env.ambient_light_energy = 0.62 + 0.05 * stage
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("#1E6F8C")
	env.fog_density = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	world_env.environment = env
	add_child(world_env)


func _build_house(h: Node3D) -> void:
	_sway = Shaders.material("sway", {"amp": 0.1, "speed": 1.2})
	_sway.set_meta("merge", true)
	_walls(h)
	_floor(h)
	_surface(h)
	_cushion(h)
	_weeds(h)
	_crystals(h)
	_extras(h)
	# пузырьки по всему гроту
	shader_swarm(h, "bubbles", 14 + stage * 6, {"height": 3.6, "radius": 2.6, "size": 0.05})


# ---------- Стены из гладких камней ----------

func _walls(h: Node3D) -> void:
	if not _geo.has("walls"):
		_geo["walls"] = _wall_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["walls"]
	mi.material_override = vmat(0.8, 0.3)
	h.add_child(mi)
	wall_parts.append(mi)  # 0.15: стиль «стены»
	# крупные валуны у подножия
	for i in 8:
		var a := TAU * i / 8.0 + 0.25
		var skip := false
		for s in ["floor_l", "floor_r", "wall_l", "wall_r"]:
			var sp: Vector3 = spots[s].pos
			if absf(angle_difference(a, atan2(sp.z, sp.x))) < 0.32:
				skip = true
		if skip:
			continue
		var p := dir(a) * (R - 0.25) + Vector3(0, 0.15, 0)
		var k := 0.8 + hash1(i, 3) * 0.6
		put(h, sphere(0.45 * k, 14), mat(Color("#2C5A80").lerp(Color("#3D6E8E"), hash1(i, 4)), 0.7), p, Vector3(0, hash1(i, 5) * 3.0, 0), Vector3(1.2, 0.7, 0.9))
		put(h, sphere(0.25 * k, 12), mat(Color("#3F7FA0"), 0.7, 0.0, false), p + dir(a + 0.4) * 0.35 * k + Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1.1, 0.6, 1.0))


func _wall_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_seg := 120
	var ys := []
	var y := -0.1
	while y < WALL_H:
		ys.append(y)
		y += 0.12
	for j in 12:
		ys.append(WALL_H + (TOP_H - WALL_H) * (j + 1) / 12.0)
	var deep := Color("#16304F")
	var mid := Color("#24507A")
	var light := Color("#3C7AA0")
	var grid := []
	var cols := []
	for j in ys.size():
		var row := []
		var crow := []
		var yy: float = ys[j]
		for i in n_seg + 1:
			var a := TAU * i / n_seg
			# гладкие «булыжники»: несколько волн по кругу и по высоте
			var bump := 0.5 * sin(a * 7.0 + yy * 2.3) * sin(a * 3.0 - yy * 1.7) + 0.3 * sin(a * 13.0 + 1.0 + yy * 3.7) + 0.2 * sin(a * 23.0 - yy * 5.0)
			var r := wall_r(yy) * (1.0 + 0.06 * bump * clampf(1.0 - (yy - WALL_H) / 1.6, 0.25, 1.0))
			row.append(Vector3(cos(a) * r, yy, sin(a) * r))
			var c := deep.lerp(mid, smoothstep(-0.6, 0.3, bump)).lerp(light, smoothstep(0.4, 0.9, bump) * 0.7)
			# у дна — зеленоватый налёт, у окна наверху — светлее от лучей
			c = c.lerp(Color("#2F6A5A"), clampf(1.0 - yy / 0.7, 0.0, 0.7) * (0.6 + 0.4 * sin(a * 5.0)))
			c = c.lerp(Color("#5FA8C0"), clampf((yy - 2.9) / 0.9, 0.0, 0.5))
			if i == n_seg:
				c = crow[0]
			crow.append(c)
		grid.append(row)
		cols.append(crow)
	for j in ys.size() - 1:
		for i in n_seg:
			var a0 := TAU * (i + 0.5) / n_seg
			var A: Vector3 = grid[j][i]
			var B: Vector3 = grid[j][i + 1]
			var C: Vector3 = grid[j + 1][i + 1]
			var D: Vector3 = grid[j + 1][i]
			var inward := -Vector3(cos(a0), 0, sin(a0))
			if ys[j] > WALL_H:
				inward = (inward + Vector3(0, -1.2, 0)).normalized()
			tri(st, A, D, C, inward, cols[j][i], cols[j + 1][i], cols[j + 1][i + 1])
			tri(st, A, C, B, inward, cols[j][i], cols[j + 1][i + 1], cols[j][i + 1])
	st.index()
	st.generate_normals()
	return st.commit()


# ---------- Песчаное дно с каустикой ----------

func _floor(h: Node3D) -> void:
	if not _geo.has("floor"):
		_geo["floor"] = _floor_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _geo["floor"]
	var m := Shaders.material("caustic", {"strength": 0.22 + 0.04 * stage})
	mi.material_override = m
	h.add_child(mi)
	floor_parts.append(mi)  # 0.15: стиль «пол» (параметр tint шейдера caustic)
	# камешки
	var xfs := []
	for i in 46:
		var a := hash1(i, 11) * TAU
		var rr := 1.15 + hash1(i, 12) * 1.9
		var s := 0.6 + hash1(i, 13) * 0.9
		xfs.append(Transform3D(Basis(Vector3.UP, hash1(i, 14) * TAU) * Basis.from_scale(Vector3(1.0, 0.55, 0.8) * s), dir(a) * rr + Vector3(0, 0.03 + _floor_h(rr), 0)))
	scatter(h, sphere(0.06, 10), vmat(0.6, 0.35), xfs, [Color("#8FA3B8"), Color("#B5A4D0"), Color("#7FB8B0"), Color("#D0B79E"), Color("#E8E0F0")])


static func _floor_h(rr: float) -> float:
	return 0.22 * pow(clampf(rr / R, 0.0, 1.0), 4.0)


func _floor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var segs := 60
	var pts := []
	var cols := []
	for j in rings + 1:
		var rr := (R + 0.2) * j / rings
		var row := []
		var crow := []
		for i in segs + 1:
			var a := TAU * i / segs
			var hh := 0.0
			if j > 0:
				hh = 0.035 * sin(a * 5.0 + rr * 4.0) * sin(rr * 2.3) + _floor_h(rr)
			row.append(Vector3(cos(a) * rr, hh, sin(a) * rr))
			# песок с рябью
			var ripple := 0.5 + 0.5 * sin(rr * 9.0 + sin(a * 3.0) * 1.5)
			var c := Color("#9A8460").lerp(Color("#B39A72"), ripple * 0.6)
			c = c.lerp(Color("#6E8E8A"), smoothstep(0.7, 1.0, float(j) / rings) * 0.6)
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


# ---------- Поверхность и лучи света ----------

func _surface(h: Node3D) -> void:
	var w := put(h, quad(Vector2(3.0, 3.0)), Shaders.material("water_top"), Vector3(0, TOP_H + 0.12, 0), Vector3(PI / 2.0, 0, 0))
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# лучи — прозрачные конусы от окна вниз
	var rays := Shaders.material("rays", {"col": Color(0.6, 1.0, 1.0, 0.13 + 0.02 * stage)})
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var top := dir(a) * (0.35 + 0.25 * hash1(i, 21)) + Vector3(0, TOP_H, 0)
		var bot := dir(a + 0.3) * (1.0 + 0.9 * hash1(i, 22)) + Vector3(0, 0.0, 0)
		var len := top.distance_to(bot)
		var c := put(h, cyl(0.12 + 0.08 * hash1(i, 23), 0.45 + 0.25 * hash1(i, 24), len, 12), rays, (top + bot) * 0.5)
		c.basis = Basis(Quaternion(Vector3.UP, (top - bot).normalized()))
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anim(c, "wiggle", {"axis": Vector3.FORWARD, "amp": 0.04, "spd": 0.4, "p": float(i)})
	# свет сверху — «солнце» сквозь воду, даёт тени в высоком качестве
	var sun := SpotLight3D.new()
	sun.light_color = Color("#BFF6FF")
	sun.light_energy = 1.0 + 0.12 * stage
	sun.spot_range = 7.0
	sun.spot_angle = 42.0
	sun.spot_attenuation = 0.8
	sun.shadow_blur = 2.0
	sun.position = Vector3(0.2, TOP_H + 0.6, 0.3)
	h.add_child(sun)
	sun.look_at_from_position(sun.position, Vector3(0, 0, 0), Vector3.FORWARD)
	shadow_light = sun
	lights.append([sun, sun.light_energy, "slow"])
	omni(h, Vector3(0, 1.6, 1.4), Color("#5FD8E8"), 0.45, 5.0)
	features.append([Vector3(0, TOP_H - 0.2, 0), 2.0, "surface"])


# ---------- Подушка-губка для героя ----------

func _cushion(h: Node3D) -> void:
	var n := node(h)
	casters.append(n)
	put(n, sphere(0.62, 28), mat(Color("#5E9E94"), 1.0), Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.0, 0.42, 1.0))
	put(n, sphere(0.5, 24), mat(Color("#86C4B4"), 1.0, 0.0, false), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.36, 1.0))
	# мягкие «полипы» по краю
	var xfs := []
	for i in 12:
		var a := TAU * i / 12.0 + 0.2
		xfs.append(Transform3D(Basis.from_scale(Vector3(1.2, 0.7, 1.2)), dir(a) * 0.5 + Vector3(0, 0.25 + 0.02 * sin(i * 2.3), 0)))
	scatter(n, sphere(0.07, 10), mat(Color("#B6E4D6"), 1.0, 0.0, false), xfs)
	# камни-подставки и ракушка
	put(n, sphere(0.2, 12), mat(Color("#3C6E90"), 0.7), Vector3(0.6, 0.06, -0.3), Vector3.ZERO, Vector3(1.2, 0.6, 1.0))
	put(n, sphere(0.15, 12), mat(Color("#5B88A8"), 0.7), Vector3(-0.55, 0.05, 0.35), Vector3.ZERO, Vector3(1.0, 0.6, 1.2))


# ---------- Водоросли ----------

func _weeds(h: Node3D) -> void:
	var count := 7 + stage * 3
	var cols := [Color("#2FAE7A"), Color("#4FC48A"), Color("#3DBE9A"), Color("#6FD07A")]
	for i in count:
		var a := TAU * i / count + 0.2 + 0.25 * hash1(i, 31)
		var skip := false
		for s in ["floor_l", "floor_r"]:
			var sp: Vector3 = spots[s].pos
			if absf(angle_difference(a, atan2(sp.z, sp.x))) < 0.25:
				skip = true
		if skip:
			continue
		var rr := R - 0.38 - 0.15 * hash1(i, 32)
		var base := dir(a) * rr + Vector3(0, _floor_h(rr), 0)
		var hh := 1.0 + hash1(i, 33) * 1.3
		for blade in 2:
			var pts := []
			var off := dir(a + PI / 2.0) * (blade - 0.5) * 0.12
			for k in 10:
				var s := k / 9.0
				pts.append(base + off + Vector3(sin(s * 3.0 + i + blade) * 0.12 * s, s * hh * (1.0 - 0.25 * blade), cos(s * 2.0 + i) * 0.08 * s))
			put(h, tube(pts, 0.05, 0.012, 5, cols[(i + blade) % 4]), _sway)
			# листочки-лопасти
			for k in [3, 5, 7]:
				put(h, _rotated_leaf(pts[k], k * 1.7 + i, (cols[(i + blade) % 4] as Color).lightened(0.15), float(k) / 9.0), _sway)


## Листок водоросли, повёрнутый вокруг точки крепления; UV.y — высота на стебле (чтобы колыхался вместе)
func _rotated_leaf(p: Vector3, ang: float, col: Color, v: float) -> ArrayMesh:
	var b := Basis(Vector3.UP, ang)
	var pts := [p, p + b * Vector3(0.12, 0.06, 0.0), p + b * Vector3(0.22, 0.16, 0.0)]
	var m := tube(pts, 0.03, 0.006, 4, col)
	# у листа «высота для колыхания» — как у его точки на стебле
	var arr := m.surface_get_arrays(0)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	for i in uvs.size():
		uvs[i] = Vector2(uvs[i].x, v + uvs[i].y * 0.12)
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


# ---------- Кристаллы на дне ----------

func _crystals(h: Node3D) -> void:
	var cc := [Color("#3FD0FF"), Color("#B46CFF"), Color("#3DDC97"), Color("#FF8FD8"), Color("#9FF6FF")]
	var count := 2 + stage * 3
	for i in count:
		var a := TAU * (i * 0.382 + 0.1)
		var skip := false
		for s in ["floor_l", "floor_r"]:
			var sp: Vector3 = spots[s].pos
			if absf(angle_difference(a, atan2(sp.z, sp.x))) < 0.3:
				skip = true
		if skip:
			a += 0.6
		var rr := R - 0.7 - 0.4 * hash1(i, 41)
		var p := dir(a) * rr + Vector3(0, _floor_h(rr), 0)
		var c: Color = cc[i % cc.size()]
		var g := crystal_cluster(h, p, 0.8 + 0.4 * hash1(i, 42), c, 1.1, i)
		g.rotation.y = hash1(i, 43) * TAU
		halo(h, p + Vector3(0, 0.25, 0), 0.9, Color(c, 0.28))
	if count >= 5:
		omni(h, dir(TAU * 0.482) * 2.0 + Vector3(0, 0.5, 0), Color("#B48CFF"), 0.6, 2.6, "pulse")


# ---------- Подарки ступеней ----------

func _extras(h: Node3D) -> void:
	if stage >= 1:
		# актинии: розовые шарики-щупальца, слегка «дышат»
		for i in 3:
			var a := TAU * (0.15 + i * 0.31)
			var rr := 1.7 + 0.3 * hash1(i, 51)
			var g := node(h, dir(a) * rr + Vector3(0, _floor_h(rr), 0))
			put(g, cyl(0.1, 0.13, 0.14, 12), mat(Color("#E86FA0"), 0.8), Vector3(0, 0.07, 0))
			var top := node(g, Vector3(0, 0.14, 0))
			var xfs := []
			for k in 14:
				var aa := TAU * k / 14.0
				xfs.append(Transform3D(Basis(Vector3.FORWARD.rotated(Vector3.UP, aa), 0.5) * Basis.from_scale(Vector3(1, 2.4, 1)), dir(aa) * 0.08 + Vector3(0, 0.06, 0)))
			scatter(top, sphere(0.035, 8), mat(Color("#FFB3D6"), 0.7, 0.3, false), xfs)
			anim(top, "pulse", {"amp": 0.08, "spd": 1.3, "p": float(i)})
		# ракушки на песке
		for i in 5:
			var a := TAU * hash1(i, 55)
			var rr := 1.3 + 1.3 * hash1(i, 56)
			var s := put(h, hemi(0.07, 12), mat(Color("#FFD3E0").lerp(Color("#FFE8B0"), hash1(i, 57)), 0.6), dir(a) * rr + Vector3(0, _floor_h(rr) + 0.01, 0), Vector3(0, a, 0), Vector3(1.0, 0.5, 0.8))
			s.name = "shell"
	if stage >= 2:
		# светящиеся самоцветы в стенах
		var gc := [Color("#9FF6FF"), Color("#FF8FD8"), Color("#FFD34D")]
		for i in 4:
			var a := deg_to_rad([50.0, 150.0, 285.0, 128.0][i])
			var hy := 0.9 + 1.0 * hash1(i, 61)
			var p := dir(a) * (wall_r(hy) - 0.06) + Vector3(0, hy, 0)
			var g := node(h, p, face_center(a))
			crystal_cluster(g, Vector3.ZERO, 0.45, gc[i % 3], 1.2, i)
			g.rotation.x = 1.25
			halo(h, p - dir(a) * 0.1, 0.55, Color(gc[i % 3], 0.32))
		# медуза — мягкий светящийся купол, плавно поднимается и опускается
		var j := node(h, Vector3(0.6, 2.6, -1.9))
		anim(j, "drift", {"amp": Vector3(0.2, 0.25, 0.15), "tilt": 0.1})
		put(j, hemi(0.2, 20), glass(Color(1.0, 0.7, 0.95, 0.55), 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.6, 1))
		put(j, sphere(0.08, 12), glow_mat(Color("#FFC2EC"), 1.6), Vector3(0, 0.08, 0))
		for k in 5:
			var aa := TAU * k / 5.0
			var pts := [Vector3(cos(aa) * 0.12, 0, sin(aa) * 0.12), Vector3(cos(aa) * 0.13, -0.15, sin(aa) * 0.13 + 0.03), Vector3(cos(aa) * 0.1, -0.32, sin(aa) * 0.1)]
			put(j, tube(pts, 0.012, 0.005, 4), mat(Color("#FFB3E6"), 0.6, 0.6, false))
		halo(j, Vector3(0, 0.05, 0), 0.8, Color(1.0, 0.6, 0.9, 0.3))
	if stage >= 3:
		# стайка светящихся рыбок кружит под сводом
		for i in 7:
			var f := node(h, Vector3(0, 2.2 + 0.2 * sin(i * 1.7), 0))
			var fish := node(f, Vector3(1.7 + 0.2 * hash1(i, 71), 0, 0))
			fish.scale = Vector3.ONE * (0.8 + 0.3 * hash1(i, 72))
			_fish(fish, [Color("#FFD36B"), Color("#FF9EC6"), Color("#9FF6FF")][i % 3])
			anim(f, "spin", {"spd": -0.35, "p": i * 0.9})
		omni(h, Vector3(0, 2.3, 0), Color("#FFE6A0"), 0.35, 3.5, "slow")


## Объёмная рыбка (плывёт вдоль +z... по касательной к кругу): тело, хвост, глазки; светится
func _fish(f: Node3D, col: Color) -> void:
	var body := node(f)
	anim(body, "wiggle", {"amp": 0.22, "spd": 6.0, "p": f.position.x * 7.0})
	put(body, sphere(0.09, 14), mat(col, 0.5, 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(0.55, 0.75, 1.0))
	put(body, prism(Vector3(0.11, 0.1, 0.02)), mat(col.darkened(0.1), 0.5, 0.9, false), Vector3(0, 0, -0.11), Vector3(PI / 2.0, 0, 0))
	for sx in [-1.0, 1.0]:
		put(body, sphere(0.014, 6), mat(OUT, 0.4, 0.0, false), Vector3(sx * 0.045, 0.02, 0.05))
	halo(f, Vector3.ZERO, 0.35, Color(col, 0.3))


## Рыбка «из картона»: тело и хвост (смотрит в -x... хвостом к +x)
static func _fish_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := PI * 0.15 + (TAU - PI * 0.3) * i / 13.0
		pts.append(Vector2(cos(a) * 0.12, sin(a) * 0.07))
	pts.append(Vector2(0.2, 0.07))
	pts.append(Vector2(0.2, -0.07))
	return pts


## Полочка-уступ из камня
func _ledge(n: Node3D, _spot: String) -> void:
	# камень, выступающий из стены (половина — в стене), сверху плоский
	put(n, sphere(0.45, 18), mat(Color("#2F5C82"), 0.8), Vector3(0, -0.2, 0.04), Vector3.ZERO, Vector3(1.25, 0.5, 0.8))
	put(n, sphere(0.4, 18), mat(Color("#5B92B0"), 0.75, 0.0, false), Vector3(0, 0.0, 0.12), Vector3.ZERO, Vector3(1.15, 0.08, 0.75))
	put(n, sphere(0.06, 8), mat(Color("#FF9EC6"), 0.7, 0.3, false), Vector3(-0.3, 0.07, 0.35))


# ---------- Украшения ----------

func _decor(id: String, n: Node3D, sk: String) -> void:
	match id:
		"axo_starfish": _d_starfish(n)
		"axo_coral": _d_coral(n, Color("#FF7BA8"), 1.0)
		"axo_anchor": _d_anchor(n, sk)
		"axo_shell": _d_shell(n)
		"axo_lily": _d_lily(n)
		"axo_bubble": _d_bubble(n)
		"axo_tree":
			_d_coral(n, Color("#4FD8C8"), 1.35, Vector3(-0.2, 0, 0))
			_d_coral(n, Color("#B07CFF"), 1.0, Vector3(0.22, 0, 0.05))
			put(n, sphere(0.3, 14), mat(Color("#3C6E90"), 0.7), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.6, 0.35, 1.0))
		"axo_sofa": _d_sofa(n)
		"axo_castle": _d_castle(n)
		"axo_chest": _d_chest(n)


func _d_starfish(n: Node3D) -> void:
	var s := node(n, Vector3(0, 0.42, 0.06))
	anim(s, "wiggle", {"axis": Vector3.BACK, "amp": 0.1, "spd": 0.8})
	put(s, extrude(_soft_star(0.26, 0.11), 0.08), mat(Color("#FF8A4C"), 0.75, 0.3))
	for i in 5:
		var a := PI / 2.0 + i * TAU / 5.0
		for j in 2:
			put(s, sphere(0.018, 6), mat(Color("#FFD1A8"), 0.8, 0.0, false), Vector3(cos(a) * (0.08 + j * 0.07), sin(a) * (0.08 + j * 0.07), 0.045))
	for sx in [-1.0, 1.0]:
		var e := put(s, sphere(0.022, 8), mat(OUT, 0.4, 0.0, false), Vector3(sx * 0.045, 0.01, 0.045), Vector3.ZERO, Vector3(1, 1, 0.5))
		anim(e, "blink_eye", {"p": 1.0})
		put(s, sphere(0.008, 6), mat(Color.WHITE, 0.4, 0.5, false), Vector3(sx * 0.045 - 0.008, 0.02, 0.055))
	put(s, torus(0.018, 0.026, 12), mat(OUT, 0.5, 0.0, false), Vector3(0, -0.04, 0.042), Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 0.4))
	for sx in [-1.0, 1.0]:
		put(s, sphere(0.02, 6), mat(Color("#FF6F8E"), 0.8, 0.0, false), Vector3(sx * 0.08, -0.03, 0.043), Vector3.ZERO, Vector3(1.2, 0.7, 0.3))


## Звезда со скруглёнными лучами
static func _soft_star(ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 60:
		var a := PI / 2.0 + TAU * i / 60.0
		var k := 0.5 + 0.5 * cos(a * 5.0 - PI * 2.5)
		pts.append(Vector2(cos(a), sin(a)) * lerpf(ri, ro, pow(k, 1.6)))
	return pts


func _d_coral(n: Node3D, col: Color, k: float, off := Vector3.ZERO) -> void:
	var g := node(n, off)
	anim(g, "sway", {"amp": 0.05, "spd": 1.0, "p": off.x * 5.0})
	var m := mat(col, 0.7, 0.15)
	var tip := mat(col.lightened(0.25), 0.6, 0.3, false)
	var branches := [[Vector3(0, 0, 0), Vector3(0, 0.3, 0), Vector3(0, 0.55, 0.02)],
		[Vector3(0, 0.2, 0), Vector3(-0.12, 0.32, 0), Vector3(-0.2, 0.48, 0.02)],
		[Vector3(0, 0.26, 0), Vector3(0.14, 0.36, 0.02), Vector3(0.2, 0.58, 0)],
		[Vector3(-0.12, 0.32, 0), Vector3(-0.2, 0.36, 0.05), Vector3(-0.3, 0.38, 0.04)],
		[Vector3(0.14, 0.36, 0.02), Vector3(0.24, 0.38, -0.02), Vector3(0.3, 0.44, 0)],
		[Vector3(0, 0.4, 0.01), Vector3(0.04, 0.5, 0.1), Vector3(0.06, 0.62, 0.12)]]
	for b in branches:
		var pts := bez(b[0] * k, b[1] * k, b[2] * k, 6)
		put(g, tube(pts, 0.045 * k, 0.03 * k, 7), m)
		put(g, sphere(0.04 * k, 10), tip, (b[2] as Vector3) * k)


func _d_anchor(n: Node3D, sk: String) -> void:
	var g := node(n, Vector3(0, 0, 0))
	if sk == "ledge":
		g.rotation.x = -0.18
	var grey := mat(Color("#9FB3C8"), 0.4)
	grey.metallic = 0.0
	put(g, cyl(0.035, 0.035, 0.7, 10), grey, Vector3(0, 0.42, 0))
	put(g, cyl(0.03, 0.03, 0.34, 10), grey, Vector3(0, 0.6, 0), Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		put(g, sphere(0.045, 10), grey, Vector3(sx * 0.17, 0.6, 0))
	put(g, torus(0.05, 0.09, 18), grey, Vector3(0, 0.83, 0), Vector3(PI / 2.0, 0, 0))
	var arc := []
	for i in 13:
		var a := lerpf(PI * 0.12, PI * 0.88, i / 12.0)
		arc.append(Vector3(cos(a) * 0.3, 0.38 - sin(a) * 0.3, 0))
	put(g, tube(arc, 0.035, 0.035, 8), grey)
	for sx in [-1.0, 1.0]:
		var tipp := Vector3(sx * 0.3 * cos(PI * 0.12), 0.38 - sin(PI * 0.12) * 0.3, 0)
		put(g, prism(Vector3(0.12, 0.13, 0.05)), grey, tipp + Vector3(0, 0.03, 0), Vector3(0, 0, sx * 0.4))
	# верёвка, обвившая якорь
	var rope := []
	for i in 26:
		var s := i / 25.0
		rope.append(Vector3(cos(s * 18.0) * 0.05, 0.45 + s * 0.3, sin(s * 18.0) * 0.05))
	put(g, tube(rope, 0.014, 0.014, 5), mat(Color("#C9A46A"), 1.0, 0.0, false))
	# морская звёздочка-малышка на лапе якоря
	put(g, extrude(_soft_star(0.06, 0.028), 0.03), mat(Color("#FFB86B"), 0.7, 0.0, false), Vector3(-0.22, 0.22, 0.04), Vector3(0, 0, 0.4))
	for i in 3:
		var b := put(g, sphere(0.022, 8), glass(Color(0.85, 1.0, 1.0, 0.45), 0.3), Vector3(0.04, 0.9, 0.02))
		anim(b, "rise", {"h": 0.45, "spd": 0.35, "p": i / 3.0})


func _d_shell(n: Node3D) -> void:
	var pink := Color("#FFC2D6")
	put(n, sphere(0.22, 20), mat(pink.darkened(0.08), 0.6), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1.0, 0.3, 0.85))
	var pearl := put(n, sphere(0.07, 18), mat(Color("#F6F2FF"), 0.15, 0.6), Vector3(0, 0.13, 0.03))
	anim(pearl, "pulse", {"amp": 0.05})
	halo(n, Vector3(0, 0.14, 0.06), 0.5, Color(1, 1, 1, 0.3))
	var lid := node(n, Vector3(0, 0.1, -0.17))
	anim(lid, "call", {"f": _clam})
	var top := node(lid, Vector3(0, 0, 0.17))
	put(top, sphere(0.22, 20), mat(pink, 0.6), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 0.32, 0.85))
	# рёбрышки и волнистый край
	for i in 7:
		var a := lerpf(-1.2, 1.2, i / 6.0)
		put(top, sphere(0.02, 6), mat(pink.lightened(0.25), 0.6, 0.0, false), Vector3(sin(a) * 0.12, 0.085, cos(a) * 0.1 - 0.02), Vector3(0, a, 0), Vector3(0.6, 0.4, 3.0))
		put(top, sphere(0.03, 8), mat(pink, 0.6, 0.0, false), Vector3(sin(a) * 0.205, 0.02, cos(a) * 0.17))
	omni(n, Vector3(0, 0.2, 0.1), Color("#FFE6F4"), 0.4, 1.4, "pulse")


func _clam(nd: Node3D, t: float, a: Dictionary) -> void:
	var o := 0.3 + 0.25 * sin(t * 1.2)
	nd.transform = Transform3D(Basis(Vector3.RIGHT, -o), a.base.origin)


func _d_lily(n: Node3D) -> void:
	var pad := node(n)
	anim(pad, "bob", {"amp": 0.015, "spd": 1.2})
	var poly := PackedVector2Array()
	for i in 30:
		var a := 0.3 + (TAU - 0.6) * i / 29.0
		poly.append(Vector2(cos(a), sin(a)) * 0.34)
	poly.append(Vector2.ZERO)
	put(pad, extrude(poly, 0.04), mat(Color("#3FAF6E"), 0.8), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	for i in 7:
		var a := TAU * i / 7.0
		put(pad, prism(Vector3(0.07, 0.14, 0.03)), mat(Color("#FFB8D6"), 0.6, 0.15), Vector3(cos(a) * 0.05, 0.08, sin(a) * 0.05), Vector3(0, -a + PI / 2.0, -0.5))
	put(pad, sphere(0.04, 10), glow_mat(Color("#FFD34D"), 0.8), Vector3(0, 0.07, 0))
	# под листом — светлячок-рачок
	var f := node(n, Vector3(0, -0.45, 0))
	anim(f, "drift", {"amp": Vector3(0.18, 0.08, 0.12), "tilt": 0.0})
	put(f, sphere(0.035, 10), glow_mat(Color("#FFF27A"), 3.0))
	halo(f, Vector3.ZERO, 0.5, Color(1.0, 0.95, 0.5, 0.45))
	omni(f, Vector3.ZERO, Color("#FFF2A0"), 0.5, 1.6, "pulse")


func _d_bubble(n: Node3D) -> void:
	var g := node(n)
	anim(g, "bob", {"amp": 0.04, "spd": 1.5})
	put(g, sphere(0.25, 24), glass(Color(0.7, 1.0, 1.0, 0.3), 0.25), Vector3(0, 0.3, 0))
	put(g, sphere(0.09, 16), glow_mat(Color("#FFF6C8"), 1.5), Vector3(0, 0.3, 0))
	put(g, torus(0.2, 0.25, 24), mat(Color("#BFF0FF"), 0.3, 0.2, false), Vector3(0, 0.3, 0), Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 0.25))
	put(g, cyl(0.05, 0.07, 0.06, 12), mat(Color("#5B92B0"), 0.5), Vector3(0, 0.57, 0))
	halo(g, Vector3(0, 0.3, 0), 0.9, Color(0.6, 1.0, 1.0, 0.2))
	omni(g, Vector3(0, 0.3, 0.1), Color("#BFF6FF"), 0.5, 2.2, "pulse")
	for i in 3:
		var b := put(n, sphere(0.022 + 0.008 * i, 8), glass(Color(0.85, 1.0, 1.0, 0.45), 0.3), Vector3(0.05 * i - 0.05, 0.6, 0))
		anim(b, "rise", {"h": 0.5, "spd": 0.4, "p": i / 3.0})


func _d_sofa(n: Node3D) -> void:
	var stone := mat(Color("#8FA8C8"), 0.8)
	put(n, sphere(0.3, 18), stone, Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1.7, 0.5, 0.85))
	put(n, sphere(0.28, 18), stone, Vector3(0, 0.34, -0.16), Vector3(0.3, 0, 0), Vector3(1.75, 0.75, 0.42))
	for sx in [-1.0, 1.0]:
		put(n, sphere(0.14, 12), mat(Color("#7E9FBF"), 0.8), Vector3(sx * 0.46, 0.26, 0.02), Vector3.ZERO, Vector3(0.8, 1.0, 1.4))
	put(n, sphere(0.2, 16), mat(Color("#4FC48A"), 1.0), Vector3(-0.13, 0.29, 0.05), Vector3.ZERO, Vector3(1.2, 0.35, 0.9))
	put(n, sphere(0.16, 16), mat(Color("#6FD8A0"), 1.0), Vector3(0.2, 0.3, 0.04), Vector3.ZERO, Vector3(1.1, 0.4, 0.9))
	for d in [Vector3(-0.3, 0.42, -0.1), Vector3(0.24, 0.5, -0.12), Vector3(0.42, 0.12, 0.18)]:
		put(n, sphere(0.025, 6), mat(Color("#FFB3D0"), 0.8, 0.3, false), d)


func _d_castle(n: Node3D) -> void:
	var sand := mat(Color("#E6C98E"), 0.95)
	var sand2 := mat(Color("#F0D9A6"), 0.95)
	put(n, box(Vector3(0.6, 0.32, 0.36)), sand, Vector3(0, 0.16, 0))
	for i in 5:
		put(n, box(Vector3(0.08, 0.07, 0.36)), sand2, Vector3(-0.24 + i * 0.12, 0.355, 0))
	for sx in [-1.0, 1.0]:
		put(n, cyl(0.11, 0.12, 0.56, 14), sand2, Vector3(sx * 0.3, 0.28, 0.02))
		put(n, cyl(0.0, 0.15, 0.2, 14), mat(Color("#E0556F"), 0.7), Vector3(sx * 0.3, 0.66, 0.02))
		var win := put(n, sphere(0.032, 8), glow_mat(Color("#9FF6FF"), 1.8), Vector3(sx * 0.3, 0.4, 0.12), Vector3.ZERO, Vector3(0.8, 1.2, 0.5))
		win.name = "window"
	put(n, cyl(0.075, 0.075, 0.02, 14), mat(Color("#5A3A2E"), 1.0, 0.0, false), Vector3(0, 0.1, 0.18), Vector3(PI / 2.0, 0, 0), Vector3(1, 1, 1.6))
	put(n, box(Vector3(0.15, 0.1, 0.02)), mat(Color("#5A3A2E"), 1.0, 0.0, false), Vector3(0, 0.05, 0.18))
	for i in 3:
		put(n, sphere(0.022, 8), glow_mat(Color("#9FF6FF"), 1.5), Vector3(-0.15 + i * 0.15, 0.24, 0.185))
	put(n, cyl(0.008, 0.008, 0.24, 4), mat(OUT, 0.5, 0.0, false), Vector3(0.3, 0.88, 0.02))
	var flag := node(n, Vector3(0.3, 0.96, 0.02))
	anim(flag, "flag")
	put(flag, prism(Vector3(0.14, 0.1, 0.01), 0.0), mat(Color("#FFD34D"), 0.6, 0.0, false), Vector3(0.07, 0, 0), Vector3(0, 0, -PI / 2.0))
	# ракушки на стене замка
	for p in [Vector3(-0.16, 0.2, 0.185), Vector3(0.18, 0.28, 0.185)]:
		put(n, hemi(0.035, 10), mat(Color("#FFC2D6"), 0.6, 0.0, false), p, Vector3(PI / 2.0, 0, 0))
	halo(n, Vector3(0, 0.3, 0.2), 0.8, Color(0.6, 1.0, 1.0, 0.18))


func _d_chest(n: Node3D) -> void:
	var wood := mat(Color("#9A5A34"), 0.8)
	var gold := mat(Color("#FFCB45"), 0.35, 0.15)
	put(n, box(Vector3(0.5, 0.26, 0.32)), wood, Vector3(0, 0.13, 0))
	for sx in [-0.17, 0.17]:
		put(n, box(Vector3(0.05, 0.27, 0.33)), gold, Vector3(sx, 0.135, 0))
	# сокровища внутри
	for i in 7:
		put(n, cyl(0.04, 0.04, 0.012, 12), mat(Color("#FFD34D"), 0.3, 0.4, false), Vector3(-0.17 + i * 0.055, 0.265 + 0.01 * (i % 2), -0.04 + 0.04 * (i % 3)), Vector3(0.3 * (i % 2), 0, 0.2 * (i % 3 - 1)))
	crystal(n, Vector3(0.08, 0.24, 0.0), 0.16, 0.04, Vector3(0.2, 0, -0.3), Color("#FF4D6D"), 1.0)
	var lid := node(n, Vector3(0, 0.26, -0.16))
	anim(lid, "hinge", {"ang": 1.05, "spd": 0.8})
	var top := node(lid, Vector3(0, 0, 0.16))
	put(top, cyl(0.16, 0.16, 0.5, 16), wood, Vector3.ZERO, Vector3(0, 0, PI / 2.0), Vector3(1, 1, 1))
	for sx in [-0.17, 0.17]:
		put(top, cyl(0.165, 0.165, 0.05, 16), gold, Vector3(sx, 0, 0), Vector3(0, 0, PI / 2.0))
	put(top, box(Vector3(0.08, 0.1, 0.04)), gold, Vector3(0, -0.04, 0.16))
	# под крышкой — кусочек ткани, чтобы цилиндр не просвечивал внутрь
	put(top, box(Vector3(0.48, 0.02, 0.3)), mat(Color("#7A3A2A"), 1.0, 0.0, false), Vector3(0, -0.01, 0))
	var glow := halo(n, Vector3(0, 0.35, 0), 0.9, Color(1.0, 0.85, 0.3, 0.35))
	anim(glow, "call", {"f": _chest_glow})
	omni(n, Vector3(0, 0.4, 0.1), Color("#FFD27A"), 0.5, 1.6, "pulse")


func _chest_glow(nd: Node3D, t: float, _a: Dictionary) -> void:
	var o := clampf(sin(t * 0.8) * 2.0, 0.0, 1.0)
	nd.visible = o > 0.05
	nd.scale = Vector3.ONE * maxf(0.05, o)
