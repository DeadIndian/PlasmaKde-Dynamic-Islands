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

    // Read the first display's roles.  Role names vary across Plasma
    // versions so both spellings are tried.  Bindings keep the values
    // reactive so the widget updates when the backlight changes.
    Repeater {
        model: control.displays

        delegate: Item {
            visible: false
            readonly property string dName: model.displayName || model.DisplayName || ""
            readonly property int bVal: model.brightness || model.Brightness || 0
            readonly property int bMax: model.brightnessMax || model.maxBrightness || model.BrightnessMax || 100

            Component.onCompleted: {
                if (index === 0) {
                    src.displayName = dName
                    src.brightness = bVal
                    src.brightnessMax = bMax
                }
            }
            onBValChanged: if (index === 0) src.brightness = bVal
            onBMaxChanged: if (index === 0) src.brightnessMax = bMax
        }
    }

    function setBrightness(value) {
        if (available) {
            control.setBrightness(displayName, Math.max(0, Math.min(brightnessMax, Math.round(value))))
        }
    }
}
