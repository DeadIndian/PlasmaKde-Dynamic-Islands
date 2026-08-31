import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "IslandUtils.js" as Utils
import "Translator.js" as Tr

// The expanded media panel. Every size, font and colour comes from `style`
// (a MediaStyle), so the same settings drive the compact capsule too.
Item {
    id: view

    property var island: null
    property var style: null

    readonly property bool hasArt: island.mediaArtUrl !== ""
    readonly property bool artistShown: style.artistVisible
        && !(style.artistHideIfSame && island.mediaDisplayArtist === island.mediaDisplayTitle)
    readonly property bool seekable: island.mediaContainer !== null
        && island.mediaLengthSeconds > 0
        && island.mediaContainer.canSeek === true

    Item {
        id: artSlot

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: view.style.artSize
        height: width
        visible: view.style.showArt

        // Album art ambient glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 20
            height: parent.height + 20
            radius: width / 2
            color: view.island && view.island.accent ? view.island.accent : "#8d5cff"
            opacity: 0.25
            visible: view.hasArt
            z: -1
        }

        // ShadowedImage is Kirigami's rounded-image primitive. A plain Image
        // inside a clipped Rectangle would not round, because Qt Quick's clip
        // is rectangular.
        Kirigami.ShadowedImage {
            anchors.fill: parent
            visible: view.hasArt
            source: view.island.mediaArtUrl
            radius: view.style.artRadius
        }

        Rectangle {
            anchors.fill: parent
            visible: !view.hasArt
            radius: view.style.artRadius
            color: Qt.rgba(0.92, 0.94, 0.96, 0.28)

            Kirigami.Icon {
                anchors.centerIn: parent
                source: "audio-x-generic"
                width: Math.round(parent.width * 0.58)
                height: width
            }
        }
    }

    SoundBars {
        id: musicBars

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 16
        width: 38
        height: 28
        visible: view.style.showSoundBars
        playing: view.island.mediaPlaying
        barColor: view.island.textPrimary
        animate: view.island.animationsEnabled
    }

    Row {
        id: musicControls

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 14
        visible: view.style.showControls

        Kirigami.Icon {
            source: "media-skip-backward"
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            opacity: view.island.mediaContainer ? (prevMouse.containsMouse ? 1.0 : 0.8) : 0.35
            scale: prevMouse.pressed ? 0.85 : 1.0

            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (view.island.mediaContainer) view.island.mediaContainer.Previous()
            }
        }

        Kirigami.Icon {
            source: view.island.mediaPlaying ? "media-playback-pause" : "media-playback-start"
            width: 26
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            opacity: view.island.mediaContainer ? (playMouse.containsMouse ? 1.0 : 0.8) : 0.35
            scale: playMouse.pressed ? 0.85 : 1.0

            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (view.island.mediaContainer) view.island.mediaContainer.PlayPause()
            }
        }

        Kirigami.Icon {
            source: "media-skip-forward"
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            opacity: view.island.mediaContainer ? (nextMouse.containsMouse ? 1.0 : 0.8) : 0.35
            scale: nextMouse.pressed ? 0.85 : 1.0

            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (view.island.mediaContainer) view.island.mediaContainer.Next()
            }
        }
    }

    ScrollingLabel {
        id: musicTitle

        anchors.left: artSlot.visible ? artSlot.right : parent.left
        anchors.leftMargin: artSlot.visible ? 14 : 16
        anchors.right: musicBars.visible ? musicBars.left : parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 16
        height: implicitHeight
        visible: view.style.titleVisible
        text: view.island.mediaDisplayTitle || Tr.t("No title")
        color: view.style.titleColor
        fontFamily: view.style.titleFont
        fontSize: view.style.titleSize
        fontWeight: view.style.titleWeight
        scroll: view.style.titleScroll
        animate: view.island.animationsEnabled
    }

    ScrollingLabel {
        id: musicArtist

        anchors.left: musicTitle.left
        anchors.right: musicTitle.right
        anchors.top: musicTitle.visible ? musicTitle.bottom : parent.top
        anchors.topMargin: musicTitle.visible ? 2 : 16
        height: implicitHeight
        visible: view.artistShown
        text: view.island.mediaDisplayArtist || view.island.mediaIdentity || Tr.t("Media player")
        color: view.style.artistColor
        fontFamily: view.style.artistFont
        fontSize: view.style.artistSize
        fontWeight: view.style.artistWeight
        scroll: view.style.artistScroll
        animate: view.island.animationsEnabled
    }

    Item {
        id: seekRow

        anchors.left: musicTitle.left
        anchors.right: musicControls.visible ? musicControls.left : parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        height: Math.max(view.style.seekBarHeight, elapsedLabel.visible ? elapsedLabel.implicitHeight : 0)
        visible: view.style.showSeekBar

        PlasmaComponents.Label {
            id: elapsedLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: view.style.showTimes
            text: Utils.mmss(view.island.mediaPositionSeconds)
            color: view.style.artistColor
            font.pointSize: Math.max(6, view.style.artistSize - 2)
        }

        PlasmaComponents.Label {
            id: totalLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: view.style.showTimes
            text: Utils.mmss(view.island.mediaLengthSeconds)
            color: view.style.artistColor
            font.pointSize: Math.max(6, view.style.artistSize - 2)
        }

        Rectangle {
            id: seekTrack

            anchors.left: elapsedLabel.visible ? elapsedLabel.right : parent.left
            anchors.leftMargin: elapsedLabel.visible ? 8 : 0
            anchors.right: totalLabel.visible ? totalLabel.left : parent.right
            anchors.rightMargin: totalLabel.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            height: seekHover.containsMouse ? view.style.seekBarHeight + 2 : view.style.seekBarHeight
            radius: Math.max(1, height / 2)
            color: Qt.rgba(1, 1, 1, 0.22)

            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: progressFill
                width: parent.width * view.island.mediaProgress
                height: parent.height
                radius: parent.radius
                color: view.island.accent

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                // Glowing scrubber dot
                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: progressFill.width - 5
                    visible: seekHover.containsMouse
                    scale: seekHover.containsMouse ? 1.0 : 0.0
                    
                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Click-to-seek. MPRIS positions are microseconds, and the
            // container's `position` property is writable.
            MouseArea {
                id: seekHover
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                hoverEnabled: true
                enabled: view.seekable
                cursorShape: view.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: (mouse) => {
                    const fraction = Math.max(0, Math.min(1, mouse.x / width))
                    view.island.mediaContainer.position = Math.round(fraction * view.island.mediaLength)
                }
            }
        }
    }
}
