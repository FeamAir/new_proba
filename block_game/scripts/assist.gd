extends RefCounted
## Версия 0.9: удержание игроков. Только данные и правила, без рисования
## (рисование — scripts/assist_ui.gd):
##  - помощь на трудном уровне «Подсказка кристалла»: после 2 проигрышей подряд
##    на одном уровне можно убрать нижний ряд камня (после 3+ — два ряда), бесплатно;
##  - счётчик попыток по уровням (хранится только на телефоне, никуда не отправляется),
##    выгрузка в CSV для тестировщиков;
##  - «Подарок новичку»: +10 осколков за самую первую победу в игре;
##  - цель на главном экране: ближайшая по цене непокупленная доступная вещь.
## Сохраняется в user://save.cfg, раздел [stats]; старые сохранения без него
## загружаются со значениями по умолчанию.

const Meta := preload("res://scripts/meta.gd")

const OFFER_AFTER := 2       # проигрышей подряд, после которых предлагается помощь
const BIG_AFTER := 3         # с этого числа проигрышей убираются 2 ряда
const NEWBIE_GIFT := 10
const CSV_HEADER := "level,attempts,losses,wins,best_pieces,assists"

var track := true            # false — не считать (робот-тестер)
var levels: Dictionary = {}  # номер уровня -> {"tries", "losses", "wins", "best", "help"}
var streak: Dictionary = {}  # номер уровня -> проигрышей подряд
var gift_given := false
var boost_level := 0         # принятая помощь: для какого уровня (0 — нет)
var boost_rows := 0          # сколько рядов убрать


# ---------- Счётчик попыток ----------

func rec(n: int) -> Dictionary:
	if not levels.has(n):
		levels[n] = {"tries": 0, "losses": 0, "wins": 0, "best": 0, "help": 0}
	return levels[n]


## Начало попытки уровня n. Возвращает, сколько рядов камня убрать (принятая помощь),
## помощь при этом расходуется.
func on_start(n: int) -> int:
	var rows := boost_rows if boost_level == n else 0
	boost_level = 0
	boost_rows = 0
	if not track:
		return rows
	rec(n).tries += 1
	if rows > 0:
		rec(n).help += 1
	return rows


func on_lose(n: int) -> void:
	if not track:
		return
	rec(n).losses += 1
	streak[n] = int(streak.get(n, 0)) + 1


func on_win(n: int, pieces: int) -> void:
	if not track:
		return
	var r := rec(n)
	r.wins += 1
	r.best = pieces if r.best <= 0 else mini(r.best, pieces)
	streak.erase(n)


# ---------- Помощь ----------

## Сколько рядов предложить убрать на уровне n (0 — помощь не предлагается).
func offer_rows(n: int) -> int:
	var s := int(streak.get(n, 0))
	if s >= BIG_AFTER:
		return 2
	if s >= OFFER_AFTER:
		return 1
	return 0


## Игрок согласился: помощь сработает при следующем старте этого уровня.
func accept(n: int) -> bool:
	var rows := offer_rows(n)
	if rows <= 0:
		return false
	boost_level = n
	boost_rows = rows
	return true


## Убрать k нижних рядов камня: всё поле сдвигается вниз, кристаллы из убранных рядов
## считаются освобождёнными. Хотя бы один ряд камня и один кристалл остаются.
## Возвращает {"rows": сколько убрано, "freed": сколько кристаллов освобождено}.
static func apply_boost(board: Array, cols: int, rows_total: int, empty: int, crystal: int, k: int, crystals_total: int) -> Dictionary:
	var res := {"rows": 0, "freed": 0}
	# ряды камня: снизу подряд, в ряду почти нет дыр (как в tools/level_bot.gd)
	var stone_rows := 0
	for y in range(rows_total - 1, -1, -1):
		var filled := 0
		for x in cols:
			if board[y * cols + x] != empty:
				filled += 1
		if filled < cols - 3:
			break
		stone_rows += 1
	k = mini(k, stone_rows - 1)
	if k <= 0:
		return res
	var freed := 0
	for y in range(rows_total - k, rows_total):
		for x in cols:
			if board[y * cols + x] == crystal:
				freed += 1
	for y in range(rows_total - 1, -1, -1):
		for x in cols:
			board[y * cols + x] = board[(y - k) * cols + x] if y - k >= 0 else empty
	# все кристаллы были в убранных рядах — один возвращается в новый нижний ряд
	if freed >= crystals_total:
		var y := rows_total - 1
		for x in cols:
			if board[y * cols + x] != empty and board[y * cols + x] != crystal:
				board[y * cols + x] = crystal
				freed -= 1
				break
	res.rows = k
	res.freed = freed
	return res


# ---------- Подарок новичку ----------

## +10 осколков за самую первую победу в игре. total_stars — звёзд до этой победы:
## у игрока с прогрессом (старое сохранение) подарка нет, он просто отмечается выданным.
func take_gift(total_stars_before: int) -> int:
	if gift_given:
		return 0
	gift_given = true
	return NEWBIE_GIFT if total_stars_before == 0 else 0


# ---------- Цель «до следующей вещи» ----------

## Ближайшая по цене непокупленная и не закрытая вещь гардероба или украшение своего дома.
## Пусто — всё куплено. Иначе {"id", "price", "have", "need" (сколько не хватает), "ready"}.
static func next_goal(meta, hero: String, total_stars: int, max_level: int) -> Dictionary:
	var best := {}
	for it in Meta.ITEMS + Meta.DECOR:
		if it.has("home") and it.home != hero:
			continue
		if meta.is_owned(it.id) or Meta.lock_reason(it.id, total_stars, max_level) != "":
			continue
		if best.is_empty() or int(it.price) < int(best.price):
			best = it
	if best.is_empty():
		return {}
	var price := int(best.price)
	return {"id": best.id, "price": price, "have": meta.shards, "need": maxi(0, price - meta.shards),
		"ready": meta.shards >= price, "home": best.get("home", ""), "slot": best.get("slot", "home")}


# ---------- CSV для тестировщиков ----------

func sorted_levels() -> Array:
	var ks := levels.keys()
	ks.sort()
	return ks


func csv() -> String:
	var lines := [CSV_HEADER]
	for n in sorted_levels():
		var r: Dictionary = levels[n]
		lines.append("%d,%d,%d,%d,%d,%d" % [n, r.tries, r.losses, r.wins, r.best, r.help])
	return "\n".join(lines) + "\n"


# ---------- Сохранение: [stats] ----------

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("stats", "levels", levels)
	cfg.set_value("stats", "streak", streak)
	cfg.set_value("stats", "gift", gift_given)


func load_from(cfg: ConfigFile) -> void:
	levels = {}
	streak = {}
	var lv = cfg.get_value("stats", "levels", {})
	if lv is Dictionary:
		for n in lv:
			var r = lv[n]
			if (n is int) and n > 0 and r is Dictionary:
				var d := rec(n)
				for f in ["tries", "losses", "wins", "best", "help"]:
					var v = r.get(f, 0)
					d[f] = maxi(0, int(v)) if (v is int or v is float) else 0
	var st = cfg.get_value("stats", "streak", {})
	if st is Dictionary:
		for n in st:
			if (n is int) and (st[n] is int) and st[n] > 0:
				streak[n] = st[n]
	var gg = cfg.get_value("stats", "gift", false)
	gift_given = gg if gg is bool else false
	boost_level = 0
	boost_rows = 0
