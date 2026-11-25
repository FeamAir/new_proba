# Вычитка текстов (сценарист, 25.11.2026) — применить в 0.14

Источник: полная вычитка scripts/i18n.gd (en/ru). Формат: ключ | язык | стало | почему.

## Главное
- forge_say_start_owl / _owl_girl | ru | «Собери набор, дружок, — выкую тебе совиное чудо!» | «скую» → «выкую», голос доброго мастера
- forge_say_start_axolotl | ru | «Собери набор, дружок, — выкую тебе морское сокровище!»
- forge_say_start_puppy | ru | «Собери набор — выкую тебе награду чемпиона!»
- forge_say_start_kitten | ru | «Собери набор — выкую тебе наряд на загляденье!»
- forge_say_super | ru | «Ещё одна легендарная вещь — и главный приз твой!»
- forge_say_ready | ru | «Всё готово, дружок. Куём?»
- forge_say_all | ru | «У тебя уже всё есть. Сияй, дружок!»
- forge_say_start_* | en | «Complete a set, and I'll forge you an owlish wonder! / a treasure of the deep! / a champion's prize! / something fancy!»
- forge_say_super | en | «One more Legendary, and the grand prize is yours!»
- forge_say_ready | en | «All set, little one. Shall we forge?»
- switch_text, switch_text_named | ru | «Вещи и украшения %s вернутся осколками» / «%s: вещи и украшения вернутся осколками» | на деле не «снимаются», а возвращаются
- switch_text, switch_text_named | en | «%s's items and decorations will be traded back for shards»
- switch_done, migrate_refund | ru | «Возвращено: %d %s» | «Вернулось 1 осколок» — ошибка согласования
- pick_ok | ru | «ВПЕРЁД!»
- switch_title / migrate_text / name_title | en | везде buddy вместо friend («Switch buddy?», «Every buddy now has…», «Name your buddy»)
- try_hint | ru «Нравится? Купи — и вещь твоя!» | en «Like it? Buy it to keep it!»
- card_placed | ru «НА МЕСТЕ»; card_place | ru «Разместить»
- boost_title «Помощь кристалла»; boost_popup «ПОМОЩЬ КРИСТАЛЛА!»; boost_yes ru «Принять помощь», en «Use the boost»
- boost_desc_1/2 | ru «Нижний ряд камня исчезнет» / «Два нижних ряда камня исчезнут» | en «Removes the bottom row of stone» / «Removes the two bottom rows of stone»
- tut_chain | ru «Чем длиннее цепочка, тем больше осколков» | en «The longer the chain, the more shards!»
- tut_crumble | en «Place pieces so the stone crumbles»
- tut_rotate | ru «Нажми, чтобы повернуть»
- forge_skip | ru «нажми, чтобы пропустить»
- win_stats | ru «Счёт: %d   Фигур: %d»
- win_gift | en «Welcome gift +%d!»
- forge_can | en «Ready to forge!»
- forge_keep | ru «Вещи набора останутся у тебя» | en «You keep the set items»
- lock_hall | en «Clear hall: %s» | ru «Сначала пройди: %s»

## Род героя (0.13)
- item_ki_starry_boy ru «Звёздный котик», _girl ru «Звёздная кошечка», en оба «Starry Kitten»
- добавить item_pu_skin_dalmatian_girl ru «Далматинка» (en Dalmatian)
- ключи *_girl должны быть в ОБОИХ языках (иначе t() отдаёт английский)
- код: forge_ui.gd ~209 (реплика без рода — ок), notice_ui.gd ~181 (hero_gen_ без рода/имени — подключить switch_text_named и *_girl), forge_ui.gd ~287 (item_name без рода — передавать пол), migrate_sets_text жёстко «Кот-детектив» (для девочки «Кошка-детектив»)

## Мелочи
- en: Bushy mustache; Pom-pom beanie; Sports shades; Masquerade Fireworks (item_ki_aura_fireworks)
- ru: item_pu_basket «Корзинка для пикника»; item_ow_book «Летающая книжка»; item_ax_starfish «Заколка-звёздочка»; item_ax_shell_pack «Рюкзак-ракушка»; item_pu_robo «Робот-дружок»; item_pu_aura_bolts «Скоростные молнии»; item_pu_frisbee «Золотая тарелка-фрисби»; item_axo_sofa «Каменный диван»; item_axo_tree «Коралловые деревья»; item_pup_sign «Табличка-косточка»; item_owl_mushrooms «Грибы-фонарики»; item_ki_clue_trail «Цепочка улик»; item_ki_trench «Тренч»; hall_9 «Кристальная корона» (по желанию)
- rarity_super | ru «Эксклюзивная» | en «Exclusive»
- pick_lives_axolotl | en «lives in an underwater grotto» | ru «живёт в подводном гроте»
- pause_sound ru «Звук: %s»; stats_sub ru «хранится только на этом телефоне»; stats_best ru «Рекорд»
- en: forge_hall_hint «Unlocks after Hall %d»; map_locked «Unlocks after Level %d»; map_below «Depth %d m and below»; goal_ready «Ready to buy: %s!»; switch_refund «You'll get back %d %s»; switch_done «%d %s refunded»
- migrate_sets_text | en «…Items from the old sets were refunded as shards.» | ru «…Вещи из старых наборов вернулись осколками.»
- spot_wall_l/r | ru «Стена слева/справа» | en «Wall left/right» (если влезает)
- boost_no | ru «Нет, спасибо. Ещё раз»
- Заглавные буквы в en-названиях вещей — единообразно по редкости.

## Словарик
осколки — shards; друг — buddy; Кристальная кузница — Crystal Forge; выковать/«Выковать за %d»/«Выковано» — forge/Forge for %d/Forged (сменить и forge_btn, forge_can, forge_done, forge_got); набор — set (complete a set); Зал %d — Hall %d; легендарная — Legendary; главный приз — grand prize; редкости: Обычная/Редкая/Эпическая/Легендарная/Эксклюзивная — Common/Rare/Epic/Legendary/Exclusive; вещи/украшения — items/decorations; гардероб — Wardrobe; примерка — try-on; каскад — cascade; цепочка — chain; помощь кристалла — Crystal Boost; «Unlocks after…»; в подсказках «нажми» (tap); Мастер Ух — Master Hoot (только в именительном падеже), обращается «дружок» / «little one».
