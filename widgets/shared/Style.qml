// Obsidian Glass design tokens, shared by every Frost widget. They follow the
// colour scheme: dark glass with light text under Frost Dark, light glass with
// dark text under Frost Light (see daynight.sh), switching live.
import QtQuick

QtObject {
    property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }
    readonly property bool light: palette.window.hslLightness > 0.5

    readonly property color accent: "#F21D43"
    readonly property color accentSoft: Qt.rgba(242/255, 29/255, 67/255, 0.22)
    readonly property color textOnAccent: "white"                      // text and icons on red
    readonly property color text: light ? "#1D1D22" : "#F2F2F5"
    readonly property color muted: light ? "#62626E" : "#9A9AA6"
    readonly property color faint: light ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08)      // hairlines, quiet fills
    readonly property color hover: light ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12)      // pointer-over fills
    readonly property color subtle: light ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.25)     // "off" dots, muted bars
    readonly property color glass: light ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(18/255, 18/255, 22/255, 0.48)
    readonly property color glassSoft: light ? Qt.rgba(1, 1, 1, 0.68) : Qt.rgba(28/255, 28/255, 34/255, 0.38)
    readonly property color border: light ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color highlight: light ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.08)  // glass top edge
    readonly property color fill: light ? Qt.rgba(29/255, 29/255, 34/255, 0.88) : Qt.rgba(242/255, 242/255, 245/255, 0.9)  // slider levels
    readonly property color textOnFill: light ? "white" : "#1a1a1f"
    readonly property int radius: 18
    readonly property int pad: 18
    readonly property string mono: "JetBrains Mono"
}
