import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "IslandUtils.js" as Utils
import "Translator.js" as Tr
import "WidgetCatalog.js" as Catalog

// 3-Column 2D Grid Control Center & Dynamic Island panel.
Item {
    id: panel

    property var island: null
    property bool editMode: false
    property bool dragging: false
    property int activeDragIndex: -1

    // ── Config & Grid Layout Shortcuts ────────────────────────────────
    readonly property int pad: Plasmoid.configuration.panelPadding || 12
    readonly property int gap: Plasmoid.configuration.panelSpacing || 10
    readonly property int maxH: Plasmoid.configuration.panelMaxHeight || 600
    readonly property int columns: 3

    readonly property real totalWidth: Math.max(360, Plasmoid.configuration.panelWidth || 420)
    readonly property real availableWidth: totalWidth - pad * 2
    readonly property real colWidth: (availableWidth - (columns - 1) * gap) / columns
    readonly property real baseRowHeight: 48

    // Dynamic Sizing
    readonly property real contentHeight: gridLayout.implicitHeight
    readonly property real totalContentHeight: pad * 2 + topHeader.implicitHeight + gap + contentHeight + (editMode ? drawerArea.implicitHeight + gap : 0)
    implicitHeight: Math.max(120, Math.min(maxH, totalContentHeight))
    implicitWidth: totalWidth

    // ── Model Management ─────────────────────────────────────────────
    property var rawWidgetConfig: Plasmoid.configuration.panelWidgets || "network:1:1,bluetooth:1:1,dnd:1:1,nightlight:1:1,darkmode:1:1,power:1:1,volume:3:1,brightness:3:1,media:3:2,system:3:2"

    function currentSpecs() {
        let specs = []
        for (let i = 0; i < gridModel.count; i++) {
            const item = gridModel.get(i)
            specs.push({ id: item.widgetId, spanW: item.spanW, spanH: item.spanH })
        }
        return specs
    }

    function rebuild() {
        gridModel.clear()
        const specs = Utils.parseWidgetSpecs(rawWidgetConfig, Catalog.ids(), Catalog.defaultSpanWFor, Catalog.defaultSpanHFor)
        for (let i = 0; i < specs.length; i++) {
            gridModel.append({ widgetId: specs[i].id, spanW: specs[i].spanW, spanH: specs[i].spanH })
        }
    }

    function persistOrder() {
        const specs = currentSpecs()
        Plasmoid.configuration.panelWidgets = Utils.serializeWidgetSpecs(specs)
    }

    function addWidget(id) {
        const spanW = Catalog.defaultSpanWFor(id)
        const spanH = Catalog.defaultSpanHFor(id)
        gridModel.append({ widgetId: id, spanW: spanW, spanH: spanH })
        persistOrder()
    }

    function removeWidget(index) {
        if (index >= 0 && index < gridModel.count) {
            gridModel.remove(index)
            persistOrder()
        }
    }

    function cycleWidgetSpan(index) {
        if (index >= 0 && index < gridModel.count) {
            const current = gridModel.get(index)
            const next = Utils.cycleSpan2D(current.spanW, current.spanH)
            gridModel.setProperty(index, "spanW", next.spanW)
            gridModel.setProperty(index, "spanH", next.spanH)
            persistOrder()
        }
    }

    onRawWidgetConfigChanged: {
        if (dragging) return
        const incomingSpecs = Utils.parseWidgetSpecs(rawWidgetConfig, Catalog.ids(), Catalog.defaultSpanWFor, Catalog.defaultSpanHFor)
        const incomingStr = Utils.serializeWidgetSpecs(incomingSpecs)
        const currentStr = Utils.serializeWidgetSpecs(currentSpecs())
        if (incomingStr !== currentStr) rebuild()
    }

    Component.onCompleted: rebuild()

    ListModel {
        id: gridModel
    }

    // ── Main Panel Layout ─────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: pad
        spacing: gap

        // ── Top Header Bar ────────────────────────────────────────────
        RowLayout {
            id: topHeader
            Layout.fillWidth: true
            spacing: 10

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Kirigami.Icon {
                    source: "user-identity"
                    width: 20; height: 20
                    color: island ? island.textPrimary : "white"
                }

                PlasmaComponents.Label {
                    text: island ? island.clockDisplay : Qt.formatTime(new Date(), "hh:mm")
                    color: island ? island.textPrimary : "white"
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.fillWidth: true }

            // Edit Mode Toggle Button
            Rectangle {
                implicitHeight: 28
                implicitWidth: editLabel.implicitWidth + 20
                radius: 14
                color: panel.editMode
                    ? (island ? island.accent : "#27ae60")
                    : (editMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Kirigami.Icon {
                        source: panel.editMode ? "dialog-ok-apply" : "document-edit"
                        width: 14; height: 14
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PlasmaComponents.Label {
                        id: editLabel
                        text: panel.editMode ? Tr.t("Done") : Tr.t("Edit")
                        color: "white"
                        font.pointSize: 9
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: editMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panel.editMode = !panel.editMode
                }
            }
        }

        // ── Scrollable Grid View ──────────────────────────────────────
        Flickable {
            id: gridFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            contentHeight: gridLayout.implicitHeight
            clip: true
            interactive: !panel.editMode && !panel.dragging

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                policy: gridFlickable.contentHeight > gridFlickable.height
                    ? QQC2.ScrollBar.AsNeeded
                    : QQC2.ScrollBar.AlwaysOff
            }

            Flow {
                id: gridLayout
                width: panel.availableWidth
                spacing: panel.gap

                Repeater {
                    id: gridRepeater
                    model: gridModel

                    delegate: Item {
                        id: cardItem
                        width: Math.min(panel.availableWidth, model.spanW * panel.colWidth + (model.spanW - 1) * panel.gap)
                        height: model.spanH === 1
                            ? Math.max(cardLoader.item ? cardLoader.item.implicitHeight : 48, 48)
                            : (model.spanH * 70 + (model.spanH - 1) * panel.gap)

                        readonly property bool isBeingDragged: panel.activeDragIndex === index

                        z: isBeingDragged ? 99 : 1
                        scale: isBeingDragged ? 1.04 : 1.0
                        opacity: isBeingDragged ? 0.88 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }

                        Behavior on x {
                            enabled: panel.editMode && !cardItem.isBeingDragged
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        Behavior on y {
                            enabled: panel.editMode && !cardItem.isBeingDragged
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        // Main Card Wrapper
                        Rectangle {
                            id: cardContainer
                            anchors.fill: parent
                            radius: 16
                            color: cardItem.isBeingDragged
                                ? Qt.rgba(0.25, 0.25, 0.35, 0.7)
                                : (panel.editMode ? Qt.rgba(0.2, 0.2, 0.25, 0.4) : Qt.rgba(1, 1, 1, 0.06))
                            border.width: panel.editMode ? (cardItem.isBeingDragged ? 2 : 1) : 0
                            border.color: cardItem.isBeingDragged
                                ? (island ? island.accent : "#3498db")
                                : (panel.editMode ? Qt.rgba(1, 1, 1, 0.3) : "transparent")

                            Loader {
                                id: cardLoader
                                anchors.fill: parent
                                source: Catalog.fileFor(model.widgetId)

                                Binding {
                                    target: cardLoader.item
                                    property: "island"
                                    value: panel.island
                                    when: cardLoader.status === Loader.Ready
                                }

                                Binding {
                                    target: cardLoader.item
                                    property: "widgetId"
                                    value: model.widgetId
                                    when: cardLoader.status === Loader.Ready && cardLoader.item && cardLoader.item.hasOwnProperty("widgetId")
                                }

                                Binding {
                                    target: cardLoader.item
                                    property: "spanW"
                                    value: model.spanW
                                    when: cardLoader.status === Loader.Ready && cardLoader.item && cardLoader.item.hasOwnProperty("spanW")
                                }

                                Binding {
                                    target: cardLoader.item
                                    property: "spanH"
                                    value: model.spanH
                                    when: cardLoader.status === Loader.Ready && cardLoader.item && cardLoader.item.hasOwnProperty("spanH")
                                }

                                Binding {
                                    target: cardLoader.item
                                    property: "span"
                                    value: model.spanW
                                    when: cardLoader.status === Loader.Ready && cardLoader.item && cardLoader.item.hasOwnProperty("span")
                                }
                            }

                            // ── Edit Mode Overlay ───────────────────────
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: panel.editMode
                                color: dragGripMouse.pressed ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.3)
                                border.width: cardItem.isBeingDragged ? 2 : 1
                                border.color: cardItem.isBeingDragged
                                    ? (island ? island.accent : "#3498db")
                                    : Qt.rgba(1, 1, 1, 0.25)

                                MouseArea {
                                    id: dragGripMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.SizeAllCursor

                                    onPressed: {
                                        panel.activeDragIndex = index
                                        panel.dragging = true
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!panel.dragging || panel.activeDragIndex < 0) return
                                        const pt = mapToItem(gridLayout, mouse.x, mouse.y)
                                        let target = -1
                                        for (let i = 0; i < gridModel.count; i++) {
                                            if (i === panel.activeDragIndex) continue
                                            const item = gridRepeater.itemAt(i)
                                            if (item) {
                                                const marginX = item.width * 0.2
                                                const marginY = item.height * 0.2
                                                if (pt.x >= item.x + marginX && pt.x <= item.x + item.width - marginX &&
                                                    pt.y >= item.y + marginY && pt.y <= item.y + item.height - marginY) {
                                                    target = i
                                                    break
                                                }
                                            }
                                        }
                                        if (target >= 0 && target !== panel.activeDragIndex) {
                                            gridModel.move(panel.activeDragIndex, target, 1)
                                            panel.activeDragIndex = target
                                        }
                                    }

                                    onReleased: {
                                        panel.activeDragIndex = -1
                                        panel.dragging = false
                                        panel.persistOrder()
                                    }
                                }

                                RowLayout {
                                    anchors.top: parent.top
                                    anchors.topMargin: 4
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    spacing: 4

                                    // Span Toggle Button (1x1, 2x1, 2x2, 3x1, 3x2)
                                    Rectangle {
                                        implicitHeight: 22
                                        implicitWidth: spanLabel.implicitWidth + 12
                                        radius: 11
                                        color: Qt.rgba(1, 1, 1, 0.25)

                                        PlasmaComponents.Label {
                                            id: spanLabel
                                            anchors.centerIn: parent
                                            text: model.spanW + "x" + model.spanH
                                            color: "white"
                                            font.pointSize: 8
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: panel.cycleWidgetSpan(index)
                                        }
                                    }

                                    // Delete Button
                                    Rectangle {
                                        implicitHeight: 22
                                        implicitWidth: 22
                                        radius: 11
                                        color: Qt.rgba(0.9, 0.2, 0.2, 0.8)

                                        PlasmaComponents.Label {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: "white"
                                            font.pointSize: 9
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: panel.removeWidget(index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Edit Mode Bottom Drawer ("+ Add Widget") ──────────────────
        ColumnLayout {
            id: drawerArea
            Layout.fillWidth: true
            visible: panel.editMode
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            PlasmaComponents.Label {
                text: Tr.t("Add Quick Toggle or Widget:")
                color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                font.pointSize: 9
                font.weight: Font.DemiBold
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Catalog.CATALOG

                    delegate: Rectangle {
                        readonly property bool inGrid: {
                            for (let i = 0; i < gridModel.count; i++) {
                                if (gridModel.get(i).widgetId === modelData.id) return true
                            }
                            return false
                        }

                        visible: !inGrid && Catalog.isAvailable(modelData.id, Plasmoid.configuration)
                        implicitHeight: 26
                        implicitWidth: addBtnRow.implicitWidth + 16
                        radius: 13
                        color: addBtnMouse.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)

                        Row {
                            id: addBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            Kirigami.Icon {
                                source: Catalog.iconFor(modelData.id)
                                width: 14; height: 14
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            PlasmaComponents.Label {
                                text: "+ " + Catalog.labelFor(modelData.id)
                                color: "white"
                                font.pointSize: 8.5
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: addBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: panel.addWidget(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
