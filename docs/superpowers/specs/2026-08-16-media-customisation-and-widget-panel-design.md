# Media Customisation & Widget Panel — Design

Date: 2026-08-16
Status: approved for planning
Target: `com.ifny75.dynamicisland` (Plasma 6 applet, pure QML)

## Problem

Two gaps in the current applet:

1. Media rendering is hardcoded. `main.qml` fixes title at `pointSize: 14`, artist at `10`, album art at 52px, and offers no way to hide a line, change a font, or restyle the seek bar. Users cannot make the capsule match their panel.
2. Clicking the capsule while nothing is happening opens `statusExpanded` in `activeMode === 3`, which shows only the keyboard layout. That click should open something useful — a small floating panel holding whatever the user wants, dock-style.

Additionally the applet has no extension story: every feature is welded into `main.qml` (1384 lines). New features should drop in as modules that users toggle, where turning a module on reveals its settings and turning it off hides them.

## Goals

- Full control over media appearance: per-line visibility, font family, size, weight, colour, overflow behaviour; album art size/radius; seek bar; text templates; independent scale for capsule vs expanded.
- Clicking an idle capsule opens a floating widget panel that stays open and can be interacted with.
- Widgets in that panel are reordered by dragging them, in the panel itself.
- A module system: one toggle per module, settings visible only when the module is on, and adding a module later costs one widget file + one catalog line + one config page + one config entry.
- Ship six widgets: Media controls, System resources, Timer, Volume, Brightness, Clock.
- The result still packages as a single `.plasmoid` archive installable from the KDE Store.

## Non-goals

- Translating new strings. `Tr.t()` falls back to its English source, so the seven existing languages show English labels for new settings. Adding roughly sixty keys across seven languages is separate work.
- Real Plasma widgets in the panel. "Widget" here means an item rendered inside our own panel, not a `Plasmoid` instance.
- Multiple instances of the same widget in one panel. The order list holds unique ids.
- Per-instance widget settings. A widget's settings are global and live on its module's config page.
- Drag-and-drop between the panel and anywhere else.

## Verified environment facts

Probed on the target machine (Plasma 6.7.3, Qt 6, Fedora 44) before designing, because three of these are private Plasma APIs:

- `ConfigCategory` exposes a bindable `visible` property (`plasmaconfigplugin.qmltypes`, with `visibleChanged`). Two installed third-party plasmoids already bind it to `Plasmoid.configuration`, so hiding a module's settings page is a supported pattern rather than a guess.
- `org.kde.plasma.private.volume` provides `SinkModel`. It has **no** `preferredSink` or `defaultSink` property — both probe as falsy even after the event loop settles. Sinks are reachable through model roles: `model.PulseObject` (with writable `.volume`, writable `.muted`, and `.volumeWritable`), `model.Default`, `model.Description`. `PulseAudio.NormalVolume` is the divisor for percentages. This matches the `Repeater`-over-model idiom `main.qml` already uses for MPRIS.
- `org.kde.plasma.private.brightnesscontrolplugin` provides `ScreenBrightnessControl` with `isBrightnessAvailable`, a `displays` model, and `setBrightness(displayName, value)`.
- `node`, `zip` and `kpackagetool6` are available, so pure JS gets a real test and packaging can be verified end to end.

The two `private` imports and the existing `org.kde.ksysguard.sensors` import are all version-fragile. Each is isolated behind a `Loader`, following the precedent already set at `main.qml:258`.

## Architecture

### Module system

A **module** is a feature provider with a master toggle. A **widget** is a panel item. Some widgets belong to a module and are unavailable when it is off; others are general and always available.

```
package/contents/ui/
  WidgetCatalog.js        registry: { id, label, icon, file, requiresModule }
  widgets/                one file per widget
  IslandPanel.qml         the floating panel
  IslandUtils.js          pure helpers (tested by node)
```

`WidgetCatalog.js` is the single registry. `requiresModule` names a config key (`"enableMedia"`) or is empty for general widgets. Adding a module later means:

1. one file in `ui/widgets/`
2. one entry in `WidgetCatalog.js`
3. one `ConfigCategory` in `config/config.qml` with `visible: Plasmoid.configuration.enableX`
4. config entries in `config/main.xml`

Module settings live in their own config page, one file each. This is deliberate: KConfigXT only binds `cfg_*` properties declared on a config page's **root** item, so settings loaded into a shared page through a `Loader` would not save. One page per module keeps each file small and each module's `cfg_*` properties at a root where they work.

Known limitation: `ConfigCategory.visible` reads committed configuration, not the unsaved switch state, so toggling a module reveals its page after **Apply**. The Modules page states this.

### Media styling

`MediaStyle.qml` is an `Item` that resolves configuration into ready-to-bind values, parameterised by `scalePercent`. All sizes are `base × scalePercent / 100`. Two instances exist in `main.qml`:

- `scalePercent: mediaCapsuleScale` (default 85) for the capsule
- `scalePercent: mediaExpandedScale` (default 100) for the expanded panel

Three surfaces bind to it: the capsule content block, the expanded media panel, and the panel's media widget. One knob set, three surfaces, no duplicated configuration UI.

Empty string means inherit: an empty font family uses the default font, an empty colour uses `root.textPrimary` / `root.textSecondary`. With the shipped defaults the rendering is byte-for-byte what it is today, so no existing user sees a visual change on upgrade.

### Files

Extracted from `main.qml`:

| File | Why |
|---|---|
| `MediaStyle.qml` | resolves media config; instantiated per surface |
| `ScrollingLabel.qml` | elides, or marquees when `contentWidth > width` |
| `SoundBars.qml` | currently an inline `component`, which other files cannot reach |
| `MediaExpanded.qml` | today's `musicExpanded`, rebuilt on `MediaStyle` |

New:

| File | Purpose |
|---|---|
| `IslandPanel.qml` | floating panel, drag-to-reorder, order persistence |
| `WidgetCatalog.js` | widget registry |
| `IslandUtils.js` | `formatTemplate`, `parseWidgetList`, `serializeWidgetList`, `mmss`, `moveItem` |
| `VolumeSource.qml` | `Loader`-isolated PulseAudio access |
| `BrightnessSource.qml` | `Loader`-isolated brightness access |
| `widgets/MediaWidget.qml` | |
| `widgets/SystemWidget.qml` | |
| `widgets/TimerWidget.qml` | |
| `widgets/VolumeWidget.qml` | |
| `widgets/BrightnessWidget.qml` | |
| `widgets/ClockWidget.qml` | |
| `configMedia.qml` | media appearance page |
| `configPanel.qml` | panel geometry + widget add/remove + general widget settings |
| `configTimer.qml` | timer module settings |

Modified: `main.qml`, `config/main.xml`, `config/config.qml`, `configFeatures.qml`, `configMonitor.qml`, `metadata.json`. New at repo root (not shipped): `package.sh`, `tests/`.

## Phase 1 — media appearance

Independently shippable. Phase 2 reuses `MediaStyle.qml`, `ScrollingLabel.qml` and `SoundBars.qml`, so this lands first.

### Config entries

Under `<group name="General">` in `main.xml`, all read through `MediaStyle`:

| Key | Type | Default | Range |
|---|---|---|---|
| `mediaTitleVisible` | Bool | true | |
| `mediaTitleFont` | String | `""` | `""` = inherit |
| `mediaTitleSize` | Int | 14 | 6–40 |
| `mediaTitleWeight` | Int | 500 | 100–900 |
| `mediaTitleColor` | String | `""` | `""` = `textPrimary` |
| `mediaTitleScroll` | Bool | false | false = elide |
| `mediaArtistVisible` | Bool | true | |
| `mediaArtistFont` | String | `""` | |
| `mediaArtistSize` | Int | 10 | 6–40 |
| `mediaArtistWeight` | Int | 400 | 100–900 |
| `mediaArtistColor` | String | `""` | `""` = `textSecondary` |
| `mediaArtistScroll` | Bool | false | |
| `mediaArtistHideIfSame` | Bool | true | hide artist when equal to title |
| `mediaShowArt` | Bool | true | |
| `mediaArtSize` | Int | 52 | 24–96 (expanded) |
| `mediaArtRadius` | Int | 8 | 0–48 |
| `mediaCapsuleArtSize` | Int | 22 | 0–28 (0 hides) |
| `mediaShowSeekBar` | Bool | true | |
| `mediaSeekBarHeight` | Int | 5 | 1–12 |
| `mediaShowTimes` | Bool | false | elapsed / total, flanking the seek bar |
| `mediaShowSoundBars` | Bool | true | both surfaces |
| `mediaShowControls` | Bool | true | prev / play / next |
| `mediaTitleFormat` | String | `{title}` | |
| `mediaArtistFormat` | String | `{artist}` | |
| `mediaCapsuleScale` | Int | 85 | 50–150 |
| `mediaExpandedScale` | Int | 100 | 50–200 |

Weight is stored as a numeric 100–900 because Qt accepts numeric font weights directly; the config page presents a named combo (Light / Normal / Medium / DemiBold / Bold) mapping to 300 / 400 / 500 / 600 / 700.

`mediaCapsuleScale` defaults to 85 so `mediaTitleSize` 14 renders as 12 in the capsule, matching today's hardcoded pair (14 expanded / 12 capsule).

### Text templates

`formatTemplate(tpl, vals)` in `IslandUtils.js` substitutes `{title}`, `{artist}`, `{album}`, `{player}`. Unknown tokens are left as literal text rather than blanked, so a typo is visible instead of silently eating the line. Values come from the existing `mediaTitle` / `mediaArtist` / `mediaIdentity` root properties plus `album` read from the MPRIS model with a `|| ""` guard.

### Overflow

`ScrollingLabel.qml` wraps a `Text` in a clipped `Item`. When `contentWidth <= width` it renders plainly. When it overflows and `scroll` is true it animates `x` from 0 to `-(contentWidth - width)` and back, pausing at each end; when `scroll` is false it sets `elide: Text.ElideRight`, preserving today's behaviour.

### Capsule width

`compactTitleMetrics` currently hardcodes `pointSize: 12` / `weight: Font.Medium`. It must bind to the capsule `MediaStyle` instead, or the capsule will size itself wrongly for any non-default font. This is the one place where getting media styling wrong breaks layout rather than just looks.

## Phase 2 — widget panel and modules

### Capsule click routing

`panelEnabled` (Bool, default true) gates the whole feature. With it off the applet behaves exactly as it does today: an idle click opens `statusExpanded` and its keyboard-layout view. This is the escape hatch for anyone who preferred the old popup.

New `panelShowMode` (String, default `idle`), effective only when `panelEnabled`:

- `idle` — the panel opens when nothing is active. Active media or a notification keeps today's expanded view.
- `always` — the panel always opens. Active content renders as a fixed, non-draggable header row above the widget list, **unless a widget already in the list covers it** — an active track with the `media` widget present shows only the widget, never both. Concretely: the header is skipped for media when `panelWidgets` contains `media`. Notifications have no widget, so their header always renders.

### Panel persistence

Today `popupMouseArea.onExited: root.closePopup()` closes the popup as soon as the pointer leaves. That makes sliders and buttons unusable, so it is removed and gated behind a new `popupCloseOnHoverExit` (Bool, default `false`) — it is a behaviour change for existing users, so the old behaviour stays reachable.

The panel then closes on:

- click outside — `hideOnWindowDeactivate` is already `true`
- click on the capsule — existing `togglePopup()`
- `Esc` — `Shortcut { sequences: [StandardKey.Cancel]; onActivated: root.closePopup() }` in the dialog's `mainItem`

### Panel rendering

`IslandPanel.qml` holds a `ListView` over a `ListModel` built from `panelWidgets`. Each delegate contains:

```qml
Loader {
    property var island: root        // in the loaded item's scope chain
    source: WidgetCatalog.fileFor(widgetId)
}
```

Widgets read `island.mediaTitle`, `island.cpuUsage` and so on. Properties declared on a `Loader` are in the loaded item's scope, so widgets receive an explicit handle rather than reaching for an outer `id` by luck.

`source` must be a **relative** path (`"widgets/MediaWidget.qml"`, resolved against `ui/`). Absolute or `file://` paths work from a hand-installed copy and break from a store-installed package — the one packaging trap in this design.

Panel `implicitHeight` is `panelPadding × 2 + Σ delegate heights + panelSpacing × (n − 1)`, clamped to `panelMaxHeight`; past that the `ListView` flicks. Width is `panelWidth`. Background, corner radius and border reuse the existing Appearance settings.

Empty state: a "No widgets yet" label and a gear that triggers `Plasmoid.internalAction("configure")`.

### Drag-to-reorder

Dragging starts **only** from a 16px grip column on the left of each row (a `⋮⋮` glyph). Making the whole row draggable would swallow drags meant for the volume slider and the media seek bar.

`panelShowGrips` controls the glyph's visibility, not whether dragging works: true (default) keeps grips always visible, false fades them in on row hover. Dragging is available either way, so a user cannot accidentally lock themselves out of reordering.

Mechanics:

- the grip's `MouseArea` sets `drag.target` to the row's inner content item and raises its `z`
- the target index comes from `list.indexAt(x, centerY)`, **not** from `y / rowHeight`, because widget heights differ
- crossing a neighbour calls `model.move()`; `ListView.moveDisplaced` animates the shift
- on release the inner item's `y` resets to 0 and the new order is written to `Plasmoid.configuration.panelWidgets`

Two writers touch `panelWidgets`: the config page (add/remove) and the panel (reorder). The panel suppresses config-driven model rebuilds while a drag is live, and otherwise rebuilds only when the incoming string differs from the serialised current model. Without that guard a config write mid-drag would rebuild the model under the pointer.

### Widget catalogue

| id | Label | Gate | Data source |
|---|---|---|---|
| `media` | Media controls | `enableMedia` | existing `mediaContainer` |
| `system` | System resources | `enableSysMonitor` | existing `SystemMonitor.qml` |
| `timer` | Timer | `enableTimer` | new root state |
| `volume` | Volume | — | new `VolumeSource.qml` |
| `brightness` | Brightness | — | new `BrightnessSource.qml` |
| `clock` | Clock | — | existing `timeText` |

A widget whose `requiresModule` key is false is filtered out of the panel and greyed out in the config page's add list; its id stays in `panelWidgets` so re-enabling the module restores it in place.

Widget behaviour:

- **Media** — art, title, artist, seek bar, prev / play / next, all styled by `MediaStyle` at `mediaExpandedScale`. Seeking is offered only when `mediaLength > 0`.
- **System** — CPU / RAM / temperature bars. Reads the existing `showCpuStat` / `showRamStat` / `showTempStat` settings rather than adding three duplicates; temperature hides itself when `cpuTemp === 0`, as the capsule already does.
- **Timer** — minutes field plus start / pause / reset.
- **Volume** — slider and mute button for the sink whose `model.Default` role is true, falling back to index 0. Percentage is `PulseObject.volume / PulseAudio.NormalVolume × 100`. The slider is disabled when `volumeWritable` is false.
- **Brightness** — slider over the first entry of `displays`, written with `setBrightness(displayName, value)`. The widget hides itself when `isBrightnessAvailable` is false or the `Loader` failed, which is the desktop-without-backlight case.
- **Clock** — large time, optional date, reusing `use24HourClock` / `showSeconds` / `showDate`. New `widgetClockSize` (Int, default 28).

### Timer module

Root state in `main.qml`: `timerTotal`, `timerRemaining`, `timerRunning`, plus a repeating 1s `Timer` gated on `timerRunning`.

When the timer runs and `timerTakeOverClock` is true, `clockDisplay` returns `mmss(timerRemaining)` — the ordinary clock disappears and the countdown ticks in its place, which is the requested behaviour. Precedence becomes:

```
clockDisplay = timer > system stats > time
```

`activeMode` is untouched while the timer runs, because a timer is a persistent state rather than a transient event. On completion it sets `modeIndex = 4` and restarts `eventTimer`, so the capsule announces it through the existing mode-4 path (`Translator.js` already carries a Pomodoro string for that mode). `timerNotifyOnFinish` (default true) additionally posts a desktop notification.

`mmss` lives in `IslandUtils.js` and is tested. Durations of an hour or more render as `h:mm:ss`.

Note that a longer `mm:ss` string is wider than `HH:mm`, but `compactTimeMetrics` already measures `clockDisplay`, so the capsule resizes without further work.

### Existing-config fix

`enableSysMonitor` currently means two things: load the sensors, and rotate the idle clock through system stats. The panel's system widget needs the first without the second. Split:

- `enableSysMonitor` — module master, gates the `Loader` and the widget
- `sysMonitorRotateClock` (Bool, default `true`) — the capsule rotation

Defaulting the new key to `true` preserves behaviour for anyone who had `enableSysMonitor` on, since `enableSysMonitor` itself defaults to `false`.

This is a root-cause fix rather than a workaround: `enableSysMonitor` is read in three places (`sysLoader.active`, `sysRotateTimer.running`, `showSysStats`) and only the latter two are about rotation.

### Config entries

| Key | Type | Default | Range |
|---|---|---|---|
| `panelEnabled` | Bool | true | |
| `panelShowMode` | String | `idle` | `idle` / `always` |
| `panelWidgets` | String | `media,system` | ordered, comma-separated ids |
| `panelWidth` | Int | 320 | 240–560 |
| `panelMaxHeight` | Int | 420 | 120–900 |
| `panelSpacing` | Int | 8 | 0–24 |
| `panelPadding` | Int | 12 | 0–32 |
| `panelShowGrips` | Bool | true | |
| `popupCloseOnHoverExit` | Bool | false | |
| `enableTimer` | Bool | true | |
| `timerDefaultMinutes` | Int | 25 | 1–600 |
| `timerTakeOverClock` | Bool | true | |
| `timerNotifyOnFinish` | Bool | true | |
| `sysMonitorRotateClock` | Bool | true | |
| `widgetClockSize` | Int | 28 | 10–64 |

`panelWidgets` is a comma-separated ordered id list, matching the existing dash-separated `compactOrder` idiom rather than introducing JSON for a list of short strings. `parseWidgetList` drops ids absent from the catalogue and de-duplicates, so a hand-edited or downgraded config cannot produce a broken panel.

### Config pages

`config/config.qml` gains three categories:

| Category | Icon | Source | Visible when |
|---|---|---|---|
| Media | `applications-multimedia` | `configMedia.qml` | `enableMedia` |
| Panel | `dashboard-show` | `configPanel.qml` | always |
| Timer | `chronometer` | `configTimer.qml` | `enableTimer` |

`configFeatures.qml` gains the timer switch and a note that module pages appear after Apply. `configMonitor.qml` gains the `sysMonitorRotateClock` switch.

`configPanel.qml` holds panel geometry, `panelEnabled`, `panelShowMode`, `popupCloseOnHoverExit`, the widget add/remove list (checkboxes over the catalogue, module-gated entries greyed out with their requirement named), and the settings for general widgets that have any — currently just `widgetClockSize`. Volume and brightness need none. Reordering is not offered here; it happens by dragging in the panel.

## Packaging

The applet must stay installable as a single `.plasmoid` from the KDE Store. `.plasmoid` is a zip with `metadata.json` at the **archive root**, so:

- every runtime file lives under `package/contents/`; nothing outside `package/` is referenced at runtime
- `tests/`, `package.sh` and `docs/` sit at the repo root and are not shipped
- all `Loader.source` and import paths stay relative
- the package remains pure QML with no compiled plugin, which is what the store requires
- `X-Plasma-API-Minimum-Version` stays `6.0`. The two private imports are newer than that, but each is `Loader`-isolated, so on an older Plasma the corresponding widget hides instead of the applet failing to load.
- `metadata.json` `Version` goes to `1.2.0`

New `package.sh` at the repo root:

```sh
cd package && zip -r -q "../dynamicisland-$VERSION.plasmoid" . -x '.*' -x '*/.*'
```

`VERSION` is read from `metadata.json` so the archive name cannot drift from the declared version.

## Error handling

- **Missing QML module** — `org.kde.ksysguard.sensors`, `org.kde.plasma.private.volume` and `org.kde.plasma.private.brightnesscontrolplugin` each load through a `Loader`. A failed `Loader` leaves `item === null`; every consumer already guards on that (`sysLoader.item ? … : 0`) and the affected widget hides. The applet never fails to load because one optional import is absent.
- **Hardware absent** — no CPU temperature sensor yields `cpuTemp === 0` and the stat is omitted, as today. No backlight yields `isBrightnessAvailable === false` and the brightness widget hides. A sink with `volumeWritable === false` disables the slider rather than writing into the void.
- **Bad config** — `parseWidgetList` filters unknown ids and duplicates. An out-of-catalogue id from a downgrade is dropped on read, not written back, so upgrading again restores it.
- **No media player** — `mediaContainer` is null; controls dim to 0.35 opacity, matching the existing pattern at `main.qml:996`.
- **Concurrent order writes** — the panel suppresses config-driven rebuilds during a drag, as described above.

## Testing

Pure logic lives in `IslandUtils.js` and is covered by `tests/islandutils.test.mjs`, run with plain `node` — no framework, no fixtures. The file strips the leading `.pragma library` directive (valid QML, invalid JS) before evaluating, then asserts:

- `formatTemplate` — token substitution, unknown tokens left literal, empty values
- `parseWidgetList` / `serializeWidgetList` — round trip, unknown ids dropped, duplicates collapsed, empty string
- `mmss` — zero, sub-minute, exact minute, past an hour
- `moveItem` — forward, backward, no-op, boundaries

These are the four places where a logic error produces a wrong panel or a wrong countdown rather than a visible layout glitch.

Rendering and interaction are verified by hand, since Plasma imports do not resolve outside plasmashell:

1. `./install.sh && plasmawindowed com.ifny75.dynamicisland`, watching stderr for QML errors
2. media styling: change each knob, confirm the capsule resizes correctly for a large font
3. panel: open from an idle capsule, drag a widget past a neighbour, confirm the order survives a Plasma restart
4. panel persistence: move the pointer away and confirm it stays; `Esc` and an outside click close it
5. timer: start it, confirm the capsule clock is replaced by the countdown, confirm the finish announcement
6. packaging: `./package.sh`, then `kpackagetool6 --type Plasma/Applet --install dynamicisland-1.2.0.plasmoid` into a clean location and confirm the panel and its widgets still load

Step 6 is the check that catches an absolute `Loader.source`, which works in step 1 and fails only from a packaged install.

## Implementation order

1. Extract `SoundBars.qml`, `ScrollingLabel.qml`, `MediaStyle.qml`; add `IslandUtils.js` and its test
2. Rebuild `MediaExpanded.qml` and the capsule media block on `MediaStyle`; add `configMedia.qml` and the media config entries; fix `compactTitleMetrics`
3. Verify phase 1 in `plasmawindowed`
4. Panel infrastructure: `WidgetCatalog.js`, `IslandPanel.qml`, drag-to-reorder, click routing, persistence, `configPanel.qml`
5. Widgets, cheapest first: Clock, System, Media, Timer, Volume, Brightness — with `VolumeSource.qml` and `BrightnessSource.qml`
6. Timer module: root state, clock takeover, finish announcement, `configTimer.qml`
7. Split `enableSysMonitor` / `sysMonitorRotateClock`
8. `package.sh`, version bump, packaged-install verification
