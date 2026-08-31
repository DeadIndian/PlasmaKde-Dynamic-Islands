import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property int spanW: 3
    property int spanH: 1

    implicitHeight: spanH >= 2 ? 160 : 54
    implicitWidth: spanW * 100

    readonly property bool isTallCard: spanH >= 2

    readonly property var srcModel: island ? island.notifModel : null
    readonly property int notifCount: srcModel ? srcModel.count : 0

    // Theme Accent
    readonly property color themeAccent: island ? (island.accent || "#3498db") : "#3498db"

    Rectangle {
        id: fullCardRect
        anchors.fill: parent
        radius: 16
        color: cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        border.color: widget.notifCount > 0 ? widget.themeAccent : Qt.rgba(1, 1, 1, 0.15)

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
        }

        // Single-row card: no room for a list, so only a header + one preview line.
        // The card's height comes from the grid span, not from this item, so an
        // in-card "expand" toggle can't buy the list any space — resize to 3x2+
        // in edit mode to get the full list.
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            visible: !widget.isTallCard
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Kirigami.Icon {
                    source: "notifications"
                    width: 20; height: 20
                    color: island ? island.textPrimary : "white"
                }

                PlasmaComponents.Label {
                    text: Tr.t("Notifications")
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 10
                    font.weight: Font.Bold
                }

                // Count Badge
                Rectangle {
                    implicitHeight: 18
                    implicitWidth: countLabel.implicitWidth + 10
                    radius: 9
                    color: widget.notifCount > 0 ? widget.themeAccent : Qt.rgba(1, 1, 1, 0.15)

                    PlasmaComponents.Label {
                        id: countLabel
                        anchors.centerIn: parent
                        text: widget.notifCount
                        color: "white"
                        font.pointSize: 7.5
                        font.weight: Font.Bold
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear All Button (when notifCount > 0)
                Rectangle {
                    implicitHeight: 22
                    implicitWidth: clearLabel.implicitWidth + 10
                    radius: 11
                    visible: widget.notifCount > 0
                    color: clearMouse.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)

                    PlasmaComponents.Label {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: Tr.t("Clear All")
                        color: "white"
                        font.pointSize: 7.5
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (island) island.clearAllNotifications()
                    }
                }

            }

            // Preview line when collapsed
            PlasmaComponents.Label {
                Layout.fillWidth: true
                // notificationTitle only tracks alerts seen since login, so fall
                // back to a plain count for history carried over from before.
                text: widget.notifCount === 0
                    ? Tr.t("No new notifications")
                    : (island && island.notificationTitle
                        ? (island.notificationTitle + (island.notificationBody ? (" — " + island.notificationBody) : ""))
                        : Tr.tr("%1 notifications", widget.notifCount))
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.6)
                font.pointSize: 8.5
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Tall card (spanH >= 2): full scrollable list
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            visible: widget.isTallCard
            spacing: 8

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Kirigami.Icon {
                    source: "notifications"
                    width: 20; height: 20
                    color: island ? island.textPrimary : "white"
                }

                PlasmaComponents.Label {
                    text: Tr.t("Notifications Center")
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 10.5
                    font.weight: Font.Bold
                }

                Rectangle {
                    implicitHeight: 18
                    implicitWidth: tCountLabel.implicitWidth + 10
                    radius: 9
                    color: widget.notifCount > 0 ? widget.themeAccent : Qt.rgba(1, 1, 1, 0.15)

                    PlasmaComponents.Label {
                        id: tCountLabel
                        anchors.centerIn: parent
                        text: widget.notifCount
                        color: "white"
                        font.pointSize: 7.5
                        font.weight: Font.Bold
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear All Button
                Rectangle {
                    implicitHeight: 24
                    implicitWidth: tClearLabel.implicitWidth + 12
                    radius: 12
                    visible: widget.notifCount > 0
                    color: tClearMouse.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)

                    PlasmaComponents.Label {
                        id: tClearLabel
                        anchors.centerIn: parent
                        text: Tr.t("Clear All")
                        color: "white"
                        font.pointSize: 8
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: tClearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (island) island.clearAllNotifications()
                    }
                }

            }

            // Notification List View
            Flickable {
                id: notifFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: notifColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: notifColumn
                    width: notifFlick.width
                    spacing: 6

                    // Empty State
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: widget.notifCount === 0
                        spacing: 4

                        Kirigami.Icon {
                            source: "notifications-disabled"
                            width: 28; height: 28
                            opacity: 0.4
                            Layout.alignment: Qt.AlignHCenter
                            color: "white"
                        }

                        PlasmaComponents.Label {
                            text: Tr.t("No notifications right now")
                            color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.5)
                            font.pointSize: 8.5
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Active Notification Items
                    Repeater {
                        model: widget.srcModel

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: notifItemCol.implicitHeight + 14
                            radius: 12
                            color: notifItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)

                            MouseArea {
                                id: notifItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (island && island.activateNotificationAt) {
                                        island.activateNotificationAt(index)
                                    }
                                }
                            }

                            ColumnLayout {
                                id: notifItemCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 7
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Kirigami.Icon {
                                        source: model.applicationIconName || model.iconName || "notifications"
                                        width: 16; height: 16
                                        color: island ? island.textPrimary : "white"
                                    }

                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        text: model.summary || model.applicationName || Tr.t("Notification")
                                        color: island ? island.textPrimary : "white"
                                        font.pointSize: 8.5
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }

                                    // Dismiss 'x' button
                                    Rectangle {
                                        implicitHeight: 18
                                        implicitWidth: 18
                                        radius: 9
                                        color: delMouse.pressed ? Qt.rgba(1, 1, 1, 0.3) : (delMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1))

                                        PlasmaComponents.Label {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: "white"
                                            font.pointSize: 7.5
                                        }

                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (island && island.dismissNotificationAt) {
                                                    island.dismissNotificationAt(index)
                                                }
                                            }
                                        }
                                    }
                                }

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    visible: (model.body || model.text || "").length > 0
                                    text: model.body || model.text || ""
                                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                                    font.pointSize: 8
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
