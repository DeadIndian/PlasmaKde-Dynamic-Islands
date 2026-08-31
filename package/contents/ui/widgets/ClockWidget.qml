import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    id: widget

    property var island: null
    property int spanW: 1
    property int spanH: 1

    implicitHeight: spanH >= 2 ? 118 : 48
    implicitWidth: spanW * 100

    readonly property bool showDate: Plasmoid.configuration.showDate !== undefined ? Plasmoid.configuration.showDate : true
    readonly property string datePos: Plasmoid.configuration.clockDatePosition || "below"

    readonly property string timeStr: island ? island.timeOnlyText : Qt.formatTime(new Date(), Plasmoid.configuration.use24HourClock ? "HH:mm" : "h:mm")
    readonly property string dateStr: island ? island.dateText : Qt.formatDate(new Date(), "ddd, MMM d")

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.12)
        scale: hoverArea.pressed ? 0.97 : 1.0
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        // Layout for vertical (below / above)
        Column {
            anchors.centerIn: parent
            spacing: 1
            visible: !widget.showDate || widget.datePos === "below" || widget.datePos === "above"

            // Date ABOVE
            PlasmaComponents.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: widget.showDate && widget.datePos === "above"
                text: widget.dateStr
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.65)
                font.pointSize: widget.spanW === 1 ? 7.5 : 8.5
            }

            // Time
            PlasmaComponents.Label {
                id: clockLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: widget.timeStr
                color: island ? island.textPrimary : "white"
                font.pointSize: widget.spanW === 1 ? 12.5 : (widget.spanH >= 2 ? 18 : 15)
                font.weight: Font.Bold
                font.features: {"tnum": 1}
            }

            // Date BELOW
            PlasmaComponents.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: widget.showDate && widget.datePos === "below"
                text: widget.dateStr
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.65)
                font.pointSize: widget.spanW === 1 ? 7.5 : 8.5
            }
        }

        // Layout for horizontal (beside_left / beside_right)
        Row {
            anchors.centerIn: parent
            spacing: widget.spanW === 1 ? 3 : 6
            visible: widget.showDate && (widget.datePos === "beside_left" || widget.datePos === "beside_right")

            // Date (beside_left)
            PlasmaComponents.Label {
                visible: widget.datePos === "beside_left"
                text: widget.dateStr
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.65)
                font.pointSize: widget.spanW === 1 ? 7.5 : 9.0
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            // Time
            PlasmaComponents.Label {
                text: widget.timeStr
                color: island ? island.textPrimary : "white"
                font.pointSize: widget.spanW === 1 ? 11.5 : (widget.spanH >= 2 ? 17 : 14)
                font.weight: Font.Bold
                font.features: {"tnum": 1}
                anchors.verticalCenter: parent.verticalCenter
            }

            // Date (beside_right)
            PlasmaComponents.Label {
                visible: widget.datePos === "beside_right"
                text: widget.dateStr
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.65)
                font.pointSize: widget.spanW === 1 ? 7.5 : 9.0
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
