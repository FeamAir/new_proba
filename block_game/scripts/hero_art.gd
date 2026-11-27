extends RefCounted
## Cascado 0.18: нарисованные герои и гардероб (перерисовка, этапы 1–2) вместо рисунка кодом.
##
## Картинки: assets/heroes_art/<герой>/<облик>_<окрас>_<поза>.webp (высота 512),
## вещи — assets/wardrobe_art/<герой>/<слой>.webp, значки карточек — assets/wardrobe_art/<герой>/icons/.
## Точки привязки героя — assets/heroes_art/anchors.json, посадка вещей — assets/wardrobe_art/fit.json
## (копии из art_src/; описание — art_src/wardrobe/compose.py, эталонная сборка на Python).
##
## ПЕРЕКЛЮЧАТЕЛЬ — enabled (одно место): false — везде рисунок кодом (scripts/hero.gd), как до 0.18.
## Если картинки нет (вещь без слоя, неизвестный окрас), scripts/hero.gd сам рисует кодом.
##
## Как собирается наряд (повторяет compose.py ТОЧНО):
##   U = (neck.y - head.y) * высота картинки героя — «высота головы», единица размеров вещей;
##   слой: точка героя anchor + offset·U (+ поправки pose_fix героя, затем poses слоя),
##   ширина width·U, поворот rot по часовой вокруг pivot, flip — отражение;
##   порядок: z="behind" (по order) -> герой -> z="front" (по order); gender — слой только для облика.
## В игре слои не сливаются в одну картинку: «план» сборки (текстуры + матрицы) считается ОДИН раз
## на ключ (герой, облик, окрас, поза, набор вещей) и кэшируется, а кадр — это 2–10 текстурных
## прямоугольников (дёшево на телефоне). compose_image() — та же сборка в Image (для тестов, сравнение с compose.py).
##
## Система координат «героя кодом»: ноги на y = FEET_Y, макушка — на TOP[kind] (как в hero.gd),
## поэтому прежние места, масштабы, сияния-частицы и эффекты кода садятся на нарисованного героя.

const Meta := preload("res://scripts/meta.gd")

## Переключатель: нарисованные герои (true) или рисунок кодом (false)
static var enabled := true

const HEROES_DIR := "res://assets/heroes_art/"
const WARD_DIR := "res://assets/wardrobe_art/"
const ANCHORS_PATH := "res://assets/heroes_art/anchors.json"
const FIT_PATH := "res://assets/wardrobe_art/fit.json"
const POSES := ["idle", "happy", "wow", "worried", "sad"]
const MASTER_POSES := ["talk", "happy", "forge"]
const SLOTS := ["head", "eyes", "neck", "back", "companion", "aura"]

## Ноги и макушка героя кодом (hero.gd: ноги на ~115, макушка — _anchors_base top)
const FEET_Y := 115.0
const TOP := {"owl": -84.0, "axolotl": -92.0, "puppy": -106.0, "kitten": -106.0, "master": -96.0}
## Картинка, по которой подобран размер героя (высота «макушка–лапы» = как у героя кодом)
const REF := {"owl": "owl/boy_base_idle", "axolotl": "axolotl/boy_base_idle", "puppy": "puppy/boy_base_idle",
	"kitten": "kitten/boy_base_idle", "master": "master_uh/master_base_talk"}
## Поправка размера нарисованного героя (подобрано по снимкам экранов)
const ART_K := {"owl": 1.08, "axolotl": 1.0, "puppy": 1.0, "kitten": 1.0, "master": 1.0}
## Глаза от точки eyes (в U, по горизонтали) — для эффектов кода (сияющие глаза)
const EYE_DX := {"owl": 0.3, "axolotl": 0.4, "puppy": 0.27, "kitten": 0.25}
## Хвост котика (для звёздного хвоста): ломаная в долях картинки, от тела к кончику; нет позы — хвоста не видно
const KIT_TAIL := {
	"idle": [Vector2(0.70, 0.80), Vector2(0.77, 0.62), Vector2(0.81, 0.45), Vector2(0.81, 0.30), Vector2(0.76, 0.17)],
	"worried": [Vector2(0.70, 0.80), Vector2(0.77, 0.62), Vector2(0.81, 0.45), Vector2(0.81, 0.30), Vector2(0.76, 0.18)],
	"happy": [Vector2(0.60, 0.84), Vector2(0.69, 0.73), Vector2(0.77, 0.62), Vector2(0.85, 0.54), Vector2(0.92, 0.50)],
}
## Жабры аксолотля: начало каждой жабры (в U от точки head) — к жемчужинам ax_gill_pearls (fit.json)
const GILL_BASE := [Vector2(-0.45, 0.32), Vector2(-0.62, 0.45), Vector2(-0.6, 0.72)]

static var _anch := {}
static var _fit := {}
static var _loaded := false
static var _tex := {}      # путь -> Texture2D (или null, если файла нет)
static var _plans := {}    # ключ наряда -> план сборки
static var _hu := {}       # kind -> единиц кода на U
static var plans_built := 0  # сколько планов посчитано (для тестов кэша)


# ---------- Данные ----------

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_anch = _json(ANCHORS_PATH).get("images", {})
	_fit = _json(FIT_PATH)


static func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("HeroArt: нет файла " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func anchors(key: String) -> Dictionary:
	_load()
	return _anch.get(key, {})


static func fit_items() -> Dictionary:
	_load()
	return _fit.get("items", {})


static func fit_item(id: String) -> Dictionary:
	return fit_items().get(id, {})


## Текстура (загружается один раз; сглаживание мипмапами — настройкой проекта)
static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var base = load(path)
		if base is Texture2D:
			# Без CanvasTexture: его нет в облегчённом движке для Android.
			# Сглаживание мипмапами задаёт настройка проекта
			# rendering/textures/canvas_textures/default_texture_filter.
			t = base
	_tex[path] = t
	return t


static func clear_cache() -> void:
	_tex.clear()
	_plans.clear()


## Часть имени файла героя по окраске (id вещи окраса -> поле draw, иначе id; нет — base)
static func skin_file(skin_id: String) -> String:
	if skin_id == "" or skin_id.begins_with("_"):
		return "base" if skin_id == "" else skin_id
	return Meta.draw_key(skin_id)


static func gender_of(outfit: Dictionary) -> String:
	return "girl" if outfit.get("gender", "") == "girl" else "boy"


static func hero_key(kind: String, pose: String, gender := "boy", skin_id := "") -> String:
	if kind == "master":
		return "master_uh/master_base_" + pose
	return "%s/%s_%s_%s" % [kind, gender, skin_file(skin_id), pose]


static func hero_path(key: String) -> String:
	return HEROES_DIR + key + ".webp"


static func layer_path(kind: String, file: String) -> String:
	return WARD_DIR + kind + "/" + file + ".webp"


static func icon_path(kind: String, id: String, girl := false) -> String:
	if girl:
		var p := WARD_DIR + kind + "/icons/" + id + "_girl.webp"
		if ResourceLoader.exists(p):
			return p
	return WARD_DIR + kind + "/icons/" + id + ".webp"


## Есть ли нарисованный герой для этого вида (переключатель включён, картинка и точки есть)
static func available(kind: String, outfit: Dictionary, pose := "idle") -> bool:
	if not enabled:
		return false
	var key := hero_key(kind, pose, gender_of(outfit), outfit.get("skin", ""))
	return not anchors(key).is_empty() and tex(hero_path(key)) != null


## Вещи наряда в порядке слотов (без облика и окраса)
static func items_of(outfit: Dictionary) -> Array:
	var out: Array = []
	for s in SLOTS:
		var id: String = outfit.get(s, "")
		if id != "" and not id.begins_with("_"):
			out.append(id)
	return out


## Единиц «героя кодом» на одну U: высота «макушка–лапы» картинки REF = как у героя кодом
static func _units_per_u(kind: String) -> float:
	if _hu.has(kind):
		return _hu[kind]
	var a := anchors(REF.get(kind, REF.owl))
	var v := 100.0
	if not a.is_empty():
		var u: float = a.neck[1] - a.head[1]
		v = (FEET_Y - float(TOP.get(kind, -84.0))) / ((a.ground[1] - a.head[1]) / u) * float(ART_K.get(kind, 1.0))
	_hu[kind] = v
	return v


# ---------- Посадка (как compose.py) ----------

## Все слои надетых вещей с учётом облика, отсортированные: behind..., front... (по order, устойчиво)
static func layers_for(items: Array, gender := "boy") -> Array:
	var out: Array = []
	for iid in items:
		var it := fit_item(iid)
		if it.is_empty():
			continue
		for L in it.get("layers", []):
			if L.get("gender", "") != "" and L.gender != gender:
				continue
			var d: Dictionary = L.duplicate()
			d["item"] = iid
			d["_i"] = out.size()
			out.append(d)
	out.sort_custom(func(a, b):
		var za := 0 if a.get("z", "") == "behind" else 1
		var zb := 0 if b.get("z", "") == "behind" else 1
		if za != zb:
			return za < zb
		var oa := float(a.get("order", 0))
		var ob := float(b.get("order", 0))
		if oa != ob:
			return oa < ob
		return a._i < b._i)
	return out


## Где и каким размером рисовать слой: [точка pivot в px героя, ширина px, поворот (град.), U px]
static func place(L: Dictionary, anch: Dictionary, W: float, H: float, pose: String, kind: String) -> Array:
	var U: float = (anch.neck[1] - anch.head[1]) * H
	var ap: Array = anch[L.anchor]
	var off: Array = L.get("offset", [0, 0])
	var ox := float(off[0])
	var oy := float(off[1])
	var w := float(L.width)
	var rot := float(L.get("rot", 0.0))
	var pf: Dictionary = _fit.get("pose_fix", {}).get(kind, {}).get(pose, {}).get(L.anchor, {})
	var lp: Dictionary = L.get("poses", {}).get(pose, {})
	for p in [pf, lp]:
		ox += float(p.get("dx", 0.0))
		oy += float(p.get("dy", 0.0))
		w *= float(p.get("scale", 1.0))
		rot += float(p.get("rot", 0.0))
	return [Vector2(float(ap[0]) * W + ox * U, float(ap[1]) * H + oy * U), w * U, rot, U]


## Матрица слоя: пиксели картинки вещи (tw×th) -> пиксели картинки героя
static func layer_xform(L: Dictionary, tsize: Vector2, at: Vector2, width_px: float, rot: float) -> Transform2D:
	var k := width_px / tsize.x
	var pv: Array = L.get("pivot", [0.5, 0.5])
	var sx := -1.0 if L.get("flip", false) else 1.0
	return Transform2D(deg_to_rad(rot), Vector2(k * sx, k), 0.0, at) * Transform2D(0.0, Vector2.ONE, 0.0, -Vector2(float(pv[0]) * tsize.x, float(pv[1]) * tsize.y))


# ---------- План сборки (кэш) ----------

## План наряда: герой + слои с матрицами в координатах «героя кодом». {} — нарисованного героя нет.
## kind "master" — Мастер Ух (без вещей).
static func plan(kind: String, outfit: Dictionary, pose := "idle") -> Dictionary:
	if not enabled:
		return {}
	_load()
	var gender := gender_of(outfit)
	var skin: String = outfit.get("skin", "")
	var items := items_of(outfit) if kind != "master" else []
	var key := "%s|%s|%s|%s|%s" % [kind, gender, skin, pose, ",".join(items)]
	if _plans.has(key):
		return _plans[key]
	var p := _build_plan(kind, gender, skin, pose, items)
	if _plans.size() > 300:
		_plans.clear()
	_plans[key] = p
	return p


static func _build_plan(kind: String, gender: String, skin: String, pose: String, items: Array) -> Dictionary:
	var hk := hero_key(kind, pose, gender, skin)
	var an := anchors(hk)
	var ht := tex(hero_path(hk))
	if an.is_empty() or ht == null:
		return {}
	plans_built += 1
	var sz := ht.get_size()
	var W := sz.x
	var H := sz.y
	var U: float = (an.neck[1] - an.head[1]) * H
	var f: float = _units_per_u(kind) / U
	var ground := Vector2(an.ground[0] * W, an.ground[1] * H)
	# картинка героя (px) -> координаты «героя кодом»
	var X := Transform2D(0.0, Vector2(f, f), 0.0, Vector2(0, FEET_Y) - ground * f)
	var pts := {}
	for n in ["head", "eyes", "neck", "back", "ground"]:
		pts[n] = X * Vector2(an[n][0] * W, an[n][1] * H)
	var behind: Array = []
	var front: Array = []
	var placed := {}
	for L in layers_for(items, gender):
		var lt := tex(layer_path(kind, L.file))
		if lt == null:
			continue
		var pl := place(L, an, W, H, pose, kind)
		var M := X * layer_xform(L, lt.get_size(), pl[0], pl[1], pl[2])
		var slot: String = Meta.item(L.item).get("slot", "")
		var e := [lt, M, Color(1, 1, 1, float(L.get("alpha", 1.0))), slot, X * (pl[0] as Vector2)]
		(behind if L.get("z", "") == "behind" else front).append(e)
		placed[L.item] = true
	var missing: Array = items.filter(func(id): return not placed.has(id))
	return {"key": hk, "kind": kind, "pose": pose, "hero": ht, "X": X, "size": sz, "U": U, "Uc": U * f, "f": f,
		"pts": pts, "behind": behind, "front": front, "missing": missing, "girl": gender == "girl"}


## Точки «героя кодом» для эффектов кода (сияния-частицы, блеск редкости, сияющие глаза) по нарисованному герою
static func code_anchors(p: Dictionary) -> Dictionary:
	var kind: String = p.kind
	var Uc: float = p.Uc
	var pts: Dictionary = p.pts
	var ex: float = EYE_DX.get(kind, 0.27) * Uc
	var e: Vector2 = pts.eyes
	var comp: Vector2 = {"kitten": Vector2(126, -104), "puppy": Vector2(132, -100), "axolotl": Vector2(140, -78)}.get(kind, Vector2(128, -72))
	return {"top": pts.head, "top_w": Uc * 0.7, "tilt": 0.0,
		"eye_l": e + Vector2(-ex, 0), "eye_r": e + Vector2(ex, 0), "eye_rad": Uc * 0.17, "temple": Uc * 0.62,
		"neck": pts.neck, "neck_w": Uc * 0.8, "back": pts.back, "back_w": Uc * 0.9, "kind": kind,
		"comp": comp, "center": (pts.head + pts.ground) * 0.5, "size": float({"kitten": 114.0, "puppy": 118.0, "axolotl": 120.0}.get(kind, 118.0)),
		"hp": func(v): return v}


## Жабры аксолотля (для светящихся жабр): 6 ломаных по 7 точек от головы к жемчужинам
static func gills(p: Dictionary) -> Array:
	var an := anchors(p.key)
	if an.is_empty():
		return []
	var it := fit_item("ax_gill_pearls")
	var W: float = p.size.x
	var H: float = p.size.y
	var X: Transform2D = p.X
	var out: Array = []
	var Ls: Array = it.get("layers", [])
	for i in Ls.size():
		var tip: Vector2 = X * (place(Ls[i], an, W, H, p.pose, p.kind)[0] as Vector2)
		var b: Vector2 = GILL_BASE[i % 3]
		var sx := -1.0 if i < 3 else 1.0
		var base: Vector2 = p.pts.head + Vector2(b.x * sx, b.y) * p.Uc
		var line := PackedVector2Array()
		for k in 7:
			var s := k / 6.0
			line.append(base.lerp(tip, s) + (tip - base).orthogonal().normalized() * sin(s * PI) * 4.0 * sx)
		out.append(line)
	return out


## Хвост котика (для звёздного хвоста): [ось 16 точек, толщины] или [] — хвоста в позе не видно
static func kitten_tail(p: Dictionary) -> Array:
	if p.kind != "kitten" or not KIT_TAIL.has(p.pose):
		return []
	var ctrl: Array = KIT_TAIL[p.pose]
	var X: Transform2D = p.X
	var sz: Vector2 = p.size
	var c2 := PackedVector2Array()
	for v in ctrl:
		c2.append(X * Vector2(v.x * sz.x, v.y * sz.y))
	var mid := PackedVector2Array()
	var ws: Array = []
	for i in 16:
		var s := i / 15.0 * (c2.size() - 1)
		var j := mini(int(s), c2.size() - 2)
		mid.append(c2[j].lerp(c2[j + 1], s - j))
		ws.append(lerpf(16.0, 9.0, i / 15.0) * p.Uc / 135.0)
	return [mid, ws]


# ---------- Рисование ----------

## Нарисовать слои плана на target с матрицей base (координаты героя кодом -> target).
## which: "behind" / "front"; t — для покачивания спутника.
static func draw_layers(target: CanvasItem, p: Dictionary, which: String, base: Transform2D, t: float, skip_comp := false) -> void:
	for e in p[which]:
		var M: Transform2D = e[1]
		if e[3] == "companion":
			if skip_comp:
				continue
			M = Transform2D(0.0, Vector2(sin(t * 0.9) * 6.0, sin(t * 1.7) * 5.0)) * M
		target.draw_set_transform_matrix(base * M)
		target.draw_texture(e[0], Vector2.ZERO, e[2])


static func draw_hero_tex(target: CanvasItem, p: Dictionary, base: Transform2D, mod := Color.WHITE) -> void:
	target.draw_set_transform_matrix(base * (p.X as Transform2D))
	target.draw_texture(p.hero, Vector2.ZERO, mod)


## Текстура, обрезанная кругом (аватарки): M — пиксели текстуры -> target, circle — многоугольник круга
static func draw_clipped(target: CanvasItem, t: Texture2D, M: Transform2D, circle: PackedVector2Array, mod := Color.WHITE) -> void:
	var sz := t.get_size()
	var quad := PackedVector2Array([M * Vector2.ZERO, M * Vector2(sz.x, 0), M * sz, M * Vector2(0, sz.y)])
	if Geometry2D.is_polygon_clockwise(quad):
		quad.reverse()
	var inv := M.affine_inverse()
	for poly in Geometry2D.intersect_polygons(quad, circle):
		if poly.size() < 3:
			continue
		var uvs := PackedVector2Array()
		for q in poly:
			var l: Vector2 = inv * q
			uvs.append(Vector2(l.x / sz.x, l.y / sz.y))
		target.draw_polygon(poly, PackedColorArray([mod]), uvs, t)


## Голова героя в наряде в круге (c, r): верх картинки между head и neck
static func draw_avatar(target: CanvasItem, p: Dictionary, c: Vector2, r: float) -> void:
	var circle := PackedVector2Array()
	for i in 40:
		var a := i * TAU / 40.0
		circle.append(c + Vector2(cos(a), sin(a)) * r)
	var pts: Dictionary = p.pts
	var mid: Vector2 = pts.head.lerp(pts.neck, 0.42)
	var k: float = r / (0.74 * p.Uc)
	var base := Transform2D(0.0, Vector2(k, k), 0.0, c - mid * k)
	target.draw_set_transform(Vector2.ZERO)
	for e in p.behind:
		draw_clipped(target, e[0], base * (e[1] as Transform2D), circle, e[2])
	draw_clipped(target, p.hero, base * (p.X as Transform2D), circle)
	for e in p.front:
		if e[3] != "companion":
			draw_clipped(target, e[0], base * (e[1] as Transform2D), circle, e[2])


## Значок вещи для карточки (icons/<id>.webp; окрас девочки — <id>_girl). false — значка нет.
static func draw_icon(target: CanvasItem, id: String, kind: String, c: Vector2, size: float, girl := false) -> bool:
	if not enabled or id == "":
		return false
	var owner := Meta.owner_of(id)
	var t := tex(icon_path(owner if owner != "" else kind, id, girl))
	if t == null:
		return false
	target.draw_set_transform(Vector2.ZERO)
	target.draw_texture_rect(t, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false)
	return true


# ---------- Сборка в Image (для тестов: сравнение с art_src/wardrobe/compose.py) ----------

static func _image(path: String) -> Image:
	# исходный файл картинки (есть в проекте, не в собранной игре — сборка в Image только для тестов)
	var img := Image.new()
	if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Повторяет compose.compose(): холст с полями margin, слои позади, герой, слои спереди, обрезка по содержимому
## (crop = false — без обрезки: герой в точке (W·margin, H·margin), для сравнения со сборкой по текстурам игры).
static func compose_image(kind: String, pose: String, items: Array, gender := "boy", skin := "", margin := 0.55, crop := true) -> Image:
	_load()
	var key := hero_key(kind, pose, gender, skin)
	var himg := _image(hero_path(key))
	var an := anchors(key)
	if himg == null or an.is_empty():
		return null
	var W := himg.get_width()
	var H := himg.get_height()
	var mx := int(W * margin)
	var my := int(H * margin)
	var canvas := Image.create(W + 2 * mx, H + 2 * my, false, Image.FORMAT_RGBA8)
	var Ls := layers_for(items, gender)
	for L in Ls.filter(func(x): return x.get("z", "") == "behind"):
		_draw_layer_img(canvas, L, kind, place(L, an, W, H, pose, kind), Vector2(mx, my))
	canvas.blend_rect(himg, Rect2i(0, 0, W, H), Vector2i(mx, my))
	for L in Ls.filter(func(x): return x.get("z", "") != "behind"):
		_draw_layer_img(canvas, L, kind, place(L, an, W, H, pose, kind), Vector2(mx, my))
	if not crop:
		return canvas
	var bb := canvas.get_used_rect()
	return canvas.get_region(bb) if bb.size.x > 0 else canvas


static func _draw_layer_img(canvas: Image, L: Dictionary, kind: String, pl: Array, off: Vector2) -> void:
	var src := _image(layer_path(kind, L.file))
	if src == null:
		return
	var at: Vector2 = pl[0] + off
	var k: float = pl[1] / src.get_width()
	var im := src.duplicate() as Image
	im.resize(maxi(1, roundi(src.get_width() * k)), maxi(1, roundi(src.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var pv: Array = L.get("pivot", [0.5, 0.5])
	var px := float(pv[0])
	var py := float(pv[1])
	if L.get("flip", false):
		im.flip_x()
		px = 1.0 - px
	var a := float(L.get("alpha", 1.0))
	if a < 1.0:
		for y in im.get_height():
			for x in im.get_width():
				var col := im.get_pixel(x, y)
				col.a = floorf(col.a * 255.0 * a) / 255.0
				im.set_pixel(x, y, col)
	var pvx := px * im.get_width()
	var pvy := py * im.get_height()
	var r := 0.0
	for cx in [0.0, float(im.get_width())]:
		for cy in [0.0, float(im.get_height())]:
			r = maxf(r, Vector2(cx - pvx, cy - pvy).length())
	var ri := int(r) + 2
	var sq := Image.create(2 * ri, 2 * ri, false, Image.FORMAT_RGBA8)
	sq.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(roundi(ri - pvx), roundi(ri - pvy)))
	var rot: float = pl[2]
	if rot != 0.0:
		sq = _rotate(sq, rot)
	canvas.blend_rect(sq, Rect2i(Vector2i.ZERO, sq.get_size()), Vector2i(roundi(at.x - ri), roundi(at.y - ri)))


## Поворот квадратной картинки вокруг центра на deg по часовой (билинейно, как PIL rotate(-deg))
static func _rotate(img: Image, deg: float) -> Image:
	var n := img.get_width()
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := deg_to_rad(deg)
	var ca := cos(a)
	var sa := sin(a)
	var c := n / 2.0
	for y in n:
		for x in n:
			var dx := x + 0.5 - c
			var dy := y + 0.5 - c
			# обратный поворот: где этот пиксель был до поворота
			var sx := dx * ca + dy * sa + c - 0.5
			var sy := -dx * sa + dy * ca + c - 0.5
			if sx < -1.0 or sy < -1.0 or sx > n or sy > n:
				continue
			var x0 := floori(sx)
			var y0 := floori(sy)
			var fx := sx - x0
			var fy := sy - y0
			var acc := Color(0, 0, 0, 0)
			var wsum := 0.0
			for q in [[x0, y0, (1 - fx) * (1 - fy)], [x0 + 1, y0, fx * (1 - fy)], [x0, y0 + 1, (1 - fx) * fy], [x0 + 1, y0 + 1, fx * fy]]:
				if q[0] < 0 or q[1] < 0 or q[0] >= n or q[1] >= n:
					continue
				var col := img.get_pixel(q[0], q[1])
				acc.r += col.r * col.a * q[2]
				acc.g += col.g * col.a * q[2]
				acc.b += col.b * col.a * q[2]
				acc.a += col.a * q[2]
				wsum += q[2]
			if acc.a > 0.0001:
				out.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a))
	return out
