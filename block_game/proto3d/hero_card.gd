extends Node2D
## ПРОТОТИП 3D-дома. «Картонка» героя: рисует 2D-героя (scripts/hero.gd) внутри SubViewport.
## Текстура этого SubViewport показывается в 3D-комнате спрайтом, всегда повёрнутым к камере.
## Так в 3D сохраняются все анимации, окраски и наряды героя без перерисовки в 3D.

const Hero := preload("res://scripts/hero.gd")

var kind := "owl"
var outfit := {}
## Секунд с последнего касания (для реакции героя), как в игре
var react := 99.0
## Где стоят ноги героя внутри картинки и масштаб
var feet := Vector2(256, 470)
var sc := 1.5

var _hero = Hero.new()
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	react += delta
	queue_redraw()


func poke() -> void:
	react = 0.0


func _draw() -> void:
	# ноги героя в его координатах — на y ≈ 115
	_hero.draw(self, kind, feet - Vector2(0, 115 * sc), sc, outfit, _t, react)
