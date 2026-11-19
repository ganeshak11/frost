// Live sound and brightness levels for the Control Centre and Quick Controls.
// Asks levels.py (contents/code, started on demand, 127.0.0.1 only), which
// answers the moment something changes: volume keys, the earbuds' own buttons,
// another app, a Bluetooth device coming or going. Changes made here go
// straight to wpctl / pactl / KDE's brightness service.
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: lv
    property bool active: true

    property real vol: 0;   property bool volMuted: false
    property real mic: 0;   property bool micMuted: false
    property real light: 0; property int lightMax: 1
    property string output: ""           // name of the default output / input
    property string input: ""
    property var sinks: []               // [{name, desc, bt, icon, default, vol, muted}]
    property var sources: []
    property var apps: []                // [{index, name, icon, vol, muted, playing}]
    property bool ok: false              // the helper is answering

    // While a slider is held, and for a moment after a change from here, incoming
    // levels must not snap it back. Cleared on release and on cancel (the desktop
    // takes the mouse on press-and-hold to move the widget).
    property bool dragging: false
    property double lastSet: 0
    readonly property bool holding: dragging || Date.now() - lastSet < 1200

    readonly property string bd: "qdbus6 org.kde.ScreenBrightness /org/kde/ScreenBrightness/display0 org.kde.ScreenBrightness.Display."
    readonly property string helper: "setsid python3 '" + Qt.resolvedUrl("../code/levels.py").toString().replace("file://", "") + "' >/dev/null 2>&1 &"

    function setLevel(kind, v) {
        v = Math.max(0, Math.min(1, v))
        lastSet = Date.now(); settle.restart()
        if (kind === "vol") { vol = v; run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2)) }
        else if (kind === "mic") { mic = v; run("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + v.toFixed(2)) }
        else { light = v; run(bd + "SetBrightness " + Math.max(1, Math.round(v * lightMax)) + " 1") }   // flags 1: no on-screen indicator
    }
    function toggleMute(kind) {
        lastSet = Date.now(); settle.restart()
        if (kind === "vol") { volMuted = !volMuted; run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") }
        else if (kind === "mic") { micMuted = !micMuted; run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") }
    }
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function setDefault(isOutput, name) { run((isOutput ? "pactl set-default-sink " : "pactl set-default-source ") + q(name)) }
    function setApp(index, v) { run("pactl set-sink-input-volume " + index + " " + Math.round(Math.max(0, Math.min(1, v)) * 100) + "%") }
    function toggleApp(index) { run("pactl set-sink-input-mute " + index + " toggle") }

    // ---- talking to the helper: one request always waiting for the next change
    property int ver: -1
    property var last: null
    property double lastStart: 0
    function apply(s, force) {
        last = s
        sinks = s.sinks || []; sources = s.sources || []; apps = s.apps || []
        output = s.output || ""; input = s.input || ""
        if (holding && !force) return
        vol = Math.min(1, s.vol); volMuted = s.volMuted
        mic = Math.min(1, s.mic); micMuted = s.micMuted
        if (s.light >= 0) { light = s.light; lightMax = s.lightMax }
    }
    function poll() {
        if (!active) return
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let s = null
            if (xhr.status === 200) { try { s = JSON.parse(xhr.responseText) } catch (e) {} }
            if (s) { lv.ok = true; lv.ver = s.ver; lv.apply(s); Qt.callLater(lv.poll) }
            else {
                lv.ok = false; lv.ver = -1
                if (Date.now() - lv.lastStart > 5000) { lv.lastStart = Date.now(); lv.run(lv.helper) }
                retry.restart()
            }
        }
        xhr.open("GET", "http://127.0.0.1:47822/state?since=" + ver)
        xhr.send()
    }
    onActiveChanged: if (active) { ver = -1; poll() }
    Component.onCompleted: poll()
    Timer { id: retry; interval: 1500; onTriggered: lv.poll() }
    // after letting go, show what the system really has (in case it changed meanwhile)
    Timer { id: settle; interval: 1300; onTriggered: if (lv.last && !lv.dragging) lv.apply(lv.last, true) }

    function run(c) { exec.connectSource(c) }
    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }
}
