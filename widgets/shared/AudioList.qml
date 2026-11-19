// Sound devices and apps, for the Control Centre and Quick Controls:
//   Output / Input   click one to make it the default (the red one is in use)
//   Apps             each app playing sound, with its own volume (click the
//                    icon to mute it)
// Takes its data from a Levels object.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.ScrollView {
    id: al
    property var levels
    property int maxHeight: 320
    implicitHeight: Math.min(col.implicitHeight, maxHeight)
    contentWidth: availableWidth
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
    Style { id: st }

    component Header: Text {
        color: st.muted; font.pixelSize: 10; font.letterSpacing: 1.5
        Layout.leftMargin: 6; Layout.topMargin: 4
    }
    component Device: Rectangle {
        id: row
        property var dev
        property bool isOutput: true
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 10
        color: dev.default ? st.accentSoft : (dm.containsMouse ? st.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 10
            Kirigami.Icon {
                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                isMask: true; color: row.dev.default ? st.accent : st.text
                source: row.dev.bt ? "audio-headphones" : row.isOutput ? "audio-speakers" : "audio-input-microphone"
            }
            Text { text: row.dev.desc; color: st.text; font.pixelSize: 13; font.weight: row.dev.default ? Font.DemiBold : Font.Normal
                   elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
            Text { visible: row.dev.default; text: row.dev.muted ? "Muted" : Math.round(row.dev.vol * 100) + "%"
                   color: st.accent; font.pixelSize: 11; font.family: st.mono }
        }
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (!row.dev.default) al.levels.setDefault(row.isOutput, row.dev.name) }
    }

    ColumnLayout {
        id: col
        width: al.availableWidth
        spacing: 3

        Header { text: "OUTPUT" }
        Repeater { model: al.levels ? al.levels.sinks : []; Device { dev: modelData; isOutput: true } }
        Header { text: "INPUT"; Layout.topMargin: 8 }
        Repeater { model: al.levels ? al.levels.sources : []; Device { dev: modelData; isOutput: false } }
        Text { visible: !!al.levels && al.levels.sources.length === 0; text: "No microphones"; color: st.muted; font.pixelSize: 12; Layout.leftMargin: 6 }

        Header { text: "APPS"; Layout.topMargin: 8 }
        Text { visible: !!al.levels && al.levels.apps.length === 0; text: "Nothing is playing"; color: st.muted; font.pixelSize: 12; Layout.leftMargin: 6 }
        Repeater {
            model: al.levels ? al.levels.apps : []
            RowLayout {
                id: app
                required property var modelData
                property real shown: modelData.vol         // follows the system unless being dragged
                Layout.fillWidth: true
                Layout.leftMargin: 6; Layout.rightMargin: 6
                spacing: 10
                onModelDataChanged: if (!am.pressed) shown = modelData.vol
                Kirigami.Icon {
                    Layout.preferredWidth: 20; Layout.preferredHeight: 20
                    source: app.modelData.icon; fallback: "audio-x-generic"
                    opacity: app.modelData.muted ? 0.35 : 1
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                onClicked: al.levels.toggleApp(app.modelData.index) }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: app.modelData.name; color: app.modelData.playing ? st.text : st.muted; font.pixelSize: 12
                           elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                    Rectangle {
                        id: track
                        Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                        color: st.faint
                        Rectangle { width: parent.width * Math.min(1, app.shown); height: parent.height; radius: 3
                                    color: app.modelData.muted ? st.subtle : st.fill }
                        MouseArea {
                            id: am
                            anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            property real lastSent: 0
                            function set(x) { app.shown = Math.max(0, Math.min(1, x / width)); al.levels.setApp(app.modelData.index, app.shown) }
                            onPressed: (e) => set(e.x)
                            onPositionChanged: (e) => { if (Date.now() - lastSent > 80) { lastSent = Date.now(); set(e.x) } }
                            onReleased: (e) => set(e.x)
                        }
                    }
                }
                Text { text: app.modelData.muted ? "off" : Math.round(app.shown * 100); color: st.muted; font.pixelSize: 10; font.family: st.mono
                       Layout.preferredWidth: 24; horizontalAlignment: Text.AlignRight }
            }
        }
    }
}
