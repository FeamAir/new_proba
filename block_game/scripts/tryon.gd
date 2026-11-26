extends RefCounted
## Примерка в гардеробе (Cascado 0.7): некупленная вещь или украшение показываются
## временно, ничего не покупая. Купить — confirm(), отказаться — clear().
## Примерка не сохраняется: в save.cfg попадают только купленные вещи (meta.gd).
## 0.15: примерка варианта стен / пола / света комнаты (start_room, room()).

const Meta := preload("res://scripts/meta.gd")
const Catalog := preload("res://scripts/decor_catalog.gd")

var id := ""        # что примеряем; "" — примерки нет
var home := ""      # для украшения — дом героя
var spot := ""      # для украшения — место в доме


func active() -> bool:
	return id != ""


func is_decor() -> bool:
	return active() and Meta.item(id).has("home")


## 0.15: примеряется вариант слоя стиля комнаты
func is_room() -> bool:
	return active() and Catalog.is_room_item(id)


func start_room(h: String, item_id: String) -> void:
	id = item_id
	home = h
	spot = ""


func start_item(item_id: String) -> void:
	id = item_id
	home = ""
	spot = ""


func start_decor(h: String, sp: String, item_id: String) -> void:
	id = item_id
	home = h
	spot = sp


func clear() -> void:
	id = ""
	home = ""
	spot = ""


## Наряд для рисования: купленный наряд, а в слоте примеряемой вещи — она.
func outfit(meta) -> Dictionary:
	var o: Dictionary = meta.outfit()
	if active() and not is_decor():
		Meta.put_on(o, id)  # 0.12b: супер-эксклюзив снимает вещи своих слотов, и наоборот
	return o


## Украшения дома для рисования: поставленные, а на месте примерки — примеряемое.
func placed(meta, h: String) -> Dictionary:
	var d: Dictionary = meta.decor_placed.get(h, {}).duplicate()
	if is_decor() and h == home:
		d[spot] = id
	return d


## 0.15: повороты вещей для рисования (у примеряемой — без поворота)
func rots(meta, h: String) -> Dictionary:
	var r: Dictionary = meta.decor_rot.get(h, {}).duplicate()
	if is_decor() and h == home:
		r.erase(spot)
	return r


## 0.15: стиль комнаты для рисования: выбранный, а в слое примерки — примеряемый вариант
func room(meta, h: String) -> Dictionary:
	var st: Dictionary = meta.room_of(h)
	if is_room() and h == home:
		st[Catalog.room_item(id).layer] = id
	return st


## Можно ли купить: "ok", "poor" (не хватает осколков), "locked" (условие: звёзды / зал).
func status(meta, total_stars: int, max_level: int) -> String:
	if not active():
		return "locked"
	if Meta.lock_reason(id, total_stars, max_level) != "":
		return "locked"
	if is_room() and Catalog.room_item(id).house != meta.hero:
		return "locked"
	if Meta.owner_of(id) != "" and Meta.owner_of(id) != meta.hero:
		return "locked"  # 0.12b: чужую вещь не купить
	if meta.shards < price():
		return "poor"
	return "ok"


func price() -> int:
	if is_room():
		return int(Catalog.room_item(id).get("price", 0))
	return int(Meta.item(id).get("price", 0))


## Сколько осколков не хватает (0 — хватает).
func shortage(meta) -> int:
	return maxi(0, price() - int(meta.shards))


## «Купить»: покупает и надевает / ставит. Удачно — примерка закончена.
## Возвращает то же, что meta.buy_item / buy_decor: "bought", "owned", "poor", "locked".
func confirm(meta, total_stars: int, max_level: int) -> String:
	if not active():
		return "locked"
	var res: String
	if is_room():
		res = meta.buy_room(home, id, total_stars, max_level)
	elif is_decor():
		res = meta.buy_decor(home, spot, id, total_stars, max_level)
	else:
		res = meta.buy_item(id, total_stars, max_level)
	if res == "bought" or res == "owned":
		clear()
	return res
