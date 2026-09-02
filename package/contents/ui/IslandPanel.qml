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

    // Live drag offset. The delegate adds these to its layout position through a
    // binding, so nothing ever assigns x/y directly and the binding to the
    // placement engine survives every drag.
    property real dragTransX: 0
    property real dragTransY: 0
    property real autoScrollAccum: 0
    property int dragSpanW: 1
    property int dragSpanH: 1

    // Where the dragged card sat when the gesture began, in content coordinates.
    property real dragBaseX: 0
    property real dragBaseY: 0

    readonly property real dragCardX: dragBaseX + dragTransX
    readonly property real dragCardY: dragBaseY + dragTransY + autoScrollAccum
    readonly property real dragCardH: Math.round(dragSpanH * rowHeight + (dragSpanH - 1) * gap)

    // Previewed drop, recomputed on every drag move.
    property string dropAction: "move"
    property int dropCol: 0
    property int dropRow: 0
    property int dropSwapIndex: -1

    // ── Config & Grid Layout Shortcuts ────────────────────────────────
    readonly property int pad: Plasmoid.configuration.panelPadding || 12
    readonly property int gap: Plasmoid.configuration.panelSpacing || 10
    readonly property string sizePreset: Plasmoid.configuration.panelSizePreset || "large"

    readonly property int columns: sizePreset === "small" ? 2 : (sizePreset === "medium" ? 3 : 4)
    readonly property real colWidth: sizePreset === "small" ? 145 : (sizePreset === "medium" ? 135 : 125)
    readonly property real totalWidth: pad * 2 + columns * colWidth + (columns - 1) * gap
    readonly property real availableWidth: columns * colWidth + (columns - 1) * gap
    // Dynamic Sizing (widget height * X)
    readonly property real baseRowHeight: 54
    readonly property real headerHeight: 28
    readonly property int maxRows: sizePreset === "small" ? 3 : (sizePreset === "medium" ? 3 : 8)
    readonly property real maxGridHeight: maxRows * baseRowHeight + (maxRows - 1) * gap
    property real calculatedGridHeight: 200
    readonly property real visibleGridHeight: Math.max(baseRowHeight, Math.min(calculatedGridHeight, maxGridHeight))
    readonly property real mainCardHeight: pad * 2 + headerHeight + gap + visibleGridHeight
    readonly property real drawerCardHeight: editMode && addWidgetCard ? (addWidgetCard.implicitHeight + gap) : 0
    readonly property real totalContentHeight: mainCardHeight + drawerCardHeight
    readonly property int maxH: editMode ? 950 : Math.round(pad * 2 + headerHeight + gap + maxGridHeight)
    implicitHeight: Math.round(Math.min(maxH, totalContentHeight))
    implicitWidth: totalWidth

    // ── Layout ─────────────────────────────────────────────────────────
    // Cells come from Utils.resolvePlacements; this only turns them into pixels
    // and writes them back for the delegates to bind to.
    readonly property real rowHeight: baseRowHeight
    readonly property bool showGrips: Plasmoid.configuration.panelShowGrips

    function applyLayout() {
        if (!gridModel || gridModel.count === 0) return
        const resolved = Utils.resolvePlacements(currentSpecs(), columns)
        for (let i = 0; i < resolved.items.length; i++) {
            const it = resolved.items[i]
            gridModel.setProperty(i, "col", it.col)
            gridModel.setProperty(i, "row", it.row)
            gridModel.setProperty(i, "spanW", it.spanW)
            gridModel.setProperty(i, "spanH", it.spanH)
            gridModel.setProperty(i, "layoutX", Math.round(it.col * (colWidth + gap)))
            gridModel.setProperty(i, "layoutY", Math.round(it.row * (rowHeight + gap)))
            gridModel.setProperty(i, "layoutW", Math.round(it.spanW * colWidth + (it.spanW - 1) * gap))
            gridModel.setProperty(i, "layoutH", Math.round(it.spanH * rowHeight + (it.spanH - 1) * gap))
        }
        calculatedGridHeight = resolved.rows > 0
            ? Math.round(resolved.rows * rowHeight + (resolved.rows - 1) * gap)
            : rowHeight
    }

    function cancelDrag() {
        activeDragIndex = -1
        dragging = false
        dragTransX = 0
        dragTransY = 0
        autoScrollAccum = 0
        dropSwapIndex = -1
    }

    // Resolves the previewed drop from where the dragged card currently sits.
    function evaluateDrop(index, pixelX, pixelY) {
        const cell = Utils.cellFromPixel(pixelX, pixelY, colWidth, rowHeight, gap)
        const res = Utils.dropResult(currentSpecs(), index, cell.col, cell.row, columns)
        dropAction = res.action
        dropCol = res.col
        dropRow = res.row
        dropSwapIndex = res.action === "swap" ? res.withIndex : -1
    }

    onColWidthChanged: applyLayout()
    onAvailableWidthChanged: applyLayout()
    onGapChanged: applyLayout()

    // A column change invalidates any drop being previewed against the old grid.
    onColumnsChanged: {
        cancelDrag()
        applyLayout()
        persistOrder()
    }

    // ── Model Management ─────────────────────────────────────────────
    property var rawWidgetConfig: Plasmoid.configuration.panelWidgets !== undefined && Plasmoid.configuration.panelWidgets !== "" ? Plasmoid.configuration.panelWidgets : "network:1:1,bluetooth:1:1,dnd:1:1,nightlight:1:1,darkmode:1:1,power:1:1,volume:3:1,brightness:3:1,media:3:2,system:3:2"

    function currentSpecs() {
        let specs = []
        for (let i = 0; i < gridModel.count; i++) {
            const item = gridModel.get(i)
            specs.push({ id: item.widgetId, col: item.col, row: item.row, spanW: item.spanW, spanH: item.spanH })
        }
        return specs
    }

    function rebuild() {
        gridModel.clear()
        let specs = Utils.parseWidgetSpecs(rawWidgetConfig, Catalog.ids(), Catalog.defaultSpanWFor, Catalog.defaultSpanHFor)
        if (specs.length === 0) {
            const fallbackStr = "network:1:1,bluetooth:1:1,dnd:1:1,nightlight:1:1,darkmode:1:1,power:1:1,volume:3:1,brightness:3:1,media:3:2,system:3:2"
            specs = Utils.parseWidgetSpecs(fallbackStr, Catalog.ids(), Catalog.defaultSpanWFor, Catalog.defaultSpanHFor)
            Plasmoid.configuration.panelWidgets = fallbackStr
        }
        for (let i = 0; i < specs.length; i++) {
            let sw = Math.min(columns, Math.max(1, specs[i].spanW))
            let sh = specs[i].spanH
            if (specs[i].id === "timer" && sw === 1 && sh === 1 && columns >= 2) {
                sw = 2
            }
            gridModel.append({
                widgetId: specs[i].id,
                col: specs[i].col,
                row: specs[i].row,
                spanW: sw,
                spanH: sh,
                layoutX: 0,
                layoutY: 0,
                layoutW: 100,
                layoutH: 48
            })
        }
        applyLayout()
    }

    function persistOrder() {
        // Never write an empty layout: a change signal can fire before rebuild()
        // has populated the model.
        if (gridModel.count === 0) return
        const next = Utils.serializeWidgetSpecs(currentSpecs())
        if (next !== Plasmoid.configuration.panelWidgets) {
            Plasmoid.configuration.panelWidgets = next
        }
    }

    function addWidget(id) {
        let spanW = Catalog.defaultSpanWFor(id)
        let spanH = Catalog.defaultSpanHFor(id)
        if (id === "timer" && spanW === 1 && spanH === 1) {
            spanW = 2
        }
        // col/row -1 hands placement to the auto-placer, which fills the first
        // free slot in reading order.
        gridModel.append({
            widgetId: id,
            col: -1,
            row: -1,
            spanW: spanW,
            spanH: spanH,
            layoutX: 0,
            layoutY: 0,
            layoutW: 100,
            layoutH: 48
        })
        applyLayout()
        persistOrder()
    }

    function removeWidget(index) {
        if (gridModel.count > 1 && index >= 0 && index < gridModel.count) {
            gridModel.remove(index)
            applyLayout()
            persistOrder()
        }
    }

    function cycleWidgetSpan(index) {
        if (index < 0 || index >= gridModel.count) return
        const current = gridModel.get(index)
        let next = Utils.cycleSpan2D(current.spanW, current.spanH, panel.columns)
        if (current.widgetId === "timer" && next.spanW === 1 && next.spanH === 1) {
            next = { spanW: 2, spanH: 1 }
        }
        gridModel.setProperty(index, "spanW", next.spanW)
        gridModel.setProperty(index, "spanH", next.spanH)

        // The resized widget yields, never its neighbours. Slide it left to fit,
        // and if it still collides hand it to the auto-placer. resolvePlacements
        // alone would not do this: it resolves conflicts by model order, which
        // could displace a widget the user did not touch.
        const occ = Utils.buildOccupancy(currentSpecs(), panel.columns, index)
        const clamped = Math.max(0, Math.min(current.col, panel.columns - next.spanW))
        if (Utils.fits(occ, clamped, current.row, next.spanW, next.spanH, panel.columns)) {
            gridModel.setProperty(index, "col", clamped)
        } else {
            gridModel.setProperty(index, "col", -1)
            gridModel.setProperty(index, "row", -1)
        }

        applyLayout()
        persistOrder()
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

    // ── 1. Main Floating Panel Card (Un-squeezed, Full View) ───────────
    Rectangle {
        id: mainPanelCard
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: panel.mainCardHeight
        radius: island ? island.cornerRadius : 16
        color: island ? Qt.rgba(island.bgColor.r, island.bgColor.g, island.bgColor.b, island.bgOpacity) : Qt.rgba(0.07, 0.1, 0.15, 0.85)
        border.width: island && island.borderEnabled ? 1 : (panel.editMode ? 1 : 0)
        border.color: panel.editMode ? Qt.rgba(1, 1, 1, 0.25) : (island ? Qt.rgba(1, 1, 1, 0.15) : "transparent")

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: pad
            spacing: gap

            // ── Top Header Bar ────────────────────────────────────────────
            RowLayout {
                id: topHeader
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 10

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: userRow.implicitWidth + 16
                    radius: 14
                    color: userMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : (userMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    Layout.alignment: Qt.AlignVCenter

                    Row {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 6

                        Kirigami.Icon {
                            source: "user-identity"
                            width: 16; height: 16
                            color: island ? island.textPrimary : "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        PlasmaComponents.Label {
                            text: (island && island.userName) ? island.userName : "User"
                            color: island ? island.textPrimary : "white"
                            font.pointSize: 9.5
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: userMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.text: Tr.t("System Info & About")
                        onClicked: {
                            if (island && island.openSystemAbout) {
                                island.openSystemAbout()
                            }
                        }
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
                Layout.preferredHeight: panel.visibleGridHeight
                Layout.fillHeight: true
                contentWidth: availableWidth
                contentHeight: gridLayout.implicitHeight
                clip: true
                interactive: !panel.editMode && !panel.dragging

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    id: vScrollBar
                    active: true
                    policy: gridFlickable.contentHeight > gridFlickable.height + 4
                        ? QQC2.ScrollBar.AlwaysOn
                        : QQC2.ScrollBar.AlwaysOff

                    contentItem: Rectangle {
                        implicitWidth: 4
                        implicitHeight: 24
                        radius: 2
                        color: island ? Qt.rgba(island.accent.r, island.accent.g, island.accent.b, 0.75) : Qt.rgba(1, 1, 1, 0.5)
                    }
                    background: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.1)
                    }
                }

                Item {
                    id: gridLayout
                    width: panel.availableWidth
                    // While dragging, the content has to reach the previewed cell or
                    // the bottom row of the grid would be the lowest a widget could
                    // ever go, and bottom-edge autoscroll would have nowhere to run.
                    implicitHeight: panel.dragging
                        ? Math.max(panel.calculatedGridHeight,
                                   Math.round((panel.dropRow + panel.dragSpanH) * (panel.rowHeight + panel.gap)))
                        : panel.calculatedGridHeight

                    // Single shared drop preview. z: 0 keeps it behind the cards.
                    Rectangle {
                        id: dropPlaceholder
                        visible: panel.dragging
                        z: 0
                        radius: 16
                        color: "transparent"
                        border.width: 2
                        border.color: panel.dropAction === "reject"
                            ? Qt.rgba(0.9, 0.25, 0.25, 0.9)
                            : (island ? island.accent : "#3498db")

                        x: Math.round(panel.dropCol * (panel.colWidth + panel.gap))
                        y: Math.round(panel.dropRow * (panel.rowHeight + panel.gap))
                        width: Math.round(panel.dragSpanW * panel.colWidth + (panel.dragSpanW - 1) * panel.gap)
                        height: Math.round(panel.dragSpanH * panel.rowHeight + (panel.dragSpanH - 1) * panel.gap)

                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    Repeater {
                        id: gridRepeater
                        model: gridModel

                        delegate: Item {
                            id: cardItem

                            readonly property bool isBeingDragged: panel.activeDragIndex === index
                            readonly property bool isSwapTarget: panel.dragging
                                && panel.dropAction === "swap"
                                && panel.dropSwapIndex === index
                            // Offsets, not assignments: x/y stay bound to the layout
                            // engine, so releasing the card animates it home for free.
                            readonly property real dragDX: isBeingDragged ? panel.dragTransX : 0
                            readonly property real dragDY: isBeingDragged ? panel.dragTransY + panel.autoScrollAccum : 0

                            x: (model.layoutX !== undefined ? model.layoutX : 0) + dragDX
                            y: (model.layoutY !== undefined ? model.layoutY : 0) + dragDY
                            width: model.layoutW !== undefined ? model.layoutW : 100
                            height: model.layoutH !== undefined ? model.layoutH : 48

                            z: isBeingDragged ? 99 : 1
                            scale: isBeingDragged ? 1.04 : (cardMouse.pressed ? 0.96 : 1.0)
                            opacity: isBeingDragged ? 1.0 : 1.0
                            rotation: 0

                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 160 }
                            }

                            Behavior on x {
                                enabled: !cardItem.isBeingDragged
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }

                            Behavior on y {
                                enabled: !cardItem.isBeingDragged
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }

                            Behavior on width {
                                enabled: !cardItem.isBeingDragged
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }

                            Behavior on height {
                                enabled: !cardItem.isBeingDragged
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }

                            // Main Card Wrapper
                            Rectangle {
                                id: cardContainer
                                anchors.fill: parent
                                radius: 16
                                color: cardItem.isBeingDragged
                                    ? Qt.rgba(0.25, 0.25, 0.35, 0.7)
                                    : (panel.editMode ? Qt.rgba(0.2, 0.2, 0.25, 0.4) : (cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)))
                                border.width: panel.editMode ? (cardItem.isBeingDragged ? 1.5 : 1) : 0
                                border.color: cardItem.isBeingDragged
                                    ? (island ? island.accent : "#3498db")
                                    : (panel.editMode ? Qt.rgba(1, 1, 1, 0.3) : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }

                                // Subtle edit mode drag glow
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    radius: parent.radius + 4
                                    color: cardItem.isBeingDragged ? (island ? island.accent : "#3498db") : "transparent"
                                    opacity: 0.25
                                    visible: cardItem.isBeingDragged
                                    z: -1
                                }

                                // Inner top highlight
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 1
                                    anchors.leftMargin: parent.radius
                                    anchors.rightMargin: parent.radius
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

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
                                    color: cardDrag.active ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.3)
                                    border.width: (cardItem.isBeingDragged || cardItem.isSwapTarget) ? 2 : 1
                                    border.color: cardItem.isBeingDragged
                                        ? (island ? island.accent : "#3498db")
                                        : (cardItem.isSwapTarget
                                            ? Qt.rgba(1, 1, 1, 0.8)
                                            : Qt.rgba(1, 1, 1, 0.25))

                                    // Swallows clicks so the live widget beneath is
                                    // inert while editing. The DragHandler takes the
                                    // grab from it once the drag threshold is crossed.
                                    MouseArea {
                                        id: editBlocker
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    DragHandler {
                                        id: cardDrag
                                        target: null
                                        enabled: panel.editMode
                                        dragThreshold: 6
                                        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        // Default grabPermissions include
                                        // ApprovesTakeOverByItems, which lets the parent
                                        // Flickable steal the grab mid-drag — the card
                                        // starts moving and the grid scrolls instead.
                                        grabPermissions: PointerHandler.CanTakeOverFromItems
                                            | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                            | PointerHandler.ApprovesTakeOverByHandlersOfSameType

                                        onActiveChanged: {
                                            if (cardDrag.active) {
                                                panel.activeDragIndex = index
                                                panel.dragging = true
                                                panel.dragSpanW = model.spanW
                                                panel.dragSpanH = model.spanH
                                                panel.dragBaseX = model.layoutX !== undefined ? model.layoutX : 0
                                                panel.dragBaseY = model.layoutY !== undefined ? model.layoutY : 0
                                                panel.dragTransX = 0
                                                panel.dragTransY = 0
                                                panel.autoScrollAccum = 0
                                                panel.dropAction = "move"
                                                panel.dropCol = model.col
                                                panel.dropRow = model.row
                                                panel.dropSwapIndex = -1
                                                return
                                            }

                                            const action = panel.dropAction
                                            const col = panel.dropCol
                                            const row = panel.dropRow
                                            const swapWith = panel.dropSwapIndex
                                            const from = index
                                            const oldCol = model.col
                                            const oldRow = model.row

                                            // Clear activeDragIndex first: that re-enables
                                            // Behavior on x/y, so the card animates from
                                            // where it was let go to where it lands.
                                            panel.activeDragIndex = -1
                                            panel.dragging = false

                                            if (action === "move") {
                                                gridModel.setProperty(from, "col", col)
                                                gridModel.setProperty(from, "row", row)
                                                panel.applyLayout()
                                                panel.persistOrder()
                                            } else if (action === "swap" && swapWith >= 0) {
                                                gridModel.setProperty(from, "col", col)
                                                gridModel.setProperty(from, "row", row)
                                                gridModel.setProperty(swapWith, "col", oldCol)
                                                gridModel.setProperty(swapWith, "row", oldRow)
                                                panel.applyLayout()
                                                panel.persistOrder()
                                            }

                                            panel.dragTransX = 0
                                            panel.dragTransY = 0
                                            panel.autoScrollAccum = 0
                                            panel.dropSwapIndex = -1
                                        }

                                        onActiveTranslationChanged: {
                                            if (!cardDrag.active) return
                                            panel.dragTransX = cardDrag.activeTranslation.x
                                            panel.dragTransY = cardDrag.activeTranslation.y
                                            panel.evaluateDrop(index, cardItem.x, cardItem.y)
                                        }
                                    }

                                    // Hint only — the whole overlay is grabbable.
                                    Grid {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.leftMargin: 8
                                        anchors.topMargin: 8
                                        columns: 2
                                        rows: 3
                                        rowSpacing: 3
                                        columnSpacing: 3
                                        opacity: (panel.showGrips || editBlocker.containsMouse || cardDrag.active) ? 0.8 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }

                                        Repeater {
                                            model: 6
                                            delegate: Rectangle {
                                                width: 3
                                                height: 3
                                                radius: 1.5
                                                color: "white"
                                            }
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
                                            visible: gridModel.count > 1
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
        }
    }

    // ── 2. Separate Floating "Add Widget" Card (Detached below main panel) ──
    Rectangle {
        id: addWidgetCard
        visible: panel.editMode
        anchors.top: mainPanelCard.bottom
        anchors.topMargin: gap
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        implicitHeight: drawerColumn.implicitHeight + pad * 2
        radius: island ? island.cornerRadius : 16
        color: island ? Qt.rgba(island.bgColor.r, island.bgColor.g, island.bgColor.b, 0.95) : Qt.rgba(0.09, 0.12, 0.18, 0.95)
        border.width: 1
        border.color: island ? Qt.rgba(island.accent.r, island.accent.g, island.accent.b, 0.4) : Qt.rgba(1, 1, 1, 0.25)

        ColumnLayout {
            id: drawerColumn
            anchors.fill: parent
            anchors.margins: pad
            spacing: 8

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
