# i18n + Accessibility Design — Dynamic Island Plasmoid

Date: 2026-09-18
Status: Approved

## Goal

Replace custom `Translator.js` with standard KDE gettext i18n, expand from 7 to 17 languages, add screen-reader accessibility.

## Decisions (user-approved)

- Standard KDE i18n (po/mo gettext), not JS dictionaries
- Broad language coverage: 17 languages
- Claude generates initial translations; native review later
- Full migration: Translator.js deleted, all call sites converted
- Accessibility: screen reader support + font scaling via Plasma Units

## 1. i18n Architecture

- QML uses `i18n("...")`, `i18np("one", "%1 many", n)`, `.arg()` for placeholders
- Domain `com.deadindian.dynamicisland` auto-loads from `KPlugin.Id` — no engine setup
- Compiled catalogs: `package/contents/locale/<lang>/LC_MESSAGES/com.deadindian.dynamicisland.mo`
- Sources: `po/<lang>.po` + `po/com.deadindian.dynamicisland.pot`
- `Translator.js` deleted after migration
- Untranslated msgid falls back to English (gettext default) — no breakage from missing keys

## 2. Languages

Existing (port from Translator.js): ru, zh, ja, de, sv, be, uk
New: es, fr, pt-BR (pt_BR), it, hi, ar, ko, pl, nl, tr
Total: 17. Locale selection handled by KDE — no custom detection.

## 3. Migration

- 13 QML files, ~249 call sites: `Tr.t("X")` → `i18n("X")`; `Tr.tr("X", v)` → `i18n("X").arg(v)`
- Plurals: `Tr.tr("%1 unread", n)` → `i18np("One unread", "%1 unread", n)`
- Config pages (`configAppearance.qml`, `configModules.qml`, `configPanel.qml`) converted too
- Remove `import "Translator.js" as Tr` lines

## 4. Accessibility

- `Accessible.role` + `Accessible.name` on: compact capsule, expanded panel, each widget module
- Example: capsule reads "Dynamic Island — music: <title> by <artist>"
- Config controls get `Accessible.name` where label not adjacent
- Font scaling: replace hardcoded `pixelSize` with Plasma `Units` where feasible, so desktop font-size setting is respected
- Build status indicators already text+color — no change needed

## 5. Tooling

- `tools/extract-i18n.py` — regex-based QML string extractor → writes `po/com.deadindian.dynamicisland.pot`
- `tools/build-locales.sh` — extract, msgmerge all .po, msgfmt into `package/contents/locale/`
- `msgfmt --check` validates every .po (catches %1 format-string mistakes)
- Existing `tests/qmlcheck.sh` must pass after migration
- New smoke test: every `i18n()` string in QML exists in .pot

## 6. Edge Cases

- RTL (ar): Qt mirrors layouts automatically; audit hardcoded left/right anchors during migration
- Adding strings later: translators update .po; English fallback until translated

## Non-Goals

- Weblate/hosted translation platform setup
- Native speaker review of machine-generated translations (marked as needing review in .po headers)
- Keyboard nav, contrast/colorblind changes (not selected)
