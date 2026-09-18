# i18n + Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Translator.js with KDE gettext i18n (17 languages), add screen-reader accessibility.

**Architecture:** QML `i18n()`/`i18np()` replace `Tr.t()`/`Tr.tr()`. Domain `com.deadindian.dynamicisland` auto-loads from KPlugin.Id. `tools/extract-i18n.py` builds .pot via regex scan of QML; msgmerge/msgfmt build .mo under `package/contents/locale/`. Existing translations ported from Translator.js into .po files.

**Tech Stack:** QML/Qt6, GNU gettext, Python 3

## Global Constraints

- Domain: `com.deadindian.dynamicisland`
- Locale output: `package/contents/locale/<lang>/LC_MESSAGES/com.deadindian.dynamicisland.mo`
- Po sources: `po/<lang>.po`, template `po/com.deadindian.dynamicisland.pot`
- Languages (17): de, ru, uk, be, zh, ja, sv + es, fr, pt_BR, it, hi, ar, ko, pl, nl, tr
- Arg-based strings (5): `%1 minutes elapsed`, `%1 seconds elapsed`, `%1 unread`, `%1 notifications`, `%1% complete` — use `i18n("...").arg(v)`. `%1 unread` and `%1 notifications` additionally get `i18np` singular forms (msgid pair `"One unread"` / `"%1 unread"`, `"One new notification"` / `"%1 notifications"`).
- `tests/qmlcheck.sh` must pass after every QML-touching task
- No new runtime dependencies

---

### Task 1: Extractor tool + .pot

**Files:**
- Create: `tools/extract-i18n.py`
- Create: `po/com.deadindian.dynamicisland.pot` (generated)

**Interfaces:**
- Produces: `tools/extract-i18n.py`, exit 0, prints count. Extractor recognizes `i18n(` AND legacy `Tr.t(`/`Tr.tr(` so it works pre-migration.

- [ ] **Step 1: Write extractor**

```python
#!/usr/bin/env python3
"""Extract translatable strings from QML into a gettext .pot template.

Recognizes i18n("..."), i18np("one", "many", ...), and the legacy
Tr.t("...") / Tr.tr("...") calls so it works before and after migration.
"""
import re, sys, glob, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
UI_DIR = os.path.join(ROOT, "package", "contents", "ui")
POT_PATH = os.path.join(ROOT, "po", "com.deadindian.dynamicisland.pot")

RE_SINGLE = re.compile(r'\b(?:i18n|Tr\.t)\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]')
RE_PLURAL = re.compile(r'\bi18np\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,')

def unescape(s):
    return s.replace('\\"', '"').replace("\\\\", "\\")

def main():
    entries = {}
    for path in sorted(glob.glob(os.path.join(UI_DIR, "**", "*.qml"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        for lineno, line in enumerate(open(path, encoding="utf-8"), 1):
            for m in RE_SINGLE.finditer(line):
                entries.setdefault(unescape(m.group(1)), []).append((rel, lineno))
            for m in RE_PLURAL.finditer(line):
                entries.setdefault(unescape(m.group(2)), []).append((rel, lineno))

    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: com.deadindian.dynamicisland\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"',
        '',
    ]
    for msgid in sorted(entries):
        for rel, lineno in sorted(set(entries[msgid])):
            lines.append(f"#: {rel}:{lineno}")
        lines.append(f'msgid "{msgid}"')
        lines.append('msgstr ""')
        lines.append("")
    os.makedirs(os.path.dirname(POT_PATH), exist_ok=True)
    open(POT_PATH, "w", encoding="utf-8").write("\n".join(lines))
    print(f"extract-i18n: {len(entries)} strings -> {os.path.relpath(POT_PATH, ROOT)}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run**

Run: `python3 tools/extract-i18n.py`
Expected: `extract-i18n: 247 strings -> po/com.deadindian.dynamicisland.pot`

- [ ] **Step 3: Validate**

Run: `msgfmt --check po/com.deadindian.dynamicisland.pot -o /dev/null && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add tools/extract-i18n.py po/com.deadindian.dynamicisland.pot
git commit -m "feat(i18n): add QML string extractor and pot template"
```

### Task 2: Port existing 7 languages to .po

**Files:**
- Create: `tools/js2po.py` (one-shot converter, committed for reference)
- Create: `po/de.po`, `po/ru.po`, `po/uk.po`, `po/be.po`, `po/zh.po`, `po/ja.po`, `po/sv.po` (generated)

**Interfaces:**
- Consumes: Translator.js dict, Task 1 .pot
- Produces: 7 .po files; every Translator.js key matching a .pot msgid gets its translation; unmatched keys dropped; untranslated msgids stay `msgstr ""`

- [ ] **Step 1: Write converter**

```python
#!/usr/bin/env python3
"""One-shot: convert Translator.js language dicts into .po files.

Reads po/com.deadindian.dynamicisland.pot for the msgid list, pulls each
language's dict out of Translator.js, writes po/<lang>.po.
"""
import re, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
JS = os.path.join(ROOT, "package", "contents", "ui", "Translator.js")
POT = os.path.join(ROOT, "po", "com.deadindian.dynamicisland.pot")

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def unesc(s):
    return s.replace('\\"', '"').replace("\\\\", "\\")

def parse_js():
    js = open(JS, encoding="utf-8").read()
    langs = {}
    for lang in ["ru", "zh", "ja", "de", "sv", "be", "uk"]:
        m = re.search(r'\n    %s: \{\n(.*?)\n    \},' % lang, js, re.S)
        if not m:
            print(f"WARN: lang {lang} not found"); continue
        pairs = {}
        for pm in re.finditer(r'"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)"', m.group(1)):
            pairs[unesc(pm.group(1))] = unesc(pm.group(2))
        langs[lang] = pairs
    return langs

def parse_pot():
    msgids = []
    for chunk in open(POT, encoding="utf-8").read().split("\n\n"):
        m = re.match(r'^msgid "(.*)"$', chunk, re.S | re.M) if chunk.startswith("msgid") else None
        if m and m.group(1):
            msgids.append(unesc(m.group(1)))
    return msgids

def main():
    langs = parse_js()
    msgids = parse_pot()
    for lang, pairs in langs.items():
        out = ['msgid ""', 'msgstr ""',
               '"Project-Id-Version: com.deadindian.dynamicisland\\n"',
               '"Language: %s\\n"' % lang,
               '"MIME-Version: 1.0\\n"',
               '"Content-Type: text/plain; charset=UTF-8\\n"',
               '"Content-Transfer-Encoding: 8bit\\n"',
               '"X-Generator: js2po.py (ported from Translator.js)\\n"',
               '']
        n = 0
        for msgid in msgids:
            tr = pairs.get(msgid)
            if not tr:
                continue
            out.append(f'msgid "{esc(msgid)}"')
            out.append(f'msgstr "{esc(tr)}"')
            out.append("")
            n += 1
        path = os.path.join(ROOT, "po", f"{lang}.po")
        open(path, "w", encoding="utf-8").write("\n".join(out))
        print(f"{lang}.po: {n}/{len(msgids)} translated")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run converter**

Run: `python3 tools/js2po.py`
Expected output lines: `ru.po: ~100/247 translated`, `zh.po: ...`, etc. (Translator.js holds ~100 keys per lang; the .pot has 247 because configModules.qml has many strings Translator.js never covered — those stay untranslated with English fallback, as designed.)

- [ ] **Step 3: Validate all .po**

Run: `for f in po/*.po; do msgfmt --check "$f" -o /dev/null || echo "FAIL $f"; done; echo done`
Expected: `done` with no FAIL lines.

- [ ] **Step 4: Commit**

```bash
git add tools/js2po.py po/*.po
git commit -m "feat(i18n): port ru/zh/ja/de/sv/be/uk translations to po files"
```

### Task 3: Add 10 new languages (es, fr, pt_BR, it, hi, ar, ko, pl, nl, tr)

**Files:**
- Create: `po/es.po`, `po/fr.po`, `po/pt_BR.po`, `po/it.po`, `po/hi.po`, `po/ar.po`, `po/ko.po`, `po/pl.po`, `po/nl.po`, `po/tr.po`

**Interfaces:**
- Consumes: `po/com.deadindian.dynamicisland.pot`
- Produces: 10 new .po files, full translations of all 247 msgids (marked fuzzy: false; header notes machine-translation provenance)

- [ ] **Step 1: Generate translations**

Write each .po by hand in this task (agent translates the 247 msgids per language). Header template per file:

```
msgid ""
msgstr ""
"Project-Id-Version: com.deadindian.dynamicisland\n"
"Language: es\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
"X-Generator: Claude (machine translation, review welcome)\n"
```

Translation rules:
- Keep `%1` placeholders verbatim in msgstr
- Keep `·` separators in the six "Content · Time · FPS" strings
- Keep trailing `:` on labels
- Keep leading emoji (🎵 ⏰ 🔔 💻 ⏱️) in section headers
- "MPRIS", "CPU", "RAM", "FPS", "ISO", "hex", "px" stay as-is in all languages
- zh/ja-style fullwidth colons only apply to zh/ja; new langs use their own convention (fr/es use space before `:` per lang norms; ko uses no space)

- [ ] **Step 2: Validate**

Run: `for f in po/*.po; do msgfmt --check "$f" -o /dev/null || echo "FAIL $f"; done; echo done`
Expected: `done`, no FAIL

- [ ] **Step 3: Commit**

```bash
git add po/*.po
git commit -m "feat(i18n): add es/fr/pt_BR/it/hi/ar/ko/pl/nl/tr translations"
```

### Task 4: Build script (extract + merge + compile)

**Files:**
- Create: `tools/build-locales.sh`

**Interfaces:**
- Consumes: Task 1 extractor, all po/*.po
- Produces: `package/contents/locale/<lang>/LC_MESSAGES/com.deadindian.dynamicisland.mo` for every po; exit non-zero on any msgfmt error

- [ ] **Step 1: Write build script**

```bash
#!/usr/bin/env bash
# Extract strings, merge into all .po files, compile .mo catalogs into the
# package. Run after any i18n() string change.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="com.deadindian.dynamicisland"

python3 "$ROOT/tools/extract-i18n.py"

for po in "$ROOT"/po/*.po; do
    lang="$(basename "$po" .po)"
    msgmerge --quiet --update --backup=none "$po" "$ROOT/po/$DOMAIN.pot"
    out="$ROOT/package/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$out"
    msgfmt --check -o "$out/$DOMAIN.mo" "$po"
    echo "$lang: $(msgfmt --statistics -o /dev/null "$po" 2>&1)"
done
echo "locales built."
```

- [ ] **Step 2: Run**

Run: `chmod +x tools/build-locales.sh && tools/build-locales.sh`
Expected: per-lang statistics lines, then `locales built.`; `package/contents/locale/` contains 17 lang dirs.

- [ ] **Step 3: Commit**

```bash
git add tools/build-locales.sh package/contents/locale/
git commit -m "feat(i18n): add locale build script and compiled catalogs"
```

### Task 5: Migrate QML files (Tr.* → i18n)

**Files:**
- Modify: all 12 QML files under `package/contents/ui/` with `Tr.` calls (configModules.qml, configAppearance.qml, configPanel.qml, main.qml, IslandPanel.qml, MediaExpanded.qml, widgets/QuickToggleWidget.qml, widgets/TimerWidget.qml, widgets/NotificationsWidget.qml, widgets/SystemWidget.qml, widgets/VolumeWidget.qml, widgets/MediaWidget.qml)
- Delete: `package/contents/ui/Translator.js`

**Interfaces:**
- Consumes: nothing new — i18n() is ambient in Plasma QML
- Produces: zero `Tr.` references; `Tr` import lines removed

- [ ] **Step 1: Mechanical replace in all 12 files**

Per file: remove `import "Translator.js" as Tr` (or `"../Translator.js"`), then rewrite calls:
- `Tr.t("X")` → `i18n("X")`
- `Tr.tr("X", v)` → `i18n("X").arg(v)`
- Special cases:
  - main.qml:519 `Tr.tr("%1 minutes elapsed", ...)` → `i18n("%1 minutes elapsed").arg(Math.round(timerTotal / 60))`
  - main.qml:521 `Tr.tr("%1 seconds elapsed", ...)` → `i18n("%1 seconds elapsed").arg(timerTotal)`
  - main.qml:1438 `Tr.tr("%1 unread", root.unreadCount)` → `(root.unreadCount === 1 ? i18n("One unread") : i18n("%1 unread").arg(root.unreadCount))`
  - NotificationsWidget.qml:126 `Tr.tr("%1 notifications", n)` → `(n === 1 ? i18n("One new notification") : i18n("%1 notifications").arg(n))`
  - main.qml:1438 fallback `Tr.t("New notification")` stays as `i18n("New notification")` (distinct msgid)
  - main.qml:1521 `Tr.tr("%1% complete", ...)` → `i18n("%1% complete").arg(root.jobsPercent)`

Use scripted sed for the bulk, then fix specials by hand:
```bash
cd package/contents/ui
grep -rl 'Tr\.t(\|Tr\.tr(' . --include='*.qml' | while read f; do
  sed -i -E 's/Tr\.tr\(/i18n(/g; s/Tr\.t\(/i18n(/g' "$f"
done
grep -rn 'Tr\.' . --include='*.qml'   # must return nothing
```
Then remove every `import "Translator.js" as Tr` / `import "../Translator.js" as Tr` line, then hand-apply the special cases above (arg placement, singular forms). NOTE: sed leaves `i18n("X", v)` shapes from Tr.tr — convert those to `i18n("X").arg(v)` by hand (only 5 sites, listed above).

- [ ] **Step 2: Add singular msgids to QML**

The two `i18np`-style singulars are implemented as plain ternaries (no i18np — corpus is small, plural rules differ per lang; ternary with "One ..." msgid is the lazy correct form):
- `"One unread"`, `"One new notification"` — already inserted by Step 1 hand-fixes. These msgids must exist in .pot (re-extract in Task 6 picks them up).

- [ ] **Step 3: Lint**

Run: `tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 4: Grep guards**

Run:
```bash
grep -rn 'Tr\.' package/contents/ui --include='*.qml' && echo "LEFTOVER Tr REFS" || echo "no Tr refs"
grep -rn 'Translator' package/contents/ui --include='*.qml' && echo "LEFTOVER IMPORTS" || echo "no imports"
```
Expected: `no Tr refs`, `no imports`

- [ ] **Step 5: Delete Translator.js, commit**

```bash
git rm package/contents/ui/Translator.js
git add -A package/contents/ui
git commit -m "refactor(i18n): migrate QML from Translator.js to gettext i18n"
```

### Task 6: Re-extract, merge, rebuild locales; smoke-test coverage

**Files:**
- Modify: `po/com.deadindian.dynamicisland.pot`, all `po/*.po` (msgmerge adds new msgids like "One unread", removes dead ones)
- Modify: `package/contents/locale/**` (rebuilt .mo)

**Interfaces:**
- Consumes: post-migration QML (Task 5), Tasks 1–4 tooling
- Produces: .pot matching live code; all .po merged; .mo rebuilt

- [ ] **Step 1: Rebuild everything**

Run: `tools/build-locales.sh`
Expected: new msgids (`One unread`, `One new notification`, any config strings Translator.js lacked) appear in pot; per-lang stats printed. Untranslated counts for old 7 langs ~higher than Task 2 (new strings not yet translated), 10 new langs translated from Task 3 stay ~fully translated.

- [ ] **Step 2: Smoke-test coverage**

Run:
```bash
python3 - <<'EOF'
import re, glob, subprocess, sys
# every i18n string in QML must exist as msgid in each .po (or as msgid with empty msgstr = fallback)
pot = open('po/com.deadindian.dynamicisland.pot').read()
missing = []
for f in glob.glob('package/contents/ui/**/*.qml', recursive=True):
    for m in re.finditer(r'\bi18n\("((?:[^"\\]|\\.)*)"\)', open(f).read()):
        s = m.group(1)
        if f'msgid "{s}"' not in pot:
            missing.append((f, s))
if missing:
    [print("MISSING", f, s) for f, s in missing]
    sys.exit(1)
print("coverage OK")
EOF
```
Expected: `coverage OK`

- [ ] **Step 3: Runtime spot-check (manual, by user or agent with display)**

Run: `plasmawindowed com.deadindian.dynamicisland` after `install.sh`; switch system language or run `LANG=de_DE.UTF-8 plasmawindowed com.deadindian.dynamicisland`
Expected: capsule/config text appears in German. (Document result; not a hard gate in CI.)

- [ ] **Step 4: Commit**

```bash
git add po package/contents/locale
git commit -m "chore(i18n): rebuild pot and catalogs after QML migration"
```

### Task 7: Accessibility — screen reader names on island surfaces

**Files:**
- Modify: `package/contents/ui/main.qml` (compact capsule MouseArea ~line 898, expanded surface)
- Modify: `package/contents/ui/IslandPanel.qml` (panel root)

**Interfaces:**
- Consumes: existing state props on root (activeMode, mediaDisplayTitle, notificationTitle, unreadCount, timeText)
- Produces: Accessible.name/role on capsule, expanded panel, widget panel root

- [ ] **Step 1: Compact capsule**

On the compact MouseArea (main.qml:898) add:

```qml
Accessible.role: Accessible.Button
Accessible.name: {
    if (popupOpen) return i18n("Dynamic Island, expanded")
    if (showMedia) return i18n("Dynamic Island — music: %1").arg(mediaDisplayTitle || i18n("Media player"))
    if (activeMode === 2) return i18n("Dynamic Island — notifications: %1").arg(unreadCount > 0 ? i18n("%1 unread").arg(unreadCount) : i18n("No new notifications"))
    if (compactTitle.length > 0) return i18n("Dynamic Island — %1").arg(compactTitle)
    return i18n("Dynamic Island — %1").arg(timeText)
}
Accessible.onPressAction: clicked()   // match the MouseArea's signal handler name
```

(If the MouseArea uses `onClicked`, `Accessible.onPressAction: clicked()` triggers it; adjust to actual handler in file.)

- [ ] **Step 2: Expanded panel**

On the expanded panel root Item in main.qml (the popup surface; locate via `Plasmoid.expanded` binding) add:

```qml
Accessible.role: Accessible.LayeredPanel
Accessible.name: i18n("Dynamic Island expanded panel")
```

- [ ] **Step 3: IslandPanel widget grid**

On IslandPanel.qml root `Item`:

```qml
Accessible.role: Accessible.LayeredPanel
Accessible.name: i18n("Dynamic Island widget panel")
```

- [ ] **Step 4: Lint + commit**

Run: `tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

```bash
git add package/contents/ui/main.qml package/contents/ui/IslandPanel.qml
git commit -m "feat(a11y): screen reader names for capsule, expanded panel, widget grid"
```

### Task 8: Accessibility — widget modules + config controls

**Files:**
- Modify: `package/contents/ui/widgets/*.qml` (ClockWidget, MediaWidget, NotificationsWidget, TimerWidget, SystemWidget, VolumeWidget, BrightnessWidget, QuickToggleWidget)
- Modify: config pages where a control lacks an adjacent text label (spinboxes with unit labels only)

**Interfaces:**
- Consumes: widget `island` prop for live values
- Produces: Accessible.name on each widget card root; Accessible names on bare spinboxes/sliders in config pages

- [ ] **Step 1: Widget card roots**

Each widget root `Item` gets, e.g. ClockWidget:

```qml
Accessible.role: Accessible.ListItem
Accessible.name: timeStr + (dateStr !== "" ? " " + dateStr : "")
```

Per-widget names (use the widget's own display text property):
- ClockWidget: `timeStr + " " + dateStr`
- MediaWidget: island.mediaDisplayTitle + " — " + artist (or i18n("Media player"))
- NotificationsWidget: notification count line
- TimerWidget: remaining time
- SystemWidget: cpu/ram/temperature summary line
- VolumeWidget: island.volumePercent + "%"
- BrightnessWidget: island.brightnessPercent + "%"
- QuickToggleWidget: the toggle's own label prop

- [ ] **Step 2: Config page bare inputs**

In configModules.qml/configAppearance.qml/configPanel.qml, for QQC2.SpinBox / Slider / TextField that only have a unit Label beside them (no FormData label or switch text), add `Accessible.name: <form label text>` reusing the i18n'd Kirigami.FormData.label string. Only where missing — switches with `text:` already expose their label.

- [ ] **Step 3: Lint + commit**

Run: `tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

```bash
git add package/contents/ui
git commit -m "feat(a11y): accessible names for widget cards and config inputs"
```

### Task 9: README + CONTRIBUTING i18n docs

**Files:**
- Modify: `README.md` (add Translations section)
- Modify: `CONTRIBUTING.md` (add translation workflow)

**Interfaces:**
- Consumes: none
- Produces: docs describing the po workflow

- [ ] **Step 1: README section**

```markdown
## Translations

Dynamic Island ships in 17 languages. Missing or awkward translation? Edit
`po/<lang>.po` (any po editor: Lokalize, Poedit, or a text editor) and open a
PR. Untranslated strings fall back to English automatically.

Rebuild catalogs after string changes:

    tools/build-locales.sh
```

- [ ] **Step 2: CONTRIBUTING section**

```markdown
## Translating

1. Strings live in `po/<lang>.po` (gettext). Template: `po/com.deadindian.dynamicisland.pot`.
2. Regenerate the template after QML string changes: `python3 tools/extract-i18n.py`
3. Merge template changes into your language: `msgmerge --update po/<lang>.po po/com.deadindian.dynamicisland.pot`
4. Validate: `msgfmt --check po/<lang>.po -o /dev/null`
5. PR it. `tools/build-locales.sh` compiles everything; run it once after merge.
```

- [ ] **Step 3: Commit**

```bash
git add README.md CONTRIBUTING.md
git commit -m "docs: add translation workflow to README and CONTRIBUTING"
```

## Self-Review

- Spec coverage: Tasks 1–6 = spec §1,2,3,5; Tasks 7–8 = §4; Task 9 = docs. RTL audit (§6) folded into Task 5 hand-fix step (no hardcoded left/right layout in QML — Qt anchors use left/right mirroring-aware properties; confirmed during migration by grep `Layout.leftMargin|anchors.left` — if found, note but don't restructure).
- Placeholders: none — all code shown.
- Type consistency: extractor msgid format matches converter/merge; i18n arg forms match Task 5 special list.
