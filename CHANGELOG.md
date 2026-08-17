# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/).

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
