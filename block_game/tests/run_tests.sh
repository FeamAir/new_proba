#!/usr/bin/env bash
# Запуск тестов логики. Падает (код 1), если есть проваленная проверка ИЛИ ошибка скрипта:
# Godot при ошибке скрипта молча пропускает остаток функции, поэтому смотрим и на вывод.
# Запускаются все файлы tests/test_*.gd по очереди.
# Использование: GODOT=/путь/к/godot tests/run_tests.sh
set -u
GODOT="${GODOT:-godot}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOTAL=0
BAD=0
for T in "$DIR"/tests/test_*.gd; do
  NAME="tests/$(basename "$T")"
  echo "== $NAME"
  OUT="$(timeout 300 "$GODOT" --headless --path "$DIR" -s "$NAME" 2>&1)"
  CODE=$?
  echo "$OUT" | grep -E "^\s+(ok|FAIL)|Итог|SCRIPT ERROR|Parse Error|   at: " || true
  OKS=$(echo "$OUT" | grep -cE "^\s+ok")
  TOTAL=$((TOTAL + OKS))
  if [ $CODE -ne 0 ] || echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|FAIL"; then
    BAD=1
  fi
done
if [ $BAD -ne 0 ]; then
  echo "ТЕСТЫ НЕ ПРОШЛИ (проверок ok: $TOTAL)"; exit 1
fi
echo "ТЕСТЫ ПРОШЛИ: $TOTAL проверок"
