import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int span: 3

    readonly property bool showCpu: island ? island.showCpuStat : true
    readonly property bool showRam: island ? island.showRamStat : true
    readonly property bool showTemp: island ? (island.showTempStat && island.cpuTemp > 0) : false

    implicitHeight: widget.span === 1 ? 64 : 72
    implicitWidth: 360

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // CPU Row
            RowLayout {
                width: parent.width
                spacing: 8
                visible: widget.showCpu

                PlasmaComponents.Label {
                    text: Tr.t("CPU")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: 8.5
                    font.bold: true
                    Layout.preferredWidth: 32
                }

                PlasmaComponents.Label {
                    text: island ? Math.round(island.cpuUsage) + "%" : "0%"
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 8.5
                    font.weight: Font.Medium
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.16)

                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, island ? island.cpuUsage / 100 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: island ? island.accent : "#3498db"

                        Behavior on width {
                            NumberAnimation {
                                duration: island ? island.dur(240) : 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // RAM Row
            RowLayout {
                width: parent.width
                spacing: 8
                visible: widget.showRam

                PlasmaComponents.Label {
                    text: Tr.t("RAM")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: 8.5
                    font.bold: true
                    Layout.preferredWidth: 32
                }

                PlasmaComponents.Label {
                    text: island ? Math.round(island.ramUsage) + "%" : "0%"
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 8.5
                    font.weight: Font.Medium
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.16)

                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, island ? island.ramUsage / 100 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: island ? island.accent : "#3498db"

                        Behavior on width {
                            NumberAnimation {
                                duration: island ? island.dur(240) : 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // TEMP Row
            RowLayout {
                width: parent.width
                spacing: 8
                visible: widget.showTemp

                PlasmaComponents.Label {
                    text: Tr.t("TEMP")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: 8.5
                    font.bold: true
                    Layout.preferredWidth: 32
                }

                PlasmaComponents.Label {
                    text: island ? Math.round(island.cpuTemp) + "°C" : "0°C"
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 8.5
                    font.weight: Font.Medium
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.16)

                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, island ? island.cpuTemp / 100 : 0))
                        height: parent.height
                        radius: parent.radius
                        color: (island && island.cpuTemp > 80) ? "#e74c3c"
                            : (island && island.cpuTemp > 65) ? "#f39c12"
                            : (island ? island.accent : "#3498db")

                        Behavior on width {
                            NumberAnimation {
                                duration: island ? island.dur(240) : 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
