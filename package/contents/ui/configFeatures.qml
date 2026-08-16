import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Translator.js" as Tr

Kirigami.FormLayout {
    property alias cfg_enableMedia: mediaSwitch.checked
    property alias cfg_enableKeyboard: keyboardSwitch.checked
    property alias cfg_enableDownloads: downloadsSwitch.checked
    property alias cfg_enableScreenSharing: sharingSwitch.checked
    property alias cfg_ideBuildEnabled: ideSwitch.checked
    property alias cfg_enableTimer: timerSwitch.checked

    QQC2.Switch { id: mediaSwitch;     Kirigami.FormData.label: Tr.t("Media:");          text: Tr.t("Now playing / MPRIS") }
    QQC2.Switch { id: keyboardSwitch;  Kirigami.FormData.label: Tr.t("Keyboard layout:"); text: Tr.t("Announce layout changes") }
    QQC2.Switch { id: downloadsSwitch; Kirigami.FormData.label: Tr.t("Downloads:");      text: Tr.t("Show active jobs / progress") }
    QQC2.Switch { id: sharingSwitch;   Kirigami.FormData.label: Tr.t("Screen sharing:"); text: Tr.t("Show capture / presentation state") }
    QQC2.Switch { id: ideSwitch;       Kirigami.FormData.label: Tr.t("IntelliJ IDEA:");  text: Tr.t("Show build results (e.g. JAR build succeeded)") }
    QQC2.Switch { id: timerSwitch;     Kirigami.FormData.label: Tr.t("Timer:");          text: Tr.t("Countdown timer in the widget panel") }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Module settings pages appear after applying changes.")
    }
}
