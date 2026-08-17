import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    id: widget

    property var island: null
    property int spanW: 1
    property int spanH: 1

    implicitHeight: 48
    implicitWidth: 120

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)

        Column {
            anchors.centerIn: parent
            spacing: 1

            PlasmaComponents.Label {
                id: clockLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: island ? island.timeText : Qt.formatTime(new Date(), "hh:mm")
                color: island ? island.textPrimary : "white"
                font.pointSize: widget.spanW === 1 ? 14 : 16
                font.weight: Font.Bold
            }

            PlasmaComponents.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: widget.spanW >= 2
                text: Qt.formatDate(new Date(), "ddd, MMM d")
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.65)
                font.pointSize: 8.5
            }
        }
    }
}
