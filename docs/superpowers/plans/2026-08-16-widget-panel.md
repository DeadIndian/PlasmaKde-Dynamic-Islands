# Widget Panel & Modules Implementation Plan (Phase 2)

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clicking the idle capsule opens a floating widget panel (dock-style) whose widgets are reorderable by dragging. Six widgets ship: Media controls, System resources, Timer, Volume, Brightness, Clock — plus a timer module with countdown takeover of the capsule clock, a split of `enableSysMonitor` into module-master + clock-rotation, and a `package.sh` for single-archive store installs.

**Architecture:** A `WidgetCatalog.js` registry maps widget ids to files. `IslandPanel.qml` renders the widgets in a `ListView` over the configured order, with grip-based drag-to-reorder persisted to `panelWidgets`. Click routing in `main.qml` switches the popup between the panel and the existing expanded views. Version-fragile imports (`volume`, `brightnesscontrolplugin`) stay Loader-isolated. Reuses from phase 1: `MediaStyle.qml`, `ScrollingLabel.qml`, `SoundBars.qml`, `IslandUtils.js`, `MediaExpanded.qml`.

**Tech Stack:** QML (Qt 6), Plasma 6 applet API, KConfigXT, Kirigami, `node` for pure-JS tests, `qmllint` gate, `zip`/`kpackagetool6` for packaging.

## Global Constraints

- Pure QML only. No compiled plugin, no new runtime dependency. Single `.plasmoid` from the KDE Store.
- Every runtime file lives under `package/contents/`. All `Loader.source` and import paths stay **relative**.
- `X-Plasma-API-Minimum-Version` stays `6.0`. The `volume` and `brightnesscontrolplugin` private imports are newer; each is Loader-isolated so a missing module hides a widget instead of breaking the applet.
- Shipped defaults preserve today's behaviour. New defaults are chosen so existing users see no regression.
- New user-visible strings go through `Tr.t(...)`; no dictionary entries.
- 4-space indent, `readonly property` for derived values, comments only where intent is non-obvious.

## Environment facts (verified — do not re-probe)

- `org.kde.notification` (KNotifications) exposes `Notification` (KNotification) with `title`, `text`, `iconName`, `eventId` and methods `sendEvent()`, `close()`. This is how the timer finish notification is posted; `NotificationManager.Server` has **no** send method in this Plasma version.
- `org.kde.plasma.private.brightnesscontrolplugin` `ScreenBrightnessControl`: `displays` (model with roles `displayName`, `brightness`, `brightnessMax`; `maxBrightness` string also present as fallback), `isBrightnessAvailable`, `setBrightness(displayName: string, value: int)`.
- `org.kde.plasma.private.volume` provides `SinkModel` with roles `model.PulseObject` (writable `.volume`, `.muted`, `.volumeWritable`), `model.Default`, `model.Description`; `PulseAudio.NormalVolume` is the percentage divisor. No `preferredSink`/`defaultSink` properties.
- The existing `org.kde.ksysguard.sensors` import stays Loader-isolated (`SystemMonitor.qml`).
- `Shortcut`/`StandardKey` come from `import QtQuick` on Qt 6.5+.

---

### Task 1: Config entries

**Files:** Modify `package/contents/config/main.xml`.

Add three blocks. After the `<!-- Clock -->` group's `showDate` entry, add `widgetClockSize`. After the `<!-- System monitor -->` entries, add `sysMonitorRotateClock`. After the `<!-- Layout -->` group, add `<!-- Panel -->` and `<!-- Timer -->` blocks:

```xml
        <!-- Panel -->
        <entry name="panelEnabled" type="Bool">
            <default>true</default>
        </entry>
        <entry name="panelShowMode" type="String">
            <default>idle</default>
        </entry>
        <entry name="panelWidgets" type="String">
            <default>media,system</default>
        </entry>
        <entry name="panelWidth" type="Int">
            <default>320</default>
            <min>240</min>
            <max>560</max>
        </entry>
        <entry name="panelMaxHeight" type="Int">
            <default>420</default>
            <min>120</min>
            <max>900</max>
        </entry>
        <entry name="panelSpacing" type="Int">
            <default>8</default>
            <min>0</min>
            <max>24</max>
        </entry>
        <entry name="panelPadding" type="Int">
            <default>12</default>
            <min>0</min>
            <max>32</max>
        </entry>
        <entry name="panelShowGrips" type="Bool">
            <default>true</default>
        </entry>
        <entry name="popupCloseOnHoverExit" type="Bool">
            <default>false</default>
        </entry>

        <!-- Timer -->
        <entry name="enableTimer" type="Bool">
            <default>true</default>
        </entry>
        <entry name="timerDefaultMinutes" type="Int">
            <default>25</default>
            <min>1</min>
            <max>600</max>
        </entry>
        <entry name="timerTakeOverClock" type="Bool">
            <default>true</default>
        </entry>
        <entry name="timerNotifyOnFinish" type="Bool">
            <default>true</default>
        </entry>
```

- [ ] Add the entries, run `./tests/qmlcheck.sh`, then `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di2.log` and confirm no KConfigXT parse warnings.

### Task 2: WidgetCatalog.js

**Files:** Create `package/contents/ui/WidgetCatalog.js`.

```js
.pragma library

// Registry of panel widgets. `requiresModule` names a Plasmoid.configuration
// key (e.g. "enableMedia") that must be true for the widget to appear; an
// empty string means the widget is always available. Adding a module later
// costs one widget file, one catalog line, one config page and one config
// entry group.
var CATALOG = [
    { id: "media", label: "Media controls", icon: "media-playback-start", file: "widgets/MediaWidget.qml", requiresModule: "enableMedia" },
    { id: "system", label: "System resources", icon: "utilities-system-monitor", file: "widgets/SystemWidget.qml", requiresModule: "enableSysMonitor" },
    { id: "timer", label: "Timer", icon: "chronometer", file: "widgets/TimerWidget.qml", requiresModule: "enableTimer" },
    { id: "volume", label: "Volume", icon: "audio-volume-high", file: "widgets/VolumeWidget.qml", requiresModule: "" },
    { id: "brightness", label: "Brightness", icon: "brightness-low", file: "widgets/BrightnessWidget.qml", requiresModule: "" },
    { id: "clock", label: "Clock", icon: "preferences-system-time", file: "widgets/ClockWidget.qml", requiresModule: "" }
];

function entryFor(id) {
    for (var i = 0; i < CATALOG.length; i++) {
        if (CATALOG[i].id === id) {
            return CATALOG[i];
        }
    }
    return null;
}

function ids() {
    var out = [];
    for (var i = 0; i < CATALOG.length; i++) {
        out.push(CATALOG[i].id);
    }
    return out;
}

function fileFor(id) { var e = entryFor(id); return e ? e.file : ""; }
function labelFor(id) { var e = entryFor(id); return e ? e.label : ""; }
function iconFor(id) { var e = entryFor(id); return e ? e.icon : ""; }
function requiresModule(id) { var e = entryFor(id); return e ? e.requiresModule : ""; }

function isAvailable(id, config) {
    var req = requiresModule(id);
    return req === "" || config[req] === true;
}
```

- [ ] Run `./tests/qmlcheck.sh`.

### Task 3: VolumeSource.qml and BrightnessSource.qml

**Files:** Create `package/contents/ui/VolumeSource.qml`, `package/contents/ui/BrightnessSource.qml`.

Each is Loader-isolated: a failed `Loader` leaves `item === null`, and the widget hides. Both expose `available` and the value/write surface the widget needs.

`VolumeSource.qml`:

```qml
import QtQuick
import org.kde.plasma.private.volume as Volume

// Loader-isolated PulseAudio access. A missing module or a system without
// sinks leaves `available` false and the volume widget hides. The default
// sink is chosen by the model's Default role, falling back to the first row.
Item {
    id: src

    property var sink: null
    readonly property bool available: model.count > 0 && sink !== null
    readonly property bool muted: sink ? sink.muted : false
    readonly property bool writable: sink ? sink.volumeWritable === true : false
    readonly property int percent: sink
        ? Math.round(sink.volume / Volume.PulseAudio.NormalVolume * 100)
        : 0

    Volume.SinkModel {
        id: model
    }

    // Delegates complete in row order, so the index-0 fallback is always
    // recorded before the Default row (if any) overwrites it.
    Repeater {
        model: src.model

        delegate: Item {
            visible: false
            Component.onCompleted: {
                if (index === 0) {
                    src.fallbackSink = model.PulseObject
                }
                if (model.Default) {
                    src.sink = model.PulseObject
                }
            }
        }
    }

    property var fallbackSink: null
    onFallbackSinkChanged: if (src.sink === null) src.sink = fallbackSink

    function setVolume(pct) {
        if (sink && sink.volumeWritable) {
            sink.volume = Math.max(0, Math.min(100, pct)) / 100 * Volume.PulseAudio.NormalVolume
        }
    }

    function toggleMute() {
        if (sink) {
            sink.muted = !sink.muted
        }
    }
}
```

`BrightnessSource.qml`:

```qml
import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin as BrightnessControl

// Loader-isolated brightness access. The widget hides itself when no
// backlight is available or the module failed to load.
Item {
    id: src

    readonly property bool available: control.isBrightnessAvailable && displayName.length > 0
    property string displayName: ""
    property int brightness: 0
    property int brightnessMax: 100

    BrightnessControl.ScreenBrightnessControl {
        id: control
    }

    // Captures the first display's roles defensively: role names differ
    // slightly across Plasma versions, so both spellings are tried.
    Repeater {
        model: control.displays

        delegate: Item {
            visible: false
            Component.onCompleted: {
                if (index === 0) {
                    src.displayName = model.displayName || model.DisplayName || ""
                    src.brightness = model.brightness || model.Brightness || 0
                    src.brightnessMax = model.brightnessMax || model.maxBrightness || model.BrightnessMax || 100
                }
            }
        }
    }

    function setBrightness(value) {
        if (available) {
            control.setBrightness(displayName, Math.max(0, Math.min(brightnessMax, Math.round(value))))
        }
    }
}
```

- [ ] Run `./tests/qmlcheck.sh`.

### Task 4: IslandPanel.qml

**Files:** Create `package/contents/ui/IslandPanel.qml`.

The floating panel: a header row (only in `always` mode with active content), a `ListView` of widget delegates, grip-based drag-to-reorder, and an empty state. Height is computed from delegate heights and clamped to `panelMaxHeight`; past that the list flicks.

```qml
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "IslandUtils.js" as Utils
import "Translator.js" as Tr
import "WidgetCatalog.js" as Catalog

// The floating widget panel. Widget ids come from `island.panelVisibleWidgets`
// (already filtered by module availability); the ListView's order is the live
// order, persisted to panelWidgets after a drag. `island` is supplied by the
// Loader in main.qml so every widget receives an explicit handle.
Item {
    id: panel

    property var island: null
    property bool dragging: false

    readonly property int pad: Plasmoid.configuration.panelPadding
    readonly property int gap: Plasmoid.configuration.panelSpacing
    readonly property int maxH: Plasmoid.configuration.panelMaxHeight
    readonly property bool showGrips: Plasmoid.configuration.panelShowGrips

    // In "always" mode active media/notification content becomes a fixed
    // header, unless a widget already covers it (media widget present).
    readonly property bool headerShown: island && island.panelShowMode === "always"
        && (island.activeMode === 0 || island.activeMode === 2)
        && !(island.activeMode === 0 && island.panelWidgetIds.indexOf("media") !== -1)
    readonly property real headerHeight: headerShown ? headerRow.implicitHeight + 12 : 0
    readonly property real listHeight: widgetList.count === 0 ? 64
        : Math.min(widgetList.contentHeight + gap * Math.max(0, widgetList.count - 1),
            maxH - pad * 2 - headerHeight)
    implicitHeight: pad * 2 + headerHeight + listHeight

    property var widgetIds: island ? island.panelVisibleWidgets : []

    function currentOrder() {
        let ids = []
        for (let i = 0; i < widgetList.model.count; i++) {
            ids.push(widgetList.model.get(i).widgetId)
        }
        return Utils.serializeWidgetList(ids)
    }

    function rebuild(serialized) {
        widgetList.model.clear()
        const ids = Utils.parseWidgetList(serialized, Catalog.ids())
        for (let i = 0; i < ids.length; i++) {
            widgetList.model.append({ widgetId: ids[i] })
        }
    }

    function persistOrder() {
        Plasmoid.configuration.panelWidgets = currentOrder()
    }

    // Rebuild when the config changes, but never while a drag is live (the
    // drag itself wrote the config) and never when the incoming order merely
    // echoes the current model (e.g. an unrelated config write).
    onWidgetIdsChanged: {
        if (dragging) {
            return
        }
        const incoming = Utils.serializeWidgetList(widgetIds)
        if (incoming === currentOrder()) {
            return
        }
        rebuild(incoming)
    }

    Component.onCompleted: rebuild(Utils.serializeWidgetList(widgetIds))

    Column {
        anchors.fill: parent

        // ---- Header (always mode, active content) ----
        Item {
            id: headerRow

            width: parent.width
            height: visible ? headerContent.implicitHeight : 0
            visible: panel.headerShown

            Row {
                id: headerContent

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Kirigami.Icon {
                    width: 28
                    height: 28
                    source: island.activeMode === 0 ? "media-playback-start"
                        : (island.notificationIcon || "notifications")
                    color: island.textPrimary
                }

                Column {
                    width: parent.width - 40
                    spacing: 2

                    PlasmaComponents.Label {
                        width: parent.width
                        text: island.activeMode === 0
                            ? (island.mediaDisplayTitle || Tr.t("Music"))
                            : (island.notificationTitle || Tr.t("Notification"))
                        color: island.textPrimary
                        font.pointSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    PlasmaComponents.Label {
                        width: parent.width
                        text: island.activeMode === 0
                            ? (island.mediaDisplayArtist || island.mediaIdentity || "")
                            : (island.notificationBody || island.notificationApp || "")
                        color: island.textSecondary
                        font.pointSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ---- Widget list ----
        Item {
            width: parent.width
            height: panel.listHeight

            ListView {
                id: widgetList

                anchors.fill: parent
                spacing: panel.gap
                clip: true
                moveDisplaced: Transition {
                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
                }

                model: ListModel {}

                delegate: Item {
                    id: row

                    width: widgetList.width
                    height: Math.max(content.implicitHeight, 1)
                    property int delegateIndex: index

                    // Grip column: the only drag handle, so slider drags on
                    // the widget body are never swallowed by reordering.
                    Rectangle {
                        id: grip

                        width: 16
                        height: parent.height
                        color: gripMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        visible: panel.showGrips || gripMouse.containsMouse

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: "⋮⋮"
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize: 10
                        }

                        MouseArea {
                            id: gripMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: content
                            drag.axis: Drag.YAxis

                            onPressed: {
                                panel.dragging = true
                                content.z = 10
                            }

                            onPositionChanged: {
                                if (!gripMouse.drag.active) {
                                    return
                                }
                                const center = content.mapToItem(widgetList, content.width / 2, content.height / 2)
                                const target = widgetList.indexAt(center.x, center.y)
                                if (target >= 0 && target !== row.delegateIndex) {
                                    widgetList.model.move(row.delegateIndex, target)
                                }
                            }

                            onReleased: {
                                content.y = 0
                                content.z = 0
                                panel.dragging = false
                                panel.persistOrder()
                            }
                        }
                    }

                    Item {
                        id: content

                        anchors.left: grip.right
                        anchors.right: parent.right
                        height: row.height

                        Loader {
                            anchors.fill: parent
                            property var island: panel.island
                            source: Catalog.fileFor(model.widgetId)
                        }
                    }
                }
            }

            // ---- Empty state ----
            Item {
                anchors.fill: parent
                visible: widgetList.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    PlasmaComponents.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Tr.t("No widgets yet")
                        color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                        font.pointSize: 11
                        opacity: 0.75
                    }

                    Kirigami.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "configure"
                        width: 22
                        height: 22
                        color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const action = Plasmoid.internalAction("configure")
                                if (action) {
                                    action.trigger()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] Run `./tests/qmlcheck.sh`.

### Task 5: Widgets

**Files:** Create `package/contents/ui/widgets/ClockWidget.qml`, `SystemWidget.qml`, `MediaWidget.qml`, `TimerWidget.qml`, `VolumeWidget.qml`, `BrightnessWidget.qml`.

Each widget root declares `property var island: null`; the panel's Loader overrides it. Widgets read `island.*` for state and `Plasmoid.configuration` for their own settings.

**ClockWidget.qml** — the existing `timeText` at `widgetClockSize`:

```qml
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    property var island: null

    implicitHeight: 56

    PlasmaComponents.Label {
        anchors.centerIn: parent
        text: island.timeText
        color: island.textPrimary
        font.pointSize: Plasmoid.configuration.widgetClockSize
        font.weight: Font.Medium
    }
}
```

**SystemWidget.qml** — CPU/RAM/temp bars gated by the existing stat settings; temp hides at 0:

```qml
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents

Item {
    property var island: null

    implicitHeight: 96

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        RowLayout {
            visible: island.showCpuStat
            spacing: 10

            PlasmaComponents.Label { text: Tr.t("CPU"); color: island.textSecondary; font.pointSize: 10; Layout.preferredWidth: 36 }
            PlasmaComponents.Label { text: Math.round(island.cpuUsage) + "%"; color: island.textPrimary; font.pointSize: 11; Layout.preferredWidth: 42 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: parent.width * Math.min(1, island.cpuUsage / 100)
                    height: parent.height
                    radius: parent.radius
                    color: island.accent
                }
            }
        }

        RowLayout {
            visible: island.showRamStat
            spacing: 10

            PlasmaComponents.Label { text: Tr.t("RAM"); color: island.textSecondary; font.pointSize: 10; Layout.preferredWidth: 36 }
            PlasmaComponents.Label { text: Math.round(island.ramUsage) + "%"; color: island.textPrimary; font.pointSize: 11; Layout.preferredWidth: 42 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: parent.width * Math.min(1, island.ramUsage / 100)
                    height: parent.height
                    radius: parent.radius
                    color: island.accent
                }
            }
        }

        RowLayout {
            visible: island.showTempStat && island.cpuTemp > 0
            spacing: 10

            PlasmaComponents.Label { text: Tr.t("TEMP"); color: island.textSecondary; font.pointSize: 10; Layout.preferredWidth: 36 }
            PlasmaComponents.Label { text: Math.round(island.cpuTemp) + "°C"; color: island.textPrimary; font.pointSize: 11; Layout.preferredWidth: 42 }
        }
    }
}
```

(with `import "../Translator.js" as Tr` added.)

**MediaWidget.qml** — art, scrolling title/artist, seek bar with times, and prev/play/next, all styled by `island.mediaStyleExpanded`:

```qml
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../IslandUtils.js" as Utils
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null

    readonly property var style: island.mediaStyleExpanded
    implicitHeight: Math.max(96, style.artSize + 34)

    Item {
        id: artSlot

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(style.artSize, 56)
        height: width
        visible: style.showArt

        Kirigami.ShadowedImage {
            anchors.fill: parent
            visible: island.mediaArtUrl !== ""
            source: island.mediaArtUrl
            radius: style.artRadius
        }

        Rectangle {
            anchors.fill: parent
            visible: island.mediaArtUrl === ""
            radius: style.artRadius
            color: Qt.rgba(0.92, 0.94, 0.96, 0.28)

            Kirigami.Icon {
                anchors.centerIn: parent
                source: "audio-x-generic"
                width: Math.round(parent.width * 0.58)
                height: width
            }
        }
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: style.showControls

        Kirigami.Icon {
            source: "media-skip-backward"
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            opacity: island.mediaContainer ? 1 : 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: if (island.mediaContainer) island.mediaContainer.Previous()
            }
        }

        Kirigami.Icon {
            source: island.mediaPlaying ? "media-playback-pause" : "media-playback-start"
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            opacity: island.mediaContainer ? 1 : 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: if (island.mediaContainer) island.mediaContainer.PlayPause()
            }
        }

        Kirigami.Icon {
            source: "media-skip-forward"
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            opacity: island.mediaContainer ? 1 : 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: if (island.mediaContainer) island.mediaContainer.Next()
            }
        }
    }

    Column {
        id: textCol

        anchors.left: artSlot.visible ? artSlot.right : parent.left
        anchors.leftMargin: artSlot.visible ? 14 : 16
        anchors.right: controls.visible ? controls.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        ScrollingLabel {
            width: parent.width
            height: implicitHeight
            text: island.mediaDisplayTitle || Tr.t("No title")
            color: style.titleColor
            fontFamily: style.titleFont
            fontSize: style.titleSize
            fontWeight: style.titleWeight
            scroll: style.titleScroll
            animate: island.animationsEnabled
        }

        ScrollingLabel {
            width: parent.width
            height: implicitHeight
            visible: style.artistVisible
                && !(style.artistHideIfSame && island.mediaDisplayArtist === island.mediaDisplayTitle)
            text: island.mediaDisplayArtist || island.mediaIdentity || Tr.t("Media player")
            color: style.artistColor
            fontFamily: style.artistFont
            fontSize: style.artistSize
            fontWeight: style.artistWeight
            scroll: style.artistScroll
            animate: island.animationsEnabled
        }

        Item {
            width: parent.width
            height: Math.max(style.seekBarHeight, 14)
            visible: style.showSeekBar

            PlasmaComponents.Label {
                id: elapsedLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: style.showTimes
                text: Utils.mmss(island.mediaPositionSeconds)
                color: style.artistColor
                font.pointSize: Math.max(6, style.artistSize - 2)
            }

            PlasmaComponents.Label {
                id: totalLabel

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: style.showTimes
                text: Utils.mmss(island.mediaLengthSeconds)
                color: style.artistColor
                font.pointSize: Math.max(6, style.artistSize - 2)
            }

            Rectangle {
                id: seekTrack

                anchors.left: elapsedLabel.visible ? elapsedLabel.right : parent.left
                anchors.leftMargin: elapsedLabel.visible ? 8 : 0
                anchors.right: totalLabel.visible ? totalLabel.left : parent.right
                anchors.rightMargin: totalLabel.visible ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                height: style.seekBarHeight
                radius: Math.max(1, height / 2)
                color: Qt.rgba(1, 1, 1, 0.22)

                Rectangle {
                    width: parent.width * island.mediaProgress
                    height: parent.height
                    radius: parent.radius
                    color: island.accent

                    Behavior on width { NumberAnimation { duration: island.dur(220); easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -6
                    anchors.bottomMargin: -6
                    enabled: island.mediaContainer !== null && island.mediaLengthSeconds > 0
                    onClicked: (mouse) => {
                        const fraction = Math.max(0, Math.min(1, mouse.x / width))
                        island.mediaContainer.position = Math.round(fraction * island.mediaLength)
                    }
                }
            }
        }
    }
}
```

**TimerWidget.qml** — minutes field + start/pause/resume/reset driving root functions:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "../IslandUtils.js" as Utils
import "../Translator.js" as Tr

Item {
    property var island: null

    implicitHeight: 64

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        PlasmaComponents.Label {
            text: island.timerTotal > 0 ? Utils.mmss(island.timerRemaining)
                : Tr.tr("%1 min", minutesSpin.value)
            color: island.textPrimary
            font.pointSize: 16
            font.weight: Font.Medium
            Layout.preferredWidth: 92
        }

        QQC2.SpinBox {
            id: minutesSpin
            from: 1
            to: 600
            value: Plasmoid.configuration.timerDefaultMinutes
            enabled: !island.timerRunning
            editable: false
            Layout.preferredWidth: 72
        }

        Item { Layout.fillWidth: true }

        QQC2.Button {
            text: island.timerRunning ? Tr.t("Pause")
                : island.timerTotal > 0 ? Tr.t("Resume") : Tr.t("Start")
            onClicked: {
                if (island.timerRunning) {
                    island.pauseTimer()
                } else if (island.timerTotal > 0) {
                    island.resumeTimer()
                } else {
                    island.startTimer(minutesSpin.value)
                }
            }
        }

        QQC2.Button {
            text: Tr.t("Reset")
            onClicked: island.resetTimer()
        }
    }
}
```

**VolumeWidget.qml** — slider + mute over `VolumeSource`:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null

    readonly property var src: volumeLoader.item
    implicitHeight: src && src.available ? 56 : 0
    visible: src && src.available

    Loader {
        id: volumeLoader
        anchors.fill: parent
        source: "../VolumeSource.qml"
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Kirigami.Icon {
            source: "audio-volume-high"
            width: 22
            height: 22
            color: island.textPrimary
        }

        QQC2.Slider {
            id: volumeSlider

            from: 0
            to: 100
            value: widget.src ? widget.src.percent : 0
            enabled: widget.src ? widget.src.writable : false
            Layout.fillWidth: true
            onMoved: if (widget.src) widget.src.setVolume(value)
        }

        QQC2.Button {
            text: widget.src && widget.src.muted ? Tr.t("Unmute") : Tr.t("Mute")
            onClicked: if (widget.src) widget.src.toggleMute()
        }
    }
}
```

**BrightnessWidget.qml** — slider over `BrightnessSource`, hides when unavailable:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: widget

    property var island: null

    readonly property var src: brightnessLoader.item
    implicitHeight: src && src.available ? 56 : 0
    visible: src && src.available

    Loader {
        id: brightnessLoader
        anchors.fill: parent
        source: "../BrightnessSource.qml"
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Kirigami.Icon {
            source: "brightness-low"
            width: 22
            height: 22
            color: island.textPrimary
        }

        QQC2.Slider {
            from: 0
            to: widget.src ? Math.max(1, widget.src.brightnessMax) : 1
            value: widget.src ? widget.src.brightness : 0
            Layout.fillWidth: true
            onMoved: if (widget.src) widget.src.setBrightness(value)
        }

        PlasmaComponents.Label {
            text: widget.src ? Math.round(widget.src.brightness) + "%" : ""
        }
    }
}
```

(with `import org.kde.plasma.components as PlasmaComponents` added.)

- [ ] Run `./tests/qmlcheck.sh`.

### Task 6: main.qml wiring

**Files:** Modify `package/contents/ui/main.qml`.

**Step 1 — imports:** add `import org.kde.notification as Notifications` and `import "WidgetCatalog.js" as Catalog` to the import block.

**Step 2 — panel properties** (near the other config reads, after `showFps`/`fpsStyle`):

```qml
    readonly property bool panelEnabled: Plasmoid.configuration.panelEnabled
    readonly property string panelShowMode: Plasmoid.configuration.panelShowMode
    readonly property bool popupCloseOnHoverExit: Plasmoid.configuration.popupCloseOnHoverExit
    readonly property int panelWidth: Plasmoid.configuration.panelWidth
    readonly property var panelWidgetIds: Utils.parseWidgetList(Plasmoid.configuration.panelWidgets, Catalog.ids())
    // Module-gated ids dropped here; the ids themselves stay in panelWidgets so
    // re-enabling a module restores the widget in place.
    readonly property var panelVisibleWidgets: {
        let out = []
        for (let i = 0; i < panelWidgetIds.length; i++) {
            if (Catalog.isAvailable(panelWidgetIds[i], Plasmoid.configuration)) {
                out.push(panelWidgetIds[i])
            }
        }
        return out
    }
    readonly property bool panelActive: panelEnabled && (panelShowMode === "always" || idleMode)
```

**Step 3 — timer state and functions** (near the other state properties, after `buildApp`):

```qml
    property int timerTotal: 0
    property int timerRemaining: 0
    property bool timerRunning: false
```

and near the other functions:

```qml
    function startTimer(minutes) {
        timerTotal = Math.max(1, Math.round(minutes || Plasmoid.configuration.timerDefaultMinutes)) * 60
        timerRemaining = timerTotal
        timerRunning = true
    }

    function pauseTimer() {
        timerRunning = false
    }

    function resumeTimer() {
        if (timerRemaining > 0) {
            timerRunning = true
        }
    }

    function resetTimer() {
        timerRunning = false
        timerTotal = 0
        timerRemaining = 0
    }

    function tickTimer() {
        timerRemaining -= 1
        if (timerRemaining <= 0) {
            timerRemaining = 0
            timerRunning = false
            finishTimer()
        }
    }

    function finishTimer() {
        modeIndex = 4
        eventTimer.restart()
        if (Plasmoid.configuration.timerNotifyOnFinish) {
            timerNotifier.title = Tr.t("Timer finished")
            timerNotifier.text = Tr.tr("%1 minutes elapsed", Math.round(timerTotal / 60))
            timerNotifier.sendEvent()
        }
    }
```

and the ticking Timer + the KNotification instance (near the other Timers):

```qml
    Timer {
        id: timerTick
        interval: 1000
        running: root.timerRunning
        repeat: true
        onTriggered: root.tickTimer()
    }

    Notifications.Notification {
        id: timerNotifier
        eventId: "timerFinished"
        iconName: "chronometer"
    }
```

**Step 4 — clock takeover precedence:**

```qml
    readonly property string clockDisplay: (timerRunning && Plasmoid.configuration.timerTakeOverClock)
        ? Utils.mmss(timerRemaining)
        : showSysStats ? statsText : timeText
```

**Step 5 — sysMonitorRotateClock split:**

```qml
    readonly property bool sysMonitorRotateClock: Plasmoid.configuration.sysMonitorRotateClock
    readonly property bool showSysStats: enableSysMonitor && sysMonitorRotateClock && idleMode && sysPhase && sysReady
```

and `sysRotateTimer.running` becomes `root.enableSysMonitor && root.sysMonitorRotateClock && root.idleMode`.

**Step 6 — popup routing.** In the `PlasmaCore.Dialog`, change `x` to use the panel width when active, and change `mainItem` width/height, the `onExited` gate, and add the Esc `Shortcut`:

```qml
        x: Math.round((root.compactWidth - (root.panelActive ? root.panelWidth : root.expandedWidth)) / 2)
```

```qml
        mainItem: Item {
            width: root.panelActive ? root.panelWidth : root.expandedWidth
            height: root.panelActive
                ? (expandedLoader.item && expandedLoader.item.item
                    ? expandedLoader.item.item.implicitHeight : root.expandedHeight)
                : root.expandedHeight
            opacity: root.popupOpen ? 1 : 0
            scale: root.popupOpen ? 1 : 0.92

            Behavior on opacity { NumberAnimation { duration: root.animationsEnabled ? Math.round(130 * root.animMultiplier) : 0; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animationsEnabled ? Math.round(170 * root.animMultiplier) : 0; easing.type: Easing.OutBack } }

            Shortcut {
                sequences: [StandardKey.Cancel]
                onActivated: root.closePopup()
            }

            MouseArea {
                id: popupMouseArea

                anchors.fill: parent
                hoverEnabled: true
                onExited: if (root.popupCloseOnHoverExit) root.closePopup()
            }
            ...
```

**Step 7 — expandedContent routing.** Replace the component with a `Loader` whose `sourceComponent` picks the panel when active:

```qml
    Component {
        id: expandedContent

        Loader {
            id: modeLoader
            anchors.fill: parent
            sourceComponent: root.panelActive ? panelContent
                : root.activeMode === 0 ? musicExpanded
                : root.activeMode === 2 ? notificationExpanded
                : statusExpanded
        }
    }

    Component {
        id: panelContent

        Loader {
            id: panelHost
            anchors.fill: parent
            property var island: root
            source: "IslandPanel.qml"
        }
    }
```

- [ ] Run `node tests/islandutils.test.mjs && ./tests/qmlcheck.sh`.

### Task 7: Config pages

**Files:** Create `package/contents/ui/configPanel.qml`, `package/contents/ui/configTimer.qml`; modify `package/contents/config/config.qml`, `package/contents/ui/configFeatures.qml`, `package/contents/ui/configMonitor.qml`.

**configPanel.qml** — panel behaviour, geometry, widget add/remove (module-gated entries greyed), clock widget size. Every `cfg_*` on the root item:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../ui/Translator.js" as Tr
import "../ui/IslandUtils.js" as Utils
import "../ui/WidgetCatalog.js" as Catalog

Kirigami.FormLayout {
    id: page

    property alias cfg_panelEnabled: panelEnabledSwitch.checked
    property alias cfg_panelWidth: widthSpin.value
    property alias cfg_panelMaxHeight: maxHeightSpin.value
    property alias cfg_panelSpacing: spacingSpin.value
    property alias cfg_panelPadding: paddingSpin.value
    property alias cfg_panelShowGrips: gripsSwitch.checked
    property alias cfg_popupCloseOnHoverExit: hoverExitSwitch.checked
    property alias cfg_widgetClockSize: clockSizeSpin.value
    property string cfg_panelShowMode: "idle"
    property string cfg_panelWidgets: "media,system"

    function widgetIds() {
        return Utils.parseWidgetList(cfg_panelWidgets, Catalog.ids())
    }

    function hasWidget(id) {
        return widgetIds().indexOf(id) !== -1
    }

    function toggleWidget(id, on) {
        let ids = widgetIds()
        if (on && ids.indexOf(id) === -1) {
            ids.push(id)
        }
        if (!on) {
            ids = ids.filter((x) => x !== id)
        }
        cfg_panelWidgets = Utils.serializeWidgetList(ids)
    }

    QQC2.Switch {
        id: panelEnabledSwitch
        Kirigami.FormData.label: Tr.t("Widget panel:")
        text: Tr.t("Open a floating widget panel from the idle capsule")
    }

    QQC2.ComboBox {
        id: showModeCombo
        Kirigami.FormData.label: Tr.t("When to open:")
        enabled: panelEnabledSwitch.checked
        textRole: "text"
        valueRole: "value"
        model: [
            { text: Tr.t("Only when nothing else is happening"), value: "idle" },
            { text: Tr.t("Always, with active content as a header"), value: "always" }
        ]
        onActivated: page.cfg_panelShowMode = currentValue
        Component.onCompleted: currentIndex = indexOfValue(page.cfg_panelShowMode)
    }

    QQC2.Switch {
        id: hoverExitSwitch
        Kirigami.FormData.label: Tr.t("Close behaviour:")
        text: Tr.t("Close when the pointer leaves the panel")
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Width:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: widthSpin; from: 240; to: 560; stepSize: 10 }
        QQC2.Label { text: Tr.t("px") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Max height:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: maxHeightSpin; from: 120; to: 900; stepSize: 20 }
        QQC2.Label { text: Tr.t("px, taller panels scroll") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Spacing:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: spacingSpin; from: 0; to: 24; stepSize: 1 }
        QQC2.Label { text: Tr.t("px between widgets") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Padding:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: paddingSpin; from: 0; to: 32; stepSize: 1 }
        QQC2.Label { text: Tr.t("px around the widgets") }
    }

    QQC2.Switch {
        id: gripsSwitch
        Kirigami.FormData.label: Tr.t("Reorder:")
        enabled: panelEnabledSwitch.checked
        text: Tr.t("Always show the drag handles (otherwise they appear on hover)")
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.Label {
        Kirigami.FormData.label: Tr.t("Widgets:")
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Reorder by dragging in the panel. Widgets of a disabled module stay in the list but are greyed out until you enable that module.")
    }

    Repeater {
        model: Catalog.CATALOG

        delegate: QQC2.CheckBox {
            Kirigami.FormData.label: index === 0 ? Tr.t("Show:") : ""
            enabled: Catalog.requiresModule(modelData.id) === ""
                || Plasmoid.configuration[Catalog.requiresModule(modelData.id)]
            text: Catalog.labelFor(modelData.id)
            checked: page.hasWidget(modelData.id)
            onToggled: page.toggleWidget(modelData.id, checked)
        }
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Clock size:")
        QQC2.SpinBox { id: clockSizeSpin; from: 10; to: 64; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }
}
```

**configTimer.qml:**

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../ui/Translator.js" as Tr

Kirigami.FormLayout {
    property alias cfg_enableTimer: timerSwitch.checked
    property alias cfg_timerDefaultMinutes: defaultSpin.value
    property alias cfg_timerTakeOverClock: takeoverSwitch.checked
    property alias cfg_timerNotifyOnFinish: notifySwitch.checked

    QQC2.Switch {
        id: timerSwitch
        Kirigami.FormData.label: Tr.t("Timer module:")
        text: Tr.t("Show the countdown timer widget in the panel")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Default length:")
        enabled: timerSwitch.checked
        QQC2.SpinBox { id: defaultSpin; from: 1; to: 600; stepSize: 1 }
        QQC2.Label { text: Tr.t("min") }
    }

    QQC2.Switch {
        id: takeoverSwitch
        Kirigami.FormData.label: Tr.t("Countdown:")
        enabled: timerSwitch.checked
        text: Tr.t("Replace the capsule clock with the countdown while it runs")
    }

    QQC2.Switch {
        id: notifySwitch
        Kirigami.FormData.label: Tr.t("Finished:")
        enabled: timerSwitch.checked
        text: Tr.t("Post a desktop notification when the timer ends")
    }
}
```

**config.qml** — add after the `Appearance` category:

```qml
    ConfigCategory {
        name: Tr.t("Panel")
        icon: "dashboard-show"
        source: "configPanel.qml"
    }
    ConfigCategory {
        name: Tr.t("Timer")
        icon: "chronometer"
        source: "configTimer.qml"
        visible: Plasmoid.configuration.enableTimer
    }
```

**configFeatures.qml** — add `property alias cfg_enableTimer: timerSwitch.checked`, a `Timer` switch, and the Apply note:

```qml
    QQC2.Switch { id: timerSwitch; Kirigami.FormData.label: Tr.t("Timer:"); text: Tr.t("Countdown timer in the widget panel") }
```

plus a wrapping note label at the bottom: `Tr.t("Module settings pages appear after applying changes.")`.

**configMonitor.qml** — rename the master switch text and add the rotation switch:

- master: `text: Tr.t("Enable system monitoring (CPU, RAM, temperature)")`
- new: `property alias cfg_sysMonitorRotateClock: rotateSwitch.checked` and

```qml
    QQC2.Switch {
        id: rotateSwitch
        Kirigami.FormData.label: Tr.t("Rotate clock:")
        enabled: sysMonSwitch.checked
        text: Tr.t("Alternate the idle clock with system usage")
    }
```

- [ ] Run `./tests/qmlcheck.sh`.

### Task 8: Packaging and acceptance

**Files:** Create `package.sh`; modify `package/metadata.json` (version).

**package.sh:**

```sh
#!/usr/bin/env bash
# Builds the single-archive .plasmoid for KDE Store installs. The archive name
# is derived from metadata.json so it cannot drift from the declared version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' "$ROOT/package/metadata.json" | head -1)
OUT="$ROOT/dynamicisland-$VERSION.plasmoid"

rm -f "$OUT"
(cd "$ROOT/package" && zip -r -q "$OUT" . -x '.*' -x '*/.*')
echo "Built $OUT"
```

Bump `package/metadata.json` `Version` to `1.3.0`.

**Acceptance:**

- [ ] `node tests/islandutils.test.mjs && ./tests/qmlcheck.sh` — both pass.
- [ ] `./install.sh && plasmawindowed com.ifny75.dynamicisland 2>&1 | tee /tmp/di3.log` — no errors; idle capsule opens the panel; `Esc`/outside click closes it.
- [ ] Config round-trip: set `panelWidgets` to `clock,media` via `kwriteconfig6`, confirm the panel order follows, then restore.
- [ ] `./package.sh` produces `dynamicisland-1.3.0.plasmoid`; `unzip -l` shows `metadata.json` at the archive root and no `tests/`/`docs/`.
- [ ] Commit.

## Self-review

**Spec coverage.** Panel infrastructure (Task 4), click routing and persistence (Task 6), six widgets (Task 5), timer module with clock takeover and finish announcement (Tasks 6), `enableSysMonitor` split (Task 6 step 5), config pages (Task 7), packaging (Task 8). `parseWidgetList`/`serializeWidgetList`/`moveItem` from phase 1 carry the order logic; `mmss` formats the countdown.

**Version fragility.** `volume` and `brightnesscontrolplugin` are Loader-isolated; a missing module hides the widget. `org.kde.notification` and `org.kde.ksysguard.sensors` follow the same pattern where needed.

**Concurrency.** The panel suppresses rebuilds during a drag and skips rebuilds whose incoming order equals the current model, so config writes from the panel cannot rebuild the model under the pointer.
