// Level-1 floating glass surface: translucent fill, 1px light border,
// a faint inner highlight along the top edge, and a fade-up entrance.
// `shown` lets a widget hide itself (e.g. media when nothing plays); the
// active layout profile can also hide it (General/hidden in its config).
import QtQuick
import org.kde.plasma.plasmoid

Rectangle {
    id: card
    property bool soft: false
    property real shown: 1
    readonly property bool profileHidden: Plasmoid.configuration.hidden === true

    radius: st.radius
    color: soft ? st.glassSoft : st.glass
    border.color: st.border
    border.width: 1
    Style { id: st }

    Rectangle {   // inner highlight
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: card.radius; rightMargin: card.radius }
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    opacity: 0
    visible: opacity > 0.01
    transform: Translate { id: lift; y: 8 }
    Component.onCompleted: {
        opacity = Qt.binding(() => card.profileHidden ? 0 : card.shown)
        lift.y = 0
    }
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
}
