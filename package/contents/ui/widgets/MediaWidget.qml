import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import ".."
import "../IslandUtils.js" as Utils
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int spanW: 3
    property int spanH: 2

    readonly property bool isMiniPill: spanW === 1 && spanH === 1
    readonly property bool isTallCard: spanH >= 2 && spanW >= 2
    readonly property var style: island ? island.mediaStyleExpanded : null

    implicitHeight: isMiniPill ? 48 : (isTallCard ? 150 : 80)
    implicitWidth: 400

    readonly property string displayTitle: {
        if (island && island.mediaDisplayTitle && island.mediaDisplayTitle.trim().length > 0) {
            return island.mediaDisplayTitle
        }
        return Tr.t("No Media Playing")
    }

    readonly property string displayArtist: {
        if (island && (island.mediaDisplayArtist || island.mediaIdentity) && (island.mediaDisplayArtist || island.mediaIdentity).trim().length > 0) {
            return island.mediaDisplayArtist || island.mediaIdentity
        }
        return Tr.t("Media Player")
    }

    // ── Tall 2D Card View (2x2, 3x2) ──────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        visible: widget.isTallCard

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Album Art
            Item {
                implicitWidth: 48
                implicitHeight: 48

                Kirigami.ShadowedImage {
                    anchors.fill: parent
                    visible: island && island.mediaArtUrl !== ""
                    source: island ? island.mediaArtUrl : ""
                    radius: style ? style.artRadius : 8
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !island || island.mediaArtUrl === ""
                    radius: style ? style.artRadius : 8
                    color: Qt.rgba(0.92, 0.94, 0.96, 0.2)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "audio-x-generic"
                        width: 32; height: 32
                        color: island ? island.textPrimary : "white"
                    }
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                ScrollingLabel {
                    width: parent.width
                    height: implicitHeight
                    text: widget.displayTitle
                    color: style ? style.titleColor : (island ? island.textPrimary : "white")
                    fontFamily: style ? style.titleFont : ""
                    fontSize: style ? style.titleSize : 13
                    fontWeight: Font.Bold
                    scroll: style ? style.titleScroll : true
                    animate: island ? island.animationsEnabled : true
                }

                ScrollingLabel {
                    width: parent.width
                    height: implicitHeight
                    text: widget.displayArtist
                    color: style ? style.artistColor : (island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7))
                    fontFamily: style ? style.artistFont : ""
                    fontSize: style ? style.artistSize : 10.5
                    fontWeight: Font.Normal
                    scroll: style ? style.artistScroll : true
                    animate: island ? island.animationsEnabled : true
                }
            }
        }

        // Seekbar Row
        Item {
            Layout.fillWidth: true
            height: 16

            PlasmaComponents.Label {
                id: tallElapsed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: island ? Utils.mmss(island.mediaPositionSeconds) : "00:00"
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                font.pointSize: 8
            }

            PlasmaComponents.Label {
                id: tallTotal
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: island ? Utils.mmss(island.mediaLengthSeconds) : "00:00"
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                font.pointSize: 8
            }

            Rectangle {
                anchors.left: tallElapsed.right
                anchors.leftMargin: 8
                anchors.right: tallTotal.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.2)

                Rectangle {
                    width: parent.width * (island ? island.mediaProgress : 0)
                    height: parent.height
                    radius: parent.radius
                    color: island ? island.accent : "#3498db"
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: island && island.mediaContainer !== null && island.mediaLengthSeconds > 0
                    onClicked: (mouse) => {
                        if (!island || !island.mediaContainer) return
                        const fraction = Math.max(0, Math.min(1, mouse.x / width))
                        island.mediaContainer.position = Math.round(fraction * island.mediaLength)
                    }
                }
            }
        }

        // Controls Row
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24

            Kirigami.Icon {
                source: "media-skip-backward"
                width: 24; height: 24
                color: island ? island.textPrimary : "white"
                opacity: (island && island.mediaContainer) ? 1 : 0.45
                scale: tallPrevMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: tallPrevMouse
                    anchors.fill: parent
                    onClicked: if (island && island.mediaContainer) island.mediaContainer.Previous()
                }
            }

            Kirigami.Icon {
                source: (island && island.mediaPlaying) ? "media-playback-pause" : "media-playback-start"
                width: 28; height: 28
                color: island ? island.textPrimary : "white"
                opacity: (island && island.mediaContainer) ? 1 : 0.45
                scale: tallPlayMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: tallPlayMouse
                    anchors.fill: parent
                    onClicked: if (island && island.mediaContainer) island.mediaContainer.PlayPause()
                }
            }

            Kirigami.Icon {
                source: "media-skip-forward"
                width: 24; height: 24
                color: island ? island.textPrimary : "white"
                opacity: (island && island.mediaContainer) ? 1 : 0.45
                scale: tallNextMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: tallNextMouse
                    anchors.fill: parent
                    onClicked: if (island && island.mediaContainer) island.mediaContainer.Next()
                }
            }
        }
    }

    // ── Single Row View (2x1, 3x1) ────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: !widget.isMiniPill && !widget.isTallCard

        Item {
            id: artSlotSingle
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44

            Kirigami.ShadowedImage {
                anchors.fill: parent
                visible: island && island.mediaArtUrl !== ""
                source: island ? island.mediaArtUrl : ""
                radius: style ? style.artRadius : 6
            }

            Rectangle {
                anchors.fill: parent
                visible: !island || island.mediaArtUrl === ""
                radius: style ? style.artRadius : 6
                color: Qt.rgba(0.92, 0.94, 0.96, 0.28)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "audio-x-generic"
                    width: 24; height: 24
                    color: island ? island.textPrimary : "white"
                }
            }
        }

        Row {
            id: controlsSingle
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Kirigami.Icon {
                source: "media-skip-backward"
                width: 20; height: 20
                color: island ? island.textPrimary : "white"
                opacity: (island && island.mediaContainer) ? 1 : 0.45
                scale: singlePrevMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                MouseArea { id: singlePrevMouse; anchors.fill: parent; onClicked: if (island && island.mediaContainer) island.mediaContainer.Previous() }
            }

            Kirigami.Icon {
                source: (island && island.mediaPlaying) ? "media-playback-pause" : "media-playback-start"
                width: 24; height: 24
                color: island ? island.textPrimary : "white"
                opacity: (island && island.mediaContainer) ? 1 : 0.45
                scale: singlePlayMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                MouseArea { id: singlePlayMouse; anchors.fill: parent; onClicked: if (island && island.mediaContainer) island.mediaContainer.PlayPause() }
            }

            Kirigami.Icon {
                source: "media-skip-forward"
                width: 20; height: 20
                color: island ? island.textPrimary : "white"
                opacity: (island && island.mediaContainer) ? 1 : 0.45
                scale: singleNextMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                MouseArea { id: singleNextMouse; anchors.fill: parent; onClicked: if (island && island.mediaContainer) island.mediaContainer.Next() }
            }
        }

        Column {
            anchors.left: artSlotSingle.right
            anchors.leftMargin: 10
            anchors.right: controlsSingle.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            ScrollingLabel {
                width: parent.width
                height: implicitHeight
                text: widget.displayTitle
                color: style ? style.titleColor : (island ? island.textPrimary : "white")
                fontSize: style ? style.titleSize : 11.5
                fontWeight: Font.Medium
                animate: island ? island.animationsEnabled : true
            }

            ScrollingLabel {
                width: parent.width
                height: implicitHeight
                text: widget.displayArtist
                color: style ? style.artistColor : (island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7))
                fontSize: style ? style.artistSize : 9.5
                animate: island ? island.animationsEnabled : true
            }
        }
    }

    // ── Mini Pill View (1x1) ──────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: widget.isMiniPill
        radius: 16
        color: (island && island.mediaPlaying) ? Qt.lighter(island.accent || "#3498db", 1.1) : Qt.rgba(1, 1, 1, 0.18)
        border.width: 1
        border.color: (island && island.mediaPlaying) ? Qt.lighter(island.accent || "#3498db", 1.3) : Qt.rgba(1, 1, 1, 0.15)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Kirigami.Icon {
                source: (island && island.mediaPlaying) ? "media-playback-pause" : "media-playback-start"
                width: 18; height: 18
                color: "white"
                scale: pillPlayMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: pillPlayMouse
                    anchors.fill: parent
                    onClicked: if (island && island.mediaContainer) island.mediaContainer.PlayPause()
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: widget.displayTitle
                color: "white"
                font.pointSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }
}
