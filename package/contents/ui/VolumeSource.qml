import QtQuick
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.plasma5support as Plasma5Support

// Loader-isolated PulseAudio/PipeWire access.
// Mirrors the BrightnessSource pattern: Repeater reads roles declaratively,
// writes go through the PulseObject directly.
Item {
    id: src

    // ── Exposed state ──────────────────────────────────────────────────
    readonly property bool available: defaultSink !== null
    readonly property int  normalVol: Volume.PulseAudio.NormalVolume || 65536

    // The default sink's PulseObject, populated by the Repeater below.
    property var defaultSink: null

    // Volume as 0-100 percent
    readonly property int percent: {
        if (!defaultSink) return 0
        return Math.max(0, Math.min(100, Math.round(defaultSink.volume / normalVol * 100)))
    }

    readonly property bool muted: defaultSink ? defaultSink.muted : false

    // ── SinkModel + Repeater (mirrors BrightnessSource pattern) ────────
    Volume.SinkModel {
        id: sinkModel
    }

    // Invisible Repeater; each delegate holds a reference to its
    // PulseObject and Default flag via declarative role bindings.
    Repeater {
        model: sinkModel

        delegate: Item {
            visible: false

            // Declarative role access — the QML engine resolves these
            // by name through the model's roleNames(), no magic numbers needed.
            readonly property var   pulseObj:  model.PulseObject
            readonly property bool  isDefault: model.Default

            // Whenever the default sink or its PulseObject changes, update src.defaultSink.
            onIsDefaultChanged: src.pickDefaultSink()
            onPulseObjChanged:  src.pickDefaultSink()
            Component.onCompleted:   src.pickDefaultSink()
            Component.onDestruction: Qt.callLater(src.pickDefaultSink)
        }
    }

    // ── Sink selection ─────────────────────────────────────────────────
    function pickDefaultSink() {
        var found = null
        var first = null
        for (var i = 0; i < sinkModel.count; i++) {
            var item = repeaterItem(i)
            if (!item || !item.pulseObj) continue
            if (!first) first = item.pulseObj
            if (item.isDefault) { found = item.pulseObj; break }
        }
        src.defaultSink = found ? found : first
    }

    // Helper: get Repeater delegate by index.
    // The Repeater is the second child of src (index 1 after sinkModel).
    function repeaterItem(i) {
        // Walk children to find the Repeater's delegate at index i.
        for (var c = 0; c < src.children.length; c++) {
            var child = src.children[c]
            if (child && typeof child.itemAt === "function") {
                return child.itemAt(i)
            }
        }
        return null
    }

    // ── Write API ──────────────────────────────────────────────────────
    function setVolume(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        if (defaultSink) {
            // Primary path: write directly to PulseObject (same as plasma-pa does)
            defaultSink.volume = Math.round((clamped / 100) * normalVol)
            if (defaultSink.muted && clamped > 0) defaultSink.muted = false
        } else {
            // Fallback: shell command (same as main.qml's setVolume)
            execFallback.run(
                "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100) +
                " || pactl set-sink-volume @DEFAULT_SINK@ " + clamped + "%" +
                " || amixer set Master " + clamped + "%"
            )
        }
    }

    function toggleMute() {
        if (defaultSink) {
            defaultSink.muted = !defaultSink.muted
        } else {
            execFallback.run(
                "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" +
                " || pactl set-sink-mute @DEFAULT_SINK@ toggle" +
                " || amixer set Master toggle"
            )
        }
    }

    // ── Shell fallback (mirrors ExecSource, used when PulseObject unavailable) ──
    Plasma5Support.DataSource {
        id: execFallback
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName) => disconnectSource(sourceName)
    }

    // Convenience wrapper so callsites don't need to know about DataSource internals
    function run(cmd) {
        if (cmd) execFallback.connectSource("sh -c " + JSON.stringify(cmd + "; echo done"))
    }

    Component.onCompleted: pickDefaultSink()
}
