"""Собирает страницу политики конфиденциальности (RU + EN) для GitHub Pages.
Запуск: python3 tools/make_privacy_site.py  ->  store/privacy_site/index.html"""
import re, os, markdown
base = os.path.join(os.path.dirname(__file__), "..", "store")
def body(name):
    text = open(os.path.join(base, "legal", name), encoding="utf-8").read()
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)  # служебные пометки не публикуем
    return markdown.markdown(text)
html = f"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cascado — Privacy Policy / Политика конфиденциальности</title>
<style>
body{{margin:0;background:#120B24;color:#F4EEFF;font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}}
main{{max-width:760px;margin:0 auto;padding:24px 16px 64px}}
h1{{color:#FFB547;line-height:1.2}} h2{{color:#3FD0FF;margin-top:1.6em}} a{{color:#FF8FD8}}
nav a{{margin-right:16px}} hr{{border:0;border-top:1px solid #2A1A4F;margin:48px 0}}
</style></head><body><main>
<nav><a href="#ru">Русский</a><a href="#en">English</a></nav>
<section id="ru">{body("privacy_policy_ru.md")}</section>
<hr>
<section id="en" lang="en">{body("privacy_policy_en.md")}</section>
</main></body></html>
"""
out = os.path.join(base, "privacy_site", "index.html")
open(out, "w", encoding="utf-8").write(html)
print("ok", out)
