// Level-3 interactive glass: brighter on hover, scales to 0.97 on press,
// red tint and icon when active.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: btn
    property string iconName
    property string label
    property string sublabel
    property bool active: false
    property bool busy: false
    signal clicked()

    Style { id: st }
    radius: 12
    color: active ? st.accentSoft : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
    border.color: active ? Qt.rgba(242/255, 29/255, 67/255, 0.55) : Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Kirigami.Icon {
            source: btn.iconName
            Layout.preferredWidth: 22; Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignHCenter
            color: btn.active ? st.accent : st.text
            isMask: true
            opacity: btn.busy ? 0.4 : 1
        }
        Text {
            text: btn.label
            color: st.text
            font.pixelSize: 13
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: btn.sublabel
            visible: text.length > 0
            color: btn.active ? st.accent : st.muted
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
