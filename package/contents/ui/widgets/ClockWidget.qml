import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    property var island: null

    implicitHeight: 56
    implicitWidth: Math.max(180, clockLabel.implicitWidth + 40)

    PlasmaComponents.Label {
        id: clockLabel
        anchors.centerIn: parent
        text: island.timeText
        color: island.textPrimary
        font.pointSize: Plasmoid.configuration.widgetClockSize
        font.weight: Font.Medium
    }
}
