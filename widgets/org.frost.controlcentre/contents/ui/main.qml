// Control Centre: a glass panel that drops down under the Dynamic Island.
// Open it with Meta+Alt+C, or right-click / scroll down on the island.
//   Wi-Fi, Bluetooth   click the switch to turn on / off, click the name for the
//                      list of networks / paired devices (click one to connect)
//   tiles              Do Not Disturb, Night Light, Tailscale
//   sliders            display brightness, volume (click the icon to mute)
//   now playing        any MPRIS player
// Esc or a click elsewhere closes it. The widget itself is a 1 px item in the top panel.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    activationTogglesExpanded: false
    Style { id: st }

    // ---- open / close (same guards as Spotlight: the shortcut fires twice)
    property double lastToggle: 0
    property bool ready: false
    Timer { interval: 3000; running: true; onTriggered: root.ready = true }
    function toggle() {
        if (!ready || Date.now() - lastToggle < 300) return
        lastToggle = Date.now()
        win.visible ? close() : open()
    }
    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    onExpandedChanged: (on) => { if (on) { root.toggle(); Qt.callLater(() => root.expanded = false) } }
    property string page: "main"        // main, wifi, bluetooth
    function open() {
        page = "main"
        refresh()
        win.visible = true
        win.requestActivate()
        panel.forceActiveFocus()
    }
    function close() { win.visible = false }

    fullRepresentation: Item {
        Layout.preferredWidth: 1; Layout.minimumWidth: 1; Layout.maximumWidth: 1
        Layout.preferredHeight: 1
    }

    // ---- state
    PlasmaNM.EnabledConnections { id: nm }
    PlasmaNM.Handler { id: nmHandler }
    NotificationManager.Settings { id: notif }
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing

    readonly property bool btOn: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    property int btTick: 0
    Connections { target: BluezQt.Manager; function onDeviceChanged() { root.btTick++ } }
    readonly property string btWhat: {
        btTick
        if (!btOn) return "Off"
        const c = BluezQt.Manager.devices.filter(d => d.connected)
        return c.length === 0 ? "On" : c.length === 1 ? c[0].name : c.length + " devices"
    }
    property string ssid: ""
    readonly property string wifiWhat: !nm.wirelessEnabled ? "Off" : ssid || "Not connected"
    readonly property bool dndOn: notif.notificationsInhibitedUntil !== undefined
                                  && !isNaN(notif.notificationsInhibitedUntil) && notif.notificationsInhibitedUntil > new Date()
    property bool nightOn: false
    property string tsState: "…"
    property real vol: 0;   property bool volMuted: false
    property real light: 0; property int lightMax: 1
    property bool dragging: false

    readonly property string qd: "qdbus6 org.kde.KWin /org/kde/KWin/NightLight org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight "
    readonly property string cmdSsid: "nmcli -t -f TYPE,NAME connection show --active | sed -n 's/^802-11-wireless://p' | head -1"
    readonly property string cmdNight: "echo $(" + qd + "enabled) $(" + qd + "inhibited)"
    readonly property string cmdTs: "command -v tailscale >/dev/null || { echo none; exit; }; tailscale status >/dev/null 2>&1 && echo on || echo off"
    readonly property string bd: "qdbus6 org.kde.ScreenBrightness /org/kde/ScreenBrightness/display0 org.kde.ScreenBrightness.Display."
    readonly property string cmdLevels: "echo $(wpctl get-volume @DEFAULT_AUDIO_SINK@) '|' $(" + bd + "Brightness) $(" + bd + "MaxBrightness)"
    function refresh() { exec.run(cmdNight); exec.run(cmdTs); exec.run(cmdLevels); exec.run(cmdSsid) }
    function setLevel(kind, v) {
        v = Math.max(0, Math.min(1, v))
        if (kind === "vol") { vol = v; exec.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2)) }
        else { light = v; exec.run(bd + "SetBrightness " + Math.max(1, Math.round(v * lightMax)) + " 0") }
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            const out = (data["stdout"] || "").trim()
            if (src === root.cmdNight) {
                const p = out.split(/\s+/); root.nightOn = p[0] === "true" && p[1] !== "true"
            } else if (src === root.cmdLevels) {
                if (!root.dragging) {
                    const parts = out.split("|").map(x => x.trim())
                    root.vol = Math.min(1, parseFloat(((parts[0] || "").match(/Volume:\s*([\d.]+)/) || [0, 0])[1]))
                    root.volMuted = /MUTED/.test(parts[0])
                    const b = (parts[1] || "").split(/\s+/).map(Number)
                    if (b[1] > 0) { root.lightMax = b[1]; root.light = b[0] / b[1] }
                }
            } else if (src === root.cmdSsid) {
                root.ssid = out
            } else if (src === root.cmdTs) {
                root.tsState = out
            } else if (src.startsWith("qdbus6 org.kde.kglobalaccel")) {
                nightCheck.restart()
            } else if (src.startsWith("tailscale ")) {
                exec.run(root.cmdTs)
            }
            disconnectSource(src)
        }
        function run(c) { connectSource(c) }
    }
    Timer { interval: 3000; running: win.visible; repeat: true; onTriggered: { exec.run(root.cmdLevels); exec.run(root.cmdNight); exec.run(root.cmdSsid) } }
    Timer { id: nightCheck; interval: 600; onTriggered: exec.run(root.cmdNight) }

    // for testing on its own: `plasmawindowed org.frost.controlcentre frost-test:main|wifi|bluetooth [frost-shot:/path.png]`
    Timer {
        interval: 1500; running: Qt.application.name === "plasmawindowed"
        onTriggered: {
            const args = Qt.application.arguments
            const a = args.find(x => x.startsWith("frost-test:"))
            if (!a) return
            root.ready = true; root.open(); root.page = a.slice(11) || "main"
            if (args.find(x => x.startsWith("frost-shot:"))) shotTimer.start()
        }
    }
    Timer {
        id: shotTimer; interval: 3500
        onTriggered: panel.grabToImage(r => { r.saveToFile(Qt.application.arguments.find(x => x.startsWith("frost-shot:")).slice(11)); Qt.quit() })
    }

    // ---- pieces
    readonly property rect scr: Plasmoid.containment && Plasmoid.containment.screenGeometry.width > 0
                                ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, Screen.width || 1920, Screen.height || 1080)
    readonly property int panelW: 380

    // a rounded section of the panel
    component Section: Rectangle {
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: st.faint
    }
    // a round icon switch
    component Bubble: Rectangle {
        id: bb
        property string icon
        property bool on: false
        signal hit()
        implicitWidth: 34; implicitHeight: 34
        radius: 17
        color: on ? st.accent : (bm.containsMouse ? st.hover : Qt.rgba(1, 1, 1, 0.10))
        scale: bm.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
        Kirigami.Icon { anchors.centerIn: parent; width: 17; height: 17; isMask: true; source: bb.icon
                        color: bb.on ? st.textOnAccent : st.text }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bb.hit() }
    }
    // switch + name + state, and a chevron that opens its list
    component ConnRow: Item {
        id: cr
        property string icon
        property string label
        property string sub
        property bool on: false
        property bool hasList: true
        signal toggled()
        signal more()
        implicitHeight: 46
        Rectangle { anchors.fill: parent; radius: 12; color: cm.containsMouse && cr.hasList ? st.faint : "transparent" }
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 8 }
            spacing: 10
            Bubble { icon: cr.icon; on: cr.on; onHit: cr.toggled() }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: cr.label; color: st.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text { text: cr.sub; color: st.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
            }
            Text { visible: cr.hasList; text: "›"; color: st.muted; font.pixelSize: 20 }
        }
        MouseArea {   // everything but the switch opens the list
            id: cm
            anchors { fill: parent; leftMargin: 46 }
            hoverEnabled: true
            enabled: cr.hasList
            cursorShape: Qt.PointingHandCursor
            onClicked: cr.more()
        }
    }
    // a square tile: icon on top, name and state below
    component Tile: Rectangle {
        id: tl
        property string icon
        property string label
        property string sub
        property bool on: false
        signal hit()
        radius: 16
        color: on ? Qt.rgba(242/255, 29/255, 67/255, 0.30) : (tm.containsMouse ? st.hover : Qt.rgba(1, 1, 1, 0.06))
        border.color: on ? Qt.rgba(242/255, 29/255, 67/255, 0.55) : st.faint
        scale: tm.pressed ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            spacing: 10
            Kirigami.Icon { source: tl.icon; isMask: true; color: tl.on ? st.accent : st.text
                            Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: tl.label; color: st.text; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: tl.sub; color: tl.on ? Qt.rgba(1, 1, 1, 0.8) : st.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tl.hit() }
    }
    // a wide slider that fills from the left, icon inside
    component HSlider: ColumnLayout {
        id: hs
        property string title
        property string kind
        property real value
        property bool muted: false
        property string icon
        property string mutedIcon: icon
        spacing: 6
        Text { text: hs.title; color: st.text; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.leftMargin: 2 }
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.30)
            border.color: st.faint
            clip: true
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(track.height, track.width * hs.value)
                radius: track.radius
                color: hs.muted ? st.subtle : st.fill
                Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 160 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                property real lastSent: 0
                function at(x) { return x / width }
                onPressed: (e) => { root.dragging = true; root.setLevel(hs.kind, at(e.x)) }
                onPositionChanged: (e) => { if (Date.now() - lastSent > 80) { lastSent = Date.now(); root.setLevel(hs.kind, at(e.x)) } }
                onReleased: (e) => { root.setLevel(hs.kind, at(e.x)); root.dragging = false }
                onWheel: (w) => root.setLevel(hs.kind, hs.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            }
            Kirigami.Icon {
                anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                width: 15; height: 15; isMask: true
                source: hs.muted ? hs.mutedIcon : hs.icon
                color: hs.muted ? st.text : st.textOnFill
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: hs.kind === "vol"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.volMuted = !root.volMuted; exec.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") }
                }
            }
            Text {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: hs.muted ? "off" : Math.round(hs.value * 100)
                color: hs.value > 0.9 && !hs.muted ? st.textOnFill : st.muted
                font.family: st.mono; font.pixelSize: 10
            }
        }
    }
    component MediaBtn: Kirigami.Icon {
        id: mb
        signal hit()
        implicitWidth: 22; implicitHeight: 22
        isMask: true
        color: mbm.containsMouse ? st.accent : st.text
        MouseArea { id: mbm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mb.hit() }
    }

    PlasmaCore.Dialog {
        id: win
        visible: false
        type: PlasmaCore.Dialog.Normal
        // the Frost theme's dialog frame: translucent glass, blurred by KWin
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        x: root.scr.x + root.scr.width / 2 - width / 2
        y: root.scr.y + 46                      // just under the island

        mainItem: FocusScope {
            id: panel
            width: root.panelW
            height: root.page === "main" ? mainCol.implicitHeight : listCol.implicitHeight
            Keys.onEscapePressed: root.page === "main" ? root.close() : root.page = "main"

            // ---- the main page
            ColumnLayout {
                id: mainCol
                visible: root.page === "main"
                width: parent.width
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Section {   // connectivity
                        Layout.preferredWidth: (root.panelW - 10) * 0.56
                        Layout.preferredHeight: 3 * 46 + 12
                        ColumnLayout {
                            anchors { fill: parent; margins: 6 }
                            spacing: 0
                            ConnRow {
                                Layout.fillWidth: true
                                icon: nm.wirelessEnabled ? "network-wireless" : "network-wireless-disconnected"
                                label: "Wi-Fi"; sub: root.wifiWhat; on: nm.wirelessEnabled
                                onToggled: nmHandler.enableWireless(!nm.wirelessEnabled)
                                onMore: root.page = "wifi"
                            }
                            ConnRow {
                                Layout.fillWidth: true
                                icon: root.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                                label: "Bluetooth"; sub: root.btWhat; on: root.btOn
                                onToggled: BluezQt.Manager.bluetoothBlocked = !BluezQt.Manager.bluetoothBlocked
                                onMore: root.page = "bluetooth"
                            }
                            ConnRow {
                                Layout.fillWidth: true
                                visible: root.tsState !== "none"
                                icon: "network-vpn"; label: "Tailscale"; hasList: false
                                sub: root.tsState === "on" ? "Connected" : root.tsState === "off" ? "Off" : "…"
                                on: root.tsState === "on"
                                onToggled: exec.run(root.tsState === "on" ? "tailscale down" : "tailscale up")
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        Tile {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            icon: root.dndOn ? "notifications-disabled" : "notifications"
                            label: "Do Not Disturb"; sub: root.dndOn ? "On" : "Off"; on: root.dndOn
                            onHit: {
                                if (root.dndOn) { notif.notificationsInhibitedUntil = undefined; notif.revokeApplicationInhibitions() }
                                else { const d = new Date(); d.setFullYear(d.getFullYear() + 1); notif.notificationsInhibitedUntil = d }
                                notif.save()
                            }
                        }
                        Tile {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            icon: "redshift-status-on"; label: "Night Light"; sub: root.nightOn ? "On" : "Off"; on: root.nightOn
                            onHit: exec.run('qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Toggle Night Color"')
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    Layout.preferredHeight: sliders.implicitHeight + 24
                    ColumnLayout {
                        id: sliders
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 12
                        HSlider { Layout.fillWidth: true; title: "Display"; kind: "light"; value: root.light; icon: "brightness-high" }
                        HSlider { Layout.fillWidth: true; title: "Sound"; kind: "vol"; value: root.vol; muted: root.volMuted
                                  icon: "audio-volume-high"; mutedIcon: "audio-volume-muted" }
                    }
                }

                Section {   // now playing
                    visible: !!root.player && (root.player.track || "").length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 48; Layout.preferredHeight: 48
                            radius: 10; color: st.faint; clip: true
                            Image { anchors.fill: parent; source: root.player ? root.player.artUrl : ""; fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(96, 96); asynchronous: true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: root.player ? root.player.track : ""; color: st.text; font.pixelSize: 13; font.weight: Font.DemiBold
                                   elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                            Text { text: root.player ? (root.player.artist || root.player.identity) : ""; color: st.muted; font.pixelSize: 11
                                   elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                        }
                        MediaBtn { source: "media-skip-backward"; onHit: root.player.Previous() }
                        MediaBtn { source: root.playing ? "media-playback-pause" : "media-playback-start"; onHit: root.player.PlayPause() }
                        MediaBtn { source: "media-skip-forward"; onHit: root.player.Next() }
                    }
                }

                RowLayout {   // footer
                    Layout.fillWidth: true
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    spacing: 8
                    Text { text: Qt.formatDate(new Date(), "dddd, d MMMM"); color: st.muted; font.pixelSize: 11; Layout.fillWidth: true }
                    Bubble { implicitWidth: 30; implicitHeight: 30; icon: "configure"
                             onHit: { exec.run("systemsettings"); root.close() } }
                    Bubble { implicitWidth: 30; implicitHeight: 30; icon: "system-shutdown"
                             onHit: { root.close(); exec.run("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptAll") } }
                }
            }

            // ---- the Wi-Fi / Bluetooth page
            ColumnLayout {
                id: listCol
                visible: root.page !== "main"
                width: parent.width
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Bubble { implicitWidth: 30; implicitHeight: 30; icon: "go-previous"; onHit: root.page = "main" }
                    Text { text: root.page === "wifi" ? "Wi-Fi" : "Bluetooth"; color: st.text; font.pixelSize: 15; font.weight: Font.DemiBold
                           Layout.fillWidth: true }
                    Bubble {   // on / off
                        readonly property bool isOn: root.page === "wifi" ? nm.wirelessEnabled : root.btOn
                        icon: root.page === "wifi" ? "network-wireless" : "network-bluetooth"
                        on: isOn
                        onHit: root.page === "wifi" ? nmHandler.enableWireless(!nm.wirelessEnabled)
                                                    : BluezQt.Manager.bluetoothBlocked = !BluezQt.Manager.bluetoothBlocked
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: st.faint }
                WifiList { visible: root.page === "wifi"; Layout.fillWidth: true; maxRows: 8 }
                BluetoothList { visible: root.page === "bluetooth"; Layout.fillWidth: true; maxRows: 8 }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: st.faint }
                Text {
                    Layout.leftMargin: 6; Layout.bottomMargin: 2
                    text: root.page === "wifi" ? "Network Settings…" : "Bluetooth Settings…"
                    color: lm.containsMouse ? st.accent : st.muted; font.pixelSize: 12
                    MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { exec.run(root.page === "wifi" ? "systemsettings kcm_networkmanagement" : "systemsettings kcm_bluetooth"); root.close() } }
                }
            }
        }
    }
}
