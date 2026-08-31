import QtQuick

// The five-bar equaliser. Extracted from main.qml so the expanded media view
// and the panel's media widget can both use it.
Row {
    id: bars

    property bool playing: false
    property color barColor: "white"
    property bool animate: true

    spacing: 5
    width: 44
    height: 34

    Repeater {
        model: [18, 27, 14, 24, 20]

        Rectangle {
            id: bar

            width: 4
            height: modelData
            y: (parent.height - height) / 2
            radius: 3
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(bars.barColor, 1.15) }
                GradientStop { position: 1.0; color: bars.barColor }
            }
            opacity: bars.playing ? 0.9 : 0.55
            transformOrigin: Item.Center
            transform: Scale {
                origin.x: bar.width / 2
                origin.y: bar.height / 2
                xScale: 1
                yScale: bars.playing ? 0.95 : 0.45

                SequentialAnimation on yScale {
                    running: bars.playing && bars.animate
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.40 + ((index * 17) % 45) / 100
                        duration: 260 + index * 45
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0.95
                        duration: 260 + index * 45
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
