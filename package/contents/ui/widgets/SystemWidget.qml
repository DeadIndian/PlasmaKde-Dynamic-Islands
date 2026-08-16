import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    property var island: null

    implicitHeight: 96
    implicitWidth: 360

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        RowLayout {
            visible: island.showCpuStat
            spacing: 10

            PlasmaComponents.Label { text: Tr.t("CPU"); color: island.textSecondary; font.pointSize: 10; Layout.preferredWidth: 36 }
            PlasmaComponents.Label { text: Math.round(island.cpuUsage) + "%"; color: island.textPrimary; font.pointSize: 11; Layout.preferredWidth: 42 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: parent.width * Math.min(1, island.cpuUsage / 100)
                    height: parent.height
                    radius: parent.radius
                    color: island.accent
                }
            }
        }

        RowLayout {
            visible: island.showRamStat
            spacing: 10

            PlasmaComponents.Label { text: Tr.t("RAM"); color: island.textSecondary; font.pointSize: 10; Layout.preferredWidth: 36 }
            PlasmaComponents.Label { text: Math.round(island.ramUsage) + "%"; color: island.textPrimary; font.pointSize: 11; Layout.preferredWidth: 42 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: parent.width * Math.min(1, island.ramUsage / 100)
                    height: parent.height
                    radius: parent.radius
                    color: island.accent
                }
            }
        }

        RowLayout {
            visible: island.showTempStat && island.cpuTemp > 0
            spacing: 10

            PlasmaComponents.Label { text: Tr.t("TEMP"); color: island.textSecondary; font.pointSize: 10; Layout.preferredWidth: 36 }
            PlasmaComponents.Label { text: Math.round(island.cpuTemp) + "°C"; color: island.textPrimary; font.pointSize: 11; Layout.preferredWidth: 42 }
        }
    }
}
