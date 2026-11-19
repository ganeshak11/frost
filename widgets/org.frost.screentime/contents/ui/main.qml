// Screen Time: how long you've used each app today, when in the day, and the
// last seven days. Numbers come from the Frost Screen Time tracker
// (extras/screentime), read once a minute with `frost-screentime summary`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property var s: null            // the last summary
    property bool installed: true
    readonly property var apps: s ? s.apps.slice(0, 5) : []
    readonly property var hours: s ? s.hours : []
    readonly property var week: s ? s.week : []

    function dur(secs) {
        secs = Math.round(secs || 0)
        if (secs < 60) return secs > 0 ? "<1m" : "0m"
        const h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60)
        return h ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m"
    }
    function delta() {
        if (!s || !s.yesterday) return ""
        const d = s.total - s.yesterday
        if (Math.abs(d) < 60) return "same as yesterday"
        return (d > 0 ? "▲ " : "▼ ") + dur(Math.abs(d)) + " vs yesterday"
    }

    readonly property string cmd: "\"$HOME/.local/bin/frost-screentime\" summary"
    function refresh() { exec.connectSource(cmd) }
    P5Support.DataSource {
        id: exec; engine: "executable"
        onNewData: (src, data) => {
            disconnectSource(src)
            try { root.s = JSON.parse(data["stdout"]); root.installed = true }
            catch (e) { root.installed = false }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    fullRepresentation: GlassCard {
        Layout.minimumWidth: 300; Layout.preferredWidth: 320
        Layout.minimumHeight: 380; Layout.preferredHeight: 400
        Style { id: st }

        MouseArea { anchors.fill: parent; onClicked: root.refresh() }

        ColumnLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { text: "SCREEN TIME"; color: st.muted; font.pixelSize: 11; font.letterSpacing: 2.5 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.delta(); color: root.s && root.s.total > root.s.yesterday ? st.accent : st.muted
                    font.family: st.mono; font.pixelSize: 10
                }
            }

            RowLayout {
                spacing: 8
                Text { text: root.dur(root.s ? root.s.total : 0); color: st.text; font.family: st.mono; font.pixelSize: 34 }
                Text { text: "today"; color: st.muted; font.pixelSize: 12; Layout.alignment: Qt.AlignBaseline }
            }

            // 24 hours: one bar per hour, the current hour in red
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Item {
                    id: strip
                    Layout.fillWidth: true; Layout.preferredHeight: 40
                    readonly property real cell: (width - 23 * 3) / 24
                    readonly property real peak: Math.max(900, ...(root.hours.length ? root.hours : [0]))
                    Repeater {
                        model: 24
                        Rectangle {
                            readonly property real v: root.hours[index] || 0
                            x: index * (strip.cell + 3); width: strip.cell
                            height: v > 0 ? Math.max(3, v / strip.peak * strip.height) : 2
                            anchors.bottom: parent.bottom
                            radius: Math.min(2, width / 2)
                            color: root.s && index === root.s.hour ? st.accent : (v > 0 ? st.fill : st.faint)
                            opacity: root.s && index === root.s.hour ? 1 : (v > 0 ? 0.55 : 1)
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 12
                    Repeater {
                        model: ["12a", "6a", "12p", "6p"]
                        Text {
                            x: index * 6 * (strip.cell + 3); text: modelData
                            color: st.muted; font.family: st.mono; font.pixelSize: 9
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: st.faint }

            // top apps
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 9
                Repeater {
                    model: root.apps
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Kirigami.Icon { source: modelData.icon; fallback: "application-x-executable"; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.name; color: st.text; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: root.dur(modelData.secs); color: st.muted; font.family: st.mono; font.pixelSize: 11 }
                            }
                            Rectangle {
                                Layout.fillWidth: true; height: 3; radius: 1.5; color: st.faint
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: parent.width * (root.apps.length ? modelData.secs / root.apps[0].secs : 0)
                                    color: index === 0 ? st.accent : st.fill; opacity: index === 0 ? 1 : 0.5
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: root.apps.length === 0
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    color: st.muted; font.pixelSize: 12
                    text: !root.installed || (root.s && !root.s.running)
                          ? "The tracker isn't running. Install it with extras/screentime/install.sh."
                          : "Counting from now. Your apps show up here after a minute of use."
                }
                Item { Layout.fillHeight: true }
            }

            // last seven days
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                readonly property real peak: Math.max(3600, ...root.week.map(d => d.secs))
                Repeater {
                    model: root.week
                    ColumnLayout {
                        id: day
                        required property var modelData
                        required property int index
                        readonly property bool isToday: index === root.week.length - 1
                        Layout.fillWidth: true
                        spacing: 3
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 24
                            Rectangle {
                                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                width: Math.min(parent.width, 18); radius: 2
                                height: day.modelData.secs > 0 ? Math.max(3, day.modelData.secs / day.parent.peak * parent.height) : 2
                                color: day.isToday ? st.accent : (day.modelData.secs > 0 ? st.fill : st.faint)
                                opacity: day.isToday ? 1 : (day.modelData.secs > 0 ? 0.45 : 1)
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: day.modelData.day.charAt(0)
                            color: day.isToday ? st.text : st.muted; font.family: st.mono; font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }
}
