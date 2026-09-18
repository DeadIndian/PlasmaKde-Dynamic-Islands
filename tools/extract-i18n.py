#!/usr/bin/env python3
"""Extract translatable strings from QML into a gettext .pot template.

Recognizes i18n("..."), i18np("one", "many", ...), and the legacy
Tr.t("...") / Tr.tr("...") calls so it works before and after migration.
"""
import re, sys, glob, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
UI_DIR = os.path.join(ROOT, "package", "contents", "ui")
POT_PATH = os.path.join(ROOT, "po", "com.deadindian.dynamicisland.pot")

RE_SINGLE = re.compile(r'\b(?:i18n|Tr\.tr?)\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]')
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
