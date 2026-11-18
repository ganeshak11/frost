/*
    Frost splash: shown between logging in and the desktop appearing.
    Black screen, the day in large spaced letters, the date in red, a thin red
    line that fills as Plasma starts, and a welcome line. Matches Chronos.
*/
import QtQuick
import org.kde.coreaddons as KCoreAddons

Rectangle {
    id: root
    color: "#000000"
    property int stage            // set by KSplash, 1..6 while Plasma starts

    readonly property date now: new Date()
    KCoreAddons.KUser { id: kuser }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 14
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd").toUpperCase()
            color: "#F2F2F5"
            font.pixelSize: 64
            font.letterSpacing: 10
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "d MMMM yyyy").toUpperCase()
            color: "#F21D43"
            font.pixelSize: 18
            font.letterSpacing: 5
        }
        Item { width: 1; height: 24 }
        Rectangle {   // progress line
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320; height: 2; radius: 1
            color: Qt.rgba(1, 1, 1, 0.12)
            Rectangle {
                height: parent.height; radius: 1
                color: "#F21D43"
                width: parent.width * Math.min(1, Math.max(0.05, root.stage / 6))
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.08 }
        text: "Welcome back, " + (kuser.fullName || kuser.loginName).split(" ")[0]
        color: "#9A9AA6"
        font.pixelSize: 16
        opacity: content.opacity
    }
}
