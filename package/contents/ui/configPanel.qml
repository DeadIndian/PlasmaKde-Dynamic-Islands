import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "Translator.js" as Tr
import "IslandUtils.js" as Utils
import "WidgetCatalog.js" as Catalog
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Property Aliases for Plasmoid Configuration Mapping
    property alias cfg_panelEnabled: panelEnabledSwitch.checked
    property alias cfg_panelShowGrips: gripsSwitch.checked
    property alias cfg_popupCloseOnHoverExit: hoverExitSwitch.checked
    property alias cfg_widgetClockSize: clockSizeSpin.value
    property string cfg_panelShowMode: "idle"
    property string cfg_panelSizePreset: "large"
    property string cfg_panelWidgets: Plasmoid.configuration.panelWidgets || "network:1:1,bluetooth:1:1,dnd:1:1,nightlight:1:1,darkmode:1:1,power:1:1,volume:3:1,brightness:3:1,media:3:2,system:3:2"

    Connections {
        target: Plasmoid.configuration
        ignoreUnknownSignals: true
        function onPanelWidgetsChanged() {
            if (Plasmoid.configuration.panelWidgets && Plasmoid.configuration.panelWidgets.length > 0) {
                page.cfg_panelWidgets = Plasmoid.configuration.panelWidgets
            }
        }
    }

    function widgetSpecs() {
        return Utils.parseWidgetSpecs(cfg_panelWidgets, Catalog.ids(), Catalog.defaultSpanWFor, Catalog.defaultSpanHFor)
    }

    function hasWidget(id) {
        let specs = widgetSpecs()
        for (let i = 0; i < specs.length; i++) {
            if (specs[i].id === id) return true
        }
        return false
    }

    function toggleWidget(id, on) {
        let specs = widgetSpecs()
        if (on && !hasWidget(id)) {
            specs.push({ id: id, spanW: Catalog.defaultSpanWFor(id), spanH: Catalog.defaultSpanHFor(id) })
        }
        if (!on && specs.length > 1) {
            specs = specs.filter((x) => x.id !== id)
        }
        cfg_panelWidgets = Utils.serializeWidgetSpecs(specs)
    }

    function moveWidget(id, delta) {
        let specs = widgetSpecs()
        let idx = -1
        for (let i = 0; i < specs.length; i++) {
            if (specs[i].id === id) { idx = i; break }
        }
        if (idx === -1) return
        let target = idx + delta
        if (target < 0 || target >= specs.length) return
        let updated = Utils.moveItem(specs, idx, target)
        cfg_panelWidgets = Utils.serializeWidgetSpecs(updated)
    }

    Kirigami.FormLayout {
        // Section 1: Quick Control Panel Options
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Quick Control Panel Options")
        }

        QQC2.Switch {
            id: panelEnabledSwitch
            Kirigami.FormData.label: Tr.t("Widget panel:")
            text: Tr.t("Open an interactive floating control panel when clicking the idle capsule")
        }

        QQC2.ComboBox {
            id: sizePresetCombo
            Kirigami.FormData.label: Tr.t("Panel layout preset:")
            enabled: panelEnabledSwitch.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Small (Compact 2x3 grid)"), value: "small" },
                { text: Tr.t("Medium (3x3 grid)"), value: "medium" },
                { text: Tr.t("Large (Full 4-column panel)"), value: "large" }
            ]
            onActivated: page.cfg_panelSizePreset = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_panelSizePreset))
        }

        QQC2.ComboBox {
            id: showModeCombo
            Kirigami.FormData.label: Tr.t("Trigger mode:")
            enabled: panelEnabledSwitch.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Only when idle (no active media or notification)"), value: "idle" },
                { text: Tr.t("Always, embedding active content at the top"), value: "always" }
            ]
            onActivated: page.cfg_panelShowMode = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_panelShowMode))
        }

        QQC2.Switch {
            id: hoverExitSwitch
            Kirigami.FormData.label: Tr.t("Auto-close on hover exit:")
            enabled: panelEnabledSwitch.checked
            text: Tr.t("Automatically close the panel when mouse pointer leaves")
        }

        QQC2.Switch {
            id: gripsSwitch
            Kirigami.FormData.label: Tr.t("Reorder handles:")
            enabled: panelEnabledSwitch.checked
            text: Tr.t("Always show drag handle grips on widgets (otherwise visible on hover)")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Panel clock font size:")
            enabled: panelEnabledSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: clockSizeSpin; from: 10; to: 64; stepSize: 1 }
            QQC2.Label { text: Tr.t("pt") }
        }

        // Section 2: Active Control Center Widgets (Ordered List)
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Active Widgets (In Panel Display Order)")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: Tr.t("Widgets currently active on your floating panel in exact display order. Use the arrows to move items up/down.")
        }

        Repeater {
            id: activeRepeater
            model: page.widgetSpecs()

            delegate: RowLayout {
                Kirigami.FormData.label: index === 0 ? Tr.t("Active list:") : ""
                spacing: 8
                Layout.fillWidth: true

                readonly property string widgetId: modelData.id
                readonly property bool isModuleEnabled: Catalog.requiresModule(widgetId) === ""
                    || Plasmoid.configuration[Catalog.requiresModule(widgetId)]

                Kirigami.Icon {
                    source: Catalog.iconFor(widgetId)
                    width: 16; height: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                QQC2.Label {
                    text: Catalog.labelFor(widgetId)
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }

                QQC2.Label {
                    text: "(" + modelData.spanW + "x" + modelData.spanH + ")"
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                QQC2.ToolButton {
                    icon.name: "go-up"
                    enabled: index > 0
                    onClicked: page.moveWidget(widgetId, -1)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: Tr.t("Move Up")
                }

                QQC2.ToolButton {
                    icon.name: "go-down"
                    enabled: index < activeRepeater.count - 1
                    onClicked: page.moveWidget(widgetId, 1)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: Tr.t("Move Down")
                }

                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    enabled: activeRepeater.count > 1
                    onClicked: page.toggleWidget(widgetId, false)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: Tr.t("Remove Widget")
                }
            }
        }

        // Section 3: More Available Widgets to Add
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Available Widgets (Click to Add)")
        }

        Repeater {
            model: Catalog.CATALOG

            delegate: RowLayout {
                readonly property bool isActive: page.hasWidget(modelData.id)
                readonly property bool isModuleEnabled: Catalog.requiresModule(modelData.id) === ""
                    || Plasmoid.configuration[Catalog.requiresModule(modelData.id)]

                visible: !isActive && isModuleEnabled
                spacing: 8
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: Catalog.iconFor(modelData.id)
                    width: 16; height: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                QQC2.Label {
                    text: Catalog.labelFor(modelData.id)
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                QQC2.Button {
                    text: "+ " + Tr.t("Add to Panel")
                    icon.name: "list-add"
                    onClicked: page.toggleWidget(modelData.id, true)
                }
            }
        }
    }
}
