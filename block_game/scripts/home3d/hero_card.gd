extends Node2D
## «Картонка» героя для 3D-дома: рисует 2D-героя (scripts/hero.gd) внутри SubViewport.
## Текстура этого SubViewport показывается в 3D-комнате спрайтом, всегда повёрнутым к камере.
## Так в 3D сохраняются все анимации, окраски и наряды героя без перерисовки в 3D.
## 0.18: нарисованный герой (scripts/hero_art.gd) собирается в SubViewport ОДИН раз — при смене наряда,
## позы (касание — happy) или размера; дыхание и подпрыгивание — масштабом и сдвигом самого спрайта.
## 0.19: размер картинки подбирается под наряд (frame()): спутник, сияние и высокие шляпы не обрезаются краем.
## Если в наряде есть частицы кода (сияние, супер-награда) — картинка обновляется 12 раз в секунду.
## Рисунок кодом (картинки нет или HeroArt.enabled = false) — как раньше, каждый кадр.

const Hero := preload("res://scripts/hero.gd")
const HeroArt := preload("res://scripts/hero_art.gd")

const FX_FPS := 12.0

var kind := "owl"
var outfit := {}
## Секунд с последнего касания (для реакции героя), как в игре
var react := 99.0
## Масштаб: size — сторона «основного» квадрата картинки (512 — высокое качество, 320 — простое),
## sc — масштаб героя при size = 512. Ноги героя в основном квадрате — на (0.5, FEET) его стороны.
var size := 512
var sc := 1.5
## 0.18: спрайт в комнате и точка под лапками (задаёт room.gd) — для дыхания спрайтом
var sprite: Sprite3D
var feet3d := Vector3.ZERO
## Подъём спрайта над feet3d (покачивание героя в комнате, задаёт room.gd)
var lift := 0.0
var renders := 0          # сколько раз картинка собрана (для тестов)
## 0.19: рамка картинки в координатах «героя кодом» (см. frame()) и где в картинке начало координат героя (px)
var frame_rect := Rect2()
var origin_px := Vector2.ZERO

## Запас вокруг слоёв для эффектов кода (блеск редких вещей, частицы сияний), единиц «героя кодом»
const FX_PAD := 12.0
## Прыжок щенка при касании (hero.gd _draw_art): обычный и супер-награды pu_hero
const PUPPY_HOP := 14.0
const PUPPY_HERO_JUMP := 46.0
## Частицы сияний, которые рисует код (hero_magic.gd, wardrobe_*.gd): где они бывают, в долях размера
## героя a.size вокруг a.center. Остальным сияниям хватает мягкого свечения ±1.35 (оно же внутри картинок сияний).
const AURA_FX := {
	"pu_aura_bolts": Rect2(-2.35, -1.5, 3.85, 3.0),     # полоски скорости слева, молнии
	"ow_aura_starfall": Rect2(-1.4, -2.15, 3.3, 3.5),   # падающие звёзды с хвостами справа сверху
}
const AURA_GLOW := Rect2(-1.35, -1.35, 2.7, 2.7)

var _hero = Hero.new()
var _t := 0.0
var _sig := ""
var _fx_since := 0.0
var _layout_sig := ""


## Рамка картинки в координатах «героя кодом»: прежний квадрат (ноги внизу посередине) плюс всё,
## что рисует наряд в позах idle и happy — спутник с покачиванием, сияние, высокие шляпы.
## Одна рамка на обе позы — картонка не меняет размер при касании.
func frame() -> Rect2:
	var side := 512.0 / sc
	var f := Rect2(-side * 0.5, HeroArt.FEET_Y - side * FEET, side, side)
	if not HeroArt.available(kind, outfit, "idle"):
		return f  # рисунок кодом — как раньше
	var aura: String = outfit.get("aura", "")
	for pose in ["idle", "happy"]:
		var p := HeroArt.plan(kind, outfit, pose)
		var b := HeroArt.bounds(p)
		if b.has_area():
			f = f.merge(b.grow(FX_PAD))
		if aura != "" and not p.is_empty():
			var a := HeroArt.code_anchors(p)
			var r: Rect2 = AURA_FX.get(aura, AURA_GLOW)
			var R: float = a.size
			f = f.merge(Rect2(a.center + r.position * R, r.size * R).grow(FX_PAD))
	if kind == "puppy":
		f = f.grow_individual(0.0, PUPPY_HERO_JUMP if outfit.get("aura", "") == "pu_hero" else PUPPY_HOP, 0.0, 0.0)
	return f


## Подогнать размер SubViewport и смещение спрайта под рамку (при смене героя, наряда или качества)
func layout() -> void:
	var sig := "%s|%s|%d" % [kind, str(outfit), size]
	var vp := get_parent() as SubViewport
	if sig == _layout_sig and (vp == null or vp.size == Vector2i((frame_rect.size * _px()).ceil())):
		_apply_sprite()
		return
	_layout_sig = sig
	frame_rect = frame()
	var k := _px()
	var px := Vector2i((frame_rect.size * k).ceil())
	origin_px = -frame_rect.position * k
	if vp and vp.size != px:
		vp.size = px
	_apply_sprite()
	_sig = ""  # пересобрать картинку


## Пикселей картинки на единицу «героя кодом»
func _px() -> float:
	return sc * size / 512.0


## Ноги героя в картинке (px)
func feet_px() -> Vector2:
	return origin_px + Vector2(0, HeroArt.FEET_Y * _px())


## Спрайт: начало координат спрайта — точка под лапками (смещение offset, ось y вверх)
func _apply_sprite() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var vp := get_parent() as SubViewport
	var px := Vector2(vp.size) if vp else frame_rect.size * _px()
	var fp := feet_px()
	var ofs := Vector2(px.x * 0.5 - fp.x, fp.y - px.y * 0.5)
	if not sprite.centered or sprite.offset != ofs:
		sprite.centered = true
		sprite.offset = ofs


func _process(delta: float) -> void:
	_t += delta
	react += delta
	layout()
	var vp := get_parent() as SubViewport
	var pose := "happy" if react < Hero.REACT_TIME else "idle"
	if vp == null or not HeroArt.available(kind, outfit, pose):
		_hero.still = false
		if vp:
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		queue_redraw()
		return
	_hero.still = true
	var sig := "%s|%s|%s|%d" % [kind, str(outfit), pose, size]
	var fx: bool = outfit.get("aura", "") != ""
	_fx_since += delta
	if sig != _sig or (fx and _fx_since >= 1.0 / FX_FPS):
		_sig = sig
		_fx_since = 0.0
		queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_animate_sprite()


## Дыхание и подпрыгивание при касании — спрайтом (картинку не пересобираем)
func _animate_sprite() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var breath := 1.0 + 0.018 * sin(_t * 2.2)
	var hop := 0.0
	if react < Hero.REACT_TIME:
		hop = absf(sin(react / Hero.REACT_TIME * TAU)) * 0.06 * Hero.react_env(react)
	sprite.scale = Vector3(1.0, breath, 1.0)
	sprite.position = feet3d + Vector3(0, hop + lift, 0)


func poke() -> void:
	react = 0.0


## Ноги героя внутри картинки (доля высоты)
const FEET := 470.0 / 512.0


func _draw() -> void:
	# начало координат героя — origin_px (ноги героя в его координатах — на y = 115)
	_hero.draw(self, kind, origin_px, _px(), outfit, _t, react)
	renders += 1
