#!/usr/bin/env bash
# Lints every QML file in the package, failing only on syntax and import
# errors. Semantic warnings are ignored on purpose: Plasma's private modules
# resolve at runtime but not for qmllint, so those warnings are noise here.
# Type-level "X was not found" warnings are also noise when the module's
# qmltypes is incomplete (e.g. org.kde.plasma.private.volume registers types
# the qmltypes file does not declare); genuine failures say "Failed to import"
# or "not installed" and still fail the gate.
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
        | grep -E '\[syntax\]|\[import\]|^Error:' \
        | grep -v 'was not found')
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
