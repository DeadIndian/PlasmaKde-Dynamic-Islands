import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "IslandUtils.js" as Utils
import "Translator.js" as Tr
import "WidgetCatalog.js" as Catalog

// The floating widget panel. Widget ids come from `island.panelVisibleWidgets`
// (already filtered by module availability); the ListView's order is the live
// order, persisted to panelWidgets after a drag. `island` is supplied by the
// Loader in main.qml so every widget receives an explicit handle.
Item {
    id: panel

    property var island: null
    property bool dragging: false

    readonly property int pad: Plasmoid.configuration.panelPadding
    readonly property int gap: Plasmoid.configuration.panelSpacing
    readonly property int maxH: Plasmoid.configuration.panelMaxHeight
    readonly property bool showGrips: Plasmoid.configuration.panelShowGrips

    // In "always" mode active media/notification content becomes a fixed
    // header, unless a widget already covers it (media widget present).
    readonly property bool headerShown: island && island.panelShowMode === "always"
        && (island.activeMode === 0 || island.activeMode === 2)
        && !(island.activeMode === 0 && island.panelWidgetIds.indexOf("media") !== -1)
    readonly property real headerHeight: headerShown ? headerRow.implicitHeight + 12 : 0
    readonly property real listHeight: widgetList.count === 0 ? 64
        : Math.min(widgetList.contentHeight + gap * Math.max(0, widgetList.count - 1),
            maxH - pad * 2 - headerHeight)
    implicitHeight: pad * 2 + headerHeight + listHeight

    property var widgetIds: island ? island.panelVisibleWidgets : []

    function currentOrder() {
        let ids = []
        for (let i = 0; i < widgetList.model.count; i++) {
            ids.push(widgetList.model.get(i).widgetId)
        }
        return Utils.serializeWidgetList(ids)
    }

    function rebuild(serialized) {
        widgetList.model.clear()
        const ids = Utils.parseWidgetList(serialized, Catalog.ids())
        for (let i = 0; i < ids.length; i++) {
            widgetList.model.append({ widgetId: ids[i] })
        }
    }

    function persistOrder() {
        Plasmoid.configuration.panelWidgets = currentOrder()
    }

    // Rebuild when the config changes, but never while a drag is live (the
    // drag itself wrote the config) and never when the incoming order merely
    // echoes the current model (e.g. an unrelated config write).
    onWidgetIdsChanged: {
        if (dragging) {
            return
        }
        const incoming = Utils.serializeWidgetList(widgetIds)
        if (incoming === currentOrder()) {
            return
        }
        rebuild(incoming)
    }

    Component.onCompleted: rebuild(Utils.serializeWidgetList(widgetIds))

    Column {
        anchors.fill: parent

        // ---- Header (always mode, active content) ----
        Item {
            id: headerRow

            width: parent.width
            height: visible ? headerContent.implicitHeight : 0
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
                    width: 28
                    height: 28
                    source: island.activeMode === 0 ? "media-playback-start"
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

        // ---- Widget list ----
        Item {
            width: parent.width
            height: panel.listHeight

            ListView {
                id: widgetList

                anchors.fill: parent
                spacing: panel.gap
                clip: true
                moveDisplaced: Transition {
                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
                }

                model: ListModel {}

                delegate: Item {
                    id: row

                    width: widgetList.width
                    height: Math.max(content.implicitHeight, 1)
                    property int delegateIndex: index

                    // Grip column: the only drag handle, so slider drags on
                    // the widget body are never swallowed by reordering.
                    Rectangle {
                        id: grip

                        width: 16
                        height: parent.height
                        color: gripMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
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
                            drag.target: content
                            drag.axis: Drag.YAxis

                            onPressed: {
                                panel.dragging = true
                                content.z = 10
                            }

                            onPositionChanged: {
                                if (!gripMouse.drag.active) {
                                    return
                                }
                                const center = content.mapToItem(widgetList, content.width / 2, content.height / 2)
                                const target = widgetList.indexAt(center.x, center.y)
                                if (target >= 0 && target !== row.delegateIndex) {
                                    widgetList.model.move(row.delegateIndex, target)
                                }
                            }

                            onReleased: {
                                content.y = 0
                                content.z = 0
                                panel.dragging = false
                                panel.persistOrder()
                            }
                        }
                    }

                    Item {
                        id: content

                        anchors.left: grip.right
                        anchors.right: parent.right
                        height: row.height

                        Loader {
                            anchors.fill: parent
                            property var island: panel.island
                            source: Catalog.fileFor(model.widgetId)
                        }
                    }
                }
            }

            // ---- Empty state ----
            Item {
                anchors.fill: parent
                visible: widgetList.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

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
                        width: 22
                        height: 22
                        color: island ? island.textSecondary : Qt.rgba(1, 1, 1, 0.7)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const action = Plasmoid.internalAction("configure")
                                if (action) {
                                    action.trigger()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
