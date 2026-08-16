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
    property string cfg_panelWidgets: "media,system"

    function widgetIds() {
        return Utils.parseWidgetList(cfg_panelWidgets, Catalog.ids())
    }

    function hasWidget(id) {
        return widgetIds().indexOf(id) !== -1
    }

    function toggleWidget(id, on) {
        let ids = widgetIds()
        if (on && ids.indexOf(id) === -1) {
            ids.push(id)
        }
        if (!on) {
            ids = ids.filter((x) => x !== id)
        }
        cfg_panelWidgets = Utils.serializeWidgetList(ids)
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
        QQC2.SpinBox { id: widthSpin; from: 240; to: 560; stepSize: 10 }
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
        Kirigami.FormData.label: Tr.t("Widgets:")
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Reorder by dragging in the panel. Widgets of a disabled module stay in the list but are greyed out until you enable that module.")
    }

    Repeater {
        model: Catalog.CATALOG

        delegate: QQC2.CheckBox {
            Kirigami.FormData.label: index === 0 ? Tr.t("Show:") : ""
            enabled: Catalog.requiresModule(modelData.id) === ""
                || Plasmoid.configuration[Catalog.requiresModule(modelData.id)]
            text: Catalog.labelFor(modelData.id)
            checked: page.hasWidget(modelData.id)
            onToggled: page.toggleWidget(modelData.id, checked)
        }
    }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Clock size:")
        QQC2.SpinBox { id: clockSizeSpin; from: 10; to: 64; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }
}
