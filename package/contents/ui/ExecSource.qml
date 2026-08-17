import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: execSource

    Plasma5Support.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
        }
    }

    function run(cmd) {
        if (cmd && cmd.length > 0) {
            // Append '; echo done' to guarantee onNewData fires and clears connectedSources
            const fullCmd = "sh -c " + JSON.stringify(cmd + " ; echo done")
            dataSource.connectSource(fullCmd)
        }
    }
}
