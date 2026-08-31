import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import QtQuick.Shapes
import "../IslandUtils.js" as Utils
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int spanW: 2
    property int spanH: 1

    implicitHeight: spanH >= 2 ? 118 : 54
    implicitWidth: spanW * 100

    readonly property bool isMiniPill: false
    readonly property bool isTallCard: spanH >= 2
    property int selectedMinutes: Plasmoid.configuration.timerDefaultMinutes || 25
    property int customMins: 10
    property int customSecs: 0

    // Theme Accent Color (Reverted to Dynamic Island theme)
    readonly property color themeAccent: island ? (island.accent || "#3498db") : "#3498db"

    // Quick presets list (in minutes)
    readonly property var presets: [5, 10, 15, 25, 30]

    function formatPresetLabel(mins) {
        if (mins >= 60) return (mins / 60) + "h"
        return mins + "m"
    }

    // Scroll wheel adjust handler when timer is idle
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (!island || island.timerTotal === 0) {
                var step = wheel.angleDelta.y > 0 ? 1 : -1
                widget.selectedMinutes = Math.max(1, Math.min(180, widget.selectedMinutes + step))
            }
        }
    }

    // ── Full Card View ────────────────────────────────────────────────
    Rectangle {
        id: fullCardRect
        anchors.fill: parent
        visible: !widget.isMiniPill
        radius: 16
        color: (island && island.timerRunning)
            ? Qt.rgba(widget.themeAccent.r, widget.themeAccent.g, widget.themeAccent.b, 0.22)
            : (cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10))
        border.width: 1
        border.color: (island && island.timerRunning)
            ? widget.themeAccent
            : Qt.rgba(1, 1, 1, 0.15)

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
        }

        // Completion Pulse Animation
        SequentialAnimation {
            running: island && island.timerTotal > 0 && island.timerRemaining === 0
            loops: Animation.Infinite
            NumberAnimation { target: fullCardRect; property: "scale"; from: 1.0; to: 1.03; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: fullCardRect; property: "scale"; from: 1.03; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }

        // Single-Row Compact Layout (spanH === 1)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            visible: !widget.isTallCard
            spacing: 6

            // Animated Timer Ring & Icon
            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(1, 1, 1, 0.15)
                        strokeWidth: 2.5
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 15; centerY: 15
                            radiusX: 12; radiusY: 12
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: widget.themeAccent
                        strokeWidth: 2.5
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 15; centerY: 15
                            radiusX: 12; radiusY: 12
                            startAngle: -90
                            sweepAngle: (island && island.timerTotal > 0)
                                ? (island.timerRemaining / island.timerTotal) * 360
                                : 360
                        }
                    }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "chronometer"
                    width: 15; height: 15
                    color: island ? island.textPrimary : "white"
                }
            }

            // Time Readout
            PlasmaComponents.Label {
                text: (island && island.timerTotal > 0)
                    ? Utils.mmss(island.timerRemaining)
                    : Utils.mmss(widget.selectedMinutes * 60)
                color: island ? island.textPrimary : "white"
                font.pointSize: 12.5
                font.weight: Font.Bold
                font.features: {"tnum": 1}
                Layout.alignment: Qt.AlignVCenter
            }

            // Presets pills (shown when idle and spanW >= 2)
            Row {
                spacing: 3
                Layout.alignment: Qt.AlignVCenter
                visible: (!island || island.timerTotal === 0) && widget.spanW >= 2

                Repeater {
                    model: widget.presets
                    delegate: Rectangle {
                        implicitHeight: 20
                        implicitWidth: pLabel.implicitWidth + 8
                        radius: 10
                        color: widget.selectedMinutes === modelData
                            ? widget.themeAccent
                            : (pMouse.pressed ? Qt.rgba(1, 1, 1, 0.24) : (pMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.12)))
                        border.width: 1
                        border.color: widget.selectedMinutes === modelData
                            ? widget.themeAccent
                            : Qt.rgba(1, 1, 1, 0.15)

                        PlasmaComponents.Label {
                            id: pLabel
                            anchors.centerIn: parent
                            text: widget.formatPresetLabel(modelData)
                            color: "white"
                            font.pointSize: 7.5
                            font.weight: widget.selectedMinutes === modelData ? Font.Bold : Font.Medium
                        }

                        MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: widget.selectedMinutes = modelData
                        }
                    }
                }

                // Add Custom Timer (+) Button
                Rectangle {
                    implicitHeight: 20
                    implicitWidth: 20
                    radius: 10
                    color: addMouse.pressed ? Qt.rgba(1, 1, 1, 0.28) : (addMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.14))
                    border.width: 1
                    border.color: widget.themeAccent

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: "+"
                        color: "white"
                        font.pointSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: customTimerPopup.open()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Action Buttons
            Row {
                spacing: 5
                Layout.alignment: Qt.AlignVCenter

                // Reset Button
                Rectangle {
                    implicitHeight: 24
                    implicitWidth: rLabel.implicitWidth + 12
                    radius: 12
                    scale: rMouse.pressed ? 0.94 : 1.0
                    visible: island && (island.timerTotal > 0 || island.timerRunning)
                    color: rMouse.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    PlasmaComponents.Label {
                        id: rLabel
                        anchors.centerIn: parent
                        text: Tr.t("Reset")
                        color: "white"
                        font.pointSize: 8
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: rMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (island) island.resetTimer()
                    }
                }

                // Start / Pause / Resume Button
                Rectangle {
                    implicitHeight: 24
                    implicitWidth: sLabel.implicitWidth + 14
                    radius: 12
                    scale: sMouse.pressed ? 0.94 : 1.0
                    color: sMouse.pressed
                        ? Qt.lighter(widget.themeAccent, 1.2)
                        : widget.themeAccent
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    PlasmaComponents.Label {
                        id: sLabel
                        anchors.centerIn: parent
                        text: (island && island.timerRunning) ? Tr.t("Pause")
                            : (island && island.timerTotal > 0) ? Tr.t("Resume") : Tr.t("Start")
                        color: "white"
                        font.pointSize: 8
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!island) return
                            if (island.timerRunning) {
                                island.pauseTimer()
                            } else if (island.timerTotal > 0) {
                                island.resumeTimer()
                            } else {
                                island.startTimer(widget.selectedMinutes, 0)
                            }
                        }
                    }
                }
            }
        }

        // Tall Card Layout (spanH >= 2) - Designed to fit cleanly without vertical overflow
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            visible: widget.isTallCard
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Timer Ring
                Item {
                    implicitWidth: 36
                    implicitHeight: 36
                    Layout.alignment: Qt.AlignVCenter

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Qt.rgba(1, 1, 1, 0.15)
                            strokeWidth: 3
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 18; centerY: 18
                                radiusX: 15; radiusY: 15
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: widget.themeAccent
                            strokeWidth: 3
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 18; centerY: 18
                                radiusX: 15; radiusY: 15
                                startAngle: -90
                                sweepAngle: (island && island.timerTotal > 0)
                                    ? (island.timerRemaining / island.timerTotal) * 360
                                    : 360
                            }
                        }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "chronometer"
                        width: 18; height: 18
                        color: island ? island.textPrimary : "white"
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    PlasmaComponents.Label {
                        text: (island && island.timerTotal > 0)
                            ? Utils.mmss(island.timerRemaining)
                            : Utils.mmss(widget.selectedMinutes * 60)
                        color: island ? island.textPrimary : "white"
                        font.pointSize: 15
                        font.weight: Font.Bold
                        font.features: {"tnum": 1}
                    }

                    PlasmaComponents.Label {
                        text: (island && island.timerRunning) ? Tr.t("Timer Running")
                            : (island && island.timerTotal > 0) ? Tr.t("Timer Paused") : Tr.t("Select Duration")
                        color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                        font.pointSize: 8
                    }
                }
            }

            // Quick Preset Buttons Grid (Tall view)
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !island || island.timerTotal === 0

                Repeater {
                    model: widget.presets
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: 11
                        color: widget.selectedMinutes === modelData
                            ? widget.themeAccent
                            : (tpMouse.pressed ? Qt.rgba(1, 1, 1, 0.24) : (tpMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.12)))
                        border.width: 1
                        border.color: widget.selectedMinutes === modelData
                            ? widget.themeAccent
                            : Qt.rgba(1, 1, 1, 0.15)

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: widget.formatPresetLabel(modelData)
                            color: "white"
                            font.pointSize: 8
                            font.weight: widget.selectedMinutes === modelData ? Font.Bold : Font.Medium
                        }

                        MouseArea {
                            id: tpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: widget.selectedMinutes = modelData
                        }
                    }
                }

                // Add Custom Timer (+) Button
                Rectangle {
                    implicitHeight: 22
                    implicitWidth: 26
                    radius: 11
                    color: tpAddMouse.pressed ? Qt.rgba(1, 1, 1, 0.28) : (tpAddMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.14))
                    border.width: 1
                    border.color: widget.themeAccent

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: "+"
                        color: "white"
                        font.pointSize: 9.5
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: tpAddMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: customTimerPopup.open()
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons Row (Tall view)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 26
                    radius: 13
                    scale: trMouse.pressed ? 0.94 : 1.0
                    visible: island && (island.timerTotal > 0 || island.timerRunning)
                    color: trMouse.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: Tr.t("Reset")
                        color: "white"
                        font.pointSize: 8.5
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: trMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (island) island.resetTimer()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 26
                    radius: 13
                    scale: tsMouse.pressed ? 0.94 : 1.0
                    color: tsMouse.pressed
                        ? Qt.lighter(widget.themeAccent, 1.2)
                        : widget.themeAccent
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: (island && island.timerRunning) ? Tr.t("Pause")
                            : (island && island.timerTotal > 0) ? Tr.t("Resume") : Tr.t("Start Timer")
                        color: "white"
                        font.pointSize: 8.5
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: tsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!island) return
                            if (island.timerRunning) {
                                island.pauseTimer()
                            } else if (island.timerTotal > 0) {
                                island.resumeTimer()
                            } else {
                                island.startTimer(widget.selectedMinutes, 0)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Compact Pill View (spanW === 1 && spanH === 1) ───────────────
    Rectangle {
        anchors.fill: parent
        visible: widget.isMiniPill
        radius: 16
        color: (island && island.timerRunning)
            ? widget.themeAccent
            : (miniMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.12))
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        scale: miniMouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Kirigami.Icon {
                source: "chronometer"
                width: 16; height: 16
                color: "white"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: (island && island.timerTotal > 0) ? Utils.mmss(island.timerRemaining) : Tr.t("Timer")
                color: "white"
                font.pointSize: 9
                font.weight: Font.DemiBold
                font.features: {"tnum": 1}
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: miniMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (!island) return
                if (island.timerRunning) island.pauseTimer()
                else if (island.timerTotal > 0) island.resumeTimer()
                else island.startTimer(widget.selectedMinutes, 0)
            }
        }
    }

    // ── Custom Timer Sub-Popup ───────────────────────────────────────
    QQC2.Popup {
        id: customTimerPopup
        parent: widget
        x: Math.round((widget.width - width) / 2)
        y: Math.round((widget.height - height) / 2)
        width: Math.min(widget.width - 12, 230)
        implicitHeight: 110
        modal: true
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        background: Rectangle {
            color: island ? (island.cardBg || "#1e222b") : "#1e222b"
            radius: 14
            border.width: 1.5
            border.color: widget.themeAccent
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            PlasmaComponents.Label {
                text: Tr.t("Set Custom Timer")
                color: island ? island.textPrimary : "white"
                font.pointSize: 9
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            // Minutes & Seconds Adjusters Row
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                // Minutes adjuster
                Row {
                    spacing: 3
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: Qt.rgba(1, 1, 1, 0.15)
                        PlasmaComponents.Label { anchors.centerIn: parent; text: "−"; color: "white"; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: widget.customMins = Math.max(0, widget.customMins - 1) }
                    }

                    PlasmaComponents.Label {
                        text: widget.customMins + "m"
                        color: "white"
                        font.pointSize: 10
                        font.weight: Font.Bold
                        font.features: {"tnum": 1}
                        width: 32
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: Qt.rgba(1, 1, 1, 0.15)
                        PlasmaComponents.Label { anchors.centerIn: parent; text: "+"; color: "white"; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: widget.customMins = Math.min(180, widget.customMins + 1) }
                    }
                }

                // Seconds adjuster
                Row {
                    spacing: 3
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: Qt.rgba(1, 1, 1, 0.15)
                        PlasmaComponents.Label { anchors.centerIn: parent; text: "−"; color: "white"; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: widget.customSecs = Math.max(0, widget.customSecs - 5) }
                    }

                    PlasmaComponents.Label {
                        text: widget.customSecs + "s"
                        color: "white"
                        font.pointSize: 10
                        font.weight: Font.Bold
                        font.features: {"tnum": 1}
                        width: 30
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: Qt.rgba(1, 1, 1, 0.15)
                        PlasmaComponents.Label { anchors.centerIn: parent; text: "+"; color: "white"; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: widget.customSecs = Math.min(59, widget.customSecs + 5) }
                    }
                }
            }

            // Sub-popup Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    PlasmaComponents.Label { anchors.centerIn: parent; text: Tr.t("Cancel"); color: "white"; font.pointSize: 8 }
                    MouseArea { anchors.fill: parent; onClicked: customTimerPopup.close() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 12
                    color: widget.themeAccent
                    PlasmaComponents.Label { anchors.centerIn: parent; text: Tr.t("Start Timer"); color: "white"; font.pointSize: 8; font.weight: Font.Bold }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            widget.selectedMinutes = widget.customMins
                            if (island) {
                                island.startTimer(widget.customMins, widget.customSecs)
                            }
                            customTimerPopup.close()
                        }
                    }
                }
            }
        }
    }
}
