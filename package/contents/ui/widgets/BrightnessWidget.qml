import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

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
            color: island.textSecondary
            font.pointSize: 10
        }
    }
}
