// Device Ecosystem: this laptop's connection, your KDE Connect phone (battery,
// ring it, send it a file) and Tailscale with its peers. A small helper
// script collects everything in one read-only pass every 20 seconds.
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property var st: ({ net: {}, phones: [], tailscale: { state: "…", peers: [] } })
    readonly property string helper: "bash " + shq(Qt.resolvedUrl("../code/status.sh").toString().replace("file://", ""))
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function ago(iso) {
        if (!iso) return ""
        const m = Math.round((Date.now() - new Date(iso)) / 60000)
        return m < 60 ? m + "m ago" : m < 1440 ? Math.round(m / 60) + "h ago" : Math.round(m / 1440) + "d ago"
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            if (src === root.helper) { try { root.st = JSON.parse(data["stdout"]) } catch (e) {} }
            else poll.restart()
            disconnectSource(src)
        }
    }
    Timer { id: poll; interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.connectSource(root.helper) }

    property string sendTo: ""
    FileDialog {
        id: picker
        title: "Send a file to your phone"
        onAccepted: exec.connectSource("kdeconnect-cli -d " + root.shq(root.sendTo) + " --share " + root.shq(selectedFile.toString().replace("file://", "")))
    }

    fullRepresentation: GlassCard {
        Layout.minimumWidth: 520; Layout.preferredWidth: 560
        Layout.minimumHeight: 144; Layout.preferredHeight: 160
        Style { id: c }

        ColumnLayout {
            anchors { fill: parent; margins: c.pad }
            spacing: 7

            Text { text: "CONNECTED ECOSYSTEM"; color: c.muted; font.pixelSize: 11; font.letterSpacing: 2.5 }

            component Dot: Rectangle { property bool on; width: 7; height: 7; radius: 3.5; color: on ? c.accent : c.subtle }
            component Name: Text { color: c.text; font.pixelSize: 14; Layout.preferredWidth: 130; elide: Text.ElideRight }
            component Info: Text { color: c.muted; font.family: c.mono; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight }

            // this laptop
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Dot { on: !!root.st.net.ip }
                Name { text: "This laptop" }
                Info { text: root.st.net.ip ? root.st.net.kind + " · " + root.st.net.ip : "Offline" }
            }

            // KDE Connect phones
            Repeater {
                model: root.st.phones
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Dot { on: modelData.reachable }
                    Name { text: modelData.name }
                    Info {
                        text: !modelData.reachable ? "Not connected" :
                              modelData.battery >= 0 ? (modelData.charging ? "⚡ " : "") + modelData.battery + "%" : "Connected"
                        color: modelData.reachable && modelData.battery >= 0 && modelData.battery <= 15 && !modelData.charging ? c.accent : c.muted
                    }
                    component Act: Kirigami.Icon {
                        signal hit()
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16; isMask: true
                        color: am.containsMouse ? c.accent : c.text
                        MouseArea { id: am; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.hit() }
                    }
                    Act { visible: modelData.reachable; source: "send-to-symbolic"; onHit: { root.sendTo = modelData.id; picker.open() } }
                    Act { visible: modelData.reachable; source: "audio-volume-high"; onHit: exec.connectSource("kdeconnect-cli -d " + root.shq(modelData.id) + " --ring") }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: c.faint }

            // Tailscale
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Dot { on: root.st.tailscale.state === "Running" }
                Name { text: "Tailscale" }
                Info { text: root.st.tailscale.state === "Running" ? "Connected · " + root.st.tailscale.self
                             : root.st.tailscale.state === "Absent" ? "Not installed" : root.st.tailscale.state }
            }
            Repeater {
                model: root.st.tailscale.peers.slice(0, 3)
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Item { width: 7 }
                    Text { text: "↳ " + modelData.name; color: c.muted; font.pixelSize: 12; Layout.preferredWidth: 130; elide: Text.ElideRight }
                    Info { text: modelData.online ? "online · " + modelData.ip : "last seen " + root.ago(modelData.lastSeen) }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
