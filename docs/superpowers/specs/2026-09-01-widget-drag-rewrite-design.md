# Widget Drag Rewrite — Free Grid Placement

- **Date:** 2026-09-01
- **Status:** Approved, ready for implementation planning
- **Scope:** Panel widget move/reorder interaction in `package/contents/ui/IslandPanel.qml`

## Problem

Moving widgets in the panel does not feel like moving widgets. The causes are
structural, not a matter of tuning animation durations.

1. **The dragged card never follows the cursor.** `x` and `y` are bound to
   `model.layoutX` / `model.layoutY` (`IslandPanel.qml:373-374`) and nothing
   overrides them during a drag. The only visible change is border colour and a
   glow. The user drags and nothing moves under the pointer.

2. **No drag threshold.** `onPressed` sets `dragging = true` immediately
   (`:516`), so every click on a card in edit mode begins a drag and ends by
   writing the config.

3. **Reorder is index-based, layout is greedy first-fit.** A drop calls
   `gridModel.move()` and repacks (`:539-541`). Moving a 3x2 widget by one index
   reflows the entire grid, so the result rarely matches intent.

4. **Hit-test thrash.** The target is found by testing the pointer, mapped
   through the very `MouseArea` that just moved, against sibling delegates
   (`:521-543`). After `activeDragIndex = target` the pointer is still over the
   old slot, which retriggers the move.

5. **No drop preview.** Nothing indicates where the card will land.

6. **Edit mode cannot scroll.** `interactive: !panel.editMode && !panel.dragging`
   (`:340`) while `maxRows` allows up to 8 rows (`:32`), and there is no
   autoscroll during a drag. Widgets below the fold are unreachable while
   editing.

7. **Dead config.** `panelShowGrips` exists in `main.xml:306` and
   `configPanel.qml:16`, labelled "Always show drag handle grips on widgets
   (otherwise visible on hover)" (`configPanel.qml:122`), and is never read by
   the panel.

## Decisions

- **Free grid placement.** Each widget stores an explicit `col`/`row`. A drop
  lands where the card is pointed and stays there. Holes are allowed.
- **Swap if same span, otherwise refuse.** Two widgets of identical span trade
  places. Any other collision does not commit.
- **No gravity.** Widgets never slide to fill vertical gaps. Deleting leaves a
  hole.
- **Drag from anywhere on the card, in edit mode only.** The existing edit
  overlay is the drag surface. The grip is a visual hint, not a target.
- **`DragHandler` with `target: null`.** The handler writes an offset, never
  `x`/`y`, so the binding to the layout engine survives.
- **Placement and collision logic lives in `IslandUtils.js`** as pure functions,
  covered by node tests.

## Data model and config format

`gridModel` gains `col` and `row`, the widget's top-left cell. `-1` means "not
placed yet". `layoutX`, `layoutY`, `layoutW`, `layoutH` remain the pixel values
the delegate binds to; they are derived from `col`/`row`/`spanW`/`spanH`, never
authored.

The `panelWidgets` config string grows from three fields to five:

```
legacy:  media:3:2          id:spanW:spanH
new:     media:0:4:3:2      id:col:row:spanW:spanH
```

Parsing discriminates on field count. Five fields means explicit placement;
anything fewer is legacy and yields `col = row = -1`. Unplaced widgets are
auto-placed first-fit in reading order, which reproduces exactly what the current
packer produces, so an existing config loads pixel-identical to today. The first
save writes the five-field form. No migration script, no version key, and no
change in behaviour for a user who never opens edit mode.

Field count is a safe discriminator because the serializer only ever emits five
fields, so `media:3:2` can only be legacy.

`maxRows` (`:32`) stops being a placement limit. Free placement with holes
requires rows to grow on demand, or a drop into row 4 on the `small` preset would
silently fail. It survives as a viewport cap only: `maxGridHeight` still clamps
visible height and the Flickable scrolls past it. Grid content height becomes
`(lowestOccupiedRow + 1)` rows worth of pixels. Rows are unbounded in the sense
that no preset caps them; the only ceiling is the safety cap of 64 that guards
against a corrupted config string.

## Placement engine

Six pure functions in `IslandUtils.js`, free of QML types so
`tests/islandutils.test.mjs` can exercise them under node:

```
buildOccupancy(items, cols, skipIndex)        → sparse 2D map, cell → item index
fits(occ, col, row, spanW, spanH, cols)       → bool; false when col+spanW > cols or row < 0
findFreeSlot(occ, spanW, spanH, cols)         → {col, row}, first-fit reading order
resolvePlacements(items, cols)                → {items, rows}; assigns col/row
dropResult(items, dragIndex, col, row, cols)  → the drop decision
cellFromPixel(x, y, colW, rowH, gap)          → {col, row}
```

`resolvePlacements` is pure: it returns new objects rather than mutating its
input, and the caller writes results back with `gridModel.setProperty`.

`dropResult` returns exactly one of three outcomes:

- `{action: "move"}` — the target footprint is free.
- `{action: "swap", withIndex}` — the footprint is covered by **exactly one**
  widget whose `spanW` and `spanH` match the dragged widget. Identical spans mean
  the exchange cannot fail, so no further check is needed.
- `{action: "reject"}` — everything else: differing span, more than one widget
  overlapped, or partial overlap such as a 1x1 dropped inside a 3x2.

The snap anchor is the card's **top-left**, not the pointer:
`col = round(x / (colWidth + gap))`, `row = round(y / (rowHeight + gap))`. Round
rather than floor gives nearest-slot snapping, so the card need not be aligned
precisely. Anchoring to the pointer would make a 4x3 widget lurch away from the
cursor.

**Clamping comes before the decision, not after.** `cellFromPixel` returns a raw
cell, which can be out of bounds — dragging a 3-wide card to the far right, or
above the first row. `dropResult` clamps `col` into `[0, cols - spanW]` and `row`
to `>= 0` before evaluating collisions. Out-of-bounds therefore pins to the
nearest valid column instead of flashing red, and `reject` is reserved for genuine
collisions. Without this, dragging a wide widget rightwards would look broken.

`resolvePlacements` runs two passes. The first keeps every widget whose
`col`/`row` are `>= 0` and still fit, clamping `col` leftward when `col + spanW`
overflows. The second first-fits whatever remains. This single function covers
three cases that are currently three separate problems: loading a legacy config,
changing the column preset, and adding a widget.

Two existing operations gain placement rules:

- **Resize** (`cycleWidgetSpan`, `:191`): if the new span does not fit in place,
  clamp `col` leftward; if it still collides, `findFreeSlot`. A resize is never
  refused — rows are unbounded, so a destination always exists.
- **Column preset change**: re-run `resolvePlacements`. Going 2 → 4 columns
  preserves every position. Going 4 → 2 re-places widgets wider than 2 columns,
  which is unavoidable and preferable to dropping them.

Delete stays trivial: remove the entry, leave the hole. That is the no-gravity
decision holding.

## Drag mechanic

The card follows the cursor without losing its binding. The delegate gains two
properties and `x`/`y` stay declarative:

```qml
property real dragDX: 0
property real dragDY: 0
x: (model.layoutX || 0) + dragDX
y: (model.layoutY || 0) + dragDY
```

`DragHandler { target: null }` writes only `dragDX`/`dragDY`, taken from
`activeTranslation`. Nothing ever assigns `x`, so the binding to the layout
engine survives every drag. On release, set `dragging = false` first — which
re-enables `Behavior on x` — and only then zero `dragDX`. Both terms change in a
single frame, the Behavior sees one `x` transition, and the card glides into its
new slot. The settle animation costs nothing extra.

`grabPermissions` must exclude `ApprovesTakeOverByItems`. It is present by
default, and it lets the parent Flickable snatch the grab mid-drag: the card
starts moving and then the grid scrolls instead. That one flag accounts for a
large share of the current jank.

`dragThreshold` is 6. Below that the gesture is a click, and a click that never
became a drag must not persist anything.

On release the three outcomes share one code path. `move` and `swap` write
`col`/`row` via `setProperty` and persist; `reject` writes nothing. In all three
cases `dragDX`/`dragDY` return to zero and `Behavior on x`/`y` carries the card to
its resting position, so a rejected drop animates back to where it started rather
than snapping.

**Content height must grow during a drag**, otherwise the bottom row of the grid
is the lowest a widget can ever reach and no new row can be created. While
dragging, grid content height is the larger of the resolved layout height and the
candidate cell's bottom edge. This is also what gives bottom-edge autoscroll
somewhere to scroll to.

## Feedback

The drop placeholder is a single `Item` inside `gridLayout`, not one per
delegate: an outline at the snapped candidate cell, sized to the dragged widget's
span, with `Behavior` on `x`, `y`, `width` and `height` so it glides between
cells instead of teleporting. Accent-coloured for `move` and `swap`, red for
`reject`. On `swap` the occupant also takes a subtle highlight, so the exchange
is visible before it is committed.

Autoscroll becomes necessary because edit mode can now scroll — `interactive`
becomes `!panel.dragging`, replacing `!panel.editMode && !panel.dragging` at
`:340`. A ~16ms `Timer` runs while dragging: within 40px of a viewport edge it
moves `contentY`, with the step scaled by depth into the zone. The detail that
makes it feel correct is the compensation — when autoscroll shifts `contentY` by
`dy`, add `dy` to `dragDY`. The card stays pinned under the cursor while the grid
slides beneath it; without this it drifts away from the pointer.

The grip glyph sits at the card's top-left, with `panelShowGrips` switching
between always-visible and visible-on-hover, finally matching the label at
`configPanel.qml:122`. It is a hint only — the whole overlay remains grabbable.
The cursor is `OpenHandCursor` in edit mode and `ClosedHandCursor` while
dragging.

Existing edit chrome is unchanged: span pill and delete button stay at the card's
top-right.

## Removed

The hit-test loop and the `gridModel.move()` call at `:521-543` are deleted.
Positions are explicit, so model order no longer affects layout at all;
reordering the model is never required, only `setProperty` on `col`/`row`.

## Edge cases

**Malformed config.** Field-level fallback already exists in
`parseWidgetSpecs`; `col` and `row` join it, and a non-numeric or negative value
becomes `-1`, meaning auto-place. `row` is capped at 64 so a corrupted string
cannot produce a Flickable with a `contentHeight` of hundreds of thousands of
pixels. An empty list still falls back to the default string at `:136`.

**Preset change mid-drag.** A change to `columns` during a drag would leave the
drop target computed against a grid that no longer exists. `onColumnsChanged`
aborts the drag — `dragging = false`, `dragDX = dragDY = 0` — then runs
`resolvePlacements`.

**Persist only on real change.** Compare the serialized spec before and after and
skip the write when they are equal. Today `onReleased` writes unconditionally
(`:548`), so a stray click dirties the config and can round-trip back through
`onRawWidgetConfigChanged`.

Unchanged on purpose: the `if (dragging) return` guard at `:206`, deduplication of
repeated ids in `parseWidgetSpecs`, and hiding the delete button when
`gridModel.count <= 1`.

## Out of scope

- **Escape-to-cancel-drag.** Requires reliable keyboard focus inside a Plasma
  popup, which is its own investigation. Worth adding later if a mis-drag proves
  annoying in practice.
- **Widgets from disabled modules.** `rebuild()` never consults
  `Catalog.isAvailable`, so a widget whose module is switched off still renders if
  it is present in the config; only the Add drawer filters (`:654`). Pre-existing
  and unrelated to moving widgets.
- **Touch-specific tuning.** `DragHandler` handles touch for free, but no
  touch-specific thresholds or long-press affordances are designed here.

## Testing

Placement and collision logic is pure JS precisely so that it is testable. New
cases in `tests/islandutils.test.mjs`:

- same-span swap
- different-span reject
- multi-overlap reject
- drop-on-self is a no-op
- out-of-bounds target clamps rather than rejecting (right edge, above row 0)
- a legacy three-field config auto-places to byte-identical old order
- 4 → 2 column shrink
- resize clamped at the right edge
- five-field serialize/parse round-trip

There is no headless QML test for `IslandPanel.qml`. The blocker is the one
`configpages.check.qml:19` already documents for `configPanel.qml`: it reads
`Plasmoid.configuration` at property-init time (`IslandPanel.qml:21-23`, `:121`),
so it cannot load outside a real plasmoid context. The QML side is covered by
`tests/qmlcheck.sh` for syntax, plus a manual checklist:

1. Swap two 1x1 toggles.
2. Drag a toggle onto the media widget and confirm the placeholder turns red and
   nothing commits.
3. Drop a widget into empty space.
4. Drag toward the bottom edge and confirm autoscroll keeps the card under the
   cursor.
5. Click a card without moving it and confirm the config is not written.
6. Flip the size preset 4 → 2 and back.
7. Resize a widget sitting at the right edge.
8. Restart plasmashell and confirm the layout reloads identically.

## Files touched

- `package/contents/ui/IslandUtils.js` — six new pure functions; `parseWidgetSpecs`
  and `serializeWidgetSpecs` extended to five fields.
- `package/contents/ui/IslandPanel.qml` — packer replaced by the placement engine;
  drag rewritten onto `DragHandler`; placeholder and autoscroll added; hit-test
  loop removed.
- `tests/islandutils.test.mjs` — new cases listed above.

