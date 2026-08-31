import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: execSource

    property var queryCallbacks: ({})

    Plasma5Support.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            if (execSource.queryCallbacks[sourceName]) {
                const cb = execSource.queryCallbacks[sourceName]
                delete execSource.queryCallbacks[sourceName]
                const out = (data && data["stdout"]) ? String(data["stdout"]).trim() : ""
                if (cb) cb(out)
            }
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

    function query(cmd, cb) {
        if (cmd && cmd.length > 0) {
            const fullCmd = "sh -c " + JSON.stringify(cmd)
            if (cb) execSource.queryCallbacks[fullCmd] = cb
            dataSource.connectSource(fullCmd)
        }
    }
}
