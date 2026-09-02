# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/).

## [1.5.0] — 2026-09-02
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
- The grid scrollbar no longer covers the right-hand column. It floats over the
  content instead of reserving width, so an always-visible bar clipped those cards
  and swallowed clicks and wheel events aimed at them. It now fades in only while
  the grid is scrolling.

## [1.4.0] — 2026-08-31
### Added
- **Notifications widget** for the Quick Control Panel — scrollable list with
  per-item dismiss, *Clear all*, and an unread count badge. A `3x1` card shows a
  header plus one preview line; resize to `3x2` or taller for the full list.
- **Panel layout presets** — *Small* (2-column), *Medium* (3-column) and *Large*
  (4-column, new default) grids for the expanded widget panel.
- **4-column widget spans.** Widgets can now be sized `4x1`, `4x2` and `4x3` on the
  Large preset; the resize cycle adapts to the active preset's column count.
- **System monitor display styles** — horizontal progress bars (default), circular
  donut charts, compact glass value pills, or mini stat grid cards.
- **Clock & date layout options** — place the date *below*, *above*, or beside the
  time (left/right), pick from preset date formats, or supply a custom format string.
- **Timer rework** — dedicated tall-card layout, quick-preset pills, a custom-timer
  popup with minute/second adjusters, scroll-wheel adjustment while idle, and a
  completion pulse animation.
- Panel clock font size, auto-close-on-hover-exit, and a reorder-handles toggle.

### Changed
- **Settings consolidated from ten pages into three** — *Appearance & Behavior*,
  *Modules & Features* and *Quick Control Panel*. Every old option is still there,
  grouped into labelled sections.
- Config pages are now `KCM.SimpleKCM` instead of bare `Kirigami.FormLayout`, so long
  pages scroll instead of clipping their lower controls.
- **System stats no longer appear in the capsule by default.** The old "Rotate with
  clock" switch is now a **Stats location** choice — *Widget panel only* (new default)
  or *Also rotate through the capsule clock*. Enabling the System Monitor module keeps
  the capsule on time and event modules (media, notifications, downloads, sharing,
  builds); stats live in the widget panel until you opt in.
- **Modules & Features** category icon fixed — `applications-interactivity` does not
  exist in Breeze, so the entry rendered with no icon. Now `plugins`.
- Night Light and Brightness toggles use existing Breeze icons
  (`weather-clear-night`, `display-brightness`) instead of missing ones.
- Project maintainership transferred to **DeadIndian**.

### Removed
- **About & Info** settings page. Plasma builds an About page from `metadata.json`
  automatically, so the custom one was a duplicate.
- `configAnimation`, `configClock`, `configFeatures`, `configLayout`, `configMedia`,
  `configMonitor`, `configNotifications`, `configSize` and `configTimer.qml` — merged
  into the three consolidated pages.

### ⚠️ Breaking
- **Plugin ID renamed** `com.ifny75.dynamicisland` → `com.deadindian.dynamicisland`.
  Plasma treats this as a different widget, so the old capsule shows up as an unknown
  widget and its settings are not carried over. Remove the old install, then re-add
  the widget to your panel:
  ```bash
  kpackagetool6 -t Plasma/Applet -r com.ifny75.dynamicisland
  ```

## [1.3.0] — 2026-08-17
### Added
- **Timer widget** — countdown / stopwatch panel with configurable presets.
- **Volume widget** — live volume slider with mute toggle in the expanded panel.
- **Brightness widget** — display brightness slider directly in the island.
- **Quick Toggle widget** — configurable toggle buttons (Night Color, Do Not Disturb, etc.).
- **Media widget** — dedicated expanded media panel with richer album art and controls.
- **Clock widget** — standalone clock panel component for layout flexibility.
- **System widget** — CPU / RAM monitor panel with sparkline history.
- `ExecSource.qml` — generic command-output data source for custom modules.
- `configPanel.qml` — per-panel settings tab for the expanded island panels.
- `configTimer.qml` / `configMedia.qml` — dedicated settings tabs for new widgets.

### Changed
- `IslandPanel.qml` extracted as a reusable expanded-panel host (was inlined in `main.qml`).
- `VolumeSource.qml` and `BrightnessSource.qml` refactored to clean data-source pattern.
- `WidgetCatalog.js` introduced to register and order all island panels centrally.
- `IslandUtils.js` extended with shared geometry and color helpers.

## [1.2.0] — 2026-08-16
### Added
- **"Layout" settings tab.**
- Optional **"/" separators** between compact modules.
- Reorderable compact blocks (Content · Time · FPS) with 6 presets.
- **FPS counter** with two styles (accent badge / plain clock font).
- **Distance from panel** setting (0–120 px) to prevent the expanded panel from overlapping the capsule.

### Changed
- Plain FPS style now renders `N fps` in the clock font.
- Reorderable compact segments via config.

## [1.1.0] — 2026-08-15
### Added
- Split settings into multiple tabbed categories.
- Permanent FPS counter next to the clock.

### Fixed
- CPU/RAM monitor moved to the isolated sensors API (`SystemMonitor.qml`) so an unavailable module cannot break the widget.
- Orange sharing dot now reliably appears for "screen sharing + music".

## [1.0.0] — 2026-08-14
### Added
- System monitor mode: CPU & RAM usage alternating with the clock.
- Per-module enable/disable switches.
- Separate widths for music / notification / status panels.
- Clock seconds and date options; configurable idle & sharing dot colors.
- Orange sharing indicator left of the music.
- Notifications redesigned (wider, cleaner, multi-line body).
- Configurable background, opacity, corner radius, border and accent color.
- Compact capsule transparent by default; filled background on the big panel.
- Settings UI and configuration keys.
- IntelliJ IDEA build-result capsule.

### Fixed
- Popup no longer lingers on another monitor when closing.

## [0.1.0] — 2026-08-13
### Added
- Initial dynamic-island capsule: clock, MPRIS media, notifications, keyboard
  layout, downloads and screen-sharing states with an expandable popup.
