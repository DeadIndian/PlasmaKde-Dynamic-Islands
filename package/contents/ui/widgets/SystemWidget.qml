import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int spanW: 3
    property int spanH: 1

    readonly property bool isMiniCol: spanW === 1
    readonly property bool isTallCard: spanH >= 2

    readonly property bool showCpu: island ? island.showCpuStat : true
    readonly property bool showRam: island ? island.showRamStat : true
    readonly property bool showTemp: island ? (island.showTempStat && island.cpuTemp > 0) : false

    readonly property string sysStyle: island ? island.sysMonitorStyle : "lines"
    readonly property color themeAccent: island ? (island.accent || "#3498db") : "#3498db"

    readonly property int activeCount: (showCpu ? 1 : 0) + (showRam ? 1 : 0) + (showTemp ? 1 : 0)

    // Dynamically calculate maximum circle diameter that fills available card real estate!
    readonly property real dynamicRingDiameter: {
        let count = Math.max(1, activeCount)
        let availW = (width - 16 - (count - 1) * 8) / count
        let availH = height - 20 // Space for label below
        let sz = Math.min(availW, availH)
        return Math.max(26, Math.min(68, sz))
    }

    readonly property real dynamicRingRadius: dynamicRingDiameter / 2.0
    readonly property real dynamicStroke: Math.max(2.5, dynamicRingDiameter * 0.08)
    readonly property real dynamicArcRadius: Math.max(8, dynamicRingRadius - dynamicStroke)
    readonly property real dynamicValFontSize: Math.max(7.0, Math.min(13.0, dynamicRingDiameter * 0.24))
    readonly property real dynamicLabelFontSize: Math.max(7.0, Math.min(10.0, dynamicRingDiameter * 0.22))

    implicitHeight: isTallCard ? 118 : 54
    implicitWidth: spanW * 100

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: systemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
        scale: systemMouse.pressed ? 0.97 : 1.0
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        MouseArea {
            id: systemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        // ── Mode 1: Horizontal Progress Bars (lines) ────────────────────
        Column {
            anchors.left: parent.left
            anchors.leftMargin: widget.isMiniCol ? 6 : 10
            anchors.right: parent.right
            anchors.rightMargin: widget.isMiniCol ? 6 : 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: widget.isTallCard ? 8 : (widget.isMiniCol ? 3 : 4)
            visible: widget.sysStyle === "lines"

            // CPU Row
            RowLayout {
                width: parent.width
                spacing: widget.isMiniCol ? 4 : 6
                visible: widget.showCpu

                PlasmaComponents.Label {
                    text: widget.isMiniCol ? "CP" : Tr.t("CPU")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: widget.dynamicLabelFontSize
                    font.bold: true
                    Layout.preferredWidth: widget.isMiniCol ? 16 : 28
                }

                PlasmaComponents.Label {
                    text: island ? Math.round(island.cpuUsage) + "%" : "0%"
                    color: island ? island.textPrimary : "white"
                    font.pointSize: widget.dynamicLabelFontSize
                    font.weight: Font.Medium
                    Layout.preferredWidth: widget.isMiniCol ? 24 : 32
                    horizontalAlignment: Text.AlignRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)

                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, island ? island.cpuUsage / 100 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: widget.themeAccent

                        Behavior on width {
                            NumberAnimation { duration: island ? island.dur(240) : 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            // RAM Row
            RowLayout {
                width: parent.width
                spacing: widget.isMiniCol ? 4 : 6
                visible: widget.showRam

                PlasmaComponents.Label {
                    text: widget.isMiniCol ? "RM" : Tr.t("RAM")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: widget.dynamicLabelFontSize
                    font.bold: true
                    Layout.preferredWidth: widget.isMiniCol ? 16 : 28
                }

                PlasmaComponents.Label {
                    text: island ? Math.round(island.ramUsage) + "%" : "0%"
                    color: island ? island.textPrimary : "white"
                    font.pointSize: widget.dynamicLabelFontSize
                    font.weight: Font.Medium
                    Layout.preferredWidth: widget.isMiniCol ? 24 : 32
                    horizontalAlignment: Text.AlignRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)

                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, island ? island.ramUsage / 100 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: widget.themeAccent

                        Behavior on width {
                            NumberAnimation { duration: island ? island.dur(240) : 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            // TEMP Row
            RowLayout {
                width: parent.width
                spacing: widget.isMiniCol ? 4 : 6
                visible: widget.showTemp

                PlasmaComponents.Label {
                    text: widget.isMiniCol ? "TP" : Tr.t("TEMP")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: widget.dynamicLabelFontSize
                    font.bold: true
                    Layout.preferredWidth: widget.isMiniCol ? 16 : 28
                }

                PlasmaComponents.Label {
                    text: island ? Math.round(island.cpuTemp) + "°" : "0°"
                    color: island ? island.textPrimary : "white"
                    font.pointSize: widget.dynamicLabelFontSize
                    font.weight: Font.Medium
                    Layout.preferredWidth: widget.isMiniCol ? 24 : 32
                    horizontalAlignment: Text.AlignRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)

                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, island ? island.cpuTemp / 100 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: (island && island.cpuTemp > 80) ? "#e74c3c"
                            : (island && island.cpuTemp > 65) ? "#f39c12"
                            : widget.themeAccent

                        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on width {
                            NumberAnimation { duration: island ? island.dur(240) : 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // ── Mode 2: Donut / Pie Charts (donuts) ─────────────────────────
        RowLayout {
            anchors.centerIn: parent
            spacing: Math.max(6, Math.min(24, (parent.width - widget.dynamicRingDiameter * widget.activeCount) / Math.max(1, widget.activeCount + 1)))
            visible: widget.sysStyle === "donuts"

            // CPU Donut
            Column {
                spacing: 2
                visible: widget.showCpu
                Layout.alignment: Qt.AlignVCenter

                Item {
                    implicitWidth: widget.dynamicRingDiameter
                    implicitHeight: widget.dynamicRingDiameter
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Qt.rgba(1, 1, 1, 0.15)
                            strokeWidth: widget.dynamicStroke
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: widget.dynamicRingRadius; centerY: widget.dynamicRingRadius
                                radiusX: widget.dynamicArcRadius; radiusY: widget.dynamicArcRadius
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: widget.themeAccent
                            strokeWidth: widget.dynamicStroke
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: widget.dynamicRingRadius; centerY: widget.dynamicRingRadius
                                radiusX: widget.dynamicArcRadius; radiusY: widget.dynamicArcRadius
                                startAngle: -90
                                sweepAngle: Math.min(360, Math.max(0, (island ? island.cpuUsage : 0) * 3.6))
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: island ? Math.round(island.cpuUsage) + "%" : "0%"
                        font.pointSize: widget.dynamicValFontSize
                        font.weight: Font.Bold
                        color: "white"
                    }
                }

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("CPU")
                    font.pointSize: widget.dynamicLabelFontSize
                    font.weight: Font.Medium
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                }
            }

            // RAM Donut
            Column {
                spacing: 2
                visible: widget.showRam
                Layout.alignment: Qt.AlignVCenter

                Item {
                    implicitWidth: widget.dynamicRingDiameter
                    implicitHeight: widget.dynamicRingDiameter
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Qt.rgba(1, 1, 1, 0.15)
                            strokeWidth: widget.dynamicStroke
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: widget.dynamicRingRadius; centerY: widget.dynamicRingRadius
                                radiusX: widget.dynamicArcRadius; radiusY: widget.dynamicArcRadius
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: widget.themeAccent
                            strokeWidth: widget.dynamicStroke
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: widget.dynamicRingRadius; centerY: widget.dynamicRingRadius
                                radiusX: widget.dynamicArcRadius; radiusY: widget.dynamicArcRadius
                                startAngle: -90
                                sweepAngle: Math.min(360, Math.max(0, (island ? island.ramUsage : 0) * 3.6))
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: island ? Math.round(island.ramUsage) + "%" : "0%"
                        font.pointSize: widget.dynamicValFontSize
                        font.weight: Font.Bold
                        color: "white"
                    }
                }

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("RAM")
                    font.pointSize: widget.dynamicLabelFontSize
                    font.weight: Font.Medium
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                }
            }

            // TEMP Donut
            Column {
                spacing: 2
                visible: widget.showTemp
                Layout.alignment: Qt.AlignVCenter

                Item {
                    implicitWidth: widget.dynamicRingDiameter
                    implicitHeight: widget.dynamicRingDiameter
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Qt.rgba(1, 1, 1, 0.15)
                            strokeWidth: widget.dynamicStroke
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: widget.dynamicRingRadius; centerY: widget.dynamicRingRadius
                                radiusX: widget.dynamicArcRadius; radiusY: widget.dynamicArcRadius
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: (island && island.cpuTemp > 80) ? "#e74c3c"
                                : (island && island.cpuTemp > 65) ? "#f39c12" : widget.themeAccent
                            strokeWidth: widget.dynamicStroke
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: widget.dynamicRingRadius; centerY: widget.dynamicRingRadius
                                radiusX: widget.dynamicArcRadius; radiusY: widget.dynamicArcRadius
                                startAngle: -90
                                sweepAngle: Math.min(360, Math.max(0, (island ? island.cpuTemp : 0) * 3.6))
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: island ? Math.round(island.cpuTemp) + "°" : "0°"
                        font.pointSize: widget.dynamicValFontSize
                        font.weight: Font.Bold
                        color: "white"
                    }
                }

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("TEMP")
                    font.pointSize: widget.dynamicLabelFontSize
                    font.weight: Font.Medium
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                }
            }
        }

        // ── Mode 3: Compact Glass Pills (badges) ────────────────────────
        RowLayout {
            anchors.centerIn: parent
            spacing: widget.isMiniCol ? 3 : (widget.spanW === 2 ? 5 : 8)
            visible: widget.sysStyle === "badges"

            // CPU Badge
            Rectangle {
                implicitHeight: widget.isMiniCol ? 20 : 24
                implicitWidth: cpuBadgeLabel.implicitWidth + (widget.isMiniCol ? 10 : 16)
                radius: implicitHeight / 2
                visible: widget.showCpu
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle { width: 5; height: 5; radius: 2.5; color: widget.themeAccent; anchors.verticalCenter: parent.verticalCenter }
                    PlasmaComponents.Label {
                        id: cpuBadgeLabel
                        text: (widget.isMiniCol ? "C " : "CPU ") + (island ? Math.round(island.cpuUsage) + "%" : "0%")
                        color: "white"
                        font.pointSize: widget.dynamicLabelFontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // RAM Badge
            Rectangle {
                implicitHeight: widget.isMiniCol ? 20 : 24
                implicitWidth: ramBadgeLabel.implicitWidth + (widget.isMiniCol ? 10 : 16)
                radius: implicitHeight / 2
                visible: widget.showRam
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle { width: 5; height: 5; radius: 2.5; color: widget.themeAccent; anchors.verticalCenter: parent.verticalCenter }
                    PlasmaComponents.Label {
                        id: ramBadgeLabel
                        text: (widget.isMiniCol ? "R " : "RAM ") + (island ? Math.round(island.ramUsage) + "%" : "0%")
                        color: "white"
                        font.pointSize: widget.dynamicLabelFontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // TEMP Badge
            Rectangle {
                implicitHeight: widget.isMiniCol ? 20 : 24
                implicitWidth: tempBadgeLabel.implicitWidth + (widget.isMiniCol ? 10 : 16)
                radius: implicitHeight / 2
                visible: widget.showTemp
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: (island && island.cpuTemp > 80) ? "#e74c3c" : ((island && island.cpuTemp > 65) ? "#f39c12" : widget.themeAccent)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PlasmaComponents.Label {
                        id: tempBadgeLabel
                        text: (widget.isMiniCol ? "T " : "TEMP ") + (island ? Math.round(island.cpuTemp) + "°" : "0°")
                        color: "white"
                        font.pointSize: widget.dynamicLabelFontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── Mode 4: Mini Stat Grid Cards (cards) ─────────────────────────
        RowLayout {
            anchors.fill: parent
            anchors.margins: widget.isMiniCol ? 4 : 6
            spacing: widget.isMiniCol ? 3 : 5
            visible: widget.sysStyle === "cards"

            // CPU Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                visible: widget.showCpu
                color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: widget.isMiniCol ? 4 : 5
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: widget.isMiniCol ? "C" : "CPU"
                            font.pointSize: widget.dynamicLabelFontSize
                            color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 4; height: 4; radius: 2; color: widget.themeAccent }
                    }

                    PlasmaComponents.Label {
                        text: island ? Math.round(island.cpuUsage) + "%" : "0%"
                        font.pointSize: widget.dynamicValFontSize + 1
                        font.weight: Font.Bold
                        color: "white"
                    }
                }
            }

            // RAM Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                visible: widget.showRam
                color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: widget.isMiniCol ? 4 : 5
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: widget.isMiniCol ? "R" : "RAM"
                            font.pointSize: widget.dynamicLabelFontSize
                            color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 4; height: 4; radius: 2; color: widget.themeAccent }
                    }

                    PlasmaComponents.Label {
                        text: island ? Math.round(island.ramUsage) + "%" : "0%"
                        font.pointSize: widget.dynamicValFontSize + 1
                        font.weight: Font.Bold
                        color: "white"
                    }
                }
            }

            // TEMP Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                visible: widget.showTemp
                color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: widget.isMiniCol ? 4 : 5
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: widget.isMiniCol ? "T" : "TEMP"
                            font.pointSize: widget.dynamicLabelFontSize
                            color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 4; height: 4; radius: 2; color: (island && island.cpuTemp > 80) ? "#e74c3c" : widget.themeAccent }
                    }

                    PlasmaComponents.Label {
                        text: island ? Math.round(island.cpuTemp) + "°" : "0°"
                        font.pointSize: widget.dynamicValFontSize + 1
                        font.weight: Font.Bold
                        color: "white"
                    }
                }
            }
        }
    }
}
