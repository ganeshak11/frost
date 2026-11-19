// Quick Command Centre, phone style: three tall rounded sliders (volume,
// microphone, screen brightness; drag or scroll, tap the icon to mute, tap the
// number on volume / mic for outputs, inputs and per-app volume) and
// rounded pills for Wi-Fi, Bluetooth, Tailscale, Do Not Disturb, Night Light
// and Power. Power opens Plasma's normal shutdown screen, so it always asks.
// Wi-Fi and Bluetooth: the round icon turns them on / off, the rest of the pill
// opens the list of networks / paired devices (click one to connect).
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

    // sliders: live levels (see Levels.qml)
    Levels { id: lv }
    property string listFor: ""      // "wifi" / "bluetooth" / "audio" while its list covers the card
    // Bluetooth pill: the connected device's battery when it reports one
    property int btTick: 0
    Connections { target: BluezQt.Manager; function onDeviceChanged() { root.btTick++ } }
    readonly property string btSub: {
        btTick
        if (!btOn) return "Off"
        const c = BluezQt.Manager.devices.filter(d => d.connected)
        const b = c.length === 1 && c[0].battery ? c[0].battery.percentage : -1
        return b >= 0 ? b + "%" : "On"
    }

    readonly property string qd: "qdbus6 org.kde.KWin /org/kde/KWin/NightLight org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight "
    readonly property string cmdNight: "echo $(" + qd + "enabled) $(" + qd + "inhibited)"
    readonly property string cmdTs: "tailscale status >/dev/null 2>&1 && echo on || echo off"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            const out = (data["stdout"] || "").trim(), err = (data["stderr"] || "").trim()
            if (src === root.cmdNight) {
                const p = out.split(/\s+/); root.nightOn = p[0] === "true" && p[1] !== "true"
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
    Timer { id: nightCheck; interval: 600; onTriggered: exec.run(root.cmdNight) }

    // for testing on its own: `plasmawindowed org.frost.controls frost-test:wifi|bluetooth|audio [frost-shot:/path.png]`
    Timer {
        interval: 1500; running: Qt.application.name === "plasmawindowed"
        onTriggered: {
            const args = Qt.application.arguments, a = args.find(x => x.startsWith("frost-test:"))
            if (!a) return
            root.listFor = a.slice(11) === "main" ? "" : a.slice(11)
            const shot = args.find(x => x.startsWith("frost-shot:"))
            if (shot) shotTimer.start()
        }
    }
    Timer {
        id: shotTimer; interval: 3500
        onTriggered: root.fullRepresentationItem.grabToImage(r => { r.saveToFile(Qt.application.arguments.find(x => x.startsWith("frost-shot:")).slice(11)); Qt.quit() })
    }

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
                Behavior on height { enabled: !lv.dragging; NumberAnimation { duration: 180 } }
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
                preventStealing: true
                property real lastSent: 0
                function at(y) { return 1 - y / height }
                onPressed: (e) => { lv.dragging = true; lv.setLevel(sl.kind, at(e.y)) }
                onPositionChanged: (e) => {
                    if (Date.now() - lastSent > 80) { lastSent = Date.now(); lv.setLevel(sl.kind, at(e.y)) }
                }
                onReleased: (e) => { lv.setLevel(sl.kind, at(e.y)); lv.dragging = false }
                onCanceled: lv.dragging = false
                onWheel: (w) => lv.setLevel(sl.kind, sl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            }
            MouseArea {   // the number on volume / mic: outputs, inputs and apps
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 32
                visible: sl.kind !== "light"
                cursorShape: Qt.PointingHandCursor
                onClicked: root.listFor = "audio"
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
                    onClicked: lv.toggleMute(sl.kind)
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
            property bool hasList: false
            signal hit()
            signal more()
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
                    MouseArea { anchors.fill: parent; z: 2; visible: pl.hasList; cursorShape: Qt.PointingHandCursor; onClicked: pl.hit() }
                }
                Text { text: card.compact ? pl.shortLabel : pl.label; color: pl.on ? st.textOnAccent : st.text; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: !card.compact; text: pl.sub; color: pl.on ? Qt.rgba(1, 1, 1, 0.85) : st.muted; font.pixelSize: 11 }
            }
            MouseArea { id: pm; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pl.hasList ? pl.more() : pl.hit() }
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
                VSlider { Layout.preferredWidth: 44; Layout.fillWidth: card.compact; Layout.fillHeight: true; kind: "vol"; value: lv.vol; muted: lv.volMuted
                          icon: "audio-volume-high"; mutedIcon: "audio-volume-muted" }
                VSlider { Layout.preferredWidth: 44; Layout.fillWidth: card.compact; Layout.fillHeight: true; kind: "mic"; value: lv.mic; muted: lv.micMuted
                          icon: "audio-input-microphone"; mutedIcon: "microphone-sensitivity-muted" }
                VSlider { Layout.preferredWidth: 44; Layout.fillWidth: card.compact; Layout.fillHeight: true; kind: "light"; value: lv.light; icon: "brightness-high" }
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
                    hasList: true; onMore: root.listFor = "wifi"
                }
                Pill {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    icon: root.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                    label: "Bluetooth"; shortLabel: "BT"; sub: root.btSub; on: root.btOn
                    onHit: BluezQt.Manager.bluetoothBlocked = !BluezQt.Manager.bluetoothBlocked
                    hasList: true; onMore: root.listFor = "bluetooth"
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
        // the Wi-Fi / Bluetooth list, over the whole card
        Rectangle {
            anchors.fill: parent
            visible: root.listFor !== ""
            radius: card.radius
            color: "#0e0e12"
            border.color: st.border
            MouseArea { anchors.fill: parent }          // keep clicks off the card below
            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                        color: backM.containsMouse ? st.hover : st.faint
                        Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; isMask: true; color: st.text; source: "go-previous" }
                        MouseArea { id: backM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.listFor = "" }
                    }
                    Text { text: ({ wifi: "Wi-Fi", bluetooth: "Bluetooth", audio: "Sound" })[root.listFor] || ""
                           color: st.text; font.pixelSize: 15; font.weight: Font.DemiBold
                           Layout.fillWidth: true }
                }
                WifiList { visible: root.listFor === "wifi"; Layout.fillWidth: true; maxRows: 6 }
                BluetoothList { visible: root.listFor === "bluetooth"; Layout.fillWidth: true; maxRows: 6 }
                AudioList { visible: root.listFor === "audio"; Layout.fillWidth: true; Layout.fillHeight: true; levels: lv }
                Item { Layout.fillHeight: root.listFor !== "audio" }
                Text {
                    readonly property var kcm: ({ wifi: "kcm_networkmanagement", bluetooth: "kcm_bluetooth", audio: "kcm_pulseaudio" })
                    text: ({ wifi: "Network Settings…", bluetooth: "Bluetooth Settings…", audio: "Sound Settings…" })[root.listFor] || ""
                    color: setM.containsMouse ? st.accent : st.muted; font.pixelSize: 12
                    MouseArea { id: setM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: exec.run("systemsettings " + parent.kcm[root.listFor]) }
                }
            }
        }
    }
}
