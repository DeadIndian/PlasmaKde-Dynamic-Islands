import QtQuick
import QtQuick.Window

// Smoke check for NotificationsWidget: loads the real widget against a stub
// island and asserts it renders one row per model entry. Guards the two ways
// the list has silently gone blank before — a broken binding inside the
// Flickable, and the list layout being hidden on a card too short to hold it.
//
// Run: /usr/lib64/qt6/bin/qml -platform offscreen tests/notificationswidget.check.qml
// Exit 0 = pass, 1 = wrong row count, 2 = QML failed to load, 3 = no item.
Window {
    width: 420
    height: 200
    visible: true

    readonly property string widgetUrl:
        Qt.resolvedUrl("../package/contents/ui/widgets/NotificationsWidget.qml")

    ListModel {
        id: fakeModel
        ListElement { summary: "Alpha"; body: "first"; applicationName: "app1"; applicationIconName: "dialog-information"; iconName: "" }
        ListElement { summary: "Beta"; body: "second"; applicationName: "app2"; applicationIconName: "dialog-information"; iconName: "" }
        ListElement { summary: "Gamma"; body: "third"; applicationName: "app3"; applicationIconName: "dialog-information"; iconName: "" }
    }

    QtObject {
        id: stubIsland
        property var notifModel: fakeModel
        property color accent: "#3498db"
        property color textPrimary: "white"
        property color textSecondary: "#aaaaaa"
        property string notificationTitle: "Gamma"
        property string notificationBody: "third"
        function clearAllNotifications() {}
        function dismissNotificationAt(i) {}
        function activateNotificationAt(i) {}
    }

    Loader {
        id: loader
        anchors.fill: parent
        source: widgetUrl
        onStatusChanged: if (status === Loader.Error) Qt.exit(2)
    }

    Binding { target: loader.item; property: "island"; value: stubIsland; when: loader.status === Loader.Ready }
    Binding { target: loader.item; property: "spanW"; value: 3; when: loader.status === Loader.Ready }
    Binding { target: loader.item; property: "spanH"; value: 2; when: loader.status === Loader.Ready }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            if (!loader.item) {
                Qt.exit(3)
            }
            const rows = countRows(loader.item)
            const ok = loader.item.notifCount === fakeModel.count && rows >= fakeModel.count
            console.warn("notifCount=" + loader.item.notifCount + " renderedRows=" + rows)
            Qt.exit(ok ? 0 : 1)
        }

        // Walks the tree for Flickables (the list container) and counts the
        // visible, text-sized items inside them. `visible` is effective in Qt
        // Quick, so rows under a hidden layout correctly count as zero.
        function countRows(item) {
            let n = 0
            const stack = [item]
            while (stack.length > 0) {
                const it = stack.pop()
                for (let i = 0; i < it.children.length; ++i) {
                    const k = it.children[i]
                    if (k.contentHeight !== undefined && k.contentWidth !== undefined) {
                        n += countDirect(k)
                    }
                    stack.push(k)
                }
            }
            return n
        }

        function countDirect(flick) {
            let n = 0
            const content = flick.contentItem
            if (!content) {
                return 0
            }
            for (let i = 0; i < content.children.length; ++i) {
                const col = content.children[i]
                for (let j = 0; j < col.children.length; ++j) {
                    const row = col.children[j]
                    if (row.visible && row.height > 20 && row.width > 20) {
                        n++
                    }
                }
            }
            return n
        }
    }
}
