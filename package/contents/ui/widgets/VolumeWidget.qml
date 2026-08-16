import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null

    readonly property var src: volumeLoader.item
    implicitHeight: src && src.available ? 56 : 0
    implicitWidth: 320
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
