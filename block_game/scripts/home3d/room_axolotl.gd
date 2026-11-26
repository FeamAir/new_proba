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
## 0.15: просвет в своде (окно) — слева за героем: угол, высота центра, полуширина (рад) и полувысота
const WIN_ANG := -1.833
const WIN_Y := 2.02
const WIN_HALF_ANG := 0.2
const WIN_HALF_H := 0.4

static var _geo := {}
var _sway: ShaderMaterial
## 0.15: что меняет стиль комнаты (стены / пол / свет)
var _rays: ShaderMaterial
var _rays_a := 0.15
var _sun: SpotLight3D
var _fill: OmniLight3D
var _bubbles: MultiMeshInstance3D
var _pebbles: MultiMeshInstance3D
var _win_mat: ShaderMaterial
var _style_nodes := {}


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
	# 0.15: 15 мест (типы — scripts/decor_data/axolotl.gd). Камера смотрит с +Z; полка славы — у стены +Z.
	# Задняя дуга: просвет в своде (окно) слева от героя, справа — wall_back; по бокам — большие места,
	# стены, пол; сверху — у края просвета (hang) и на сталактите (hang_2); спереди по бокам — уступы.
	# [угол°, тип, радиус (пол/подвес) или 0 (стена), высота]
	var defs := {
		"floor_l": [190.0, "floor", 2.15, 0.0], "floor_r": [-6.0, "floor", 2.2, 0.0],
		"wall_l": [-160.0, "wall", 0.0, 1.3], "wall_r": [-20.0, "wall", 0.0, 1.25],
		"hang": [-120.0, "hang", 0.62, TOP_H + 0.02], "near": [32.0, "near", 1.08, 0.0],
		"window": [rad_to_deg(WIN_ANG), "window", 0.0, 0.0],
		"big_back": [-136.0, "big", 2.25, 0.0], "big_corner": [-44.0, "big", 2.25, 0.0],
		"wall_back": [-72.0, "wall", 0.0, 1.5],
		"ledge_l": [155.0, "shelf", 0.0, 1.55], "ledge_r": [25.0, "shelf", 0.0, 1.55],
		"hang_2": [-40.0, "hang", 1.45, 0.0],
		"floor_front": [56.0, "floor", 1.9, 0.0], "near_2": [148.0, "near", 1.08, 0.0],
	}
	for s in defs:
		var d: Array = defs[s]
		var a := deg_to_rad(d[0])
		var k: String = d[1]
		var y: float = d[3]
		var sp := {"yaw": face_center(a), "mark": Vector3(0, 0.3, 0), "stand": Vector3(0, 0.04, 0.24)}
		match k:
			"wall", "shelf":
				sp.pos = dir(a) * (wall_r(y) - 0.05) + Vector3(0, y, 0)
				sp.mark = Vector3(0, 0.3, 0.34)
			"hang":
				if s == "hang_2":
					y = vault_y(d[2]) - 0.42  # кончик сталактита
				sp.pos = dir(a) * d[2] + Vector3(0, y, 0)
				sp.mark = Vector3(0, -1.05, 0)
			"window":
				sp.pos = dir(a) * (wall_r(WIN_Y - WIN_HALF_H) - 0.2) + Vector3(0, WIN_Y - WIN_HALF_H + 0.07, 0)
				sp.mark = Vector3(0, 0.3, 0.1)
				sp.erase("stand")
			"big":
				sp.pos = dir(a) * d[2] + Vector3(0, _floor_h(d[2]), 0)
				sp.mark = Vector3(0, 0.6, 0)
			_:
				sp.pos = dir(a) * d[2] + Vector3(0, y, 0)
		spots[s] = sp
	# 0.14: полка славы — каменная ниша напротив входа камеры (за спиной камеры в обычном обзоре)
	shelf_def = {"style": "axolotl", "pos": dir(PI / 2.0) * R, "yaw": face_center(PI / 2.0), "room_r": R,
		"rows": [[1.28, wall_r(1.28) - 0.04], [1.78, wall_r(1.78) - 0.04]], "spacing": 0.37, "scale": 1.0, "depth": 0.3,
		"plaque_z": 0.205, "plaque_y": -0.035, "focus_d": 0.64, "view_d": 1.9}
	trophy_light = 1.05


## Высота свода над точкой на расстоянии rr от центра
static func vault_y(rr: float) -> float:
	if rr >= R * 0.96:
		return WALL_H
	var lo := 0.0
	var hi := 1.0
	for i in 20:
		var m := (lo + hi) * 0.5
		if wall_r(WALL_H + (TOP_H - WALL_H) * m) > rr:
			lo = m
		else:
			hi = m
	return WALL_H + (TOP_H - WALL_H) * lo


## 0.15: угол места на полу/стене близко к углу a (камни, водоросли, кристаллы дома их обходят)
func _near_spot(a: float, kinds: Array, tol: float) -> bool:
	for s in spots:
		if not kinds.has(Catalog.spot_kind(s, kind)):
			continue
		var p: Vector3 = spots[s].pos
		if Vector2(p.x, p.z).length() > 1.5 and absf(angle_difference(a, atan2(p.z, p.x))) < tol:
			return true
	return false


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
	_window(h)
	_stalactite(h)
	_cushion(h)
	_weeds(h)
	_crystals(h)
	_extras(h)
	# пузырьки по всему гроту
	_bubbles = shader_swarm(h, "bubbles", 14 + stage * 6, {"height": 3.6, "radius": 2.6, "size": 0.05})


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
		if _near_spot(a, ["floor", "big", "wall", "window"], 0.32):
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
			# у просвета — светлее
			var wd := Vector2(angle_difference(a, WIN_ANG) / WIN_HALF_ANG, (yy - WIN_Y) / WIN_HALF_H).length()
			c = c.lerp(Color("#4F98B8"), clampf(1.6 - wd * 0.6, 0.0, 0.6))
			if i == n_seg:
				c = crow[0]
			crow.append(c)
		grid.append(row)
		cols.append(crow)
	for j in ys.size() - 1:
		for i in n_seg:
			var a0 := TAU * (i + 0.5) / n_seg
			# 0.15: просвет в своде (окно) — дыра в стене
			var da := angle_difference(a0, WIN_ANG) / WIN_HALF_ANG
			var dy: float = ((ys[j] + ys[j + 1]) * 0.5 - WIN_Y) / WIN_HALF_H
			if da * da + dy * dy < 1.0:
				continue
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
	_pebbles = scatter(h, sphere(0.06, 10), vmat(0.6, 0.35), xfs, [Color("#8FA3B8"), Color("#B5A4D0"), Color("#7FB8B0"), Color("#D0B79E"), Color("#E8E0F0")])


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
	_rays = rays
	_rays_a = 0.13 + 0.02 * stage
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
	_sun = sun
	lights.append([sun, sun.light_energy, "slow"])
	_fill = omni(h, Vector3(0, 1.6, 1.4), Color("#5FD8E8"), 0.45, 5.0)
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
		if _near_spot(a, ["floor", "big", "wall", "window"], 0.27):
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
		for t in 3:
			if _near_spot(a, ["floor", "big"], 0.3):
				a += 0.45
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
			for t in 3:
				if _near_spot(a, ["floor", "big"], 0.3):
					a += 0.4
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
			var a := deg_to_rad([62.0, 118.0, -178.0, 8.0][i])  # 0.15: мимо мест на стенах
			var hy := 0.9 + 1.0 * hash1(i, 61)
			var p := dir(a) * (wall_r(hy) - 0.06) + Vector3(0, hy, 0)
			var g := node(h, p, face_center(a))
			crystal_cluster(g, Vector3.ZERO, 0.45, gc[i % 3], 1.2, i)
			g.rotation.x = 1.25
			halo(h, p - dir(a) * 0.1, 0.55, Color(gc[i % 3], 0.32))
		# медуза — мягкий светящийся купол, плавно поднимается и опускается
		var j := node(h, Vector3(0.45, 2.75, -1.15))
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
		_: _new_decor(id, n, sk)


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


# ---------- 0.15: просвет в своде (окно) и сталактит ----------

func _window(h: Node3D) -> void:
	var out := dir(WIN_ANG)
	var yaw := face_center(WIN_ANG)
	var wr := wall_r(WIN_Y)
	var side := dir(WIN_ANG + PI / 2.0)
	# камни по краю просвета
	for i in 16:
		var t := TAU * i / 16.0
		var p := out * (wr - 0.04) + Vector3(0, WIN_Y + sin(t) * (WIN_HALF_H + 0.07), 0) + side * cos(t) * (WIN_HALF_ANG * wr + 0.07)
		var k := 0.8 + 0.4 * hash1(i, 81)
		vp(h, sphere(0.13 * k, 12), Color("#3C6E90").lerp(Color("#5B92B0"), hash1(i, 82)), p, Vector3(0, hash1(i, 83) * 3.0, 0), Vector3(1.2, 0.9, 0.8))
	# подоконник-уступ
	vp(h, sphere(0.5, 18), Color("#3F7FA0"), out * (wr - 0.1) + Vector3(0, WIN_Y - WIN_HALF_H - 0.02, 0), Vector3(0, yaw, 0), Vector3(1.0, 0.18, 0.62))
	vp(h, sphere(0.06, 8), Color("#FF9EC6"), out * (wr - 0.38) + Vector3(0, WIN_Y - WIN_HALF_H + 0.04, 0) + side * 0.3, Vector3.ZERO, Vector3.ONE, false)
	# за просветом — светлая вода с бегущими бликами
	_win_mat = smat("axo_window", AXO_WINDOW, {}, false)
	var q := put(h, quad(Vector2(2.2, 1.9)), _win_mat, out * (R + 0.55) + Vector3(0, WIN_Y + 0.1, 0))
	q.rotation.y = yaw
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# луч из просвета вниз, в грот
	var top := out * (wr - 0.1) + Vector3(0, WIN_Y + 0.15, 0)
	var bot := out * 0.6 + Vector3(0, 0.0, 0)
	var c := put(h, cyl(0.28, 0.75, top.distance_to(bot), 12), _rays, (top + bot) * 0.5)
	c.basis = Basis(Quaternion(Vector3.UP, (top - bot).normalized()))
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anim(c, "wiggle", {"axis": Vector3.FORWARD, "amp": 0.03, "spd": 0.35, "p": 2.0})
	features.append([out * (wr - 0.2) + Vector3(0, WIN_Y, 0), 1.6, "window"])


## Сталактит над местом hang_2 (кончик — точка подвеса)
func _stalactite(h: Node3D) -> void:
	if not spots.has("hang_2"):
		return
	var p: Vector3 = spots["hang_2"].pos
	var top := vault_y(Vector2(p.x, p.z).length()) + 0.15
	var L := top - p.y
	vp(h, cyl(0.03, 0.2, L, 10), Color("#3C6E90"), p + Vector3(0, L * 0.5, 0))
	vp(h, cyl(0.02, 0.12, L * 0.6, 8), Color("#5B92B0"), p + Vector3(0.12, L * 0.7, 0.05), Vector3(0, 0, 0.1))
	vp(h, sphere(0.04, 8), Color("#7FB8D0"), p + Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1, 1.4, 1), false)


# ---------- 0.15: стиль комнаты (стены / пол / свет) ----------
## Стены: свой шейдер поверх цвета камня (перламутр, корабельные доски, светящиеся прожилки).
## Пол: свой шейдер песка с каустикой (розовый с ракушками, монеты, чёрный с огоньками) + россыпи ракушек / монет.
## Свет: оттенок окружения + лучи, солнце и фон: закат, праздничные цветные пузыри, тьма бездны.

func apply_walls(id: String) -> void:
	var mode := ["axo_walls_stone", "axo_walls_pearl", "axo_walls_planks", "axo_walls_veins"].find(id)
	_swap_mat(wall_parts, "axo_walls", AXO_WALLS, maxi(mode, 0))


func apply_floor(id: String) -> void:
	var mode := ["axo_floor_sand", "axo_floor_pink", "axo_floor_coins", "axo_floor_dark"].find(id)
	_swap_mat(floor_parts, "axo_floor", AXO_FLOOR, maxi(mode, 0))
	_style_extra("floor_shells", mode == 1, _shell_scatter)
	_style_extra("floor_coins", mode == 2, _coin_scatter)
	if _pebbles:
		_pebbles.visible = mode != 2


func apply_light(id: String) -> void:
	super.apply_light(id)
	var mode := maxi(["axo_light_sun", "axo_light_sunset", "axo_light_party", "axo_light_abyss"].find(id), 0)
	if env and not _env0.is_empty() and mode > 0:
		env.ambient_light_color = [Color(), Color(0.68, 0.55, 0.58), Color(0.6, 0.52, 0.74), Color(0.16, 0.2, 0.42)][mode]
		env.fog_light_color = [Color(), Color(0.42, 0.22, 0.26), Color(0.34, 0.2, 0.46), Color(0.02, 0.04, 0.12)][mode]
		if mode == 3:
			env.ambient_light_energy = _env0.amb_e * 0.55
	if env:
		env.background_color = [Color("#0A2A44"), Color("#3A1A2E"), Color("#2A1650"), Color("#02050E")][mode]
		env.glow_intensity = 0.95 if mode == 3 else 0.6
		env.glow_hdr_threshold = 0.6 if mode == 3 else 0.85
	if _rays:
		var rc: Color = [Color(0.6, 1.0, 1.0), Color(1.0, 0.72, 0.55), Color(1.0, 0.75, 1.0), Color(0.3, 0.45, 1.0)][mode]
		_rays.set_shader_parameter("col", Color(rc, _rays_a * [1.0, 1.25, 1.1, 0.25][mode]))
	if _sun and _sun.has_meta("e0"):
		_sun.light_color = [Color("#BFF6FF"), Color("#FFB890"), Color("#FFC8F0"), Color("#5A78FF")][mode]
		_sun.light_energy = float(_sun.get_meta("e0")) * [1.0, 1.05, 1.0, 0.3][mode]
		for l in lights:
			if l[0] == _sun:
				l[1] = _sun.light_energy
	if _fill and _fill.has_meta("e0"):
		_fill.light_color = [Color("#5FD8E8"), Color("#FF9E80"), Color("#C890FF"), Color("#3050C0")][mode]
	if _win_mat:
		_win_mat.set_shader_parameter("mode", mode)
	if _bubbles:
		_bubbles.visible = mode != 2
	_style_extra("light_party", mode == 2, _party_bubbles)


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
	if key == "light_party":
		var mmi := n.get_child(0) as MultiMeshInstance3D
		if mmi:
			mmi.multimesh.visible_instance_count = -1 if high else 20


func set_quality(hq: bool) -> void:
	super.set_quality(hq)
	for m in _style_mats.values():
		(m as ShaderMaterial).set_shader_parameter("lite", 0.0 if hq else 1.0)
	for k in _style_nodes:
		_style_quality(k, _style_nodes[k])


## Розовый песок: россыпь ракушек (одна сетка)
func _shell_scatter(n: Node3D) -> void:
	var xfs := []
	var cols := []
	for i in 40:
		var a := hash1(i, 101) * TAU
		var rr := 1.0 + hash1(i, 102) * 2.0
		var b := Basis(Vector3.UP, hash1(i, 103) * TAU) * Basis.from_scale(Vector3(1.0, 0.45, 0.85) * (0.6 + 0.7 * hash1(i, 104)))
		xfs.append(Transform3D(b, dir(a) * rr + Vector3(0, _floor_h(rr) + 0.01, 0)))
		cols.append([Color("#FFD3E0"), Color("#FFB8D0"), Color("#FFE8C8"), Color("#F4C8FF")][i % 4])
	scatter(n, hemi(0.07, 10), vmat(0.6, 0.4), xfs, cols)
	var st := []
	for i in 7:
		var a := hash1(i, 105) * TAU
		var rr := 1.2 + hash1(i, 106) * 1.7
		st.append(Transform3D(Basis(Vector3.UP, hash1(i, 107) * TAU) * Basis(Vector3.RIGHT, -PI / 2.0), dir(a) * rr + Vector3(0, _floor_h(rr) + 0.02, 0)))
	scatter(n, extrude(_soft_star(0.09, 0.04), 0.03), mat(Color("#FF9E6C"), 0.8, 0.0, false), st)


## Монеты в песке: россыпь блестящих монет и пара кучек (одна сетка)
func _coin_scatter(n: Node3D) -> void:
	var xfs := []
	for i in 60:
		var a := hash1(i, 111) * TAU
		var rr := 1.0 + hash1(i, 112) * 2.0
		var tilt := Basis.from_euler(Vector3(0.5 * (hash1(i, 113) - 0.5), hash1(i, 115) * TAU, 0.5 * (hash1(i, 114) - 0.5)))
		xfs.append(Transform3D(tilt, dir(a) * rr + Vector3(0, _floor_h(rr) + 0.012, 0)))
	for pile in 3:
		var a := TAU * (0.2 + pile * 0.37)
		var c := dir(a) * (1.5 + 0.3 * pile)
		for k in 9:
			var o := Vector3((hash1(pile * 9 + k, 117) - 0.5) * 0.16, 0.012 + 0.018 * (k % 4), (hash1(pile * 9 + k, 118) - 0.5) * 0.16)
			xfs.append(Transform3D(Basis(Vector3.RIGHT, 0.2 * (k % 3)), c + o + Vector3(0, _floor_h(c.length()), 0)))
	scatter(n, cyl(0.035, 0.035, 0.01, 12), mat(Color("#FFCB45"), 0.3, 0.35, false), xfs)


## Праздничные пузыри: цветные переливающиеся пузыри по всему гроту (одна сетка-шейдер)
func _party_bubbles(n: Node3D) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad(Vector2(1, 1))
	mm.instance_count = 38
	for i in 38:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = smat("axo_party", PARTY_BUBBLES, {}, false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 8, 12))
	n.add_child(mmi)


const AXO_WALLS := """
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
void fragment() {
	vec3 c = COLOR.rgb;
	vec3 em = vec3(0.0);
	float ang = atan(wp.x, -wp.z);
	vec2 cu = vec2(ang * 3.1, wp.y);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float rough = 0.8;
	float spec = 0.3;
	if (mode == 1) {
		// перламутр: пастельные переливы, зависят от взгляда, и чешуйки-волны
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float ph = vn(cu * 1.4) * 1.5 + fres * 1.6 + wp.y * 0.35 + TIME * 0.04;
		vec3 iri = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + ph * 0.5));
		vec2 g = vec2(cu.x * 6.0, wp.y * 7.0);
		g.x += mod(floor(g.y), 2.0) * 0.5;
		vec2 f = fract(g) - vec2(0.5, 0.0);
		float scale_ = smoothstep(0.06, 0.0, abs(length(f) - 0.5));
		c = vec3(0.74, 0.73, 0.84) * (0.55 + lum * 1.2);
		c = mix(c, c * (0.7 + 0.6 * iri), 0.4);
		c *= 1.0 - scale_ * 0.07;
		em += iri * 0.025 + vec3(0.9, 0.85, 1.0) * pow(fres, 3.0) * 0.1;
		rough = 0.25;
		spec = 0.7;
	} else if (mode == 2) {
		// корабельные доски: горизонтальные доски с волокнами, щели, шляпки гвоздей
		float bh = 0.22;
		float row = floor(wp.y / bh);
		float t = fract(wp.y / bh);
		float off = h21(vec2(row, 3.0)) * 4.0;
		float x = cu.x + off;
		float seg = floor(x / 1.4);
		float fx = fract(x / 1.4);
		float tone = h21(vec2(row, seg));
		vec3 wood = mix(vec3(0.36, 0.2, 0.1), vec3(0.55, 0.33, 0.16), tone);
		float grain = 0.5 + 0.5 * sin((wp.y * 60.0 + vn(vec2(x * 3.0, row)) * 6.0));
		wood *= 0.85 + 0.15 * grain;
		float gap = smoothstep(0.06, 0.0, t) + smoothstep(0.94, 1.0, t) + smoothstep(0.012, 0.0, fx) + smoothstep(0.988, 1.0, fx);
		wood = mix(wood, vec3(0.08, 0.05, 0.04), clamp(gap, 0.0, 1.0));
		vec2 np = vec2(fx * 1.4, t * bh);
		float nail = smoothstep(0.016, 0.01, min(length(np - vec2(0.06, bh * 0.5)), length(np - vec2(1.34, bh * 0.5))));
		wood = mix(wood, vec3(0.6, 0.55, 0.45), nail);
		// внизу — водоросли-налёт, сверху — свет
		wood = mix(wood, vec3(0.15, 0.3, 0.2), clamp(0.6 - wp.y, 0.0, 0.6) * vn(cu * 3.0));
		c = wood * (0.75 + lum * 0.9);
		rough = 0.9;
		spec = 0.15;
	} else if (mode == 3) {
		// светящиеся прожилки в тёмном камне
		c = c * vec3(0.35, 0.32, 0.5);
		vec2 p = cu * 0.9;
		vec2 warp = vec2(vn(p * 1.2 + 5.0), vn(p * 1.2 + 9.0)) * 1.5;
		float n = vn(p * 1.8 + warp);
		float ridge = 1.0 - abs(2.0 * n - 1.0);
		float vein = smoothstep(0.92, 0.985, ridge);
		if (lite < 0.5) {
			float n2 = vn(p * 4.5 + warp * 2.0 + 3.0);
			vein = max(vein, smoothstep(0.95, 0.99, 1.0 - abs(2.0 * n2 - 1.0)) * 0.6);
		}
		vec3 vc = mix(vec3(0.15, 0.9, 1.0), vec3(0.85, 0.3, 1.0), vn(p * 0.6 + 2.0));
		float pulse = 0.6 + 0.4 * sin(TIME * 1.3 + wp.y * 2.0 - ang * 2.0);
		c = mix(c, vc * 0.3, vein * 0.8);
		em += vc * vein * pulse * 1.3;
		rough = 0.6;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = em;
}
"""

const AXO_FLOOR := """
shader_type spatial;
uniform int mode = 1;
uniform float lite = 0.0;
uniform float strength = 0.25;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float cell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float md = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(h21(i + g), h21(i + g + 17.0));
			o = 0.5 + 0.45 * sin(TIME * 0.7 + 6.2831 * o);
			md = min(md, length(g + o - f));
		}
	}
	return md;
}
void fragment() {
	vec3 c = COLOR.rgb;
	vec3 cc = vec3(0.55, 0.95, 1.0);
	float cs = strength;
	vec3 em = vec3(0.0);
	float r = length(wp.xz);
	if (mode == 1) {
		c = mix(vec3(0.86, 0.64, 0.66), vec3(0.98, 0.84, 0.8), dot(c, vec3(0.5)) * 1.2) * 0.8;
		vec2 g = wp.xz * 9.0;
		vec2 id = floor(g);
		float hh = h21(id);
		if (hh > 0.8) {
			float d = length(fract(g) - 0.5);
			c = mix(c, vec3(1.0, 0.95, 0.9), smoothstep(0.2, 0.1, d) * 0.8);
		}
		cc = vec3(1.0, 0.85, 0.9);
	} else if (mode == 2) {
		c = mix(c, vec3(0.86, 0.7, 0.4), 0.62);
		vec2 g = wp.xz * 7.0;
		vec2 id = floor(g);
		float hh = h21(id);
		if (hh > 0.72) {
			vec2 o = vec2(h21(id + 3.0), h21(id + 5.0)) * 0.5 + 0.25;
			float d = length(fract(g) - o);
			float coin = smoothstep(0.17, 0.14, d);
			float rim = smoothstep(0.02, 0.0, abs(d - 0.13));
			float glint = pow(max(0.0, sin(TIME * 2.0 + hh * 30.0)), 12.0);
			c = mix(c, vec3(1.0, 0.75, 0.2) * (0.8 + 0.3 * rim), coin);
			em += vec3(1.0, 0.8, 0.3) * coin * (0.15 + glint * 1.4);
		}
		cc = vec3(1.0, 0.92, 0.6);
	} else if (mode == 3) {
		c = vec3(0.05, 0.05, 0.1) + c * 0.12;
		vec2 g = wp.xz * 14.0;
		vec2 id = floor(g);
		float hh = h21(id);
		if (hh > 0.7) {
			float d = length(fract(g) - 0.5 - (vec2(h21(id + 1.0), h21(id + 2.0)) - 0.5) * 0.6);
			vec3 gc = 0.6 + 0.4 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + hh * 3.0));
			float tw = pow(0.5 + 0.5 * sin(TIME * (1.5 + hh * 3.0) + hh * 60.0), 3.0);
			em += gc * smoothstep(0.1, 0.0, d) * (0.4 + 1.8 * tw);
		}
		cc = vec3(0.35, 0.45, 1.0);
		cs = strength * 0.6;
	}
	float k = 0.0;
	if (lite < 0.5 || mode != 3) {
		vec2 p = wp.xz * 1.6;
		k = pow(smoothstep(0.0, 0.9, cell(p)), 3.0);
	}
	float fade = smoothstep(4.2, 1.0, r);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = em + cc * k * cs * fade;
}
"""

const AXO_WINDOW := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform int mode = 0;
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.55, 0.95, 1.0);
	vec3 bot = vec3(0.08, 0.45, 0.6);
	if (mode == 1) { top = vec3(1.0, 0.72, 0.5); bot = vec3(0.55, 0.25, 0.45); }
	if (mode == 2) { top = vec3(1.0, 0.7, 0.95); bot = vec3(0.35, 0.25, 0.7); }
	if (mode == 3) { top = vec3(0.06, 0.12, 0.3); bot = vec3(0.01, 0.02, 0.06); }
	vec3 c = mix(top, bot, smoothstep(0.0, 1.0, uv.y));
	float streak = pow(0.5 + 0.5 * sin(uv.x * 22.0 + sin(uv.y * 3.0 + TIME * 0.6) * 2.0 + TIME * 0.4), 6.0);
	c += top * streak * (1.0 - uv.y) * 0.35;
	float wv = sin(uv.x * 9.0 + TIME * 1.1) * sin(uv.x * 5.0 - TIME * 0.7) * 0.5 + 0.5;
	c += vec3(1.0) * smoothstep(0.1, 0.0, uv.y - 0.03 * wv) * 0.4;
	if (mode == 3) {
		vec2 g = uv * vec2(14.0, 12.0);
		vec2 id = floor(g);
		float hh = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
		if (hh > 0.85) c += vec3(0.4, 0.8, 1.0) * smoothstep(0.12, 0.0, length(fract(g) - 0.5)) * (0.5 + 0.5 * sin(TIME * 2.0 + hh * 40.0));
	}
	ALBEDO = c;
}
"""

const PARTY_BUBBLES := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
varying float fade;
varying vec3 tint;
float h(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() {
	float id = float(INSTANCE_ID);
	float height = 3.6;
	float spd = 0.18 + 0.3 * h(id + 1.0);
	float t = fract(TIME * spd / height + h(id + 2.0));
	float a = 6.2831 * h(id + 3.0);
	float r = 2.6 * sqrt(h(id + 4.0));
	vec3 p = vec3(cos(a) * r + 0.15 * sin(TIME * 1.1 + id), t * height, sin(a) * r + 0.15 * cos(TIME * 0.9 + id));
	float s = 0.06 + 0.07 * h(id + 5.0);
	fade = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.85, t);
	tint = 0.6 + 0.4 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + h(id + 6.0) + TIME * 0.05));
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = p + (right * VERTEX.x + up * VERTEX.y) * s * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float ring = smoothstep(1.0, 0.82, d) * smoothstep(0.45, 0.82, d);
	float hl = smoothstep(0.32, 0.0, length(q - vec2(-0.35, -0.35)));
	ALBEDO = mix(tint, vec3(1.0), hl);
	ALPHA = clamp(ring * 0.85 + hl * 0.9 + smoothstep(1.0, 0.0, d) * 0.15, 0.0, 1.0) * fade;
}
"""


# ---------- 0.15: новые украшения ----------
## Все строятся от точки места (+Z — в комнату). sk: floor / near / big — на дне, wall — висит на стене
## (плоские), ledge — стоит на каменном уступе или на подоконнике просвета, hang — на нитке (или своя).
## Неподвижное склеивается в 2–4 сетки (vp / gm / gl), двигается немногое; свет — свечение и сияние, свои
## источники света — только у фонаря, удильщика, батискафа.

const WOOD := Color("#9A5A34")
const WOOD_D := Color("#6A3A22")
const GOLD := Color("#FFCB45")
const BRASS := Color("#E0A83A")
const CREAM := Color("#FFF3E0")
const ROCK := Color("#3C6E90")


func _new_decor(id: String, n: Node3D, sk: String) -> bool:
	match id:
		"axo_kelp": _d_kelp(n, sk)
		"axo_seahorse": _d_seahorse(n, sk)
		"axo_arch": _d_arch(n)
		"axo_bottle": _d_bottle(n, sk)
		"axo_map": _d_map(n)
		"axo_spyglass": _d_spyglass(n, sk)
		"axo_lantern": _d_ship_lantern(n, sk)
		"axo_barrel": _d_barrel(n)
		"axo_flag": _d_flag(n, sk)
		"axo_wheel": _d_wheel(n)
		"axo_ship": _d_ship(n)
		"axo_plankton": _d_plankton(n, sk)
		"axo_anemones": _d_anemones(n, sk)
		"axo_vent": _d_vent(n)
		"axo_neonsquid": _d_neonsquid(n, sk)
		"axo_crystal": _d_abyss_crystal(n, sk)
		"axo_angler": _d_angler(n)
		"axo_pod": _d_pod(n)
		"axo_jelly": _d_jelly(n)
		"axo_sub": _d_sub(n)
		_: return false
	return true


## Мировая точка внутри вещи (комната стоит в начале координат) — для частиц-шейдеров
func _world(n: Node3D, local: Vector3) -> Vector3:
	return _rel_xf(self, n) * local


## Водоросли-занавес: зелёные ленты колышутся (шейдер «sway»); на стене — на палке, в просвете — растут по краям
func _d_kelp(n: Node3D, sk: String) -> void:
	var cols := [Color("#2FAE7A"), Color("#4FC48A"), Color("#8FB84A"), Color("#3DBE9A"), Color("#6FD07A"), Color("#C8A04A")]
	var g := node(n)
	g.scale = Vector3(1, 1, 0.6)
	if sk == "wall":
		var top := 0.95
		vp(n, cyl(0.035, 0.035, 0.95, 10), Color("#B08A5A"), Vector3(0, top + 0.02, 0.1), Vector3(0, 0, PI / 2.0))
		for sx in [-1.0, 1.0]:
			vp(n, sphere(0.05, 8), Color("#8A6A4A"), Vector3(sx * 0.49, top + 0.02, 0.1))
		for i in 7:
			var x := -0.39 + i * 0.13
			var hh := 0.65 + 0.25 * hash1(i, 3)
			var pts := []
			for k in 9:
				var s := k / 8.0
				pts.append(Vector3(x + 0.04 * sin(s * 5.0 + i), top - s * hh, 0.22 + 0.06 * sin(s * 4.0 + i * 2.0)))
			put(g, ptube(pts, 0.06, 0.04, 5, (cols[i % cols.size()] as Color).lightened(0.1)), _sway)
			put(g, _rotated_leaf(pts[3], i * 1.3, (cols[i % cols.size()] as Color).lightened(0.2), 0.4), _sway)
	else:
		for side in [-1.0, 1.0]:
			for i in 3:
				var base := Vector3(side * (0.22 + 0.07 * i), 0.0, 0.03 * i)
				var hh := 0.6 - 0.12 * i
				var pts := []
				for k in 9:
					var s := k / 8.0
					pts.append(base + Vector3(-side * 0.06 * sin(s * 3.0), s * hh, 0.05 * sin(s * 5.0 + i)))
				put(g, ptube(pts, 0.04, 0.012, 5, cols[(i + int(side + 1)) % cols.size()]), _sway)
				put(g, _rotated_leaf(pts[4], i * 2.0 + side, (cols[i] as Color).lightened(0.15), 0.5), _sway)
		vp(n, sphere(0.1, 10), ROCK, Vector3(-0.28, 0.02, 0), Vector3.ZERO, Vector3(1.2, 0.5, 1.0))
		vp(n, sphere(0.09, 10), Color("#5B92B0"), Vector3(0.3, 0.02, 0.02), Vector3.ZERO, Vector3(1.2, 0.5, 1.0))


## Морской конёк (смотрит в +x): голова с носиком, изогнутое тельце, хвост-завиток, плавник
func _horse(p: Node3D, col: Color) -> void:
	var dark := col.darkened(0.25)
	var body := [Vector3(0.0, 0.2, 0), Vector3(0.035, 0.14, 0), Vector3(0.04, 0.07, 0), Vector3(0.015, 0.01, 0), Vector3(-0.02, -0.04, 0)]
	vp(p, ptube(body, 0.05, 0.035, 8), col)
	var curl := []
	for k in 10:
		var a := PI * 0.5 + k * 0.55
		var r := 0.05 * (1.0 - k * 0.07)
		curl.append(Vector3(-0.02 + cos(a) * r - 0.0, -0.04 - 0.05 + sin(a) * r * 1.0, 0))
	vp(p, ptube(curl, 0.03, 0.01, 6), col)
	vp(p, sphere(0.055, 12), col, Vector3(0.0, 0.25, 0))
	vp(p, cyl(0.018, 0.024, 0.09, 8), col, Vector3(0.07, 0.24, 0), Vector3(0, 0, PI / 2.0 + 0.2))
	vp(p, sphere(0.02, 8), col.lightened(0.3), Vector3(0.115, 0.23, 0), Vector3.ZERO, Vector3.ONE, false)
	vp(p, prism(Vector3(0.05, 0.07, 0.015)), dark, Vector3(-0.04, 0.12, 0), Vector3(0, 0, 0.6), Vector3.ONE, false)
	vp(p, prism(Vector3(0.03, 0.045, 0.015)), dark, Vector3(-0.01, 0.31, 0), Vector3(0, 0, -0.4), Vector3.ONE, false)
	for sz in [-1.0, 1.0]:
		vp(p, sphere(0.016, 8), Color("#1E1236"), Vector3(0.02, 0.265, sz * 0.045), Vector3.ZERO, Vector3.ONE, false)
		vp(p, sphere(0.006, 4), Color.WHITE, Vector3(0.026, 0.272, sz * 0.055), Vector3.ZERO, Vector3.ONE, false)
	for k in 4:
		vp(p, sphere(0.012, 5), col.lightened(0.35), Vector3(0.045, 0.16 - k * 0.04, 0.025), Vector3.ZERO, Vector3.ONE, false)


## Морские коньки: двое плывут навстречу друг другу (сверху — в колечке, на стене — перед стеной)
func _d_seahorse(n: Node3D, sk: String) -> void:
	var c := Vector3(0, 0.22, 0) if sk == "hang" else Vector3(0, 0.42, 0.16)
	if sk == "hang":
		vp(n, torus(0.26, 0.29, 32), Color("#FFB8D6"), c + Vector3(0, 0.02, 0), Vector3(PI / 2.0, 0, 0))
		vp(n, cyl(0.012, 0.012, 0.44, 5), Color("#C9A46A"), c + Vector3(0, -0.01, 0), Vector3(0, 0, PI / 2.0))
		for k in 5:
			var a := TAU * k / 5.0
			vp(n, sphere(0.022, 6), CREAM, c + Vector3(cos(a) * 0.275, sin(a) * 0.275 + 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	else:
		for k in 4:
			var b := put(n, sphere(0.02 + 0.006 * k, 8), glass(Color(0.85, 1.0, 1.0, 0.45), 0.3), c + Vector3(-0.05 + 0.03 * k, 0.2, 0.02))
			anim(b, "rise", {"h": 0.5, "spd": 0.35, "p": k / 4.0})
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var h := node(n, c + Vector3(side * 0.13, -0.12, 0))
		var inner := node(h)
		if side > 0.0:
			inner.rotation.y = PI
		_horse(inner, Color("#FF9E5C") if i == 0 else Color("#C890FF"))
		bake(inner)
		anim(h, "call", {"f": _horse_swim, "side": side, "p": i * 1.7})
	if sk != "hang":
		vp(n, sphere(0.06, 8), Color("#FF7BA8"), Vector3(0, 0.12, 0.06), Vector3.ZERO, Vector3(1.4, 0.6, 0.6))


func _horse_swim(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := sin(t * 0.6 + a.p)
	var o: Vector3 = a.base.origin + Vector3(-a.side * 0.04 * (0.5 + 0.5 * u), 0.035 * sin(t * 1.7 + a.p), 0)
	nd.transform = Transform3D(Basis(Vector3.BACK, 0.12 * sin(t * 1.7 + a.p + 0.8)), o)


## ★ Жемчужная арка: коралловые колонны сходятся аркой, на вершине — раскрытая ракушка с большой жемчужиной;
## жемчуг мерцает, сквозь арку поднимается поток пузырей
func _d_arch(n: Node3D) -> void:
	vp(n, sphere(0.62, 18), Color("#E8D0A8"), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.15, 0.14, 0.62))
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		vp(n, sphere(0.1, 10), ROCK.lerp(Color("#5B92B0"), hash1(k, 2)), Vector3(cos(a) * 0.55, 0.04, sin(a) * 0.3), Vector3.ZERO, Vector3(1.2, 0.6, 1.0))
	var cols := [Color("#FF6F9E"), Color("#FF9E6C")]
	var arc := []
	for side in [-1.0, 1.0]:
		var pts := []
		for k in 11:
			var s := k / 10.0
			var a := lerpf(PI, PI * 0.5, s) if side < 0 else lerpf(0.0, PI * 0.5, s)
			pts.append(Vector3(cos(a) * 0.48, 0.05 + sin(a) * 1.25, 0.05 * sin(s * 6.0)))
		vp(n, ptube(pts, 0.11, 0.07, 10), cols[0] if side < 0 else cols[1])
		arc.append(pts)
		# веточки кораллов по колонне
		for k in range(1, 10):
			var p: Vector3 = pts[k]
			var sd: float = side if k % 2 else -side * 0.6
			var out := Vector3(sd * 0.18, 0.12, 0.1 * ((k % 3) - 1))
			var bc: Color = [Color("#4FD8C8"), Color("#FFB3D0"), Color("#B07CFF"), Color("#FFD36B")][k % 4]
			vp(n, ptube(bez(p, p + out * 0.6 + Vector3(0, 0.05, 0), p + out, 5), 0.04, 0.025, 6), bc)
			vp(n, sphere(0.045, 8), bc.lightened(0.45), p + out, Vector3.ZERO, Vector3.ONE, false)
	# ракушка на вершине
	var top := Vector3(0, 1.3, 0.02)
	vp(n, sphere(0.22, 18), Color("#FFC2D6"), top + Vector3(0, -0.02, 0), Vector3(0.3, 0, 0), Vector3(1.0, 0.3, 0.8))
	vp(n, sphere(0.22, 18), Color("#FFD3E0"), top + Vector3(0, 0.12, -0.08), Vector3(-0.9, 0, 0), Vector3(1.0, 0.3, 0.8))
	for k in 7:
		var a := lerpf(-1.1, 1.1, k / 6.0)
		vp(n, sphere(0.02, 6), Color("#FFE8F0"), top + Vector3(sin(a) * 0.15, 0.14 + cos(a) * 0.05, -0.02), Vector3.ZERO, Vector3(0.7, 0.7, 2.5), false)
	var pearl_m := smat("axo_pearl", PEARL, {})
	put(n, vc(sphere(0.09, 18), Color("#F6F2FF")), pearl_m, top + Vector3(0, 0.07, 0.03))
	# жемчужные нити вдоль арки
	for side in 2:
		var pts: Array = arc[side]
		for k in range(0, 11):
			var p: Vector3 = pts[k] + Vector3(0, 0, 0.11)
			put(n, vc(sphere(0.035 if k % 3 else 0.05, 10), Color("#FFF6FF") if k % 2 else Color("#FFE0F0")), pearl_m, p)
	halo(n, top + Vector3(0, 0.07, 0.05), 0.8, Color(1.0, 0.9, 1.0, 0.4))
	# морская звезда и трава у подножия
	vp(n, extrude(_soft_star(0.1, 0.045), 0.03), Color("#FF8A4C"), Vector3(0.32, 0.05, 0.25), Vector3(-PI / 2.0 + 0.2, 0, 0.4))
	for k in 4:
		var x := -0.35 + k * 0.22
		var pts := [Vector3(x, 0.02, 0.2), Vector3(x + 0.03, 0.2, 0.22), Vector3(x - 0.02, 0.38 + 0.1 * (k % 2), 0.2)]
		put(n, ptube(pts, 0.025, 0.008, 5, Color("#3DBE9A")), _sway)
	# поток пузырей сквозь арку (шейдер, одна сетка)
	shader_swarm(n, "bubbles", 12, {"center": _world(n, Vector3(0, 0.1, 0.0)), "radius": 0.22, "height": 1.5, "size": 0.045}, 4.0)


const PEARL := """
shader_type spatial;
varying vec3 lp;
void vertex() { lp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float ph = TIME * 0.9 + lp.x * 6.0 + lp.y * 4.0;
	vec3 iri = 0.6 + 0.4 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + fres * 0.8 + ph * 0.1));
	ALBEDO = base * mix(vec3(1.0), iri, 0.35);
	ROUGHNESS = 0.12;
	SPECULAR = 0.9;
	EMISSION = base * 0.25 * (0.6 + 0.4 * sin(ph * 2.0)) + iri * fres * 0.5;
}
"""


## Бутылка с письмом: лежит наискосок и покачивается
func _d_bottle(n: Node3D, sk: String) -> void:
	if sk != "ledge":
		vp(n, sphere(0.25, 14), Color("#D8C49A"), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.16, 0.8))
		vp(n, extrude(_soft_star(0.07, 0.03), 0.025), Color("#FF9E6C"), Vector3(0.2, 0.04, 0.14), Vector3(-PI / 2.0, 0, 0.6))
	var g := node(n, Vector3(0, 0.09, 0))
	g.scale = Vector3.ONE * (1.0 if sk == "ledge" else 1.45)
	var b := node(g)
	b.rotation = Vector3(0, 0.4, PI / 2.0 - 0.15)
	put(b, lathe([Vector2(0, -0.14), Vector2(0.065, -0.14), Vector2(0.07, 0.06), Vector2(0.03, 0.12), Vector2(0.025, 0.18), Vector2(0, 0.18)], 18, Color(0.6, 0.9, 0.7)), gl(0.25, 0.05))
	vp(b, cyl(0.026, 0.022, 0.05, 10), Color("#C98A5C"), Vector3(0, 0.19, 0))
	vp(b, cyl(0.035, 0.035, 0.16, 12), CREAM, Vector3(0, -0.03, 0))
	vp(b, torus(0.034, 0.042, 12), Color("#E0556F"), Vector3(0, -0.03, 0), Vector3.ZERO, Vector3(1, 0.3, 1), false)
	bake(g)
	anim(g, "wiggle", {"axis": Vector3.RIGHT, "amp": 0.18, "spd": 0.9})


## Карта сокровищ: свиток на стене, тропинка из точек, крестик мигает (рисует шейдер)
func _d_map(n: Node3D) -> void:
	var c := Vector3(0, 0.42, 0.05)
	var q := put(n, quad(Vector2(0.7, 0.5)), smat("axo_map", AXO_MAP, {}, false), c + Vector3(0, 0, 0.012))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp(n, box(Vector3(0.7, 0.5, 0.02)), Color("#E8D2A0"), c)
	for sx in [-1.0, 1.0]:
		vp(n, cyl(0.035, 0.035, 0.56, 12), Color("#D8BC88"), c + Vector3(sx * 0.37, 0, 0.012))
	for p in [Vector3(-0.3, 0.2, 0.03), Vector3(0.3, 0.2, 0.03), Vector3(-0.3, -0.2, 0.03), Vector3(0.3, -0.2, 0.03)]:
		vp(n, hemi(0.035, 10), Color("#FFC2D6"), c + p, Vector3(PI / 2.0, 0, 0))


## Подзорная труба: латунные колена раздвигаются и сдвигаются; на уступе — на подставке, рядом — на ящике
func _d_spyglass(n: Node3D, sk: String) -> void:
	var y := 0.0
	if sk != "ledge":
		vp(n, box(Vector3(0.42, 0.28, 0.3)), WOOD, Vector3(0, 0.14, 0))
		for k in 3:
			vp(n, box(Vector3(0.43, 0.03, 0.31)), WOOD_D, Vector3(0, 0.04 + k * 0.1, 0), Vector3.ZERO, Vector3.ONE, false)
		vp(n, box(Vector3(0.03, 0.29, 0.31)), WOOD_D, Vector3(0.17, 0.14, 0), Vector3.ZERO, Vector3.ONE, false)
		vp(n, extrude(_soft_star(0.06, 0.028), 0.02), Color("#FF9E6C"), Vector3(-0.1, 0.18, 0.155))
		y = 0.28
	for sx in [-0.12, 0.12]:
		vp(n, cyl(0.015, 0.02, 0.1, 6), WOOD_D, Vector3(sx, y + 0.05, 0))
		vp(n, torus(0.03, 0.045, 10), WOOD_D, Vector3(sx, y + 0.11, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, false)
	var t := node(n, Vector3(0, y + 0.13, 0))
	t.rotation = Vector3(0, -0.25, 0.08)
	vp(t, cyl(0.05, 0.05, 0.26, 16), BRASS, Vector3(-0.05, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, true, 0.35)
	vp(t, torus(0.045, 0.06, 16), Color("#C48A2A"), Vector3(-0.17, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.35)
	vp(t, cyl(0.058, 0.058, 0.03, 16), Color("#5A3A22"), Vector3(-0.19, 0, 0), Vector3(0, 0, PI / 2.0))
	vp(t, cyl(0.048, 0.048, 0.005, 16), Color("#9FE8FF"), Vector3(-0.205, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.2)
	var s1 := node(t, Vector3(0.08, 0, 0))
	vp(s1, cyl(0.04, 0.04, 0.2, 14), BRASS, Vector3(0.0, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, true, 0.35)
	vp(s1, torus(0.035, 0.048, 14), Color("#C48A2A"), Vector3(0.09, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.35)
	var s2 := node(s1, Vector3(0.05, 0, 0))
	vp(s2, cyl(0.03, 0.03, 0.16, 12), BRASS, Vector3(0.0, 0, 0), Vector3(0, 0, PI / 2.0), Vector3.ONE, true, 0.35)
	vp(s2, cyl(0.018, 0.02, 0.05, 10), Color("#5A3A22"), Vector3(0.09, 0, 0), Vector3(0, 0, PI / 2.0))
	bake(s2)
	bake(s1, [s2])
	bake(t, [s1])
	anim(s1, "call", {"f": _slide_x, "d": 0.12, "p": 0.0})
	anim(s2, "call", {"f": _slide_x, "d": 0.1, "p": 0.4})


func _slide_x(nd: Node3D, t: float, a: Dictionary) -> void:
	var o := clampf(sin(t * 0.6 - a.p) * 1.6 + 0.3, 0.0, 1.0)
	nd.transform = Transform3D(Basis(), a.base.origin + Vector3(a.d * o, 0, 0))


## Корабельный фонарь: тёплый огонёк качается; на стене — на кованом кронштейне
func _d_ship_lantern(n: Node3D, sk: String) -> void:
	var host := n
	if sk == "wall":
		var iron := Color("#3A3550")
		vp(n, box(Vector3(0.12, 0.2, 0.03)), iron, Vector3(0, 0.75, 0.015))
		vp(n, cyl(0.016, 0.016, 0.34, 6), iron, Vector3(0, 0.85, 0.17), Vector3(PI / 2.0, 0, 0))
		vp(n, ptube(bez(Vector3(0, 0.66, 0.02), Vector3(0, 0.7, 0.25), Vector3(0, 0.85, 0.32), 6), 0.012, 0.012, 5), iron)
		vp(n, torus(0.02, 0.035, 10), iron, Vector3(0, 0.83, 0.33), Vector3(0, PI / 2.0, 0))
		host = node(n, Vector3(0, 0.81, 0.33))
		anim(host, "pendulum", {"amp": 0.08, "spd": 1.0})
		host = node(host, Vector3(0, -0.5, 0))
	var frame := Color("#4A3A2A")
	vp(host, cyl(0.13, 0.15, 0.05, 12), frame, Vector3(0, 0.025, 0), Vector3.ZERO, Vector3.ONE, true, 0.5)
	put(host, cyl(0.11, 0.11, 0.26, 12), gl(0.3, 0.5), Vector3(0, 0.18, 0))
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		vp(host, cyl(0.012, 0.012, 0.28, 5), BRASS, Vector3(cos(a) * 0.12, 0.18, sin(a) * 0.12), Vector3.ZERO, Vector3.ONE, false, 0.35)
	vp(host, cyl(0.03, 0.15, 0.1, 12), frame, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3.ONE, true, 0.5)
	vp(host, cyl(0.035, 0.035, 0.05, 8), BRASS, Vector3(0, 0.43, 0), Vector3.ZERO, Vector3.ONE, false, 0.35)
	vp(host, torus(0.035, 0.05, 12), BRASS, Vector3(0, 0.48, 0), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	var fl := put(host, sphere(0.045, 10), glow_mat(Color("#FFD46B"), 4.5), Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
	anim(fl, "flame", {"p": 0.5})
	halo(host, Vector3(0, 0.18, 0), 0.85, Color(1.0, 0.75, 0.35, 0.45))
	omni(host, Vector3(0, 0.2, 0.15), Color("#FFB866"), 0.9, 2.6, "flicker")


## Бочка с монетами: монеты насыпаны горкой, время от времени одна выпрыгивает
func _d_barrel(n: Node3D) -> void:
	var g := node(n)
	vp(g, lathe([Vector2(0, 0), Vector2(0.18, 0), Vector2(0.22, 0.12), Vector2(0.23, 0.24), Vector2(0.22, 0.36), Vector2(0.18, 0.46), Vector2(0, 0.46)], 22), WOOD)
	for k in 9:
		var a := TAU * k / 9.0
		vp(g, box(Vector3(0.012, 0.44, 0.03)), WOOD_D, dir(a) * 0.215 + Vector3(0, 0.23, 0), Vector3(0, -a, 0), Vector3.ONE, false)
	for y in [0.07, 0.39]:
		vp(g, torus(0.2, 0.225, 22), Color("#5A5A6A"), Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 0.6, 1), true, 0.4)
	vp(g, cyl(0.17, 0.17, 0.02, 18), Color("#4A2A1A"), Vector3(0, 0.44, 0))
	vp(g, sphere(0.17, 16), GOLD, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.0, 0.45, 1.0), true, 0.3)
	for k in 14:
		var a := hash1(k, 5) * TAU
		var r := 0.15 * sqrt(hash1(k, 6))
		vp(g, cyl(0.035, 0.035, 0.01, 12), Color("#FFD34D"), Vector3(cos(a) * r, 0.5 + 0.04 * (1.0 - r / 0.15), sin(a) * r), Vector3(0.6 * (hash1(k, 7) - 0.5), 0, 0.6 * (hash1(k, 8) - 0.5)), Vector3.ONE, false, 0.3)
	crystal(g, Vector3(0.05, 0.5, 0.03), 0.12, 0.03, Vector3(0.3, 0, -0.4), Color("#FF4D6D"), 1.0)
	vp(g, sphere(0.03, 10), Color("#9FF6FF"), Vector3(-0.06, 0.53, -0.02), Vector3.ZERO, Vector3.ONE, false, 0.2)
	# монеты на песке
	for k in 7:
		var a := 0.6 + k * 0.45
		vp(n, cyl(0.035, 0.035, 0.01, 12), Color("#FFD34D"), dir(a) * (0.3 + 0.08 * hash1(k, 9)) + Vector3(0, 0.008 + 0.01 * (k % 2), 0), Vector3(0.2 * (k % 3), 0, 0.15), Vector3.ONE, false, 0.3)
	# выпрыгивающие монетки
	for k in 3:
		var cn := node(n, Vector3(0, 0.5, 0))
		vp(cn, cyl(0.035, 0.035, 0.01, 12), Color("#FFE27A"), Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3.ONE, false, 0.3)
		bake(cn)
		anim(cn, "call", {"f": _coin_hop, "p": k * 2.1, "a": 0.5 + k * 2.0})
	halo(n, Vector3(0, 0.52, 0), 0.6, Color(1.0, 0.85, 0.3, 0.3))


func _coin_hop(nd: Node3D, t: float, a: Dictionary) -> void:
	var u := fposmod(t * 0.35 + a.p * 0.16, 1.0)
	var on := u < 0.45
	nd.visible = on
	if not on:
		return
	var s := u / 0.45
	var d := dir(a.a) * 0.32 * s
	var y := 0.5 + 0.35 * sin(s * PI) - 0.5 * s * s + 0.01
	nd.transform = Transform3D(Basis(Vector3.UP, t * 9.0) * Basis(Vector3.RIGHT, s * 4.0), Vector3(d.x, maxf(0.01, y), d.z))


## Флаг с ракушкой (без черепов): колышется; на стене — на древке с кронштейна, в просвете — на камне
func _d_flag(n: Node3D, sk: String) -> void:
	var pole := node(n)
	var L := 0.8
	if sk == "wall":
		pole.position = Vector3(-0.25, 0.3, 0.06)
		pole.rotation.z = -0.55
		vp(n, box(Vector3(0.1, 0.14, 0.03)), Color("#3A3550"), Vector3(-0.25, 0.32, 0.015))
		L = 0.72
	else:
		vp(n, sphere(0.1, 10), ROCK, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.2, 0.6, 1.0))
	vp(pole, cyl(0.016, 0.018, L, 8), WOOD, Vector3(0, L * 0.5, 0))
	vp(pole, sphere(0.03, 8), GOLD, Vector3(0, L + 0.02, 0), Vector3.ZERO, Vector3.ONE, true, 0.3)
	var cloth := put(pole, _flag_mesh(0.42, 0.28, 10), smat("axo_flag", AXO_FLAG, {}, false), Vector3(0.0, L - 0.16, 0))
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _flag_cache: Dictionary = {}


## Полотнище флага: плоская сетка (UV.x — от древка к краю: шейдер колышет край сильнее)
static func _flag_mesh(w: float, h: float, nx: int) -> ArrayMesh:
	var key := [w, h, nx]
	if _flag_cache.has(key):
		return _flag_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx:
		for j in 2:
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var v0 := j * 0.5
			var v1 := (j + 1) * 0.5
			var q := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for k in t:
					var uv: Vector2 = q[k]
					st.set_normal(Vector3(0, 0, 1))
					st.set_uv(uv)
					st.add_vertex(Vector3(uv.x * w, h * 0.5 - uv.y * h, 0))
	var m := st.commit()
	_flag_cache[key] = m
	return m


const AXO_FLAG := """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float w = UV.x;
	VERTEX.z += sin(UV.x * 7.0 - TIME * 3.0) * 0.05 * w;
	VERTEX.y += sin(UV.x * 5.0 - TIME * 2.4) * 0.015 * w;
}
void fragment() {
	vec2 uv = vec2(UV.x * 1.5, UV.y);
	vec3 c = vec3(0.12, 0.45, 0.75);
	if (UV.y < 0.12 || UV.y > 0.88) c = vec3(1.0, 0.8, 0.3);
	vec2 p = (uv - vec2(0.75, 0.52)) * vec2(1.0, 1.0);
	float r = length(p);
	float a = atan(p.x, p.y + 0.18);
	float shell = step(r, 0.24) * step(-0.2, p.y + 0.02);
	float ribs = smoothstep(0.05, 0.0, abs(sin(a * 9.0))) * shell;
	c = mix(c, vec3(1.0, 0.72, 0.8), shell);
	c = mix(c, vec3(0.9, 0.45, 0.6), ribs * 0.7);
	float shade = 0.85 + 0.15 * sin(UV.x * 7.0 - TIME * 3.0);
	ALBEDO = c * shade;
	ROUGHNESS = 0.9;
}
"""


## Штурвал: поворачивается туда-сюда на деревянной стойке
func _d_wheel(n: Node3D) -> void:
	var c := Vector3(0, 0.48, 0.12)
	vp(n, box(Vector3(0.14, 0.5, 0.08)), WOOD_D, Vector3(0, 0.25, 0.04))
	vp(n, cyl(0.05, 0.05, 0.12, 12), WOOD_D, c + Vector3(0, 0, -0.05), Vector3(PI / 2.0, 0, 0))
	var w := node(n, c)
	vp(w, torus(0.24, 0.29, 32), WOOD, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	vp(w, torus(0.255, 0.275, 32), GOLD, Vector3(0, 0, 0.025), Vector3(PI / 2.0, 0, 0), Vector3(1, 0.4, 1), false, 0.3)
	vp(w, cyl(0.07, 0.07, 0.06, 16), WOOD_D, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	vp(w, cyl(0.04, 0.04, 0.07, 12), GOLD, Vector3(0, 0, 0.01), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.3)
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector3(cos(a), sin(a), 0)
		vp(w, cyl(0.018, 0.022, 0.4, 8), WOOD, d * 0.18, Vector3(0, 0, a - PI / 2.0))
		vp(w, capsule(0.026, 0.12), WOOD_D, d * 0.36, Vector3(0, 0, a - PI / 2.0))
	bake(w)
	anim(w, "wiggle", {"axis": Vector3.BACK, "amp": 0.7, "spd": 0.55})


## ★ Затонувший кораблик: нос корабля в песке, мачта с парусом-ракушкой, светятся иллюминаторы,
## поднимаются пузыри, из иллюминатора выплывает рыбка
func _d_ship(n: Node3D) -> void:
	vp(n, sphere(0.75, 18), Color("#D8C49A"), Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.1, 0.17, 0.75))
	var hull := node(n, Vector3(0.0, 0.1, 0.0))
	hull.rotation = Vector3(-0.22, 0.55, 0.28)
	var wood := Color("#8A4E2C")
	# корпус: половина «капли» и доски
	vp(hull, hemi(0.5, 20), wood, Vector3(0, 0.35, 0), Vector3(PI, 0, 0), Vector3(0.62, 0.95, 1.25))
	vp(hull, cyl(0.0, 0.31, 0.42, 16), wood, Vector3(0, 0.2, 0.8), Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.55))
	for k in 4:
		vp(hull, torus(0.47 - k * 0.07, 0.5 - k * 0.07, 24), Color("#6A3A22"), Vector3(0, 0.33 - k * 0.11, 0), Vector3.ZERO, Vector3(0.62, 0.5, 1.25), false)
	vp(hull, cyl(0.31, 0.31, 0.04, 20), Color("#B07A4A"), Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1.0, 1.0, 2.0))
	vp(hull, torus(0.29, 0.33, 24), Color("#5A3018"), Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.98))
	# нос и бушприт
	vp(hull, cyl(0.02, 0.03, 0.5, 8), WOOD_D, Vector3(0, 0.45, 0.78), Vector3(1.2, 0, 0))
	vp(hull, sphere(0.06, 10), GOLD, Vector3(0, 0.36, 0.62), Vector3.ZERO, Vector3(0.8, 1.0, 0.6), true, 0.3)
	# иллюминаторы (светятся) с латунными кольцами
	for k in 3:
		for side in [-1.0, 1.0]:
			var p := Vector3(side * 0.3, 0.2, -0.32 + k * 0.3)
			vp(hull, torus(0.04, 0.06, 14), BRASS, p, Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.3)
			vp(hull, sphere(0.045, 10), Color("#FFD27A"), p + Vector3(side * 0.005, 0, 0), Vector3.ZERO, Vector3(0.5, 1, 1), false)
	_glowify(hull, Color("#FFD27A"), 3.0)
	# мачта, рея и парус-ракушка
	vp(hull, cyl(0.035, 0.045, 1.3, 10), WOOD_D, Vector3(0, 1.0, -0.1))
	vp(hull, cyl(0.02, 0.02, 0.7, 8), WOOD_D, Vector3(0, 1.38, -0.1), Vector3(0, 0, PI / 2.0))
	vp(hull, torus(0.08, 0.12, 14), WOOD, Vector3(0, 1.55, -0.1), Vector3.ZERO, Vector3(1, 0.5, 1))
	var sail := put(hull, _flag_mesh(0.6, 0.55, 8), smat("axo_sail", AXO_SAIL, {}, false), Vector3(-0.3, 1.08, -0.07))
	sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-1.0, 1.0]:
		vp(hull, ptube([Vector3(sx * 0.34, 1.38, -0.1), Vector3(sx * 0.2, 0.9, 0.0), Vector3(sx * 0.28, 0.38, 0.0)], 0.006, 0.006, 4), Color("#C9A46A"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var fl := put(hull, _flag_mesh(0.2, 0.12, 6), smat("axo_flag", AXO_FLAG, {}, false), Vector3(0, 1.62, -0.1))
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# водоросли на борту
	for k in 3:
		var p := Vector3(-0.28 + k * 0.05, 0.0, -0.2 + k * 0.25)
		put(hull, ptube([p, p + Vector3(-0.08, 0.2, 0.02), p + Vector3(-0.05, 0.42, 0.0)], 0.03, 0.01, 5, Color("#3DBE9A")), _sway)
	# сокровища у борта
	for k in 6:
		vp(n, cyl(0.035, 0.035, 0.01, 12), Color("#FFD34D"), Vector3(0.35 + 0.05 * k, 0.04 + 0.012 * (k % 3), 0.35 - 0.04 * k), Vector3(0.3 * (k % 2), 0, 0.2), Vector3.ONE, false, 0.3)
	vp(n, extrude(_soft_star(0.09, 0.04), 0.03), Color("#FF8A4C"), Vector3(-0.45, 0.06, 0.35), Vector3(-PI / 2.0 + 0.2, 0, 0.3))
	# рыбка выплывает из иллюминатора и кружит
	var fo := node(n, Vector3(0.1, 0.55, 0.1))
	var fish := node(fo, Vector3(0.6, 0, 0))
	fish.scale = Vector3.ONE * 0.9
	_fish(fish, Color("#FFD36B"))
	anim(fo, "spin", {"spd": -0.45})
	shader_swarm(n, "bubbles", 10, {"center": _world(n, Vector3(0.0, 0.6, 0.0)), "radius": 0.3, "height": 1.6, "size": 0.045}, 4.0)
	halo(n, Vector3(0, 0.5, 0), 1.2, Color(1.0, 0.8, 0.4, 0.22))
	omni(n, Vector3(0.2, 0.6, 0.5), Color("#FFC870"), 0.7, 2.4, "slow")


const AXO_SAIL := """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	VERTEX.z += sin(UV.x * 3.1416) * (0.08 + 0.02 * sin(TIME * 1.3)) * (1.0 - UV.y * 0.3);
}
void fragment() {
	vec2 uv = UV;
	vec3 c = vec3(0.93, 0.88, 0.76);
	float tear = step(0.88, uv.y) * step(0.5, fract(uv.x * 4.0 + uv.y * 3.0));
	if (tear > 0.5) discard;
	vec2 p = uv - vec2(0.5, 0.48);
	float r = length(p);
	float a = atan(p.x, p.y + 0.2);
	float shell = step(r, 0.25) * step(-0.18, p.y);
	float ribs = smoothstep(0.06, 0.0, abs(sin(a * 8.0))) * shell;
	c = mix(c, vec3(1.0, 0.65, 0.75), shell * 0.9);
	c = mix(c, vec3(0.85, 0.4, 0.55), ribs * 0.6);
	c *= 0.8 + 0.2 * smoothstep(0.0, 0.3, uv.y);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""


## Гирлянда планктона: светящиеся точки по нити пульсируют волной; сверху — своя бечёвка, на стене — волной
func _d_plankton(n: Node3D, sk: String) -> void:
	var pts := []
	if sk == "hang":
		for i in 33:
			var s := i / 32.0
			pts.append(Vector3(lerpf(-0.6, 0.6, s), -0.15 - sin(s * PI * 2.0) * 0.12 * (1.0 if s < 0.5 else 0.6) - sin(s * PI) * 0.3, 0.05 * sin(s * 9.0)))
		vp(n, sphere(0.03, 8), ROCK, Vector3.ZERO)
		vp(n, ptube([Vector3.ZERO, pts[0]], 0.005, 0.005, 3), Color("#7FB8D0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		vp(n, ptube([Vector3.ZERO, pts[32]], 0.005, 0.005, 3), Color("#7FB8D0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	else:
		for i in 33:
			var s := i / 32.0
			pts.append(Vector3(lerpf(-0.48, 0.48, s), 0.55 + 0.1 * sin(s * TAU * 1.5), 0.08))
		for p in [pts[0], pts[32]]:
			vp(n, sphere(0.03, 8), ROCK, (p as Vector3) - Vector3(0, 0, 0.04))
	var g := node(n)
	vp(g, ptube(pts, 0.006, 0.006, 4), Color("#7FB8D0"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var cols := [Color("#7FF5E0"), Color("#9F8CFF"), Color("#FF8FD8"), Color("#6FD8FF")]
	for i in range(1, 32, 2):
		var p: Vector3 = pts[i]
		put(g, vc(sphere(0.022 + 0.01 * (i % 3), 8), cols[i % 4]), gm(2.6, 2.4, 0.6), p + Vector3(0, -0.02 * (i % 2), 0))
	halo(g, (pts[16] as Vector3), 1.0, Color(0.5, 0.8, 1.0, 0.18))
	bake(g)
	if sk == "hang":
		anim(g, "pendulum", {"amp": 0.04, "spd": 0.7})


## Светящиеся анемоны: щупальца колышутся, кончики светятся
func _d_anemones(n: Node3D, sk: String) -> void:
	var k := 0.9 if sk == "ledge" else 1.2
	vp(n, sphere(0.2 * k, 12), ROCK, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.4, 0.4, 1.1))
	var tm_ := Shaders.material("sway", {"amp": 0.05, "speed": 1.4, "emit": 0.55, "rough": 0.5})
	tm_.set_meta("merge", true)
	var defs := [[Vector3(-0.1, 0, 0.0), Color("#C060FF"), Color("#FF8FF0"), 1.0], [Vector3(0.12, 0, -0.04), Color("#2FB0D0"), Color("#9FF6FF"), 0.8], [Vector3(0.02, 0, 0.13), Color("#FF5FA0"), Color("#FFD0E8"), 0.65]]
	for d in defs:
		var p: Vector3 = (d[0] as Vector3) * k
		var s: float = d[3] * k
		vp(n, cyl(0.06 * s, 0.08 * s, 0.14 * s, 12), d[1], p + Vector3(0, 0.07 * s, 0))
		for i in 12:
			var a := TAU * i / 12.0
			var o := p + Vector3(0, 0.14 * s, 0) + dir(a) * 0.045 * s
			var pts := [o, o + dir(a) * 0.06 * s + Vector3(0, 0.08 * s, 0), o + dir(a) * 0.09 * s + Vector3(0, 0.17 * s, 0)]
			put(n, ptube(pts, 0.014 * s, 0.024 * s, 5, (d[2] as Color)), tm_)
		put(n, vc(sphere(0.04 * s, 8), d[2]), gm(2.0, 1.5, 0.4), p + Vector3(0, 0.15 * s, 0))
	halo(n, Vector3(0, 0.2 * k, 0), 0.7 * k, Color(0.8, 0.5, 1.0, 0.3))


## Тёплый источник: каменная труба, светящееся жерло, вверх поднимаются светящиеся пузыри
func _d_vent(n: Node3D) -> void:
	vp(n, lathe([Vector2(0, 0), Vector2(0.28, 0), Vector2(0.24, 0.12), Vector2(0.16, 0.3), Vector2(0.13, 0.46), Vector2(0.1, 0.5), Vector2(0.06, 0.42), Vector2(0, 0.42)], 14), Color("#4A4A66"))
	for k in 7:
		var a := TAU * k / 7.0 + 0.2
		var y := 0.06 + 0.06 * (k % 3)
		vp(n, sphere(0.07 + 0.03 * hash1(k, 2), 8), Color("#5A5A78").lerp(Color("#3A3A50"), hash1(k, 3)), dir(a) * (0.24 - y * 0.3) + Vector3(0, y, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	for k in 5:
		var a := TAU * k / 5.0
		vp(n, sphere(0.03, 6), Color("#FF8A3A"), dir(a) * 0.12 + Vector3(0, 0.47, 0), Vector3.ZERO, Vector3.ONE, false)
	put(n, vc(cyl(0.075, 0.06, 0.02, 12), Color("#FFB060")), gm(3.5, 2.5, 0.35), Vector3(0, 0.46, 0))
	_glowify(n, Color("#FF8A3A"), 2.5)
	for i in 6:
		var b := put(n, sphere(0.025 + 0.008 * (i % 3), 8), glow_mat(Color("#FFB8E0") if i % 2 else Color("#FFD08A"), 2.2), Vector3(0.02 * (i % 3 - 1), 0.5, 0.0))
		anim(b, "rise", {"h": 0.9, "spd": 0.45 + 0.05 * i, "p": i / 6.0})
	halo(n, Vector3(0, 0.5, 0), 0.8, Color(1.0, 0.6, 0.4, 0.45))


## Неоновый кальмар: светящаяся трубка-силуэт на тёмной табличке, мигает
func _d_neonsquid(n: Node3D, sk: String) -> void:
	var c := Vector3(0, 0.42, 0.04) if sk != "ledge" else Vector3(0, 0.3, 0)
	if sk == "ledge":
		vp(n, box(Vector3(0.36, 0.05, 0.12)), Color("#2A2440"), Vector3(0, 0.025, 0))
	vp(n, box(Vector3(0.46, 0.56, 0.03)), Color("#1E1A34"), c + Vector3(0, -0.02, -0.01))
	for p in [Vector3(-0.2, 0.23, 0.01), Vector3(0.2, 0.23, 0.01), Vector3(-0.2, -0.27, 0.01), Vector3(0.2, -0.27, 0.01)]:
		vp(n, sphere(0.014, 6), Color("#9A9AB0"), c + p, Vector3.ZERO, Vector3.ONE, false, 0.3)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#FF5FD8")
	m.emission_enabled = true
	m.emission = Color("#FF5FD8")
	m.emission_energy_multiplier = 3.0
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color("#5FF0FF")
	m2.emission_enabled = true
	m2.emission = Color("#5FF0FF")
	m2.emission_energy_multiplier = 3.0
	var mantle := []
	for i in 15:
		var a := lerpf(-PI * 0.42, PI * 1.42, i / 14.0)
		var r := 0.11 + 0.06 * pow(maxf(0.0, sin(a)), 4.0)
		mantle.append(c + Vector3(cos(a) * 0.1, 0.08 + sin(a) * r, 0.03))
	put(n, ptube(mantle, 0.012, 0.012, 5), m)
	for i in 5:
		var x := -0.08 + i * 0.04
		var pts := []
		for k in 7:
			var s := k / 6.0
			pts.append(c + Vector3(x + 0.03 * sin(s * 6.0 + i), 0.0 - s * 0.24, 0.03))
		put(n, ptube(pts, 0.01, 0.008, 4), m2)
	for sx in [-1.0, 1.0]:
		put(n, torus(0.014, 0.024, 10), m2, c + Vector3(sx * 0.04, 0.08, 0.03), Vector3(PI / 2.0, 0, 0))
	halo(n, c + Vector3(0, 0.0, 0.05), 0.9, Color(1.0, 0.4, 0.9, 0.3))
	anim(node(n), "call", {"f": _neon_blink.bind(m, m2)})


func _neon_blink(_nd: Node3D, t: float, _a: Dictionary, m: StandardMaterial3D, m2: StandardMaterial3D) -> void:
	var u := fposmod(t, 5.0)
	var flick := 1.0
	if u > 4.3 and u < 4.6:
		flick = 0.25 if fposmod(t * 14.0, 1.0) < 0.5 else 1.0
	m.emission_energy_multiplier = 3.0 * flick * (0.85 + 0.15 * sin(t * 3.0))
	m2.emission_energy_multiplier = 3.0 * (flick if u > 4.4 else 1.0) * (0.85 + 0.15 * sin(t * 3.0 + 1.5))


## Кристалл бездны: тёмная призма, внутри пульсирует светящееся ядро
func _d_abyss_crystal(n: Node3D, sk: String) -> void:
	var k := 0.7 if sk == "ledge" else 1.15
	vp(n, sphere(0.2 * k, 12), Color("#2A2A44"), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.3, 0.45, 1.1))
	var core := put(n, sphere(0.08 * k, 14), glow_mat(Color("#B07CFF"), 3.5, true), Vector3(0, 0.3 * k, 0))
	anim(core, "pulse", {"amp": 0.15, "spd": 1.6})
	anim(core, "bulb", {"e0": 3.0, "e1": 1.5, "spd": 1.6})
	var g := node(n, Vector3(0, 0.02, 0))
	var cm := gl(0.35, 0.25)
	put(g, vc(cyl(0.12 * k, 0.1 * k, 0.4 * k, 6), Color("#6A4AC8")), cm, Vector3(0, 0.22 * k, 0))
	put(g, vc(cyl(0.0, 0.12 * k, 0.18 * k, 6), Color("#6A4AC8")), cm, Vector3(0, 0.51 * k, 0))
	for d in [[Vector3(-0.13, 0, 0.04), 0.25, Vector3(0, 0, 0.45)], [Vector3(0.12, 0, -0.02), 0.3, Vector3(0.1, 0, -0.4)], [Vector3(0.03, 0, 0.12), 0.18, Vector3(0.5, 0, 0.0)]]:
		var c := node(g, (d[0] as Vector3) * k)
		c.rotation = d[2]
		var h: float = d[1] * k
		put(c, vc(cyl(0.05 * k, 0.045 * k, h * 0.72, 6), Color("#8A5CFF")), gm(1.4, 1.2, 0.35), Vector3(0, h * 0.36, 0))
		put(c, vc(cyl(0.0, 0.05 * k, h * 0.28, 6), Color("#8A5CFF")), gm(1.4, 1.2, 0.35), Vector3(0, h * 0.86, 0))
	halo(n, Vector3(0, 0.3 * k, 0), 0.9 * k, Color(0.65, 0.4, 1.0, 0.4))


## Добрый удильщик-ночник: круглый, большие глазки, улыбка; огонёк на «удочке» покачивается
func _d_angler(n: Node3D) -> void:
	vp(n, sphere(0.22, 12), ROCK, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.4, 0.4, 1.1))
	var b := node(n, Vector3(0, 0.3, 0))
	anim(b, "bob", {"amp": 0.02, "spd": 1.3})
	var body := Color("#5A6AD8")
	vp(b, sphere(0.2, 20), body, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.92, 1.05))
	vp(b, sphere(0.16, 16), Color("#A8B8FF"), Vector3(0, -0.07, 0.07), Vector3.ZERO, Vector3(1.0, 0.7, 0.9), false)
	for sx in [-1.0, 1.0]:
		vp(b, sphere(0.06, 14), Color.WHITE, Vector3(sx * 0.08, 0.06, 0.16), Vector3.ZERO, Vector3(1, 1, 0.6))
		vp(b, sphere(0.035, 10), Color("#1E1236"), Vector3(sx * 0.08, 0.055, 0.195), Vector3.ZERO, Vector3(1, 1, 0.5), false)
		vp(b, sphere(0.012, 6), Color.WHITE, Vector3(sx * 0.08 - 0.012, 0.07, 0.21), Vector3.ZERO, Vector3.ONE, false)
		vp(b, sphere(0.03, 8), Color("#FF8FB0"), Vector3(sx * 0.13, -0.02, 0.15), Vector3.ZERO, Vector3(1.2, 0.6, 0.4), false)
		vp(b, prism(Vector3(0.1, 0.1, 0.02)), Color("#5A6AC8"), Vector3(sx * 0.2, -0.02, 0.0), Vector3(0, sx * 0.5, sx * 1.2))
	vp(b, torus(0.04, 0.052, 16), Color("#1E1236"), Vector3(0, -0.05, 0.17), Vector3(PI / 2.0 - 0.3, 0, 0), Vector3(1.4, 1, 0.5), false)
	for sx in [-1.0, 1.0]:
		vp(b, prism(Vector3(0.02, 0.025, 0.01)), Color.WHITE, Vector3(sx * 0.022, -0.075, 0.2), Vector3(PI, 0, 0), Vector3.ONE, false)
	vp(b, prism(Vector3(0.14, 0.12, 0.03)), Color("#5A6AC8"), Vector3(0, 0.0, -0.22), Vector3(PI / 2.0, 0, 0))
	var rod := node(b, Vector3(0, 0.17, 0.02))
	vp(rod, ptube(bez(Vector3.ZERO, Vector3(0, 0.18, 0.05), Vector3(0, 0.16, 0.2), 6), 0.012, 0.008, 5), body)
	put(rod, sphere(0.045, 12), glow_mat(Color("#BFFFF0"), 4.0), Vector3(0, 0.12, 0.22))
	halo(rod, Vector3(0, 0.12, 0.22), 0.7, Color(0.6, 1.0, 0.9, 0.5))
	omni(rod, Vector3(0, 0.12, 0.3), Color("#9FFFE8"), 0.7, 2.0, "pulse")
	bake(rod)
	anim(rod, "pendulum", {"amp": 0.18, "spd": 1.4})
	bake(b, [rod])


## Кресло-капсула: прозрачная полусфера с подсветкой, подушка внутри
func _d_pod(n: Node3D) -> void:
	vp(n, cyl(0.06, 0.12, 0.16, 12), Color("#2A2A44"), Vector3(0, 0.08, 0))
	put(n, vc(torus(0.3, 0.34, 28), Color("#5FF0FF")), gm(2.6, 1.2, 0.3), Vector3(0, 0.17, 0))
	vp(n, sphere(0.34, 22), Color("#3A3A66"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.0, 0.4, 1.0))
	var shell := put(n, vc(hemi(0.42, 24), Color("#9FE8FF")), gl(0.22, 0.15), Vector3(0, 0.34, -0.02), Vector3(-PI / 2.0 - 0.35, 0, 0))
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp(n, torus(0.38, 0.42, 28), Color("#9F8CFF"), Vector3(0, 0.34, -0.02), Vector3(-0.35, 0, 0), Vector3.ONE, true, 0.35)
	vp(n, sphere(0.27, 18), Color("#FF8FD8"), Vector3(0, 0.4, 0.02), Vector3.ZERO, Vector3(1.0, 0.35, 0.9))
	vp(n, sphere(0.2, 16), Color("#FFB3E6"), Vector3(0, 0.55, -0.16), Vector3(-0.4, 0, 0), Vector3(1.0, 0.7, 0.35))
	for k in 6:
		var a := lerpf(-1.2, 1.2, k / 5.0)
		put(n, vc(sphere(0.022, 6), Color("#FFE27A")), gm(3.0, 2.0, 0.5), Vector3(sin(a) * 0.38, 0.34 + cos(a) * 0.38 * 0.95, -0.16 - cos(a) * 0.1))
	halo(n, Vector3(0, 0.45, 0), 1.0, Color(0.5, 0.9, 1.0, 0.3))


## Медузы-люстра: три купола на кольце пульсируют голубым и розовым, щупальца колышутся
func _d_jelly(n: Node3D) -> void:
	vp(n, sphere(0.03, 8), ROCK, Vector3.ZERO)
	vp(n, cyl(0.006, 0.006, 0.25, 4), Color("#9FE8FF"), Vector3(0, -0.125, 0), Vector3.ZERO, Vector3.ONE, false)
	vp(n, torus(0.2, 0.225, 28), Color("#9F8CFF"), Vector3(0, -0.25, 0), Vector3.ZERO, Vector3.ONE, true, 0.4)
	for k in 3:
		var a := TAU * k / 3.0
		vp(n, cyl(0.004, 0.004, 0.28, 3), Color("#9FE8FF"), dir(a) * 0.105 + Vector3(0, -0.125, 0), Vector3(0, 0, 0), Vector3.ONE, false)
	var tm_ := Shaders.material("sway", {"amp": 0.06, "speed": 1.2, "emit": 1.0, "rough": 0.5})
	tm_.set_meta("merge", true)
	var cols := [Color("#7FD8FF"), Color("#FF9FE0"), Color("#9F8CFF")]
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var j := node(n, dir(a) * 0.21 + Vector3(0, -0.45 - 0.1 * (k % 2), 0))
		vp(n, cyl(0.004, 0.004, 0.2 + 0.1 * (k % 2), 3), Color("#9FE8FF"), dir(a) * 0.21 + Vector3(0, -0.25 - (0.1 + 0.05 * (k % 2)), 0), Vector3.ZERO, Vector3.ONE, false)
		var dome := node(j)
		put(dome, vc(hemi(0.13, 18), cols[k]), gl(0.45, 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1))
		put(dome, vc(sphere(0.06, 10), cols[k].lightened(0.4)), gm(2.6), Vector3(0, 0.05, 0))
		bake(dome)
		anim(dome, "pulse", {"amp": 0.09, "spd": 1.6, "p": k * 1.4})
		for t in 5:
			var aa := TAU * t / 5.0
			var pts := [Vector3(cos(aa) * 0.08, 0, sin(aa) * 0.08), Vector3(cos(aa) * 0.09, -0.12, sin(aa) * 0.09 + 0.02), Vector3(cos(aa) * 0.07, -0.26, sin(aa) * 0.07)]
			put(j, ptube(pts, 0.01, 0.004, 4, cols[k]), tm_)
		halo(j, Vector3(0, 0.03, 0), 0.6, Color(cols[k], 0.4))
		anim(j, "bob", {"amp": 0.025, "spd": 1.1, "p": k * 2.0})


## ★ Батискаф: жёлтая сфера на полозьях, большой иллюминатор, прожектор водит лучом, винт крутится
func _d_sub(n: Node3D) -> void:
	var g := node(n, Vector3(0, 0.0, 0))
	g.rotation.y = 0.35
	var yel := Color("#FFC83A")
	var c := Vector3(0, 0.62, 0)
	# полозья
	for sx in [-1.0, 1.0]:
		vp(g, capsule(0.04, 1.0), Color("#5A5A6A"), Vector3(sx * 0.32, 0.06, 0), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.4)
		for z in [-0.25, 0.25]:
			vp(g, cyl(0.025, 0.025, 0.36, 8), Color("#5A5A6A"), Vector3(sx * 0.25, 0.24, z), Vector3(0, 0, -sx * 0.35), Vector3.ONE, false, 0.4)
	# корпус-сфера
	vp(g, sphere(0.48, 28), yel, c, Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(g, torus(0.46, 0.5, 32), Color("#E0A020"), c, Vector3.ZERO, Vector3(1, 0.4, 1), false, 0.35)
	for k in 16:
		var a := TAU * k / 16.0
		vp(g, sphere(0.018, 6), Color("#C8961E"), c + Vector3(cos(a) * 0.485, 0.03, sin(a) * 0.485), Vector3.ZERO, Vector3.ONE, false, 0.35)
	# большой иллюминатор спереди
	var port := c + Vector3(0, 0.04, 0.42)
	vp(g, torus(0.17, 0.23, 28), BRASS, port, Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.3)
	vp(g, cyl(0.18, 0.18, 0.02, 24), Color("#1A3A5A"), port + Vector3(0, 0, -0.03), Vector3(PI / 2.0, 0, 0))
	put(g, vc(cyl(0.12, 0.12, 0.01, 18), Color("#5FD8FF")), gm(1.2, 1.0, 0.3), port + Vector3(0, -0.03, -0.015), Vector3(PI / 2.0, 0, 0))
	# внутри — мягкая игрушка-аксолотлик
	vp(g, sphere(0.06, 12), Color("#FFB8D0"), port + Vector3(0, -0.02, -0.01), Vector3.ZERO, Vector3(1.2, 1, 0.6), false)
	for sx in [-1.0, 1.0]:
		vp(g, sphere(0.012, 6), Color("#1E1236"), port + Vector3(sx * 0.025, -0.01, 0.03), Vector3.ZERO, Vector3.ONE, false)
		vp(g, capsule(0.008, 0.05), Color("#FF7BA8"), port + Vector3(sx * 0.07, 0.03, 0.0), Vector3(0, 0, sx * 0.6), Vector3.ONE, false)
	put(g, vc(hemi(0.18, 20), Color("#BFEFFF")), gl(0.18, 0.1), port + Vector3(0, 0, 0.0), Vector3(PI / 2.0, 0, 0), Vector3(1, 0.5, 1))
	for side in [-1.0, 1.0]:
		var sp := c + Vector3(side * 0.42, 0.1, 0.12)
		vp(g, torus(0.05, 0.075, 16), BRASS, sp, Vector3(0, 0, PI / 2.0), Vector3.ONE, false, 0.3)
		put(g, vc(sphere(0.05, 10), Color("#FFE08A")), gm(2.2, 1.0, 0.2), sp + Vector3(side * 0.01, 0, 0), Vector3.ZERO, Vector3(0.4, 1, 1))
	# люк сверху
	vp(g, cyl(0.15, 0.17, 0.1, 18), Color("#E0A020"), c + Vector3(0, 0.48, 0), Vector3.ZERO, Vector3.ONE, true, 0.35)
	vp(g, torus(0.06, 0.08, 16), Color("#5A5A6A"), c + Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE, false, 0.4)
	# антенна с мигающим огоньком
	vp(g, cyl(0.01, 0.01, 0.3, 5), Color("#5A5A6A"), c + Vector3(-0.15, 0.6, -0.1), Vector3.ZERO, Vector3.ONE, false, 0.4)
	var blink := put(g, sphere(0.03, 8), glow_mat(Color("#FF4D6D"), 3.0, true), c + Vector3(-0.15, 0.77, -0.1))
	anim(blink, "bulb", {"e0": 1.5, "e1": 2.5, "spd": 4.0})
	# прожектор: водит лучом
	var lamp := node(g, c + Vector3(0.18, 0.4, 0.22))
	vp(lamp, cyl(0.07, 0.06, 0.14, 14), Color("#5A5A6A"), Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.4)
	put(lamp, vc(cyl(0.06, 0.06, 0.01, 14), Color("#FFF6C8")), gm(4.0), Vector3(0, 0, 0.075), Vector3(PI / 2.0, 0, 0))
	var beam := put(lamp, cyl(0.42, 0.06, 1.6, 16), smat("axo_beam", BEAM, {"col": Color(1.0, 0.95, 0.7, 0.35)}, false), Vector3(0, 0, 0.88), Vector3(PI / 2.0, 0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bake(lamp)
	lamp.rotation.x = 0.35
	anim(lamp, "call", {"f": _searchlight})
	# винт сзади
	vp(g, cyl(0.06, 0.1, 0.18, 12), Color("#E0A020"), c + Vector3(0, 0, -0.52), Vector3(PI / 2.0, 0, 0), Vector3.ONE, true, 0.35)
	vp(g, prism(Vector3(0.04, 0.26, 0.16)), Color("#E0A020"), c + Vector3(0, 0.16, -0.55), Vector3(0, PI / 2.0, 0))
	var prop := node(g, c + Vector3(0, 0, -0.63))
	vp(prop, sphere(0.045, 10), Color("#5A5A6A"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true, 0.4)
	for k in 3:
		var a := TAU * k / 3.0
		vp(prop, sphere(0.1, 10), BRASS, Vector3(cos(a) * 0.1, sin(a) * 0.1, 0), Vector3(0.5, 0, a), Vector3(1.0, 0.35, 0.12), true, 0.3)
	bake(prop)
	anim(prop, "spin", {"axis": Vector3.BACK, "spd": 5.0})
	shader_swarm(n, "bubbles", 8, {"center": _world(n, Vector3(0.0, 0.5, -0.5)), "radius": 0.15, "height": 1.5, "size": 0.04}, 4.0)
	halo(g, port, 0.8, Color(0.5, 0.9, 1.0, 0.35))
	omni(g, port + Vector3(0, 0.1, 0.4), Color("#9FE8FF"), 0.7, 2.4, "slow")


func _searchlight(nd: Node3D, t: float, a: Dictionary) -> void:
	nd.transform = Transform3D(Basis(Vector3.UP, 0.6 * sin(t * 0.45)) * Basis(Vector3.RIGHT, 0.35 + 0.12 * sin(t * 0.3)), a.base.origin)


## Сделать светящимися детали группы цвета col (окошки, угли): материал — gm (одна сетка на все)
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


const AXO_MAP := """
shader_type spatial;
render_mode cull_back;
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
void fragment() {
	vec2 uv = UV * vec2(1.4, 1.0);
	vec3 paper = vec3(0.92, 0.82, 0.6) * (0.9 + 0.1 * vn(UV * 12.0));
	vec3 c = paper;
	float land = vn(uv * 3.0 + 1.0) * 0.7 + vn(uv * 7.0) * 0.3;
	float isl = smoothstep(0.58, 0.6, land);
	vec3 sea = vec3(0.55, 0.78, 0.82);
	c = mix(mix(paper, sea, 0.5), mix(paper, vec3(0.6, 0.78, 0.45), 0.6), isl);
	c = mix(c, vec3(0.45, 0.35, 0.25), smoothstep(0.012, 0.0, abs(land - 0.59)));
	// тропинка из точек к крестику
	vec2 a = vec2(0.12, 0.8);
	vec2 b = vec2(0.45, 0.45);
	vec2 e = vec2(0.82, 0.3);
	float t1 = clamp(dot(UV - a, b - a) / dot(b - a, b - a), 0.0, 1.0);
	float t2 = clamp(dot(UV - b, e - b) / dot(e - b, e - b), 0.0, 1.0);
	float d1 = seg(UV, a, b);
	float d2 = seg(UV, b, e);
	float dots = smoothstep(0.012, 0.0, d1) * step(0.5, fract(t1 * 9.0)) + smoothstep(0.012, 0.0, d2) * step(0.5, fract(t2 * 9.0));
	c = mix(c, vec3(0.55, 0.25, 0.15), clamp(dots, 0.0, 1.0));
	// крестик мигает
	vec2 q = UV - e;
	float x = min(seg(q, vec2(-0.05, -0.05), vec2(0.05, 0.05)), seg(q, vec2(-0.05, 0.05), vec2(0.05, -0.05)));
	float xm = smoothstep(0.016, 0.0, x);
	float bl = 0.5 + 0.5 * sin(TIME * 4.0);
	c = mix(c, vec3(0.9, 0.15, 0.15), xm);
	// роза ветров
	vec2 r = UV - vec2(0.18, 0.22);
	float star = smoothstep(0.01, 0.0, min(abs(r.x), abs(r.y)) - 0.004) * smoothstep(0.09, 0.0, length(r));
	c = mix(c, vec3(0.35, 0.25, 0.2), star);
	c = mix(c, vec3(0.55, 0.4, 0.25), smoothstep(0.03, 0.0, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y))) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0, 0.2, 0.15) * xm * bl * 1.5;
}
"""

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.95, 0.7, 0.35);
void fragment() {
	float v = UV.y;
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.4);
	float flick = 0.8 + 0.2 * sin(TIME * 2.0 + UV.x * 18.0 - v * 6.0);
	ALBEDO = col.rgb * col.a * smoothstep(0.0, 0.6, v) * edge * flick;
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
