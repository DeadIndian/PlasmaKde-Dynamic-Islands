import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../Translator.js" as Tr

Item {
    id: widget

    property var island: null
    property string widgetId: "network"
    property int spanW: 1
    property int spanH: 1

    implicitHeight: 48
    implicitWidth: 110

    readonly property bool isActive: {
        if (!island) return false
        if (widgetId === "network") return island.wifiEnabled
        if (widgetId === "bluetooth") return island.bluetoothEnabled
        if (widgetId === "dnd") return island.dndEnabled
        if (widgetId === "nightlight") return island.nightLightEnabled
        if (widgetId === "darkmode") return island.darkModeEnabled
        return false
    }

    readonly property string iconName: {
        if (widgetId === "network") return island && island.wifiEnabled ? "network-wireless" : "network-wireless-disconnected"
        if (widgetId === "bluetooth") return island && island.bluetoothEnabled ? "preferences-system-bluetooth" : "bluetooth-disabled"
        if (widgetId === "dnd") return island && island.dndEnabled ? "notifications-disabled" : "notifications"
        if (widgetId === "nightlight") return island && island.nightLightEnabled ? "night-light" : "weather-clear-night"
        if (widgetId === "darkmode") return island && island.darkModeEnabled ? "color-management" : "configure"
        if (widgetId === "power") return "system-shutdown"
        return "configure"
    }

    readonly property string titleText: {
        if (widgetId === "network") return Tr.t("Wi-Fi")
        if (widgetId === "bluetooth") return Tr.t("Bluetooth")
        if (widgetId === "dnd") return Tr.t("DND")
        if (widgetId === "nightlight") return Tr.t("Night Light")
        if (widgetId === "darkmode") return Tr.t("Dark Theme")
        if (widgetId === "power") return Tr.t("Power")
        return Tr.t("Toggle")
    }

    readonly property string statusText: {
        if (widgetId === "power") return Tr.t("Session")
        return isActive ? Tr.t("On") : Tr.t("Off")
    }

    readonly property string kcmModule: {
        if (widgetId === "network") return "kcm_networkmanagement"
        if (widgetId === "bluetooth") return "kcm_bluetooth"
        if (widgetId === "dnd") return "kcm_notifications"
        if (widgetId === "nightlight") return "kcm_nightlight"
        if (widgetId === "darkmode") return "kcm_colors"
        return ""
    }

    function toggle() {
        if (!island) return
        if (widgetId === "power") {
            powerMenu.open()
        } else if (widgetId === "network") {
            island.toggleWifi()
        } else if (widgetId === "bluetooth") {
            island.toggleBluetooth()
        } else if (widgetId === "dnd") {
            island.toggleDnd()
        } else if (widgetId === "nightlight") {
            island.toggleNightLight()
        } else if (widgetId === "darkmode") {
            island.toggleDarkMode()
        }
    }

    function openDetailedSettings() {
        if (widgetId === "power") {
            powerMenu.open()
        } else if (island && kcmModule.length > 0) {
            island.openKcm(kcmModule)
        } else {
            toggle()
        }
    }

    Rectangle {
        id: pillBg
        anchors.fill: parent
        radius: 16
        scale: pillMouse.pressed ? 0.94 : 1.0
        color: widget.isActive
            ? (island ? island.accent : "#3498db")
            : (pillMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12))
        border.width: 1
        border.color: widget.isActive
            ? Qt.lighter(island ? island.accent : "#3498db", 1.2)
            : Qt.rgba(1, 1, 1, 0.15)

        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 220 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 6

            // Status Icon
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: widget.isActive ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.1)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: widget.iconName
                    width: 16
                    height: 16
                    color: widget.isActive ? "white" : (island ? island.textPrimary : "white")
                }
            }

            // Labels
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: widget.width > 76
                spacing: 1

                PlasmaComponents.Label {
                    width: parent.width
                    text: widget.titleText
                    color: widget.isActive ? "white" : (island ? island.textPrimary : "white")
                    font.pointSize: 8.5
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    width: parent.width
                    text: widget.statusText
                    color: widget.isActive ? Qt.rgba(1, 1, 1, 0.85) : (island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.65))
                    font.pointSize: 7.5
                    elide: Text.ElideRight
                }
            }

            // Arrow button for official KDE Detailed Settings or Power Menu
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: settingsMouse.pressed ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.12)
                visible: widget.width > 90

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "go-next-symbolic"
                    width: 12
                    height: 12
                    color: widget.isActive ? "white" : (island ? island.textPrimary : "white")
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: widget.openDetailedSettings()
                }
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            anchors.rightMargin: 24
            hoverEnabled: true
            onClicked: widget.toggle()
        }
    }

    QQC2.Menu {
        id: powerMenu

        QQC2.MenuItem {
            text: Tr.t("Lock Screen")
            icon.name: "system-lock-screen"
            onTriggered: if (island) island.triggerPowerAction("lock")
        }
        QQC2.MenuItem {
            text: Tr.t("Suspend")
            icon.name: "system-suspend"
            onTriggered: if (island) island.triggerPowerAction("suspend")
        }
        QQC2.MenuItem {
            text: Tr.t("Hibernate")
            icon.name: "system-suspend-hibernate"
            onTriggered: if (island) island.triggerPowerAction("hibernate")
        }
        QQC2.MenuItem {
            text: Tr.t("Reboot")
            icon.name: "system-reboot"
            onTriggered: if (island) island.triggerPowerAction("reboot")
        }
        QQC2.MenuItem {
            text: Tr.t("Shut Down")
            icon.name: "system-shutdown"
            onTriggered: if (island) island.triggerPowerAction("shutdown")
        }
        QQC2.MenuItem {
            text: Tr.t("Log Out")
            icon.name: "system-log-out"
            onTriggered: if (island) island.triggerPowerAction("logout")
        }
    }
}
