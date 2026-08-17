import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../ui/Translator.js" as Tr
import "../ui/IslandUtils.js" as Utils
import "../ui/WidgetCatalog.js" as Catalog

Kirigami.FormLayout {
    id: page

    property alias cfg_panelEnabled: panelEnabledSwitch.checked
    property alias cfg_panelWidth: widthSpin.value
    property alias cfg_panelMaxHeight: maxHeightSpin.value
    property alias cfg_panelSpacing: spacingSpin.value
    property alias cfg_panelPadding: paddingSpin.value
    property alias cfg_panelShowGrips: gripsSwitch.checked
    property alias cfg_popupCloseOnHoverExit: hoverExitSwitch.checked
    property alias cfg_widgetClockSize: clockSizeSpin.value
    property string cfg_panelShowMode: "idle"
    property string cfg_panelWidgets: "network:1:1,bluetooth:1:1,dnd:1:1,nightlight:1:1,darkmode:1:1,power:1:1,volume:3:1,brightness:3:1,media:3:2,system:3:2"

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
        if (!on) {
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

    QQC2.Switch {
        id: panelEnabledSwitch
        Kirigami.FormData.label: Tr.t("Widget panel:")
        text: Tr.t("Open a floating widget panel from the idle capsule")
    }

    QQC2.ComboBox {
        id: showModeCombo
        Kirigami.FormData.label: Tr.t("When to open:")
        enabled: panelEnabledSwitch.checked
        textRole: "text"
        valueRole: "value"
        model: [
            { text: Tr.t("Only when nothing else is happening"), value: "idle" },
            { text: Tr.t("Always, with active content as a header"), value: "always" }
        ]
        onActivated: page.cfg_panelShowMode = currentValue
        Component.onCompleted: currentIndex = indexOfValue(page.cfg_panelShowMode)
    }

    QQC2.Switch {
        id: hoverExitSwitch
        Kirigami.FormData.label: Tr.t("Close behaviour:")
        text: Tr.t("Close when the pointer leaves the panel")
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Width:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: widthSpin; from: 320; to: 720; stepSize: 10 }
        QQC2.Label { text: Tr.t("px") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Max height:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: maxHeightSpin; from: 120; to: 900; stepSize: 20 }
        QQC2.Label { text: Tr.t("px, taller panels scroll") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Spacing:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: spacingSpin; from: 0; to: 24; stepSize: 1 }
        QQC2.Label { text: Tr.t("px between widgets") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Padding:")
        enabled: panelEnabledSwitch.checked
        QQC2.SpinBox { id: paddingSpin; from: 0; to: 32; stepSize: 1 }
        QQC2.Label { text: Tr.t("px around the widgets") }
    }

    QQC2.Switch {
        id: gripsSwitch
        Kirigami.FormData.label: Tr.t("Reorder:")
        enabled: panelEnabledSwitch.checked
        text: Tr.t("Always show the drag handles (otherwise they appear on hover)")
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.Label {
        Kirigami.FormData.label: Tr.t("Widgets & Pills:")
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Reorder using up/down arrows or directly in Edit Mode inside the panel.")
    }

    Repeater {
        model: Catalog.CATALOG

        delegate: RowLayout {
            Kirigami.FormData.label: index === 0 ? Tr.t("Show:") : ""
            spacing: 6
            Layout.fillWidth: true

            readonly property bool isModuleEnabled: Catalog.requiresModule(modelData.id) === ""
                || Plasmoid.configuration[Catalog.requiresModule(modelData.id)]
            readonly property bool isChecked: page.hasWidget(modelData.id)
            readonly property int activeIdx: {
                let specs = page.widgetSpecs()
                for (let i = 0; i < specs.length; i++) {
                    if (specs[i].id === modelData.id) return i
                }
                return -1
            }

            QQC2.CheckBox {
                enabled: isModuleEnabled
                text: Catalog.labelFor(modelData.id)
                checked: isChecked
                onToggled: page.toggleWidget(modelData.id, checked)
            }

            Item { Layout.fillWidth: true }

            QQC2.ToolButton {
                icon.name: "go-up"
                visible: isChecked && activeIdx > 0
                onClicked: page.moveWidget(modelData.id, -1)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: Tr.t("Move Up")
            }

            QQC2.ToolButton {
                icon.name: "go-down"
                visible: isChecked && activeIdx !== -1 && activeIdx < page.widgetSpecs().length - 1
                onClicked: page.moveWidget(modelData.id, 1)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: Tr.t("Move Down")
            }
        }
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Clock size:")
        QQC2.SpinBox { id: clockSizeSpin; from: 10; to: 64; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }
}
