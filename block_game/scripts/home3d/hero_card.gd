extends Node2D
## «Картонка» героя для 3D-дома: рисует 2D-героя (scripts/hero.gd) внутри SubViewport.
## Текстура этого SubViewport показывается в 3D-комнате спрайтом, всегда повёрнутым к камере.
## Так в 3D сохраняются все анимации, окраски и наряды героя без перерисовки в 3D.
## 0.18: нарисованный герой (scripts/hero_art.gd) собирается в SubViewport ОДИН раз — при смене наряда,
## позы (касание — happy) или размера; дыхание и подпрыгивание — масштабом и сдвигом самого спрайта.
## Если в наряде есть частицы кода (сияние, супер-награда) — картинка обновляется 12 раз в секунду.
## Рисунок кодом (картинки нет или HeroArt.enabled = false) — как раньше, каждый кадр.

const Hero := preload("res://scripts/hero.gd")
const HeroArt := preload("res://scripts/hero_art.gd")

const FX_FPS := 12.0

var kind := "owl"
var outfit := {}
## Секунд с последнего касания (для реакции героя), как в игре
var react := 99.0
## Где стоят ноги героя внутри картинки (картинка size × size) и масштаб
var size := 512
var sc := 1.5
## 0.18: спрайт в комнате и точка под лапками (задаёт room.gd) — для дыхания спрайтом
var sprite: Sprite3D
var feet3d := Vector3.ZERO
var renders := 0          # сколько раз картинка собрана (для тестов)

var _hero = Hero.new()
var _t := 0.0
var _sig := ""
var _fx_since := 0.0


func _process(delta: float) -> void:
	_t += delta
	react += delta
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
	var half := (FEET - 0.5) * size * sprite.pixel_size * breath
	sprite.position = feet3d + Vector3(0, half + hop, 0)


func poke() -> void:
	react = 0.0


## Ноги героя внутри картинки (доля высоты)
const FEET := 470.0 / 512.0


func _draw() -> void:
	var k := size / 512.0
	var feet := Vector2(size * 0.5, size * FEET)
	# ноги героя в его координатах — на y ≈ 115
	_hero.draw(self, kind, feet - Vector2(0, 115 * sc * k), sc * k, outfit, _t, react)
	renders += 1
