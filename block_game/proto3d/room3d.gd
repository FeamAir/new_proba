extends Node3D
## ПРОТОТИП: дупло совёнка в 3D. Не часть игры — отдельная сцена для пробы.
## Запуск: <godot> --path block_game proto3d/room3d.tscn
##
## Всё строится кодом из простых 3D-фигур Godot (шар, цилиндр, тор, коробка, призма)
## и нескольких своих сеток (стены-кора, пол, плоские фигуры «вырезанные из картона» — звёзды, полумесяц).
## Стиль — «мягкая игрушка»: скруглённые формы, матовые материалы, тёмная обводка как у 2D-героев,
## светящиеся вещи слегка сияют. Герой — 2D-«картонка» (hero_card.gd), всегда повёрнутая к камере.
##
## Украшения стоят в тех же 6 местах, что и в 2D-доме (scripts/home.gd SPOTS):
## floor_l, floor_r, wall_l, wall_r, hang, near — так примерка из гардероба переносится без изменений.

const HeroCard := preload("res://proto3d/hero_card.gd")
const OUT := Color("#1E1236")

## Радиус дупла и высота стен
const R := 3.0
const WALL_H := 3.4
const TOP_H := 4.9
## Окно-дупло: направление (угол по кругу) и размеры
## Размер пикселя картонки героя (м): совёнок ~0.8 м
const HPS := 0.0024
const WIN_ANG := -PI / 2.0
const WIN_Y := 2.15
const WIN_HALF_ANG := 0.33
const WIN_HALF_H := 0.78

## Места украшений: угол по кругу, расстояние от центра, высота
const SPOTS3D := {
	"floor_l": [deg_to_rad(205.0), 2.05, 0.0],
	"floor_r": [deg_to_rad(-25.0), 2.1, 0.0],
	"wall_l": [deg_to_rad(222.0), R - 0.06, 1.75],
	"wall_r": [deg_to_rad(-50.0), R - 0.1, 1.5],
	"hang": [deg_to_rad(-140.0), 1.45, 3.55],
	"near": [deg_to_rad(28.0), 0.95, 0.0],
}
## Что стоит в комнате (как словарь placed в игре)
var placed := {
	"floor_l": "owl_nightlight", "floor_r": "owl_mushrooms", "wall_l": "owl_birdhouse",
	"wall_r": "owl_books", "hang": "owl_moon", "near": "owl_lantern",
}
var outfit := {"head": "wreath", "neck": "scarf"}

var cam: Camera3D
var card: Node2D
var hero_sprite: Sprite3D
## Предметы, к которым можно «подлететь» двойным тапом: [узел, точка-центр, расстояние камеры, имя]
var focusables := []
## Узлы, которые отбрасывают тень от фонарика (остальные — нет: тень с куба дорогая, каждый предмет рисуется ещё 6 раз)
var casters := []
## Анимации: [узел, вид, параметры]
var anims := []
var lights := []
var flies: MultiMeshInstance3D
var info: Label
var _t := 0.0
var _mats := {}
var _outline: StandardMaterial3D


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_outline = StandardMaterial3D.new()
	_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline.grow = true
	_outline.grow_amount = 0.012
	_outline.albedo_color = OUT
	_environment()
	_walls()
	_floor()
	_window()
	_nest()
	_room_details()
	for spot in placed:
		_place(spot, placed[spot])
	_garland(deg_to_rad(-165.0), deg_to_rad(-15.0), 3.05)
	_fireflies()
	_hero()
	_camera()
	_ui()
	_shadow_casters()
	if not OS.get_environment("PROTO_NO_MERGE"):
		_merge_static()


# ---------- Материалы и фигуры ----------

func mat(col: Color, rough := 0.85, emit := 0.0, outline := true, emit_col := Color(-1, 0, 0)) -> StandardMaterial3D:
	var key := [col, rough, emit, outline, emit_col]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.25
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col if emit_col.r < 0.0 else emit_col
		m.emission_energy_multiplier = emit
	# мягкий «бархатный» край, как у игрушки
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if outline:
		m.next_pass = _outline
	_mats[key] = m
	return m


func glass(col: Color, emit: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(col, 1.0)
	m.emission_energy_multiplier = emit
	m.roughness = 0.2
	return m


func put(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func sphere(r: float, segs := 20) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(6, segs / 2)
	return s


func cyl(r_top: float, r_bot: float, h: float, segs := 18) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func torus(r_in: float, r_out: float, segs := 28) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = segs
	t.ring_segments = 10
	return t


func node(parent: Node3D, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


## Направление по кругу дупла (угол a): точка на полу
static func dir(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))


## Поворот вокруг оси Y, при котором «перед» узла (+Z) смотрит в центр комнаты
static func face_center(a: float) -> float:
	var d := -dir(a)
	return atan2(d.x, d.z)


static func _hash(i: int, k: int) -> float:
	return fposmod(sin(i * 127.1 + k * 311.7) * 43758.5453, 1.0)


## Треугольник с нужной стороной «наружу» (Godot: лицевая сторона — по часовой стрелке)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tv := b
		b = c
		c = tv
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Плоская фигура с толщиной (как вырезанная из толстого картона): звёзды, полумесяц
func extrude(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var hz := depth * 0.5
	var w := Color.WHITE
	for s in [1.0, -1.0]:
		for i in range(0, idx.size(), 3):
			var a := Vector3(poly[idx[i]].x, poly[idx[i]].y, hz * s)
			var b := Vector3(poly[idx[i + 1]].x, poly[idx[i + 1]].y, hz * s)
			var c := Vector3(poly[idx[i + 2]].x, poly[idx[i + 2]].y, hz * s)
			_tri(st, a, b, c, Vector3(0, 0, s), w, w, w)
	var ctr := Vector2.ZERO
	for p in poly:
		ctr += p
	ctr /= poly.size()
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var mid := (p0 + p1) * 0.5
		var e := p1 - p0
		var n2 := Vector2(e.y, -e.x).normalized()
		if n2.dot(mid - ctr) < 0.0:
			n2 = -n2
		var n := Vector3(n2.x, n2.y, 0)
		var a := Vector3(p0.x, p0.y, hz)
		var b := Vector3(p1.x, p1.y, hz)
		var c := Vector3(p1.x, p1.y, -hz)
		var d := Vector3(p0.x, p0.y, -hz)
		_tri(st, a, b, c, n, w, w, w)
		_tri(st, a, c, d, n, w, w, w)
	st.index()
	st.generate_normals()
	return st.commit()


## Много одинаковых мелочей одной сеткой (MultiMesh): один вызов отрисовки на всех
func scatter(parent: Node3D, mesh: Mesh, m: Material, xfs: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	parent.add_child(mmi)
	return mmi


## Трубка по точкам (корни, верёвка гирлянды): одна сетка вместо десятков цилиндров — меньше вызовов отрисовки
static func tube(pts: Array, r0: float, r1: float, sides := 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var rings := []
	var norms := []
	var prev_side := Vector3.RIGHT
	for i in n:
		var p: Vector3 = pts[i]
		var fwd: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.1:
			side = prev_side
		side = side.normalized()
		prev_side = side
		var up := side.cross(fwd).normalized()
		var r := lerpf(r0, r1, float(i) / (n - 1))
		var ring := []
		var nr := []
		for k in sides + 1:
			var a := TAU * k / sides
			var d := side * cos(a) + up * sin(a)
			ring.append(p + d * r)
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		for k in sides:
			var quad := [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var vs := []
				var ns := []
				for q in tri:
					vs.append(rings[quad[q][0]][quad[q][1]])
					ns.append(norms[quad[q][0]][quad[q][1]])
				var fn: Vector3 = ns[0] + ns[1] + ns[2]
				if ((vs[1] as Vector3) - vs[0]).cross((vs[2] as Vector3) - vs[0]).dot(fn) > 0.0:
					vs = [vs[0], vs[2], vs[1]]
					ns = [ns[0], ns[2], ns[1]]
				for v in 3:
					st.set_normal(ns[v])
					st.add_vertex(vs[v])
	return st.commit()


func _shadow_casters() -> void:
	for gi in find_children("*", "GeometryInstance3D", true, false):
		var on := false
		for c in casters:
			if c == gi or (c as Node).is_ancestor_of(gi):
				on = true
				break
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Склейка неподвижных деталей: все детали с одинаковым материалом — в одну сетку.
## Было ~650 вызовов отрисовки, станет в разы меньше (важно для слабых телефонов).
func _merge_static() -> void:
	var moving := []
	for a in anims:
		moving.append(a[0])
	var groups := {}
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.material_override
		if m == null or not (m is StandardMaterial3D):
			continue
		if (m as StandardMaterial3D).billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			continue
		if (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var skip := false
		for mv in moving:
			if mv == mi or (mv as Node).is_ancestor_of(mi):
				skip = true
				break
		if skip:
			continue
		var key := [m, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi in list:
			var mesh: Mesh = mi.mesh
			for sidx in mesh.get_surface_count():
				st.append_from(mesh, sidx, global_transform.affine_inverse() * mi.global_transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = key[0]
		merged.cast_shadow = key[1]
		add_child(merged)
		for mi in list:
			mi.queue_free()


# ---------- Окружение и свет ----------

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#120B24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6E5AA8")
	env.ambient_light_energy = 0.55
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
	we.environment = env
	add_child(we)


# ---------- Стены-кора ----------

## Радиус стены на высоте y: чуть пузатая внизу, сверху смыкается куполом
static func wall_r(y: float) -> float:
	if y <= WALL_H:
		return R * (1.0 + 0.04 * sin(y / WALL_H * PI) - 0.05 * y / WALL_H)
	var s := clampf((y - WALL_H) / (TOP_H - WALL_H), 0.0, 1.0)
	return R * 0.95 * sqrt(maxf(0.0, 1.0 - s * s))


func _walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_seg := 176
	var ys := []
	var y := -0.05
	while y < WALL_H:
		ys.append(y)
		y += 0.12
	for j in 12:
		ys.append(WALL_H + (TOP_H - WALL_H) * sin((j + 1) / 12.0 * PI / 2.0))
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
			# продольные бороздки коры, слегка извилистые
			var w := sin(a * 41.0 + 1.3 * sin(yy * 1.4 + a * 5.0) + 0.6 * sin(yy * 3.1 + a * 2.0)) * 0.75 + 0.25 * sin(a * 97.0 + yy * 2.0)
			var ridge := signf(w) * pow(absf(w), 0.55)
			# поперечные трещинки коры
			var crack := smoothstep(0.82, 1.0, sin(yy * 6.5 + a * 9.0 + 2.0 * sin(a * 3.0))) * smoothstep(0.0, 0.6, ridge)
			var r := wall_r(yy) * (1.0 + (0.028 * ridge - 0.012 * crack) * clampf(1.0 - (yy - WALL_H) / 1.2, 0.0, 1.0))
			row.append(Vector3(cos(a) * r, yy, sin(a) * r))
			var c := dark.lerp(mid, smoothstep(-0.7, 0.1, ridge)).lerp(light, smoothstep(0.5, 1.0, ridge) * 0.8)
			c = c.lerp(dark, crack * 0.8)
			# ближе к полу — мох, вверху темнее
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
				continue  # дыра окна
			var A: Vector3 = grid[j][i]
			var B: Vector3 = grid[j][i + 1]
			var C: Vector3 = grid[j + 1][i + 1]
			var D: Vector3 = grid[j + 1][i]
			var inward := -Vector3(cos(a0), 0, sin(a0))
			_tri(st, A, D, C, inward, cols[j][i], cols[j + 1][i], cols[j + 1][i + 1])
			_tri(st, A, C, B, inward, cols[j][i], cols[j + 1][i + 1], cols[j][i + 1])
	st.index()
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.metallic_specular = 0.15
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	# грибы-трутовики на стенах — маленькие «полочки» для уюта
	for k in 5:
		var a: float = [WIN_ANG + 2.2, WIN_ANG + 2.9, WIN_ANG + 3.8, WIN_ANG + 4.6, WIN_ANG + 5.6][k]
		var hy: float = [1.1, 2.5, 0.8, 2.2, 1.3][k]
		var f := node(self, dir(a) * (wall_r(hy) - 0.02) + Vector3(0, hy, 0), face_center(a))
		for q in 2:
			var off := Vector3((q - 0.5) * 0.22, -q * 0.16, 0)
			var sz := 1.0 - q * 0.3
			put(f, sphere(0.2 * sz, 16), mat(Color("#C98A5C"), 0.9), off + Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.3, 0.5, 0.9))
			put(f, sphere(0.19 * sz, 16), mat(Color("#F2D7A8"), 0.9, 0.0, false), off + Vector3(0, 0.035, 0), Vector3.ZERO, Vector3(1.3, 0.36, 0.88))
	# сучки-дупляшки в коре
	for k in 3:
		var a: float = [WIN_ANG + 1.5, WIN_ANG + 3.4, WIN_ANG + 5.0][k]
		var hy: float = [2.9, 1.8, 3.1][k]
		var f := node(self, dir(a) * (wall_r(hy) - 0.03) + Vector3(0, hy, 0), face_center(a))
		var t := put(f, torus(0.07, 0.15, 18), mat(Color("#8A5A44"), 0.9), Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 1.4))
		put(f, sphere(0.08, 12), mat(Color("#2A1620"), 1.0, 0.0, false), Vector3(0, 0, -0.02), Vector3.ZERO, Vector3(1.0, 1.4, 0.4))


# ---------- Пол-гнездо ----------

func _floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var segs := 72
	var pts := []
	var cols := []
	for j in rings + 1:
		var rr := (R + 0.15) * j / rings
		var row := []
		var crow := []
		for i in segs + 1:
			var a := TAU * i / segs
			var h := 0.0
			if j > 0:
				h = 0.03 * sin(a * 7.0 + j * 1.3) * sin(j * 0.9) + 0.18 * pow(float(j) / rings, 4.0)
			row.append(Vector3(cos(a) * rr, h, sin(a) * rr))
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
			_tri(st, A, B, C, Vector3.UP, cols[j][i], cols[j][i + 1], cols[j + 1][i + 1])
			if j > 0:
				_tri(st, A, C, D, Vector3.UP, cols[j][i], cols[j + 1][i + 1], cols[j + 1][i])
	st.index()
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic_specular = 0.1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	# опавшие листики по полу (одна сетка на все — MultiMesh, дёшево)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere(0.05, 8)
	mm.instance_count = 55
	var leaf_cols := [Color("#C98A3E"), Color("#B5603A"), Color("#D6AE55"), Color("#7FA552"), Color("#A85A5E")]
	for i in mm.instance_count:
		var a := _hash(i, 1) * TAU
		var rr := 1.05 + _hash(i, 2) * 1.55
		var b := Basis(Vector3.UP, _hash(i, 3) * TAU) * Basis(Vector3.RIGHT, 0.15 * (_hash(i, 4) - 0.5)) * Basis.from_scale(Vector3(0.6, 0.12, 1.0) * (0.8 + 0.5 * _hash(i, 6)))
		mm.set_instance_transform(i, Transform3D(b, dir(a) * rr + Vector3(0, 0.025 + 0.18 * pow(rr / R, 4.0), 0)))
		mm.set_instance_color(i, leaf_cols[i % leaf_cols.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.roughness = 0.9
	mmi.material_override = sm
	add_child(mmi)
	# мягкие кочки мха у стен
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		if absf(angle_difference(a, SPOTS3D.floor_l[0])) < 0.35 or absf(angle_difference(a, SPOTS3D.floor_r[0])) < 0.35:
			continue
		var p := dir(a) * (R - 0.35) + Vector3(0, 0.12, 0)
		put(self, sphere(0.32, 14), mat(Color("#5E9A4A"), 1.0, 0.0, false), p, Vector3.ZERO, Vector3(1.0, 0.45, 0.8))
		put(self, sphere(0.2, 12), mat(Color("#77B65A"), 1.0, 0.0, false), p + Vector3(0.15, 0.08, 0.1), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))


# ---------- Окно-дупло с ночным небом ----------

func _window() -> void:
	var out := dir(WIN_ANG)
	var yaw := face_center(WIN_ANG)
	var wr := wall_r(WIN_Y)
	# рама — толстый «валик» коры по краю дыры
	var rim := put(self, torus(0.86, 1.12, 40), mat(Color("#7B5141"), 0.9), out * (wr * 0.975) + Vector3(0, WIN_Y, 0))
	rim.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(WIN_HALF_ANG * wr / 1.0 + 0.04, 1.0, WIN_HALF_H + 0.04))
	# подоконник
	put(self, sphere(0.5, 16), mat(Color("#8E5E46"), 0.9), out * (wr - 0.12) + Vector3(0, WIN_Y - WIN_HALF_H + 0.02, 0), Vector3(0, yaw, 0), Vector3(1.55, 0.2, 0.7))
	# небо за окном — плоскость со звёздами (свой простой шейдер)
	var sky := ShaderMaterial.new()
	sky.shader = Shader.new()
	sky.shader.code = SKY_SHADER
	var q := QuadMesh.new()
	q.size = Vector2(6.0, 4.6)
	var sk := put(self, q, sky, out * (R + 2.4) + Vector3(0, WIN_Y + 0.6, 0))
	sk.rotation.y = yaw
	# луна и её сияние
	var moon_p := out * (R + 2.0) + Vector3(0, WIN_Y + 0.42, 0) + dir(WIN_ANG + PI / 2.0) * 0.45
	put(self, sphere(0.36, 24), mat(Color("#FFF3C9"), 1.0, 1.6, false), moon_p)
	for cr in [[Vector3(-0.12, 0.1, 0.0), 0.08], [Vector3(0.1, -0.1, 0.0), 0.06]]:
		var cp: Vector3 = moon_p - out * 0.3 + Basis(Vector3.UP, yaw) * cr[0]
		put(self, sphere(cr[1], 10), mat(Color("#EFDDA0"), 1.0, 1.2, false), cp, Vector3.ZERO, Vector3(1, 1, 0.4))
	_halo(moon_p - out * 0.05, 2.2, Color(1.0, 0.92, 0.65, 0.35))
	# листва снаружи по краю окна
	for i in 7:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := out * (R + 0.5 + _hash(i, 2) * 0.6) + Vector3(0, WIN_Y + 0.9 - _hash(i, 1) * 0.6, 0) + dir(WIN_ANG + PI / 2.0) * side * (0.7 + _hash(i, 3) * 0.6)
		put(self, sphere(0.35 + _hash(i, 4) * 0.25, 12), mat(Color("#1F4C40").lerp(Color("#27604C"), _hash(i, 5)), 1.0, 0.0, false), p, Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	# ветка плюща свисает над окном
	for i in 9:
		var s := i / 8.0
		var p := out * (wr - 0.18) + Vector3(0, WIN_Y + WIN_HALF_H + 0.1 - sin(s * PI) * 0.25, 0) + dir(WIN_ANG + PI / 2.0) * lerpf(-0.95, 0.95, s)
		put(self, sphere(0.085, 8), mat(Color("#3FAF6E")), p, Vector3(0.3 * i, yaw, 0.5), Vector3(1.0, 0.45, 0.7))
	# лунный луч из окна на пол
	var moon_light := SpotLight3D.new()
	moon_light.light_color = Color("#9DB4FF")
	moon_light.light_energy = 2.2
	moon_light.spot_range = 7.0
	moon_light.spot_angle = 24.0
	moon_light.spot_attenuation = 0.6
	moon_light.position = out * (R + 0.8) + Vector3(0, WIN_Y + 1.1, 0)
	add_child(moon_light)
	moon_light.look_at(Vector3(0.3, 0.0, 0.4) - out * 0.3, Vector3.UP)
	focusables.append([rim, out * (wr - 0.1) + Vector3(0, WIN_Y, 0), 1.7, "окно"])


const SKY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 c = mix(vec3(0.043, 0.031, 0.15), vec3(0.19, 0.13, 0.38), uv.y);
	vec2 g = uv * vec2(26.0, 20.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h > 0.72) {
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float d = length(f - o * 0.6);
		float tw = 0.55 + 0.45 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
		float sz = 0.05 + 0.08 * hash(id + 1.7);
		c += vec3(1.0, 0.96, 0.82) * smoothstep(sz, 0.0, d) * tw * 1.6;
	}
	float hill = 0.80 + 0.04 * sin(uv.x * 9.0) + 0.02 * sin(uv.x * 23.0 + 1.0);
	if (uv.y > hill) c = vec3(0.10, 0.075, 0.24);
	ALBEDO = c;
}
"""


## Мягкое сияние вокруг светящейся вещи — плоский круг, всегда повёрнутый к камере
func _halo(p: Vector3, size: float, col: Color) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(col, col.a))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.35, Color(col, col.a * 0.4))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.disable_fog = true
	m.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := put(self, q, m, p)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------- Гнездо в центре ----------

func _nest() -> void:
	# круглый вязаный коврик под гнездом — цветное пятно на полу
	var rug_cols := [Color("#8A5A48"), Color("#A9735A"), Color("#C28C66")]
	for k in rug_cols.size():
		var rr := 1.3 - k * 0.12
		var rm := mat(rug_cols[k], 1.0, 0.0, k == 0)
		rm.metallic_specular = 0.05
		put(self, cyl(rr, rr + 0.02, 0.05, 56), rm, Vector3(0, 0.035 + k * 0.004, 0))
	# кисточки по краю коврика
	var tassels := []
	for k in 24:
		var a := TAU * k / 24.0
		tassels.append(Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(1.0, 0.6, 1.0)), dir(a) * 1.35 + Vector3(0, 0.035, 0)))
	scatter(self, sphere(0.04, 8), mat(Color("#E0B07A"), 1.0, 0.0, false), tassels)
	var n := node(self)
	casters.append(n)
	put(n, torus(0.38, 0.8, 36), mat(Color("#9A6E42"), 1.0), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	put(n, cyl(0.5, 0.45, 0.16, 24), mat(Color("#7A5233"), 1.0, 0.0, false), Vector3(0, 0.1, 0))
	# мягкая подушка-пух внутри
	put(n, sphere(0.44, 20), mat(Color("#F4E6D2"), 1.0), Vector3(0, 0.26, 0), Vector3.ZERO, Vector3(1.0, 0.32, 1.0))
	for k in 3:
		put(n, sphere(0.06, 10), mat(Color("#FFF6EA"), 1.0, 0.0, false), Vector3(cos(k * 2.1) * 0.32, 0.38, sin(k * 2.1) * 0.3), Vector3(0.2, k * 1.3, 0.3), Vector3(0.45, 0.22, 1.3))
	# прутики, «обмотанные» вокруг гнезда
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cyl(0.016, 0.016, 0.42, 5)
	mm.instance_count = 110
	for i in mm.instance_count:
		var a := _hash(i, 7) * TAU
		var phi := lerpf(-0.6, 2.4, _hash(i, 8))
		var p := dir(a) * (0.59 + cos(phi) * 0.215) + Vector3(0, 0.2 + sin(phi) * 0.17, 0)
		var tangent := Vector3(-sin(a), 0, cos(a))
		var tilt := (_hash(i, 10) - 0.5) * 0.7
		var fwd := (tangent + Vector3(0, tilt, 0)).normalized()
		var b := Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, Color("#E0B474").lerp(Color("#7A5141"), _hash(i, 12)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.roughness = 1.0
	mmi.material_override = sm
	n.add_child(mmi)
	# пёрышко
	put(n, sphere(0.09, 10), mat(Color("#F7F0FF")), Vector3(0.5, 0.42, 0.42), Vector3(0.3, 0.6, 0.9), Vector3(0.5, 0.25, 1.4))


# ---------- Детали комнаты ----------

func _room_details() -> void:
	# корни, выходящие из стен по полу
	for i in 5:
		var a := 0.6 + i * 1.25
		var base := dir(a) * (R - 0.15)
		var pts := [base + Vector3(0, 0.25, 0), dir(a + 0.1) * (R - 0.7) + Vector3(0, 0.1, 0), dir(a + 0.18) * (R - 1.15) + Vector3(0, 0.03, 0)]
		var smooth := []
		for k in 9:
			var u := k / 8.0
			var q: Vector3 = (pts[0] as Vector3).lerp(pts[1], u).lerp((pts[1] as Vector3).lerp(pts[2], u), u)
			smooth.append(q)
		put(self, tube(smooth, 0.12, 0.035, 9), mat(Color("#6B4433"), 0.95))
	# маленькие светящиеся грибочки-«вкрапления» на стенах (низкий уровень света — уют)
	for i in 6:
		var a := WIN_ANG + 1.2 + i * 0.75
		var p := dir(a) * (wall_r(0.4) - 0.08) + Vector3(0, 0.35 + _hash(i, 21) * 0.5, 0)
		put(self, sphere(0.05, 8), mat(Color("#7FF5E0"), 0.8, 1.4, false), p)


	# корешки свисают с потолка, на концах — светящиеся кристаллики (как на ветках в 2D-доме)
	var gem_cols := [Color("#B46CFF"), Color("#3FD0FF"), Color("#3DDC97"), Color("#FF8FD8"), Color("#FFD34D")]
	for i in 5:
		var a := WIN_ANG + 0.9 + i * 1.15
		var rr := 1.7 + _hash(i, 41) * 0.5
		var top := dir(a) * rr + Vector3(0, TOP_H * 0.92 * sqrt(maxf(0.0, 1.0 - pow(rr / (R * 0.95), 2.0))) + WALL_H * 0.0, 0)
		top.y = maxf(top.y, 3.6)
		var ln := 0.55 + _hash(i, 42) * 0.5
		var prev := top
		var chain := [top]
		for k in 4:
			prev = prev + Vector3(sin(i + k * 1.7) * 0.05, -ln / 4.0, cos(i * 2.0 + k) * 0.05)
			chain.append(prev)
		put(self, tube(chain, 0.03, 0.015, 5), mat(Color("#7A5141"), 0.95, 0.0, false))
		var c: Color = gem_cols[i]
		var g := _crystal(self, prev + Vector3(0, -0.02, 0), 0.2, 0.05, Vector3(PI, 0, 0), c, 1.0)
		anims.append([g, "pulse", float(i)])
		_halo(prev + Vector3(0, -0.1, 0), 0.5, Color(c, 0.35))


# ---------- Украшения (места как в 2D-доме) ----------

func _spot_xf(spot: String) -> Array:
	var s: Array = SPOTS3D[spot]
	var a: float = s[0]
	var r: float = s[1]
	if spot.begins_with("wall"):
		r = wall_r(s[2]) - 0.05  # вплотную к коре
	return [dir(a) * r + Vector3(0, s[2], 0), face_center(a), a]


func _place(spot: String, id: String) -> void:
	if id == "":
		return
	var xf := _spot_xf(spot)
	var n := node(self, xf[0], xf[1])
	n.name = id
	var focus_d := 1.25
	var center := Vector3(0, 0.3, 0)
	match id:
		"owl_lantern":
			_lantern(n)
			center = Vector3(0, 0.35, 0)
		"owl_birdhouse":
			_birdhouse(n)
			center = Vector3(0, 0, 0.25)
		"owl_books":
			_books(n)
			center = Vector3(0, 0.15, 0.25)
		"owl_nightlight":
			_nightlight(n)
			center = Vector3(0, 0.3, 0)
		"owl_mushrooms":
			_mushrooms(n)
			center = Vector3(0, 0.25, 0)
		"owl_moon":
			_moon_mobile(n)
			center = Vector3(0, -0.75, 0)
			focus_d = 1.5
	var at: Vector3 = n.to_global(center)
	focusables.append([n, at, focus_d, id])
	if id != "owl_lantern":
		casters.append(n)


func _lantern(n: Node3D) -> void:
	var frame := mat(Color("#3A2A55"), 0.6)
	put(n, cyl(0.17, 0.2, 0.07, 16), frame, Vector3(0, 0.035, 0))
	var glass_m := glass(Color(1.0, 0.86, 0.45, 0.55), 1.2)
	put(n, cyl(0.15, 0.15, 0.34, 16), glass_m, Vector3(0, 0.24, 0))
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		put(n, cyl(0.016, 0.016, 0.36, 6), frame, Vector3(cos(a) * 0.155, 0.24, sin(a) * 0.155))
	put(n, cyl(0.02, 0.21, 0.13, 16), frame, Vector3(0, 0.47, 0))
	var ring := put(n, torus(0.06, 0.09, 16), frame, Vector3(0, 0.58, 0), Vector3(PI / 2.0, 0, 0))
	ring.scale = Vector3.ONE
	# огонёк
	var flame := put(n, sphere(0.06, 12), mat(Color("#FFE27A"), 0.5, 4.0, false), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
	anims.append([flame, "flame", 0.0])
	var l := OmniLight3D.new()
	l.light_color = Color("#FFB866")
	l.light_energy = 1.35
	l.omni_range = 3.8
	l.omni_attenuation = 1.2
	l.shadow_enabled = true
	l.shadow_blur = 2.0
	l.position = Vector3(0, 0.26, 0)
	n.add_child(l)
	lights.append([l, 1.35, "flicker"])
	var h := _halo(n.to_global(Vector3(0, 0.25, 0)), 0.9, Color(1.0, 0.8, 0.4, 0.4))
	h.reparent(n)


func _birdhouse(n: Node3D) -> void:
	# колышек из стены
	put(n, cyl(0.04, 0.05, 0.3, 8), mat(Color("#6B4433")), Vector3(0, -0.36, 0.1), Vector3(PI / 2.0, 0, 0))
	var body := node(n, Vector3(0, 0, 0.25))
	put(body, box(Vector3(0.42, 0.46, 0.38)), mat(Color("#E7B26A"), 0.8), Vector3(0, 0, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(0.6, 0.3, 0.46)
	put(body, roof, mat(Color("#E0556F"), 0.7), Vector3(0, 0.38, 0))
	put(body, cyl(0.075, 0.075, 0.04, 16), mat(Color("#2A1A3A"), 1.0, 0.0, false), Vector3(0, 0.04, 0.19), Vector3(PI / 2.0, 0, 0))
	put(body, cyl(0.015, 0.015, 0.16, 6), mat(Color("#8A5A3A")), Vector3(0, -0.1, 0.24), Vector3(PI / 2.0, 0, 0))
	# сердечко-окошко и сидящий жучок-светлячок
	put(body, sphere(0.035, 8), mat(Color("#FFE27A"), 0.5, 3.0, false), Vector3(0.12, 0.5, 0.05))


func _books(n: Node3D) -> void:
	# полка — гриб-трутовик, растущий из стены
	var shelf := put(n, sphere(0.42, 20), mat(Color("#E9C79A")), Vector3(0, 0, 0.18), Vector3.ZERO, Vector3(1.4, 0.18, 0.8))
	put(n, sphere(0.4, 20), mat(Color("#C98A5C"), 0.9, 0.0, false), Vector3(0, -0.025, 0.17), Vector3.ZERO, Vector3(1.42, 0.12, 0.82))
	shelf.name = "shelf"
	var cols := [Color("#E0556F"), Color("#5FC8FF"), Color("#FFD34D"), Color("#3DDC97")]
	var x := -0.36
	for i in 4:
		var h: float = [0.3, 0.26, 0.32, 0.22][i]
		var w: float = [0.08, 0.07, 0.09, 0.075][i]
		var tilt := 0.0 if i < 3 else -0.35
		put(n, box(Vector3(w, h, 0.2)), mat(cols[i], 0.7), Vector3(x + w * 0.5, 0.07 + h * 0.5, 0.2), Vector3(0, 0, tilt))
		x += w + 0.01
	# свеча
	put(n, cyl(0.04, 0.045, 0.14, 12), mat(Color("#FFF3E0")), Vector3(0.22, 0.14, 0.22))
	var fl := put(n, sphere(0.03, 10), mat(Color("#FFD34D"), 0.5, 5.0, false), Vector3(0.22, 0.25, 0.22), Vector3.ZERO, Vector3(1, 1.6, 1))
	anims.append([fl, "flame", 1.3])
	var h2 := _halo(n.to_global(Vector3(0.22, 0.26, 0.22)), 0.45, Color(1.0, 0.75, 0.35, 0.45))
	h2.reparent(n)


func _crystal(parent: Node3D, pos: Vector3, h: float, r: float, tilt: Vector3, col: Color, emit: float) -> Node3D:
	var c := node(parent, pos)
	c.rotation = tilt
	var m := mat(col, 0.25, emit)
	put(c, cyl(r, r * 0.9, h * 0.72, 6), m, Vector3(0, h * 0.36, 0))
	put(c, cyl(0.0, r, h * 0.28, 6), m, Vector3(0, h * 0.72 + h * 0.14, 0))
	return c


func _nightlight(n: Node3D) -> void:
	put(n, cyl(0.26, 0.3, 0.1, 20), mat(Color("#4A3B6B"), 0.7), Vector3(0, 0.05, 0))
	var g := node(n)
	_crystal(g, Vector3(0, 0.08, 0), 0.62, 0.09, Vector3.ZERO, Color("#8FEFFF"), 0.9)
	_crystal(g, Vector3(-0.12, 0.08, 0.02), 0.4, 0.07, Vector3(0, 0, 0.35), Color("#6FD8FF"), 0.8)
	_crystal(g, Vector3(0.12, 0.08, -0.02), 0.46, 0.075, Vector3(0.1, 0, -0.3), Color("#B48CFF"), 0.8)
	anims.append([g, "pulse", 0.0])
	var l := OmniLight3D.new()
	l.light_color = Color("#7FE3FF")
	l.light_energy = 1.1
	l.omni_range = 2.8
	l.position = Vector3(0, 0.45, 0.1)
	n.add_child(l)
	lights.append([l, 1.1, "pulse"])
	var h := _halo(n.to_global(Vector3(0, 0.4, 0)), 1.2, Color(0.5, 0.9, 1.0, 0.3))
	h.reparent(n)


func _mushroom(parent: Node3D, pos: Vector3, k: float, col: Color) -> void:
	put(parent, cyl(0.045 * k, 0.06 * k, 0.26 * k, 10), mat(Color("#F2E8FF")), pos + Vector3(0, 0.13 * k, 0))
	var cap := SphereMesh.new()
	cap.radius = 0.16 * k
	cap.height = 0.16 * k
	cap.is_hemisphere = true
	cap.radial_segments = 18
	cap.rings = 6
	put(parent, cap, mat(col, 0.5, 0.7), pos + Vector3(0, 0.25 * k, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
	for i in 4:
		var a := i * 1.7
		put(parent, sphere(0.022 * k, 6), mat(Color.WHITE, 0.8, 0.6, false), pos + Vector3(cos(a) * 0.09 * k, 0.32 * k, sin(a) * 0.09 * k))


func _mushrooms(n: Node3D) -> void:
	_mushroom(n, Vector3(-0.18, 0, 0.02), 0.85, Color("#7FF5E0"))
	_mushroom(n, Vector3(0.14, 0, -0.06), 1.2, Color("#C38BFF"))
	_mushroom(n, Vector3(0.02, 0, 0.18), 0.65, Color("#FFB547"))
	var l := OmniLight3D.new()
	l.light_color = Color("#B88BFF")
	l.light_energy = 0.8
	l.omni_range = 2.2
	l.position = Vector3(0, 0.45, 0.2)
	n.add_child(l)
	lights.append([l, 0.8, "pulse"])
	var h := _halo(n.to_global(Vector3(0, 0.3, 0)), 1.0, Color(0.75, 0.55, 1.0, 0.28))
	h.reparent(n)


## Звезда/полумесяц «из картона» для мобиля
func _star_poly(r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI / 2.0 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _crescent_poly(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(-PI * 0.78, PI * 0.78, i / 16.0)
		pts.append(Vector2(-cos(a), sin(a)) * r)
	for i in range(16, -1, -1):
		var a := lerpf(-PI * 0.78, PI * 0.78, i / 16.0)
		pts.append(Vector2(-cos(a) * r * 0.5 - r * 0.25, sin(a) * r * 0.75))
	return pts


func _moon_mobile(n: Node3D) -> void:
	var rope := mat(Color("#C9B88A"), 1.0, 0.0, false)
	put(n, cyl(0.008, 0.008, 1.0, 4), rope, Vector3(0, 0.5, 0))
	var sw := node(n)
	anims.append([sw, "sway", 0.0])
	put(sw, cyl(0.025, 0.025, 1.0, 8), mat(Color("#9A6A44")), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	put(sw, cyl(0.006, 0.006, 0.36, 4), rope, Vector3(0, -0.18, 0))
	var moon := put(sw, extrude(_crescent_poly(0.26), 0.08), mat(Color("#FFE58A"), 0.6, 0.6), Vector3(0, -0.6, 0))
	anims.append([moon, "spin", 0.0])
	for s in [[-0.45, 0.42, 0.13], [0.45, 0.3, 0.1]]:
		put(sw, cyl(0.006, 0.006, s[1], 4), rope, Vector3(s[0], -s[1] * 0.5, 0))
		var st := put(sw, extrude(_star_poly(s[2], s[2] * 0.45), 0.06), mat(Color("#FFD34D"), 0.6, 0.7), Vector3(s[0], -s[1] - s[2], 0))
		anims.append([st, "spin", s[0] * 3.0])


# ---------- Гирлянда вдоль стены ----------

func _garland(a0: float, a1: float, y: float) -> void:
	var g := node(self)
	g.name = "garland"
	var n := 60
	var pts := []
	for i in n + 1:
		var s := float(i) / n
		var a := lerpf(a0, a1, s)
		# три провиса между гвоздиками
		var sag := absf(sin(s * PI * 3.0)) * 0.28
		pts.append(dir(a) * (wall_r(y) - 0.12) + Vector3(0, y - sag, 0))
	var rope := mat(Color("#3E9E62"), 0.9, 0.0, false)
	put(g, tube(pts, 0.014, 0.014, 5), rope)
	var cols := [Color("#FF4D6D"), Color("#FFD34D"), Color("#B46CFF"), Color("#7FE3FF"), Color("#FF8FD8")]
	var k := 0
	var caps := []
	for i in range(2, n, 4):
		var p: Vector3 = pts[i] + Vector3(0, -0.07, 0)
		var c: Color = cols[k % cols.size()]
		var b := put(g, sphere(0.05, 10), mat(c, 0.4, 2.2).duplicate(), p, Vector3.ZERO, Vector3(1, 1.25, 1))
		anims.append([b, "bulb", float(k)])
		caps.append(Transform3D(Basis(), p + Vector3(0, 0.065, 0)))
		k += 1
	scatter(g, cyl(0.025, 0.025, 0.03, 8), mat(Color("#3A2A55"), 0.6, 0.0, false), caps)
	var leaves := []
	for i in range(0, n, 3):
		var p: Vector3 = pts[i]
		leaves.append(Transform3D(Basis.from_euler(Vector3(0.3 * i, 0.7 * i, 0.2)) * Basis.from_scale(Vector3(1.0, 0.4, 0.6)), p + Vector3(0, 0.02, 0)))
	scatter(g, sphere(0.045, 8), mat(Color("#5BC27E"), 0.9, 0.0, false), leaves)
	# гвоздики-узелки
	for s in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		put(g, sphere(0.05, 8), mat(Color("#9A6A44")), dir(lerpf(a0, a1, s)) * (wall_r(y) - 0.1) + Vector3(0, y, 0))
	focusables.append([g, dir(lerpf(a0, a1, 0.5)) * (wall_r(y) - 0.3) + Vector3(0, y - 0.25, 0), 1.6, "гирлянда"])


# ---------- Светлячки ----------

func _fireflies() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere(0.018, 6)
	mm.instance_count = 16
	flies = MultiMeshInstance3D.new()
	flies.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.4)
	m.emission_energy_multiplier = 4.0
	flies.material_override = m
	flies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flies)


func _update_flies() -> void:
	var mm := flies.multimesh
	for i in mm.instance_count:
		var a := _hash(i, 31) * TAU + _t * (0.08 + 0.1 * _hash(i, 32)) * (1.0 if i % 2 == 0 else -1.0)
		var rr := 0.7 + _hash(i, 33) * 1.2
		var y := 1.9 + _hash(i, 34) * 1.7 + sin(_t * (0.6 + _hash(i, 35)) + i) * 0.2
		var s := 0.5 + 0.5 * sin(_t * 3.0 + i * 1.9)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (0.4 + s)), dir(a) * rr + Vector3(0, y, 0)))


# ---------- Герой-«картонка» ----------

func _hero() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(512, 512)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	card = HeroCard.new()
	card.kind = "owl"
	card.outfit = outfit
	sv.add_child(card)
	hero_sprite = Sprite3D.new()
	hero_sprite.texture = sv.get_texture()
	hero_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hero_sprite.pixel_size = HPS
	hero_sprite.shaded = false
	hero_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	hero_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	hero_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ноги героя (y=470 из 512) — на подушке гнезда
	hero_sprite.position = Vector3(0, 0.38 + (470 - 256) * HPS, 0)
	hero_sprite.offset = Vector2.ZERO
	hero_sprite.modulate = Color(1.0, 0.96, 0.92)
	add_child(hero_sprite)
	# мягкая тень под героем
	var g := Gradient.new()
	g.set_color(0, Color(0.08, 0.04, 0.12, 0.6))
	g.set_color(1, Color(0.08, 0.04, 0.12, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.8, 0.6)
	var sh := put(self, pm, m, Vector3(0, 0.405, 0))
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	focusables.append([hero_sprite, Vector3(0, 0.75, 0), 1.45, "герой"])


# ---------- Камера и подсказки ----------

func _camera() -> void:
	cam = Camera3D.new()
	cam.set_script(load("res://proto3d/orbit_camera.gd"))
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 30.0
	cam.wall_radius = R - 0.3
	cam.ceiling = TOP_H - 0.9
	add_child(cam)
	cam.current = true
	cam.tapped.connect(_on_tap)
	cam.double_tapped.connect(_on_double_tap)


func _ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	var title := Label.new()
	title.text = "Дупло совёнка · 3D-проба"
	title.add_theme_font_override("font", fv)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#FFE9B0"))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(720, 50)
	cl.add_child(title)
	info = Label.new()
	info.text = "Веди пальцем — поворот\nДва пальца — ближе / дальше\nДвойной тап по вещи — подлететь к ней"
	info.add_theme_font_override("font", fv)
	info.add_theme_font_size_override("font_size", 26)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	info.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.9))
	info.add_theme_constant_override("outline_size", 9)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 1120)
	info.size = Vector2(720, 130)
	cl.add_child(info)


func _pick(pos: Vector2) -> Array:
	var best := []
	var best_d := 120.0
	for f in focusables:
		var p: Vector3 = f[1]
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(pos)
		if d < best_d:
			best_d = d
			best = f
	return best


func _on_tap(pos: Vector2) -> void:
	var f := _pick(pos)
	if not f.is_empty() and f[3] == "герой":
		card.poke()


func _on_double_tap(pos: Vector2) -> void:
	var f := _pick(pos)
	if f.is_empty() or (cam.focused and cam.goal_pivot.distance_to(f[1]) < 0.05):
		cam.fly_home()
		return
	cam.fly_to(f[1], _view_dir(f), f[2])


## С какой стороны смотреть на предмет: на стенные — из центра комнаты,
## на те, что у центра (рядом с героем), — снаружи, со стороны текущей камеры
func _view_dir(f: Array) -> Vector3:
	var at: Vector3 = f[1]
	if f[3] == "герой":
		return cam.global_position - at
	if Vector2(at.x, at.z).length() < 1.4:
		var out := Vector3(at.x, 0, at.z).normalized()
		var side := cam.global_position - at
		side.y = 0
		return (out + side.normalized()).normalized()
	return -at


## Для съёмки и тестов: развернуться к предмету по имени/id без касаний
func focus_named(nm: String) -> void:
	for f in focusables:
		if f[3] == nm:
			cam.fly_to(f[1], _view_dir(f), f[2])


# ---------- Анимация ----------

func _process(delta: float) -> void:
	_t += delta
	for a in anims:
		var nd: Node3D = a[0]
		var ph: float = a[2]
		match a[1]:
			"flame":
				var s := 1.0 + 0.12 * sin(_t * 13.0 + ph) + 0.06 * sin(_t * 31.0 + ph)
				nd.scale = Vector3(s, 1.5 * s, s)
			"pulse":
				nd.scale = Vector3.ONE * (1.0 + 0.03 * sin(_t * 2.0 + ph))
			"sway":
				nd.rotation = Vector3(0.05 * sin(_t * 0.8), _t * 0.25, 0.06 * sin(_t * 1.1))
			"spin":
				nd.rotation.y = 0.5 * sin(_t * 0.9 + ph)
			"bulb":
				var m: StandardMaterial3D = (nd as MeshInstance3D).material_override
				m.emission_energy_multiplier = 1.6 + 1.0 * sin(_t * 2.2 + ph * 1.3)
	for l in lights:
		var light: Light3D = l[0]
		var base: float = l[1]
		if l[2] == "flicker":
			light.light_energy = base * (1.0 + 0.06 * sin(_t * 11.0) + 0.04 * sin(_t * 23.0))
		else:
			light.light_energy = base * (1.0 + 0.15 * sin(_t * 2.0))
	_update_flies()
