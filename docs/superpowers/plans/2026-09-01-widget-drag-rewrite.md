# Widget Drag Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the panel's index-based widget reorder with free grid placement — a dragged card follows the cursor, snaps to a previewed cell, and stays where it is dropped.

**Architecture:** All placement and collision logic moves into `IslandUtils.js` as pure functions covered by node tests; `IslandPanel.qml` keeps only pixels, animation and gesture. Widgets gain explicit `col`/`row`, persisted in `panelWidgets` as `id:col:row:spanW:spanH`. Dragging uses a `DragHandler` with `target: null` writing a translation offset, so the delegate's binding to the layout engine is never destroyed.

**Tech Stack:** QML (Qt 6), Plasma 6 applet API, KConfigXT, Kirigami, `node` for pure-JS tests, `qmllint` gate.

**Spec:** `docs/superpowers/specs/2026-09-01-widget-drag-rewrite-design.md`

## Global Constraints

- Pure QML only. No build step, no new runtime dependency, no compiled plugin.
- 4-space indentation. `readonly property` for derived values. Comments only where intent is non-obvious.
- `IslandUtils.js` stays free of QML types — it must keep evaluating under plain `node` via `tests/islandutils.test.mjs`.
- Existing configs must load pixel-identical to today. Legacy `id:spanW:spanH` entries auto-place in reading order.
- `MAX_COLS = 4`, `MAX_ROWS = 64`. The row cap is a corruption guard, not a layout limit.
- Drag threshold is `6`. Autoscroll edge zone is `40` px. Placeholder animations are `140` ms; card layout animations stay at the existing `220` ms.
- Every test command is run from the repo root.

## Commands

- Pure-JS tests: `node tests/islandutils.test.mjs` — prints `islandutils: all assertions passed`, exit 0.
- QML lint gate: `./tests/qmlcheck.sh` — prints `qmlcheck: OK`, exit 0.
- Live check: `./install.sh` then `plasmawindowed com.deadindian.dynamicisland` (QML errors print to the terminal).

## Environment facts (verified — do not re-probe)

- `tests/islandutils.test.mjs` loads `IslandUtils.js` by stripping `.pragma`/`.import` lines and evaluating it in a `new Function`, then re-exports each function by name at the bottom of that constructed source (lines 14-26). **Every new function must be added to that export list** or it is invisible to the tests.
- The test file uses bare `node:assert/strict` calls at module top level — no test framework, no `describe`/`it`. Match that style.
- `DragHandler`'s default `grabPermissions` include `ApprovesTakeOverByItems`, which lets an ancestor `Flickable` steal the grab mid-drag.
- `PointerHandler.<GrabPermission>` enum values are reachable from QML with a plain `import QtQuick`.
- `package/metadata.json` is at version `1.4.0`; `CHANGELOG.md`'s newest section is `## [1.4.0] — 2026-08-31`.

---

### Task 1: Config format grows to `id:col:row:spanW:spanH`

**Files:**
- Modify: `package/contents/ui/IslandUtils.js:44-92` (`parseWidgetSpecs`, `serializeWidgetSpecs`)
- Test: `tests/islandutils.test.mjs:50-58` (replace the existing 2D spec block)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `parseWidgetSpecs(str, validIds, defaultWFn, defaultHFn)` → `Array<{id: string, col: number, row: number, spanW: number, spanH: number}>`. `col`/`row` are `-1` for "not placed".
  - `serializeWidgetSpecs(specs)` → `string`, always five fields per entry.
  - Module constants `MAX_COLS = 4`, `MAX_ROWS = 64`.
  - `parseCell(field, maxValue)` → `number`, `-1` when out of range or non-numeric.

- [ ] **Step 1: Write the failing test**

Replace `tests/islandutils.test.mjs:50-58` (the `// parseWidgetSpecs & serializeWidgetSpecs 2D` block through the `serializeWidgetSpecs` assertion) with:

```js
// parseWidgetSpecs & serializeWidgetSpecs — 5-field explicit placement
const placedStr = "network:0:0:1:1,volume:0:1:3:1,media:0:2:2:2";
const placed = U.parseWidgetSpecs(placedStr, valid);
assert.deepEqual(placed, [
    { id: "network", col: 0, row: 0, spanW: 1, spanH: 1 },
    { id: "volume", col: 0, row: 1, spanW: 3, spanH: 1 },
    { id: "media", col: 0, row: 2, spanW: 2, spanH: 2 }
]);
assert.equal(U.serializeWidgetSpecs(placed), placedStr);

// Legacy 3-field entries parse as unplaced.
const legacy = U.parseWidgetSpecs("network:1:1,volume:3:1,media:2:2", valid);
assert.deepEqual(legacy, [
    { id: "network", col: -1, row: -1, spanW: 1, spanH: 1 },
    { id: "volume", col: -1, row: -1, spanW: 3, spanH: 1 },
    { id: "media", col: -1, row: -1, spanW: 2, spanH: 2 }
]);
assert.equal(
    U.serializeWidgetSpecs(legacy),
    "network:-1:-1:1:1,volume:-1:-1:3:1,media:-1:-1:2:2",
);

// "-1" survives a round-trip as unplaced rather than becoming a literal cell.
assert.deepEqual(U.parseWidgetSpecs("network:-1:-1:1:1", valid), [
    { id: "network", col: -1, row: -1, spanW: 1, spanH: 1 }
]);

// Out-of-range col/row degrade to unplaced, field by field.
assert.deepEqual(U.parseWidgetSpecs("network:9:0:1:1,volume:0:999:3:1", valid), [
    { id: "network", col: -1, row: 0, spanW: 1, spanH: 1 },
    { id: "volume", col: 0, row: -1, spanW: 3, spanH: 1 }
]);

// Legacy short forms still fall back to catalog defaults.
const wDefaults = { media: 3, network: 1 };
const hDefaults = { media: 2, network: 1 };
assert.deepEqual(U.parseWidgetSpecs("media", valid, wDefaults, hDefaults), [
    { id: "media", col: -1, row: -1, spanW: 3, spanH: 2 }
]);
assert.deepEqual(U.parseWidgetSpecs("media:2", valid, wDefaults, hDefaults), [
    { id: "media", col: -1, row: -1, spanW: 2, spanH: 2 }
]);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/islandutils.test.mjs`
Expected: FAIL — `AssertionError` on the first `deepEqual`, because the current
`parseWidgetSpecs` returns objects without `col`/`row`.

- [ ] **Step 3: Add the constants and the cell parser**

In `package/contents/ui/IslandUtils.js`, immediately after the `.pragma library`
header comment block (above `formatTemplate`), add:

```js
// Grid bounds. MAX_ROWS is a guard against a corrupted config string, not a
// layout limit: rows grow on demand.
var MAX_COLS = 4;
var MAX_ROWS = 64;

// Parses an explicit col/row field. Anything non-numeric or out of range becomes
// -1, which means "place this widget automatically".
function parseCell(field, maxValue) {
    var v = parseInt(String(field).trim(), 10);
    if (isNaN(v) || v < 0 || v > maxValue) {
        return -1;
    }
    return v;
}
```

- [ ] **Step 4: Rewrite `parseWidgetSpecs`**

Replace the whole function (`IslandUtils.js:44-79`, from the
`// Parses grid items formatted as` comment through its closing brace) with:

```js
// Parses grid items formatted as "id:col:row:spanW:spanH". Shorter forms are
// legacy ("id:spanW:spanH", "id:spanW", "id") and yield col/row -1, meaning the
// placement engine positions them. Field count is a safe discriminator because
// serializeWidgetSpecs only ever emits five fields.
function parseWidgetSpecs(str, validIds, defaultWFn, defaultHFn) {
    var out = [];
    var allowed = validIds || [];
    var seen = [];
    var parts = String(str === null || str === undefined ? "" : str).split(",");

    for (var i = 0; i < parts.length; i++) {
        var raw = parts[i].trim();
        if (raw.length === 0) continue;
        var pair = raw.split(":");
        var id = pair[0].trim();
        if (id.length === 0 || (allowed.length > 0 && allowed.indexOf(id) === -1) || seen.indexOf(id) !== -1) {
            continue;
        }

        var col = -1;
        var row = -1;
        var wField = 1;
        var hField = 2;
        var spanW = 3;
        var spanH = 1;

        if (pair.length >= 5) {
            col = parseCell(pair[1], MAX_COLS - 1);
            row = parseCell(pair[2], MAX_ROWS - 1);
            wField = 3;
            hField = 4;
        }

        if (pair.length > wField) {
            var parsedW = parseInt(pair[wField].trim(), 10);
            if (parsedW >= 1 && parsedW <= MAX_COLS) spanW = parsedW;
        } else if (defaultWFn) {
            spanW = typeof defaultWFn === "function" ? defaultWFn(id) : (defaultWFn[id] || 3);
        }

        if (pair.length > hField) {
            var parsedH = parseInt(pair[hField].trim(), 10);
            if (parsedH >= 1 && parsedH <= 3) spanH = parsedH;
        } else if (defaultHFn) {
            spanH = typeof defaultHFn === "function" ? defaultHFn(id) : (defaultHFn[id] || 1);
        }

        seen.push(id);
        out.push({ id: id, col: col, row: row, spanW: spanW, spanH: spanH });
    }
    return out;
}
```

- [ ] **Step 5: Rewrite `serializeWidgetSpecs`**

Replace the whole function (`IslandUtils.js:81-92`) with:

```js
// Always emits five fields, which is what makes field count a safe format
// discriminator on the way back in.
function serializeWidgetSpecs(specs) {
    if (!specs || !specs.length) return "";
    var parts = [];
    for (var i = 0; i < specs.length; i++) {
        var item = specs[i];
        if (typeof item === "string") {
            parts.push(item);
        } else if (item && item.id) {
            var col = (item.col === undefined || item.col === null) ? -1 : item.col;
            var row = (item.row === undefined || item.row === null) ? -1 : item.row;
            parts.push(item.id + ":" + col + ":" + row + ":" + (item.spanW || 3) + ":" + (item.spanH || 1));
        }
    }
    return parts.join(",");
}
```

- [ ] **Step 6: Export `parseCell` to the test harness**

In `tests/islandutils.test.mjs`, add one line to the export list inside the
`new Function(...)` call (after the `serializeWidgetSpecs` line at `:22`):

```js
        "\nexports.parseCell = parseCell;" +
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `node tests/islandutils.test.mjs`
Expected: PASS — `islandutils: all assertions passed`

- [ ] **Step 8: Run the lint gate**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 9: Commit**

```bash
git add package/contents/ui/IslandUtils.js tests/islandutils.test.mjs
git commit -m "feat(panel): widget specs carry explicit col/row

panelWidgets grows from id:spanW:spanH to id:col:row:spanW:spanH. Legacy
three-field entries parse with col/row -1, meaning the placement engine
positions them, so existing configs load unchanged."
```

---

### Task 2: Occupancy map and fit test

**Files:**
- Modify: `package/contents/ui/IslandUtils.js` (append after `serializeWidgetSpecs`)
- Test: `tests/islandutils.test.mjs` (append after the spec assertions from Task 1)

**Interfaces:**
- Consumes: `MAX_COLS`, `MAX_ROWS` from Task 1.
- Produces:
  - `buildOccupancy(items, cols, skipIndex)` → sparse `Array<Array<number>>` indexed `[row][col]`, each cell holding the index of the item covering it. `skipIndex` omits one item; pass `-1` or omit to include all. Items with `col < 0` or `row < 0` are skipped.
  - `fits(occ, col, row, spanW, spanH, cols)` → `boolean`.

- [ ] **Step 1: Write the failing test**

Append to `tests/islandutils.test.mjs`, immediately before the final
`console.log` line:

```js
// buildOccupancy & fits
const grid4 = [
    { id: "network", col: 0, row: 0, spanW: 1, spanH: 1 },
    { id: "bluetooth", col: 1, row: 0, spanW: 1, spanH: 1 },
    { id: "media", col: 0, row: 1, spanW: 3, spanH: 2 }
];
const occ4 = U.buildOccupancy(grid4, 4);
assert.equal(occ4[0][0], 0);
assert.equal(occ4[0][1], 1);
assert.equal(occ4[0][2], undefined);
assert.equal(occ4[2][2], 2, "media spans down into row 2");
assert.equal(occ4[1][3], undefined, "media is 3 wide, column 3 is free");

// skipIndex lifts one widget out, which is what a drag needs.
const occNoMedia = U.buildOccupancy(grid4, 4, 2);
assert.equal(occNoMedia[1], undefined);
assert.equal(occNoMedia[0][0], 0);

// Unplaced widgets occupy nothing.
assert.deepEqual(U.buildOccupancy([{ id: "x", col: -1, row: -1, spanW: 1, spanH: 1 }], 4), []);

assert.equal(U.fits(occ4, 2, 0, 1, 1, 4), true, "free cell");
assert.equal(U.fits(occ4, 0, 0, 1, 1, 4), false, "occupied cell");
assert.equal(U.fits(occ4, 3, 1, 1, 1, 4), true, "beside media");
assert.equal(U.fits(occ4, 2, 0, 3, 1, 4), false, "overflows the right edge");
assert.equal(U.fits(occ4, 3, 0, 1, 1, 4), true, "last column is in bounds");
assert.equal(U.fits(occ4, -1, 0, 1, 1, 4), false, "negative col");
assert.equal(U.fits(occ4, 0, -1, 1, 1, 4), false, "negative row");
assert.equal(U.fits(occ4, 0, 5, 3, 2, 4), true, "empty rows below the content");
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/islandutils.test.mjs`
Expected: FAIL — `TypeError: U.buildOccupancy is not a function`

- [ ] **Step 3: Implement both functions**

Append to `package/contents/ui/IslandUtils.js`, after `serializeWidgetSpecs`:

```js
// Maps every cell a widget covers to that widget's index. Sparse: occ[row][col].
// `skipIndex` leaves one widget out, which is how a drag asks "would this fit if
// the card I am holding were not there?".
function buildOccupancy(items, cols, skipIndex) {
    var occ = [];
    var list = items || [];
    var skip = (skipIndex === undefined || skipIndex === null) ? -1 : skipIndex;
    for (var i = 0; i < list.length; i++) {
        if (i === skip) continue;
        var it = list[i];
        if (!it || it.col < 0 || it.row < 0) continue;
        var w = Math.max(1, Math.min(cols, it.spanW || 1));
        var h = Math.max(1, it.spanH || 1);
        for (var dr = 0; dr < h; dr++) {
            var r = it.row + dr;
            if (!occ[r]) occ[r] = [];
            for (var dc = 0; dc < w; dc++) {
                occ[r][it.col + dc] = i;
            }
        }
    }
    return occ;
}

// True when a spanW x spanH block sits inside the grid at (col,row) without
// overlapping anything in `occ`.
function fits(occ, col, row, spanW, spanH, cols) {
    if (col < 0 || row < 0) return false;
    var w = Math.max(1, spanW || 1);
    var h = Math.max(1, spanH || 1);
    if (col + w > cols) return false;
    for (var dr = 0; dr < h; dr++) {
        var cells = occ[row + dr];
        if (!cells) continue;
        for (var dc = 0; dc < w; dc++) {
            if (cells[col + dc] !== undefined) return false;
        }
    }
    return true;
}
```

- [ ] **Step 4: Export both to the test harness**

In `tests/islandutils.test.mjs`, add to the export list inside `new Function(...)`:

```js
        "\nexports.buildOccupancy = buildOccupancy;" +
        "\nexports.fits = fits;" +
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `node tests/islandutils.test.mjs`
Expected: PASS — `islandutils: all assertions passed`

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/IslandUtils.js tests/islandutils.test.mjs
git commit -m "feat(panel): add grid occupancy map and fit test"
```

---

### Task 3: Placement resolution

**Files:**
- Modify: `package/contents/ui/IslandUtils.js` (append after `fits`)
- Test: `tests/islandutils.test.mjs` (append after the Task 2 assertions)

**Interfaces:**
- Consumes: `buildOccupancy`, `fits`, `MAX_ROWS`.
- Produces:
  - `findFreeSlot(occ, spanW, spanH, cols)` → `{col: number, row: number}`. Always returns a slot; rows grow on demand.
  - `resolvePlacements(items, cols)` → `{items: Array<{id, col, row, spanW, spanH}>, rows: number}`. Pure — returns new objects. `rows` is the count of grid rows the layout occupies (`max(row + spanH)`).

- [ ] **Step 1: Write the failing test**

Append to `tests/islandutils.test.mjs`, before the final `console.log`:

```js
// findFreeSlot
assert.deepEqual(U.findFreeSlot([], 1, 1, 4), { col: 0, row: 0 });
assert.deepEqual(U.findFreeSlot(occ4, 1, 1, 4), { col: 2, row: 0 });
assert.deepEqual(U.findFreeSlot(occ4, 3, 1, 4), { col: 0, row: 3 }, "first row with 3 free columns");

// resolvePlacements — a fully legacy config auto-places in reading order, which
// is byte-identical to what the old greedy packer produced.
const legacySix = [
    { id: "network", col: -1, row: -1, spanW: 1, spanH: 1 },
    { id: "bluetooth", col: -1, row: -1, spanW: 1, spanH: 1 },
    { id: "dnd", col: -1, row: -1, spanW: 1, spanH: 1 },
    { id: "nightlight", col: -1, row: -1, spanW: 1, spanH: 1 },
    { id: "volume", col: -1, row: -1, spanW: 3, spanH: 1 },
    { id: "media", col: -1, row: -1, spanW: 3, spanH: 2 }
];
const resolvedLegacy = U.resolvePlacements(legacySix, 4);
assert.deepEqual(
    resolvedLegacy.items.map((i) => [i.id, i.col, i.row]),
    [
        ["network", 0, 0],
        ["bluetooth", 1, 0],
        ["dnd", 2, 0],
        ["nightlight", 3, 0],
        ["volume", 0, 1],
        ["media", 0, 2]
    ],
);
assert.equal(resolvedLegacy.rows, 4);

// Explicit placements are honoured, holes are preserved.
const holes = [
    { id: "network", col: 3, row: 2, spanW: 1, spanH: 1 },
    { id: "media", col: 0, row: 0, spanW: 3, spanH: 2 }
];
const resolvedHoles = U.resolvePlacements(holes, 4);
assert.deepEqual(resolvedHoles.items.map((i) => [i.id, i.col, i.row]), [
    ["network", 3, 2],
    ["media", 0, 0]
]);
assert.equal(resolvedHoles.rows, 3);

// Input is not mutated.
assert.equal(holes[0].col, 3);

// 4 -> 2 column shrink: spans clamp to the new width and columns slide left.
const shrunk = U.resolvePlacements(holes, 2);
assert.deepEqual(shrunk.items.map((i) => [i.id, i.col, i.row, i.spanW, i.spanH]), [
    ["network", 1, 2, 1, 1],
    ["media", 0, 0, 2, 2]
]);
assert.equal(shrunk.rows, 3);

// A widget resized past the right edge slides left rather than overflowing — this
// is the pass-1 clamp that keeps a resize at column 3 legal.
const resizedEdge = U.resolvePlacements([
    { id: "network", col: 3, row: 0, spanW: 2, spanH: 1 }
], 4);
assert.deepEqual(resizedEdge.items.map((i) => [i.col, i.row, i.spanW]), [[2, 0, 2]]);

// A widget whose explicit cell is taken falls through to auto-placement, and it
// is the loser that moves, never the widget already sitting there.
const clash = [
    { id: "media", col: 0, row: 0, spanW: 3, spanH: 2 },
    { id: "volume", col: 0, row: 1, spanW: 3, spanH: 1 }
];
const resolvedClash = U.resolvePlacements(clash, 4);
assert.deepEqual(resolvedClash.items.map((i) => [i.id, i.col, i.row]), [
    ["media", 0, 0],
    ["volume", 0, 2]
]);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/islandutils.test.mjs`
Expected: FAIL — `TypeError: U.findFreeSlot is not a function`

- [ ] **Step 3: Implement both functions**

Append to `package/contents/ui/IslandUtils.js`, after `fits`:

```js
// First free slot in reading order. Rows grow on demand so this always finds
// somewhere; MAX_ROWS only stops a runaway loop on a corrupted grid.
function findFreeSlot(occ, spanW, spanH, cols) {
    var w = Math.max(1, Math.min(cols, spanW || 1));
    var h = Math.max(1, spanH || 1);
    for (var r = 0; r < MAX_ROWS; r++) {
        for (var c = 0; c <= cols - w; c++) {
            if (fits(occ, c, r, w, h, cols)) {
                return { col: c, row: r };
            }
        }
    }
    return { col: 0, row: 0 };
}

// Turns a list of widgets into a laid-out grid. Two passes: honour every explicit
// placement that still fits, sliding a widget left when its span no longer
// reaches the right edge; then auto-place whatever is left in reading order.
// Pure — the caller writes the returned values back to the model.
function resolvePlacements(items, cols) {
    var list = items || [];
    var out = [];
    var i;

    for (i = 0; i < list.length; i++) {
        var src = list[i] || {};
        out.push({
            id: src.id,
            col: (src.col === undefined || src.col === null) ? -1 : src.col,
            row: (src.row === undefined || src.row === null) ? -1 : src.row,
            spanW: Math.max(1, Math.min(cols, src.spanW || 1)),
            spanH: Math.max(1, src.spanH || 1)
        });
    }

    var occ = [];

    function mark(item, index) {
        for (var dr = 0; dr < item.spanH; dr++) {
            var r = item.row + dr;
            if (!occ[r]) occ[r] = [];
            for (var dc = 0; dc < item.spanW; dc++) {
                occ[r][item.col + dc] = index;
            }
        }
    }

    for (i = 0; i < out.length; i++) {
        var placed = out[i];
        if (placed.col < 0 || placed.row < 0) continue;
        var col = Math.max(0, Math.min(placed.col, cols - placed.spanW));
        if (fits(occ, col, placed.row, placed.spanW, placed.spanH, cols)) {
            placed.col = col;
            mark(placed, i);
        } else {
            placed.col = -1;
            placed.row = -1;
        }
    }

    for (i = 0; i < out.length; i++) {
        var loose = out[i];
        if (loose.col >= 0 && loose.row >= 0) continue;
        var slot = findFreeSlot(occ, loose.spanW, loose.spanH, cols);
        loose.col = slot.col;
        loose.row = slot.row;
        mark(loose, i);
    }

    var rows = 0;
    for (i = 0; i < out.length; i++) {
        var bottom = out[i].row + out[i].spanH;
        if (bottom > rows) rows = bottom;
    }

    return { items: out, rows: rows };
}
```

- [ ] **Step 4: Export both to the test harness**

In `tests/islandutils.test.mjs`, add to the export list inside `new Function(...)`:

```js
        "\nexports.findFreeSlot = findFreeSlot;" +
        "\nexports.resolvePlacements = resolvePlacements;" +
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `node tests/islandutils.test.mjs`
Expected: PASS — `islandutils: all assertions passed`

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/IslandUtils.js tests/islandutils.test.mjs
git commit -m "feat(panel): resolve widget placements from explicit cells

Two-pass placement: honour explicit col/row that still fit, clamping a
span that overflows the right edge, then auto-place the rest in reading
order. A fully legacy config resolves to the same layout the old greedy
packer produced."
```

---

### Task 4: Drop decision

**Files:**
- Modify: `package/contents/ui/IslandUtils.js` (append after `resolvePlacements`)
- Test: `tests/islandutils.test.mjs` (append after the Task 3 assertions)

**Interfaces:**
- Consumes: `buildOccupancy`, `fits`, `MAX_ROWS`.
- Produces:
  - `cellFromPixel(x, y, colW, rowH, gap)` → `{col: number, row: number}`, nearest cell (rounded, may be out of bounds).
  - `dropResult(items, dragIndex, col, row, cols)` → `{action: "move"|"swap"|"reject", col: number, row: number, withIndex?: number}`. `col`/`row` are always present and always clamped into the grid, so the caller can draw a preview for every outcome. `withIndex` is only set for `swap`, and for `swap` the returned `col`/`row` are the occupant's cell.

- [ ] **Step 1: Write the failing test**

Append to `tests/islandutils.test.mjs`, before the final `console.log`:

```js
// cellFromPixel — rounds to the nearest slot, so a card need not be aligned.
assert.deepEqual(U.cellFromPixel(0, 0, 125, 54, 10), { col: 0, row: 0 });
assert.deepEqual(U.cellFromPixel(135, 64, 125, 54, 10), { col: 1, row: 1 });
assert.deepEqual(U.cellFromPixel(80, 0, 125, 54, 10), { col: 1, row: 0 }, "past halfway rounds up");
assert.deepEqual(U.cellFromPixel(60, 0, 125, 54, 10), { col: 0, row: 0 }, "before halfway rounds down");

// dropResult
const drop = [
    { id: "network", col: 0, row: 0, spanW: 1, spanH: 1 },
    { id: "bluetooth", col: 1, row: 0, spanW: 1, spanH: 1 },
    { id: "media", col: 0, row: 1, spanW: 3, spanH: 2 }
];

// Free cell -> move.
assert.deepEqual(U.dropResult(drop, 0, 2, 0, 4), { action: "move", col: 2, row: 0 });

// Same span, single occupant -> swap onto that occupant's exact cell.
assert.deepEqual(U.dropResult(drop, 0, 1, 0, 4), { action: "swap", col: 1, row: 0, withIndex: 1 });

// Different span -> reject, but still report a clamped preview cell.
assert.deepEqual(U.dropResult(drop, 0, 1, 1, 4), { action: "reject", col: 1, row: 1 });

// A wide card dropped over two 1x1 widgets overlaps two occupants -> reject.
assert.deepEqual(U.dropResult(drop, 2, 0, 0, 4), { action: "reject", col: 0, row: 0 });

// Dropping on itself is a move to the same cell; nothing else has to special-case it.
assert.deepEqual(U.dropResult(drop, 0, 0, 0, 4), { action: "move", col: 0, row: 0 });

// Out of bounds clamps instead of rejecting.
assert.deepEqual(U.dropResult(drop, 2, 7, 0, 4), { action: "reject", col: 1, row: 0 });
assert.deepEqual(U.dropResult(drop, 0, 9, 9, 4), { action: "move", col: 3, row: 9 });
assert.deepEqual(U.dropResult(drop, 0, -4, -4, 4), { action: "move", col: 0, row: 0 });

// An unknown index is refused rather than throwing.
assert.equal(U.dropResult(drop, 99, 0, 0, 4).action, "reject");
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/islandutils.test.mjs`
Expected: FAIL — `TypeError: U.cellFromPixel is not a function`

- [ ] **Step 3: Implement both functions**

Append to `package/contents/ui/IslandUtils.js`, after `resolvePlacements`:

```js
// Nearest cell to a pixel offset. Round rather than floor: the card snaps to the
// closest slot instead of demanding precise alignment. May be out of bounds —
// dropResult clamps.
function cellFromPixel(x, y, colW, rowH, gap) {
    var stepX = (colW || 1) + (gap || 0);
    var stepY = (rowH || 1) + (gap || 0);
    return {
        col: Math.round((x || 0) / stepX),
        row: Math.round((y || 0) / stepY)
    };
}

// Decides what dropping `dragIndex` at (col,row) does. The target is clamped into
// the grid before collisions are checked, so "reject" always means a real
// collision rather than an overshoot, and every outcome carries a cell the caller
// can draw a preview at.
//
// A swap is only offered when the dragged footprint covers exactly one widget of
// identical span; that exchange cannot fail, because the hole the dragged card
// leaves behind is the same shape as the occupant.
function dropResult(items, dragIndex, col, row, cols) {
    var list = items || [];
    var dragged = list[dragIndex];
    if (!dragged) {
        return { action: "reject", col: 0, row: 0 };
    }

    var w = Math.max(1, Math.min(cols, dragged.spanW || 1));
    var h = Math.max(1, dragged.spanH || 1);
    var c = Math.max(0, Math.min(col, cols - w));
    var r = Math.max(0, Math.min(row, MAX_ROWS - h));

    var occ = buildOccupancy(list, cols, dragIndex);

    if (fits(occ, c, r, w, h, cols)) {
        return { action: "move", col: c, row: r };
    }

    var occupant = -1;
    for (var dr = 0; dr < h; dr++) {
        var cells = occ[r + dr];
        if (!cells) continue;
        for (var dc = 0; dc < w; dc++) {
            var hit = cells[c + dc];
            if (hit === undefined) continue;
            if (occupant === -1) {
                occupant = hit;
            } else if (occupant !== hit) {
                return { action: "reject", col: c, row: r };
            }
        }
    }

    if (occupant < 0) {
        return { action: "reject", col: c, row: r };
    }

    var other = list[occupant];
    if (other.spanW !== dragged.spanW || other.spanH !== dragged.spanH) {
        return { action: "reject", col: c, row: r };
    }

    return { action: "swap", col: other.col, row: other.row, withIndex: occupant };
}
```

- [ ] **Step 4: Export both to the test harness**

In `tests/islandutils.test.mjs`, add to the export list inside `new Function(...)`:

```js
        "\nexports.cellFromPixel = cellFromPixel;" +
        "\nexports.dropResult = dropResult;" +
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `node tests/islandutils.test.mjs`
Expected: PASS — `islandutils: all assertions passed`

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/IslandUtils.js tests/islandutils.test.mjs
git commit -m "feat(panel): decide drops as move, swap or reject

Targets are clamped into the grid before collisions are checked, so an
overshoot pins to the nearest valid cell and reject is reserved for real
collisions. Swap is offered only for a single occupant of identical span."
```

---

### Task 5: Panel drives layout from the placement engine

**Files:**
- Modify: `package/contents/ui/IslandPanel.qml:17-18` (drag state), `:43-118` (packer → engine), `:123-213` (model management), `:371-376` (delegate)

**Interfaces:**
- Consumes: `Utils.resolvePlacements`, `Utils.buildOccupancy`, `Utils.fits`, `Utils.parseWidgetSpecs`, `Utils.serializeWidgetSpecs`.
- Produces (all on the `panel` root, used by Tasks 6 and 7):
  - `applyLayout()` — resolves cells and writes `col`, `row`, `spanW`, `spanH`, `layoutX/Y/W/H` back to `gridModel`, then sets `calculatedGridHeight`.
  - `cancelDrag()` — clears all drag state.
  - `currentSpecs()` → `Array<{id, col, row, spanW, spanH}>`.
  - `readonly property real rowHeight`.
  - Drag state: `dragging`, `activeDragIndex`, `dragTransX`, `dragTransY`, `autoScrollAccum`, `dragSpanW`, `dragSpanH`, `dropAction`, `dropCol`, `dropRow`, `dropSwapIndex`.

There is no headless QML test for this file — it reads `Plasmoid.configuration`
at property-init time (`:21-23`, `:121`), the same blocker
`tests/configpages.check.qml:19` documents for `configPanel.qml`. Verification is
the lint gate plus the live check.

`maxRows` (`:32`) needs no edit: it only feeds `maxGridHeight` and `maxH`, which
are viewport caps. It was never consulted by the packer, so placement is already
free of it.

- [ ] **Step 1: Add drag and drop state**

Replace `IslandPanel.qml:17-18`:

```qml
    property bool dragging: false
    property int activeDragIndex: -1
```

with:

```qml
    property bool dragging: false
    property int activeDragIndex: -1

    // Live drag offset. The delegate adds these to its layout position through a
    // binding, so nothing ever assigns x/y directly and the binding to the
    // placement engine survives every drag.
    property real dragTransX: 0
    property real dragTransY: 0
    property real autoScrollAccum: 0
    property int dragSpanW: 1
    property int dragSpanH: 1

    // Previewed drop, recomputed on every drag move.
    property string dropAction: "move"
    property int dropCol: 0
    property int dropRow: 0
    property int dropSwapIndex: -1
```

- [ ] **Step 2: Replace the packer with the placement engine**

Replace `IslandPanel.qml:43-118` — the whole
`// ── 2D Grid Packing Engine ──` section, from that comment through the
`onColumnsChanged: rebuild()` line — with:

```qml
    // ── Layout ─────────────────────────────────────────────────────────
    // Cells come from Utils.resolvePlacements; this only turns them into pixels
    // and writes them back for the delegates to bind to.
    readonly property real rowHeight: baseRowHeight

    function applyLayout() {
        if (!gridModel || gridModel.count === 0) return
        const resolved = Utils.resolvePlacements(currentSpecs(), columns)
        for (let i = 0; i < resolved.items.length; i++) {
            const it = resolved.items[i]
            gridModel.setProperty(i, "col", it.col)
            gridModel.setProperty(i, "row", it.row)
            gridModel.setProperty(i, "spanW", it.spanW)
            gridModel.setProperty(i, "spanH", it.spanH)
            gridModel.setProperty(i, "layoutX", Math.round(it.col * (colWidth + gap)))
            gridModel.setProperty(i, "layoutY", Math.round(it.row * (rowHeight + gap)))
            gridModel.setProperty(i, "layoutW", Math.round(it.spanW * colWidth + (it.spanW - 1) * gap))
            gridModel.setProperty(i, "layoutH", Math.round(it.spanH * rowHeight + (it.spanH - 1) * gap))
        }
        calculatedGridHeight = resolved.rows > 0
            ? Math.round(resolved.rows * rowHeight + (resolved.rows - 1) * gap)
            : rowHeight
    }

    function cancelDrag() {
        activeDragIndex = -1
        dragging = false
        dragTransX = 0
        dragTransY = 0
        autoScrollAccum = 0
        dropSwapIndex = -1
    }

    onColWidthChanged: applyLayout()
    onAvailableWidthChanged: applyLayout()
    onGapChanged: applyLayout()

    // A column change invalidates any drop being previewed against the old grid.
    onColumnsChanged: {
        cancelDrag()
        applyLayout()
        persistOrder()
    }
```

- [ ] **Step 3: Carry col/row through the model functions**

In `IslandPanel.qml`, replace `currentSpecs` (`:123-130`) with:

```qml
    function currentSpecs() {
        let specs = []
        for (let i = 0; i < gridModel.count; i++) {
            const item = gridModel.get(i)
            specs.push({ id: item.widgetId, col: item.col, row: item.row, spanW: item.spanW, spanH: item.spanH })
        }
        return specs
    }
```

Replace the `gridModel.append({...})` call inside `rebuild` (`:146-154`) with:

```qml
            gridModel.append({
                widgetId: specs[i].id,
                col: specs[i].col,
                row: specs[i].row,
                spanW: sw,
                spanH: sh,
                layoutX: 0,
                layoutY: 0,
                layoutW: 100,
                layoutH: 48
            })
```

Replace `rebuild`'s closing `updateLayoutPositions()` (`:156`) with `applyLayout()`.

Replace `persistOrder` (`:159-162`) with:

```qml
    function persistOrder() {
        // Never write an empty layout: a change signal can fire before rebuild()
        // has populated the model.
        if (gridModel.count === 0) return
        const next = Utils.serializeWidgetSpecs(currentSpecs())
        if (next !== Plasmoid.configuration.panelWidgets) {
            Plasmoid.configuration.panelWidgets = next
        }
    }
```

Replace the `gridModel.append({...})` inside `addWidget` (`:170-178`) with:

```qml
        // col/row -1 hands placement to the auto-placer, which fills the first
        // free slot in reading order.
        gridModel.append({
            widgetId: id,
            col: -1,
            row: -1,
            spanW: spanW,
            spanH: spanH,
            layoutX: 0,
            layoutY: 0,
            layoutW: 100,
            layoutH: 48
        })
```

In `addWidget` (`:179`) and `removeWidget` (`:186`), replace each
`updateLayoutPositions()` with `applyLayout()`.

- [ ] **Step 4: Make resize move the resized widget, not its neighbours**

Replace `cycleWidgetSpan` (`:191-203`) with:

```qml
    function cycleWidgetSpan(index) {
        if (index < 0 || index >= gridModel.count) return
        const current = gridModel.get(index)
        let next = Utils.cycleSpan2D(current.spanW, current.spanH, panel.columns)
        if (current.widgetId === "timer" && next.spanW === 1 && next.spanH === 1) {
            next = { spanW: 2, spanH: 1 }
        }
        gridModel.setProperty(index, "spanW", next.spanW)
        gridModel.setProperty(index, "spanH", next.spanH)

        // The resized widget yields, never its neighbours. Slide it left to fit,
        // and if it still collides hand it to the auto-placer. resolvePlacements
        // alone would not do this: it resolves conflicts by model order, which
        // could displace a widget the user did not touch.
        const occ = Utils.buildOccupancy(currentSpecs(), panel.columns, index)
        const clamped = Math.max(0, Math.min(current.col, panel.columns - next.spanW))
        if (Utils.fits(occ, clamped, current.row, next.spanW, next.spanH, panel.columns)) {
            gridModel.setProperty(index, "col", clamped)
        } else {
            gridModel.setProperty(index, "col", -1)
            gridModel.setProperty(index, "row", -1)
        }

        applyLayout()
        persistOrder()
    }
```

- [ ] **Step 5: Run the lint gate**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 6: Run the pure-JS tests (regression check)**

Run: `node tests/islandutils.test.mjs`
Expected: PASS — `islandutils: all assertions passed`

- [ ] **Step 7: Live check that the existing layout is unchanged**

```bash
./install.sh
plasmawindowed com.deadindian.dynamicisland
```

Expected: the panel opens with the same widget arrangement as before the change,
and no QML errors in the terminal. Dragging does not work yet — that is Task 6.
Confirm resize (the `NxM` pill) and delete still work, and that a widget added
from the drawer lands in the first free slot.

- [ ] **Step 8: Commit**

```bash
git add package/contents/ui/IslandPanel.qml
git commit -m "refactor(panel): lay out widgets from explicit cells

Replaces the greedy first-fit packer with Utils.resolvePlacements. The
model carries col/row, layout only converts cells to pixels, and resize
moves the resized widget rather than displacing whichever neighbour it
collides with."
```

---

### Task 6: Drag on `DragHandler`, with a drop preview

**Files:**
- Modify: `package/contents/ui/IslandPanel.qml:362-376` (grid item and delegate geometry), `:501-550` (edit overlay: replace `dragGripMouse`)

**Interfaces:**
- Consumes: `applyLayout`, `cancelDrag`, `currentSpecs`, `rowHeight`, and all drag state from Task 5; `Utils.cellFromPixel`, `Utils.dropResult`.
- Produces: `panel.evaluateDrop(index, pixelX, pixelY)` — recomputes `dropAction`, `dropCol`, `dropRow`, `dropSwapIndex`.

- [ ] **Step 1: Add the drop evaluator**

In `IslandPanel.qml`, add after `cancelDrag()` from Task 5:

```qml
    // Resolves the previewed drop from where the dragged card currently sits.
    function evaluateDrop(index, pixelX, pixelY) {
        const cell = Utils.cellFromPixel(pixelX, pixelY, colWidth, rowHeight, gap)
        const res = Utils.dropResult(currentSpecs(), index, cell.col, cell.row, columns)
        dropAction = res.action
        dropCol = res.col
        dropRow = res.row
        dropSwapIndex = res.action === "swap" ? res.withIndex : -1
    }
```

- [ ] **Step 2: Let the grid grow while dragging**

Replace `IslandPanel.qml:362-365`:

```qml
                Item {
                    id: gridLayout
                    width: panel.availableWidth
                    implicitHeight: panel.calculatedGridHeight
```

with:

```qml
                Item {
                    id: gridLayout
                    width: panel.availableWidth
                    // While dragging, the content has to reach the previewed cell or
                    // the bottom row of the grid would be the lowest a widget could
                    // ever go, and bottom-edge autoscroll would have nowhere to run.
                    implicitHeight: panel.dragging
                        ? Math.max(panel.calculatedGridHeight,
                                   Math.round((panel.dropRow + panel.dragSpanH) * (panel.rowHeight + panel.gap)))
                        : panel.calculatedGridHeight
```

- [ ] **Step 3: Add the drop placeholder**

Insert inside `gridLayout`, directly before `Repeater { id: gridRepeater`:

```qml
                    // Single shared drop preview. z: 0 keeps it behind the cards.
                    Rectangle {
                        id: dropPlaceholder
                        visible: panel.dragging
                        z: 0
                        radius: 16
                        color: "transparent"
                        border.width: 2
                        border.color: panel.dropAction === "reject"
                            ? Qt.rgba(0.9, 0.25, 0.25, 0.9)
                            : (island ? island.accent : "#3498db")

                        x: Math.round(panel.dropCol * (panel.colWidth + panel.gap))
                        y: Math.round(panel.dropRow * (panel.rowHeight + panel.gap))
                        width: Math.round(panel.dragSpanW * panel.colWidth + (panel.dragSpanW - 1) * panel.gap)
                        height: Math.round(panel.dragSpanH * panel.rowHeight + (panel.dragSpanH - 1) * panel.gap)

                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }
```

- [ ] **Step 4: Make the delegate follow the cursor through a binding**

Replace `IslandPanel.qml:371-378` — the delegate header through its
`readonly property bool isBeingDragged` line — with:

```qml
                        delegate: Item {
                            id: cardItem

                            readonly property bool isBeingDragged: panel.activeDragIndex === index
                            // Offsets, not assignments: x/y stay bound to the layout
                            // engine, so releasing the card animates it home for free.
                            readonly property real dragDX: isBeingDragged ? panel.dragTransX : 0
                            readonly property real dragDY: isBeingDragged ? panel.dragTransY + panel.autoScrollAccum : 0

                            x: (model.layoutX !== undefined ? model.layoutX : 0) + dragDX
                            y: (model.layoutY !== undefined ? model.layoutY : 0) + dragDY
                            width: model.layoutW !== undefined ? model.layoutW : 100
                            height: model.layoutH !== undefined ? model.layoutH : 48
```

Note the original declares `isBeingDragged` *after* the geometry block; this
replacement moves it above, so make sure the old declaration is gone and only one
remains.

- [ ] **Step 5: Replace the drag `MouseArea` with a `DragHandler`**

Replace `IslandPanel.qml:511-550` — the entire `MouseArea { id: dragGripMouse ... }`
block including its `onPressed`, `onPositionChanged` and `onReleased` handlers —
with:

```qml
                                    // Swallows clicks so the live widget beneath is
                                    // inert while editing. The DragHandler takes the
                                    // grab from it once the drag threshold is crossed.
                                    MouseArea {
                                        id: editBlocker
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    DragHandler {
                                        id: cardDrag
                                        target: null
                                        enabled: panel.editMode
                                        dragThreshold: 6
                                        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        // Default grabPermissions include
                                        // ApprovesTakeOverByItems, which lets the parent
                                        // Flickable steal the grab mid-drag — the card
                                        // starts moving and the grid scrolls instead.
                                        grabPermissions: PointerHandler.CanTakeOverFromItems
                                            | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                            | PointerHandler.ApprovesTakeOverByHandlersOfSameType

                                        onActiveChanged: {
                                            if (cardDrag.active) {
                                                panel.activeDragIndex = index
                                                panel.dragging = true
                                                panel.dragSpanW = model.spanW
                                                panel.dragSpanH = model.spanH
                                                panel.dragTransX = 0
                                                panel.dragTransY = 0
                                                panel.autoScrollAccum = 0
                                                panel.dropAction = "move"
                                                panel.dropCol = model.col
                                                panel.dropRow = model.row
                                                panel.dropSwapIndex = -1
                                                return
                                            }

                                            const action = panel.dropAction
                                            const col = panel.dropCol
                                            const row = panel.dropRow
                                            const swapWith = panel.dropSwapIndex
                                            const from = index
                                            const oldCol = model.col
                                            const oldRow = model.row

                                            // Clear activeDragIndex first: that re-enables
                                            // Behavior on x/y, so the card animates from
                                            // where it was let go to where it lands.
                                            panel.activeDragIndex = -1
                                            panel.dragging = false

                                            if (action === "move") {
                                                gridModel.setProperty(from, "col", col)
                                                gridModel.setProperty(from, "row", row)
                                                panel.applyLayout()
                                                panel.persistOrder()
                                            } else if (action === "swap" && swapWith >= 0) {
                                                gridModel.setProperty(from, "col", col)
                                                gridModel.setProperty(from, "row", row)
                                                gridModel.setProperty(swapWith, "col", oldCol)
                                                gridModel.setProperty(swapWith, "row", oldRow)
                                                panel.applyLayout()
                                                panel.persistOrder()
                                            }

                                            panel.dragTransX = 0
                                            panel.dragTransY = 0
                                            panel.autoScrollAccum = 0
                                            panel.dropSwapIndex = -1
                                        }

                                        onActiveTranslationChanged: {
                                            if (!cardDrag.active) return
                                            panel.dragTransX = cardDrag.activeTranslation.x
                                            panel.dragTransY = cardDrag.activeTranslation.y
                                            panel.evaluateDrop(index, cardItem.x, cardItem.y)
                                        }
                                    }
```

- [ ] **Step 6: Show the swap partner and fix the press feedback**

The overlay's darkening still refers to the deleted `dragGripMouse`. Add a swap
flag to the delegate, immediately after the `dragDY` property added in Step 4:

```qml
                            readonly property bool isSwapTarget: panel.dragging
                                && panel.dropAction === "swap"
                                && panel.dropSwapIndex === index
```

Then replace `IslandPanel.qml:505-509` with:

```qml
                                    color: cardDrag.active ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.3)
                                    border.width: (cardItem.isBeingDragged || cardItem.isSwapTarget) ? 2 : 1
                                    border.color: cardItem.isBeingDragged
                                        ? (island ? island.accent : "#3498db")
                                        : (cardItem.isSwapTarget
                                            ? Qt.rgba(1, 1, 1, 0.8)
                                            : Qt.rgba(1, 1, 1, 0.25))
```

The delegate's `z: isBeingDragged ? 99 : 1` and `scale` already lift the dragged
card above its neighbours — leave both alone.

- [ ] **Step 7: Lint**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

If `qmllint` reports an unqualified access warning for `island`, ignore it — the
filter in `qmlcheck.sh` only fails on `[syntax]`, `[import]` and `Error:`.

- [ ] **Step 8: Re-run the JS suite**

Run: `node tests/islandutils.test.mjs`
Expected: `islandutils: all assertions passed`

- [ ] **Step 9: Live check**

Run:

```bash
./install.sh && plasmawindowed com.deadindian.dynamicisland
```

Open the widget panel, enter edit mode, and confirm:

1. Pressing a card and moving 6px starts a drag; the card tracks the cursor.
2. An outline appears at the snapped cell and glides between cells.
3. Dropping a 1x1 onto another 1x1 swaps them; the partner brightens first.
4. Dropping a 1x1 onto the 3x2 media card turns the outline red and nothing moves;
   the card animates back to its original slot.
5. Clicking a card without moving it leaves the layout untouched.

- [ ] **Step 10: Commit**

```bash
git add package/contents/ui/IslandPanel.qml
git commit -m "feat: drag widgets with DragHandler and preview the drop cell"
```

---

### Task 7: Edit-mode scrolling, autoscroll and the grip glyph

Free placement means widgets can live below the fold, so edit mode has to scroll,
and a drag that reaches the bottom edge has to pull the grid up with it.

**Files:**
- Modify: `package/contents/ui/IslandPanel.qml`

**Interfaces:**
- Consumes: `panel.dragging`, `panel.dragTransX/Y`, `panel.autoScrollAccum`,
  `panel.dragSpanW/H`, `panel.evaluateDrop()`, `editBlocker`, `cardDrag` (Task 6);
  `Plasmoid.configuration.panelShowGrips` (`main.xml:306`, already declared).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Publish the dragged card's geometry on the panel**

The autoscroll timer lives outside the delegate, so it cannot read `cardItem.x`.
Derive the card's position from panel state instead. Add next to the drag-state
properties from Task 5:

```qml
    // Where the dragged card sat when the gesture began, in content coordinates.
    property real dragBaseX: 0
    property real dragBaseY: 0

    readonly property real dragCardX: dragBaseX + dragTransX
    readonly property real dragCardY: dragBaseY + dragTransY + autoScrollAccum
    readonly property real dragCardH: Math.round(dragSpanH * rowHeight + (dragSpanH - 1) * gap)

    readonly property bool showGrips: Plasmoid.configuration.panelShowGrips
```

And in the `cardDrag.onActiveChanged` start branch from Task 6 Step 5, alongside
`panel.dragSpanW = model.spanW`, record the origin:

```qml
                                                panel.dragBaseX = model.layoutX !== undefined ? model.layoutX : 0
                                                panel.dragBaseY = model.layoutY !== undefined ? model.layoutY : 0
```

- [ ] **Step 2: Let edit mode scroll**

Replace `IslandPanel.qml:340`:

```qml
                interactive: !panel.dragging
```

Was `!panel.editMode && !panel.dragging`, which made every widget below the fold
unreachable while editing.

- [ ] **Step 3: Add the autoscroll timer**

Insert inside `gridFlickable`, after the closing brace of the
`QQC2.ScrollBar.vertical` block and before `Item { id: gridLayout`:

```qml
                // Edge autoscroll. contentY moves, and the same delta is added to
                // autoScrollAccum so the card stays pinned under the cursor while
                // the grid slides beneath it — without that it drifts away.
                Timer {
                    id: autoScroller
                    interval: 16
                    repeat: true
                    running: panel.dragging && gridFlickable.contentHeight > gridFlickable.height

                    readonly property real zone: 40
                    readonly property real maxStep: 14

                    onTriggered: {
                        if (panel.activeDragIndex < 0) return

                        const top = panel.dragCardY - gridFlickable.contentY
                        const bottom = top + panel.dragCardH
                        let dy = 0
                        if (top < zone) {
                            dy = -maxStep * Math.min(1, (zone - top) / zone)
                        } else if (bottom > gridFlickable.height - zone) {
                            dy = maxStep * Math.min(1, (bottom - (gridFlickable.height - zone)) / zone)
                        }
                        if (dy === 0) return

                        const limit = Math.max(0, gridFlickable.contentHeight - gridFlickable.height)
                        const next = Math.max(0, Math.min(gridFlickable.contentY + dy, limit))
                        const applied = next - gridFlickable.contentY
                        if (applied === 0) return

                        gridFlickable.contentY = next
                        panel.autoScrollAccum += applied
                        panel.evaluateDrop(panel.activeDragIndex, panel.dragCardX, panel.dragCardY)
                    }
                }
```

- [ ] **Step 4: Draw the grip glyph**

Six dots at the card's top-left, hand-drawn rather than a `Kirigami.Icon` so it
does not depend on an icon-theme name being present. Insert inside the edit overlay
`Rectangle`, after the `DragHandler` from Task 6 Step 5:

```qml
                                    // Hint only — the whole overlay is grabbable.
                                    Grid {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.leftMargin: 8
                                        anchors.topMargin: 8
                                        columns: 2
                                        rows: 3
                                        rowSpacing: 3
                                        columnSpacing: 3
                                        opacity: (panel.showGrips || editBlocker.containsMouse || cardDrag.active) ? 0.8 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }

                                        Repeater {
                                            model: 6
                                            delegate: Rectangle {
                                                width: 3
                                                height: 3
                                                radius: 1.5
                                                color: "white"
                                            }
                                        }
                                    }
```

This is the first read of `panelShowGrips`. Its label at `configPanel.qml:122` —
"Always show drag handle grips on widgets (otherwise visible on hover)" — now
describes what the switch actually does.

- [ ] **Step 5: Lint**

Run: `./tests/qmlcheck.sh`
Expected: `qmlcheck: OK`

- [ ] **Step 6: Live check**

Run:

```bash
./install.sh && plasmawindowed com.deadindian.dynamicisland
```

Confirm:
1. In edit mode the grid scrolls with the wheel.
2. Dragging a card toward the bottom edge scrolls the grid, and the card stays
   under the cursor rather than drifting up.
3. Dropping into a newly revealed row works and survives a `plasmashell` restart.
4. Turning off *Always show grips* in the panel settings leaves the dots visible on
   hover only.

- [ ] **Step 7: Commit**

```bash
git add package/contents/ui/IslandPanel.qml
git commit -m "feat: scroll and autoscroll the widget grid while editing"
```

---

### Task 8: Release notes and version bump

`CONTRIBUTING.md` requires a `CHANGELOG.md` entry and a version bump in
`package/metadata.json` for any user-visible change.

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `package/metadata.json:16`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Bump the version**

`package/metadata.json` currently reads `"Version": "1.4.0"`. New behaviour plus a
backward-compatible config format means a minor bump:

```json
        "Version": "1.5.0",
```

- [ ] **Step 2: Add the changelog entry**

Insert directly below the `[Keep a Changelog]` / `[Semantic Versioning]` paragraph
and above `## [1.4.0] — 2026-08-31`:

```markdown
## [1.5.0] — 2026-09-01
### Changed
- **Widget panel drag rewritten around free grid placement.** Cards now follow the
  cursor, snap to the nearest cell, and stay exactly where they are dropped instead
  of reflowing the whole grid. Each widget stores an explicit column and row, so
  gaps are allowed and a layout no longer shifts when a neighbour moves.
- Dropping a widget onto another of the **same size swaps the two**; any other
  collision is refused, previewed with a red outline, and the card animates back to
  where it started.
- A **drop outline** previews the destination cell during the drag, and the swap
  partner is highlighted before the exchange commits.
- Dragging needs **6px of movement** to begin, so a click on a card in edit mode no
  longer counts as a move — and no longer rewrites the saved layout.
- The widget grid **scrolls in edit mode**, with autoscroll when a drag reaches the
  top or bottom edge. Widgets below the fold were previously unreachable while
  editing.
- Rows grow on demand: a widget can be dropped into a new row below the current
  layout instead of being limited to the preset's row count.
- **Always show grips** now works. The setting existed since 1.4.0 but the panel
  never read it; the grip dots now honour it and otherwise appear on hover.

### Fixed
- Moving a widget no longer repacks unrelated widgets in the grid.
- The parent scroll view can no longer steal a drag in progress, which caused the
  grid to scroll instead of the card moving.
```

The `panelWidgets` config string grows from `id:spanW:spanH` to
`id:col:row:spanW:spanH`. Existing configs load unchanged — this needs no
⚠️ Breaking section, unlike 1.4.0's plugin rename.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md package/metadata.json
git commit -m "chore: release 1.5.0 — free grid placement for panel widgets"
```

---

## Done when

- `node tests/islandutils.test.mjs` prints `islandutils: all assertions passed`.
- `./tests/qmlcheck.sh` prints `qmlcheck: OK`.
- The manual checklist from the spec's Testing section passes end to end:
  swap two 1x1 toggles; refuse a 1x1 onto the media card; drop into empty space;
  autoscroll keeps the card under the cursor; a click writes nothing; the 4 → 2
  preset flip and back; a resize at the right edge; a `plasmashell` restart reloads
  the layout identically.
