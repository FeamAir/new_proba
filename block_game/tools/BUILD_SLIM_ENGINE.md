# Облегчённый движок Godot 4.7 для Android (Cascado)

Зачем: стандартный шаблон экспорта Godot содержит весь движок (физика, сеть, XR,
видео, сложная письменность и т.д.). Игре это не нужно. Собранный под игру
«облегчённый» шаблон уменьшает скачивание из Google Play примерно **в 2,3 раза**.

## Результат (проверено 2026-11-26, версия игры 0.16)

| | обычный шаблон 4.7 | облегчённый |
|---|---|---|
| библиотека движка arm64 (`libgodot_android.so`, без сжатия) | 71,1 МБ | 22,3 МБ |
| она же в сжатом виде (как в APK) | 24,0 МБ | 8,0 МБ |
| release APK, 2 архитектуры | 54,7 МБ | 22,1 МБ |
| release APK, только arm64 | — | 12,8 МБ |
| AAB (для Google Play) | 54,7 МБ | 22,1 МБ |
| **оценка скачивания из Play, arm64** (bundletool get-size) | **28,8 МБ** | **12,7 МБ** |
| оценка скачивания из Play, armeabi-v7a | 30,2 МБ | 13,6 МБ |

## Что выкинуто

Всё описано в одном файле `tools/engine_build_profile.gdbuild` (формат Godot
«Engine Compilation Configuration», JSON):

* **247 классов** (`disabled_classes`): 2D/3D-физика и навигация, частицы,
  анимации/AnimationTree, TileMap, Skeleton, GLTF, OpenXR/XR, видео, сеть
  (HTTPRequest, Multiplayer…), сложные элементы интерфейса (Tree, TextEdit,
  RichTextLabel, ItemList, GraphEdit, контейнеры…), Sprite2D/Camera2D и др.
* **опции сборки** (`disabled_build_options`): `disable_physics_2d/3d`,
  `disable_navigation_2d/3d`, `disable_xr`, `vulkan=no` (игра рисует через
  GL Compatibility = OpenGL ES 3), и все модули выключены, кроме нужных:
  `gdscript, freetype, text_server_fb, ogg, vorbis, regex, webp`.
  * `text_server_fb` вместо `text_server_adv`: латиница и кириллица рисуются
    (проверено), но НЕТ арабского/иврита/индийских письменностей и лигатур.
  * `svg` выключен: значки стандартной темы Godot (галочки и т.п.) пустые —
    игра их не использует, всё рисует сама.
  * `mbedtls` выключен: нет HTTPS/шифрования — игра сеть не использует.
* параметры компиляции: `production=yes optimize=size_extra lto=full swappy=no`
  (Swappy нужен только для Vulkan).

Оставлено: 3D (MeshInstance3D, StandardMaterial3D, ShaderMaterial, свет,
WorldEnvironment с glow/fog, SubViewport, Sprite3D, Label3D, MultiMesh,
SurfaceTool), звук WAV/OGG, шрифты (FontVariation на встроенном шрифте),
LineEdit (ввод имени), ConfigFile, RegEx, буфер обмена (DisplayServer).

## ВАЖНО при развитии игры

Если в коде появится НОВЫЙ класс Godot (например `Sprite2D`, `Timer`-наследник,
`AnimationPlayer`, `RichTextLabel`, `CPUParticles2D`, `HTTPRequest`…), его нужно
убрать из списка `disabled_classes` в `engine_build_profile.gdbuild` и
пересобрать движок. Иначе в облегчённой сборке объект не создастся
(ошибка «Cannot get class …», `null`). Так уже было найдено: звук `music.ogg`
внутри хранится как `OggPacketSequence` — без него музыка не грузилась.
Проверка: тесты проекта на облегчённой Linux-сборке (ниже, шаг 5) — они это ловят.

## Как пересобрать (≈ 30–40 минут на 4 ядрах, из них сборка ≈ 20–25)

Собранные файлы лежат во временной папке и могут пропасть — их всегда можно
пересобрать по этой инструкции. Нужно: Python 3, `pip install scons`,
Android SDK (`~/tools/android-sdk`), сеть до github.com и dl.google.com.

```bash
W=/путь/к/рабочей/папке        # не внутри репозитория
P=/home/user/new_proba/block_game
mkdir -p $W && cd $W

# 1. Исходники Godot 4.7-stable (официальный архив + проверка SHA-512)
curl -L -o godot-4.7-stable.tar.xz https://github.com/godotengine/godot-builds/releases/download/4.7-stable/godot-4.7-stable.tar.xz
curl -L -o SHA512-SUMS.txt https://github.com/godotengine/godot-builds/releases/download/4.7-stable/SHA512-SUMS.txt
grep " godot-4.7-stable.tar.xz$" SHA512-SUMS.txt | sha512sum -c -
tar xJf godot-4.7-stable.tar.xz && cd godot-4.7-stable

# 2. NDK нужной версии (номер — в platform/android/detect.py, get_ndk_version)
pip install scons
yes | ~/tools/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/tools/android-sdk "ndk;29.0.14206865"
export ANDROID_HOME=$HOME/tools/android-sdk

# 3. Сборка библиотек движка (arm64 ≈ 7–10 мин, armv7 ≈ 6–7 мин)
for A in arm64 arm32; do
  scons -j4 platform=android arch=$A target=template_release production=yes \
    optimize=size_extra lto=full swappy=no build_profile=$P/tools/engine_build_profile.gdbuild
done
# результат: platform/android/java/lib/libs/release/{arm64-v8a,armeabi-v7a}/libgodot_android.so

# 4. Шаблоны: берём ОБЫЧНЫЕ шаблоны 4.7 и подменяем в них libgodot_android.so
#    (Java-часть та же, версия движка та же). Скрипт make_templates.py — ниже.
L=platform/android/java/lib/libs/release
python3 make_templates.py ~/.local/share/godot/export_templates/4.7.stable $W/templates release \
  arm64-v8a=$L/arm64-v8a/libgodot_android.so armeabi-v7a=$L/armeabi-v7a/libgodot_android.so
# получится $W/templates/android_release.apk и $W/templates/android_source_release.zip

# 5. Проверка: Linux-сборка с тем же профилем (≈ 6–9 мин) и тесты проекта на ней
scons -j4 platform=linuxbsd target=template_debug optimize=speed_trace disable_path_overrides=no \
  build_profile=$P/tools/engine_build_profile.gdbuild
GODOT=$PWD/bin/godot.linuxbsd.template_debug.x86_64 $P/tests/run_tests.sh
```

Подключение к экспорту (в `export_presets.cfg` или в окне экспорта редактора):

* пресет «Android» (APK): `custom_template/release="<W>/templates/android_release.apk"`
  — экспортировать **release** (`--export-release`). Debug-шаблон не собирался;
  для телефона годится release APK, подписанный тестовым ключом
  (переменные `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`).
* пресет «Android AAB» (gradle): `gradle_build/android_source_template="<W>/templates/android_source_release.zip"`,
  затем удалить старую папку `android/` проекта и экспортировать с
  `--install-android-build-template --export-release "Android AAB" out.aab`.
* Пути в пресете абсолютные — их лучше не коммитить, а ставить на машине, где
  лежат шаблоны.

### make_templates.py

```python
#!/usr/bin/env python3
"""Подмена libgodot_android.so в обычных шаблонах 4.7.
usage: make_templates.py <stock_templates_dir> <out_dir> <release|debug> <arch>=<so> [...]"""
import io, sys, zipfile, os
stock, out, kind = sys.argv[1:4]
libs = dict(a.split("=", 1) for a in sys.argv[4:])
os.makedirs(out, exist_ok=True)

def rewrite(src_bytes, prefix):
    zin = zipfile.ZipFile(io.BytesIO(src_bytes))
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zout:
        for info in zin.infolist():
            name = info.filename
            if name.startswith(prefix):
                arch = name[len(prefix):].split("/")[0]
                if arch not in libs:
                    continue  # лишние архитектуры убираем
                data = open(libs[arch], "rb").read() if name.endswith("libgodot_android.so") else zin.read(name)
            elif name.startswith("META-INF/") and name.upper().endswith((".SF", ".RSA", ".EC", "MANIFEST.MF")):
                continue  # старая подпись; Godot подпишет заново
            else:
                data = zin.read(name)
            zi = zipfile.ZipInfo(name, info.date_time)
            zi.compress_type = info.compress_type
            zi.external_attr = info.external_attr
            zout.writestr(zi, data)
    return buf.getvalue()

apk = open(os.path.join(stock, f"android_{kind}.apk"), "rb").read()
open(os.path.join(out, f"android_{kind}.apk"), "wb").write(rewrite(apk, "lib/"))
src = zipfile.ZipFile(os.path.join(stock, "android_source.zip"))
buf = io.BytesIO()
aar = f"libs/{kind}/godot-lib.template_{kind}.aar"
with zipfile.ZipFile(buf, "w") as zout:
    for info in src.infolist():
        data = src.read(info.filename)
        if info.filename == aar:
            data = rewrite(data, "jni/")
        zi = zipfile.ZipInfo(info.filename, info.date_time)
        zi.compress_type = info.compress_type
        zi.external_attr = info.external_attr
        zout.writestr(zi, data)
open(os.path.join(out, f"android_source_{kind}.zip"), "wb").write(buf.getvalue())
```

## Как был получен список классов

Редактор Godot умеет искать используемые классы («Проект → Инструменты →
Конфигурация компиляции движка → Определить из проекта»), но только в окне
редактора. Здесь то же сделано скриптом (более осторожно): из стандартного
Godot 4.7 выгружен список всех классов с методами/свойствами; класс считается
нужным, если его имя встречается в коде/сценах/импортированных ресурсах
(`.godot/imported`), или он возвращается методами/свойствами, которые вызывает
код, плюс принудительный список (GDScript, PackedScene, Theme, ImageTexture,
ViewportTexture, PopupMenu для LineEdit, OggPacketSequence, DPITexture…) и
все наследники Font, InputEvent, StyleBox, Window. Остальные наследники
Node/Resource выключены. Можно также открыть этот файл в окне
«Конфигурация компиляции движка» редактора и поправить галочками.

## Риски

* Новый класс в коде без правки профиля → не работает только в облегчённой
  сборке (в редакторе всё будет хорошо). Обязательно гонять тесты на
  облегчённой Linux-сборке перед выпуском.
* На реальном телефоне облегчённая сборка ещё не запускалась (в облаке нет
  эмулятора). Перед загрузкой в Play — поставить APK на телефон и пройти
  главный экран, уровень, 3D-дом, ввод имени, звук.
* Только латиница/кириллица (text_server_fb).
* Шаблоны собраны из официального архива 4.7-stable; при переходе на новую
  версию Godot всё пересобрать.

## Обязательно перед каждой сборкой для телефона/Play (урок 0.18)
В облегчённом движке вырезаны неиспользуемые классы (например, CanvasTexture).
Тесты на обычном редакторе этого не ловят. Перед сборкой прогнать тесты и на облегчённом движке:
`GODOT=<W>/bin/slim_linux_template_debug bash tests/run_tests.sh`
(0.18: игра не запускалась на телефоне из-за CanvasTexture в hero_art.gd).
