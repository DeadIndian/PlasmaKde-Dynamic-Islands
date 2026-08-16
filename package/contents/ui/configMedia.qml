import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Translator.js" as Tr

Kirigami.FormLayout {
    id: page

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

    readonly property var weightOptions: [
        { text: Tr.t("Light"), value: 300 },
        { text: Tr.t("Normal"), value: 400 },
        { text: Tr.t("Medium"), value: 500 },
        { text: Tr.t("DemiBold"), value: 600 },
        { text: Tr.t("Bold"), value: 700 }
    ]

    // Title line

    QQC2.Switch {
        id: titleVisibleSwitch
        Kirigami.FormData.label: Tr.t("Title line:")
        text: Tr.t("Show the track title")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Title size:")
        enabled: titleVisibleSwitch.checked
        QQC2.SpinBox { id: titleSizeSpin; from: 6; to: 40; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }

    QQC2.ComboBox {
        id: titleWeightCombo
        Kirigami.FormData.label: Tr.t("Title weight:")
        enabled: titleVisibleSwitch.checked
        textRole: "text"
        valueRole: "value"
        model: page.weightOptions
        onActivated: page.cfg_mediaTitleWeight = currentValue
        Component.onCompleted: currentIndex = indexOfValue(page.cfg_mediaTitleWeight)
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Title font:")
        enabled: titleVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaTitleFont
        onEditingFinished: page.cfg_mediaTitleFont = text
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Title colour (hex):")
        enabled: titleVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaTitleColor
        onEditingFinished: page.cfg_mediaTitleColor = text
    }

    QQC2.Switch {
        id: titleScrollSwitch
        Kirigami.FormData.label: Tr.t("Long titles:")
        enabled: titleVisibleSwitch.checked
        text: Tr.t("Scroll instead of trimming with an ellipsis")
    }

    Item { Kirigami.FormData.isSection: true }

    // Artist line

    QQC2.Switch {
        id: artistVisibleSwitch
        Kirigami.FormData.label: Tr.t("Artist line:")
        text: Tr.t("Show the artist")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Artist size:")
        enabled: artistVisibleSwitch.checked
        QQC2.SpinBox { id: artistSizeSpin; from: 6; to: 40; stepSize: 1 }
        QQC2.Label { text: Tr.t("pt") }
    }

    QQC2.ComboBox {
        id: artistWeightCombo
        Kirigami.FormData.label: Tr.t("Artist weight:")
        enabled: artistVisibleSwitch.checked
        textRole: "text"
        valueRole: "value"
        model: page.weightOptions
        onActivated: page.cfg_mediaArtistWeight = currentValue
        Component.onCompleted: currentIndex = indexOfValue(page.cfg_mediaArtistWeight)
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Artist font:")
        enabled: artistVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaArtistFont
        onEditingFinished: page.cfg_mediaArtistFont = text
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Artist colour (hex):")
        enabled: artistVisibleSwitch.checked
        placeholderText: Tr.t("Leave empty to inherit")
        text: page.cfg_mediaArtistColor
        onEditingFinished: page.cfg_mediaArtistColor = text
    }

    QQC2.Switch {
        id: artistScrollSwitch
        Kirigami.FormData.label: Tr.t("Long artists:")
        enabled: artistVisibleSwitch.checked
        text: Tr.t("Scroll instead of trimming with an ellipsis")
    }

    QQC2.Switch {
        id: artistHideSameSwitch
        Kirigami.FormData.label: Tr.t("Duplicates:")
        enabled: artistVisibleSwitch.checked
        text: Tr.t("Hide the artist when it matches the title")
    }

    Item { Kirigami.FormData.isSection: true }

    // Album art

    QQC2.Switch {
        id: artSwitch
        Kirigami.FormData.label: Tr.t("Album art:")
        text: Tr.t("Show cover art")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Art size:")
        enabled: artSwitch.checked
        QQC2.SpinBox { id: artSizeSpin; from: 24; to: 96; stepSize: 2 }
        QQC2.Label { text: Tr.t("px, expanded panel") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Art corners:")
        enabled: artSwitch.checked
        QQC2.SpinBox { id: artRadiusSpin; from: 0; to: 48; stepSize: 1 }
        QQC2.Label { text: Tr.t("px radius") }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Capsule art:")
        enabled: artSwitch.checked
        QQC2.SpinBox { id: capsuleArtSpin; from: 0; to: 28; stepSize: 1 }
        QQC2.Label { text: Tr.t("px, 0 hides it") }
    }

    Item { Kirigami.FormData.isSection: true }

    // Seek bar and extras

    QQC2.Switch {
        id: seekSwitch
        Kirigami.FormData.label: Tr.t("Seek bar:")
        text: Tr.t("Show progress, click to seek")
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Seek bar height:")
        enabled: seekSwitch.checked
        QQC2.SpinBox { id: seekHeightSpin; from: 1; to: 12; stepSize: 1 }
        QQC2.Label { text: Tr.t("px") }
    }

    QQC2.Switch {
        id: timesSwitch
        Kirigami.FormData.label: Tr.t("Times:")
        enabled: seekSwitch.checked
        text: Tr.t("Show elapsed and total either side of the bar")
    }

    QQC2.Switch {
        id: soundBarsSwitch
        Kirigami.FormData.label: Tr.t("Equaliser:")
        text: Tr.t("Show the animated bars")
    }

    QQC2.Switch {
        id: controlsSwitch
        Kirigami.FormData.label: Tr.t("Controls:")
        text: Tr.t("Show previous, play/pause and next")
    }

    Item { Kirigami.FormData.isSection: true }

    // Text templates

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Title text:")
        text: page.cfg_mediaTitleFormat
        onEditingFinished: page.cfg_mediaTitleFormat = text
    }

    QQC2.TextField {
        Kirigami.FormData.label: Tr.t("Artist text:")
        text: page.cfg_mediaArtistFormat
        onEditingFinished: page.cfg_mediaArtistFormat = text
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Available placeholders: {title}, {artist}, {album}, {player}. Anything else is shown as typed.")
    }

    Item { Kirigami.FormData.isSection: true }

    // Scale

    RowLayout {
        Kirigami.FormData.label: Tr.t("Capsule scale:")
        QQC2.Slider {
            id: capsuleScaleSlider
            from: 50; to: 150; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: capsuleScaleSlider.value + "%" }
    }

    RowLayout {
        Kirigami.FormData.label: Tr.t("Expanded scale:")
        QQC2.Slider {
            id: expandedScaleSlider
            from: 50; to: 200; stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: expandedScaleSlider.value + "%" }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        text: Tr.t("Sizes above are multiplied by these, so one set of settings drives both the small capsule and the big panel.")
    }
}
