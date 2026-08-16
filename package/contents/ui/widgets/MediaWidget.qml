import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import ".."
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
