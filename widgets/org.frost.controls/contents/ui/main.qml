// Quick Controls: a phone-style control centre on a 4 x 4 grid of glass modules.
//
//   ┌───────────┬─────┬─────┐   connectivity  click a bubble to turn it on / off;
//   │ Wi-Fi  BT │     │     │                 right-click Wi-Fi / Bluetooth for its list,
//   │ Air    TS │ ☀   │ 🔊  │                 click the module around the bubbles for
//   ├───────────┼─────┼─────┤                 all four with names and details
//   │  Focus    │Night│ Mic │   faders        drag (from where they are) or scroll; click the speaker to mute
//   ├─────┬─────┼─────┼─────┤   Sound         outputs, inputs and per-app volume
//   │Sound│Shot │Sett.│Power│   Power         Plasma's shutdown screen (it always asks)
//   └─────┴─────┴─────┴─────┘
//
// The list pages cover the card and swallow the mouse wheel, so scrolling a list
// never reaches the faders underneath.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
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

    // ---- state
    PlasmaNM.EnabledConnections { id: nm }
    PlasmaNM.Handler { id: nmHandler }
    NotificationManager.Settings { id: notif }
    Levels { id: lv }                    // live volume, mic, brightness (see Levels.qml)

    readonly property bool btBlocked: BluezQt.Manager.bluetoothBlocked
    readonly property bool btOn: BluezQt.Manager.bluetoothOperational && !btBlocked
    readonly property bool airplane: !nm.wirelessEnabled && btBlocked
    readonly property bool dndOn: notif.notificationsInhibitedUntil !== undefined
                                  && !isNaN(notif.notificationsInhibitedUntil) && notif.notificationsInhibitedUntil > new Date()
    property bool nightOn: false
    property string tsState: "…"         // on, off, none (not installed)
    property string tsHint: ""
    property string ssid: ""

    property int btTick: 0
    Connections { target: BluezQt.Manager; function onDeviceChanged() { root.btTick++ } }
    readonly property string btWhat: {
        btTick
        if (!btOn) return "Off"
        const c = BluezQt.Manager.devices.filter(d => d.connected)
        if (c.length !== 1) return c.length === 0 ? "Not connected" : c.length + " devices"
        const b = c[0].battery ? c[0].battery.percentage : -1
        return c[0].name + (b >= 0 ? "  ·  " + b + "%" : "")
    }
    readonly property string wifiWhat: !nm.wirelessEnabled ? "Off" : ssid || "Not connected"
    readonly property string tsWhat: tsHint || ({ on: "Connected", off: "Off", none: "Not installed" })[tsState] || "…"
    readonly property bool outputIsBt: lv.sinks.some(s => s.default && s.bt)

    function setAirplane(on) {
        nmHandler.enableWireless(!on)
        BluezQt.Manager.bluetoothBlocked = on
    }
    function toggleDnd() {
        if (dndOn) { notif.notificationsInhibitedUntil = undefined; notif.revokeApplicationInhibitions() }
        else { const d = new Date(); d.setFullYear(d.getFullYear() + 1); notif.notificationsInhibitedUntil = d }
        notif.save()
    }
    function toggleTs() { if (tsState !== "none") exec.run(tsState === "on" ? "tailscale down" : "tailscale up") }

    // ---- pages: "" (the grid), network, wifi, bluetooth, audio
    property string page: ""
    property string back: ""             // where the back button goes
    function show(p, from) { back = from || ""; page = p }

    readonly property string qd: "qdbus6 org.kde.KWin /org/kde/KWin/NightLight org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight "
    readonly property string cmdNight: "echo $(" + qd + "enabled) $(" + qd + "inhibited)"
    readonly property string cmdTs: "command -v tailscale >/dev/null || { echo none; exit; }; tailscale status >/dev/null 2>&1 && echo on || echo off"
    readonly property string cmdSsid: "nmcli -t -f TYPE,NAME connection show --active | sed -n 's/^802-11-wireless://p' | head -1"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            const out = (data["stdout"] || "").trim(), err = (data["stderr"] || "").trim()
            if (src === root.cmdNight) {
                const p = out.split(/\s+/); root.nightOn = p[0] === "true" && p[1] !== "true"
            } else if (src === root.cmdTs) {
                root.tsState = out
            } else if (src === root.cmdSsid) {
                root.ssid = out
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
            onTriggered: { exec.run(root.cmdNight); exec.run(root.cmdTs); exec.run(root.cmdSsid) } }
    Timer { id: nightCheck; interval: 600; onTriggered: exec.run(root.cmdNight) }
    Connections { target: nm; function onWirelessEnabledChanged() { ssidCheck.restart() } }
    Timer { id: ssidCheck; interval: 2500; onTriggered: exec.run(root.cmdSsid) }

    // for testing on its own:
    //   plasmawindowed org.frost.controls frost-test:main|network|wifi|bluetooth|audio [frost-shot:/path.png]
    Timer {
        interval: 1500; running: Qt.application.name === "plasmawindowed"
        onTriggered: {
            const args = Qt.application.arguments, a = args.find(x => x.startsWith("frost-test:"))
            if (!a) return
            const p = a.slice(11)
            root.show(p === "main" ? "" : p)
            if (args.find(x => x.startsWith("frost-shot:"))) shotTimer.start()
        }
    }
    Timer {
        id: shotTimer; interval: 3500
        onTriggered: root.fullRepresentationItem.grabToImage(r => { r.saveToFile(Qt.application.arguments.find(x => x.startsWith("frost-shot:")).slice(11)); Qt.quit() })
    }

    fullRepresentation: GlassCard {
        id: card
        Layout.minimumWidth: 240; Layout.minimumHeight: 240
        Layout.preferredWidth: 288; Layout.preferredHeight: 288
        Style { id: st }

        // the grid: 4 x 4 square units
        readonly property int pad: 16
        readonly property int gap: 10
        readonly property int u: Math.floor(Math.min(width - 2 * pad - 3 * gap, height - 2 * pad - 3 * gap) / 4)
        readonly property int mr: Math.round(u * 0.36)                 // module corner radius
        function at(i) { return i * (u + gap) }
        function span(n) { return n * u + (n - 1) * gap }
        readonly property color module: Qt.rgba(1, 1, 1, 0.07)
        readonly property color moduleHover: Qt.rgba(1, 1, 1, 0.11)
        readonly property color light: "#F2F2F5"                     // "on" tiles and the fader fill

        // a hover hint (the tiles are icons only)
        component Tip: QQC2.ToolTip { delay: 600; timeout: 2500 }

        // a round on / off bubble, for the connectivity module
        component Bubble: Item {
            id: bb
            property string icon
            property bool on: false
            property bool dim: false
            property string tip
            signal hit()
            signal more()
            opacity: dim ? 0.35 : 1
            Rectangle {
                id: disc
                anchors.centerIn: parent
                width: Math.round(card.u * 0.8); height: width; radius: width / 2
                color: bb.on ? st.accent : (bm.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                scale: bm.pressed ? 0.9 : 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Kirigami.Icon { anchors.centerIn: parent; width: Math.round(parent.width * 0.44); height: width
                                isMask: true; color: "white"; source: bb.icon }
            }
            MouseArea {
                id: bm
                anchors.fill: disc
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: (m) => m.button === Qt.RightButton ? bb.more() : bb.hit()
            }
            Tip { visible: bm.containsMouse && bb.tip.length > 0; text: bb.tip }
        }

        // a square icon tile: dark glass when off, light with a red icon when on
        component Tile: Rectangle {
            id: tl
            property string icon
            property bool on: false
            property string tip
            signal hit()
            radius: card.mr
            color: on ? card.light : (tm.containsMouse ? card.moduleHover : card.module)
            scale: tm.pressed ? 0.94 : 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Kirigami.Icon { anchors.centerIn: parent; width: Math.round(card.u * 0.4); height: width
                            isMask: true; color: tl.on ? st.accent : st.text; source: tl.icon }
            MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tl.hit() }
            Tip { visible: tm.containsMouse && tl.tip.length > 0; text: tl.tip }
        }

        // a short, wide vertical fader that fills from the bottom with a flat top.
        // Like a phone: grabbing it moves the level from where it is (no jump to the
        // pointer), a click without dragging goes to that spot. The fill follows the
        // pointer every frame; the system is told at most every 40 ms, and once more
        // on release with the exact value.
        component Fader: Rectangle {
            id: fd
            property string kind
            property real value
            property bool muted: false
            property string icon
            property string mutedIcon: icon
            property string tip
            property real local: 0                     // the level while it's ours (dragging, scrolling)
            readonly property bool own: fm.pressed || push.running || release.running
            readonly property real level: muted && !own ? 0 : Math.max(0, Math.min(1, own ? local : value))
            function set(v) {
                local = Math.max(0, Math.min(1, v))
                release.restart()
                if (!push.running) push.start()
            }
            Timer { id: push; interval: 40; onTriggered: lv.setLevel(fd.kind, fd.local) }
            Timer { id: release; interval: 450 }       // keep our value until the system has caught up
            radius: card.mr
            color: fm.containsMouse || fm.pressed ? card.moduleHover : card.module
            Behavior on color { ColorAnimation { duration: 160 } }

            Item {   // clipped box: its top edge is the level, the rounded bottom stays
                id: fillBox
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: fd.height * fd.level
                clip: true
                // follow the pointer exactly while dragging; glide for clicks, scrolling and outside changes
                Behavior on height { enabled: !fm.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: fd.height; radius: fd.radius
                    color: card.light
                }
            }
            Text {   // the number, while the pointer is on it
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 9 }
                text: fd.muted && !fd.own ? "off" : Math.round(fd.level * 100)
                opacity: fm.containsMouse || fm.pressed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                color: fillBox.height > fd.height - 22 ? st.textOnFill : st.muted
                font.family: st.mono; font.pixelSize: 10
            }
            MouseArea {
                id: fm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                property real startV: 0
                property real startY: 0
                property bool dragging: false
                onPressed: (e) => {
                    if (fd.muted && fd.kind !== "light") lv.toggleMute(fd.kind)   // touching it unmutes
                    lv.dragging = true
                    startV = fd.muted ? 0 : Math.max(0, Math.min(1, fd.value)); startY = e.y
                    dragging = false
                    fd.local = startV
                }
                onPositionChanged: (e) => {
                    if (!pressed) return
                    if (!dragging && Math.abs(e.y - startY) < 3) return
                    dragging = true
                    fd.set(startV + (startY - e.y) / height)
                }
                onReleased: (e) => {
                    if (!dragging) fd.set(1 - e.y / height)               // a click: go there
                    push.stop(); lv.setLevel(fd.kind, fd.local)            // the exact final value
                    release.restart()
                    dragging = false; lv.dragging = false
                }
                onCanceled: { dragging = false; lv.dragging = false }      // else the levels would never refresh again
                onWheel: (w) => {
                    // mouse wheels move 5% a notch; touchpads move with the fingers
                    const d = w.pixelDelta.y !== 0 ? w.pixelDelta.y / 300 : w.angleDelta.y / 120 * 0.05
                    if (!fd.own) fd.local = fd.muted ? 0 : fd.value
                    fd.set(fd.local + d)
                    w.accepted = true
                }
            }
            Kirigami.Icon {   // click to mute (volume)
                id: fIcon
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Math.round(card.u * 0.22) }
                width: Math.round(card.u * 0.38); height: width; isMask: true
                source: fd.muted && !fd.own ? fd.mutedIcon : fd.icon
                color: fillBox.height > fIcon.anchors.bottomMargin + height / 2 ? st.textOnFill : st.text
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: fd.kind !== "light"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: lv.toggleMute(fd.kind)
                }
            }
            Tip { visible: fm.containsMouse && !fm.pressed && fd.tip.length > 0; text: fd.tip }
        }

        // ---- the grid
        Item {
            id: grid
            width: card.span(4); height: card.span(4)
            anchors.centerIn: parent
            enabled: root.page === ""
            opacity: root.page === "" ? 1 : 0
            scale: root.page === "" ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {   // connectivity, 2 x 2; the space around the bubbles opens the details
                x: 0; y: 0; width: card.span(2); height: card.span(2)
                radius: card.mr
                color: netM.containsMouse ? card.moduleHover : card.module
                Behavior on color { ColorAnimation { duration: 160 } }
                MouseArea { id: netM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.show("network") }
                Grid {
                    anchors.fill: parent
                    columns: 2
                    Bubble {
                        width: parent.width / 2; height: parent.height / 2
                        icon: nm.wirelessEnabled ? "network-wireless" : "network-wireless-disconnected"
                        on: nm.wirelessEnabled; tip: "Wi-Fi: " + root.wifiWhat
                        onHit: nmHandler.enableWireless(!nm.wirelessEnabled)
                        onMore: root.show("wifi")
                    }
                    Bubble {
                        width: parent.width / 2; height: parent.height / 2
                        icon: root.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                        on: root.btOn; tip: "Bluetooth: " + root.btWhat
                        onHit: BluezQt.Manager.bluetoothBlocked = !root.btBlocked
                        onMore: root.show("bluetooth")
                    }
                    Bubble {
                        width: parent.width / 2; height: parent.height / 2
                        icon: "network-flightmode-on"; on: root.airplane; tip: "Airplane mode"
                        onHit: root.setAirplane(!root.airplane)
                        onMore: root.show("network")
                    }
                    Bubble {
                        width: parent.width / 2; height: parent.height / 2
                        icon: "network-vpn"; on: root.tsState === "on"; dim: root.tsState === "none"
                        tip: "Tailscale: " + root.tsWhat
                        onHit: root.toggleTs()
                        onMore: root.show("network")
                    }
                }
            }
            Fader {
                x: card.at(2); y: 0; width: card.u; height: card.span(2)
                kind: "light"; value: lv.light; icon: "brightness-high"; tip: "Brightness"
            }
            Fader {
                x: card.at(3); y: 0; width: card.u; height: card.span(2)
                kind: "vol"; value: lv.vol; muted: lv.volMuted; tip: lv.output || "Volume"
                icon: lv.vol < 0.34 ? "audio-volume-low" : lv.vol < 0.67 ? "audio-volume-medium" : "audio-volume-high"
                mutedIcon: "audio-volume-muted"
            }

            Rectangle {   // Focus (Do Not Disturb), 2 x 1
                id: focusTile
                x: 0; y: card.at(2); width: card.span(2); height: card.u
                radius: card.mr
                color: root.dndOn ? card.light : (fcM.containsMouse ? card.moduleHover : card.module)
                scale: fcM.pressed ? 0.96 : 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                RowLayout {
                    anchors { fill: parent; leftMargin: Math.round(card.u * 0.16); rightMargin: 10 }
                    spacing: 9
                    Rectangle {
                        Layout.preferredWidth: Math.round(card.u * 0.62); Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: root.dndOn ? st.accent : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Kirigami.Icon { anchors.centerIn: parent; width: Math.round(parent.width * 0.5); height: width
                                        isMask: true; color: "white"
                                        source: root.dndOn ? "notifications-disabled" : "notifications" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: "Focus"; color: root.dndOn ? st.textOnFill : st.text
                               font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: root.dndOn ? "Do Not Disturb" : "Off"; color: root.dndOn ? Qt.rgba(0.1, 0.1, 0.12, 0.7) : st.muted
                               font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
                MouseArea { id: fcM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleDnd() }
            }
            Tile {
                x: card.at(2); y: card.at(2); width: card.u; height: card.u
                icon: "redshift-status-on"; on: root.nightOn; tip: "Night Light"
                onHit: exec.run('qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Toggle Night Color"')
            }
            Tile {
                x: card.at(3); y: card.at(2); width: card.u; height: card.u
                icon: lv.micMuted ? "microphone-sensitivity-muted" : "audio-input-microphone"
                on: lv.micMuted; tip: lv.micMuted ? "Microphone off" : "Microphone on"
                onHit: lv.toggleMute("mic")
            }

            Tile {
                x: 0; y: card.at(3); width: card.u; height: card.u
                icon: root.outputIsBt ? "audio-headphones-symbolic" : "audio-speakers-symbolic"; tip: "Sound: " + (lv.output || "outputs and apps")
                onHit: root.show("audio")
            }
            Tile {
                x: card.at(1); y: card.at(3); width: card.u; height: card.u
                icon: "camera-photo-symbolic"; tip: "Screenshot (region)"
                onHit: exec.run("spectacle -r")
            }
            Tile {
                x: card.at(2); y: card.at(3); width: card.u; height: card.u
                icon: "preferences-system-symbolic"; tip: "System Settings"
                onHit: exec.run("systemsettings")
            }
            Tile {
                x: card.at(3); y: card.at(3); width: card.u; height: card.u
                icon: "system-shutdown-symbolic"; tip: "Power"
                onHit: exec.run("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptAll")
            }
        }

        // ---- a page over the whole card: the network details, or a list
        Rectangle {
            id: sheet
            anchors.fill: parent
            radius: card.radius
            color: "#121216"
            border.color: st.border
            property string shown: ""        // keeps the last page while it fades out
            Connections { target: root; function onPageChanged() { if (root.page) sheet.shown = root.page } }
            opacity: root.page ? 1 : 0
            visible: opacity > 0.01
            scale: root.page ? 1 : 1.03
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // swallow every click and wheel that a list doesn't take, so nothing
            // reaches the faders below
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onWheel: (w) => w.accepted = true
            }

            component Row_: Rectangle {
                id: nr
                property string icon
                property string label
                property string sub
                property bool on: false
                property bool dim: false
                property bool hasList: false
                signal toggled()
                signal more()
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 12
                color: nrM.containsMouse && hasList ? st.hover : "transparent"
                opacity: dim ? 0.45 : 1
                RowLayout {
                    anchors { fill: parent; leftMargin: 4; rightMargin: 8 }
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                        color: nr.on ? st.accent : (swM.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12))
                        scale: swM.pressed ? 0.9 : 1
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on scale { NumberAnimation { duration: 110 } }
                        Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; isMask: true; color: "white"; source: nr.icon }
                        MouseArea { id: swM; anchors.fill: parent; z: 2; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: nr.toggled() }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: nr.label; color: st.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { text: nr.sub; color: st.muted; font.pixelSize: 11; elide: Text.ElideRight
                               Layout.fillWidth: true; textFormat: Text.PlainText }
                    }
                    Kirigami.Icon { visible: nr.hasList; source: "go-next"; isMask: true; color: st.muted
                                    Layout.preferredWidth: 14; Layout.preferredHeight: 14 }
                }
                MouseArea { id: nrM; anchors.fill: parent; anchors.leftMargin: 42; hoverEnabled: true
                            enabled: nr.hasList; cursorShape: Qt.PointingHandCursor; onClicked: nr.more() }
            }

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
                        MouseArea { id: backM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.show(root.back) }
                    }
                    Text { text: ({ network: "Connections", wifi: "Wi-Fi", bluetooth: "Bluetooth", audio: "Sound" })[sheet.shown] || ""
                           color: st.text; font.pixelSize: 15; font.weight: Font.DemiBold
                           Layout.fillWidth: true }
                    Rectangle {   // on / off for the list's radio
                        visible: sheet.shown === "wifi" || sheet.shown === "bluetooth"
                        readonly property bool isOn: sheet.shown === "wifi" ? nm.wirelessEnabled : root.btOn
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                        color: isOn ? st.accent : (radM.containsMouse ? st.hover : st.faint)
                        Kirigami.Icon { anchors.centerIn: parent; width: 15; height: 15; isMask: true; color: "white"
                                        source: sheet.shown === "wifi" ? "network-wireless" : "network-bluetooth" }
                        MouseArea { id: radM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: sheet.shown === "wifi" ? nmHandler.enableWireless(!nm.wirelessEnabled)
                                                                      : BluezQt.Manager.bluetoothBlocked = !root.btBlocked }
                    }
                }

                ColumnLayout {   // the connectivity module, opened up
                    visible: sheet.shown === "network"
                    Layout.fillWidth: true
                    spacing: 2
                    Row_ { icon: nm.wirelessEnabled ? "network-wireless" : "network-wireless-disconnected"
                           label: "Wi-Fi"; sub: root.wifiWhat; on: nm.wirelessEnabled; hasList: true
                           onToggled: nmHandler.enableWireless(!nm.wirelessEnabled); onMore: root.show("wifi", "network") }
                    Row_ { icon: root.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                           label: "Bluetooth"; sub: root.btWhat; on: root.btOn; hasList: true
                           onToggled: BluezQt.Manager.bluetoothBlocked = !root.btBlocked; onMore: root.show("bluetooth", "network") }
                    Row_ { icon: "network-flightmode-on"; label: "Airplane Mode"; sub: root.airplane ? "On" : "Off"
                           on: root.airplane; onToggled: root.setAirplane(!root.airplane) }
                    Row_ { icon: "network-vpn"; label: "Tailscale"; sub: root.tsWhat
                           on: root.tsState === "on"; dim: root.tsState === "none"; onToggled: root.toggleTs() }
                }
                WifiList { visible: sheet.shown === "wifi"; Layout.fillWidth: true
                           maxRows: Math.max(2, Math.floor((sheet.height - 104) / rowH)) }
                BluetoothList { visible: sheet.shown === "bluetooth"; Layout.fillWidth: true
                                maxRows: Math.max(2, Math.floor((sheet.height - 104) / rowH)) }
                AudioList { visible: sheet.shown === "audio"; Layout.fillWidth: true; Layout.fillHeight: true
                            levels: lv; maxHeight: sheet.height - 104 }
                Item { Layout.fillHeight: sheet.shown !== "audio" }
                Text {
                    Layout.leftMargin: 4
                    readonly property var kcm: ({ network: "kcm_networkmanagement", wifi: "kcm_networkmanagement",
                                                  bluetooth: "kcm_bluetooth", audio: "kcm_pulseaudio" })
                    text: ({ network: "Network Settings…", wifi: "Network Settings…",
                             bluetooth: "Bluetooth Settings…", audio: "Sound Settings…" })[sheet.shown] || ""
                    color: setM.containsMouse ? st.accent : st.muted; font.pixelSize: 12
                    MouseArea { id: setM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: exec.run("systemsettings " + parent.kcm[sheet.shown]) }
                }
            }
        }
    }
}
