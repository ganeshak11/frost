// Screen Time: how long you've used each app today, when in the day, and the
// last seven days, for this laptop and your phone together (phone in Frost red,
// laptop in white; the same card as on the phone). Numbers come from the Frost
// Screen Time tracker (extras/screentime), read once a minute with
// `frost-screentime summary`; the phone's arrive through Frost Link (extras/link).
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
    readonly property var ph: s && s.phone ? s.phone : ({ total: 0, yesterday: 0, apps: [], hours: [] })
    readonly property int both: (s ? s.total : 0) + ph.total
    // top apps of both devices, each marked with where it was used
    readonly property var apps: s ? s.apps.map(a => Object.assign({ phone: false }, a))
                                      .concat(ph.apps.map(a => Object.assign({ phone: true }, a)))
                                      .sort((x, y) => y.secs - x.secs).slice(0, 5) : []
    readonly property var hours: s ? s.hours : []
    readonly property var week: s ? s.week : []

    function dur(secs) {
        secs = Math.round(secs || 0)
        if (secs < 60) return secs > 0 ? "<1m" : "0m"
        const h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60)
        return h ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m"
    }
    function delta() {
        const y = s ? s.yesterday + ph.yesterday : 0
        if (!y) return ""
        const d = both - y
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
                    text: root.delta(); color: root.s && root.both > root.s.yesterday + root.ph.yesterday ? st.accent : st.muted
                    font.family: st.mono; font.pixelSize: 10
                }
            }

            RowLayout {
                spacing: 8
                Text { text: root.dur(root.both); color: st.text; font.family: st.mono; font.pixelSize: 34 }
                Text { text: "today"; color: st.muted; font.pixelSize: 12; Layout.alignment: Qt.AlignBaseline }
            }
            RowLayout {   // the two devices apart
                spacing: 16
                Repeater {
                    model: [["Phone", st.accent, root.ph.total], ["Laptop", st.fill, root.s ? root.s.total : 0]]
                    RowLayout {
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: modelData[1] }
                        Text { text: modelData[0]; color: st.muted; font.pixelSize: 11 }
                        Text { text: root.dur(modelData[2]); color: st.text; font.family: st.mono; font.pixelSize: 11 }
                    }
                }
            }

            // 24 hours: one bar per hour, the current hour in red
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Item {
                    id: strip
                    Layout.fillWidth: true; Layout.preferredHeight: 40
                    readonly property real cell: (width - 23 * 3) / 24
                    readonly property real peak: Math.max(900, ...Array.from({ length: 24 }, (_, i) => (root.hours[i] || 0) + (root.ph.hours[i] || 0)))
                    Repeater {   // each hour: phone (red) under laptop (white); the current hour brighter
                        model: 24
                        Item {
                            readonly property real p: root.ph.hours[index] || 0
                            readonly property real l: root.hours[index] || 0
                            readonly property bool now: root.s && index === root.s.hour
                            x: index * (strip.cell + 3); width: strip.cell; height: strip.height
                            Rectangle {
                                visible: parent.p + parent.l === 0
                                anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: st.faint
                            }
                            Rectangle {
                                id: pBar
                                anchors.bottom: parent.bottom; width: parent.width; radius: Math.min(2, width / 2)
                                height: parent.p > 0 ? Math.max(2, parent.p / strip.peak * strip.height) : 0
                                color: st.accent; opacity: parent.now ? 1 : 0.7
                            }
                            Rectangle {
                                anchors.bottom: pBar.top; width: parent.width; radius: Math.min(2, width / 2)
                                height: parent.l > 0 ? Math.max(2, parent.l / strip.peak * strip.height) : 0
                                color: st.fill; opacity: parent.now ? 0.95 : 0.5
                            }
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
                                Text { text: modelData.phone ? "phone" : "laptop"; color: modelData.phone ? st.accent : st.muted; font.pixelSize: 10 }
                                Text { text: root.dur(modelData.secs); color: st.muted; font.family: st.mono; font.pixelSize: 11 }
                            }
                            Rectangle {
                                Layout.fillWidth: true; height: 3; radius: 1.5; color: st.faint
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: parent.width * (root.apps.length ? modelData.secs / root.apps[0].secs : 0)
                                    color: modelData.phone ? st.accent : st.fill; opacity: index === 0 ? 1 : 0.6
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
                readonly property real peak: Math.max(3600, ...root.week.map(d => d.secs + (d.phone || 0)))
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
                            Rectangle {   // nothing that day
                                visible: day.modelData.secs + (day.modelData.phone || 0) === 0
                                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                width: Math.min(parent.width, 18); height: 2; radius: 1; color: st.faint
                            }
                            Rectangle {   // phone, red, at the bottom
                                id: wp
                                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                width: Math.min(parent.width, 18); radius: 2
                                height: (day.modelData.phone || 0) / day.parent.peak * parent.height
                                color: st.accent; opacity: day.isToday ? 1 : 0.6
                            }
                            Rectangle {   // laptop, white, on top
                                anchors { bottom: wp.top; horizontalCenter: parent.horizontalCenter }
                                width: Math.min(parent.width, 18); radius: 2
                                height: day.modelData.secs / day.parent.peak * parent.height
                                color: st.fill; opacity: day.isToday ? 0.9 : 0.45
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
