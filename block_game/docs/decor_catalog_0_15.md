# Каталог украшений 0.15 (сценарист, 26.11.2026)

Обозначения: (*) — старое украшение, id не меняется; ★ — «вау»-украшение. Формат строки: id | RU / EN | места (типы) | цена | вид и анимация.

## Общие правила
Типы мест (7, общие): floor — пол (малые/средние); big — крупная вещь у задней стены/в углу (вау, мебель); wall — стена/забор/стена пещеры; shelf — полка/уступ/крыша будки; hang — подвес сверху; window — окно/подоконник/проём; near — рядом с героем.
Совместимость: старые типы floor/wall/hang/near как есть. Исключение — котик: старое место `hang` фактически верхняя полка → id `hang` остаётся, тип `shelf`; kit_catnip и kit_aquarium: тип hang → shelf.
Полка славы: места не должны попадать в её зону (shelf_def в room_*.gd).
Одна купленная вещь = одно место (без копий). Перестановка, поворот, настроения и перекраска уже купленного стиля комнаты — бесплатно. Пожелание: кнопка «Примерить стиль» (весь набор полупрозрачно до покупки).

## 1. СОВЁНОК — дупло (16 мест)
Места: floor_l*, floor_r* (floor) · floor_front (floor, передний край) · big_back (big, задняя стена за героем) · big_corner (big, дальний угол напротив полки славы) · wall_l*, wall_r* (wall, кора) · wall_back (wall, выше героя) · shelf_l, shelf_r (shelf, грибы-трутовики) · hang* (hang, центр свода) · hang_l, hang_r (hang, сучки на своде) · window (window, вход в дупло с луной) · near*, near_2 (near).

### А. «Книжный уголок» / Reading Nook — тёплый янтарный
- owl_nest* | Коврик-гнездо / Nest rug | near, floor | 10 | как сейчас
- owl_lantern* | Фонарик / Lantern | hang, wall, near | 15 | как сейчас
- owl_birdhouse* | Скворечник / Birdhouse | wall | 25 | как сейчас
- owl_books* | Книжки / Books | wall, shelf, near | 30 | как сейчас
- owl_hammock* | Гамак / Hammock | wall, floor | 35 | как сейчас
- owl_candles | Свечи / Candles | shelf, window | 25 | 3 свечи разной высоты, огоньки мерцают, тёплая подсветка
- owl_tea | Чайный столик / Tea table | floor, near | 40 | столик-спил, чайник и чашки, пар-шарики тают
- owl_clock | Часы с маятником / Pendulum clock | wall | 50 | круглый циферблат, маятник качается
- owl_armchair | Кресло-пенёк / Stump armchair | floor, near | 60 | пенёк с зелёной подушкой, плед
- owl_bookcase ★ | Книжный шкаф / Tall bookcase | big | 220 | шкаф до свода, цветные корешки, лесенка; книга выдвигается/задвигается; лампа с тёплым светом

### Б. «Звездочёт» / Stargazer — синий лунный
- owl_garland* | Гирлянда / Garland | hang | 20 | как сейчас
- owl_swing* | Качели / Swing | hang | 30 | как сейчас
- owl_moon* | Луна-подвеска / Hanging moon | hang | 40 + 25★ | как сейчас
- owl_nightlight* | Кристалл-ночник / Crystal lamp | floor, near | 50 + зал 1 | как сейчас
- owl_starmap | Карта созвездий / Star map | wall | 35 | тёмный свиток, звёзды-линии мигают по очереди
- owl_globe | Звёздный глобус / Star globe | shelf, floor | 45 | синий шар в точках, вращается, светится
- owl_comet | Комета в банке / Comet jar | shelf, window | 55 | банка, внутри светящийся шарик с хвостом бегает по кругу
- owl_planets | Модель планет / Planet mobile | hang | 60 | кольца-орбиты с 5 шариками, вращаются
- owl_telescope | Телескоп / Telescope | window, floor | 70 | латунная труба на треноге, поворачивается к луне
- owl_observatory ★ | Мини-обсерватория / Mini observatory | big | 220 | белый купол, щель раскрывается, выдвигается телескоп, голубой луч с искрами

### В. «Лавка зелий» / Potion Workshop — зелёный волшебный
- owl_mushrooms* | Грибы-фонарики / Mushroom lamps | floor, shelf | 20 | как сейчас
- owl_mortar | Ступка / Mortar and pestle | shelf, near | 20 | каменная чаша, пестик покачивается
- owl_herbs | Сушёные травы / Drying herbs | hang, wall | 25 | пучки трав на верёвке
- owl_wreath | Венок из листьев / Leaf wreath | wall, window | 30 | венок с ягодками, падает листик
- owl_fireflies | Банка светлячков / Firefly jar | hang, shelf, window | 35 | 6 огоньков летают в банке
- owl_potions | Бутылочки зелий / Potion bottles | shelf, wall | 40 | 4 бутылочки, светятся пульсом
- owl_crystals | Друза кристаллов / Crystal cluster | floor, shelf | 45 | фиолетовые призмы переливаются
- owl_staff | Волшебный посох / Magic staff | wall, near | 50 | кристалл наверху вращается и светится
- owl_spellbook | Книга заклинаний / Spellbook stand | near, floor | 60 | страницы листаются, искорки
- owl_cauldron ★ | Котёл зелий / Bubbling cauldron | big, floor | 200 | зелёная жидкость, пузыри, пар меняет цвет, подсветка снизу

### Стиль комнаты совёнка
Стены: Кора / Bark (0, как сейчас) · Мшистые стены / Mossy walls (30) · Звёздная роспись / Starry paint (50, мерцающие звёзды) · Светящиеся руны / Glowing runes (60, пульсирующие узоры).
Пол: Опавшие листья / Leaf litter (0) · Плетёный коврик / Woven rug (25) · Ковёр-созвездие / Constellation rug (45) · Светящиеся корни / Glow roots (60).
Свет: Лунная ночь / Moonlit night (0) · Тёплая лампа / Warm lamplight (30) · Светлячки / Firefly evening (50, десятки огоньков) · Северное сияние / Aurora (70).

## 2. АКСОЛОТЛЬ — грот (15 мест)
Места: floor_l*, floor_r* (floor) · floor_front (floor) · big_back (big) · big_corner (big, напротив полки славы) · wall_l*, wall_r* (wall) · wall_back (wall) · ledge_l, ledge_r (shelf, уступы) · hang* (hang) · hang_2 (hang, сталактит) · window (window, просвет в своде с лучами) · near*, near_2 (near).

### А. «Коралловый сад» / Coral Garden — розово-бирюзовый
- axo_starfish* | Морская звезда / Starfish | wall, shelf | 10
- axo_coral* | Коралл / Coral | wall, floor | 15
- axo_shell* | Жемчужница / Pearl shell | floor, near, shelf | 25
- axo_lily* | Кувшинка / Water lily | hang | 25
- axo_tree* | Коралловые деревья / Coral trees | floor | 35
- axo_sofa* | Каменный диван / Stone sofa | near | 40
- axo_castle* | Замок / Castle | floor, big | 50 + зал 2
- axo_kelp | Водоросли-занавес / Kelp curtain | wall, window | 35 | зелёные ленты колышутся
- axo_seahorse | Морские коньки / Seahorse pair | hang, wall | 45 | два конька плавают навстречу
- axo_arch ★ | Жемчужная арка / Pearl arch | big | 200 | арка из кораллов с жемчугом, поток пузырей, жемчуг мерцает

### Б. «Затонувший корабль» / Sunken Treasure — дерево, золото (на флаге ракушка, без черепов)
- axo_anchor* | Якорь / Anchor | floor, wall | 20
- axo_chest* | Сундук / Treasure chest | floor, near | 60 + 40★
- axo_bottle | Бутылка с письмом / Message bottle | floor, shelf, near | 20 | покачивается
- axo_map | Карта сокровищ / Treasure map | wall | 30 | крестик мигает
- axo_spyglass | Подзорная труба / Spyglass | shelf, near | 30 | раздвигается
- axo_lantern | Корабельный фонарь / Ship lantern | hang, wall | 35 | тёплый свет, качается
- axo_barrel | Бочка с монетами / Coin barrel | floor, near | 40 | высыпаются монетки
- axo_flag | Флаг с ракушкой / Shell flag | wall, window | 40 | колышется
- axo_wheel | Штурвал / Ship's wheel | wall | 45 | поворачивается туда-сюда
- axo_ship ★ | Затонувший кораблик / Sunken ship | big | 220 | нос корабля в песке, мачта, светящиеся иллюминаторы, пузыри, выплывает рыбка

### В. «Сияние бездны» / Deep Glow — тёмный неон
- axo_bubble* | Лампа-пузырь / Bubble lamp | hang, near | 30
- axo_plankton | Гирлянда планктона / Plankton string | hang, wall | 25 | светящиеся точки дрейфуют
- axo_anemones | Светящиеся анемоны / Glow anemones | floor, shelf | 30 | кончики светятся
- axo_vent | Тёплый источник / Thermal vent | floor | 40 | светящиеся пузыри
- axo_neonsquid | Неоновый кальмар / Neon squid | wall, window | 40 | трубка-силуэт мигает
- axo_crystal | Кристалл бездны / Abyss crystal | floor, shelf | 45 | пульсирует
- axo_angler | Добрый удильщик / Anglerfish lamp | floor, near | 50 | огонёк на «удочке» покачивается
- axo_pod | Кресло-капсула / Glow pod chair | near | 55 | прозрачная сфера с подсветкой
- axo_jelly | Медузы-люстра / Jellyfish lamp | hang | 60 | 3 купола пульсируют голубым и розовым
- axo_sub ★ | Батискаф / Bathyscaphe | big | 230 | иллюминатор, прожектор водит лучом, винт крутится

### Стиль комнаты аксолотля
Стены: Каменный грот / Stone grotto (0) · Перламутр / Mother-of-pearl (40) · Корабельные доски / Ship planks (50) · Светящиеся прожилки / Glow veins (60).
Пол: Белый песок / White sand (0) · Розовый песок с ракушками / Pink shell sand (30) · Монеты в песке / Coin sand (50) · Чёрный песок с огоньками / Dark glitter sand (45).
Свет: Солнечные лучи / Sun rays (0) · Закат под водой / Underwater sunset (30) · Праздничные пузыри / Party bubbles (50) · Тьма бездны / Abyss dark (60, светящиеся вещи ярче).

## 3. ЩЕНОК — ночной сад (15 мест, без window)
Места: floor_l*, floor_r* (floor) · floor_front (floor) · big_back (big, у забора за будкой слева) · big_side (big, дальний левый угол; стенд кубков справа) · wall_l*, wall_r* (wall, забор, не перекрывает стенд) · house_wall (wall, стенка будки) · roof (shelf, крыша будки) · fence_top (shelf, верх забора) · tree (hang, ветка) · hang* (hang, верёвка над будкой) · near*, near_2 (near).

### А. «Сад и пикник» / Garden Picnic
- pup_bowl* | Миска / Bowl | near, floor | 20
- pup_sign* | Табличка-косточка / Bone sign | wall | 20
- pup_flowerbed* | Клумба / Flowerbed | floor | 25
- pup_pinwheel* | Вертушка / Pinwheel | wall, floor | 30
- pup_bed* | Лежанка / Cushion bed | near | 45
- pup_teddy* | Плюшевый мишка / Teddy bear | near, floor | 60 + зал 1
- pup_sunflowers | Подсолнухи / Sunflowers | wall, floor | 35 | головки поворачиваются
- pup_picnic | Плед для пикника / Picnic blanket | floor, near | 40 | клетчатый плед, крышка корзинки подпрыгивает
- pup_birdbath | Поилка для птиц / Birdbath | floor | 45 | по краю прыгает птичка
- pup_gazebo ★ | Беседка с огоньками / Gazebo | big | 200 | белая беседка, гирлянда, качели внутри

### Б. «Поход» / Campfire Camp
- pup_bone* | Косточка / Bone | near | 15
- pup_lamp* | Садовый фонарь / Garden lamp | hang, wall, floor | 35
- pup_kite* | Воздушный змей / Kite | hang | 50 + 25★
- pup_pennants | Флажки / Pennant string | hang, wall | 25 | колышутся
- pup_binoculars | Бинокль / Binoculars | near, shelf | 25 | поворачивается к звёздам
- pup_backpack | Рюкзак / Backpack | near, floor | 30 | с котелком сбоку
- pup_trailmap | Карта похода / Trail map | wall | 30 | по тропе ползёт огонёк
- pup_canoe | Каноэ / Canoe | floor, big | 60 | лодка с веслом на боку
- pup_tent | Палатка / Tent | big, floor | 70 | полог колышется, внутри тёплый свет
- pup_campfire ★ | Костёр / Campfire | floor, big | 180 | брёвна в кругу камней, пламя-конусы, искры, тёплый свет, зефирка на палочке

### В. «Скейт-парк» / Skate Park (без букв и логотипов: лапки, косточки, звёзды, молнии)
- pup_ball* | Мячик / Ball | floor, near | 10
- pup_cones | Конусы / Traffic cones | floor, shelf | 15 | один падает и встаёт
- pup_spray | Баллончики / Spray cans | shelf | 20
- pup_headphones | Наушники / Headphones | near, shelf | 25 | огоньки на чашках
- pup_skateboard | Скейтборд / Skateboard | near, floor | 30 | колёса крутятся
- pup_hoop | Баскетбольное кольцо / Hoop | wall | 45 | мяч иногда залетает
- pup_graffiti | Граффити на заборе / Fence graffiti | wall | 50 | лапка и звёзды, цвета переливаются
- pup_boombox | Магнитофон / Boombox | floor, near, shelf | 55 | колонки пульсируют, ноты
- pup_neon | Неоновая лапка / Neon paw sign | wall, shelf | 60 | лапка и молния мигают
- pup_ramp ★ | Рампа / Skate ramp | big | 230 | по рампе сам катается скейт

### Стиль сада щенка
Забор: Деревянный штакетник / Picket fence (0) · Частокол из брёвен / Log palisade (40) · Каменная ограда с плющом / Ivy stone wall (35) · Цветная бетонная стена / Painted concrete (50).
Земля: Газон / Lawn (0) · Цветочный луг / Flower meadow (35) · Лесная хвоя и шишки / Pine needles (40) · Площадка с разметкой / Court asphalt (50).
Свет: Звёздная ночь / Starry night (0) · Летний закат / Summer sunset (40) · Праздничные огоньки / Party lights (50) · Неон улицы / Street neon (60).

## 4. КОТИК — чердак (15 мест)
Места: floor_l*, floor_r* (floor) · floor_front (floor) · big_back (big) · big_corner (big, под скосом) · wall_l*, wall_r* (wall, скошенный потолок-стена) · wall_back (wall, у окна) · hang* (тип shelf! верхняя полка) · shelf_low (shelf) · window (window, круглое окно) · beam, beam_2 (hang, балки) · near*, near_2 (near).

### А. «Уютный вечер» / Cozy Evening
- kit_yarn* | Клубок / Ball of yarn | floor, near | 10
- kit_mouse* | Мышка / Toy mouse | near | 15
- kit_pillow* | Подушка / Pillow | near | 20
- kit_box* | Коробка / Box | floor, near | 30
- kit_scratcher* | Когтеточка / Scratching post | floor | 35
- kit_lamp* | Торшер / Floor lamp | floor | 40
- kit_tree* | Кошачий домик / Cat tree | floor, big | 60 + зал 2
- kit_tea | Чайник с печеньем / Tea set | shelf, window | 30 | пар из носика
- kit_windowseat | Подушки на подоконнике / Window seat | window | 50 | плед покачивается
- kit_stove ★ | Печка-буржуйка / Little stove | big | 200 | огонь в окошке, тёплый свет, дымок

### Б. «Рок-чердак» / Rock Loft
- kit_headphones | Наушники с ушками / Cat-ear headphones | shelf, near | 20 | ушки светятся
- kit_poster | Постер с молнией / Lightning poster | wall | 25
- kit_mic | Микрофон на стойке / Microphone | near, floor | 35 | покачивается
- kit_beanbag | Кресло-мешок / Bean bag | near, floor | 40 | чёрное с молнией
- kit_vinyl | Проигрыватель / Record player | shelf, floor | 45 | пластинка крутится, ноты
- kit_amp | Колонки / Amp speakers | floor, near | 50 | динамики пульсируют
- kit_disco | Диско-шар / Disco ball | hang | 50 | вращается, зайчики по стенам
- kit_neon | Неоновая молния / Neon bolt | wall, window | 55 | мигает
- kit_guitar | Электрогитара / Electric guitar | wall, near | 60 | в форме молнии, струны дрожат
- kit_drums ★ | Барабаны / Drum kit | big | 220 | палочки отбивают ритм, тарелки блестят, цветные прожекторы

### В. «Звёздная мастерская» / Star Studio
- kit_picture* | Картина с рыбкой / Fish picture | wall | 20
- kit_paints | Палитра и кисти / Paint palette | shelf, near | 20 | кисточка покачивается
- kit_catnip* | Кошачья мята / Catnip | shelf, wall, floor | 25 (тип hang→shelf)
- kit_vase | Глиняная ваза / Clay vase | shelf, floor | 25 | кривоватая, с цветком
- kit_cranes | Бумажные журавлики / Paper cranes | hang | 30 | качаются и кружатся
- kit_plants | Цветы в горшках / Window plants | window, shelf | 35 | листья покачиваются
- kit_aquarium* | Аквариум / Fish tank | shelf, wall, near | 50 + 30★ (тип hang→shelf)
- kit_starlamp | Звёздный проектор / Star projector | floor, shelf | 55 | точки-звёзды вращаются по потолку
- kit_easel | Мольберт / Easel | floor, near | 60 | картина «дорисовывается», 3 сменяются
- kit_stainedglass ★ | Витражное окно / Stained glass window | window | 180 | цветные лучи на пол меняют цвет

### Стиль комнаты котика
Стены: Деревянные балки / Wooden beams (0) · Обои в цветочек / Floral wallpaper (30) · Кирпич / Brick wall (50) · Ночное небо / Night sky (50).
Пол: Доски / Planks (0) · Вязаный коврик / Knitted rug (25) · Шахматная плитка / Checker tiles (45) · Пол в брызгах краски / Paint-splash floor (40).
Свет: Тёплая лампа / Warm lamp (0) · Лунный свет / Moonlight (30) · Праздничные огоньки / Fairy lights (50) · Неон и прожекторы / Neon stage (60).

## Баланс
Стиль (10 вещей) 480–625, вау 180–230; стены+пол+свет 120–170 → комната в одном стиле ≈ 620–800. Всё в одном доме ≈ 2100. Доход ≈ 27/уровень (≈2700 за 100 уровней). Гардероб до супер-награды ≈ 2400 + один стиль ≈ 700 → приходится выбирать (так задумано).
Вопрос владельцу: возврат всей суммы при смене героя теперь может быть до ~2100 — оставить полный возврат?
