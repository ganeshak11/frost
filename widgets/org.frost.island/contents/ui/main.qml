// Dynamic Island for Plasma.
//
// A black pill at the top centre of the screen that shows live activities and
// morphs (with a springy animation) as things happen:
//   idle         the time; an orange dot when an app is using the microphone
//   music        artwork + live beat bars (any MPRIS player)
//   focus        timer icon + countdown from the Frost Focus widget
//   recording    red dot + elapsed time while the screen is recorded / shared
//   timer        countdown you start from the island (stopwatch counts up)
//   transfers    Dolphin / KIO copies and moves, Firefox / Brave downloads
//   two at once  the most important one in the pill, the next as a bubble
//   privacy      green dot = camera in use, orange dot = microphone in use
// Events briefly expand it into a banner, then it shrinks back:
//   notifications (click to open, hover to keep it), charger plugged in or
//   out, low battery, Bluetooth device connected, Do Not Disturb on/off,
//   timer finished, download finished, rain expected within the hour
// Click the pill to expand it: full music player, big focus timer, or (when
// idle) date, battery, devices and your latest notifications. It collapses
// when the pointer leaves it.
// Volume, brightness, mute and other on-screen displays slide out of the pill
// as a level bar (through the Frost OSD bridge, widgets/osd-bridge), and new
// banners make a soft sound unless Do Not Disturb is on.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    // the widget's global shortcut (right-click > Configure > Keyboard Shortcuts) opens/closes the island
    activationTogglesExpanded: false
    // Plasma both emits activated() and sets `expanded` when the shortcut fires;
    // either one toggles the island, the guard stops them cancelling out
    property double lastToggle: 0
    function toggleOpen() {
        if (Date.now() - lastToggle < 400) return
        lastToggle = Date.now()
        current ? nextBanner() : (isOpen = !isOpen)
    }
    Connections { target: Plasmoid; function onActivated() { root.toggleOpen() } }
    onExpandedChanged: (on) => { if (on) { root.toggleOpen(); Qt.callLater(() => root.expanded = false) } }

    readonly property color accent: "#F21D43"
    readonly property color text: "#F2F2F5"
    readonly property color muted: "#9A9AA6"
    readonly property string mono: "JetBrains Mono"
    readonly property int pillH: 32
    readonly property int pillTop: 4

    // ---- clock -------------------------------------------------------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { root.now = new Date(); root.tickMusic(); root.checkTimer() } }

    // ---- music -------------------------------------------------------------
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    property double lastPlaying: 0
    readonly property bool musicActive: !!player && (player.track || "").length > 0 && (playing || now.getTime() - lastPlaying < 30000)
    onPlayingChanged: lastPlaying = Date.now()
    function tickMusic() { if (playing) { lastPlaying = Date.now(); player.updatePosition() } }
    function clock(us) { const s = Math.max(0, Math.floor((us || 0) / 1e6)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    property var bars: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property double lastStart: 0
    readonly property string beatsHelper: "setsid python3 '" + Qt.resolvedUrl("../code/beats.py").toString().replace("file://", "") + "' >/dev/null 2>&1 &"
    Timer {
        interval: 60; repeat: true; running: root.playing && root.musicActive
        onTriggered: {
            const xhr = new XMLHttpRequest()
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) { try { const v = JSON.parse(xhr.responseText); if (v.length) root.bars = v.filter((_, i) => i % 2 === 0).slice(0, 16) } catch (e) {} }
                else if (Date.now() - root.lastStart > 5000) { root.lastStart = Date.now(); exec.connectSource(root.beatsHelper) }
            }
            xhr.open("GET", "http://127.0.0.1:47821/"); xhr.send()
        }
        onRunningChanged: if (!running) root.bars = root.bars.map(() => 0)
    }

    // ---- system status (battery, mic, bluetooth, focus timer) --------------
    property var sys: ({ battery: null, mic: [], cam: [], rec: [], bt: [], dl: [], recent: [], focus: null, loc: null })
    readonly property string statusCmd: "python3 '" + Qt.resolvedUrl("../code/status.py").toString().replace("file://", "") + "'"
    P5Support.DataSource {
        id: exec; engine: "executable"
        onNewData: (src, data) => {
            if (src === root.statusCmd) { try { root.applyStatus(JSON.parse(data["stdout"])) } catch (e) {} }
            disconnectSource(src)
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.connectSource(root.statusCmd) }

    property bool firstStatus: true
    function applyStatus(s) {
        const old = sys
        sys = s
        if (firstStatus) { firstStatus = false; return }
        const b = s.battery, ob = old.battery
        if (b && ob) {
            const plugged = (x) => x.ac !== undefined ? x.ac : x.status !== "Discharging"
            if (plugged(b) && !plugged(ob)) banner({ icon: "battery-charging", title: "Charging", value: b.pct + "%", tint: "#4ade80", battery: b.pct })
            else if (!plugged(b) && plugged(ob)) banner({ icon: "battery-full", title: "On battery", value: b.pct + "%", battery: b.pct })
            if (!plugged(b) && b.pct <= 20 && ob.pct > 20) banner({ icon: "battery-caution", title: "Low battery", value: b.pct + "%", tint: accent, battery: b.pct })
        }
        // browser downloads: speed from the size change, a banner when one ends
        const prev = {}
        for (const d of (old.dl || [])) prev[d.path] = d
        for (const d of (s.dl || [])) d.speed = prev[d.path] ? Math.max(0, (d.bytes - prev[d.path].bytes) / 3) : 0
        for (const d of (old.dl || [])) if (!(s.dl || []).some(x => x.path === d.path)) {
            const ok = (s.recent || []).includes(d.name)
            banner({ icon: ok ? "folder-download" : "dialog-cancel", app: d.from, title: d.name,
                     value: ok ? "Downloaded" : "Stopped", tint: ok ? "#4ade80" : muted,
                     url: ok ? "file://" + d.path.replace(/\.(part|crdownload)$/, "") : "" })
        }
        for (const d of s.bt) if (!(old.bt || []).includes(d)) banner({ icon: "audio-headphones", title: d, value: "Connected" })
        for (const d of (old.bt || [])) if (!s.bt.includes(d)) banner({ icon: "bluetooth-disabled", title: d, value: "Disconnected" })
    }
    readonly property bool charging: !!sys.battery && sys.battery.status === "Charging"
    readonly property bool micInUse: (sys.mic || []).length > 0
    readonly property bool camInUse: (sys.cam || []).length > 0
    readonly property bool recording: (sys.rec || []).length > 0
    property double recSince: 0
    onRecordingChanged: recSince = recording ? Date.now() : 0
    readonly property var dl: (sys.dl || []).length ? sys.dl[0] : null
    readonly property bool dlActive: !!dl
    function size(b) {
        const u = ["B", "KB", "MB", "GB"]; let i = 0; b = Number(b) || 0
        while (b >= 1024 && i < 3) { b /= 1024; i++ }
        return (i ? b.toFixed(b < 10 ? 1 : 0) : b.toFixed(0)) + " " + u[i]
    }
    function hms(sec) {
        sec = Math.max(0, Math.floor(sec))
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), x = sec % 60
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(x).padStart(2, "0")
    }
    readonly property string recText: hms((now.getTime() - recSince) / 1000)

    // ---- timer and stopwatch (started from the expanded island) -------------
    readonly property var cfg: Plasmoid.configuration
    readonly property bool timerRunning: Number(cfg.timerEnd) > 0
    readonly property bool timerActive: timerRunning || cfg.timerLeft > 0
    readonly property int timerLeftNow: timerRunning ? Math.max(0, Math.ceil((Number(cfg.timerEnd) - now.getTime()) / 1000)) : cfg.timerLeft
    readonly property real timerProgress: cfg.timerTotal > 0 ? 1 - timerLeftNow / cfg.timerTotal : 0
    function startTimer(min) { cfg.timerTotal = min * 60; cfg.timerLeft = 0; cfg.timerEnd = String(Date.now() + min * 60000); isOpen = false }
    function pauseTimer() { cfg.timerLeft = timerLeftNow; cfg.timerEnd = "0" }
    function resumeTimer() { cfg.timerEnd = String(Date.now() + cfg.timerLeft * 1000); cfg.timerLeft = 0 }
    function cancelTimer() { cfg.timerEnd = "0"; cfg.timerLeft = 0 }
    function addMinute() {
        cfg.timerTotal = cfg.timerTotal + 60
        timerRunning ? cfg.timerEnd = String(Number(cfg.timerEnd) + 60000) : cfg.timerLeft = cfg.timerLeft + 60
    }
    function checkTimer() {
        if (timerRunning && Number(cfg.timerEnd) <= Date.now()) {
            const total = cfg.timerTotal
            cancelTimer()
            banner({ icon: "chronometer", title: "Timer done", value: hms(total), tint: accent, urgent: true, alarm: true })
        }
    }
    readonly property bool swActive: cfg.swRunning || Number(cfg.swAcc) > 0
    readonly property double swMs: (Number(cfg.swAcc) || 0) + (cfg.swRunning ? now.getTime() - Number(cfg.swStart) : 0)
    function startSw() { cfg.swStart = String(Date.now()); cfg.swRunning = true; isOpen = false }
    function pauseSw() { cfg.swAcc = String(swMs); cfg.swRunning = false }
    function resetSw() { cfg.swAcc = "0"; cfg.swRunning = false }

    // ---- rain alert: precipitation in the next hour at the Weather widget's place
    property double lastRainAlert: 0
    function checkRain() {
        if (Date.now() - lastRainAlert < 2 * 3600000) return
        const l = sys.loc || { lat: 12.2958, lon: 76.6394, city: "Mysuru" }
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return
            try {
                const m = JSON.parse(xhr.responseText).minutely_15, t = Date.now()
                let i0 = 0
                for (let i = 0; i < m.time.length; i++) if (new Date(m.time[i]).getTime() <= t) i0 = i
                if ((m.precipitation[i0] || 0) >= 0.1) return                 // already raining
                for (let k = i0 + 1; k < Math.min(m.time.length, i0 + 5); k++) {
                    if ((m.precipitation[k] || 0) >= 0.2 || (m.precipitation_probability[k] || 0) >= 70) {
                        const mins = Math.max(5, Math.round((new Date(m.time[k]).getTime() - t) / 60000))
                        root.lastRainAlert = t
                        root.banner({ icon: "weather-showers", title: "Rain in about " + mins + " min", value: l.city, tint: "#60a5fa" })
                        return
                    }
                }
            } catch (e) {}
        }
        xhr.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + l.lat + "&longitude=" + l.lon
                 + "&minutely_15=precipitation,precipitation_probability&past_minutely_15=1&forecast_minutely_15=6&timezone=auto")
        xhr.send()
    }
    Timer { interval: 15 * 60000; running: true; repeat: true; onTriggered: root.checkRain() }
    Timer { interval: 20000; running: true; onTriggered: root.checkRain() }     // once soon after start

    // focus timer from the Frost Focus widget
    readonly property var focusState: sys.focus
    readonly property bool focusActive: !!focusState && focusState.phase !== "idle"
    readonly property int focusLeft: !focusState ? 0 : (focusState.phase === "focus" || focusState.phase === "break")
                                     ? Math.max(0, Math.round((focusState.endsAt - now.getTime()) / 1000)) : focusState.pausedLeft
    readonly property string focusText: Math.floor(focusLeft / 60) + ":" + String(focusLeft % 60).padStart(2, "0")
    readonly property bool focusBreak: !!focusState && focusState.phase.endsWith("break")

    // ---- notifications and Do Not Disturb ----------------------------------
    NotificationManager.Settings { id: notifSettings }
    readonly property bool dnd: notifSettings.notificationsInhibitedUntil !== undefined
                                && !isNaN(notifSettings.notificationsInhibitedUntil) && notifSettings.notificationsInhibitedUntil > now
    onDndChanged: if (ready) banner({ icon: dnd ? "notifications-disabled" : "notifications", title: "Do Not Disturb", value: dnd ? "On" : "Off", tint: dnd ? "#a78bfa" : "" })

    NotificationManager.Notifications {
        id: notes
        showExpired: true
        showDismissed: false
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        urgencies: NotificationManager.Notifications.LowUrgency | NotificationManager.Notifications.NormalUrgency | NotificationManager.Notifications.CriticalUrgency
    }
    property var seenIds: ({})
    Connections {
        target: notes
        function onRowsInserted(parent, first, last) {
            for (let i = first; i <= last; i++) {
                const ix = notes.index(i, 0)
                const id = notes.data(ix, NotificationManager.Notifications.IdRole)
                if (root.seenIds[id]) continue
                root.seenIds[id] = true
                if (notes.data(ix, NotificationManager.Notifications.TypeRole) !== NotificationManager.Notifications.NotificationType) continue
                const urgent = notes.data(ix, NotificationManager.Notifications.UrgencyRole) === NotificationManager.Notifications.CriticalUrgency
                if (root.dnd && !urgent) continue
                if (!root.ready) continue
                root.banner({
                    icon: notes.data(ix, NotificationManager.Notifications.ApplicationIconNameRole) || notes.data(ix, NotificationManager.Notifications.IconNameRole) || "dialog-information",
                    image: notes.data(ix, NotificationManager.Notifications.ImageRole) || "",
                    app: notes.data(ix, NotificationManager.Notifications.ApplicationNameRole) || "",
                    title: notes.data(ix, NotificationManager.Notifications.SummaryRole) || "",
                    body: (notes.data(ix, NotificationManager.Notifications.BodyRole) || "").replace(/<[^>]+>/g, ""),
                    notifId: id, tint: urgent ? root.accent : "", urgent: urgent
                })
                root.unseen++
            }
        }
    }
    function rowOf(model, id) {
        for (let i = 0; i < model.count; i++) {
            const ix = model.index(i, 0)
            if (model.data(ix, NotificationManager.Notifications.IdRole) === id) return ix
        }
        return null
    }
    function openNotification(id) { const ix = rowOf(notes, id); if (ix) notes.invokeDefaultAction(ix, NotificationManager.Notifications.Close) }
    // a banner that has been shown moves to the history, like a popup timing out
    function expireNotification(id) { const ix = rowOf(notes, id); if (ix) notes.expire(ix) }
    function clearHistory() { for (let i = notes.count - 1; i >= 0; i--) notes.close(notes.index(i, 0)); unseen = 0 }
    property int unseen: 0                 // red dot on the idle pill until you open the island

    // ---- file transfers (copy, move, download...): a live activity -------------
    NotificationManager.Notifications {
        id: jobsModel
        showNotifications: false
        showJobs: true
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
    }
    Instantiator {
        id: jobInst
        model: jobsModel
        delegate: QtObject {
            readonly property int row: index
            readonly property var jid: model.notificationId
            readonly property int js: model.jobState
            readonly property int pct: model.percentage || 0
            readonly property string title: model.summary || "Transfer"
            readonly property string app: model.applicationName || ""
            readonly property string icon: model.applicationIconName || "folder-download"
            readonly property bool suspendable: !!model.suspendable
            readonly property bool killable: !!model.killable
            // decide from js itself: other bindings on it may not have updated yet
            onJsChanged: { if (js === root.jobStopped) root.jobDone(this); Qt.callLater(root.updateJob) }
        }
        onObjectAdded: root.updateJob()
        onObjectRemoved: Qt.callLater(root.updateJob)
    }
    readonly property int jobStopped: NotificationManager.Notifications.JobStateStopped
    property var job: null                 // the newest unfinished transfer
    readonly property bool jobActive: !!job
    function updateJob() {
        for (let i = 0; i < jobInst.count; i++) { const o = jobInst.objectAt(i); if (o && o.js !== jobStopped) { job = o; return } }
        job = null
    }
    function jobIndex() { return job ? rowOf(jobsModel, job.jid) : null }
    function jobDone(o) {
        const ix = rowOf(jobsModel, o.jid)
        const err = ix ? jobsModel.data(ix, NotificationManager.Notifications.JobErrorRole) : 0
        if (ready) banner({ icon: o.icon, app: o.app, title: o.title, value: err ? "Failed" : "Done", tint: err ? accent : "#4ade80" })
        const id = o.jid
        Qt.callLater(() => { const j = rowOf(jobsModel, id); if (j) jobsModel.close(j) })
    }
    readonly property color jobTint: "#60a5fa"
    readonly property string jobPctText: job ? job.pct + "%" : ""
    property bool ready: false
    Timer { interval: 4000; running: true; onTriggered: root.ready = true }   // no banners for startup noise

    // ---- what the island shows ---------------------------------------------
    property var queue: []
    property var current: null            // the banner being shown
    function banner(b) { queue = queue.concat([b]); if (!current) nextBanner() }
    function nextBanner() {
        if (current && current.notifId) expireNotification(current.notifId)
        if (!queue.length) { current = null; return }
        current = queue[0]; queue = queue.slice(1)
        isOpen = false
        bannerTimer.interval = current.urgent ? 10000 : 4500
        bannerTimer.restart()
        if (!dnd || current.alarm) exec.connectSource(soundCmd)
    }
    // a soft pop for each banner (none during Do Not Disturb)
    readonly property string soundFile: Qt.resolvedUrl("../sounds/pop.wav").toString().replace("file://", "")
    readonly property string soundCmd: "(pw-play --volume=0.6 '" + soundFile + "' || paplay '" + soundFile + "') >/dev/null 2>&1 &"
    Timer { id: bannerTimer; interval: 4500; onTriggered: if (!popArea.hovered) root.nextBanner(); else restart() }

    property bool isOpen: false
    onIsOpenChanged: if (isOpen && primary === "idle") unseen = 0
    // most important first: the first goes in the pill, the second in a bubble
    readonly property var activities: [recording ? "rec" : "", musicActive ? "music" : "", timerActive ? "timer" : "",
                                       swActive ? "stopwatch" : "", jobActive ? "job" : "", dlActive ? "dl" : "",
                                       focusActive ? "focus" : ""].filter(a => a)
    readonly property string primary: activities.length ? activities[0] : "idle"
    readonly property string secondary: activities.length > 1 ? activities[1] : ""
    // ---- level bar for volume, brightness and other on-screen displays ---------
    property var hud: null                 // {icon, value (-1 = text only), max, text}
    function showHud(icon, value, maxValue, text) {
        hud = { icon: icon || "", value: value, max: maxValue > 0 ? maxValue : 100, text: text || "" }
        hudTimer.restart()
    }
    Timer { id: hudTimer; interval: 1600; onTriggered: root.hud = null }
    onHudChanged: if (hud) bannerTimer.stop(); else if (current) bannerTimer.restart()   // a banner waits its turn
    // Plasma's OSDs arrive through the bridge's OsdBus; the island still loads without it
    Component.onCompleted: {
        try {
            const c = Qt.createQmlObject('import QtQuick; import org.frost.osd; Connections { property var island; target: OsdBus; '
                                       + 'function onShown(icon, value, maxValue, text) { island.showHud(icon, value, maxValue, text) } }', root, "osdbridge")
            c.island = root
        } catch (e) { console.log("Dynamic Island: no OSD bridge, Plasma shows its own OSD") }
    }

    readonly property string mode: hud ? "hud" : current ? "banner" : isOpen ? "expanded" : "compact"

    // sizes per state
    readonly property size compactSize: primary === "music" ? Qt.size(232, pillH) : primary === "focus" ? Qt.size(196, pillH)
                                        : primary === "job" || primary === "dl" ? Qt.size(232, pillH)
                                        : primary === "rec" ? Qt.size(150, pillH)
                                        : primary === "timer" || primary === "stopwatch" ? Qt.size(176, pillH)
                                        : Qt.size(charging || micInUse || camInUse ? 150 : 118, pillH)
    readonly property size targetSize: mode === "hud" ? Qt.size(300, 40)
                                     : mode === "banner" ? Qt.size(current.body ? 420 : 340, current.body ? 84 : 64)
                                     : mode === "expanded" ? (primary === "music" ? Qt.size(440, 176) : primary === "focus" ? Qt.size(360, 150)
                                                            : primary === "job" || primary === "dl" ? Qt.size(400, 150)
                                                            : primary === "rec" ? Qt.size(340, 110)
                                                            : primary === "timer" || primary === "stopwatch" ? Qt.size(380, 150)
                                                            : Qt.size(420, 168 + histH))
                                     : compactSize

    readonly property int histRow: 40
    readonly property int histH: notes.count === 0 ? 18 : Math.min(5, notes.count) * histRow

    // ---- shared pieces ---------------------------------------------------------
    component Bars: Row {
        property int count: 6
        property real h: 14
        spacing: 2
        Repeater {
            model: parent.count
            Rectangle {
                anchors.bottom: parent.bottom
                width: 3; radius: 1.5
                height: Math.max(3, parent.h * Math.min(100, root.bars[index * 2] || 0) / 100)
                color: index % 2 ? root.accent : Qt.rgba(1, 1, 1, 0.9)
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
    component Art: Item {
        property int size: 22
        property int r: size / 2
        width: size; height: size
        Rectangle { id: m; anchors.fill: parent; radius: parent.r; visible: false; layer.enabled: true }
        Image { id: img; anchors.fill: parent; visible: false; source: root.player ? root.player.artUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 200); asynchronous: true }
        MultiEffect { anchors.fill: parent; source: img; maskEnabled: true; maskSource: m; visible: img.status === Image.Ready }
        Kirigami.Icon { anchors.fill: parent; visible: img.status !== Image.Ready; source: root.player ? (root.player.iconName || "media-default-album") : "media-default-album" }
    }
    component Ring: Item {
        property real progress: 0
        property color tint: root.accent
        width: 20; height: 20
        Canvas {
            anchors.fill: parent
            property real p: parent.progress
            onPChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset(); c.lineWidth = 2.5; c.lineCap = "round"
                c.strokeStyle = "rgba(255,255,255,0.15)"; c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 2, 0, 2 * Math.PI); c.stroke()
                c.strokeStyle = parent.tint; c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 2, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * p); c.stroke()
            }
        }
    }
    readonly property real focusProgress: !focusState ? 0 : 1 - focusLeft / Math.max(1, focusState.total || (focusBreak ? 300 : 1500))

    // compact contents (used in the panel and at the start of the morph)
    component CompactContent: Item {
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 12 }
            spacing: 8
            visible: root.primary === "music"
            Art { size: 22 }
            Item { Layout.fillWidth: true }
            Bars { count: 6; h: 14 }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
            spacing: 8
            visible: root.primary === "focus"
            Ring { progress: root.focusProgress; tint: root.focusBreak ? "#4ade80" : root.accent }
            Text { text: root.focusBreak ? "Break" : (root.focusState && root.focusState.project ? root.focusState.project : "Focus"); color: root.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: root.focusText; color: root.focusBreak ? "#4ade80" : root.accent; font.family: root.mono; font.pixelSize: 13 }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
            spacing: 8
            visible: root.primary === "job"
            Ring { progress: root.job ? root.job.pct / 100 : 0; tint: root.jobTint }
            Text { text: root.job ? root.job.title : ""; color: root.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: root.jobPctText; color: root.jobTint; font.family: root.mono; font.pixelSize: 13 }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
            spacing: 8
            visible: root.primary === "rec"
            Rectangle { width: 9; height: 9; radius: 4.5; color: root.accent
                        SequentialAnimation on opacity { running: root.primary === "rec"; loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 650 } NumberAnimation { to: 1; duration: 650 } } }
            Text { text: "REC"; color: root.muted; font.pixelSize: 11; font.letterSpacing: 1.5; Layout.fillWidth: true }
            Text { text: root.recText; color: root.accent; font.family: root.mono; font.pixelSize: 13 }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
            spacing: 8
            visible: root.primary === "timer"
            Ring { progress: root.timerProgress; tint: "#fbbf24" }
            Text { text: root.timerRunning ? "Timer" : "Paused"; color: root.muted; font.pixelSize: 12; Layout.fillWidth: true }
            Text { text: root.hms(root.timerLeftNow); color: "#fbbf24"; font.family: root.mono; font.pixelSize: 13 }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
            spacing: 8
            visible: root.primary === "stopwatch"
            Kirigami.Icon { source: "chronometer"; isMask: true; color: "#fbbf24"; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
            Text { text: root.cfg.swRunning ? "Stopwatch" : "Paused"; color: root.muted; font.pixelSize: 12; Layout.fillWidth: true }
            Text { text: root.hms(root.swMs / 1000); color: "#fbbf24"; font.family: root.mono; font.pixelSize: 13 }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
            spacing: 8
            visible: root.primary === "dl"
            Kirigami.Icon { source: "folder-download"; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
            Text { text: root.dl ? root.dl.name : ""; color: root.muted; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.fillWidth: true }
            Text { text: root.dl ? root.size(root.dl.bytes) : ""; color: root.jobTint; font.family: root.mono; font.pixelSize: 12 }
        }
        Row {   // privacy dots while another activity fills the pill
            anchors { right: parent.right; top: parent.top; rightMargin: 5; topMargin: 4 }
            spacing: 3
            visible: root.primary !== "idle"
            Rectangle { visible: root.camInUse; width: 5; height: 5; radius: 2.5; color: "#4ade80" }
            Rectangle { visible: root.micInUse; width: 5; height: 5; radius: 2.5; color: "#fb923c" }
        }
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            visible: root.primary === "idle"
            Kirigami.Icon { visible: root.charging; source: "battery-charging"; Layout.preferredWidth: 14; Layout.preferredHeight: 14; isMask: true; color: "#4ade80" }
            Text { text: Qt.formatTime(root.now, "h:mm"); color: root.text; font.family: root.mono; font.pixelSize: 13 }
            Rectangle { visible: root.camInUse; width: 7; height: 7; radius: 3.5; color: "#4ade80" }
            Rectangle { visible: root.micInUse; width: 7; height: 7; radius: 3.5; color: "#fb923c" }
            Rectangle { visible: root.unseen > 0; width: 7; height: 7; radius: 3.5; color: root.accent }
        }
    }

    // ---- the panel part: the resting pill ------------------------------------
    // The island lives alone in a small panel centred at the top of the screen
    // (windows go below it), so centring it in its own box centres it on screen.
    fullRepresentation: Item {
        id: bar
        Layout.minimumWidth: 288
        Layout.preferredWidth: 288
        Layout.preferredHeight: 40

        // the panel pads its applets; place the pill from the panel window's top
        // edge instead, so it lines up exactly with the floating island above it
        property real winY: 0
        function updateWinY() { winY = mapToItem(null, 0, 0).y }
        onHeightChanged: Qt.callLater(updateWinY)
        Component.onCompleted: Qt.callLater(updateWinY)
        readonly property real centreX: width / 2

        Rectangle {
            id: pill
            width: root.compactSize.width; height: root.pillH
            x: bar.centreX - width / 2 - (root.secondary ? 19 : 0)
            y: root.pillTop - bar.winY
            radius: height / 2
            color: "black"
            border.color: Qt.rgba(1, 1, 1, 0.10)
            opacity: pop.visible ? 0 : 1
            scale: pillMouse.containsMouse && !pop.visible ? 1.05 : 1
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on width { SpringAnimation { spring: 4; damping: 0.32 } }
            CompactContent { anchors.fill: parent }
            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.isOpen = true
            }
        }
        Rectangle {   // second activity bubble (a transfer or the focus timer while something else leads)
            visible: root.secondary !== ""
            width: root.pillH; height: root.pillH; radius: width / 2
            x: pill.x + pill.width + 6; y: pill.y
            color: "black"; border.color: Qt.rgba(1, 1, 1, 0.10)
            opacity: pop.visible ? 0 : 1
            Ring { anchors.centerIn: parent
                   visible: ["job", "focus", "timer"].includes(root.secondary)
                   progress: root.secondary === "job" ? (root.job ? root.job.pct / 100 : 0)
                           : root.secondary === "timer" ? root.timerProgress : root.focusProgress
                   tint: root.secondary === "job" ? root.jobTint : root.secondary === "timer" ? "#fbbf24"
                       : root.focusBreak ? "#4ade80" : root.accent }
            Art { anchors.centerIn: parent; size: 20; visible: root.secondary === "music" }
            Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 4.5; color: root.accent; visible: root.secondary === "rec" }
            Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; visible: ["stopwatch", "dl"].includes(root.secondary)
                            source: root.secondary === "dl" ? "folder-download" : "chronometer"
                            isMask: root.secondary === "stopwatch"; color: "#fbbf24" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isOpen = true }
        }
    }

    // ---- the floating part: banners and the expanded island ------------------
    readonly property rect scr: Plasmoid.containment && Plasmoid.containment.screenGeometry.width > 0
                                ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, Screen.width || 1920, Screen.height || 1080)
    // The floating window is only as big as the shape (plus room for the
    // spring's overshoot), so it never blocks clicks on the windows around it.
    // It grows at once and shrinks only after the shape has settled.
    readonly property int padX: 36
    readonly property int padY: 28
    property real popW: 0
    property real popH: 0
    function fitStage(grow) {
        const w = targetSize.width + 2 * padX, h = targetSize.height + padY
        popW = grow ? Math.max(popW, w) : w
        popH = grow ? Math.max(popH, h) : h
    }
    Timer { id: settle; interval: 900; onTriggered: if (root.wantPop) root.fitStage(false) }
    readonly property bool wantPop: mode !== "compact"

    PlasmaCore.Dialog {
        id: pop
        visible: false
        type: PlasmaCore.Dialog.Notification
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        location: PlasmaCore.Types.Floating
        x: root.scr.x + root.scr.width / 2 - root.popW / 2
        y: root.scr.y + root.pillTop

        mainItem: Item {
            id: stage
            width: root.popW; height: root.popH

            Rectangle {
                id: blob
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: root.compactSize.width; height: root.pillH
                radius: Math.min(height / 2, 30)
                color: "black"
                border.color: Qt.rgba(1, 1, 1, 0.10)
                clip: true
                Behavior on width { id: sw; SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }
                Behavior on height { id: sh; SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }

                HoverHandler { id: popArea }
                TapHandler {
                    onTapped: {
                        if (root.current && root.current.notifId) root.openNotification(root.current.notifId)
                        if (root.current && root.current.url) Qt.openUrlExternally(root.current.url)
                        if (root.current) { bannerTimer.stop(); root.nextBanner() }
                    }
                }

                CompactContent {
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                    width: root.compactSize.width; height: root.pillH
                    opacity: 1 - content.opacity
                    visible: opacity > 0
                }

                // contents fade in once the shape is mostly there
                Item {
                    id: content
                    anchors.fill: parent
                    opacity: Math.min(1, Math.max(0, (blob.height - root.pillH - 2) / Math.max(1, root.targetSize.height - root.pillH - 2)))

                    // level bar (volume, brightness...) or a short text (muted, layout...)
                    RowLayout {
                        visible: root.mode === "hud"
                        anchors { fill: parent; leftMargin: 14; rightMargin: 16 }
                        spacing: 12
                        readonly property bool level: !!root.hud && root.hud.value >= 0
                        Kirigami.Icon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; isMask: true; color: root.text
                                        source: root.hud ? root.hud.icon : "" }
                        Rectangle {
                            visible: parent.level
                            Layout.fillWidth: true; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.15)
                            readonly property real frac: root.hud && root.hud.value > 0 ? Math.min(1, root.hud.value / root.hud.max) : 0
                            Rectangle {
                                height: 6; radius: 3; width: parent.width * parent.frac
                                color: root.hud && root.hud.value > 100 ? root.accent : "white"     // red above 100% volume
                                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            }
                        }
                        Text { visible: !parent.level; text: root.hud ? root.hud.text : ""; color: root.text; font.pixelSize: 13
                               elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { visible: parent.level; text: root.hud ? root.hud.value + "%" : ""; color: root.text
                               font.family: root.mono; font.pixelSize: 13; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                    }

                    // banner
                    RowLayout {
                        visible: root.mode === "banner"
                        anchors { fill: parent; margins: 14; leftMargin: 16; rightMargin: 20 }
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 12
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Kirigami.Icon { anchors.centerIn: parent; width: 26; height: 26; source: root.current ? (root.current.image || root.current.icon) : "" }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { visible: !!(root.current && root.current.app); text: root.current ? (root.current.app || "") : ""; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1 }
                            Text { text: root.current ? root.current.title : ""; color: root.text; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { visible: !!(root.current && root.current.body); text: root.current ? (root.current.body || "") : ""; color: root.muted; font.pixelSize: 12; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        Text {
                            visible: !!(root.current && root.current.value)
                            text: root.current ? (root.current.value || "") : ""
                            color: root.current && root.current.tint ? root.current.tint : root.text
                            font.family: root.mono; font.pixelSize: 15
                        }
                    }

                    // expanded: music
                    ColumnLayout {
                        visible: root.mode === "expanded" && root.primary === "music"
                        anchors { fill: parent; margins: 18 }
                        spacing: 10
                        RowLayout {
                            spacing: 14
                            Art {
                                size: 64; r: 14
                                MouseArea { anchors.fill: parent; enabled: !!root.player && root.player.canRaise; cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.player.Raise(); root.isOpen = false } }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: root.player ? root.player.track : ""; color: root.text; font.pixelSize: 16; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: root.player ? root.player.artist : ""; color: root.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Bars { count: 8; h: 26 }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: root.clock(root.player ? root.player.position : 0); color: root.muted; font.family: root.mono; font.pixelSize: 10 }
                            Rectangle {
                                Layout.fillWidth: true; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                                Rectangle { height: 4; radius: 2; color: root.accent
                                            width: parent.width * (root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0) }
                                MouseArea { anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
                                            enabled: !!root.player && root.player.canSeek
                                            onClicked: (e) => root.player.position = e.x / width * root.player.length }
                            }
                            Text { text: root.clock(root.player ? root.player.length : 0); color: root.muted; font.family: root.mono; font.pixelSize: 10 }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter; spacing: 26
                            component Btn: Kirigami.Icon {
                                signal hit()
                                Layout.preferredWidth: 22; Layout.preferredHeight: 22; isMask: true
                                color: bm.containsMouse ? root.accent : root.text
                                MouseArea { id: bm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.hit() }
                            }
                            Btn { source: "media-skip-backward"; onHit: root.player.Previous() }
                            Btn { source: root.playing ? "media-playback-pause" : "media-playback-start"; onHit: root.player.PlayPause() }
                            Btn { source: "media-skip-forward"; onHit: root.player.Next() }
                        }
                    }

                    // expanded: focus
                    RowLayout {
                        visible: root.mode === "expanded" && root.primary === "focus"
                        anchors { fill: parent; margins: 22 }
                        spacing: 18
                        Ring { Layout.preferredWidth: 72; Layout.preferredHeight: 72; width: 72; height: 72; progress: root.focusProgress; tint: root.focusBreak ? "#4ade80" : root.accent }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: root.focusBreak ? "BREAK" : root.focusState && root.focusState.phase.startsWith("paused") ? "PAUSED" : "FOCUS"; color: root.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                            Text { text: root.focusText; color: root.text; font.family: root.mono; font.pixelSize: 36 }
                            Text { text: root.focusState && root.focusState.project ? root.focusState.project : "No project"; color: root.accent; font.pixelSize: 13 }
                        }
                    }

                    // expanded: transfer
                    RowLayout {
                        visible: root.mode === "expanded" && root.primary === "job"
                        anchors { fill: parent; margins: 22 }
                        spacing: 18
                        Item {
                            Layout.preferredWidth: 72; Layout.preferredHeight: 72
                            Ring { anchors.fill: parent; width: 72; height: 72; progress: root.job ? root.job.pct / 100 : 0; tint: root.jobTint }
                            Kirigami.Icon { anchors.centerIn: parent; width: 30; height: 30; source: root.job ? root.job.icon : "" }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: root.job && root.job.app ? root.job.app.toUpperCase() : "TRANSFER"; color: root.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                            Text { text: root.job ? root.job.title : ""; color: root.text; font.pixelSize: 15; elide: Text.ElideRight; Layout.fillWidth: true }
                            RowLayout {
                                spacing: 14
                                Text { text: root.jobPctText; color: root.jobTint; font.family: root.mono; font.pixelSize: 22 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    visible: !!root.job && root.job.suspendable
                                    text: root.job && root.job.js === NotificationManager.Notifications.JobStateSuspended ? "Resume" : "Pause"
                                    color: jp.containsMouse ? root.accent : root.text; font.pixelSize: 13
                                    MouseArea { id: jp; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { const ix = root.jobIndex(); if (!ix) return
                                                             root.job.js === NotificationManager.Notifications.JobStateSuspended ? jobsModel.resumeJob(ix) : jobsModel.suspendJob(ix) } }
                                }
                                Text {
                                    visible: !!root.job && root.job.killable
                                    text: "Cancel"; color: jk.containsMouse ? root.accent : root.muted; font.pixelSize: 13
                                    MouseArea { id: jk; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { const ix = root.jobIndex(); if (ix) jobsModel.killJob(ix) } }
                                }
                            }
                        }
                    }

                    component Act: Text {
                        signal hit()
                        color: am.containsMouse ? root.accent : root.text; font.pixelSize: 13
                        MouseArea { id: am; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.hit() }
                    }

                    // expanded: screen recording
                    RowLayout {
                        visible: root.mode === "expanded" && root.primary === "rec"
                        anchors { fill: parent; margins: 22 }
                        spacing: 16
                        Rectangle { width: 18; height: 18; radius: 9; color: root.accent
                                    SequentialAnimation on opacity { running: root.primary === "rec"; loops: Animation.Infinite
                                        NumberAnimation { to: 0.25; duration: 650 } NumberAnimation { to: 1; duration: 650 } } }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: "SCREEN RECORDING"; color: root.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                            Text { text: root.recText; color: root.text; font.family: root.mono; font.pixelSize: 30 }
                            Text { text: (root.sys.rec || []).join(", "); color: root.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }

                    // expanded: timer / stopwatch
                    RowLayout {
                        visible: root.mode === "expanded" && (root.primary === "timer" || root.primary === "stopwatch")
                        readonly property bool isTimer: root.primary === "timer"
                        anchors { fill: parent; margins: 22 }
                        spacing: 18
                        Item {
                            Layout.preferredWidth: 72; Layout.preferredHeight: 72
                            Ring { anchors.fill: parent; width: 72; height: 72; visible: parent.parent.isTimer; progress: root.timerProgress; tint: "#fbbf24" }
                            Kirigami.Icon { anchors.centerIn: parent; width: 34; height: 34; source: "chronometer"; isMask: true; color: "#fbbf24"; visible: !parent.parent.isTimer }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: parent.parent.isTimer ? (root.timerRunning ? "TIMER" : "TIMER · PAUSED") : (root.cfg.swRunning ? "STOPWATCH" : "STOPWATCH · PAUSED")
                                   color: root.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                            Text { text: parent.parent.isTimer ? root.hms(root.timerLeftNow) : root.hms(root.swMs / 1000)
                                   color: root.text; font.family: root.mono; font.pixelSize: 34 }
                            RowLayout {
                                spacing: 18
                                Act { visible: parent.parent.parent.isTimer; text: root.timerRunning ? "Pause" : "Resume"
                                      onHit: root.timerRunning ? root.pauseTimer() : root.resumeTimer() }
                                Act { visible: parent.parent.parent.isTimer; text: "+1 min"; onHit: root.addMinute() }
                                Act { visible: parent.parent.parent.isTimer; text: "Cancel"; color: root.muted; onHit: root.cancelTimer() }
                                Act { visible: !parent.parent.parent.isTimer; text: root.cfg.swRunning ? "Pause" : "Resume"
                                      onHit: root.cfg.swRunning ? root.pauseSw() : root.startSw() }
                                Act { visible: !parent.parent.parent.isTimer; text: "Reset"; color: root.muted; onHit: root.resetSw() }
                            }
                        }
                    }

                    // expanded: browser download
                    RowLayout {
                        visible: root.mode === "expanded" && root.primary === "dl"
                        anchors { fill: parent; margins: 22 }
                        spacing: 18
                        Kirigami.Icon { Layout.preferredWidth: 48; Layout.preferredHeight: 48; source: "folder-download" }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            Text { text: root.dl ? root.dl.from.toUpperCase() + " · DOWNLOADING" : ""; color: root.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                            Text { text: root.dl ? root.dl.name : ""; color: root.text; font.pixelSize: 15; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            Rectangle {   // the browser doesn't say the total size: a moving sheen instead of a percentage
                                id: dlTrack
                                Layout.fillWidth: true; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12); clip: true
                                Rectangle {
                                    id: sheen
                                    width: dlTrack.width * 0.3; height: 4; radius: 2; color: root.jobTint
                                    NumberAnimation on x { from: -sheen.width; to: dlTrack.width; duration: 1400; loops: Animation.Infinite; running: root.primary === "dl" }
                                }
                            }
                            Text { text: root.dl ? root.size(root.dl.bytes) + (root.dl.speed > 0 ? "  ·  " + root.size(root.dl.speed) + "/s" : "") : ""
                                   color: root.jobTint; font.family: root.mono; font.pixelSize: 13 }
                        }
                    }

                    // expanded: idle overview
                    ColumnLayout {
                        visible: root.mode === "expanded" && root.primary === "idle"
                        anchors { fill: parent; margins: 18 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 0
                                Text { text: Qt.formatDate(root.now, "dddd"); color: root.text; font.pixelSize: 18 }
                                Text { text: Qt.formatDate(root.now, "d MMMM"); color: root.accent; font.pixelSize: 12 }
                            }
                            Item { Layout.fillWidth: true }
                            ColumnLayout {
                                spacing: 1
                                Text { Layout.alignment: Qt.AlignRight; color: root.muted; font.family: root.mono; font.pixelSize: 11
                                       text: root.sys.battery ? (root.charging ? "⚡ " : "") + root.sys.battery.pct + "% " + root.sys.battery.status.toLowerCase() : "" }
                                Text { Layout.alignment: Qt.AlignRight; color: root.muted; font.pixelSize: 11; visible: text.length > 0
                                       text: (root.sys.bt || []).join(", ") }
                                Text { Layout.alignment: Qt.AlignRight; color: "#fb923c"; font.pixelSize: 11; visible: root.micInUse
                                       text: "Mic in use: " + (root.sys.mic || []).join(", ") }
                                Text { Layout.alignment: Qt.AlignRight; color: "#4ade80"; font.pixelSize: 11; visible: root.camInUse
                                       text: "Camera in use: " + (root.sys.cam || []).join(", ") }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                        RowLayout {   // start a timer or the stopwatch
                            Layout.fillWidth: true; spacing: 6
                            component Chip: Rectangle {
                                id: chip
                                property string label
                                signal hit()
                                signal wheel(int d)
                                implicitWidth: ct.implicitWidth + 18; implicitHeight: 26; radius: 13
                                color: cm2.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                Text { id: ct; anchors.centerIn: parent; text: chip.label; color: root.text; font.pixelSize: 12 }
                                MouseArea { id: cm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: chip.hit(); onWheel: (w) => chip.wheel(w.angleDelta.y) }
                            }
                            Kirigami.Icon { source: "chronometer"; isMask: true; color: "#fbbf24"; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                            Chip { label: "1m"; onHit: root.startTimer(1) }
                            Chip { label: "5m"; onHit: root.startTimer(5) }
                            Chip { label: "10m"; onHit: root.startTimer(10) }
                            Chip { label: "25m"; onHit: root.startTimer(25) }
                            Chip {   // scroll to change, click to start
                                label: root.cfg.customMinutes + "m ↕"
                                onHit: root.startTimer(root.cfg.customMinutes)
                                onWheel: (d) => root.cfg.customMinutes = Math.max(1, Math.min(180, root.cfg.customMinutes + (d > 0 ? 1 : -1)))
                            }
                            Item { Layout.fillWidth: true }
                            Chip { label: "Stopwatch"; onHit: root.startSw() }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: root.dnd ? "NOTIFICATIONS · DO NOT DISTURB" : "NOTIFICATIONS"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.5; Layout.fillWidth: true }
                            Text { visible: notes.count > 0; text: "Clear all"; color: cl.containsMouse ? root.accent : root.muted; font.pixelSize: 11
                                   MouseArea { id: cl; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                               onClicked: root.clearHistory() } }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: notes.count === 0 ? 0 : root.histH
                            visible: notes.count > 0
                            clip: true
                            model: notes
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Item {
                                id: row
                                required property int index
                                required property var model
                                width: ListView.view.width; height: root.histRow
                                Rectangle { anchors { fill: parent; topMargin: 1; bottomMargin: 1 } radius: 10; color: rm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent" }
                                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: notes.invokeDefaultAction(notes.index(row.index, 0), NotificationManager.Notifications.Close) }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 8 }
                                    spacing: 10
                                    Kirigami.Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; source: row.model.applicationIconName || "dialog-information" }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; color: root.text; font.pixelSize: 12
                                               text: (row.model.applicationName ? row.model.applicationName + "  ·  " : "") + (row.model.summary || "") }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; color: root.muted; font.pixelSize: 11; visible: text.length > 0
                                               text: (row.model.body || "").replace(/<[^>]+>/g, "").replace(/\s+/g, " ") }
                                    }
                                    Kirigami.Icon {   // dismiss
                                        Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                        source: "window-close-symbolic"; isMask: true
                                        color: xm.containsMouse ? root.accent : root.muted
                                        opacity: rm.containsMouse || xm.containsMouse ? 1 : 0
                                        MouseArea { id: xm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: notes.close(notes.index(row.index, 0)) }
                                    }
                                }
                            }
                        }
                        Text { visible: notes.count === 0; text: "Nothing new"; color: root.muted; font.pixelSize: 12 }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    // morph: open the floating island at the pill's size, then grow it;
    // shrink back to the pill before hiding it
    onTargetSizeChanged: morph()
    onWantPopChanged: morph()
    function morph() {
        if (wantPop) {
            if (!pop.visible) {
                sw.enabled = false; sh.enabled = false
                blob.width = compactSize.width; blob.height = pillH
                sw.enabled = true; sh.enabled = true
                popW = 0; popH = 0
                fitStage(true)
                pop.visible = true
            } else fitStage(true)
            blob.width = targetSize.width; blob.height = targetSize.height
            settle.restart()
            collapseCheck.restart()
        } else if (pop.visible) {
            blob.width = compactSize.width; blob.height = pillH
            hideTimer.restart()
        }
    }
    Timer { id: hideTimer; interval: 450; onTriggered: if (!root.wantPop) pop.visible = false }
    // the expanded island closes when the pointer is no longer over it
    Timer {
        id: collapseCheck; interval: 1500; repeat: true
        running: root.isOpen
        onTriggered: if (!popArea.hovered) root.isOpen = false
    }
}
