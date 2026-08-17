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
    property int fallbackPercent: 75
    property bool fallbackMuted: false

    readonly property var src: volumeLoader.item
    readonly property bool available: src ? src.available : false
    readonly property int currentPercent: available ? src.percent : fallbackPercent
    readonly property bool isMuted: available ? src.muted : fallbackMuted

    implicitHeight: 48
    implicitWidth: 320
    visible: true

    Loader {
        id: volumeLoader
        anchors.fill: parent
        source: "../VolumeSource.qml"
    }

    function updateVolume(val) {
        var target = Math.max(0, Math.min(100, Math.round(val)))
        widget.fallbackPercent = target
        if (widget.available && widget.src) {
            widget.src.setVolume(target)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            var step = wheel.angleDelta.y > 0 ? 5 : -5
            var nextVol = Math.max(0, Math.min(100, widget.currentPercent + step))
            widget.updateVolume(nextVol)
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
            source: widget.isMuted ? "audio-volume-muted"
                : widget.currentPercent > 50 ? "audio-volume-high"
                : widget.currentPercent > 0 ? "audio-volume-medium"
                : "audio-volume-low"
            width: 20
            height: 20
            color: island ? island.textPrimary : "white"
        }

        QQC2.Slider {
            id: volumeSlider
            from: 0
            to: 100
            value: widget.currentPercent
            Layout.fillWidth: true

            Binding on value {
                when: !volumeSlider.pressed
                value: widget.currentPercent
            }

            onMoved: widget.updateVolume(value)
            onValueChanged: {
                if (volumeSlider.pressed) {
                    widget.updateVolume(value)
                }
            }

            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + Math.round((volumeSlider.availableHeight - height) / 2)
                implicitWidth: 200
                implicitHeight: 6
                width: volumeSlider.availableWidth
                height: implicitHeight
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: island ? island.accent : "#3498db"
                }
            }

            handle: Rectangle {
                x: volumeSlider.leftPadding + Math.round(volumeSlider.visualPosition * (volumeSlider.availableWidth - width))
                y: volumeSlider.topPadding + Math.round((volumeSlider.availableHeight - height) / 2)
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: volumeSlider.pressed ? Qt.lighter(island ? island.accent : "#3498db", 1.2) : "white"
                border.width: 2
                border.color: island ? island.accent : "#3498db"
            }
        }

        PlasmaComponents.Label {
            text: widget.currentPercent + "%"
            color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
            font.pointSize: 9.5
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }

        Rectangle {
            implicitHeight: 26
            implicitWidth: muteLabel.implicitWidth + 18
            radius: 13
            color: muteMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)

            PlasmaComponents.Label {
                id: muteLabel
                anchors.centerIn: parent
                text: widget.isMuted ? Tr.t("Unmute") : Tr.t("Mute")
                color: island ? island.textPrimary : "white"
                font.pointSize: 8.5
                font.weight: Font.Medium
            }

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (widget.available && widget.src) {
                        widget.src.toggleMute()
                    } else {
                        widget.fallbackMuted = !widget.fallbackMuted
                    }
                }
            }
        }
    }

    // Compact pill view for spanW === 1
    Rectangle {
        anchors.fill: parent
        visible: widget.spanW === 1
        radius: 16
        color: widget.isMuted ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.18)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Kirigami.Icon {
                source: widget.isMuted ? "audio-volume-muted"
                    : widget.currentPercent > 50 ? "audio-volume-high"
                    : widget.currentPercent > 0 ? "audio-volume-medium"
                    : "audio-volume-low"
                width: 18
                height: 18
                color: island ? island.textPrimary : "white"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: widget.isMuted ? Tr.t("Muted") : widget.currentPercent + "%"
                color: island ? island.textPrimary : "white"
                font.pointSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (widget.available && widget.src) {
                    widget.src.toggleMute()
                } else {
                    widget.fallbackMuted = !widget.fallbackMuted
                }
            }
        }
    }
}
