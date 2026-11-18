// Obsidian Glass design tokens, shared by every Frost widget.
import QtQuick

QtObject {
    readonly property color accent: "#F21D43"
    readonly property color accentSoft: Qt.rgba(242/255, 29/255, 67/255, 0.22)
    readonly property color text: "#F2F2F5"
    readonly property color muted: "#9A9AA6"
    readonly property color faint: Qt.rgba(1, 1, 1, 0.08)
    readonly property color glass: Qt.rgba(18/255, 18/255, 22/255, 0.48)
    readonly property color glassSoft: Qt.rgba(28/255, 28/255, 34/255, 0.38)
    readonly property color border: Qt.rgba(1, 1, 1, 0.12)
    readonly property int radius: 18
    readonly property int pad: 18
    readonly property string mono: "JetBrains Mono"
}
