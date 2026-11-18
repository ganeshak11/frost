// Quick Command Centre, phone style: three tall rounded sliders (volume,
// microphone, screen brightness; drag or scroll, tap the icon to mute) and
// rounded pills for Wi-Fi, Bluetooth, Tailscale, Do Not Disturb, Night Light
// and Power. Power opens Plasma's normal shutdown screen, so it always asks.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    PlasmaNM.EnabledConnections { id: nm }
    PlasmaNM.Handler { id: nmHandler }
    NotificationManager.Settings { id: notif }

    readonly property bool btOn: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    readonly property bool dndOn: notif.notificationsInhibitedUntil !== undefined
                                  && !isNaN(notif.notificationsInhibitedUntil) && notif.notificationsInhibitedUntil > new Date()
    property bool nightOn: false
    property string tsState: "…"
    property string tsHint: ""

    // sliders
    property real vol: 0;   property bool volMuted: false
    property real mic: 0;   property bool micMuted: false
    property real light: 0; property int lightMax: 1
    property bool dragging: false

    readonly property string qd: "qdbus6 org.kde.KWin /org/kde/KWin/NightLight org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight "
    readonly property string cmdNight: "echo $(" + qd + "enabled) $(" + qd + "inhibited)"
    readonly property string cmdTs: "tailscale status >/dev/null 2>&1 && echo on || echo off"
    readonly property string bd: "qdbus6 org.kde.ScreenBrightness /org/kde/ScreenBrightness/display0 org.kde.ScreenBrightness.Display."
    readonly property string cmdLevels: "echo $(wpctl get-volume @DEFAULT_AUDIO_SINK@) '|' $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@) '|' $(" + bd + "Brightness) $(" + bd + "MaxBrightness)"

    function setLevel(kind, v) {
        v = Math.max(0, Math.min(1, v))
        if (kind === "vol") { vol = v; exec.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2)) }
        else if (kind === "mic") { mic = v; exec.run("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + v.toFixed(2)) }
        else { light = v; exec.run(bd + "SetBrightness " + Math.max(1, Math.round(v * lightMax)) + " 0") }
    }
    function toggleMute(kind) {
        if (kind === "vol") { volMuted = !volMuted; exec.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") }
        else if (kind === "mic") { micMuted = !micMuted; exec.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") }
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            const out = (data["stdout"] || "").trim(), err = (data["stderr"] || "").trim()
            if (src === root.cmdNight) {
                const p = out.split(/\s+/); root.nightOn = p[0] === "true" && p[1] !== "true"
            } else if (src === root.cmdLevels) {
                if (!root.dragging) {
                    const parts = out.split("|").map(x => x.trim())
                    const num = (t) => parseFloat(((t || "").match(/Volume:\s*([\d.]+)/) || [0, 0])[1])
                    root.vol = Math.min(1, num(parts[0])); root.volMuted = /MUTED/.test(parts[0])
                    root.mic = Math.min(1, num(parts[1])); root.micMuted = /MUTED/.test(parts[1])
                    const b = (parts[2] || "").split(/\s+/).map(Number)
                    if (b[1] > 0) { root.lightMax = b[1]; root.light = b[0] / b[1] }
                }
            } else if (src === root.cmdTs) {
                root.tsState = out
            } else if (src.startsWith("tailscale up") || src.startsWith("tailscale down")) {
                root.tsHint = data["exit code"] === 0 ? "" : (/access denied|permission|operator/i.test(err) ? "Needs operator" : "Failed")
                run(root.cmdTs)
            } else if (src.startsWith("qdbus6 org.kde.kglobalaccel")) {
                nightCheck.restart()
            }
            disconnectSource(src)
        }
        function run(c) { connectSource(c) }
    }
    Timer { interval: 8000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: { exec.run(root.cmdNight); exec.run(root.cmdTs) } }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.run(root.cmdLevels) }
    Timer { id: nightCheck; interval: 600; onTriggered: exec.run(root.cmdNight) }

    fullRepresentation: GlassCard {
        id: card
        // tall narrow card: sliders on top, pills in two columns below
        readonly property bool compact: width < 380
        Layout.minimumWidth: 272; Layout.preferredWidth: 288
        Layout.minimumHeight: 352; Layout.preferredHeight: 368
        Style { id: st }

        // tall rounded slider that fills from the bottom
        component VSlider: Rectangle {
            id: sl
            property string kind
            property real value
            property bool muted: false
            property string icon
            property string mutedIcon: icon
            radius: width / 2
            color: st.faint
            border.color: st.border
            clip: true
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.max(sl.width, parent.height * sl.value)
                radius: sl.radius
                color: sl.muted ? st.subtle : st.fill
                Behavior on height { enabled: !root.dragging; NumberAnimation { duration: 180 } }
            }
            Text {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
                text: sl.muted ? "off" : Math.round(sl.value * 100)
                color: sl.value > 0.88 && !sl.muted ? st.textOnFill : st.muted
                font.family: st.mono; font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                property real lastSent: 0
                function at(y) { return 1 - y / height }
                onPressed: (e) => { root.dragging = true; root.setLevel(sl.kind, at(e.y)) }
                onPositionChanged: (e) => {
                    if (Date.now() - lastSent > 80) { lastSent = Date.now(); root.setLevel(sl.kind, at(e.y)) }
                }
                onReleased: (e) => { root.setLevel(sl.kind, at(e.y)); root.dragging = false }
                onWheel: (w) => root.setLevel(sl.kind, sl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            }
            Kirigami.Icon {   // tap to mute
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 13 }
                width: 20; height: 20; isMask: true
                source: sl.muted ? sl.mutedIcon : sl.icon
                color: !sl.muted ? st.textOnFill : st.text
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    enabled: sl.kind !== "light"
                    onClicked: root.toggleMute(sl.kind)
                }
            }
        }

        // rounded pill toggle with an icon bubble
        component Pill: Rectangle {
            id: pl
            property string icon
            property string label
            property string shortLabel: label
            property string sub
            property bool on: false
            signal hit()
            radius: height / 2
            color: on ? st.accent : (pm.containsMouse ? st.hover : st.faint)
            border.color: on ? "transparent" : st.border
            scale: pm.pressed ? 0.97 : 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 90 } }
            RowLayout {
                anchors { fill: parent; leftMargin: 5; rightMargin: 14 }
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: pl.height - 10; Layout.preferredHeight: pl.height - 10
                    radius: width / 2
                    color: pl.on ? Qt.rgba(1, 1, 1, 0.22) : st.faint
                    Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; isMask: true; color: pl.on ? st.textOnAccent : st.text; source: pl.icon }
                }
                Text { text: card.compact ? pl.shortLabel : pl.label; color: pl.on ? st.textOnAccent : st.text; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: !card.compact; text: pl.sub; color: pl.on ? Qt.rgba(1, 1, 1, 0.85) : st.muted; font.pixelSize: 11 }
            }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pl.hit() }
        }

        GridLayout {
            anchors { fill: parent; margins: st.pad }
            columns: card.compact ? 1 : 2
            columnSpacing: 14; rowSpacing: 14

            RowLayout {
                Layout.fillHeight: !card.compact
                Layout.fillWidth: card.compact
                Layout.preferredHeight: card.compact ? 172 : -1
                spacing: 8
                VSlider { Layout.preferredWidth: 44; Layout.fillWidth: card.compact; Layout.fillHeight: true; kind: "vol"; value: root.vol; muted: root.volMuted
                          icon: "audio-volume-high"; mutedIcon: "audio-volume-muted" }
                VSlider { Layout.preferredWidth: 44; Layout.fillWidth: card.compact; Layout.fillHeight: true; kind: "mic"; value: root.mic; muted: root.micMuted
                          icon: "audio-input-microphone"; mutedIcon: "microphone-sensitivity-muted" }
                VSlider { Layout.preferredWidth: 44; Layout.fillWidth: card.compact; Layout.fillHeight: true; kind: "light"; value: root.light; icon: "brightness-high" }
            }

            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                columns: card.compact ? 2 : 1
                rowSpacing: 7; columnSpacing: 7
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: nm.wirelessEnabled ? "network-wireless" : "network-wireless-disconnected"
                    label: "Wi-Fi"; sub: nm.wirelessEnabled ? "On" : "Off"; on: nm.wirelessEnabled
                    onHit: nmHandler.enableWireless(!nm.wirelessEnabled)
                }
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: root.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                    label: "Bluetooth"; shortLabel: "BT"; sub: root.btOn ? "On" : "Off"; on: root.btOn
                    onHit: BluezQt.Manager.bluetoothBlocked = !BluezQt.Manager.bluetoothBlocked
                }
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: "network-vpn"; label: "Tailscale"
                    sub: root.tsHint || (root.tsState === "on" ? "Connected" : root.tsState === "off" ? "Off" : "…")
                    on: root.tsState === "on"
                    onHit: exec.run(root.tsState === "on" ? "tailscale down" : "tailscale up")
                }
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: root.dndOn ? "notifications-disabled" : "notifications"
                    label: "Do Not Disturb"; shortLabel: "DND"; sub: root.dndOn ? "On" : "Off"; on: root.dndOn
                    onHit: {
                        if (root.dndOn) { notif.notificationsInhibitedUntil = undefined; notif.revokeApplicationInhibitions() }
                        else { const d = new Date(); d.setFullYear(d.getFullYear() + 1); notif.notificationsInhibitedUntil = d }
                        notif.save()
                    }
                }
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: "redshift-status-on"; label: "Night Light"; shortLabel: "Night"; sub: root.nightOn ? "On" : "Off"; on: root.nightOn
                    onHit: exec.run('qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Toggle Night Color"')
                }
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: "system-shutdown"; label: "Power"; sub: "Options"
                    onHit: exec.run("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptAll")
                }
            }
        }
    }
}
