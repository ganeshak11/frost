// Chronos: the identity widget. Day, date, time with seconds, a greeting,
// and a thin 24-hour timeline with a red marker for "now".
// Click the time to switch between 12- and 24-hour format.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property date now: new Date()
    readonly property bool h24: Plasmoid.configuration.use24h
    readonly property string firstName: (kuser.fullName || kuser.loginName).split(" ")[0]

    KCoreAddons.KUser { id: kuser }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // Layout profiles: which Frost widgets stay visible in each one.
    readonly property var profiles: ({
        "Default":    null,   // everything
        "Focus":      ["chronos", "focus", "agenda", "music"],
        "Monitoring": ["chronos", "observatory", "devices", "controls"],
        "Minimal":    ["chronos"]
    })
    function applyProfile(name) {
        Plasmoid.configuration.profile = name
        const keep = JSON.stringify(profiles[name])
        const js = "const keep = " + keep + ";" +
                   "for (const d of desktops()) for (const w of d.widgets()) {" +
                   "  if (!w.type.startsWith('org.frost.')) continue;" +
                   "  w.currentConfigGroup = ['General'];" +
                   "  w.writeConfig('hidden', keep !== null && !keep.includes(w.type.slice(10)));" +
                   "}"
        exec.connectSource("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + "'" + js.replace(/'/g, "'\\''") + "'")
    }
    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }

    function greeting(h) {
        if (h < 5) return "Still up, " + firstName + "?"
        if (h < 12) return "Good morning, " + firstName
        if (h < 17) return "Good afternoon, " + firstName
        if (h < 21) return "Good evening, " + firstName
        return "Good night, " + firstName
    }

    fullRepresentation: GlassCard {
        Layout.minimumWidth: 520; Layout.preferredWidth: 560
        Layout.minimumHeight: 196; Layout.preferredHeight: 208
        Style { id: st }

        ColumnLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 2

            Text {
                text: Qt.formatDate(root.now, "dddd").toUpperCase()
                color: st.text
                font.pixelSize: 40
                font.letterSpacing: 4
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                text: Qt.formatDate(root.now, "d MMMM yyyy").toUpperCase()
                color: st.accent
                font.pixelSize: 15
                font.letterSpacing: 3
            }
            RowLayout {
                Layout.topMargin: 4
                spacing: 6
                Text {
                    id: clock
                    text: root.h24 ? Qt.formatTime(root.now, "HH:mm")
                                   : ((root.now.getHours() % 12 || 12) + Qt.formatTime(root.now, ":mm")).padStart(5, "0")
                    color: st.text
                    font.family: st.mono
                    font.pixelSize: 32
                    font.weight: Font.Medium
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Plasmoid.configuration.use24h = !Plasmoid.configuration.use24h
                    }
                }
                Text {
                    text: Qt.formatTime(root.now, ":ss")
                    color: st.accent
                    font.family: st.mono
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignBaseline
                }
                Text {
                    visible: !root.h24
                    text: root.now.getHours() < 12 ? "AM" : "PM"
                    color: st.muted
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignBaseline
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 0
                    Text { text: root.greeting(root.now.getHours()); color: st.text; font.pixelSize: 14; Layout.alignment: Qt.AlignRight }
                    Text {
                        text: Qt.formatTime(root.now, "t")
                        color: st.muted; font.pixelSize: 11; Layout.alignment: Qt.AlignRight
                    }
                }
            }

            // 24-hour timeline
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                Layout.topMargin: 6
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: st.border }
                Repeater {
                    model: 25
                    Rectangle {
                        x: index / 24 * (parent.width - 1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: index % 6 === 0 ? 8 : 4
                        color: index % 6 === 0 ? st.muted : st.border
                    }
                }
                Rectangle {   // "now" marker
                    x: (root.now.getHours() + root.now.getMinutes() / 60) / 24 * (parent.width - 2)
                    width: 2; height: parent.height; radius: 1
                    color: st.accent
                    Behavior on x { NumberAnimation { duration: 400 } }
                }
            }

            // layout profile chips
            RowLayout {
                Layout.topMargin: 6
                spacing: 6
                Repeater {
                    model: ["Default", "Focus", "Monitoring", "Minimal"]
                    Rectangle {
                        readonly property bool on: Plasmoid.configuration.profile === modelData
                        implicitWidth: lbl.implicitWidth + 16; implicitHeight: 20; radius: 10
                        color: on ? st.accentSoft : (pm.containsMouse ? st.faint : "transparent")
                        border.color: on ? st.accent : st.border
                        Text { id: lbl; anchors.centerIn: parent; text: modelData; color: parent.on ? st.accent : st.muted; font.pixelSize: 11 }
                        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.applyProfile(modelData) }
                    }
                }
            }
        }
    }
}
