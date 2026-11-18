// One compact metric: icon, label, value, a small progress bar.
// The bar and value turn red above the warning level.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: m
    property string iconName
    property string label
    property string value
    property string detail
    property real ratio: 0          // 0..1
    property real warnAt: 0.85
    readonly property bool hot: ratio >= warnAt
    signal clicked()
    Style { id: st }

    ColumnLayout {
        anchors.fill: parent
        spacing: 3
        RowLayout {
            spacing: 6
            Kirigami.Icon { source: m.iconName; isMask: true; color: m.hot ? st.accent : st.muted; Layout.preferredWidth: 14; Layout.preferredHeight: 14 }
            Text { text: m.label; color: st.muted; font.pixelSize: 12; font.letterSpacing: 1.5 }
            Item { Layout.fillWidth: true }
            Text { text: m.detail; color: st.muted; font.family: st.mono; font.pixelSize: 10 }
        }
        Text { text: m.value; color: m.hot ? st.accent : st.text; font.family: st.mono; font.pixelSize: 17 }
        Rectangle {
            Layout.fillWidth: true; height: 3; radius: 1.5
            color: st.faint
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, m.ratio)); height: parent.height; radius: 1.5
                color: m.hot ? st.accent : st.text
                opacity: m.hot ? 1 : 0.75
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: m.clicked() }
}
