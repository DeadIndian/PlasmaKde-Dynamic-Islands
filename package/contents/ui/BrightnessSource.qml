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
