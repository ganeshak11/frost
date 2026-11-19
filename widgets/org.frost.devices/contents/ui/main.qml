// Device Ecosystem, in the Quick Controls style: three glass modules.
//   This laptop   how it's online (Wi-Fi / Ethernet, network name) and its local IP
//   Phone         your KDE Connect phone: reachable or not, battery, and round
//                 buttons to send it a file or ring it
//   Tailscale     your private network: this laptop's address and up to three of
//                 your other devices (online with their address, or last seen)
// A red bubble means connected. Click an address to copy it.
// A small helper script collects everything in one read-only pass every 20 seconds.
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls as QQC2
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
        if (!iso) return "offline"
        const m = Math.round((Date.now() - new Date(iso)) / 60000)
        return m < 1 ? "just now" : m < 60 ? m + "m ago" : m < 1440 ? Math.round(m / 60) + "h ago" : Math.round(m / 1440) + "d ago"
    }

    // the phone to show: the first reachable one, else the first paired one
    readonly property var phone: (st.phones || []).find(p => p.reachable) || (st.phones || [])[0] || null
    readonly property bool online: !!(st.net && st.net.ip)
    readonly property bool tsOn: st.tailscale.state === "Running"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            if (src === root.helper) { try { root.st = JSON.parse(data["stdout"]) } catch (e) {} }
            else if (!src.startsWith("printf")) poll.restart()
            disconnectSource(src)
        }
    }
    Timer { id: poll; interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.connectSource(root.helper) }

    property string copied: ""                   // the address just copied, for a moment
    Timer { id: copiedTimer; interval: 1400; onTriggered: root.copied = "" }
    function copy(text) {
        if (!text) return
        exec.connectSource("printf %s " + shq(text) + " | wl-copy")
        copied = text; copiedTimer.restart()
    }

    property string sendTo: ""
    FileDialog {
        id: picker
        title: "Send a file to your phone"
        onAccepted: exec.connectSource("kdeconnect-cli -d " + root.shq(root.sendTo) + " --share " + root.shq(selectedFile.toString().replace("file://", "")))
    }

    // for testing on its own: `plasmawindowed org.frost.devices frost-shot:/path.png`
    Timer {
        interval: 4000; running: Qt.application.name === "plasmawindowed"
        onTriggered: {
            const shot = Qt.application.arguments.find(x => x.startsWith("frost-shot:"))
            if (shot) root.fullRepresentationItem.grabToImage(r => { r.saveToFile(shot.slice(11)); Qt.quit() })
        }
    }

    fullRepresentation: GlassCard {
        id: card
        Layout.minimumWidth: 520; Layout.preferredWidth: 560
        Layout.minimumHeight: 144; Layout.preferredHeight: 160
        Style { id: c }

        readonly property int pad: 16
        readonly property int gap: 10
        readonly property int mr: 20                                   // module corner radius
        readonly property color module: Qt.rgba(1, 1, 1, 0.07)
        readonly property color moduleHover: Qt.rgba(1, 1, 1, 0.11)
        readonly property color light: "#F2F2F5"

        component Tip: QQC2.ToolTip { delay: 600; timeout: 2500 }

        // a glass module
        component Module: Rectangle {
            radius: card.mr
            color: card.module
        }
        // the round bubble at the top of a module: red when connected
        component Bubble: Rectangle {
            property string icon
            property bool on: false
            implicitWidth: 36; implicitHeight: 36
            radius: 18
            color: on ? c.accent : Qt.rgba(1, 1, 1, 0.14)
            Behavior on color { ColorAnimation { duration: 160 } }
            Kirigami.Icon { anchors.centerIn: parent; width: 17; height: 17; isMask: true; color: "white"; source: parent.icon }
        }
        // a module's heading: bubble, name, and a line under the name
        component Head: RowLayout {
            property string icon
            property bool on: false
            property string title
            property string sub
            spacing: 10
            Bubble { icon: parent.icon; on: parent.on }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: parent.parent.title; color: c.text; font.pixelSize: 13; font.weight: Font.DemiBold
                       elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                Text { text: parent.parent.sub; color: c.muted; font.pixelSize: 11
                       elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
            }
        }
        // an address you can click to copy
        component Address: Text {
            id: ad
            property string value
            text: root.copied && root.copied === value ? "Copied" : value
            color: root.copied === value ? c.accent : (adM.containsMouse ? c.text : c.muted)
            font.family: c.mono; font.pixelSize: 11
            elide: Text.ElideRight
            MouseArea { id: adM; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; enabled: ad.value.length > 0
                        cursorShape: Qt.PointingHandCursor; onClicked: root.copy(ad.value) }
            Tip { visible: adM.containsMouse && ad.value.length > 0; text: "Copy " + ad.value }
        }
        // a small round action button
        component Action: Rectangle {
            id: ac
            property string icon
            property string tip
            signal hit()
            implicitWidth: 32; implicitHeight: 32
            radius: 16
            color: acM.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
            scale: acM.pressed ? 0.9 : 1
            opacity: enabled ? 1 : 0.35
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Kirigami.Icon { anchors.centerIn: parent; width: 15; height: 15; isMask: true; color: c.text; source: ac.icon }
            MouseArea { id: acM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ac.hit() }
            Tip { visible: acM.containsMouse; text: ac.tip }
        }

        RowLayout {
            anchors { fill: parent; margins: card.pad }
            spacing: card.gap

            // ---- this laptop
            Module {
                Layout.preferredWidth: 156; Layout.fillHeight: true
                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 0
                    Head {
                        Layout.fillWidth: true
                        icon: !root.online ? "network-offline-symbolic"
                              : root.st.net.kind === "Wi-Fi" ? "network-wireless-symbolic" : "network-wired-symbolic"
                        on: root.online
                        title: "This laptop"
                        sub: root.online ? root.st.net.kind : "Offline"
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        visible: root.online && !!root.st.net.name
                        text: root.st.net.name || ""
                        color: c.text; font.pixelSize: 12
                        elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                    }
                    Address { visible: root.online; value: root.st.net.ip || ""; Layout.fillWidth: true }
                    Text { visible: !root.online; text: "No network"; color: c.muted; font.pixelSize: 12 }
                }
            }

            // ---- phone (KDE Connect)
            Module {
                Layout.preferredWidth: 176; Layout.fillHeight: true
                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 0
                    Head {
                        Layout.fillWidth: true
                        icon: "smartphone-symbolic"
                        on: !!root.phone && root.phone.reachable
                        title: root.phone ? root.phone.name : "Phone"
                        sub: !root.phone ? "Not paired"
                             : !root.phone.reachable ? "Not connected"
                             : root.phone.charging ? "Charging" : "Connected"
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        // battery capsule
                        Item {
                            readonly property int pct: root.phone && root.phone.reachable ? root.phone.battery : -1
                            readonly property bool low: pct >= 0 && pct <= 15 && !root.phone.charging
                            visible: pct >= 0
                            implicitWidth: 34; implicitHeight: 16
                            Rectangle {
                                id: cap
                                width: 30; height: 16; radius: 5
                                color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.35); border.width: 1.5
                                Rectangle {
                                    x: 3; y: 3; height: parent.height - 6; radius: 2.5
                                    width: Math.max(2, (parent.width - 6) * parent.parent.pct / 100)
                                    color: parent.parent.low ? c.accent : card.light
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                }
                            }
                            Rectangle { x: cap.width + 1; y: 5; width: 2.5; height: 6; radius: 1; color: Qt.rgba(1, 1, 1, 0.35) }
                        }
                        Text {
                            readonly property int pct: root.phone && root.phone.reachable ? root.phone.battery : -1
                            visible: pct >= 0
                            text: (root.phone && root.phone.charging ? "⚡" : "") + pct + "%"
                            color: pct >= 0 && pct <= 15 && !root.phone.charging ? c.accent : c.text
                            font.family: c.mono; font.pixelSize: 12
                        }
                        Text {
                            visible: !root.phone || !root.phone.reachable
                            text: !root.phone ? "Pair in KDE Connect" : "Open KDE Connect on it"
                            color: c.muted; font.pixelSize: 11
                            elide: Text.ElideRight; Layout.fillWidth: true
                            wrapMode: Text.WordWrap; maximumLineCount: 2
                        }
                        Item { Layout.fillWidth: true; visible: !!root.phone && root.phone.reachable }
                        Action {
                            visible: !!root.phone && root.phone.reachable
                            icon: "document-send-symbolic"; tip: "Send a file"
                            onHit: { root.sendTo = root.phone.id; picker.open() }
                        }
                        Action {
                            visible: !!root.phone && root.phone.reachable
                            icon: "audio-volume-high-symbolic"; tip: "Ring it"
                            onHit: exec.connectSource("kdeconnect-cli -d " + root.shq(root.phone.id) + " --ring")
                        }
                    }
                }
            }

            // ---- Tailscale
            Module {
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Bubble { icon: "network-vpn-symbolic"; on: root.tsOn }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: "Tailscale"; color: c.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Address { visible: root.tsOn; value: root.st.tailscale.self || ""; Layout.fillWidth: true }
                            Text { visible: !root.tsOn; color: c.muted; font.pixelSize: 11
                                   text: root.st.tailscale.state === "Absent" ? "Not installed"
                                         : root.st.tailscale.state === "Stopped" ? "Off" : root.st.tailscale.state }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Repeater {   // your other devices, online first
                        model: root.tsOn ? root.st.tailscale.peers.slice().sort((a, b) => b.online - a.online).slice(0, 3) : []
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            spacing: 7
                            Rectangle { width: 6; height: 6; radius: 3; color: modelData.online ? c.accent : c.subtle }
                            Text { text: modelData.name; color: modelData.online ? c.text : c.muted; font.pixelSize: 12
                                   elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                            Address { visible: modelData.online; value: modelData.ip || "" }
                            Text { visible: !modelData.online; text: root.ago(modelData.lastSeen)
                                   color: c.muted; font.family: c.mono; font.pixelSize: 11 }
                        }
                    }
                    Text {
                        visible: root.tsOn && root.st.tailscale.peers.length === 0
                        text: "No other devices"; color: c.muted; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
