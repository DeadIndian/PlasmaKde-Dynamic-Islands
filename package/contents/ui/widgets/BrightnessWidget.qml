import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int spanW: 3
    property int spanH: 1
    property int fallbackValue: 80

    readonly property var src: brightnessLoader.item
    readonly property bool available: src ? src.available : false
    readonly property real pct: available ? (src.brightnessMax > 0 ? (src.brightness / src.brightnessMax) * 100 : 0) : fallbackValue

    implicitHeight: 48
    implicitWidth: 320
    visible: true

    Loader {
        id: brightnessLoader
        anchors.fill: parent
        source: "../BrightnessSource.qml"
    }

    function updateBrightness(val) {
        var target = Math.max(0, Math.min(100, Math.round(val)))
        widget.fallbackValue = target
        if (widget.available && widget.src) {
            var maxVal = widget.src.brightnessMax > 0 ? widget.src.brightnessMax : 100
            widget.src.setBrightness(Math.round((target / 100.0) * maxVal))
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            var step = wheel.angleDelta.y > 0 ? 5 : -5
            var nextVal = Math.max(0, Math.min(100, Math.round(widget.pct) + step))
            widget.updateBrightness(nextVal)
        }
    }

    // Full slider view for spanW >= 2
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: widget.spanW >= 2

        Kirigami.Icon {
            source: widget.pct > 50 ? "brightness-high" : "brightness-low"
            width: 20
            height: 20
            color: island ? island.textPrimary : "white"
        }

        QQC2.Slider {
            id: brightnessSlider
            from: 0
            to: 100
            value: Math.round(widget.pct)
            Layout.fillWidth: true

            Binding on value {
                when: !brightnessSlider.pressed
                value: Math.round(widget.pct)
            }

            onMoved: widget.updateBrightness(value)
            onValueChanged: {
                if (brightnessSlider.pressed) {
                    widget.updateBrightness(value)
                }
            }

            background: Rectangle {
                x: brightnessSlider.leftPadding
                y: brightnessSlider.topPadding + Math.round((brightnessSlider.availableHeight - height) / 2)
                implicitWidth: 200
                implicitHeight: 8
                width: brightnessSlider.availableWidth
                height: implicitHeight
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: brightnessSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: island ? island.accent : "#3498db"
                }
            }

            handle: Rectangle {
                x: brightnessSlider.leftPadding + Math.round(brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width))
                y: brightnessSlider.topPadding + Math.round((brightnessSlider.availableHeight - height) / 2)
                implicitWidth: 20
                implicitHeight: 20
                radius: 10
                color: brightnessSlider.pressed ? Qt.lighter(island ? island.accent : "#3498db", 1.2) : "white"
                border.width: 2
                border.color: island ? island.accent : "#3498db"
                scale: brightnessSlider.pressed ? 0.9 : (brightnessSlider.hovered ? 1.1 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }
        }

        PlasmaComponents.Label {
            text: Math.round(widget.pct) + "%"
            color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
            font.pointSize: 9.5
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    // Compact pill view for spanW === 1
    Rectangle {
        id: compactPill
        anchors.fill: parent
        visible: widget.spanW === 1
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.18)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        scale: pillMouse.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            onWheel: (wheel) => {
                var step = wheel.angleDelta.y > 0 ? 5 : -5
                var nextVal = Math.max(0, Math.min(100, Math.round(widget.pct) + step))
                widget.updateBrightness(nextVal)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Kirigami.Icon {
                source: widget.pct > 50 ? "brightness-high" : "brightness-low"
                width: 18
                height: 18
                color: island ? island.textPrimary : "white"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: Math.round(widget.pct) + "%"
                color: island ? island.textPrimary : "white"
                font.pointSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }
}
