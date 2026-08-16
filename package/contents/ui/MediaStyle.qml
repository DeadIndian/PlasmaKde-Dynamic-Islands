import QtQuick
import org.kde.plasma.plasmoid

// Resolves the media appearance settings into ready-to-bind values.
// Instantiated once per surface with a different scalePercent, so the capsule
// and the expanded panel share one set of settings at different sizes.
// An empty font family or colour means "inherit", which is why the fallbacks
// are supplied by the instantiator rather than hardcoded here.
QtObject {
    id: style

    property int scalePercent: 100
    property color fallbackPrimary: "white"
    property color fallbackSecondary: Qt.rgba(1, 1, 1, 0.74)

    readonly property real factor: Math.max(0.1, scalePercent / 100)

    readonly property bool titleVisible: Plasmoid.configuration.mediaTitleVisible
    readonly property string titleFont: Plasmoid.configuration.mediaTitleFont
    readonly property int titleSize: scaled(Plasmoid.configuration.mediaTitleSize)
    readonly property int titleWeight: Plasmoid.configuration.mediaTitleWeight
    readonly property color titleColor: Plasmoid.configuration.mediaTitleColor.length > 0
        ? Plasmoid.configuration.mediaTitleColor
        : fallbackPrimary
    readonly property bool titleScroll: Plasmoid.configuration.mediaTitleScroll

    readonly property bool artistVisible: Plasmoid.configuration.mediaArtistVisible
    readonly property string artistFont: Plasmoid.configuration.mediaArtistFont
    readonly property int artistSize: scaled(Plasmoid.configuration.mediaArtistSize)
    readonly property int artistWeight: Plasmoid.configuration.mediaArtistWeight
    readonly property color artistColor: Plasmoid.configuration.mediaArtistColor.length > 0
        ? Plasmoid.configuration.mediaArtistColor
        : fallbackSecondary
    readonly property bool artistScroll: Plasmoid.configuration.mediaArtistScroll
    readonly property bool artistHideIfSame: Plasmoid.configuration.mediaArtistHideIfSame

    readonly property bool showArt: Plasmoid.configuration.mediaShowArt
    readonly property int artSize: scaled(Plasmoid.configuration.mediaArtSize)
    readonly property int artRadius: scaled(Plasmoid.configuration.mediaArtRadius)
    // Not scaled: the compact capsule is a fixed 32px tall, so its art has to
    // stay within that regardless of the expanded panel's scale.
    readonly property int capsuleArtSize: Plasmoid.configuration.mediaCapsuleArtSize

    readonly property bool showSeekBar: Plasmoid.configuration.mediaShowSeekBar
    readonly property int seekBarHeight: scaled(Plasmoid.configuration.mediaSeekBarHeight)
    readonly property bool showTimes: Plasmoid.configuration.mediaShowTimes
    readonly property bool showSoundBars: Plasmoid.configuration.mediaShowSoundBars
    readonly property bool showControls: Plasmoid.configuration.mediaShowControls

    function scaled(base) {
        return Math.max(1, Math.round(base * factor));
    }
}
