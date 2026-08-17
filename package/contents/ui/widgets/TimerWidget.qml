import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "../IslandUtils.js" as Utils
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int spanW: 2
    property int spanH: 1

    implicitHeight: spanH >= 2 ? 96 : 48
    implicitWidth: spanW * 100

    readonly property bool isMiniPill: spanW === 1 && spanH === 1

    // Quick presets list (in minutes)
    readonly property var presets: [1, 5, 10, 15, 25, 30]

    // Full / Expanded View
    Rectangle {
        anchors.fill: parent
        visible: !widget.isMiniPill
        radius: 16
        color: (island && island.timerRunning) ? Qt.rgba(0.2, 0.4, 0.8, 0.25) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: (island && island.timerRunning) ? (island.accent || "#3498db") : Qt.rgba(1, 1, 1, 0.15)

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Kirigami.Icon {
                    source: "chronometer"
                    width: 20
                    height: 20
                    color: island ? island.textPrimary : "white"
                }

                PlasmaComponents.Label {
                    text: (island && island.timerTotal > 0)
                        ? Utils.mmss(island.timerRemaining)
                        : Utils.mmss((minutesSpin.value * 60) + secondsSpin.value)
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 13
                    font.weight: Font.Bold
                    Layout.preferredWidth: 70
                }

                // Min & Sec SpinBoxes (editable when timer is not running)
                RowLayout {
                    spacing: 4
                    visible: !island || island.timerTotal === 0

                    QQC2.SpinBox {
                        id: minutesSpin
                        from: 0
                        to: 600
                        value: Plasmoid.configuration.timerDefaultMinutes
                        enabled: island ? !island.timerRunning : true
                        editable: false
                        implicitWidth: 56
                        implicitHeight: 26
                    }
                    PlasmaComponents.Label {
                        text: Tr.t("m")
                        color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                        font.pointSize: 8.5
                    }

                    QQC2.SpinBox {
                        id: secondsSpin
                        from: 0
                        to: 59
                        stepSize: 5
                        value: Plasmoid.configuration.timerDefaultSeconds || 0
                        enabled: island ? !island.timerRunning : true
                        editable: false
                        implicitWidth: 56
                        implicitHeight: 26
                    }
                    PlasmaComponents.Label {
                        text: Tr.t("s")
                        color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                        font.pointSize: 8.5
                    }
                }

                Item { Layout.fillWidth: true }

                // Action Button: Start / Pause / Resume
                Rectangle {
                    implicitHeight: 26
                    implicitWidth: startLabel.implicitWidth + 16
                    radius: 13
                    color: startMouse.pressed
                        ? (island ? Qt.lighter(island.accent, 1.15) : "#2980b9")
                        : (island ? island.accent : "#3498db")

                    PlasmaComponents.Label {
                        id: startLabel
                        anchors.centerIn: parent
                        text: (island && island.timerRunning) ? Tr.t("Pause")
                            : (island && island.timerTotal > 0) ? Tr.t("Resume") : Tr.t("Start")
                        color: "white"
                        font.pointSize: 8.5
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: startMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!island) return
                            if (island.timerRunning) {
                                island.pauseTimer()
                            } else if (island.timerTotal > 0) {
                                island.resumeTimer()
                            } else {
                                island.startTimer(minutesSpin.value, secondsSpin.value)
                            }
                        }
                    }
                }

                // Action Button: Reset
                Rectangle {
                    implicitHeight: 26
                    implicitWidth: resetLabel.implicitWidth + 14
                    radius: 13
                    visible: island && (island.timerTotal > 0 || island.timerRunning)
                    color: resetMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)

                    PlasmaComponents.Label {
                        id: resetLabel
                        anchors.centerIn: parent
                        text: Tr.t("Reset")
                        color: island ? island.textPrimary : "white"
                        font.pointSize: 8.5
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (island) island.resetTimer()
                    }
                }
            }

            // Quick Preset Buttons Row (shown when idle)
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                visible: (!island || island.timerTotal === 0) && (widget.spanW >= 3 || widget.spanH >= 2)

                PlasmaComponents.Label {
                    text: Tr.t("Quick:")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                    font.pointSize: 8
                    Layout.alignment: Qt.AlignVCenter
                }

                Repeater {
                    model: widget.presets
                    delegate: Rectangle {
                        implicitHeight: 20
                        implicitWidth: presetLabel.implicitWidth + 10
                        radius: 10
                        color: presetMouse.pressed
                            ? Qt.rgba(1, 1, 1, 0.28)
                            : presetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        border.color: (minutesSpin.value === modelData && secondsSpin.value === 0)
                            ? (island ? island.accent : "#3498db")
                            : Qt.rgba(1, 1, 1, 0.15)

                        PlasmaComponents.Label {
                            id: presetLabel
                            anchors.centerIn: parent
                            text: modelData + "m"
                            color: island ? island.textPrimary : "white"
                            font.pointSize: 8
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                minutesSpin.value = modelData
                                secondsSpin.value = 0
                                if (island) {
                                    island.startTimer(modelData, 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Compact pill view (spanW === 1)
    Rectangle {
        anchors.fill: parent
        visible: widget.isMiniPill
        radius: 16
        color: (island && island.timerRunning) ? (island.accent || "#3498db") : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Kirigami.Icon {
                source: "chronometer"
                width: 18; height: 18
                color: "white"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: (island && island.timerTotal > 0) ? Utils.mmss(island.timerRemaining) : Tr.t("Timer")
                color: "white"
                font.pointSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!island) return
                if (island.timerRunning) island.pauseTimer()
                else if (island.timerTotal > 0) island.resumeTimer()
                else island.startTimer(Plasmoid.configuration.timerDefaultMinutes, Plasmoid.configuration.timerDefaultSeconds || 0)
            }
        }
    }
}
