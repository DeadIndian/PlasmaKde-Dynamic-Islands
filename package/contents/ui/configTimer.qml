import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../ui/Translator.js" as Tr

Kirigami.FormLayout {
    property alias cfg_enableTimer: timerSwitch.checked
    property alias cfg_timerDefaultMinutes: defaultSpin.value
    property alias cfg_timerDefaultSeconds: defaultSecSpin.value
    property alias cfg_timerTakeOverClock: takeoverSwitch.checked
    property alias cfg_timerNotifyOnFinish: notifySwitch.checked

    QQC2.Switch {
        id: timerSwitch
        Kirigami.FormData.label: Tr.t("Timer module:")
        text: Tr.t("Show the countdown timer widget in the panel")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Default length:")
        enabled: timerSwitch.checked
        spacing: 6

        QQC2.SpinBox { id: defaultSpin; from: 0; to: 600; stepSize: 1 }
        QQC2.Label { text: Tr.t("min") }

        QQC2.SpinBox { id: defaultSecSpin; from: 0; to: 59; stepSize: 5 }
        QQC2.Label { text: Tr.t("sec") }
    }

    QQC2.Switch {
        id: takeoverSwitch
        Kirigami.FormData.label: Tr.t("Countdown:")
        enabled: timerSwitch.checked
        text: Tr.t("Replace the capsule clock with the countdown while it runs")
    }

    QQC2.Switch {
        id: notifySwitch
        Kirigami.FormData.label: Tr.t("Finished:")
        enabled: timerSwitch.checked
        text: Tr.t("Post a desktop notification when the timer ends")
    }
}
