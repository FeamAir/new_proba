extends RefCounted
## Мета-слой Cascado (версия 0.6; щенок и котик — 0.9; редкости, наборы, кузница — 0.12):
## герой, осколки, гардероб, залы карты.
## Только данные и правила, без рисования (рисование — scripts/hero.gd и scripts/screens.gd).
## Сохраняется в тот же user://save.cfg, раздел [meta]; старые сохранения без него
## загружаются со значениями по умолчанию.

const I18n := preload("res://scripts/i18n.gd")

const HEROES := ["owl", "axolotl", "puppy", "kitten"]

## 0.12: спутник (маленький друг летает рядом) и сияние (эффект позади/вокруг героя)
const SLOTS := ["head", "eyes", "neck", "back", "skin", "companion", "aura"]

## 0.12: редкости вещей (от простой к самой ценной). Цвета рамок и эффекты — scripts/rarity.gd.
const RARITIES := ["common", "rare", "epic", "legendary", "super"]

## 0.12b: ГАРДЕРОБ ПО ГЕРОЯМ. Общих вещей нет: у каждого героя свой каталог из 19 вещей —
## 3 тематических набора по 5 покупаемых вещей, 3 легендарные награды кузницы (по одной за набор)
## и супер-эксклюзив (из трёх легендарных). Вещь надевается только на своего героя.
## Поля: hero — чей; slot; price — цена в осколках; rarity — RARITIES; set — id набора (SETS);
## hall — после какого зала открыта (0 — с начала); forge — награда кузницы (не продаётся);
## draw — общий рисунок/палитра (вещь нарисована раньше, но теперь только у этого героя);
## covers — у супер-эксклюзива: какие слоты он занимает целиком (их вещи снимаются).
## Названия — scripts/i18n.gd, ключи item_<id>; рисунки — scripts/wardrobe_*.gd.
const ITEMS := [
	# ---------- Совёнок: учёный и ночной волшебник ----------
	{"id": "ow_mortarboard", "hero": "owl", "slot": "head", "price": 20, "rarity": "common", "set": "owl_library", "hall": 0},
	{"id": "ow_halfglasses", "hero": "owl", "slot": "eyes", "price": 30, "rarity": "common", "set": "owl_library", "hall": 0},
	{"id": "ow_scholar_scarf", "hero": "owl", "slot": "neck", "price": 50, "rarity": "rare", "set": "owl_library", "hall": 0},
	{"id": "ow_book", "hero": "owl", "slot": "companion", "price": 70, "rarity": "rare", "set": "owl_library", "hall": 0},
	{"id": "ow_skin_snowy", "hero": "owl", "slot": "skin", "price": 120, "rarity": "epic", "set": "owl_library", "hall": 0},
	{"id": "ow_quill", "hero": "owl", "slot": "head", "price": 45, "rarity": "common", "set": "owl_night", "hall": 3},
	{"id": "ow_star_scarf", "hero": "owl", "slot": "neck", "price": 60, "rarity": "common", "set": "owl_night", "hall": 3, "draw": "comet_scarf"},
	{"id": "ow_lantern", "hero": "owl", "slot": "back", "price": 85, "rarity": "rare", "set": "owl_night", "hall": 3},
	{"id": "ow_moth", "hero": "owl", "slot": "companion", "price": 110, "rarity": "rare", "set": "owl_night", "hall": 3, "draw": "moon_moth"},
	{"id": "ow_night_goggles", "hero": "owl", "slot": "eyes", "price": 160, "rarity": "epic", "set": "owl_night", "hall": 3},
	{"id": "ow_astrolabe", "hero": "owl", "slot": "neck", "price": 65, "rarity": "common", "set": "owl_observatory", "hall": 5, "draw": "star_compass"},
	{"id": "ow_lorgnette", "hero": "owl", "slot": "eyes", "price": 85, "rarity": "common", "set": "owl_observatory", "hall": 5, "draw": "star_lorgnette"},
	{"id": "ow_dome_hat", "hero": "owl", "slot": "head", "price": 115, "rarity": "rare", "set": "owl_observatory", "hall": 5},
	{"id": "ow_planet", "hero": "owl", "slot": "companion", "price": 150, "rarity": "rare", "set": "owl_observatory", "hall": 5, "draw": "mini_planet"},
	{"id": "ow_aura_starfall", "hero": "owl", "slot": "aura", "price": 230, "rarity": "epic", "set": "owl_observatory", "hall": 5, "draw": "aura_starfall"},
	{"id": "ow_page_whirl", "hero": "owl", "slot": "aura", "rarity": "legendary", "set": "owl_library", "hall": 0, "forge": true},
	{"id": "ow_skin_starry", "hero": "owl", "slot": "skin", "rarity": "legendary", "set": "owl_night", "hall": 3, "forge": true, "draw": "skin_constellation"},
	{"id": "ow_comet", "hero": "owl", "slot": "companion", "rarity": "legendary", "set": "owl_observatory", "hall": 5, "forge": true},
	{"id": "ow_stargazer", "hero": "owl", "slot": "aura", "rarity": "super", "hall": 5, "forge": true, "covers": ["head", "back"]},
	# ---------- Аксолотль: житель глубин ----------
	{"id": "ax_starfish", "hero": "axolotl", "slot": "head", "price": 20, "rarity": "common", "set": "axo_reef", "hall": 0},
	{"id": "ax_dive_mask", "hero": "axolotl", "slot": "eyes", "price": 30, "rarity": "common", "set": "axo_reef", "hall": 0, "draw": "dive_mask"},
	{"id": "ax_coral_beads", "hero": "axolotl", "slot": "neck", "price": 50, "rarity": "rare", "set": "axo_reef", "hall": 0},
	{"id": "ax_bubble_pet", "hero": "axolotl", "slot": "companion", "price": 70, "rarity": "rare", "set": "axo_reef", "hall": 0, "draw": "bubble_pet"},
	{"id": "ax_coral_tiara", "hero": "axolotl", "slot": "head", "price": 120, "rarity": "epic", "set": "axo_reef", "hall": 0, "draw": "coral_tiara"},
	{"id": "ax_gill_pearls", "hero": "axolotl", "slot": "head", "price": 45, "rarity": "common", "set": "axo_lagoon", "hall": 3},
	{"id": "ax_pearls", "hero": "axolotl", "slot": "neck", "price": 60, "rarity": "common", "set": "axo_lagoon", "hall": 3, "draw": "pearl_necklace"},
	{"id": "ax_shell_pack", "hero": "axolotl", "slot": "back", "price": 85, "rarity": "rare", "set": "axo_lagoon", "hall": 3},
	{"id": "ax_aura_bubbles", "hero": "axolotl", "slot": "aura", "price": 110, "rarity": "rare", "set": "axo_lagoon", "hall": 3, "draw": "aura_bubbles"},
	{"id": "ax_skin_pearl", "hero": "axolotl", "slot": "skin", "price": 160, "rarity": "epic", "set": "axo_lagoon", "hall": 3, "draw": "skin_pearl"},
	{"id": "ax_black_pearl", "hero": "axolotl", "slot": "neck", "price": 65, "rarity": "common", "set": "axo_abyss", "hall": 5},
	{"id": "ax_porthole", "hero": "axolotl", "slot": "eyes", "price": 85, "rarity": "common", "set": "axo_abyss", "hall": 5},
	{"id": "ax_angler", "hero": "axolotl", "slot": "head", "price": 115, "rarity": "rare", "set": "axo_abyss", "hall": 5},
	{"id": "ax_squid", "hero": "axolotl", "slot": "companion", "price": 150, "rarity": "rare", "set": "axo_abyss", "hall": 5},
	{"id": "ax_skin_abyss", "hero": "axolotl", "slot": "skin", "price": 230, "rarity": "epic", "set": "axo_abyss", "hall": 5, "draw": "skin_midnight"},
	{"id": "ax_seahorse", "hero": "axolotl", "slot": "companion", "rarity": "legendary", "set": "axo_reef", "hall": 0, "forge": true, "draw": "seahorse"},
	{"id": "ax_wave_cape", "hero": "axolotl", "slot": "back", "rarity": "legendary", "set": "axo_lagoon", "hall": 3, "forge": true, "draw": "fin_cape"},
	{"id": "ax_plankton", "hero": "axolotl", "slot": "aura", "rarity": "legendary", "set": "axo_abyss", "hall": 5, "forge": true},
	{"id": "ax_abyssal", "hero": "axolotl", "slot": "aura", "rarity": "super", "hall": 5, "forge": true, "covers": ["head"]},
	# ---------- Щенок: весёлый спортсмен (0.13: спорт, цветочный пикник, супергерой) ----------
	{"id": "pu_cap", "hero": "puppy", "slot": "head", "price": 20, "rarity": "common", "set": "pup_playground", "hall": 0},
	{"id": "pu_whistle", "hero": "puppy", "slot": "neck", "price": 30, "rarity": "common", "set": "pup_playground", "hall": 0},
	{"id": "pu_visor", "hero": "puppy", "slot": "eyes", "price": 50, "rarity": "rare", "set": "pup_playground", "hall": 0},
	{"id": "pu_ball", "hero": "puppy", "slot": "companion", "price": 70, "rarity": "rare", "set": "pup_playground", "hall": 0},
	{"id": "pu_skin_corgi", "hero": "puppy", "slot": "skin", "price": 120, "rarity": "epic", "set": "pup_playground", "hall": 0, "draw": "skin_moon"},
	# 0.13: «Цветочный пикник» вместо «Похода» (милый набор; вещи похода возвращены осколками)
	{"id": "pu_daisy_wreath", "hero": "puppy", "slot": "head", "price": 45, "rarity": "common", "set": "pup_picnic", "hall": 3},
	{"id": "pu_flower_scarf", "hero": "puppy", "slot": "neck", "price": 60, "rarity": "common", "set": "pup_picnic", "hall": 3},
	{"id": "pu_daisy_specs", "hero": "puppy", "slot": "eyes", "price": 85, "rarity": "rare", "set": "pup_picnic", "hall": 3},
	{"id": "pu_basket", "hero": "puppy", "slot": "companion", "price": 110, "rarity": "rare", "set": "pup_picnic", "hall": 3},
	{"id": "pu_skin_cotton", "hero": "puppy", "slot": "skin", "price": 160, "rarity": "epic", "set": "pup_picnic", "hall": 3},
	{"id": "pu_bolt_band", "hero": "puppy", "slot": "head", "price": 65, "rarity": "common", "set": "pup_hero", "hall": 5},
	{"id": "pu_hero_bandana", "hero": "puppy", "slot": "neck", "price": 85, "rarity": "common", "set": "pup_hero", "hall": 5},
	{"id": "pu_jetpack", "hero": "puppy", "slot": "back", "price": 115, "rarity": "rare", "set": "pup_hero", "hall": 5, "draw": "rocket_pack"},
	{"id": "pu_robo", "hero": "puppy", "slot": "companion", "price": 150, "rarity": "rare", "set": "pup_hero", "hall": 5},
	{"id": "pu_skin_dalmatian", "hero": "puppy", "slot": "skin", "price": 230, "rarity": "epic", "set": "pup_hero", "hall": 5, "draw": "skin_gold"},
	{"id": "pu_frisbee", "hero": "puppy", "slot": "companion", "rarity": "legendary", "set": "pup_playground", "hall": 0, "forge": true},
	{"id": "pu_petal_rainbow", "hero": "puppy", "slot": "aura", "rarity": "legendary", "set": "pup_picnic", "hall": 3, "forge": true},
	{"id": "pu_aura_bolts", "hero": "puppy", "slot": "aura", "rarity": "legendary", "set": "pup_hero", "hall": 5, "forge": true},
	{"id": "pu_hero", "hero": "puppy", "slot": "aura", "rarity": "super", "hall": 5, "forge": true, "covers": ["back", "eyes", "neck"]},
	# ---------- Котик: уютный модник (0.13: уют, кот-детектив, бал-маскарад) ----------
	{"id": "ki_pompom_hat", "hero": "kitten", "slot": "head", "price": 20, "rarity": "common", "set": "kit_cozy", "hall": 0},
	{"id": "ki_bell_bow", "hero": "kitten", "slot": "neck", "price": 30, "rarity": "common", "set": "kit_cozy", "hall": 0},
	{"id": "ki_yarn", "hero": "kitten", "slot": "companion", "price": 50, "rarity": "rare", "set": "kit_cozy", "hall": 0},
	{"id": "ki_sweater", "hero": "kitten", "slot": "back", "price": 70, "rarity": "rare", "set": "kit_cozy", "hall": 0},
	{"id": "ki_skin_tabby", "hero": "kitten", "slot": "skin", "price": 120, "rarity": "epic", "set": "kit_cozy", "hall": 0, "draw": "skin_mint"},
	# 0.13: «Кот-детектив» вместо «Парижского шика» (крутой набор; вещи шика возвращены осколками)
	{"id": "ki_sleuth_hat", "hero": "kitten", "slot": "head", "price": 45, "rarity": "common", "set": "kit_detective", "hall": 3},
	{"id": "ki_moustache", "hero": "kitten", "slot": "eyes", "price": 60, "rarity": "common", "set": "kit_detective", "hall": 3},
	{"id": "ki_sleuth_badge", "hero": "kitten", "slot": "neck", "price": 85, "rarity": "rare", "set": "kit_detective", "hall": 3},
	{"id": "ki_trench", "hero": "kitten", "slot": "back", "price": 110, "rarity": "rare", "set": "kit_detective", "hall": 3},
	{"id": "ki_magnifier", "hero": "kitten", "slot": "companion", "price": 160, "rarity": "epic", "set": "kit_detective", "hall": 3},
	{"id": "ki_masquerade", "hero": "kitten", "slot": "eyes", "price": 65, "rarity": "common", "set": "kit_ball", "hall": 5, "draw": "masquerade"},
	{"id": "ki_cameo", "hero": "kitten", "slot": "neck", "price": 85, "rarity": "common", "set": "kit_ball", "hall": 5},
	{"id": "ki_feather_hat", "hero": "kitten", "slot": "head", "price": 115, "rarity": "rare", "set": "kit_ball", "hall": 5},
	{"id": "ki_ball_cloak", "hero": "kitten", "slot": "back", "price": 150, "rarity": "rare", "set": "kit_ball", "hall": 5, "draw": "ball_cloak"},
	{"id": "ki_skin_siamese", "hero": "kitten", "slot": "skin", "price": 230, "rarity": "epic", "set": "kit_ball", "hall": 5, "draw": "skin_moon"},
	{"id": "ki_teacup", "hero": "kitten", "slot": "companion", "rarity": "legendary", "set": "kit_cozy", "hall": 0, "forge": true},
	{"id": "ki_clue_trail", "hero": "kitten", "slot": "aura", "rarity": "legendary", "set": "kit_detective", "hall": 3, "forge": true},
	{"id": "ki_aura_fireworks", "hero": "kitten", "slot": "aura", "rarity": "legendary", "set": "kit_ball", "hall": 5, "forge": true},
	{"id": "ki_starry", "hero": "kitten", "slot": "aura", "rarity": "super", "hall": 5, "forge": true, "covers": ["head"]},
]

## Наборы героев (названия — i18n set_<id>): n — номер набора у героя (1..3), hall — после какого
## зала открыт (0 — с начала), col — цвет значка, icon — рисунок значка (screens.gd, set_badge).
const SETS := [
	{"id": "owl_library", "hero": "owl", "n": 1, "hall": 0, "col": Color("#FFCB6B"), "icon": "book"},
	{"id": "owl_night", "hero": "owl", "n": 2, "hall": 3, "col": Color("#9FB4FF"), "icon": "moon"},
	{"id": "owl_observatory", "hero": "owl", "n": 3, "hall": 5, "col": Color("#C08BFF"), "icon": "planet"},
	{"id": "axo_reef", "hero": "axolotl", "n": 1, "hall": 0, "col": Color("#FF8A6B"), "icon": "star"},
	{"id": "axo_lagoon", "hero": "axolotl", "n": 2, "hall": 3, "col": Color("#FFC2E4"), "icon": "pearl"},
	{"id": "axo_abyss", "hero": "axolotl", "n": 3, "hall": 5, "col": Color("#3FE0D0"), "icon": "drop"},
	{"id": "pup_playground", "hero": "puppy", "n": 1, "hall": 0, "col": Color("#FFB547"), "icon": "ball"},
	{"id": "pup_picnic", "hero": "puppy", "n": 2, "hall": 3, "col": Color("#8FE3A0"), "icon": "daisy"},
	{"id": "pup_hero", "hero": "puppy", "n": 3, "hall": 5, "col": Color("#FF5F6D"), "icon": "bolt"},
	{"id": "kit_cozy", "hero": "kitten", "n": 1, "hall": 0, "col": Color("#FF9FC0"), "icon": "yarn"},
	{"id": "kit_detective", "hero": "kitten", "n": 2, "hall": 3, "col": Color("#D9A86A"), "icon": "glass"},
	{"id": "kit_ball", "hero": "kitten", "n": 3, "hall": 5, "col": Color("#B9A4FF"), "icon": "mask"},
]

## Рецепты кузницы: needs — вещи (не тратятся, остаются у игрока), cost — осколки, hall — нужно
## пройти зал. Награда набора — из всех 5 его вещей; супер-эксклюзив героя (set "") — из трёх легендарных.
const RECIPES := [
	{"id": "ow_page_whirl", "hero": "owl", "set": "owl_library", "hall": 0, "cost": 120, "needs": ["ow_mortarboard", "ow_halfglasses", "ow_scholar_scarf", "ow_book", "ow_skin_snowy"]},
	{"id": "ow_skin_starry", "hero": "owl", "set": "owl_night", "hall": 3, "cost": 180, "needs": ["ow_quill", "ow_star_scarf", "ow_lantern", "ow_moth", "ow_night_goggles"]},
	{"id": "ow_comet", "hero": "owl", "set": "owl_observatory", "hall": 5, "cost": 250, "needs": ["ow_astrolabe", "ow_lorgnette", "ow_dome_hat", "ow_planet", "ow_aura_starfall"]},
	{"id": "ow_stargazer", "hero": "owl", "set": "", "hall": 5, "cost": 450, "needs": ["ow_page_whirl", "ow_skin_starry", "ow_comet"]},
	{"id": "ax_seahorse", "hero": "axolotl", "set": "axo_reef", "hall": 0, "cost": 120, "needs": ["ax_starfish", "ax_dive_mask", "ax_coral_beads", "ax_bubble_pet", "ax_coral_tiara"]},
	{"id": "ax_wave_cape", "hero": "axolotl", "set": "axo_lagoon", "hall": 3, "cost": 180, "needs": ["ax_gill_pearls", "ax_pearls", "ax_shell_pack", "ax_aura_bubbles", "ax_skin_pearl"]},
	{"id": "ax_plankton", "hero": "axolotl", "set": "axo_abyss", "hall": 5, "cost": 250, "needs": ["ax_black_pearl", "ax_porthole", "ax_angler", "ax_squid", "ax_skin_abyss"]},
	{"id": "ax_abyssal", "hero": "axolotl", "set": "", "hall": 5, "cost": 450, "needs": ["ax_seahorse", "ax_wave_cape", "ax_plankton"]},
	{"id": "pu_frisbee", "hero": "puppy", "set": "pup_playground", "hall": 0, "cost": 120, "needs": ["pu_cap", "pu_whistle", "pu_visor", "pu_ball", "pu_skin_corgi"]},
	{"id": "pu_petal_rainbow", "hero": "puppy", "set": "pup_picnic", "hall": 3, "cost": 180, "needs": ["pu_daisy_wreath", "pu_flower_scarf", "pu_daisy_specs", "pu_basket", "pu_skin_cotton"]},
	{"id": "pu_aura_bolts", "hero": "puppy", "set": "pup_hero", "hall": 5, "cost": 250, "needs": ["pu_bolt_band", "pu_hero_bandana", "pu_jetpack", "pu_robo", "pu_skin_dalmatian"]},
	{"id": "pu_hero", "hero": "puppy", "set": "", "hall": 5, "cost": 450, "needs": ["pu_frisbee", "pu_petal_rainbow", "pu_aura_bolts"]},
	{"id": "ki_teacup", "hero": "kitten", "set": "kit_cozy", "hall": 0, "cost": 120, "needs": ["ki_pompom_hat", "ki_bell_bow", "ki_yarn", "ki_sweater", "ki_skin_tabby"]},
	{"id": "ki_clue_trail", "hero": "kitten", "set": "kit_detective", "hall": 3, "cost": 180, "needs": ["ki_sleuth_hat", "ki_moustache", "ki_sleuth_badge", "ki_trench", "ki_magnifier"]},
	{"id": "ki_aura_fireworks", "hero": "kitten", "set": "kit_ball", "hall": 5, "cost": 250, "needs": ["ki_masquerade", "ki_cameo", "ki_feather_hat", "ki_ball_cloak", "ki_skin_siamese"]},
	{"id": "ki_starry", "hero": "kitten", "set": "", "hall": 5, "cost": 450, "needs": ["ki_teacup", "ki_clue_trail", "ki_aura_fireworks"]},
]
## 0.12: доход за глубокие залы — +2 осколка к первой победе за каждый зал глубже первого
const HALL_BONUS := 2

## 0.12b: цены старых общих вещей (версии 0.6–0.12) и плата за ковку старых наград — по ним
## при загрузке старого сохранения возвращаются осколки (вещей больше нет).
const LEGACY_PRICES := {
	"bow": 20, "cap": 30, "miner": 60, "wreath": 80, "crown": 150, "sunglasses": 40, "crystal_glasses": 50,
	"monocle": 70, "bowtie": 30, "scarf": 35, "necklace": 90, "backpack": 45, "cape": 120,
	"skin_mint": 60, "skin_moon": 80, "skin_gold": 200,
	"acorn_cap": 30, "leaf_scarf": 35, "daisy_glasses": 70, "firefly": 80, "dragonfly_wings": 90, "skin_moss": 150,
	"bluebell_hat": 160, "aura_pollen": 180, "shell_clip": 40, "dive_mask": 45, "pearl_necklace": 90, "bubble_pet": 90,
	"fin_cape": 100, "skin_pearl": 180, "coral_tiara": 180, "aura_bubbles": 200, "moth_tie": 40, "masquerade": 45,
	"top_hat": 100, "moon_moth": 100, "ball_cloak": 110, "star_lorgnette": 180, "skin_midnight": 200, "aura_moonbeam": 220,
	"flight_goggles": 50, "comet_scarf": 50, "mini_planet": 110, "space_helmet": 120, "rocket_pack": 120,
	"star_compass": 200, "skin_nebula": 220, "aura_starfall": 240, "amethyst_monocle": 60, "ermine_collar": 60,
	"float_crystal": 130, "crystal_diadem": 130, "royal_mantle": 140, "skin_amethyst": 240, "aura_facets": 260,
}
const LEGACY_FORGE := {"firefly_crown": 50, "seahorse": 80, "fullmoon_mantle": 100, "skin_constellation": 140,
	"mountain_heart": 180, "wings_cascado": 300}

## 0.13: вещи заменённых наборов («Парижский шик» котика, «Поход» щенка) и плата за ковку их наград —
## при загрузке сохранения возвращаются осколками (один раз — сообщение «Гардероб обновлён», новые наборы).
const REPLACED_013 := {"ki_beret": 45, "ki_heart_glasses": 60, "ki_lace_collar": 85, "ki_tail_bow": 110, "ki_aura_petals": 160,
	"pu_explorer_hat": 45, "pu_bone_collar": 60, "pu_aviators": 85, "pu_firefly": 110, "pu_backpack": 160}
const REPLACED_013_FORGE := {"ki_parasol": 180, "pu_kite": 180}

## 0.13: мальчик или девочка (у каждого героя — свой выбор; по умолчанию мальчик) и имя героя.
const GENDERS := ["boy", "girl"]
## Имя: до 12 знаков, только буквы (любой алфавит), цифры, пробел и дефис.
const NAME_MAX := 12

## Украшения дома: у каждого героя свой дом и свой набор. spots — куда можно поставить:
## floor (пол слева/справа), wall (стена или ветка слева/справа), hang (подвес сверху;
## у котика — верхняя полка), near (рядом с героем).
const SPOTS := ["floor_l", "floor_r", "wall_l", "wall_r", "hang", "near"]
const DECOR := [
	{"id": "owl_nest", "home": "owl", "price": 10, "spots": ["near", "floor"]},
	{"id": "owl_lantern", "home": "owl", "price": 15, "spots": ["hang", "wall", "near"]},
	{"id": "owl_garland", "home": "owl", "price": 20, "spots": ["hang"]},
	{"id": "owl_mushrooms", "home": "owl", "price": 20, "spots": ["floor"]},
	{"id": "owl_birdhouse", "home": "owl", "price": 25, "spots": ["wall"]},
	{"id": "owl_books", "home": "owl", "price": 30, "spots": ["wall", "near"]},
	{"id": "owl_swing", "home": "owl", "price": 30, "spots": ["hang"]},
	{"id": "owl_hammock", "home": "owl", "price": 35, "spots": ["wall", "floor"]},
	{"id": "owl_moon", "home": "owl", "price": 40, "spots": ["hang"], "stars": 25},
	{"id": "owl_nightlight", "home": "owl", "price": 50, "spots": ["floor", "near"], "hall": 1},
	{"id": "axo_starfish", "home": "axolotl", "price": 10, "spots": ["wall"]},
	{"id": "axo_coral", "home": "axolotl", "price": 15, "spots": ["wall", "floor"]},
	{"id": "axo_anchor", "home": "axolotl", "price": 20, "spots": ["floor", "wall"]},
	{"id": "axo_shell", "home": "axolotl", "price": 25, "spots": ["floor", "near"]},
	{"id": "axo_lily", "home": "axolotl", "price": 25, "spots": ["hang"]},
	{"id": "axo_bubble", "home": "axolotl", "price": 30, "spots": ["hang", "near"]},
	{"id": "axo_tree", "home": "axolotl", "price": 35, "spots": ["floor"]},
	{"id": "axo_sofa", "home": "axolotl", "price": 40, "spots": ["near"]},
	{"id": "axo_castle", "home": "axolotl", "price": 50, "spots": ["floor"], "hall": 2},
	{"id": "axo_chest", "home": "axolotl", "price": 60, "spots": ["floor", "near"], "stars": 40},
	{"id": "pup_ball", "home": "puppy", "price": 10, "spots": ["floor", "near"]},
	{"id": "pup_bone", "home": "puppy", "price": 15, "spots": ["near"]},
	{"id": "pup_bowl", "home": "puppy", "price": 20, "spots": ["near", "floor"]},
	{"id": "pup_sign", "home": "puppy", "price": 20, "spots": ["wall"]},
	{"id": "pup_flowerbed", "home": "puppy", "price": 25, "spots": ["floor"]},
	{"id": "pup_pinwheel", "home": "puppy", "price": 30, "spots": ["wall", "floor"]},
	{"id": "pup_lamp", "home": "puppy", "price": 35, "spots": ["hang", "wall", "floor"]},
	{"id": "pup_bed", "home": "puppy", "price": 45, "spots": ["near"]},
	{"id": "pup_kite", "home": "puppy", "price": 50, "spots": ["hang"], "stars": 25},
	{"id": "pup_teddy", "home": "puppy", "price": 60, "spots": ["near", "floor"], "hall": 1},
	{"id": "kit_yarn", "home": "kitten", "price": 10, "spots": ["floor", "near"]},
	{"id": "kit_mouse", "home": "kitten", "price": 15, "spots": ["near"]},
	{"id": "kit_pillow", "home": "kitten", "price": 20, "spots": ["near"]},
	{"id": "kit_picture", "home": "kitten", "price": 20, "spots": ["wall"]},
	{"id": "kit_catnip", "home": "kitten", "price": 25, "spots": ["hang", "wall", "floor"]},
	{"id": "kit_box", "home": "kitten", "price": 30, "spots": ["floor", "near"]},
	{"id": "kit_scratcher", "home": "kitten", "price": 35, "spots": ["floor"]},
	{"id": "kit_lamp", "home": "kitten", "price": 40, "spots": ["floor"]},
	{"id": "kit_aquarium", "home": "kitten", "price": 50, "spots": ["hang", "wall", "near"], "stars": 30},
	{"id": "kit_tree", "home": "kitten", "price": 60, "spots": ["floor"], "hall": 2},
]

# Начисление осколков за победу
const WIN_FIRST := 10
const WIN_REPEAT := 3
const PER_NEW_STAR := 5
const PER_BIG_CHAIN := 3     # за каждую цепочку ×3 и выше в партии
const CHAIN_CAP := 12        # не больше 12 за цепочки

# Залы: по 10 уровней, 10 залов (100 уровней таблицы scripts/levels.gd). После 100-го —
# «Бесконечные глубины» (последняя строка HALLS), нумерация продолжается.
# Названия — scripts/i18n.gd, ключи hall_0 ... hall_10.
const HALL_SIZE := 10
const HALLS := [
	{"col": Color("#B46CFF")},  # 1 Аметистовый зал
	{"col": Color("#3DDC97")},  # 2 Изумрудный зал
	{"col": Color("#FF7A3D")},  # 3 Огненный зал
	{"col": Color("#7FE3FF")},  # 4 Ледяной зал
	{"col": Color("#FF4D6D")},  # 5 Сердце горы
	{"col": Color("#4D7CFF")},  # 6 Сапфировый грот
	{"col": Color("#FFB547")},  # 7 Янтарные копи
	{"col": Color("#D8E2FF")},  # 8 Лунное озеро
	{"col": Color("#C6F04A")},  # 9 Гнездо светлячков
	{"col": Color("#FF8AD8")},  # 10 Корона кристаллов
	{"col": Color("#9C8FD6")},  # Бесконечные глубины
]
## Залов с уровнями таблицы (без «Бесконечных глубин»).
const HALL_COUNT := 10
## Последний уровень таблицы; дальше — «Бесконечные глубины».
const LAST_LEVEL := HALL_COUNT * HALL_SIZE
## Ступени богатства дома: сколько залов надо пройти для ступени 1, 2, 3.
const HOME_STAGE_HALLS := [1, 3, 6]
const METERS_PER_LEVEL := 12

enum Buy { OK, OWNED, LOCKED, POOR, UNKNOWN }

var hero := ""               # "" — ещё не выбран (первый запуск)
var shards := 0
var owned: Array = []        # id купленных вещей
var equipped: Dictionary = {}  # слот -> id
var decor_owned: Array = []    # id купленных украшений (свои для каждого дома)
var decor_placed: Dictionary = {"owl": {}, "axolotl": {}, "puppy": {}, "kitten": {}}  # дом -> {место -> id}
var forged: Array = []         # 0.12: id скованных в кузнице вещей
## 0.12b: осколки, вернувшиеся при обновлении старого сохранения (общие вещи убраны);
## пока не 0 — один раз показывается сообщение «Гардероб обновлён» (scripts/notice_ui.gd).
var notice_refund := 0
## Сколько осколков вернула последняя загрузка (старые вещи); не 0 — игра сразу сохраняется.
var migrated := 0
## 0.13: вещи заменённых наборов вернулись осколками — сообщение говорит о новых наборах
var notice_sets := false
## 0.13: пол героев (герой -> "boy"/"girl"; нет записи — мальчик) и имена (герой -> имя; нет — без имени)
var genders: Dictionary = {}
var names: Dictionary = {}


# ---------- Залы ----------

static func hall_index(level: int) -> int:
	return clampi((level - 1) / HALL_SIZE, 0, HALLS.size() - 1)


static func hall(level: int) -> Dictionary:
	return HALLS[hall_index(level)]


## Название зала по номеру 0..10 (10 — «Бесконечные глубины») на текущем языке (тексты — scripts/i18n.gd).
static func hall_name(h: int) -> String:
	return I18n.t("hall_%d" % clampi(h, 0, HALLS.size() - 1))


## Название вида героя; gender "girl" — женский вариант (ru: Совушка, Аксолотлинка, Собачка, Кошечка).
static func hero_name(kind: String, gender := "") -> String:
	if gender == "girl" and I18n.has("hero_%s_girl" % kind):
		return I18n.t("hero_%s_girl" % kind)
	return I18n.t("hero_" + kind)


## Родительный падеж названия героя («вещи Совёнка / Совушки»).
static func hero_gen(kind: String, gender := "") -> String:
	if gender == "girl" and I18n.has("hero_gen_%s_girl" % kind):
		return I18n.t("hero_gen_%s_girl" % kind)
	return I18n.t("hero_gen_" + kind)


static func slot_name(slot: String) -> String:
	return I18n.t("slot_" + slot)


static func spot_name(spot: String) -> String:
	return I18n.t("spot_" + spot)


## kind — герой: у окрасок для разных героев свои названия (ключ item_<id>_<герой>, если есть).
## gender (0.13) — у некоторых вещей название по полу героя (ключ item_<id>_boy / item_<id>_girl).
static func item_name(id: String, kind := "", gender := "") -> String:
	if gender != "" and I18n.has("item_%s_%s" % [id, gender]):
		return I18n.t("item_%s_%s" % [id, gender])
	if kind != "" and I18n.has("item_%s_%s" % [id, kind]):
		return I18n.t("item_%s_%s" % [id, kind])
	return I18n.t("item_" + id)


static func depth(level: int) -> int:
	return level * METERS_PER_LEVEL


## Пройден ли зал номер n (1..10): открыт уровень после его последнего.
static func hall_done(n: int, max_level: int) -> bool:
	return max_level > n * HALL_SIZE


# ---------- Осколки ----------

## Награда за победу. first — уровень пройден впервые; old_stars — прежний рекорд звёзд;
## new_stars — звёзды этой партии; big_chains — сколько цепочек ×3+ было в партии.
## level — номер уровня (0.12): за первую победу +HALL_BONUS за каждый зал глубже первого
## (зал 1 — 10, зал 2 — 12, ... зал 10 — 28; в «Бесконечных глубинах» — как в зале 10).
static func win_reward(first: bool, old_stars: int, new_stars: int, big_chains: int, level := 1) -> Dictionary:
	var r := {}
	r.win = (WIN_FIRST + hall_bonus(level)) if first else WIN_REPEAT
	r.first = first
	r.stars = PER_NEW_STAR * maxi(0, new_stars - old_stars)
	r.chains = mini(CHAIN_CAP, PER_BIG_CHAIN * maxi(0, big_chains))
	r.total = r.win + r.stars + r.chains
	return r


## 0.12: прибавка к первой победе за глубину зала.
static func hall_bonus(level: int) -> int:
	return HALL_BONUS * mini(hall_index(level), HALL_COUNT - 1)


# ---------- Вещи ----------

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	for it in DECOR:
		if it.id == id:
			return it
	return {}


static func spot_kind(spot: String) -> String:
	return spot.trim_suffix("_l").trim_suffix("_r")


static func decor_for(home: String, spot: String) -> Array:
	var k := spot_kind(spot)
	return DECOR.filter(func(it): return it.home == home and it.spots.has(k))


## Ступень богатства дома (0..3) по пройденным залам: 1 зал — ступень 1,
## 3 зала — ступень 2, 6 залов — ступень 3 (HOME_STAGE_HALLS).
static func home_stage(max_level: int) -> int:
	var halls := clampi((max_level - 1) / HALL_SIZE, 0, HALL_COUNT)
	var stage := 0
	for need in HOME_STAGE_HALLS:
		if halls >= need:
			stage += 1
	return stage


## Вещи героя в слоте (0.12b: у каждого героя свои), в порядке таблицы.
static func items_in(slot: String, kind: String) -> Array:
	return ITEMS.filter(func(it): return it.slot == slot and it.hero == kind)


## Все 19 вещей героя.
static func hero_items(kind: String) -> Array:
	return ITEMS.filter(func(it): return it.hero == kind)


## Чья вещь ("" — украшение дома или нет такой).
static func owner_of(id: String) -> String:
	return item(id).get("hero", "")


## Какой рисунок/палитра у вещи (поле draw — вещь, нарисованная раньше; иначе сам id).
static func draw_key(id: String) -> String:
	return item(id).get("draw", id) if id != "" else ""


## Надеть вещь id в наряд o (словарь слот -> id) с учётом супер-эксклюзива: он занимает
## слоты covers (их вещи снимаются), а вещь в занятый слот снимает его. Меняет o.
static func put_on(o: Dictionary, id: String) -> void:
	var it := item(id)
	if not it.has("slot"):
		return
	for s in it.get("covers", []):
		o.erase(s)
	for s in o.keys():
		var cv: Array = item(o[s]).get("covers", [])
		if cv.has(it.slot):
			o.erase(s)
	o[it.slot] = id


## Пустая строка — условие выполнено; иначе — почему вещь закрыта.
static func lock_reason(id: String, total_stars: int, max_level: int) -> String:
	var it := item(id)
	if it.is_empty():
		return "?"
	if it.has("stars") and total_stars < int(it.stars):
		return I18n.t("lock_stars") % it.stars
	if it.has("hall") and not hall_done(int(it.hall), max_level):
		return I18n.t("lock_hall") % hall_name(int(it.hall) - 1)
	if it.get("forge", false):
		return I18n.t("lock_forge")
	return ""


# ---------- 0.12: редкости, наборы, кузница, коллекция (0.12b — у каждого героя свои) ----------

static func rarity(id: String) -> String:
	return item(id).get("rarity", "common")


static func rarity_name(r: String) -> String:
	return I18n.t("rarity_" + r)


static func is_forge(id: String) -> bool:
	return item(id).get("forge", false)


## Номер набора вещи в общем списке SETS (1..12; 0 — не из набора: супер-эксклюзив).
static func set_of(id: String) -> int:
	return set_index(item(id).get("set", ""))


static func set_index(sid: String) -> int:
	for i in SETS.size():
		if SETS[i].id == sid:
			return i + 1
	return 0


static func set_info(n: int) -> Dictionary:
	return SETS[n - 1] if n >= 1 and n <= SETS.size() else {}


## gender (0.13) — у набора может быть название по полу героя (ключ set_<id>_girl).
static func set_title(n: int, gender := "") -> String:
	if n < 1 or n > SETS.size():
		return ""
	if gender == "girl" and I18n.has("set_%s_girl" % SETS[n - 1].id):
		return I18n.t("set_%s_girl" % SETS[n - 1].id)
	return I18n.t("set_" + SETS[n - 1].id)


## Наборы героя (номера в SETS), по порядку 1..3.
static func hero_sets(kind: String) -> Array:
	var out: Array = []
	for i in SETS.size():
		if SETS[i].hero == kind:
			out.append(i + 1)
	return out


## Вещи набора n (без награды кузницы), в порядке таблицы.
static func set_items(n: int) -> Array:
	var sid: String = set_info(n).get("id", "?")
	return ITEMS.filter(func(it): return it.get("set", "") == sid and not it.get("forge", false))


static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}


## Рецепт награды набора n (номер в SETS).
static func recipe_for_set(n: int) -> Dictionary:
	var sid: String = set_info(n).get("id", "?")
	for r in RECIPES:
		if r.set == sid:
			return r
	return {}


## Рецепт супер-эксклюзива героя (из трёх легендарных).
static func super_recipe(kind: String) -> Dictionary:
	for r in RECIPES:
		if r.hero == kind and r.set == "":
			return r
	return {}


## Всего вещей в коллекции героя (19).
static func collection_total(kind := "owl") -> int:
	return hero_items(kind).size()


## Сколько вещей коллекции текущего героя у игрока (купленные и скованные).
func collection_count() -> int:
	var n := 0
	for it in hero_items(hero if hero != "" else "owl"):
		if is_owned(it.id):
			n += 1
	return n


## Сколько вещей рецепта уже есть у игрока.
func recipe_have(id: String) -> int:
	var n := 0
	for need in recipe(id).get("needs", []):
		if is_owned(need):
			n += 1
	return n


## Состояние рецепта: "done" — уже скован, "hero" — рецепт другого героя, "hall" — зал не пройден,
## "items" — не хватает вещей, "poor" — не хватает осколков, "ok" — можно ковать, "unknown" — нет такого.
func forge_status(id: String, max_level: int) -> String:
	var r := recipe(id)
	if r.is_empty():
		return "unknown"
	if forged.has(id):
		return "done"
	if r.hero != hero:
		return "hero"
	if not hall_done(int(r.hall), max_level):
		return "hall"
	if recipe_have(id) < r.needs.size():
		return "items"
	if shards < int(r.cost):
		return "poor"
	return "ok"


## Все вещи рецепта собраны (осколков может не хватать) — силуэт награды пульсирует.
func recipe_complete(id: String, max_level: int) -> bool:
	return forge_status(id, max_level) in ["ok", "poor"]


## Есть ли у текущего героя рецепт, который можно сковать прямо сейчас (метка «Можно сковать!»).
func forge_ready_any(max_level: int) -> bool:
	for r in RECIPES:
		if r.hero == hero and forge_status(r.id, max_level) == "ok":
			return true
	return false


## Сколько легендарных наград героя уже скованы (для супер-эксклюзива).
func legends_forged() -> int:
	var n := 0
	for r in RECIPES:
		if r.hero == hero and r.set != "" and forged.has(r.id):
			n += 1
	return n


## Сковать награду: тратятся только осколки, вещи рецепта остаются у игрока; награда сразу надевается.
## Возвращает "forged" или причину отказа (как forge_status).
func forge(id: String, max_level: int) -> String:
	var st := forge_status(id, max_level)
	if st != "ok":
		return st
	shards -= int(recipe(id).cost)
	forged.append(id)
	equip(id)
	return "forged"


# ---------- 0.12b: смена героя с возвратом осколков ----------

## Сколько осколков вернётся, если сменить героя kind: цены его вещей + плата за ковку его наград
## + цены купленных украшений его дома (всё это снимется).
func refund_value(kind: String) -> int:
	var n := 0
	for id in owned:
		if owner_of(id) == kind:
			n += int(item(id).get("price", 0))
	for id in forged:
		if owner_of(id) == kind:
			n += int(recipe(id).get("cost", 0))
	for id in decor_owned:
		if item(id).get("home", "") == kind:
			n += int(item(id).get("price", 0))
	return n


## Нужно ли спрашивать при смене на героя h (есть что снимать с прежнего).
func switch_asks(h: String) -> bool:
	return hero != "" and h != hero and HEROES.has(h) and (refund_value(hero) > 0 or not equipped.is_empty())


## Сменить героя: всё прежнего (вещи, наряд, скованное, украшения его дома) снимается,
## потраченное возвращается осколками; новый герой наряжается с нуля.
## Возвращает число вернувшихся осколков (-1 — нет такого героя). Тот же герой — ничего не меняется.
func switch_hero(h: String) -> int:
	if not HEROES.has(h):
		return -1
	if h == hero:
		return 0
	var n := 0
	if hero != "":
		var old := hero
		n = refund_value(old)
		owned = owned.filter(func(id): return owner_of(id) != old)
		forged = forged.filter(func(id): return owner_of(id) != old)
		decor_owned = decor_owned.filter(func(id): return item(id).get("home", "") != old)
		decor_placed[old] = {}
		shards += n
	equipped = {}
	hero = h
	return n


func is_owned(id: String) -> bool:
	return owned.has(id) or decor_owned.has(id) or forged.has(id)


func is_equipped(id: String) -> bool:
	var it := item(id)
	return it.has("slot") and equipped.get(it.slot, "") == id


func buy(id: String, total_stars: int, max_level: int) -> int:
	var it := item(id)
	if it.is_empty():
		return Buy.UNKNOWN
	if is_owned(id):
		return Buy.OWNED
	if lock_reason(id, total_stars, max_level) != "" or it.get("forge", false):
		return Buy.LOCKED
	if it.has("hero") and it.hero != hero:
		return Buy.LOCKED  # 0.12b: чужую вещь не купить
	if shards < int(it.price):
		return Buy.POOR
	shards -= int(it.price)
	if it.has("home"):
		decor_owned.append(id)
	else:
		owned.append(id)
	return Buy.OK


## Надеть купленную/скованную вещь своего героя (0.12b: чужую — нельзя).
func equip(id: String) -> bool:
	if not (owned.has(id) or forged.has(id)) or owner_of(id) != hero:
		return false
	put_on(equipped, id)
	return true


func unequip(slot: String) -> void:
	equipped.erase(slot)


## Нажатие на вещь в гардеробе: надета — снять; куплена — надеть; не куплена — "try"
## (примерка: ничего не покупается, решает игрок в панели — buy_item()).
## Возвращает: "off", "on", "try", "locked" (не вещь гардероба).
func tap_item(id: String) -> String:
	if not item(id).has("slot") or owner_of(id) != hero:
		return "locked"
	if is_equipped(id):
		unequip(item(id).slot)
		return "off"
	if is_owned(id):
		equip(id)
		return "on"
	return "try"


## Купить вещь и сразу надеть (кнопка «Купить» в панели примерки).
## Возвращает: "bought", "owned", "poor", "locked".
func buy_item(id: String, total_stars: int, max_level: int) -> String:
	if not item(id).has("slot"):
		return "locked"
	match buy(id, total_stars, max_level):
		Buy.OK:
			equip(id)
			return "bought"
		Buy.OWNED:
			equip(id)
			return "owned"
		Buy.POOR:
			return "poor"
	return "locked"


# ---------- Украшения дома ----------

func placed_at(home: String, spot: String) -> String:
	return decor_placed.get(home, {}).get(spot, "")


## Поставить купленное украшение на место своего дома (с прежнего места оно уходит).
func place(home: String, spot: String, id: String) -> bool:
	var it := item(id)
	if not decor_owned.has(id) or it.get("home", "") != home or not SPOTS.has(spot) or not it.spots.has(spot_kind(spot)):
		return false
	var d: Dictionary = decor_placed.get(home, {})
	for s in d.keys():
		if d[s] == id:
			d.erase(s)
	d[spot] = id
	decor_placed[home] = d
	return true


func remove_decor(home: String, spot: String) -> void:
	if decor_placed.has(home):
		decor_placed[home].erase(spot)


## Нажатие на украшение для места: стоит тут — убрать; куплено — поставить;
## не куплено — "try" (примерка, покупка — buy_decor()); чужой дом / не то место — "locked".
func tap_decor(home: String, spot: String, id: String) -> String:
	if placed_at(home, spot) == id:
		remove_decor(home, spot)
		return "off"
	if decor_owned.has(id):
		return "on" if place(home, spot, id) else "locked"
	if not fits_spot(home, spot, id):
		return "locked"
	return "try"


func fits_spot(home: String, spot: String, id: String) -> bool:
	var it := item(id)
	return it.get("home", "") == home and SPOTS.has(spot) and it.spots.has(spot_kind(spot))


## Купить украшение и сразу поставить на место. Возвращает: "bought", "owned", "poor", "locked".
func buy_decor(home: String, spot: String, id: String, total_stars: int, max_level: int) -> String:
	if not fits_spot(home, spot, id):
		return "locked"
	match buy(id, total_stars, max_level):
		Buy.OK:
			place(home, spot, id)
			return "bought"
		Buy.OWNED:
			place(home, spot, id)
			return "owned"
		Buy.POOR:
			return "poor"
	return "locked"


## Выбрать героя (первый выбор или смена — с возвратом за прежнего, см. switch_hero).
func set_hero(h: String) -> bool:
	return switch_hero(h) >= 0


## Наряд для рисования: слот -> id (без героя). 0.13: у девочки добавляется "gender": "girl"
## (scripts/hero.gd рисует реснички и заколку; нет ключа — мальчик).
func outfit() -> Dictionary:
	var o := equipped.duplicate()
	o.merge(look(hero))
	return o


# ---------- 0.13: мальчик / девочка и имя ----------

## "boy" или "girl" (по умолчанию — мальчик).
func gender_of(kind: String) -> String:
	return "girl" if genders.get(kind, "") == "girl" else "boy"


func is_girl(kind: String) -> bool:
	return gender_of(kind) == "girl"


## Сменить пол героя: бесплатно, вещи и украшения не трогаются (это тот же герой).
func set_gender(kind: String, gender: String) -> bool:
	if not HEROES.has(kind) or not GENDERS.has(gender):
		return false
	genders[kind] = gender
	return true


## Вид героя для рисования без наряда (аватарки других героев, выбор друга).
func look(kind: String) -> Dictionary:
	return {"gender": "girl"} if is_girl(kind) else {}


## Очистить имя: убрать запрещённые знаки (оставить буквы любого алфавита, цифры, пробел, дефис),
## лишние пробелы, обрезать до NAME_MAX знаков.
static func clean_name(s: String) -> String:
	var re := RegEx.new()
	re.compile("[^\\p{L}\\p{N} \\-]")
	var o := re.sub(s, "", true)
	while o.contains("  "):
		o = o.replace("  ", " ")
	o = o.strip_edges().substr(0, NAME_MAX).strip_edges()
	return o


## Дать имя герою. Пустое (после очистки) — не принимается (false).
func set_hero_name(kind: String, s: String) -> bool:
	var n := clean_name(s)
	if not HEROES.has(kind) or n == "":
		return false
	names[kind] = n
	return true


func clear_hero_name(kind: String) -> void:
	names.erase(kind)


## Имя героя ("" — не задано).
func name_of(kind: String) -> String:
	return String(names.get(kind, ""))


## Как называть героя: его имя, а без имени — название вида по полу (Совёнок / Совушка).
func display_name(kind: String) -> String:
	var n := name_of(kind)
	return n if n != "" else hero_name(kind, gender_of(kind))


# ---------- Сохранение ----------

func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("meta", "hero", hero)
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "owned", owned)
	cfg.set_value("meta", "equipped", equipped)
	cfg.set_value("meta", "decor_owned", decor_owned)
	cfg.set_value("meta", "decor_placed", decor_placed)
	cfg.set_value("meta", "forged", forged)
	cfg.set_value("meta", "notice_refund", notice_refund)
	cfg.set_value("meta", "notice_sets", notice_sets)
	cfg.set_value("meta", "genders", genders)
	cfg.set_value("meta", "names", names)


func load_from(cfg: ConfigFile) -> void:
	var h = cfg.get_value("meta", "hero", "")
	hero = h if h is String and HEROES.has(h) else ""
	var s = cfg.get_value("meta", "shards", 0)
	shards = maxi(0, int(s)) if (s is int or s is float) else 0
	# 0.12b: вещи — только своего героя. Старые общие вещи (0.6–0.12) и скованные награды
	# возвращаются осколками по прежним ценам; вещи другого героя (не должно быть) — по новым.
	migrated = 0
	var sets_back := false
	owned = []
	var o = cfg.get_value("meta", "owned", [])
	if o is Array:
		for id in o:
			if not (id is String) or owned.has(id):
				continue
			var it := item(id)
			if it.is_empty() and REPLACED_013.has(id):
				migrated += int(REPLACED_013[id])  # 0.13: вещь заменённого набора
				sets_back = true
			elif it.is_empty() and LEGACY_PRICES.has(id):
				migrated += int(LEGACY_PRICES[id])
			elif it.has("hero") and not it.get("forge", false):
				if it.hero == hero:
					owned.append(id)
				else:
					migrated += int(it.price)
	forged = []
	var fg = cfg.get_value("meta", "forged", [])
	if fg is Array:
		for id in fg:
			if not (id is String) or forged.has(id):
				continue
			if item(id).is_empty() and REPLACED_013_FORGE.has(id):
				migrated += int(REPLACED_013_FORGE[id])
				sets_back = true
			elif item(id).is_empty() and LEGACY_FORGE.has(id):
				migrated += int(LEGACY_FORGE[id])
			elif is_forge(id):
				if owner_of(id) == hero:
					forged.append(id)
				else:
					migrated += int(recipe(id).get("cost", 0))
	shards += migrated
	var nr = cfg.get_value("meta", "notice_refund", 0)
	notice_refund = (maxi(0, int(nr)) if (nr is int or nr is float) else 0) + migrated
	var ns = cfg.get_value("meta", "notice_sets", false)
	notice_sets = (ns is bool and ns and notice_refund > 0) or sets_back
	# 0.13: пол и имена; в старом сохранении их нет — мальчики без имён
	genders = {}
	var gd = cfg.get_value("meta", "genders", {})
	if gd is Dictionary:
		for k in gd:
			if k is String and HEROES.has(k) and gd[k] is String and GENDERS.has(gd[k]):
				genders[k] = gd[k]
	names = {}
	var nm = cfg.get_value("meta", "names", {})
	if nm is Dictionary:
		for k in nm:
			if k is String and HEROES.has(k) and nm[k] is String and clean_name(nm[k]) != "":
				names[k] = clean_name(nm[k])
	decor_owned = []
	var dow = cfg.get_value("meta", "decor_owned", [])
	if dow is Array:
		for id in dow:
			if id is String and item(id).has("home") and not decor_owned.has(id):
				decor_owned.append(id)
	decor_placed = {}
	for home in HEROES:
		decor_placed[home] = {}
	var dp = cfg.get_value("meta", "decor_placed", {})
	if dp is Dictionary:
		for home in HEROES:
			var d = dp.get(home, {})
			if d is Dictionary:
				for spot in d:
					if spot is String and d[spot] is String:
						place(home, spot, d[spot])
	equipped = {}
	var e = cfg.get_value("meta", "equipped", {})
	if e is Dictionary:
		for slot in e:
			var id = e[slot]
			if id is String and (owned.has(id) or forged.has(id)) and item(id).get("slot", "") == slot:
				put_on(equipped, id)
