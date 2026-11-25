#!/usr/bin/env bash
# Запуск тестов логики. Падает (код 1), если есть проваленная проверка ИЛИ ошибка скрипта:
# Godot при ошибке скрипта молча пропускает остаток функции, поэтому смотрим и на вывод.
# Использование: GODOT=/путь/к/godot tests/run_tests.sh
set -u
GODOT="${GODOT:-godot}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(timeout 300 "$GODOT" --headless --path "$DIR" -s tests/test_logic.gd 2>&1)"
CODE=$?
echo "$OUT" | grep -E "^\s+(ok|FAIL)|Итог|SCRIPT ERROR|Parse Error|   at: " || true
OKS=$(echo "$OUT" | grep -cE "^\s+ok")
if [ $CODE -ne 0 ] || echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|FAIL"; then
  echo "ТЕСТЫ НЕ ПРОШЛИ (проверок ok: $OKS)"; exit 1
fi
echo "ТЕСТЫ ПРОШЛИ: $OKS проверок"
