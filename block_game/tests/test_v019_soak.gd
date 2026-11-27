extends SceneTree
## 0.19: «долгий прогон» (tools/soak_bot.gd) — робот играет уровни 1–15 и всё время мешает игре:
## пауза, «Назад», сворачивание, отмена, меню, перезапуск, повтор обучения — в том числе во время
## каскада, замедления, взрыва и полёта кристаллов. Проверки: ни одного зависания (фигура не падает
## и ввод не принимается), Engine.time_scale = 1, время шага и кадра, память и число объектов
## не растут от начала к концу.
## В тестах — короткий прогон (7 минут игрового времени, ~10 с). Долгий (на телефонный движок тоже):
##   godot --headless --path block_game -s tests/test_v019_soak.gd -- --soak-sec=1200 --seed=7
## Параметры: --soak-sec=N (игровых секунд), --seed=S, --levels=A-B, --k=N (шагов игры на кадр движка).

const SoakBot := preload("res://tools/soak_bot.gd")
const I18n := preload("res://scripts/i18n.gd")
const Meta := preload("res://scripts/meta.gd")
const HeroArt := preload("res://scripts/hero_art.gd")
const FILES := ["user://save.cfg", "user://home3d_guard.cfg"]

var failed := 0
var frame := 0
var g
var bot
var kept := {}
var soak_sec := 420.0
var k := 30
var long_run := false
var last_us := 0
var draw_acc := 0.0
var draw_n := 0
var next_min := 60.0
var started := false


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failed += 1
		printerr("  FAIL ", msg)


func _initialize() -> void:
	for f in FILES:
		kept[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	var args := {"soak-sec": "", "seed": "19", "levels": "1-15", "k": "30"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	if args["soak-sec"] != "":
		soak_sec = float(args["soak-sec"])
		long_run = true
	k = int(args.k)
	var lv := String(args.levels).split("-")
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.set_process(false)  # кадры игры даёт робот (g._process), рисование — движок
	bot = SoakBot.new(g, int(args.seed), Vector2i(int(lv[0]), int(lv[1]) if lv.size() > 1 else int(lv[0])))


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if not started:
		started = true
		I18n.set_lang("ru")
		g.tour.enabled = false
		g.meta = Meta.new()
		g.meta.set_hero("owl")
		g.max_level = 1  # прогресс как у нового игрока (сохранение вернётся после прогона)
		g.stars = {}
		g.tut.replay()
		g.go_home()
		# картинки героя во всех позах грузятся один раз и остаются в кэше (HeroArt.tex) —
		# грузим заранее, чтобы рост памяти в прогоне был только от утечек
		for gender in ["boy", "girl"]:
			for pose in ["idle", "happy", "wow", "worried", "sad"]:
				HeroArt.tex(HeroArt.hero_path(HeroArt.hero_key("owl", pose, gender)))
		print("— долгий прогон: %.0f с игрового времени, уровни %d–%d" % [soak_sec, bot.levels.x, bot.levels.y])
		last_us = Time.get_ticks_usec()
		return false
	# время кадра движка без шагов игры — это рисование (_draw игры, картинка героя)
	var now := Time.get_ticks_usec()
	for i in k:
		bot.tick()
	if frame > 4:
		draw_acc += float(now - last_us)
		draw_n += 1
	last_us = Time.get_ticks_usec()
	if bot.t >= next_min:
		next_min += 60.0
		var r: Dictionary = bot.sample(draw_acc / maxi(draw_n, 1))
		draw_acc = 0.0
		draw_n = 0
		print("  ", SoakBot.row_text(r))
	if bot.t >= soak_sec:
		_report()
		_finish()
		return true
	return false


func _report() -> void:
	print("  побед %d, поражений %d, фигур %d, самая длинная цепочка ×%d, наибольшее замедление %.2f с" % [
		bot.wins, bot.loses, bot.pieces, bot.max_chain, bot.max_slow])
	var keys: Array = bot.counts.keys()
	keys.sort()
	print("  помехи: ", ", ".join(keys.map(func(x): return "%s %d" % [x, bot.counts[x]])))
	for s in bot.stuck:
		printerr("  ЗАВИСАНИЕ %s" % str(s))
	check(bot.stuck.is_empty(), "ни одного зависания за %.0f с (фигура падает, каскад доходит до конца, ввод принимается)" % bot.t)
	check(Engine.time_scale == 1.0 and bot.max_slow <= 0.3, "Engine.time_scale = 1, замедление праздника не «застревает»")
	check(bot.counts.get("back", 0) > 0 and bot.counts.get("minimize", 0) > 0 and bot.counts.get("pause_resume", 0) > 0,
		"помехи были: «Назад», сворачивание, пауза и продолжение")
	check(bot.counts.get("cascade:back", 0) + bot.counts.get("cascade:minimize", 0) + bot.counts.get("cascade:pause_btn", 0) > 0,
		"помехи были и во время каскада (там игра раньше «замерзала»)")
	check(bot.wins > 0, "робот выигрывает уровни (игра идёт)")
	var m: Array = bot.minute
	if m.size() >= 3:
		var a: Dictionary = m[1]
		var b: Dictionary = m[m.size() - 1]
		print("  начало: ", SoakBot.row_text(a))
		print("  конец:  ", SoakBot.row_text(b))
		check(b.objects <= a.objects + 400, "объектов не прибавляется (%d -> %d)" % [a.objects, b.objects])
		check(b.nodes <= a.nodes + 5, "узлов не прибавляется (%d -> %d)" % [a.nodes, b.nodes])
		check(b.mem <= a.mem + 6 * 1048576, "память не растёт (%.1f -> %.1f МБ)" % [a.mem / 1048576.0, b.mem / 1048576.0])
		check(b.orphans == 0, "нет узлов-сирот")
		check(b.tick_us < maxf(a.tick_us * 3.0, 3000.0), "шаг игры не замедляется (%.0f -> %.0f мкс)" % [a.tick_us, b.tick_us])


func _finish() -> void:
	g.queue_free()
	for f in FILES:
		if kept[f] != null:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(kept[f])
			fa.close()
		elif FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("Итог: ", "ВСЁ ОК" if failed == 0 else "%d ошибок" % failed)
	quit(1 if failed else 0)
