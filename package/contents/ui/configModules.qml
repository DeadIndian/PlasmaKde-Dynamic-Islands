import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Translator.js" as Tr
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // 1. Feature Enable Toggles Aliases
    property alias cfg_enableMedia: mediaSwitch.checked
    property alias cfg_enableNotifications: notifSwitch.checked
    property alias cfg_enableTimer: timerSwitch.checked
    property alias cfg_enableKeyboard: keyboardSwitch.checked
    property alias cfg_enableDownloads: downloadsSwitch.checked
    property alias cfg_enableScreenSharing: sharingSwitch.checked
    property alias cfg_ideBuildEnabled: ideSwitch.checked
    property alias cfg_enableSysMonitor: sysMonSwitch.checked

    // 2. Media Settings Aliases
    property alias cfg_mediaTitleVisible: titleVisibleSwitch.checked
    property alias cfg_mediaTitleSize: titleSizeSpin.value
    property alias cfg_mediaTitleScroll: titleScrollSwitch.checked
    property alias cfg_mediaArtistVisible: artistVisibleSwitch.checked
    property alias cfg_mediaArtistSize: artistSizeSpin.value
    property alias cfg_mediaArtistScroll: artistScrollSwitch.checked
    property alias cfg_mediaArtistHideIfSame: artistHideSameSwitch.checked
    property alias cfg_mediaShowArt: artSwitch.checked
    property alias cfg_mediaArtSize: artSizeSpin.value
    property alias cfg_mediaArtRadius: artRadiusSpin.value
    property alias cfg_mediaCapsuleArtSize: capsuleArtSpin.value
    property alias cfg_mediaShowSeekBar: seekSwitch.checked
    property alias cfg_mediaSeekBarHeight: seekHeightSpin.value
    property alias cfg_mediaShowTimes: timesSwitch.checked
    property alias cfg_mediaShowSoundBars: soundBarsSwitch.checked
    property alias cfg_mediaShowControls: controlsSwitch.checked
    property alias cfg_mediaCapsuleScale: capsuleScaleSlider.value
    property alias cfg_mediaExpandedScale: expandedScaleSlider.value
    property string cfg_mediaTitleFont: ""
    property string cfg_mediaTitleColor: ""
    property int cfg_mediaTitleWeight: 500
    property string cfg_mediaArtistFont: ""
    property string cfg_mediaArtistColor: ""
    property int cfg_mediaArtistWeight: 400
    property string cfg_mediaTitleFormat: "{title}"
    property string cfg_mediaArtistFormat: "{artist}"

    // 3. Notifications Settings Aliases
    property alias cfg_notificationBodyLines: bodyLinesSpin.value

    // 4. Clock & Date Settings Aliases
    property alias cfg_use24HourClock: clock24Switch.checked
    property alias cfg_showSeconds: secondsSwitch.checked
    property alias cfg_showDate: dateSwitch.checked
    property string cfg_clockDatePosition: "below"
    property string cfg_clockDateFormat: "ddd_mmm_d"
    property string cfg_clockCustomFormat: "ddd, MMM d"

    // 5. Timer Settings Aliases
    property alias cfg_timerDefaultMinutes: timerDefaultMinSpin.value
    property alias cfg_timerDefaultSeconds: timerDefaultSecSpin.value
    property alias cfg_timerTakeOverClock: timerTakeoverSwitch.checked
    property alias cfg_timerNotifyOnFinish: timerNotifySwitch.checked

    // 6. System Monitor & FPS Settings Aliases
    property alias cfg_sysMonitorInterval: sysIntervalSpin.value
    property alias cfg_showCpuStat: cpuStatSwitch.checked
    property alias cfg_showRamStat: ramStatSwitch.checked
    property alias cfg_showTempStat: tempStatSwitch.checked
    property bool cfg_sysMonitorRotateClock: false
    property alias cfg_showFps: fpsSwitch.checked
    property string cfg_fpsStyle: "accent"
    property string cfg_sysMonitorStyle: "lines"

    readonly property var weightOptions: [
        { text: Tr.t("Light"), value: 300 },
        { text: Tr.t("Normal"), value: 400 },
        { text: Tr.t("Medium"), value: 500 },
        { text: Tr.t("DemiBold"), value: 600 },
        { text: Tr.t("Bold"), value: 700 }
    ]

    Kirigami.FormLayout {
        // ==========================================
        // SECTION 1: Active Modules Overview
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Dynamic Island Modules")
        }

        QQC2.Switch { id: mediaSwitch;     Kirigami.FormData.label: Tr.t("Media Player:");    text: Tr.t("Now playing track details, album art, & playback controls") }
        QQC2.Switch { id: notifSwitch;    Kirigami.FormData.label: Tr.t("Notifications:");   text: Tr.t("Expand island on incoming system notifications") }
        QQC2.Switch { id: timerSwitch;    Kirigami.FormData.label: Tr.t("Countdown Timer:"); text: Tr.t("Interactive timer in widget panel & clock takeover") }
        QQC2.Switch { id: sysMonSwitch;   Kirigami.FormData.label: Tr.t("System Monitor:");  text: Tr.t("Realtime CPU, RAM, & Temperature stats in widget panel") }
        QQC2.Switch { id: keyboardSwitch; Kirigami.FormData.label: Tr.t("Keyboard Layout:"); text: Tr.t("Announce layout changes") }
        QQC2.Switch { id: downloadsSwitch;Kirigami.FormData.label: Tr.t("Downloads:");       text: Tr.t("Show active file download progress") }
        QQC2.Switch { id: sharingSwitch;  Kirigami.FormData.label: Tr.t("Screen Capture:");  text: Tr.t("Screen recording and presentation indicator") }
        QQC2.Switch { id: ideSwitch;      Kirigami.FormData.label: Tr.t("IDE Build Status:"); text: Tr.t("IntelliJ IDEA build completion popup") }

        // ==========================================
        // SECTION 2: Media Player Customization
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("🎵 Media Player Options")
            visible: mediaSwitch.checked
        }

        QQC2.Switch {
            id: titleVisibleSwitch
            Kirigami.FormData.label: Tr.t("Title line:")
            visible: mediaSwitch.checked
            text: Tr.t("Show track title")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Title size & weight:")
            visible: mediaSwitch.checked && titleVisibleSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: titleSizeSpin; from: 6; to: 40; stepSize: 1 }
            QQC2.Label { text: Tr.t("pt") }

            QQC2.ComboBox {
                id: titleWeightCombo
                textRole: "text"
                valueRole: "value"
                model: page.weightOptions
                onActivated: page.cfg_mediaTitleWeight = currentValue
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_mediaTitleWeight))
            }
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Title font:")
            visible: mediaSwitch.checked && titleVisibleSwitch.checked
            placeholderText: Tr.t("System default font")
            text: page.cfg_mediaTitleFont
            onEditingFinished: page.cfg_mediaTitleFont = text
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Title color (hex):")
            visible: mediaSwitch.checked && titleVisibleSwitch.checked
            placeholderText: Tr.t("System default color")
            text: page.cfg_mediaTitleColor
            onEditingFinished: page.cfg_mediaTitleColor = text
        }

        QQC2.Switch {
            id: titleScrollSwitch
            Kirigami.FormData.label: Tr.t("Long titles:")
            visible: mediaSwitch.checked && titleVisibleSwitch.checked
            text: Tr.t("Scroll long track titles smoothly")
        }

        QQC2.Switch {
            id: artistVisibleSwitch
            Kirigami.FormData.label: Tr.t("Artist line:")
            visible: mediaSwitch.checked
            text: Tr.t("Show artist name")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Artist size & weight:")
            visible: mediaSwitch.checked && artistVisibleSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: artistSizeSpin; from: 6; to: 40; stepSize: 1 }
            QQC2.Label { text: Tr.t("pt") }

            QQC2.ComboBox {
                id: artistWeightCombo
                textRole: "text"
                valueRole: "value"
                model: page.weightOptions
                onActivated: page.cfg_mediaArtistWeight = currentValue
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_mediaArtistWeight))
            }
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Artist font:")
            visible: mediaSwitch.checked && artistVisibleSwitch.checked
            placeholderText: Tr.t("System default font")
            text: page.cfg_mediaArtistFont
            onEditingFinished: page.cfg_mediaArtistFont = text
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Artist color (hex):")
            visible: mediaSwitch.checked && artistVisibleSwitch.checked
            placeholderText: Tr.t("System default color")
            text: page.cfg_mediaArtistColor
            onEditingFinished: page.cfg_mediaArtistColor = text
        }

        QQC2.Switch {
            id: artistScrollSwitch
            Kirigami.FormData.label: Tr.t("Long artists:")
            visible: mediaSwitch.checked && artistVisibleSwitch.checked
            text: Tr.t("Scroll long artist names smoothly")
        }

        QQC2.Switch {
            id: artistHideSameSwitch
            Kirigami.FormData.label: Tr.t("Duplicate artist:")
            visible: mediaSwitch.checked && artistVisibleSwitch.checked
            text: Tr.t("Hide artist if it matches the track title")
        }

        QQC2.Switch {
            id: artSwitch
            Kirigami.FormData.label: Tr.t("Album art:")
            visible: mediaSwitch.checked
            text: Tr.t("Display cover art thumbnail")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Album art size & radius:")
            visible: mediaSwitch.checked && artSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: artSizeSpin; from: 24; to: 96; stepSize: 2 }
            QQC2.Label { text: Tr.t("px size") }

            QQC2.SpinBox { id: artRadiusSpin; from: 0; to: 48; stepSize: 1 }
            QQC2.Label { text: Tr.t("px radius") }
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Capsule art size:")
            visible: mediaSwitch.checked && artSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: capsuleArtSpin; from: 0; to: 28; stepSize: 1 }
            QQC2.Label { text: Tr.t("px (0 hides in capsule)") }
        }

        QQC2.Switch {
            id: seekSwitch
            Kirigami.FormData.label: Tr.t("Seek bar:")
            visible: mediaSwitch.checked
            text: Tr.t("Show track progress bar and click to seek")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Seek bar height:")
            visible: mediaSwitch.checked && seekSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: seekHeightSpin; from: 1; to: 12; stepSize: 1 }
            QQC2.Label { text: Tr.t("px") }
        }

        QQC2.Switch {
            id: timesSwitch
            Kirigami.FormData.label: Tr.t("Playback times:")
            visible: mediaSwitch.checked && seekSwitch.checked
            text: Tr.t("Show elapsed and total track duration")
        }

        QQC2.Switch {
            id: soundBarsSwitch
            Kirigami.FormData.label: Tr.t("Animated equalizer:")
            visible: mediaSwitch.checked
            text: Tr.t("Show animated sound bars when music is playing")
        }

        QQC2.Switch {
            id: controlsSwitch
            Kirigami.FormData.label: Tr.t("Playback controls:")
            visible: mediaSwitch.checked
            text: Tr.t("Show previous, play/pause, and next buttons")
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Title template:")
            visible: mediaSwitch.checked
            text: page.cfg_mediaTitleFormat
            onEditingFinished: page.cfg_mediaTitleFormat = text
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Artist template:")
            visible: mediaSwitch.checked
            text: page.cfg_mediaArtistFormat
            onEditingFinished: page.cfg_mediaArtistFormat = text
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Capsule media scale:")
            visible: mediaSwitch.checked
            spacing: 8

            QQC2.Slider {
                id: capsuleScaleSlider
                from: 50; to: 150; stepSize: 1
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
            QQC2.Label { text: capsuleScaleSlider.value + "%" }
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Expanded media scale:")
            visible: mediaSwitch.checked
            spacing: 8

            QQC2.Slider {
                id: expandedScaleSlider
                from: 50; to: 200; stepSize: 1
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
            QQC2.Label { text: expandedScaleSlider.value + "%" }
        }

        // ==========================================
        // SECTION 3: Clock & Date Options
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("⏰ Clock & Date Options")
        }

        QQC2.Switch {
            id: clock24Switch
            Kirigami.FormData.label: Tr.t("Time format:")
            text: Tr.t("Use 24-hour clock")
        }

        QQC2.Switch {
            id: secondsSwitch
            Kirigami.FormData.label: Tr.t("Seconds display:")
            text: Tr.t("Show seconds counter in time readout")
        }

        QQC2.Switch {
            id: dateSwitch
            Kirigami.FormData.label: Tr.t("Date display:")
            text: Tr.t("Show day and date next to time")
        }

        QQC2.ComboBox {
            id: datePositionCombo
            Kirigami.FormData.label: Tr.t("Date position:")
            enabled: dateSwitch.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Below time"), value: "below" },
                { text: Tr.t("Above time"), value: "above" },
                { text: Tr.t("Beside time (Right)"), value: "beside_right" },
                { text: Tr.t("Beside time (Left)"), value: "beside_left" }
            ]
            onActivated: page.cfg_clockDatePosition = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_clockDatePosition))
        }

        QQC2.ComboBox {
            id: dateFormatCombo
            Kirigami.FormData.label: Tr.t("Date format:")
            enabled: dateSwitch.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Short (Sat, Aug 29)"), value: "ddd_mmm_d" },
                { text: Tr.t("Medium (Saturday, Aug 29)"), value: "dddd_mmm_d" },
                { text: Tr.t("Long (Saturday, August 29, 2026)"), value: "dddd_mmmm_d_yyyy" },
                { text: Tr.t("Compact (Sat 29)"), value: "ddd_d" },
                { text: Tr.t("Day Only (Saturday)"), value: "dddd" },
                { text: Tr.t("Date Only (Aug 29)"), value: "mmm_d" },
                { text: Tr.t("ISO (2026-08-29)"), value: "iso" },
                { text: Tr.t("Numeric EU (29/08/2026)"), value: "numeric_eu" },
                { text: Tr.t("Numeric US (08/29/2026)"), value: "numeric_us" },
                { text: Tr.t("Custom..."), value: "custom" }
            ]
            onActivated: page.cfg_clockDateFormat = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_clockDateFormat))
        }

        QQC2.TextField {
            id: customFormatField
            Kirigami.FormData.label: Tr.t("Custom date format:")
            visible: dateSwitch.checked && page.cfg_clockDateFormat === "custom"
            text: page.cfg_clockCustomFormat
            placeholderText: "ddd, MMM d"
            onEditingFinished: page.cfg_clockCustomFormat = text
        }

        // ==========================================
        // SECTION 4: Countdown Timer Options
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("⏱️ Countdown Timer Options")
            visible: timerSwitch.checked
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Default duration:")
            visible: timerSwitch.checked
            spacing: 8

            QQC2.SpinBox { id: timerDefaultMinSpin; from: 0; to: 600; stepSize: 1 }
            QQC2.Label { text: Tr.t("min") }

            QQC2.SpinBox { id: timerDefaultSecSpin; from: 0; to: 59; stepSize: 5 }
            QQC2.Label { text: Tr.t("sec") }
        }

        QQC2.Switch {
            id: timerTakeoverSwitch
            Kirigami.FormData.label: Tr.t("Capsule takeover:")
            visible: timerSwitch.checked
            text: Tr.t("Show live countdown in capsule clock while timer is active")
        }

        QQC2.Switch {
            id: timerNotifySwitch
            Kirigami.FormData.label: Tr.t("Timer finish alert:")
            visible: timerSwitch.checked
            text: Tr.t("Send desktop notification when countdown finishes")
        }

        // ==========================================
        // SECTION 5: Notifications Options
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("🔔 Notifications Options")
            visible: notifSwitch.checked
        }

        QQC2.SpinBox {
            id: bodyLinesSpin
            Kirigami.FormData.label: Tr.t("Max body lines:")
            visible: notifSwitch.checked
            from: 1; to: 4; stepSize: 1
        }

        // ==========================================
        // SECTION 6: System Monitor & FPS Counter Options
        // ==========================================
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("💻 System Monitor & FPS Counter")
            visible: sysMonSwitch.checked || fpsSwitch.checked
        }

        QQC2.ComboBox {
            id: sysStyleCombo
            Kirigami.FormData.label: Tr.t("Stat display style:")
            visible: sysMonSwitch.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Horizontal progress bars"), value: "lines" },
                { text: Tr.t("Circular donut / pie charts"), value: "donuts" },
                { text: Tr.t("Compact glass value pills"), value: "badges" },
                { text: Tr.t("Mini stat grid cards"), value: "cards" }
            ]
            onActivated: page.cfg_sysMonitorStyle = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_sysMonitorStyle))
        }

        QQC2.ComboBox {
            id: statsLocationCombo
            objectName: "statsLocationCombo"
            Kirigami.FormData.label: Tr.t("Stats location:")
            visible: sysMonSwitch.checked
            textRole: "text"
            model: [
                { text: Tr.t("Widget panel only — capsule keeps time & events") },
                { text: Tr.t("Also rotate through the capsule clock") }
            ]
            // Two fixed entries, so index maps straight onto the bool. indexOfValue
            // is not reliable for boolean valueRole, hence the explicit mapping.
            onActivated: page.cfg_sysMonitorRotateClock = (currentIndex === 1)
            Component.onCompleted: currentIndex = page.cfg_sysMonitorRotateClock ? 1 : 0
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Stats rotation interval:")
            visible: sysMonSwitch.checked && page.cfg_sysMonitorRotateClock
            spacing: 8

            QQC2.SpinBox { id: sysIntervalSpin; from: 3; to: 30; stepSize: 1 }
            QQC2.Label { text: Tr.t("seconds") }
        }

        QQC2.Switch {
            id: cpuStatSwitch
            Kirigami.FormData.label: Tr.t("Individual stats:")
            visible: sysMonSwitch.checked
            text: Tr.t("CPU load percentage")
        }

        QQC2.Switch {
            id: ramStatSwitch
            visible: sysMonSwitch.checked
            text: Tr.t("RAM usage percentage")
        }

        QQC2.Switch {
            id: tempStatSwitch
            visible: sysMonSwitch.checked
            text: Tr.t("CPU temperature")
        }

        QQC2.Switch {
            id: fpsSwitch
            Kirigami.FormData.label: Tr.t("FPS counter:")
            text: Tr.t("Permanently show frames-per-second next to the clock")
        }

        QQC2.ComboBox {
            id: fpsStyleCombo
            Kirigami.FormData.label: Tr.t("FPS badge style:")
            visible: fpsSwitch.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Accent badge (e.g. 60 fps)"), value: "accent" },
                { text: Tr.t("Match clock font (e.g. 60)"), value: "plain" }
            ]
            onActivated: page.cfg_fpsStyle = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_fpsStyle))
        }
    }
}
