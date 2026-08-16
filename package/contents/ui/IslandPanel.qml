import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "IslandUtils.js" as Utils
import "Translator.js" as Tr
import "WidgetCatalog.js" as Catalog

// The floating widget panel.  Widget ids come from island.panelVisibleWidgets
// (filtered by module availability); the ListView order is the live order,
// persisted to panelWidgets after a drag.  island is supplied by the Loader
// in main.qml so every child widget receives an explicit handle.
Item {
    id: panel

    property var island: null
    property bool dragging: false
    // Tracks the widest loaded widget so the panel auto-scales its width.
    property real contentMaxWidth: 0

    // ── Config shortcuts ─────────────────────────────────────────────
    readonly property int pad:      Plasmoid.configuration.panelPadding
    readonly property int gap:      Plasmoid.configuration.panelSpacing
    readonly property int maxH:     Plasmoid.configuration.panelMaxHeight
    readonly property bool showGrips: Plasmoid.configuration.panelShowGrips

    // ── Header (always mode, active media/notification) ──────────────
    readonly property bool headerShown: island
        && island.panelShowMode === "always"
        && (island.activeMode === 0 || island.activeMode === 2)
        && !(island.activeMode === 0
             && island.panelWidgetIds.indexOf("media") !== -1)
    readonly property real headerHeight: headerShown ? headerRow.implicitHeight + 12 : 0

    // ── Sizing ───────────────────────────────────────────────────────
    // The ListView always fills the space between the header and the
    // bottom padding so there is no dead gap.  It scrolls when content
    // exceeds the available height.
    readonly property real listHeight: Math.max(0, maxH - pad * 2 - headerHeight)
    implicitHeight: Math.max(maxH, pad * 2 + headerHeight + listHeight)
    // Width adapts to the widest widget plus the 16 px grip column.
    implicitWidth: contentMaxWidth + 16

    // ── Model ────────────────────────────────────────────────────────
    property var widgetIds: island ? island.panelVisibleWidgets : []

    function currentOrder() {
        let ids = []
        for (let i = 0; i < widgetList.model.count; i++)
            ids.push(widgetList.model.get(i).widgetId)
        return Utils.serializeWidgetList(ids)
    }

    function rebuild(serialized) {
        contentMaxWidth = 0
        widgetList.model.clear()
        const ids = Utils.parseWidgetList(serialized, Catalog.ids())
        for (let i = 0; i < ids.length; i++)
            widgetList.model.append({ widgetId: ids[i] })
    }

    function persistOrder() {
        Plasmoid.configuration.panelWidgets = currentOrder()
    }

    // Rebuild when the config changes — but never during a live drag
    // (the drag itself wrote the config) and never when the incoming
    // order already matches the current model.
    onWidgetIdsChanged: {
        if (dragging) return
        const incoming = Utils.serializeWidgetList(widgetIds)
        if (incoming !== currentOrder()) rebuild(incoming)
    }

    Component.onCompleted: rebuild(Utils.serializeWidgetList(widgetIds))

    // ── Layout ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: pad
        anchors.bottomMargin: pad
        spacing: 0

        // ── Header ───────────────────────────────────────────────────
        Item {
            id: headerRow
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? headerContent.implicitHeight : 0
            visible: panel.headerShown

            Row {
                id: headerContent
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Kirigami.Icon {
                    width: 28; height: 28
                    source: island.activeMode === 0
                        ? "media-playback-start"
                        : (island.notificationIcon || "notifications")
                    color: island.textPrimary
                }

                Column {
                    width: parent.width - 40
                    spacing: 2

                    PlasmaComponents.Label {
                        width: parent.width
                        text: island.activeMode === 0
                            ? (island.mediaDisplayTitle || Tr.t("Music"))
                            : (island.notificationTitle || Tr.t("Notification"))
                        color: island.textPrimary
                        font.pointSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    PlasmaComponents.Label {
                        width: parent.width
                        text: island.activeMode === 0
                            ? (island.mediaDisplayArtist || island.mediaIdentity || "")
                            : (island.notificationBody || island.notificationApp || "")
                        color: island.textSecondary
                        font.pointSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ── Widget list ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: widgetList
                anchors.fill: parent
                spacing: panel.gap
                clip: true

                model: ListModel {}

                moveDisplaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Item {
                    id: row
                    width: widgetList.width
                    height: Math.max(delegateContent.height, 1)
                    property int delegateIndex: index

                    // Grip: drag handle only.  Slider drags on the widget
                    // body are never swallowed by reordering.
                    Rectangle {
                        id: grip
                        width: 16
                        height: parent.height
                        color: gripMouse.pressed
                            ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        visible: panel.showGrips || gripMouse.containsMouse

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: "⋮⋮"
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize: 10
                        }

                        MouseArea {
                            id: gripMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: delegateContent
                            drag.axis: Drag.YAxis

                            onPressed: {
                                panel.dragging = true
                                delegateContent.z = 10
                            }

                            onPositionChanged: {
                                if (!drag.active) return
                                const center = delegateContent.mapToItem(
                                    widgetList,
                                    delegateContent.width / 2,
                                    delegateContent.height / 2)
                                const target = widgetList.indexAt(center.x, center.y)
                                if (target >= 0 && target !== row.delegateIndex)
                                    widgetList.model.move(row.delegateIndex, target)
                            }

                            onReleased: {
                                delegateContent.y = 0
                                delegateContent.z = 0
                                panel.dragging = false
                                panel.persistOrder()
                            }
                        }
                    }

                    // Widget body — sized to the loaded widget's implicitHeight.
                    Item {
                        id: delegateContent
                        anchors.left: grip.right
                        anchors.right: parent.right
                        height: widgetLoader.item ? widgetLoader.item.implicitHeight : 0

                        Loader {
                            id: widgetLoader
                            anchors.fill: parent
                            source: Catalog.fileFor(model.widgetId)
                            onLoaded: {
                                item.island = panel.island
                                if (item.implicitWidth > panel.contentMaxWidth)
                                    panel.contentMaxWidth = item.implicitWidth
                            }
                        }
                    }
                }
            }

            // ── Empty state ──────────────────────────────────────────
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: widgetList.count === 0

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("No widgets yet")
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)
                    font.pointSize: 11
                    opacity: 0.75
                }

                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "configure"
                    width: 22; height: 22
                    color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const action = Plasmoid.internalAction("configure")
                            if (action) action.trigger()
                        }
                    }
                }
            }
        }
    }
}
