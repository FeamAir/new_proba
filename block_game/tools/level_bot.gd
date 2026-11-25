extends SceneTree
## Робот-игрок для проверки уровней Cascado.
## Запуск (из корня репозитория):
##   godot --headless --path block_game -s tools/level_bot.gd -- --levels=1-100 --games=30 --seed=1 --tuck=1
## Параметры (все необязательные):
##   --levels=A-B   какие уровни гонять (по умолчанию 1-100)
##   --games=N      партий на уровень (по умолчанию 30)
##   --seed=S       зерно случайных фигур (один и тот же seed = одинаковые партии)
##   --max=N        предел фигур на партию (по умолчанию 200)
##   --look=1       смотреть и на следующую фигуру (сильнее, но в ~20 раз медленнее)
##   --csv=путь     дополнительно записать итог в CSV
##   --seeds=K      режим подбора раскладки: для каждого уровня пробует K зёрен
##                  (zerno = n*7919+13 + k*104729) и пишет в CSV строку на каждое
##   --k0=K         с какого k начинать перебор зёрен (по умолчанию 0)
##   --set=a:1,b:2  временно заменить поля строки таблицы (например --set=hang:1,rows:3)
##   --tuck=1       кроме бросков сверху пробовать «подсунуть» фигуру: опустить до упора
##                  и сдвинуть вбок на 1–3 клетки (под островок камня, уровни 51+);
##                  так играет человек, в ~2 раза медленнее. Уровни 51–100 настроены с --tuck=1
## Робот ставит фигуры мгновенно: скорость падения на него не влияет.
## Прогресс игрока (user://save.cfg) сохраняется до прогона и возвращается после.

const SAVE := "user://save.cfg"
const Gravity := preload("res://scripts/gravity.gd")
# Номера фигур в расчётах робота — заведомо больше игровых, чтобы не совпасть.
const SIM_ID := 1000000

var G  # экземпляр игры
var COLS := 8
var ROWS := 14
var EMPTY := -1
var CRYSTAL := 8

# Веса оценки положения
const W_CRYSTAL := 1000.0
const W_LINE := 40.0
const W_HOLE := 45.0
const W_HEIGHT := 3.0
const W_BUMP := 4.0
const W_TOP := 25.0      # штраф за каждую клетку выше безопасной высоты
const SAFE_H := 8
const W_CROW := 2.0      # бонус за заполненность рядов с кристаллами

var look := false
var tuck := false
var set_fields := {}
var mismatches := 0


func _initialize() -> void:
	var args := {"levels": "1-100", "games": "30", "seed": "1", "max": "200", "look": "0", "csv": "", "seeds": "0", "dump": "0", "set": "", "k0": "0", "tuck": "0"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var lv := String(args.levels).split("-")
	var l_from := int(lv[0])
	var l_to := int(lv[1]) if lv.size() > 1 else l_from
	var games := int(args.games)
	var base_seed := int(args.seed)
	var max_pieces := int(args.max)
	look = args.look == "1"
	tuck = args.tuck == "1"
	for kv in String(args.set).split(",", false):
		var pr: PackedStringArray = kv.split(":")
		var val = float(pr[1]) if pr[1].contains(".") else int(pr[1])
		set_fields[pr[0]] = val

	# --- бережём сохранение игрока ---
	var had_save := FileAccess.file_exists(SAVE)
	var save_bytes := PackedByteArray()
	if had_save:
		save_bytes = FileAccess.get_file_as_bytes(SAVE)

	G = load("res://scripts/game.gd").new()
	root.add_child(G)
	G.tut.enabled = false     # 0.9: без обучения и без счётчика попыток
	G.assist.track = false
	COLS = G.COLS
	ROWS = G.ROWS
	EMPTY = G.EMPTY
	CRYSTAL = G.CRYSTAL

	var lines: Array = []
	if int(args.seeds) > 0:
		_seed_search(l_from, l_to, games, base_seed, max_pieces, int(args.seeds), args.csv, int(args.k0))
		_restore(had_save, save_bytes)
		return
	var header := "lvl | ряды крист par | интервал | побед% | фигур(побед) | 1*/2*/3* % | цепь ср | каскад% | макс цепь | медиана | par~40% | партий с каскадом% | партий с ×3+% | самая длинная"
	print(header)
	lines.append("level,rows,crystals,par,fall_interval,win_pct,avg_pieces_win,avg_pieces_all,star1_pct,star2_pct,star3_pct,avg_chain,cascade_pct,avg_max_chain,median_pieces,suggested_par,cascade_games_pct,chain3_games_pct,top_chain")
	var t0 := Time.get_ticks_msec()
	var c3_total := 0
	var c4_total := 0
	var top_chain := 0
	var games_total := 0
	G.level_override = set_fields.duplicate()
	for n in range(l_from, l_to + 1):
		var wins := 0
		var pieces_win := 0
		var pieces_all := 0
		var st := [0, 0, 0, 0]
		var clears := 0
		var chain_sum := 0
		var cascades := 0
		var casc_games := 0
		var c3_games := 0
		var maxchain_sum := 0
		var lvl_top := 0
		var rows_n := 0
		var plist: Array = []
		for gi in games:
			seed(base_seed * 100003 + n * 1009 + gi)
			G.start_level(n)
			if gi == 0:
				rows_n = _stone_rows()
			var r := _play(max_pieces)
			pieces_all += r.pieces
			chain_sum += r.chain_sum
			clears += r.clears
			cascades += r.cascades
			maxchain_sum += r.max_chain
			if r.max_chain >= 2:
				casc_games += 1
			if r.max_chain >= 3:
				c3_games += 1
				c3_total += 1
			if r.max_chain >= 4:
				c4_total += 1
			top_chain = maxi(top_chain, r.max_chain)
			lvl_top = maxi(lvl_top, r.max_chain)
			games_total += 1
			if r.win:
				wins += 1
				pieces_win += r.pieces
				plist.append(r.pieces)
				st[r.stars] += 1
		var w := maxi(wins, 1)
		plist.sort()
		var med: int = plist[plist.size() / 2] if plist.size() > 0 else 0
		# предложение par: 3 звезды примерно в 40% побед робота
		var sug: int = plist[int(plist.size() * 0.4)] if plist.size() > 0 else 0
		var row := [n, rows_n, G.crystals_total, G.par, G.fall_interval(),
			100.0 * wins / games, float(pieces_win) / w, float(pieces_all) / games,
			100.0 * st[1] / w, 100.0 * st[2] / w, 100.0 * st[3] / w,
			float(chain_sum) / maxi(clears, 1), 100.0 * cascades / maxi(clears, 1), float(maxchain_sum) / games, med, sug,
			100.0 * casc_games / games, 100.0 * c3_games / games, lvl_top]
		print("%3d | %2d %2d %3d | %.2fs | %5.0f | %6.1f | %3.0f/%3.0f/%3.0f | %.2f | %4.1f | %.2f | %3d | %3d | %3.0f | %3.0f | ×%d" % [
			row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[8], row[9], row[10], row[11], row[12], row[13], row[14], row[15], row[16], row[17], row[18]])
		if args.get("dump", "") == "1":
			print("PIECES %d %s" % [n, ",".join(plist.map(func(v): return str(v)))])
		lines.append("%d,%d,%d,%d,%.3f,%.1f,%.2f,%.2f,%.1f,%.1f,%.1f,%.3f,%.1f,%.3f,%d,%d,%.1f,%.1f,%d" % row)
	print("партий с цепочкой ×3 и больше: %d из %d (%.1f%%), ×4 и больше: %d, самая длинная цепочка: ×%d" % [
		c3_total, games_total, 100.0 * c3_total / maxi(games_total, 1), c4_total, top_chain])
	print("время: %.1f с, несовпадений хода: %d" % [(Time.get_ticks_msec() - t0) / 1000.0, mismatches])
	if args.csv != "":
		var f := FileAccess.open(args.csv, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines) + "\n")
			f.close()

	_restore(had_save, save_bytes)


func _restore(had_save: bool, save_bytes: PackedByteArray) -> void:
	# --- возвращаем сохранение как было ---
	if had_save:
		var f2 := FileAccess.open(SAVE, FileAccess.WRITE)
		f2.store_buffer(save_bytes)
		f2.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	G.free()
	quit(0)


func _stone_rows() -> int:
	# ряды камня: в них не больше двух дыр (висячие блоки над камнем не считаются)
	var n := 0
	for y in ROWS:
		var k := 0
		for x in COLS:
			if G.board[y * COLS + x] == G.STONE or G.board[y * COLS + x] == CRYSTAL:
				k += 1
		if k >= COLS - 2:
			n += 1
	return n


# Одна партия. Возвращает итог.
func _play(max_pieces: int) -> Dictionary:
	var res := {"win": false, "pieces": 0, "stars": 0, "clears": 0, "chain_sum": 0, "cascades": 0, "max_chain": 0}
	while G.state == G.State.PLAYING and G.has_piece and G.pieces_used < max_pieces:
		var best := _choose()
		if best.is_empty():
			G.hard_drop()
		else:
			_execute(best)
		var guard := 0
		while (G.state == G.State.CLEARING or G.state == G.State.SETTLE) and guard < 1000:
			G.step(0.05)
			guard += 1
		if G.chain > 0:
			res.clears += 1
			res.chain_sum += G.chain
			if G.chain >= 2:
				res.cascades += 1
			res.max_chain = maxi(res.max_chain, G.chain)
	res.pieces = G.pieces_used
	if G.state == G.State.WIN:
		res.win = true
		res.stars = G.last_stars
	return res


func _rotations(t: int) -> Array:
	var out: Array = []
	var cells: Array = G.SHAPES[t].cells.duplicate()
	var n: int = G.SHAPES[t].box
	var count := 1 if n == 0 else 4
	for r in count:
		out.append(cells)
		var rot: Array = []
		for c in cells:
			rot.append(Vector2i(n - 1 - c.y, c.x))
		cells = rot
	return out


func _fits(b: PackedInt32Array, cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var x: int = c.x + pos.x
		var y: int = c.y + pos.y
		if x < 0 or x >= COLS or y >= ROWS:
			return false
		if y >= 0 and b[y * COLS + x] != EMPTY:
			return false
	return true


# Все конечные положения фигуры: [{rot, x, board, ids, crystals, lines, chain, top_out}]
func _placements(b: PackedInt32Array, ids: PackedInt32Array, t: int, start_y: int, new_id: int) -> Array:
	var out: Array = []
	var seen := {}
	var rots := _rotations(t)
	for r in rots.size():
		var cells: Array = rots[r]
		for ox in range(-3, COLS + 1):
			var p := Vector2i(ox, start_y)
			if not _fits(b, cells, p):
				continue
			while _fits(b, cells, p + Vector2i(0, 1)):
				p.y += 1
			var finals: Array = [[p, p]]
			if tuck:
				# «подсунуть» фигуру: опустить до упора и сдвинуть вбок на 1–3 клетки
				# (под островок камня или под нависание), затем уронить дальше
				for dir in [-1, 1]:
					var q := p
					for st in 3:
						if not _fits(b, cells, q + Vector2i(dir, 0)):
							break
						q.x += dir
						var f := q
						while _fits(b, cells, f + Vector2i(0, 1)):
							f.y += 1
						finals.append([f, Vector2i(q.x, p.y)])
			for fin in finals:
				var key := "%d,%d,%d" % [r, fin[0].x, fin[0].y]
				if seen.has(key):
					continue
				seen[key] = true
				out.append(_make(b, ids, t, cells, r, ox, fin[0], fin[1], p.y, new_id))
	return out


func _make(b: PackedInt32Array, ids: PackedInt32Array, t: int, cells: Array, r: int, ox: int, p: Vector2i, slide: Vector2i, rest_y: int, new_id: int) -> Dictionary:
	var nb := b.duplicate()
	var nids := ids.duplicate()
	var top_out := false
	for c in cells:
		var y: int = c.y + p.y
		if y < 0:
			top_out = true
		else:
			nb[y * COLS + c.x + p.x] = t
			nids[y * COLS + c.x + p.x] = new_id
	var sim := _resolve(nb, nids)
	return {"rot": r, "x": ox, "tx": slide.x, "ty": rest_y, "board": nb, "ids": nids, "crystals": sim.crystals, "lines": sim.lines,
		"chain": sim.chain, "top_out": top_out}


# Очистка линий с каскадом, как в игре («липкая» гравитация из scripts/gravity.gd).
# Меняет доску и номера фигур на месте.
func _resolve(b: PackedInt32Array, ids: PackedInt32Array) -> Dictionary:
	return Gravity.resolve(b, ids, COLS, ROWS, EMPTY, [G.STONE, CRYSTAL], CRYSTAL, G.FALL_ALL)


func _features(b: PackedInt32Array) -> float:
	var holes := 0
	var agg := 0
	var bump := 0
	var top_pen := 0
	var prev_h := -1
	for x in COLS:
		var h := 0
		var seen := false
		for y in ROWS:
			var v: int = b[y * COLS + x]
			if v != EMPTY:
				if not seen:
					seen = true
					h = ROWS - y
			elif seen:
				holes += 1
		agg += h
		top_pen += maxi(0, h - SAFE_H)
		if prev_h >= 0:
			bump += absi(h - prev_h)
		prev_h = h
	var crow := 0
	for y in ROWS:
		var has_c := false
		var filled := 0
		for x in COLS:
			var v: int = b[y * COLS + x]
			if v == CRYSTAL:
				has_c = true
			if v != EMPTY:
				filled += 1
		if has_c:
			crow += filled * filled
	return -W_HOLE * holes - W_HEIGHT * agg - W_BUMP * bump - W_TOP * top_pen * top_pen + W_CROW * crow


func _score(p: Dictionary) -> float:
	if p.top_out:
		return -1e9
	return W_CRYSTAL * p.crystals + W_LINE * p.lines + _features(p.board)


func _choose() -> Dictionary:
	var b := PackedInt32Array(G.board)
	var ids := PackedInt32Array(G.piece_ids)
	var cands := _placements(b, ids, G.piece_type, G.piece_pos.y, SIM_ID)
	var best := {}
	var best_s := -INF
	for p in cands:
		var s := _score(p)
		if look and s > -1e8 and G.crystals_left - p.crystals > 0:
			var nexts := _placements(p.board, p.ids, G.next_type, 0, SIM_ID + 1)
			var bn := -1e9
			for q in nexts:
				bn = maxf(bn, _score(q))
			s = W_CRYSTAL * p.crystals + W_LINE * p.lines + bn
		elif G.crystals_left - p.crystals <= 0:
			s += 1e6
		if s > best_s:
			best_s = s
			best = p
	return best


func _execute(p: Dictionary) -> void:
	for i in p.rot:
		G.rotate_piece()
	var guard := 0
	while G.piece_pos.x != p.x and guard < 20:
		if not G.move(1 if p.x > G.piece_pos.x else -1):
			break
		guard += 1
	if G.piece_pos.x != p.x:
		mismatches += 1
	if p.tx != p.x:
		while G.piece_pos.y < p.ty and G.soft_drop():
			pass
		guard = 0
		while G.piece_pos.x != p.tx and guard < 10:
			if not G.move(1 if p.tx > G.piece_pos.x else -1):
				break
			guard += 1
		if G.piece_pos.x != p.tx:
			mismatches += 1
	G.hard_drop()


func _seed_search(l_from: int, l_to: int, games: int, base_seed: int, max_pieces: int, k_count: int, csv: String, k0 := 0) -> void:
	var out: Array = ["level,k,seed,win_pct,median,p40,avg_win,cascade_pct,cascade_games_pct,chain3_games_pct,max_chain"]
	for n in range(l_from, l_to + 1):
		for k in range(k0, k0 + k_count):
			var sd := n * 7919 + 13 + k * 104729
			G.level_override = set_fields.duplicate()
			G.level_override["seed"] = sd
			var plist: Array = []
			var wins := 0
			var clears := 0
			var cascades := 0
			var cg := 0
			var c3g := 0
			var mc := 0
			for gi in games:
				seed(base_seed * 100003 + n * 1009 + gi)
				G.start_level(n)
				var r := _play(max_pieces)
				clears += r.clears
				cascades += r.cascades
				if r.max_chain >= 2:
					cg += 1
				if r.max_chain >= 3:
					c3g += 1
				mc = maxi(mc, r.max_chain)
				if r.win:
					wins += 1
					plist.append(r.pieces)
			plist.sort()
			var med: int = plist[plist.size() / 2] if plist.size() > 0 else 999
			var p40: int = plist[int(plist.size() * 0.4)] if plist.size() > 0 else 999
			var avg := 0.0
			for v in plist:
				avg += v
			avg /= maxi(plist.size(), 1)
			var line := "%d,%d,%d,%.1f,%d,%d,%.2f,%.1f,%.1f,%.1f,%d" % [n, k, sd, 100.0 * wins / games, med, p40, avg,
				100.0 * cascades / maxi(clears, 1), 100.0 * cg / games, 100.0 * c3g / games, mc]
			print(line)
			out.append(line)
	G.level_override = {}
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		f.store_string("\n".join(out) + "\n")
		f.close()
