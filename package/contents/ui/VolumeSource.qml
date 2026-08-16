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
