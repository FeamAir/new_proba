extends RefCounted
## Cascado 0.18: свайп по ленте карточек (гардероб, режим украшения, полка кубков 2D).
## Касание в ленте не срабатывает сразу: решение — когда палец отпущен.
##   почти не сдвинулся (до TAP_SLOP) — это тап: вызывающий выполняет обычное нажатие в точке касания;
##   ушёл по горизонтали на SWIPE_MIN и больше (и больше, чем по вертикали) — свайп: страница вперёд / назад;
##   что-то среднее (повёл и передумал, повёл вверх-вниз) — ничего: ни покупки, ни примерки, ни страницы.
## Палец влево (как перелистнуть страницу книги) — следующая страница (+1), вправо — предыдущая (-1).
## Пиксели — экрана 720 по ширине.

const TAP := 0
const NEXT := 1
const PREV := -1
const NONE := 2
## Дальше этого (пикселей) палец ушёл — уже не тап
const TAP_SLOP := 24.0
## Столько пикселей по горизонтали — свайп
const SWIPE_MIN := 70.0

var idx := -1        # какой палец ведёт ленту (-1 — никакой)
var start := Vector2.ZERO
var last := Vector2.ZERO
var far := 0.0       # как далеко палец уходил от точки касания


## Что значит движение пальца d (от касания до отпускания); far — самое дальнее удаление по пути
static func classify(d: Vector2, far_ := -1.0) -> int:
	if absf(d.x) >= SWIPE_MIN and absf(d.x) > absf(d.y) * 1.2:
		return NEXT if d.x < 0.0 else PREV
	if maxf(d.length(), far_) <= TAP_SLOP:
		return TAP
	return NONE


func active() -> bool:
	return idx >= 0


## Палец i коснулся ленты в pos (новое касание всегда начинает заново: не «залипнет», если отпускание
## пришлось на другой экран)
func press(i: int, pos: Vector2) -> void:
	idx = i
	start = pos
	last = pos
	far = 0.0


func move(i: int, pos: Vector2) -> void:
	if i != idx:
		return
	last = pos
	far = maxf(far, pos.distance_to(start))


## Палец отпущен: TAP / NEXT / PREV / NONE (не тот палец — NONE)
func release(i: int, pos: Vector2) -> int:
	if i != idx:
		return NONE
	move(i, pos)
	idx = -1
	return classify(pos - start, far)


func cancel() -> void:
	idx = -1
