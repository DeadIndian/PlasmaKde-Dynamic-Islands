import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.plasma.components as PlasmaComponents

// Text that fits renders plainly. Text that overflows either elides (default,
// matching the rest of the applet) or scrolls back and forth when `scroll` is
// set. An empty fontFamily inherits the application font.
Item {
    id: control

    property string text: ""
    property bool scroll: false
    property color color: "white"
    property string fontFamily: ""
    property int fontSize: 12
    property int fontWeight: Font.Normal
    property bool animate: true
    property int pauseDuration: 1200
    property int pixelsPerSecond: 30

    readonly property bool overflowing: label.implicitWidth > width
    readonly property bool scrolling: scroll && animate && overflowing && width > 0
    readonly property real scrollDistance: Math.max(0, label.implicitWidth - width)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: overflowing

    layer.enabled: scrolling
    layer.effect: OpacityMask {
        maskSource: Item {
            width: control.width
            height: control.height
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.06; color: "white" }
                    GradientStop { position: 0.94; color: "white" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // Supplies the default font family when fontFamily is left empty.
    FontMetrics {
        id: inheritedFont
    }

    PlasmaComponents.Label {
        id: label

        width: control.scrolling ? implicitWidth : control.width
        height: control.height
        verticalAlignment: Text.AlignVCenter
        text: control.text
        color: control.color
        font.family: control.fontFamily.length > 0 ? control.fontFamily : inheritedFont.font.family
        font.pointSize: control.fontSize
        font.weight: control.fontWeight
        elide: control.scrolling ? Text.ElideNone : Text.ElideRight
    }

    SequentialAnimation {
        running: control.scrolling
        loops: Animation.Infinite

        PauseAnimation { duration: control.pauseDuration }
        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: -control.scrollDistance
            duration: Math.max(1, control.scrollDistance / control.pixelsPerSecond * 1000)
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: control.pauseDuration }
        NumberAnimation {
            target: label
            property: "x"
            from: -control.scrollDistance
            to: 0
            duration: Math.max(1, control.scrollDistance / control.pixelsPerSecond * 1000)
            easing.type: Easing.InOutQuad
        }
    }

    // Leaving scroll mode mid-animation would strand the label off-screen.
    onScrollingChanged: if (!scrolling) label.x = 0
}
