import QtQuick
import QtQuick.Window

// Smoke check for the plasmoid config pages.
//
// Guards two regressions:
//
// 1. Scrolling. Plasma's config dialog takes its scroll behaviour from
//    `pageStack.currentItem.flickable` (AppletConfiguration.qml:440). A bare
//    Kirigami.FormLayout root exposes no flickable, so long pages clip with no
//    way to reach the controls at the bottom. Each page must be a KCM.SimpleKCM.
//
// 2. The "Stats location" control in configModules.qml. sysMonitorRotateClock
//    used to be an alias to a Switch; it is now a plain bool driven by a
//    two-entry ComboBox. This catches a leftover reference to the removed Switch
//    id (runtime TypeError, invisible to qmllint) and an inverted index mapping.
//
// configPanel.qml is deliberately not covered: it reads Plasmoid.configuration
// at property-init time, so it cannot load outside a real plasmoid context.
//
// Run: /usr/lib64/qt6/bin/qml -platform offscreen tests/configpages.check.qml
// Exit 0 = pass, 1 = wrong mapping, 2 = QML failed to load, 3 = no item,
//          4 = combo not found, 5 = page does not scroll.
Window {
    width: 600
    height: 400
    visible: true

    Loader {
        id: appearanceLoader
        source: Qt.resolvedUrl("../package/contents/ui/configAppearance.qml")
        onStatusChanged: if (status === Loader.Error) Qt.exit(2)
    }

    Loader {
        id: modulesLoader
        source: Qt.resolvedUrl("../package/contents/ui/configModules.qml")
        onStatusChanged: if (status === Loader.Error) Qt.exit(2)
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            if (!appearanceLoader.item || !modulesLoader.item) {
                Qt.exit(3)
                return
            }

            // 1. Both pages must supply a flickable for the dialog to scroll.
            if (!appearanceLoader.item.flickable || !modulesLoader.item.flickable) {
                console.warn("appearance.flickable=" + appearanceLoader.item.flickable
                    + " modules.flickable=" + modulesLoader.item.flickable)
                Qt.exit(5)
                return
            }

            // 2. Stats location combo maps cleanly onto the bool.
            const page = modulesLoader.item
            const combo = find(page, "statsLocationCombo")
            if (!combo) {
                Qt.exit(4)
                return
            }

            // Default must be panel-only: capsule shows time + event modules.
            const defaultOk = page.cfg_sysMonitorRotateClock === false && combo.currentIndex === 0

            combo.currentIndex = 1
            combo.activated(1)
            const rotateOk = page.cfg_sysMonitorRotateClock === true

            combo.currentIndex = 0
            combo.activated(0)
            const backOk = page.cfg_sysMonitorRotateClock === false

            console.warn("default=" + defaultOk + " rotate=" + rotateOk + " back=" + backOk)
            Qt.exit(defaultOk && rotateOk && backOk ? 0 : 1)
        }

        function find(root, name) {
            const stack = [root]
            while (stack.length > 0) {
                const it = stack.pop()
                if (it.objectName === name) {
                    return it
                }
                for (let i = 0; i < it.children.length; ++i) {
                    stack.push(it.children[i])
                }
            }
            return null
        }
    }
}
