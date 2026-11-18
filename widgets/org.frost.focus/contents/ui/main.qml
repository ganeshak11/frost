// Focus: a Pomodoro timer. Click the project name to pick, add or remove
// your own projects (stored on this widget), start, and it counts focus time
// per project per day. After each focus block it
// reminds you to take a break (a long one every 4th). Optional Do Not Disturb
// while focusing. The timer keeps running across Plasma restarts.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property var cfg: Plasmoid.configuration
    readonly property var projects: cfg.projects.split(",").map(s => s.trim()).filter(s => s)
    readonly property string projectName: cfg.project || "No project"
    function addProject(name) {
        name = name.replace(/,/g, " ").trim()
        if (!name || projects.includes(name)) return
        cfg.projects = projects.concat([name]).join(", ")
        cfg.project = name
    }
    function removeProject(name) {
        cfg.projects = projects.filter(p => p !== name).join(", ")
        if (cfg.project === name) cfg.project = projects.filter(p => p !== name)[0] || ""
    }
    readonly property string phase: cfg.phase                    // idle | focus | break | paused-focus | paused-break
    readonly property bool running: phase === "focus" || phase === "break"
    readonly property bool isFocus: phase.endsWith("focus")
    property int remaining: 0                                          // seconds remaining
    readonly property int total: (isFocus ? cfg.focusMinutes : currentBreak) * 60
    readonly property int currentBreak: cfg.streak > 0 && cfg.streak % 4 === 0 ? cfg.longBreakMinutes : cfg.breakMinutes

    function todayKey() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
    function stats() { try { return JSON.parse(cfg.stats) } catch (e) { return {} } }
    readonly property var todayStats: { cfg.stats; return stats()[todayKey()] || { sessions: 0, projects: {} } }
    readonly property int todaySeconds: Object.values(todayStats.projects).reduce((a, b) => a + b, 0)

    function addFocus(seconds, completed) {
        if (seconds < 60 && !completed) return
        const s = stats(), k = todayKey()
        s[k] = s[k] || { sessions: 0, projects: {} }
        s[k].projects[projectName] = (s[k].projects[projectName] || 0) + seconds
        if (completed) s[k].sessions++
        // keep 60 days
        Object.keys(s).sort().slice(0, -60).forEach(d => delete s[d])
        cfg.stats = JSON.stringify(s)
    }
    function hm(sec) { const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60); return (h ? h + "h " : "") + m + "m" }

    NotificationManager.Settings { id: notif }
    property bool weSilenced: false
    function silence(on) {
        if (on && cfg.dndDuringFocus) { notif.notificationsInhibitedUntil = new Date(Number(cfg.endsAt)); notif.save(); weSilenced = true }
        else if (!on && weSilenced) { notif.notificationsInhibitedUntil = undefined; notif.save(); weSilenced = false }
    }
    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }
    function notify(title, body) {
        const q = (x) => "'" + String(x).replace(/'/g, "'\\''") + "'"   // shell-safe quoting
        exec.connectSource("notify-send -a Focus -i chronometer " + q(title) + " " + q(body))
    }

    function start(ph, seconds) {
        cfg.endsAt = String(Date.now() + seconds * 1000)
        cfg.phase = ph
        tick()
        if (ph === "focus") silence(true)
    }
    function toggle() {
        if (phase === "idle") start("focus", cfg.focusMinutes * 60)
        else if (running) { cfg.pausedLeft = remaining; cfg.phase = "paused-" + phase; silence(false) }
        else start(phase.replace("paused-", ""), cfg.pausedLeft)
    }
    function reset() {
        if (isFocus && phase !== "idle") addFocus(total - remaining, false)
        silence(false)
        cfg.phase = "idle"; remaining = cfg.focusMinutes * 60
    }
    function tick() {
        if (!running) { remaining = phase === "idle" ? cfg.focusMinutes * 60 : cfg.pausedLeft; return }
        remaining = Math.max(0, Math.round((Number(cfg.endsAt) - Date.now()) / 1000))
        if (remaining > 0) return
        if (phase === "focus") {
            addFocus(cfg.focusMinutes * 60, true)
            cfg.streak = cfg.streak + 1
            silence(false)
            notify("Focus session done", projectName + ": time for a " + currentBreak + "-minute break.")
            start("break", currentBreak * 60)
        } else {
            notify("Break over", "Ready for the next focus session?")
            cfg.phase = "idle"; remaining = cfg.focusMinutes * 60
        }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }

    fullRepresentation: GlassCard {
        id: card
        // narrow card: ring on top, controls underneath, per-project bars hidden
        readonly property bool compact: width < 380
        Layout.minimumWidth: 256; Layout.preferredWidth: 272
        Layout.minimumHeight: 224; Layout.preferredHeight: 240
        Style { id: st }

        GridLayout {
            anchors { fill: parent; margins: st.pad }
            columns: card.compact ? 1 : 2
            columnSpacing: 16; rowSpacing: 6

            Item {
                Layout.preferredWidth: card.compact ? 104 : 132; Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignCenter
                Canvas {
                    id: ring
                    anchors.fill: parent
                    Connections { target: st; function onLightChanged() { ring.requestPaint() } }
                    property real progress: root.total > 0 ? 1 - root.remaining / root.total : 0
                    onProgressChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        const r = width / 2 - 5, cx = width / 2, cy = height / 2
                        c.lineWidth = 5; c.lineCap = "round"
                        c.strokeStyle = st.light ? "rgba(0,0,0,0.08)" : "rgba(255,255,255,0.08)"
                        c.beginPath(); c.arc(cx, cy, r, 0, 2 * Math.PI); c.stroke()
                        if (progress > 0) {
                            c.strokeStyle = root.isFocus ? "#F21D43" : st.light ? "rgba(29,29,34,0.85)" : "rgba(242,242,245,0.85)"
                            c.beginPath(); c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + progress * 2 * Math.PI); c.stroke()
                        }
                    }
                    Connections { target: root; function onPhaseChanged() { ring.requestPaint() } }
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.phase === "idle" ? "FOCUS" : root.isFocus ? (root.running ? "FOCUS" : "PAUSED") : (root.running ? "BREAK" : "PAUSED")
                        color: root.isFocus && root.running ? st.accent : st.muted; font.pixelSize: 10; font.letterSpacing: 2
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.floor(root.remaining / 60) + ":" + String(root.remaining % 60).padStart(2, "0")
                        color: st.text; font.family: st.mono; font.pixelSize: card.compact ? 24 : 28
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { visible: !card.compact; text: "PROJECT"; color: st.muted; font.pixelSize: 10; font.letterSpacing: 2 }
                Text {
                    text: root.projectName + "  ›"
                    color: pm.containsMouse ? st.accent : (root.cfg.project ? st.text : st.muted); font.pixelSize: card.compact ? 15 : 18
                    horizontalAlignment: card.compact ? Text.AlignHCenter : Text.AlignLeft
                    elide: Text.ElideRight; Layout.fillWidth: true
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { editor.visible = true; newProject.forceActiveFocus() } }
                }
                RowLayout {
                    spacing: 8
                    Layout.alignment: card.compact ? Qt.AlignHCenter : Qt.AlignLeft
                    component Btn: Rectangle {
                        id: b
                        property string label
                        property bool primary: false
                        signal hit()
                        implicitWidth: t.implicitWidth + 24; implicitHeight: 28; radius: 14
                        color: primary ? (bm.containsMouse ? "#ff3358" : st.accent) : (bm.containsMouse ? st.hover : st.faint)
                        border.color: primary ? "transparent" : st.border
                        scale: bm.pressed ? 0.97 : 1
                        Text { id: t; anchors.centerIn: parent; text: b.label; color: b.primary ? st.textOnAccent : st.text; font.pixelSize: 13 }
                        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.hit() }
                    }
                    Btn { label: root.phase === "idle" ? "Start" : root.running ? "Pause" : "Resume"; primary: true; onHit: root.toggle() }
                    Btn { label: "Reset"; visible: root.phase !== "idle"; onHit: root.reset() }
                }
                Rectangle { visible: !card.compact; Layout.fillWidth: true; height: 1; color: st.faint; Layout.topMargin: 2 }
                Text {
                    text: "Today " + root.hm(root.todaySeconds) + "  ·  " + root.todayStats.sessions + " sessions"
                    Layout.alignment: card.compact ? Qt.AlignHCenter : Qt.AlignLeft
                    color: st.text; font.family: st.mono; font.pixelSize: 11
                }
                Repeater {   // top 3 projects today
                    // (wide card only)
                    model: card.compact ? [] : Object.entries(root.todayStats.projects).sort((a, b) => b[1] - a[1]).slice(0, 3)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: modelData[0]; color: st.muted; font.pixelSize: 11; Layout.preferredWidth: 80; elide: Text.ElideRight }
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 1.5; color: st.faint
                            Rectangle { height: 3; radius: 1.5; color: st.accent; width: parent.width * modelData[1] / Math.max(1, root.todaySeconds) }
                        }
                        Text { text: root.hm(modelData[1]); color: st.muted; font.family: st.mono; font.pixelSize: 10 }
                    }
                }
                Item { Layout.fillHeight: true; visible: !card.compact }
            }
        }

        // project picker / editor, opened by clicking the project name
        Rectangle {
            id: editor
            visible: false
            anchors.fill: parent
            radius: st.radius
            color: Qt.rgba(14/255, 14/255, 18/255, 0.96)
            border.color: st.border
            MouseArea { anchors.fill: parent }   // swallow clicks
            ColumnLayout {
                anchors { fill: parent; margins: st.pad }
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "YOUR PROJECTS"; color: st.muted; font.pixelSize: 10; font.letterSpacing: 2; Layout.fillWidth: true }
                    Text {
                        text: "Done"; color: dm.containsMouse ? st.accent : st.text; font.pixelSize: 12
                        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: editor.visible = false }
                    }
                }
                Flickable {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; contentHeight: plist.implicitHeight
                    Flow {
                        id: plist
                        width: parent.width; spacing: 6
                        Repeater {
                            model: root.projects
                            Rectangle {
                                readonly property bool sel: root.cfg.project === modelData
                                implicitWidth: prow.implicitWidth + 20; implicitHeight: 26; radius: 13
                                color: sel ? st.accent : st.faint
                                border.color: sel ? "transparent" : st.border
                                RowLayout {
                                    id: prow; anchors.centerIn: parent; spacing: 6
                                    Text {
                                        text: modelData; color: sel ? st.textOnAccent : st.text; font.pixelSize: 12
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    enabled: root.phase === "idle"
                                                    onClicked: { root.cfg.project = modelData; editor.visible = false } }
                                    }
                                    Text {
                                        text: "×"; color: xm.containsMouse ? (sel ? st.textOnAccent : st.text) : (sel ? Qt.rgba(1, 1, 1, 0.7) : st.muted); font.pixelSize: 14
                                        MouseArea { id: xm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.removeProject(modelData) }
                                    }
                                }
                            }
                        }
                        Text { visible: root.projects.length === 0; text: "No projects yet. Add one below."; color: st.muted; font.pixelSize: 12 }
                    }
                }
                QQC2.TextField {
                    id: newProject
                    Layout.fillWidth: true
                    placeholderText: "New project name, then Enter"
                    onAccepted: { root.addProject(text); text = "" }
                    Keys.onEscapePressed: editor.visible = false
                }
                Text {
                    visible: root.phase !== "idle"
                    text: "You can switch project when the timer isn't running."
                    color: st.muted; font.pixelSize: 10
                }
            }
        }
    }
}
