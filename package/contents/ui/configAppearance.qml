import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Translator.js" as Tr
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Property Aliases for Plasmoid Configuration Mapping
    property alias cfg_expandedWidthMusic: musicWidthSpin.value
    property alias cfg_expandedWidthNotification: notifWidthSpin.value
    property alias cfg_expandedWidthStatus: statusWidthSpin.value
    property alias cfg_expandedHeight: heightSpin.value
    property alias cfg_cornerRadius: radiusSpin.value
    property alias cfg_popupGap: gapSpin.value

    property alias cfg_followSystemTheme: themeSwitch.checked
    property alias cfg_backgroundEnabled: bgSwitch.checked
    property alias cfg_borderEnabled: borderSwitch.checked
    property alias cfg_backgroundOpacity: opacitySlider.value
    property string cfg_backgroundColor: "#0b1622"
    property string cfg_accentColor: "#8d5cff"
    property string cfg_idleDotColor: "#55e36a"
    property string cfg_sharingDotColor: "#ffaa33"

    property string cfg_compactOrder: "content-time-fps"
    property alias cfg_moduleSeparators: separatorsSwitch.checked

    property alias cfg_animationsEnabled: animationsSwitch.checked
    property alias cfg_animationSpeed: speedSlider.value

    Kirigami.FormLayout {
        // Section 1: Dimensions & Shape
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Dimensions & Shape")
        }

        QQC2.SpinBox {
            id: radiusSpin
            Kirigami.FormData.label: Tr.t("Corner radius:")
            from: 6; to: 28; stepSize: 1
        }

        QQC2.SpinBox {
            id: gapSpin
            Kirigami.FormData.label: Tr.t("Distance from panel:")
            from: 0; to: 120; stepSize: 2
        }

        QQC2.Switch {
            id: showAdvancedSpinboxes
            Kirigami.FormData.label: Tr.t("Manual dimensions:")
            text: Tr.t("Show pixel width & height spinboxes")
            checked: false
        }

        QQC2.SpinBox {
            id: musicWidthSpin
            Kirigami.FormData.label: Tr.t("Music panel width:")
            visible: showAdvancedSpinboxes.checked
            from: 280; to: 680; stepSize: 10
        }

        QQC2.SpinBox {
            id: notifWidthSpin
            Kirigami.FormData.label: Tr.t("Notification panel width:")
            visible: showAdvancedSpinboxes.checked
            from: 260; to: 640; stepSize: 10
        }

        QQC2.SpinBox {
            id: statusWidthSpin
            Kirigami.FormData.label: Tr.t("Status panel width:")
            visible: showAdvancedSpinboxes.checked
            from: 240; to: 600; stepSize: 10
        }

        QQC2.SpinBox {
            id: heightSpin
            Kirigami.FormData.label: Tr.t("Expanded panel height:")
            visible: showAdvancedSpinboxes.checked
            from: 64; to: 160; stepSize: 2
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: Tr.t("Controls corner rounding, distance from panel, and optional custom pixel dimensions.")
        }

        // Section 2: Colors & Theme
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Theme & Colors")
        }

        QQC2.Switch {
            id: themeSwitch
            Kirigami.FormData.label: Tr.t("Plasma desktop theme:")
            text: Tr.t("Follow system desktop theme colors")
        }

        QQC2.Switch {
            id: bgSwitch
            Kirigami.FormData.label: Tr.t("Expanded background:")
            enabled: !themeSwitch.checked
            text: Tr.t("Fill the expanded island panel background")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Background color:")
            enabled: !themeSwitch.checked && bgSwitch.checked
            spacing: 6

            Repeater {
                model: ["#0b1622", "#000000", "#101418", "#1a1030", "#0e1f1a", "#241016"]
                ColorSwatch {
                    swatch: modelData
                    selected: page.cfg_backgroundColor.toLowerCase() === modelData
                    onPicked: page.cfg_backgroundColor = modelData
                }
            }
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Custom background (hex):")
            enabled: !themeSwitch.checked && bgSwitch.checked
            text: page.cfg_backgroundColor
            inputMask: "\\#HHHHHH"
            onEditingFinished: if (text.length === 7) page.cfg_backgroundColor = text
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Background opacity:")
            enabled: !themeSwitch.checked && bgSwitch.checked
            spacing: 8

            QQC2.Slider {
                id: opacitySlider
                from: 20; to: 100; stepSize: 1
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
            QQC2.Label { text: opacitySlider.value + "%" }
        }

        QQC2.Switch {
            id: borderSwitch
            Kirigami.FormData.label: Tr.t("Border outline:")
            enabled: bgSwitch.checked
            text: Tr.t("Show a subtle glass border around the expanded island")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Accent color:")
            spacing: 6

            Repeater {
                model: ["#8d5cff", "#2da6e8", "#55e36a", "#ff4f6f", "#ffaa33", "#ffffff"]
                ColorSwatch {
                    swatch: modelData
                    selected: page.cfg_accentColor.toLowerCase() === modelData
                    onPicked: page.cfg_accentColor = modelData
                }
            }
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Custom accent (hex):")
            text: page.cfg_accentColor
            inputMask: "\\#HHHHHH"
            onEditingFinished: if (text.length === 7) page.cfg_accentColor = text
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Idle dot color:")
            spacing: 6

            Repeater {
                model: ["#55e36a", "#2da6e8", "#8d5cff", "#ffffff", "#ffaa33"]
                ColorSwatch {
                    swatch: modelData
                    selected: page.cfg_idleDotColor.toLowerCase() === modelData
                    onPicked: page.cfg_idleDotColor = modelData
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Sharing dot color:")
            spacing: 6

            Repeater {
                model: ["#ffaa33", "#ff4f6f", "#ffd233", "#2da6e8", "#ffffff"]
                ColorSwatch {
                    swatch: modelData
                    selected: page.cfg_sharingDotColor.toLowerCase() === modelData
                    onPicked: page.cfg_sharingDotColor = modelData
                }
            }
        }

        // Section 3: Compact Layout Ordering
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Capsule Layout & Ordering")
        }

        QQC2.ComboBox {
            id: orderCombo
            Kirigami.FormData.label: Tr.t("Compact order:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: Tr.t("Content · Time · FPS"), value: "content-time-fps" },
                { text: Tr.t("Time · Content · FPS"), value: "time-content-fps" },
                { text: Tr.t("Content · FPS · Time"), value: "content-fps-time" },
                { text: Tr.t("FPS · Content · Time"), value: "fps-content-time" },
                { text: Tr.t("Time · FPS · Content"), value: "time-fps-content" },
                { text: Tr.t("FPS · Time · Content"), value: "fps-time-content" }
            ]
            onActivated: page.cfg_compactOrder = currentValue
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_compactOrder))
        }

        QQC2.Switch {
            id: separatorsSwitch
            Kirigami.FormData.label: Tr.t("Module dividers:")
            text: Tr.t("Show “/” separators between capsule modules")
        }

        // Section 4: Motion & Animation
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Motion & Animations")
        }

        QQC2.Switch {
            id: animationsSwitch
            Kirigami.FormData.label: Tr.t("Animations:")
            text: Tr.t("Enable dynamic transitions, expansions, and audio pulses")
        }

        RowLayout {
            Kirigami.FormData.label: Tr.t("Animation speed:")
            enabled: animationsSwitch.checked
            spacing: 8

            QQC2.Slider {
                id: speedSlider
                from: 40; to: 200; stepSize: 10
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
            QQC2.Label { text: speedSlider.value + "%" }
        }

        // Reusable Color Swatch Component
        component ColorSwatch: Rectangle {
            property string swatch: "#ffffff"
            property bool selected: false
            signal picked()

            width: Kirigami.Units.gridUnit * 1.6
            height: width
            radius: width / 2
            color: swatch
            border.width: selected ? 3 : 1
            border.color: selected ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.3)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.picked()
            }
        }
    }
}
