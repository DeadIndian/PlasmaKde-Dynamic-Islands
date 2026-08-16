import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "../IslandUtils.js" as Utils
import "../Translator.js" as Tr

Item {
    property var island: null

    implicitHeight: 64
    implicitWidth: 340

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        PlasmaComponents.Label {
            text: island.timerTotal > 0 ? Utils.mmss(island.timerRemaining)
                : Tr.tr("%1 min", minutesSpin.value)
            color: island.textPrimary
            font.pointSize: 16
            font.weight: Font.Medium
            Layout.preferredWidth: 92
        }

        QQC2.SpinBox {
            id: minutesSpin
            from: 1
            to: 600
            value: Plasmoid.configuration.timerDefaultMinutes
            enabled: !island.timerRunning
            editable: false
            Layout.preferredWidth: 72
        }

        Item { Layout.fillWidth: true }

        QQC2.Button {
            text: island.timerRunning ? Tr.t("Pause")
                : island.timerTotal > 0 ? Tr.t("Resume") : Tr.t("Start")
            onClicked: {
                if (island.timerRunning) {
                    island.pauseTimer()
                } else if (island.timerTotal > 0) {
                    island.resumeTimer()
                } else {
                    island.startTimer(minutesSpin.value)
                }
            }
        }

        QQC2.Button {
            text: Tr.t("Reset")
            onClicked: island.resetTimer()
        }
    }
}
