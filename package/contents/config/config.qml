import QtQuick
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid
import "../ui/Translator.js" as Tr

ConfigModel {
    ConfigCategory {
        name: Tr.t("Appearance & Behavior")
        icon: "preferences-desktop-theme"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: Tr.t("Modules & Features")
        icon: "plugins"
        source: "configModules.qml"
    }
    ConfigCategory {
        name: Tr.t("Quick Control Panel")
        icon: "dashboard-show"
        source: "configPanel.qml"
    }
}
