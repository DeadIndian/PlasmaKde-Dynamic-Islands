#!/usr/bin/env bash
# Lints every QML file in the package, failing only on syntax and import
# errors. Semantic warnings are ignored on purpose: Plasma's private modules
# resolve at runtime but not for qmllint, so those warnings are noise here.
set -uo pipefail

LINT=/usr/lib64/qt6/bin/qmllint
QMLDIR=/usr/lib64/qt6/qml
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -x "$LINT" ]]; then
    echo "error: $LINT not found" >&2
    exit 1
fi

fail=0
while IFS= read -r file; do
    out=$("$LINT" -I "$QMLDIR" -I "$ROOT/package/contents/ui" "$file" 2>&1 \
        | grep -E '\[syntax\]|\[import\]|^Error:')
    if [[ -n "$out" ]]; then
        echo "FAIL $file"
        echo "$out"
        fail=1
    fi
done < <(find "$ROOT/package" -name '*.qml' | sort)

if [[ $fail -eq 0 ]]; then
    echo "qmlcheck: OK"
fi
exit $fail
