# Media Appearance Customisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every visual aspect of media rendering in the Dynamic Island configurable — per-line visibility, font, size, weight, colour, overflow behaviour, album art, seek bar and text templates — driven by one shared settings set across both the compact capsule and the expanded panel.

**Architecture:** A `MediaStyle.qml` object resolves configuration into ready-to-bind values and is instantiated twice, once per surface, with a different `scalePercent`. The capsule block and a new `MediaExpanded.qml` both bind to their instance. Two inline QML components currently trapped inside `main.qml` (`SoundBars`, plus new `ScrollingLabel`) are extracted into files so other files can use them.

**Tech Stack:** QML (Qt 6), Plasma 6 applet API, KConfigXT (`config/main.xml`), Kirigami, `node` for pure-JS tests, `qmllint` as a syntax/import gate.

This is phase 1 of the spec `docs/superpowers/specs/2026-08-16-media-customisation-and-widget-panel-design.md`. It ships independently. Phase 2 (widget panel) has its own plan and reuses `MediaStyle.qml`, `ScrollingLabel.qml`, `SoundBars.qml` and `IslandUtils.js` from this one.

## Global Constraints

- Pure QML only. No compiled plugin, no new runtime dependency — the applet must stay installable as a single `.plasmoid` from the KDE Store.
- Every runtime file lives under `package/contents/`. Nothing outside `package/` is referenced at runtime. `tests/` and `docs/` are repo-root only and are not shipped.
- All import and `Loader.source` paths stay **relative**. An absolute or `file://` path works from a hand-installed copy and breaks from a store-installed package.
- `X-Plasma-API-Minimum-Version` stays `6.0` in `package/metadata.json`.
- Shipped defaults must render byte-for-byte what the applet renders today. An empty string for a font family or colour means inherit. No existing user sees a visual change on upgrade.
- New user-visible strings go through `Tr.t("...")` from `Translator.js`. Do **not** add dictionary entries — `Tr.t()` falls back to its English source, and translating the new settings is explicitly out of scope.
- Font weight is stored as a numeric 100–900 (Qt accepts numeric weights); config UI presents a named combo.
- Follow the existing code's conventions: 4-space indent, `readonly property` for derived values, comments only where intent is non-obvious.

## Environment facts (already verified — do not re-probe)

- `qmllint` is at `/usr/lib64/qt6/bin/qmllint`. With `-I /usr/lib64/qt6/qml` it resolves `org.kde.*` modules. It exits 0 even on errors, so the gate greps for `[syntax]`, `[import]` and `^Error:`.
- MPRIS `MultiplexerModel` roles `track`, `artist`, `album`, `identity` are all valid strings. The model has no usable `count` property — `main.qml` already reads `mediaRepeater.count` instead.
- MPRIS `position` is writable (`write: "setPosition"`) and the container exposes `canSeek` and `Seek(offset)`. Positions and lengths are in **microseconds**.
- `Kirigami.ShadowedImage` exists (`org.kde.kirigami` primitives, since 2.0) with `radius` and `corners`. It is the rounded-image primitive to use; plain `clip: true` does not round children in Qt Quick.
- `node` is at `/usr/bin/node`.

---

### Task 1: Pure-JS helpers and the lint gate

Establishes the two checks every later task uses: a `node` test for pure logic and a `qmllint` gate for QML. `IslandUtils.js` also holds the three list helpers phase 2 needs, so the file is written once.

**Files:**
- Create: `package/contents/ui/IslandUtils.js`
- Create: `tests/islandutils.test.mjs`
- Create: `tests/qmlcheck.sh`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `formatTemplate(tpl: string, vals: object) -> string`
  - `parseWidgetList(str: string, validIds: string[]) -> string[]`
  - `serializeWidgetList(ids: string[]) -> string`
  - `mmss(seconds: number) -> string`
  - `moveItem(arr: any[], from: number, to: number) -> any[]`
  - `tests/qmlcheck.sh` — lints all package QML, exit 1 on syntax/import errors.

- [ ] **Step 1: Write the failing test**

Create `tests/islandutils.test.mjs`:

```js
// Runs the QML JS library under plain node. `.pragma library` is a valid QML
// directive but invalid JavaScript, so it is stripped before evaluating.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(
    join(here, "..", "package", "contents", "ui", "IslandUtils.js"),
    "utf8",
);
const stripped = source.replace(/^\s*\.(pragma|import)[^\n]*$/gm, "");
const U = {};
new Function(
    "exports",
    stripped +
        "\nexports.formatTemplate = formatTemplate;" +
        "\nexports.parseWidgetList = parseWidgetList;" +
        "\nexports.serializeWidgetList = serializeWidgetList;" +
        "\nexports.mmss = mmss;" +
        "\nexports.moveItem = moveItem;",
)(U);

const tokens = { title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", player: "VLC" };

// formatTemplate
assert.equal(U.formatTemplate("{title}", tokens), "Bohemian Rhapsody");
assert.equal(U.formatTemplate("{artist} — {album}", tokens), "Queen — A Night at the Opera");
assert.equal(U.formatTemplate("{title} ({player})", tokens), "Bohemian Rhapsody (VLC)");
assert.equal(U.formatTemplate("no tokens here", tokens), "no tokens here");
assert.equal(U.formatTemplate("", tokens), "");
// An unknown token stays literal so a typo is visible instead of blanking the line.
assert.equal(U.formatTemplate("{titel}", tokens), "{titel}");
// A known token with an empty value substitutes to empty, not to the literal.
assert.equal(U.formatTemplate("{artist}", { artist: "" }), "");
assert.equal(U.formatTemplate("{artist}", { artist: null }), "");
assert.equal(U.formatTemplate("{artist}", { artist: undefined }), "");

// parseWidgetList
const valid = ["media", "system", "timer", "volume", "brightness", "clock"];
assert.deepEqual(U.parseWidgetList("media,system", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("system,media", valid), ["system", "media"]);
assert.deepEqual(U.parseWidgetList(" media , system ", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("media,nope,system", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("media,media,system", valid), ["media", "system"]);
assert.deepEqual(U.parseWidgetList("", valid), []);
assert.deepEqual(U.parseWidgetList(",,", valid), []);
assert.deepEqual(U.parseWidgetList(null, valid), []);
assert.deepEqual(U.parseWidgetList(undefined, valid), []);

// serializeWidgetList round trip
assert.equal(U.serializeWidgetList(["media", "system"]), "media,system");
assert.equal(U.serializeWidgetList([]), "");
assert.equal(U.serializeWidgetList(null), "");
assert.deepEqual(
    U.parseWidgetList(U.serializeWidgetList(["timer", "clock"]), valid),
    ["timer", "clock"],
);

// mmss
assert.equal(U.mmss(0), "00:00");
assert.equal(U.mmss(9), "00:09");
assert.equal(U.mmss(59), "00:59");
assert.equal(U.mmss(60), "01:00");
assert.equal(U.mmss(599), "09:59");
assert.equal(U.mmss(3599), "59:59");
assert.equal(U.mmss(3600), "1:00:00");
assert.equal(U.mmss(3661), "1:01:01");
assert.equal(U.mmss(-5), "00:00");
assert.equal(U.mmss(12.7), "00:12");

// moveItem — returns a new array, never mutates
const base = ["a", "b", "c", "d"];
assert.deepEqual(U.moveItem(base, 0, 2), ["b", "c", "a", "d"]);
assert.deepEqual(U.moveItem(base, 3, 0), ["d", "a", "b", "c"]);
assert.deepEqual(U.moveItem(base, 1, 1), ["a", "b", "c", "d"]);
assert.deepEqual(base, ["a", "b", "c", "d"]);
// Out-of-range destinations clamp; out-of-range sources are a no-op.
assert.deepEqual(U.moveItem(base, 0, 99), ["b", "c", "d", "a"]);
assert.deepEqual(U.moveItem(base, 0, -3), ["a", "b", "c", "d"]);
assert.deepEqual(U.moveItem(base, 9, 0), ["a", "b", "c", "d"]);
assert.deepEqual(U.moveItem([], 0, 0), []);

console.log("islandutils: all assertions passed");
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node tests/islandutils.test.mjs`
Expected: FAIL — `ENOENT: no such file or directory, open '.../package/contents/ui/IslandUtils.js'`

- [ ] **Step 3: Write the implementation**

Create `package/contents/ui/IslandUtils.js`:

```js
.pragma library

// Pure helpers shared by the island and its panel widgets. Kept free of QML
// types so they can be exercised by tests/islandutils.test.mjs under node.

// Substitutes {token} placeholders from `vals`. An unrecognised token is left
// literal so a typo shows up in the UI instead of silently blanking the line.
function formatTemplate(tpl, vals) {
    if (!tpl) {
        return "";
    }
    var source = vals || {};
    return String(tpl).replace(/\{(\w+)\}/g, function (match, key) {
        if (!Object.prototype.hasOwnProperty.call(source, key)) {
            return match;
        }
        var value = source[key];
        return (value === undefined || value === null) ? "" : String(value);
    });
}

// Reads the stored widget order. Unknown ids and duplicates are dropped so a
// hand-edited or downgraded config can never produce a broken panel.
function parseWidgetList(str, validIds) {
    var out = [];
    var allowed = validIds || [];
    var parts = String(str === null || str === undefined ? "" : str).split(",");
    for (var i = 0; i < parts.length; i++) {
        var id = parts[i].trim();
        if (id.length === 0 || allowed.indexOf(id) === -1 || out.indexOf(id) !== -1) {
            continue;
        }
        out.push(id);
    }
    return out;
}

function serializeWidgetList(ids) {
    return (ids || []).join(",");
}

// Formats a duration as mm:ss, widening to h:mm:ss past an hour.
function mmss(seconds) {
    var total = Math.max(0, Math.floor(seconds || 0));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    var pad = function (n) {
        return n < 10 ? "0" + n : String(n);
    };
    if (hours > 0) {
        return hours + ":" + pad(minutes) + ":" + pad(secs);
    }
    return pad(minutes) + ":" + pad(secs);
}

// Moves one element, returning a new array. `to` clamps into range; an
// out-of-range `from` is a no-op.
function moveItem(arr, from, to) {
    var out = (arr || []).slice();
    if (from < 0 || from >= out.length) {
        return out;
    }
    var target = Math.max(0, Math.min(out.length - 1, to));
    if (target === from) {
        return out;
    }
    out.splice(target, 0, out.splice(from, 1)[0]);
    return out;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node tests/islandutils.test.mjs`
Expected: PASS — `islandutils: all assertions passed`

- [ ] **Step 5: Add the QML lint gate**

Create `tests/qmlcheck.sh`:

```bash
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
```

- [ ] **Step 6: Verify the gate passes on the untouched codebase**

Run: `chmod +x tests/qmlcheck.sh && ./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`, exit 0.

- [ ] **Step 7: Verify the gate actually catches a broken file**

Run:
```bash
printf 'import QtQuick\nItem { property int x: }\n' > package/contents/ui/ZZBroken.qml
./tests/qmlcheck.sh; echo "exit=$?"
rm package/contents/ui/ZZBroken.qml
```
Expected: `FAIL .../ZZBroken.qml`, a `[syntax]` line, `exit=1`. A gate that never fails is not a gate.

- [ ] **Step 8: Commit**

```bash
git add package/contents/ui/IslandUtils.js tests/islandutils.test.mjs tests/qmlcheck.sh
git commit -m "test: add pure JS helpers with node tests and a qmllint gate"
```

---

### Task 2: Extract SoundBars into its own file

`SoundBars` is currently an inline `component` at `package/contents/ui/main.qml:1339-1383`. Inline components are not reachable from other files, and `MediaExpanded.qml` (Task 6) plus phase 2's media widget both need it. Because the extracted file is named `SoundBars.qml` in the same directory, the type name `SoundBars` keeps resolving at all three existing call sites — only the properties it used to read off `root` must now be passed in.

**Files:**
- Create: `package/contents/ui/SoundBars.qml`
- Modify: `package/contents/ui/main.qml` (delete lines 1339-1383; edit 3 call sites)

**Interfaces:**
- Consumes: nothing.
- Produces: `SoundBars` QML type with `playing: bool`, `barColor: color`, `animate: bool`.

- [ ] **Step 1: Create the extracted file**

Create `package/contents/ui/SoundBars.qml`. This is the inline component's body verbatim, with `root.textPrimary` replaced by the new `barColor` property and the animation additionally gated on `animate`:

```qml
import QtQuick

// The five-bar equaliser. Extracted from main.qml so the expanded media view
// and the panel's media widget can both use it.
Row {
    id: bars

    property bool playing: false
    property color barColor: "white"
    property bool animate: true

    spacing: 5
    width: 44
    height: 34

    Repeater {
        model: [18, 27, 14, 24, 20]

        Rectangle {
            id: bar

            width: 4
            height: modelData
            y: (parent.height - height) / 2
            radius: 2
            color: bars.barColor
            opacity: bars.playing ? 0.9 : 0.55
            transformOrigin: Item.Center
            transform: Scale {
                origin.x: bar.width / 2
                origin.y: bar.height / 2
                xScale: 1
                yScale: bars.playing ? 1 : 0.45

                SequentialAnimation on yScale {
                    running: bars.playing && bars.animate
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.35 + ((index * 17) % 45) / 100
                        duration: 260 + index * 45
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 260 + index * 45
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Delete the inline component from main.qml**

In `package/contents/ui/main.qml`, delete the entire `component SoundBars: Row { ... }` block (lines 1339-1383, the last component before the file's closing brace).

- [ ] **Step 3: Pass the new properties at all three call sites**

Site 1 — in `compactContentBlock` (was around `main.qml:809`):

```qml
            SoundBars {
                visible: root.activeMode === 0
                playing: root.mediaPlaying
                barColor: root.textPrimary
                animate: root.animationsEnabled
                Layout.preferredWidth: 30
                Layout.preferredHeight: 26
            }
```

Site 2 — `musicBars` in `musicExpanded` (was around `main.qml:972`):

```qml
            SoundBars {
                id: musicBars
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 16
                width: 38
                height: 28
                playing: root.mediaPlaying
                barColor: root.textPrimary
                animate: root.animationsEnabled
            }
```

Site 3 — `notifBars` in `notificationExpanded` (was around `main.qml:1103`):

```qml
            SoundBars {
                id: notifBars
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 14
                width: 32
                height: 24
                playing: notificationPulse.running
                barColor: root.textPrimary
                animate: root.animationsEnabled
            }
```

`barColor: root.textPrimary` is not optional at any site: the inline version read `root.textPrimary` directly, so omitting it would silently switch those bars to the default white and break the `followSystemTheme` setting.

- [ ] **Step 4: Run the lint gate**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 5: Verify no behaviour change in the running applet**

Run: `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di.log`
Expected: no `QQmlApplicationEngine`/`file://` error lines in `/tmp/di.log`. Start a media player and confirm the bars animate in both the capsule and the expanded panel exactly as before. Close the window when done.

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/SoundBars.qml package/contents/ui/main.qml
git commit -m "refactor: extract SoundBars into its own file"
```

---

### Task 3: ScrollingLabel

A label that renders plainly when it fits, and either elides or marquees when it overflows. `scroll: false` reproduces today's `elide: Text.ElideRight` exactly.

**Files:**
- Create: `package/contents/ui/ScrollingLabel.qml`

**Interfaces:**
- Consumes: nothing.
- Produces: `ScrollingLabel` QML type with `text: string`, `scroll: bool`, `color: color`, `fontFamily: string` (`""` = inherit), `fontSize: int`, `fontWeight: int`, `animate: bool`, and read-only `overflowing: bool`. It is an `Item`, so it reports `implicitWidth`/`implicitHeight` from its inner label and works inside a `RowLayout` with `Layout.fillWidth`.

- [ ] **Step 1: Create the file**

Create `package/contents/ui/ScrollingLabel.qml`:

```qml
import QtQuick
import org.kde.plasma.components as PlasmaComponents

// Text that fits renders plainly. Text that overflows either elides (default,
// matching the rest of the applet) or scrolls back and forth when `scroll` is
// set. An empty fontFamily inherits the application font.
Item {
    id: control

    property string text: ""
    property bool scroll: false
    property color color: "white"
    property string fontFamily: ""
    property int fontSize: 12
    property int fontWeight: Font.Normal
    property bool animate: true
    property int pauseDuration: 1200
    property int pixelsPerSecond: 30

    readonly property bool overflowing: label.implicitWidth > width
    readonly property bool scrolling: scroll && animate && overflowing && width > 0
    readonly property real scrollDistance: Math.max(0, label.implicitWidth - width)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: overflowing

    // Supplies the default font family when fontFamily is left empty.
    FontMetrics {
        id: inheritedFont
    }

    PlasmaComponents.Label {
        id: label

        width: control.scrolling ? implicitWidth : control.width
        height: control.height
        verticalAlignment: Text.AlignVCenter
        text: control.text
        color: control.color
        font.family: control.fontFamily.length > 0 ? control.fontFamily : inheritedFont.font.family
        font.pointSize: control.fontSize
        font.weight: control.fontWeight
        elide: control.scrolling ? Text.ElideNone : Text.ElideRight
    }

    SequentialAnimation {
        running: control.scrolling
        loops: Animation.Infinite

        PauseAnimation { duration: control.pauseDuration }
        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: -control.scrollDistance
            duration: Math.max(1, control.scrollDistance / control.pixelsPerSecond * 1000)
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: control.pauseDuration }
        NumberAnimation {
            target: label
            property: "x"
            from: -control.scrollDistance
            to: 0
            duration: Math.max(1, control.scrollDistance / control.pixelsPerSecond * 1000)
            easing.type: Easing.InOutQuad
        }
    }

    // Leaving scroll mode mid-animation would strand the label off-screen.
    onScrollingChanged: if (!scrolling) label.x = 0
}
```

- [ ] **Step 2: Run the lint gate**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 3: Commit**

```bash
git add package/contents/ui/ScrollingLabel.qml
git commit -m "feat: add ScrollingLabel for eliding or marquee text"
```

---

### Task 4: Media config entries and MediaStyle

The 26 config entries, plus the object that turns them into per-surface values. Nothing consumes them yet, so this task changes no rendering.

**Files:**
- Modify: `package/contents/config/main.xml` (insert a new block before `<!-- Animation -->`, currently line 86)
- Create: `package/contents/ui/MediaStyle.qml`

**Interfaces:**
- Consumes: nothing.
- Produces: `MediaStyle` QML type. Inputs `scalePercent: int`, `fallbackPrimary: color`, `fallbackSecondary: color`. Read-only outputs: `titleVisible`, `titleFont`, `titleSize`, `titleWeight`, `titleColor`, `titleScroll`, `artistVisible`, `artistFont`, `artistSize`, `artistWeight`, `artistColor`, `artistScroll`, `artistHideIfSame`, `showArt`, `artSize`, `artRadius`, `capsuleArtSize`, `showSeekBar`, `seekBarHeight`, `showTimes`, `showSoundBars`, `showControls`. Sizes are already scaled by `scalePercent`; `capsuleArtSize` is deliberately **not** scaled because the capsule is a fixed 32px tall.

- [ ] **Step 1: Add the config entries**

In `package/contents/config/main.xml`, insert this block immediately before the `<!-- Animation -->` comment:

```xml
        <!-- Media appearance -->
        <entry name="mediaTitleVisible" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaTitleFont" type="String">
            <default></default>
        </entry>
        <entry name="mediaTitleSize" type="Int">
            <default>14</default>
            <min>6</min>
            <max>40</max>
        </entry>
        <entry name="mediaTitleWeight" type="Int">
            <default>500</default>
            <min>100</min>
            <max>900</max>
        </entry>
        <entry name="mediaTitleColor" type="String">
            <default></default>
        </entry>
        <entry name="mediaTitleScroll" type="Bool">
            <default>false</default>
        </entry>
        <entry name="mediaArtistVisible" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaArtistFont" type="String">
            <default></default>
        </entry>
        <entry name="mediaArtistSize" type="Int">
            <default>10</default>
            <min>6</min>
            <max>40</max>
        </entry>
        <entry name="mediaArtistWeight" type="Int">
            <default>400</default>
            <min>100</min>
            <max>900</max>
        </entry>
        <entry name="mediaArtistColor" type="String">
            <default></default>
        </entry>
        <entry name="mediaArtistScroll" type="Bool">
            <default>false</default>
        </entry>
        <entry name="mediaArtistHideIfSame" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaShowArt" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaArtSize" type="Int">
            <default>52</default>
            <min>24</min>
            <max>96</max>
        </entry>
        <entry name="mediaArtRadius" type="Int">
            <default>8</default>
            <min>0</min>
            <max>48</max>
        </entry>
        <entry name="mediaCapsuleArtSize" type="Int">
            <default>22</default>
            <min>0</min>
            <max>28</max>
        </entry>
        <entry name="mediaShowSeekBar" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaSeekBarHeight" type="Int">
            <default>5</default>
            <min>1</min>
            <max>12</max>
        </entry>
        <entry name="mediaShowTimes" type="Bool">
            <default>false</default>
        </entry>
        <entry name="mediaShowSoundBars" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaShowControls" type="Bool">
            <default>true</default>
        </entry>
        <entry name="mediaTitleFormat" type="String">
            <default>{title}</default>
        </entry>
        <entry name="mediaArtistFormat" type="String">
            <default>{artist}</default>
        </entry>
        <entry name="mediaCapsuleScale" type="Int">
            <default>85</default>
            <min>50</min>
            <max>150</max>
        </entry>
        <entry name="mediaExpandedScale" type="Int">
            <default>100</default>
            <min>50</min>
            <max>200</max>
        </entry>
```

`mediaCapsuleScale` defaults to 85 so that `mediaTitleSize` 14 renders as 12 in the capsule, reproducing today's hardcoded 14-expanded / 12-capsule pair.

- [ ] **Step 2: Create MediaStyle.qml**

Create `package/contents/ui/MediaStyle.qml`:

```qml
import QtQuick
import org.kde.plasma.plasmoid

// Resolves the media appearance settings into ready-to-bind values.
// Instantiated once per surface with a different scalePercent, so the capsule
// and the expanded panel share one set of settings at different sizes.
// An empty font family or colour means "inherit", which is why the fallbacks
// are supplied by the instantiator rather than hardcoded here.
QtObject {
    id: style

    property int scalePercent: 100
    property color fallbackPrimary: "white"
    property color fallbackSecondary: Qt.rgba(1, 1, 1, 0.74)

    readonly property real factor: Math.max(0.1, scalePercent / 100)

    readonly property bool titleVisible: Plasmoid.configuration.mediaTitleVisible
    readonly property string titleFont: Plasmoid.configuration.mediaTitleFont
    readonly property int titleSize: scaled(Plasmoid.configuration.mediaTitleSize)
    readonly property int titleWeight: Plasmoid.configuration.mediaTitleWeight
    readonly property color titleColor: Plasmoid.configuration.mediaTitleColor.length > 0
        ? Plasmoid.configuration.mediaTitleColor
        : fallbackPrimary
    readonly property bool titleScroll: Plasmoid.configuration.mediaTitleScroll

    readonly property bool artistVisible: Plasmoid.configuration.mediaArtistVisible
    readonly property string artistFont: Plasmoid.configuration.mediaArtistFont
    readonly property int artistSize: scaled(Plasmoid.configuration.mediaArtistSize)
    readonly property int artistWeight: Plasmoid.configuration.mediaArtistWeight
    readonly property color artistColor: Plasmoid.configuration.mediaArtistColor.length > 0
        ? Plasmoid.configuration.mediaArtistColor
        : fallbackSecondary
    readonly property bool artistScroll: Plasmoid.configuration.mediaArtistScroll
    readonly property bool artistHideIfSame: Plasmoid.configuration.mediaArtistHideIfSame

    readonly property bool showArt: Plasmoid.configuration.mediaShowArt
    readonly property int artSize: scaled(Plasmoid.configuration.mediaArtSize)
    readonly property int artRadius: scaled(Plasmoid.configuration.mediaArtRadius)
    // Not scaled: the compact capsule is a fixed 32px tall, so its art has to
    // stay within that regardless of the expanded panel's scale.
    readonly property int capsuleArtSize: Plasmoid.configuration.mediaCapsuleArtSize

    readonly property bool showSeekBar: Plasmoid.configuration.mediaShowSeekBar
    readonly property int seekBarHeight: scaled(Plasmoid.configuration.mediaSeekBarHeight)
    readonly property bool showTimes: Plasmoid.configuration.mediaShowTimes
    readonly property bool showSoundBars: Plasmoid.configuration.mediaShowSoundBars
    readonly property bool showControls: Plasmoid.configuration.mediaShowControls

    function scaled(base) {
        return Math.max(1, Math.round(base * factor));
    }
}
```

- [ ] **Step 3: Run the lint gate**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 4: Verify the config entries load**

Run: `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di.log`
Expected: no errors in `/tmp/di.log`. A malformed `main.xml` shows up as KConfigXT parse warnings, so a clean start confirms the new block is well-formed. Nothing looks different yet — nothing consumes the entries.

- [ ] **Step 5: Commit**

```bash
git add package/contents/config/main.xml package/contents/ui/MediaStyle.qml
git commit -m "feat: add media appearance settings and MediaStyle resolver"
```

---

### Task 5: Root media wiring

Adds the album role, the text templates, and the two `MediaStyle` instances to `main.qml`, then routes the capsule title and tooltip through the templates. After this the templates work in the capsule; the expanded panel still uses its old hardcoded layout, which Task 6 replaces.

**Files:**
- Modify: `package/contents/ui/main.qml`

**Interfaces:**
- Consumes: `MediaStyle` (Task 4), `formatTemplate` from `IslandUtils.js` (Task 1).
- Produces on `root`, for Tasks 6 and 7 and for phase 2:
  - `mediaAlbum: string`
  - `mediaTokens: var` — `{ title, artist, album, player }`
  - `mediaDisplayTitle: string`, `mediaDisplayArtist: string` — template-formatted
  - `mediaPositionSeconds: real`, `mediaLengthSeconds: real`
  - `mediaStyleCapsule`, `mediaStyleExpanded` — `MediaStyle` instances

- [ ] **Step 1: Import IslandUtils**

In `package/contents/ui/main.qml`, add to the import block (after the `Translator.js` import at line 10):

```qml
import "IslandUtils.js" as Utils
```

- [ ] **Step 2: Add the album property and populate it**

Add next to the other media properties (near `property string mediaIdentity: ""`, line 218):

```qml
    property string mediaAlbum: ""
```

In `setMedia` (line 289), add the album line:

```qml
    function setMedia(roleModel) {
        mediaTitle = roleModel.track || ""
        mediaArtist = roleModel.artist || roleModel.identity || ""
        mediaAlbum = roleModel.album || ""
        mediaArtUrl = roleModel.artUrl || ""
        mediaIdentity = roleModel.identity || ""
        mediaStatus = roleModel.playbackStatus
        mediaPosition = roleModel.position || 0
        mediaLength = roleModel.length || 0
        mediaContainer = roleModel.container
    }
```

- [ ] **Step 3: Add the token map, formatted strings, and second-based positions**

Add after the `mediaProgress` property (line 213):

```qml
    readonly property var mediaTokens: ({
        title: mediaTitle,
        artist: mediaArtist,
        album: mediaAlbum,
        player: mediaIdentity
    })
    readonly property string mediaDisplayTitle: Utils.formatTemplate(Plasmoid.configuration.mediaTitleFormat, mediaTokens)
    readonly property string mediaDisplayArtist: Utils.formatTemplate(Plasmoid.configuration.mediaArtistFormat, mediaTokens)
    // MPRIS reports position and length in microseconds.
    readonly property real mediaPositionSeconds: mediaPosition / 1000000
    readonly property real mediaLengthSeconds: mediaLength / 1000000
```

The parentheses around the object literal are required — without them QML parses the braces as a scope block.

- [ ] **Step 4: Add the two MediaStyle instances**

Add after the `sysLoader` block (line 264):

```qml
    MediaStyle {
        id: mediaStyleCapsule
        scalePercent: Plasmoid.configuration.mediaCapsuleScale
        fallbackPrimary: root.textPrimary
        fallbackSecondary: root.textSecondary
    }

    MediaStyle {
        id: mediaStyleExpanded
        scalePercent: Plasmoid.configuration.mediaExpandedScale
        fallbackPrimary: root.textPrimary
        fallbackSecondary: root.textSecondary
    }
```

- [ ] **Step 5: Route the capsule title and the tooltip through the templates**

In `compactTitle` (line 184), change the `activeMode === 0` branch:

```qml
        if (activeMode === 0) {
            return mediaDisplayTitle || Tr.t("Music")
        }
```

In `toolTipMainText` (line 20):

```qml
        if (showMedia) return mediaDisplayTitle || Tr.t("Music")
```

In `toolTipSubText` (line 27):

```qml
        if (showMedia) return mediaDisplayArtist || mediaIdentity || ""
```

- [ ] **Step 6: Run both checks**

Run: `node tests/islandutils.test.mjs && ./tests/qmlcheck.sh`
Expected: both pass.

- [ ] **Step 7: Verify templates work end to end**

Run: `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di.log`

With a player running, the capsule should look identical to before (default template is `{title}`). Then set a template by hand and confirm the capsule text changes:

```bash
kwriteconfig6 --file plasmawindowedrc --group General --key mediaTitleFormat '{artist} — {title}'
```

Restart `plasmawindowed` and confirm the capsule now shows `artist — title`. Reset it afterwards:

```bash
kwriteconfig6 --file plasmawindowedrc --group General --key mediaTitleFormat '{title}'
```

Expected: no errors in `/tmp/di.log`; the template visibly takes effect. If the capsule shows a literal `{artist}`, `mediaTokens` is not reaching `formatTemplate`.

- [ ] **Step 8: Commit**

```bash
git add package/contents/ui/main.qml
git commit -m "feat: wire media text templates and MediaStyle into the island root"
```

---

### Task 6: MediaExpanded

Replaces the hardcoded `musicExpanded` component with a file driven entirely by `MediaStyle`. This is where most of the visible payoff lands.

**Files:**
- Create: `package/contents/ui/MediaExpanded.qml`
- Modify: `package/contents/ui/main.qml` (replace the `musicExpanded` component body, lines 938-1080)

**Interfaces:**
- Consumes: `island` (the `root` `PlasmoidItem`, for `mediaDisplayTitle`, `mediaDisplayArtist`, `mediaArtUrl`, `mediaIdentity`, `mediaPlaying`, `mediaProgress`, `mediaPositionSeconds`, `mediaLengthSeconds`, `mediaContainer`, `accent`, `textPrimary`, `animationsEnabled`, `dur()`), `style` (a `MediaStyle`), `SoundBars`, `ScrollingLabel`, `IslandUtils.mmss`.
- Produces: `MediaExpanded` QML type with `island: var` and `style: var`.

- [ ] **Step 1: Create the file**

Create `package/contents/ui/MediaExpanded.qml`:

```qml
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "IslandUtils.js" as Utils
import "Translator.js" as Tr

// The expanded media panel. Every size, font and colour comes from `style`
// (a MediaStyle), so the same settings drive the compact capsule too.
Item {
    id: view

    property var island: null
    property var style: null

    readonly property bool hasArt: island.mediaArtUrl !== ""
    readonly property bool artistShown: style.artistVisible
        && !(style.artistHideIfSame && island.mediaDisplayArtist === island.mediaDisplayTitle)
    readonly property bool seekable: island.mediaContainer !== null
        && island.mediaLengthSeconds > 0
        && island.mediaContainer.canSeek === true

    Item {
        id: artSlot

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: view.style.artSize
        height: width
        visible: view.style.showArt

        // ShadowedImage is Kirigami's rounded-image primitive. A plain Image
        // inside a clipped Rectangle would not round, because Qt Quick's clip
        // is rectangular.
        Kirigami.ShadowedImage {
            anchors.fill: parent
            visible: view.hasArt
            source: view.island.mediaArtUrl
            radius: view.style.artRadius
        }

        Rectangle {
            anchors.fill: parent
            visible: !view.hasArt
            radius: view.style.artRadius
            color: Qt.rgba(0.92, 0.94, 0.96, 0.28)

            Kirigami.Icon {
                anchors.centerIn: parent
                source: "audio-x-generic"
                width: Math.round(parent.width * 0.58)
                height: width
            }
        }
    }

    SoundBars {
        id: musicBars

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 16
        width: 38
        height: 28
        visible: view.style.showSoundBars
        playing: view.island.mediaPlaying
        barColor: view.island.textPrimary
        animate: view.island.animationsEnabled
    }

    Row {
        id: musicControls

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 14
        visible: view.style.showControls

        Kirigami.Icon {
            source: "media-skip-backward"
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            opacity: view.island.mediaContainer ? 1 : 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: if (view.island.mediaContainer) view.island.mediaContainer.Previous()
            }
        }

        Kirigami.Icon {
            source: view.island.mediaPlaying ? "media-playback-pause" : "media-playback-start"
            width: 26
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            opacity: view.island.mediaContainer ? 1 : 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: if (view.island.mediaContainer) view.island.mediaContainer.PlayPause()
            }
        }

        Kirigami.Icon {
            source: "media-skip-forward"
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            opacity: view.island.mediaContainer ? 1 : 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: if (view.island.mediaContainer) view.island.mediaContainer.Next()
            }
        }
    }

    ScrollingLabel {
        id: musicTitle

        anchors.left: artSlot.visible ? artSlot.right : parent.left
        anchors.leftMargin: artSlot.visible ? 14 : 16
        anchors.right: musicBars.visible ? musicBars.left : parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 16
        height: implicitHeight
        visible: view.style.titleVisible
        text: view.island.mediaDisplayTitle || Tr.t("No title")
        color: view.style.titleColor
        fontFamily: view.style.titleFont
        fontSize: view.style.titleSize
        fontWeight: view.style.titleWeight
        scroll: view.style.titleScroll
        animate: view.island.animationsEnabled
    }

    ScrollingLabel {
        id: musicArtist

        anchors.left: musicTitle.left
        anchors.right: musicTitle.right
        anchors.top: musicTitle.visible ? musicTitle.bottom : parent.top
        anchors.topMargin: musicTitle.visible ? 2 : 16
        height: implicitHeight
        visible: view.artistShown
        text: view.island.mediaDisplayArtist || view.island.mediaIdentity || Tr.t("Media player")
        color: view.style.artistColor
        fontFamily: view.style.artistFont
        fontSize: view.style.artistSize
        fontWeight: view.style.artistWeight
        scroll: view.style.artistScroll
        animate: view.island.animationsEnabled
    }

    Item {
        id: seekRow

        anchors.left: musicTitle.left
        anchors.right: musicControls.visible ? musicControls.left : parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        height: Math.max(view.style.seekBarHeight, elapsedLabel.visible ? elapsedLabel.implicitHeight : 0)
        visible: view.style.showSeekBar

        PlasmaComponents.Label {
            id: elapsedLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: view.style.showTimes
            text: Utils.mmss(view.island.mediaPositionSeconds)
            color: view.style.artistColor
            font.pointSize: Math.max(6, view.style.artistSize - 2)
        }

        PlasmaComponents.Label {
            id: totalLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: view.style.showTimes
            text: Utils.mmss(view.island.mediaLengthSeconds)
            color: view.style.artistColor
            font.pointSize: Math.max(6, view.style.artistSize - 2)
        }

        Rectangle {
            id: seekTrack

            anchors.left: elapsedLabel.visible ? elapsedLabel.right : parent.left
            anchors.leftMargin: elapsedLabel.visible ? 8 : 0
            anchors.right: totalLabel.visible ? totalLabel.left : parent.right
            anchors.rightMargin: totalLabel.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            height: view.style.seekBarHeight
            radius: Math.max(1, height / 2)
            color: Qt.rgba(1, 1, 1, 0.22)

            Rectangle {
                width: parent.width * view.island.mediaProgress
                height: parent.height
                radius: parent.radius
                color: view.island.accent

                Behavior on width {
                    NumberAnimation { duration: view.island.dur(220); easing.type: Easing.OutCubic }
                }
            }

            // Click-to-seek. MPRIS positions are microseconds, and the
            // container's `position` property is writable.
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                enabled: view.seekable
                cursorShape: view.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: (mouse) => {
                    const fraction = Math.max(0, Math.min(1, mouse.x / width))
                    view.island.mediaContainer.position = Math.round(fraction * view.island.mediaLength)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Replace the musicExpanded component in main.qml**

In `package/contents/ui/main.qml`, replace the whole `Component { id: musicExpanded ... }` block (lines 938-1080) with:

```qml
    Component {
        id: musicExpanded

        MediaExpanded {
            anchors.fill: parent
            island: root
            style: mediaStyleExpanded
        }
    }
```

- [ ] **Step 3: Run both checks**

Run: `node tests/islandutils.test.mjs && ./tests/qmlcheck.sh`
Expected: both pass.

- [ ] **Step 4: Verify the expanded panel**

Run: `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di.log`

With a player running, click the capsule and confirm the expanded panel is visually unchanged from before this task: 52px art with an 8px radius, 14pt title, 10pt artist, sound bars top-right, controls bottom-right, seek bar across the bottom. Then verify a few knobs, restarting `plasmawindowed` after each:

```bash
kwriteconfig6 --file plasmawindowedrc --group General --key mediaShowArt false
kwriteconfig6 --file plasmawindowedrc --group General --key mediaArtSize 76
kwriteconfig6 --file plasmawindowedrc --group General --key mediaShowTimes true
kwriteconfig6 --file plasmawindowedrc --group General --key mediaTitleSize 22
kwriteconfig6 --file plasmawindowedrc --group General --key mediaArtistVisible false
```

Expected: art disappears and the text reflows to the left edge; art grows; elapsed/total labels flank the seek bar; the title grows; the artist line disappears and the title moves to the top. Reset each key afterwards with `--delete`:

```bash
for k in mediaShowArt mediaArtSize mediaShowTimes mediaTitleSize mediaArtistVisible; do
    kwriteconfig6 --file plasmawindowedrc --group General --key "$k" --delete
done
```

- [ ] **Step 5: Commit**

```bash
git add package/contents/ui/MediaExpanded.qml package/contents/ui/main.qml
git commit -m "feat: rebuild the expanded media panel on MediaStyle"
```

---

### Task 7: Capsule media styling and width metrics

The capsule is where getting this wrong breaks layout rather than just looks: `compactTitleMetrics` and `compactLeadingWidth` feed `compactWidth`, so they must track the configured font and the configured leading elements.

**Files:**
- Modify: `package/contents/ui/main.qml` (lines 37, 244-249, and the `compactContentBlock` component at 786-897)

**Interfaces:**
- Consumes: `mediaStyleCapsule` (Task 5), `ScrollingLabel` (Task 3), `SoundBars` (Task 2).
- Produces: `mediaLeadingWidth: int` on `root`.

- [ ] **Step 1: Make the title metrics follow the configured font**

Replace the `compactTitleMetrics` block (lines 244-249) with:

```qml
    // Supplies the default family when no media font is configured.
    FontMetrics {
        id: compactFontMetrics
    }

    TextMetrics {
        id: compactTitleMetrics
        text: root.compactTitle
        font.family: (root.activeMode === 0 && mediaStyleCapsule.titleFont.length > 0)
            ? mediaStyleCapsule.titleFont
            : compactFontMetrics.font.family
        font.pointSize: root.activeMode === 0 ? mediaStyleCapsule.titleSize : 12
        font.weight: root.activeMode === 0 ? mediaStyleCapsule.titleWeight : Font.Medium
    }
```

Only media mode takes the configured font. Every other mode keeps 12pt Medium, which is what the label in `compactContentBlock` renders for them.

- [ ] **Step 2: Compute the leading width instead of hardcoding it**

Add near the other width properties, before `compactLeadingWidth` (line 37):

```qml
    // Width reserved left of the capsule title for the media indicators. The
    // constants are tuned so the defaults (bars on, 22px art) come to 68 —
    // the value this was hardcoded to before the elements became optional.
    readonly property int mediaLeadingWidth: (mediaStyleCapsule.showSoundBars ? 36 : 0)
        + ((mediaStyleCapsule.showArt && mediaStyleCapsule.capsuleArtSize > 0)
            ? mediaStyleCapsule.capsuleArtSize + 10 : 0)
```

Then replace `compactLeadingWidth` (line 37) with:

```qml
    readonly property int compactLeadingWidth: showGreenDot ? 10
        : activeMode === 0 ? (sharingScreen ? mediaLeadingWidth + 18 : mediaLeadingWidth)
        : 24
```

With defaults this yields 68, and 86 while screen sharing — exactly the previous constants, so the capsule does not change width on upgrade.

- [ ] **Step 3: Drive the capsule media elements from the style**

In `compactContentBlock`, replace the `SoundBars`, spacer `Item`, `MediaCompactIcon` and title `Label` children (leaving `sharingDot`, `idleDot`, `StatusIcon` and `unreadBadge` untouched) with:

```qml
            SoundBars {
                visible: root.activeMode === 0 && mediaStyleCapsule.showSoundBars
                playing: root.mediaPlaying
                barColor: root.textPrimary
                animate: root.animationsEnabled
                Layout.preferredWidth: 30
                Layout.preferredHeight: 26
            }

            Item {
                visible: root.activeMode === 0
                Layout.preferredWidth: 6
                Layout.preferredHeight: 1
            }

            MediaCompactIcon {
                visible: root.activeMode === 0 && mediaStyleCapsule.showArt
                    && mediaStyleCapsule.capsuleArtSize > 0
                artUrl: root.mediaArtUrl
                radius: mediaStyleCapsule.artRadius
                Layout.preferredWidth: mediaStyleCapsule.capsuleArtSize
                Layout.preferredHeight: mediaStyleCapsule.capsuleArtSize
            }
```

and replace the title `PlasmaComponents.Label` with:

```qml
            ScrollingLabel {
                text: root.compactTitle
                visible: !root.showGreenDot && text.length > 0
                    && (root.activeMode !== 0 || mediaStyleCapsule.titleVisible)
                color: root.activeMode === 0 ? mediaStyleCapsule.titleColor : root.textPrimary
                fontFamily: root.activeMode === 0 ? mediaStyleCapsule.titleFont : ""
                fontSize: root.activeMode === 0 ? mediaStyleCapsule.titleSize : 12
                fontWeight: root.activeMode === 0 ? mediaStyleCapsule.titleWeight : Font.Medium
                scroll: root.activeMode === 0 && mediaStyleCapsule.titleScroll
                animate: root.animationsEnabled
                Layout.fillWidth: true
                Layout.maximumWidth: root.compactTextMaxWidth
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignVCenter
            }
```

- [ ] **Step 4: Give MediaCompactIcon a configurable radius**

In the `component MediaCompactIcon: Item` block (line 1313), add the property and use it, and round the image the same way `MediaExpanded` does:

```qml
    component MediaCompactIcon: Item {
        property string artUrl: ""
        property int radius: 6

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.12)
            visible: artUrl.length === 0

            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: width
                source: "audio-x-generic"
            }
        }

        Kirigami.ShadowedImage {
            anchors.fill: parent
            visible: artUrl.length > 0
            source: artUrl
            radius: parent.radius
        }
    }
```

- [ ] **Step 5: Run both checks**

Run: `node tests/islandutils.test.mjs && ./tests/qmlcheck.sh`
Expected: both pass.

- [ ] **Step 6: Verify capsule sizing**

Run: `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di.log`

With a player running, confirm the capsule is unchanged. Then check the two cases where the metrics matter:

```bash
kwriteconfig6 --file plasmawindowedrc --group General --key mediaTitleSize 30
```
Restart. Expected: the capsule grows to fit the larger title without the text being clipped or elided early. This is the check that `compactTitleMetrics` is bound correctly — if it still reads a fixed 12pt, the capsule will be too narrow and the title will elide.

```bash
kwriteconfig6 --file plasmawindowedrc --group General --key mediaShowSoundBars false
kwriteconfig6 --file plasmawindowedrc --group General --key mediaCapsuleArtSize 0
```
Restart. Expected: bars and art are gone and the capsule shrinks accordingly, with no dead space left of the title. Then clean up:

```bash
for k in mediaTitleSize mediaShowSoundBars mediaCapsuleArtSize; do
    kwriteconfig6 --file plasmawindowedrc --group General --key "$k" --delete
done
```

- [ ] **Step 7: Commit**

```bash
git add package/contents/ui/main.qml
git commit -m "feat: style the compact capsule media block from MediaStyle"
```

---

### Task 8: Media settings page

**Files:**
- Create: `package/contents/ui/configMedia.qml`
- Modify: `package/contents/config/config.qml`

**Interfaces:**
- Consumes: the config entries from Task 4.
- Produces: a `Media` config category, visible only when `enableMedia` is on.

- [ ] **Step 1: Create the page**

Create `package/contents/ui/configMedia.qml`. Every `cfg_*` property must be declared on this root item — KConfigXT only binds properties found there:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Translator.js" as Tr

Kirigami.FormLayout {
    id: page

    property alias cfg_mediaTitleVisible: titleVisibleSwitch.checked
    property alias cfg_mediaTitleSize: titleSizeSpin.value
    property alias cfg_mediaTitleScroll: titleScrollSwitch.checked
    property alias cfg_mediaArtistVisible: artistVisibleSwitch.checked
    property alias cfg_mediaArtistSize: artistSizeSpin.value
    property alias cfg_mediaArtistScroll: artistScrollSwitch.checked
    property alias cfg_mediaArtistHideIfSame: artistHideSameSwitch.checked
    property alias cfg_mediaShowArt: artSwitch.checked
    property alias cfg_mediaArtSize: artSizeSpin.value
    property alias cfg_mediaArtRadius: artRadiusSpin.value
    property alias cfg_mediaCapsuleArtSize: capsuleArtSpin.value
    property alias cfg_mediaShowSeekBar: seekSwitch.checked
    property alias cfg_mediaSeekBarHeight: seekHeightSpin.value
    property alias cfg_mediaShowTimes: timesSwitch.checked
    property alias cfg_mediaShowSoundBars: soundBarsSwitch.checked
    property alias cfg_mediaShowControls: controlsSwitch.checked
    property alias cfg_mediaCapsuleScale: capsuleScaleSlider.value
    property alias cfg_mediaExpandedScale: expandedScaleSlider.value
    property string cfg_mediaTitleFont: ""
    property string cfg_mediaTitleColor: ""
    property int cfg_mediaTitleWeight: 500
    property string cfg_mediaArtistFont: ""
    property string cfg_mediaArtistColor: ""
    property int cfg_mediaArtistWeight: 400
    property string cfg_mediaTitleFormat: "{title}"
    property string cfg_mediaArtistFormat: "{artist}"

    readonly property var weightOptions: [
        { text: Tr.t("Light"), value: 300 },
        { text: Tr.t("Normal"), value: 400 },
        { text: Tr.t("Medium"), value: 500 },
        { text: Tr.t("DemiBold"), value: 600 },
        { text: Tr.t("Bold"), value: 700 }
    ]

    // Title line

    QQC2.Switch {
        id: titleVisibleSwitch
        Kirigami.FormData.label: Tr.t("Title line:")
        text: Tr.t("Show the track title")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Title size:")
        enabled: titleVisibleSwitch.checked
        QQC2.SpinBox { id: titleSizeSpin; from: 6; to: 40; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }

    QQC2.ComboBox {
        id: titleWeightCombo
        Kirigami.FormData.label: Tr.t("Title weight:")
        enabled: titleVisibleSwitch.checked
        textRole: "text"
        valueRole: "value"
        model: page.weightOptions
        onActivated: page.cfg_mediaTitleWeight = currentValue
        Component.onCompleted: currentIndex = indexOfValue(page.cfg_mediaTitleWeight)
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Title font:")
        enabled: titleVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaTitleFont
        onEditingFinished: page.cfg_mediaTitleFont = text
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Title colour (hex):")
        enabled: titleVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaTitleColor
        onEditingFinished: page.cfg_mediaTitleColor = text
    }

    QQC2.Switch {
        id: titleScrollSwitch
        Kirigami.FormData.label: Tr.t("Long titles:")
        enabled: titleVisibleSwitch.checked
        text: Tr.t("Scroll instead of trimming with an ellipsis")
    }

    Item { Kirigami.FormData.isSection: true }

    // Artist line

    QQC2.Switch {
        id: artistVisibleSwitch
        Kirigami.FormData.label: Tr.t("Artist line:")
        text: Tr.t("Show the artist")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Artist size:")
        enabled: artistVisibleSwitch.checked
        QQC2.SpinBox { id: artistSizeSpin; from: 6; to: 40; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }

    QQC2.ComboBox {
        id: artistWeightCombo
        Kirigami.FormData.label: Tr.t("Artist weight:")
        enabled: artistVisibleSwitch.checked
        textRole: "text"
        valueRole: "value"
        model: page.weightOptions
        onActivated: page.cfg_mediaArtistWeight = currentValue
        Component.onCompleted: currentIndex = indexOfValue(page.cfg_mediaArtistWeight)
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Artist font:")
        enabled: artistVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaArtistFont
        onEditingFinished: page.cfg_mediaArtistFont = text
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Artist colour (hex):")
        enabled: artistVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaArtistColor
        onEditingFinished: page.cfg_mediaArtistColor = text
    }

    QQC2.Switch {
        id: artistScrollSwitch
        Kirigami.FormData.label: Tr.t("Long artists:")
        enabled: artistVisibleSwitch.checked
        text: Tr.t("Scroll instead of trimming with an ellipsis")
    }

    QQC2.Switch {
        id: artistHideSameSwitch
        Kirigami.FormData.label: Tr.t("Duplicates:")
        enabled: artistVisibleSwitch.checked
        text: Tr.t("Hide the artist when it matches the title")
    }

    Item { Kirigami.FormData.isSection: true }

    // Album art

    QQC2.Switch {
        id: artSwitch
        Kirigami.FormData.label: Tr.t("Album art:")
        text: Tr.t("Show cover art")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Art size:")
        enabled: artSwitch.checked
        QQC2.SpinBox { id: artSizeSpin; from: 24; to: 96; stepSize: 2 }
        QQC2.Label { text: Tr.t("px, expanded panel") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Art corners:")
        enabled: artSwitch.checked
        QQC2.SpinBox { id: artRadiusSpin; from: 0; to: 48; stepSize: 1 }
        QQC2.Label { text: Tr.t("px radius") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Capsule art:")
        enabled: artSwitch.checked
        QQC2.SpinBox { id: capsuleArtSpin; from: 0; to: 28; stepSize: 1 }
        QQC2.Label { text: Tr.t("px, 0 hides it") }
    }

    Item { Kirigami.FormData.isSection: true }

    // Seek bar and extras

    QQC2.Switch {
        id: seekSwitch
        Kirigami.FormData.label: Tr.t("Seek bar:")
        text: Tr.t("Show progress, click to seek")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Seek bar height:")
        enabled: seekSwitch.checked
        QQC2.SpinBox { id: seekHeightSpin; from: 1; to: 12; stepSize: 1 }
        QQC2.Label { text: Tr.t("px") }
    }

    QQC2.Switch {
        id: timesSwitch
        Kirigami.FormData.label: Tr.t("Times:")
        enabled: seekSwitch.checked
        text: Tr.t("Show elapsed and total either side of the bar")
    }

    QQC2.Switch {
        id: soundBarsSwitch
        Kirigami.FormData.label: Tr.t("Equaliser:")
        text: Tr.t("Show the animated bars")
    }

    QQC2.Switch {
        id: controlsSwitch
        Kirigami.FormData.label: Tr.t("Controls:")
        text: Tr.t("Show previous, play/pause and next")
    }

    Item { Kirigami.FormData.isSection: true }

    // Text templates

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Title text:")
        text: page.cfg_mediaTitleFormat
        onEditingFinished: page.cfg_mediaTitleFormat = text
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Artist text:")
        text: page.cfg_mediaArtistFormat
        onEditingFinished: page.cfg_mediaArtistFormat = text
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Available placeholders: {title}, {artist}, {album}, {player}. Anything else is shown as typed.")
    }

    Item { Kirigami.FormData.isSection: true }

    // Scale

    RowLayout {
        Kirigami.FormData.label: Tr.t("Capsule scale:")
        QQC2.Slider {
            id: capsuleScaleSlider
            from: 50; to: 150; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: capsuleScaleSlider.value + "%" }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Expanded scale:")
        QQC2.Slider {
            id: expandedScaleSlider
            from: 50; to: 200; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: expandedScaleSlider.value + "%" }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Sizes above are multiplied by these, so one set of settings drives both the small capsule and the big panel.")
    }
}
```

- [ ] **Step 2: Register the category**

In `package/contents/config/config.qml`, add after the `Appearance` category:

```qml
    ConfigCategory {
        name: Tr.t("Media")
        icon: "applications-multimedia"
        source: "configMedia.qml"
        visible: Plasmoid.configuration.enableMedia
    }
```

and add the import needed for `Plasmoid` at the top of the file:

```qml
import org.kde.plasma.plasmoid
```

- [ ] **Step 3: Run the lint gate**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 4: Verify the page saves**

Run: `./install.sh`, then restart Plasma (`kquitapp6 plasmashell && kstart plasmashell`) so the new config category is picked up, and open the widget's settings.

Expected:
- A **Media** category appears between Appearance and Clock.
- Every control shows its current value.
- Changing the title size and pressing Apply updates the capsule and panel live.
- Turning **Media** off on the Modules page and pressing Apply, then reopening settings, hides the Media category. It reappears when Media is turned back on and applied. (It only updates after Apply — `ConfigCategory.visible` reads committed config, not the unsaved switch.)
- Typing a bad hex into a colour field leaves the field as typed and the colour falls back to inherit rather than breaking rendering.

- [ ] **Step 5: Commit**

```bash
git add package/contents/ui/configMedia.qml package/contents/config/config.qml
git commit -m "feat: add the media appearance settings page"
```

---

### Task 9: Phase 1 acceptance

No new code. This is the gate before phase 2 starts, because phase 2 builds on these files.

**Files:**
- Modify: `package/metadata.json` (version only)

- [ ] **Step 1: Run both automated checks**

Run: `node tests/islandutils.test.mjs && ./tests/qmlcheck.sh`
Expected: both pass.

- [ ] **Step 2: Confirm defaults are unchanged from before the branch**

Run:
```bash
git stash list >/dev/null
./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di.log
```

With a fresh config (no `media*` keys set) and a player running, compare against the pre-change screenshots in `screenshots/`. The capsule and expanded panel must be visually identical. Any difference means a default drifted — check `mediaCapsuleScale` (85) and `mediaLeadingWidth` (must total 68).

- [ ] **Step 3: Confirm no QML errors**

Run: `grep -iE "error|warning: .*\.qml" /tmp/di.log`
Expected: no output.

- [ ] **Step 4: Bump the version**

In `package/metadata.json`, change `"Version": "1.1.0"` to `"Version": "1.2.0"`.

- [ ] **Step 5: Commit**

```bash
git add package/metadata.json
git commit -m "chore: bump version to 1.2.0 for media customisation"
```

---

## Self-review

**Spec coverage.** Every phase-1 requirement maps to a task: the 26 config entries and `MediaStyle` to Task 4; `ScrollingLabel` overflow behaviour to Task 3; the three extractions to Tasks 2, 3 and 6; text templates to Tasks 1 and 5; the `compactTitleMetrics` warning called out in the spec to Task 7; the settings page and its `visible` gating to Task 8; the "defaults must be byte-identical" constraint to Task 9 step 2. `IslandUtils.js` also carries `parseWidgetList`, `serializeWidgetList` and `moveItem`, which phase 1 does not use — they are here because the spec puts the file and its test in step 1 of the implementation order, and splitting one small library across two plans would be worse.

**Placeholders.** None. Every code step carries complete code; every verification step carries the exact command and the expected result.

**Type consistency.** `MediaStyle` property names used in Tasks 6 and 7 match Task 4's definitions exactly (`titleSize`, `titleWeight`, `titleColor`, `titleScroll`, `artistHideIfSame`, `capsuleArtSize`, `seekBarHeight`, `showSoundBars`, `showControls`, `showTimes`). `ScrollingLabel`'s properties used in Tasks 6 and 7 match Task 3 (`text`, `scroll`, `color`, `fontFamily`, `fontSize`, `fontWeight`, `animate`). `SoundBars`' `playing`/`barColor`/`animate` match Task 2. `mediaDisplayTitle`, `mediaDisplayArtist`, `mediaPositionSeconds`, `mediaLengthSeconds` are defined in Task 5 and consumed in Task 6 under those names. `mmss` and `formatTemplate` signatures match Task 1.

One deliberate asymmetry worth knowing: `MediaExpanded` reads `island.mediaLength` (microseconds) when writing a seek position, and `island.mediaLengthSeconds` when displaying a duration. Both properties exist and the units differ on purpose.
