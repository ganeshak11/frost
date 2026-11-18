// Calendar & Agenda: Monday-first month grid (today in red, dots on days with
// events, holidays in red text) and an agenda below that grows with what's
// coming up. Click a day to see its events; "+" adds an event to the selected
// day ("09:30 Gym" or just "Gym"); right-click one of your events to delete it.
// Calendar feeds (Google "secret iCal address", holiday calendars) are set in
// the widget settings and refreshed every 30 minutes.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property date today: new Date()
    property date shown: new Date(today.getFullYear(), today.getMonth(), 1)
    property date selected: today
    property var feedEvents: []          // [{date:"2026-11-18", time:"09:30", title, holiday}]
    readonly property var localEvents: { try { return JSON.parse(Plasmoid.configuration.events) } catch (e) { return [] } }
    readonly property var allEvents: localEvents.map(e => Object.assign({ local: true }, e)).concat(feedEvents)

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd") }
    function eventsOn(k) { return allEvents.filter(e => e.date === k).sort((a, b) => (a.time || "").localeCompare(b.time || "")) }
    readonly property var upcoming: {
        const t = key(today)
        return allEvents.filter(e => e.date >= t && !e.holiday).sort((a, b) => (a.date + (a.time || "")).localeCompare(b.date + (b.time || ""))).slice(0, 4)
    }
    readonly property var agenda: key(selected) === key(today) ? upcoming : eventsOn(key(selected))

    function addEvent(text) {
        const m = text.trim().match(/^(\d{1,2}[:.]\d{2}\s*(?:am|pm)?)?\s*(.+)$/i)
        if (!m || !m[2]) return
        let time = ""
        if (m[1]) {
            let [h, mi] = m[1].replace(".", ":").replace(/\s*(am|pm)/i, "").split(":").map(Number)
            if (/pm/i.test(m[1]) && h < 12) h += 12
            if (/am/i.test(m[1]) && h === 12) h = 0
            time = String(h).padStart(2, "0") + ":" + String(mi).padStart(2, "0")
        }
        Plasmoid.configuration.events = JSON.stringify(localEvents.concat([{ date: key(selected), time: time, title: m[2] }]))
    }
    function removeEvent(ev) {
        Plasmoid.configuration.events = JSON.stringify(localEvents.filter(e => !(e.date === ev.date && e.time === ev.time && e.title === ev.title)))
    }
    function fmtTime(t) {
        if (!t) return "All day"
        const [h, m] = t.split(":").map(Number)
        return (h % 12 || 12) + ":" + String(m).padStart(2, "0") + (h < 12 ? " AM" : " PM")
    }

    // ---- iCal feeds -------------------------------------------------------
    function parseIcs(text, holiday) {
        const lines = text.replace(/\r\n[ \t]/g, "").split(/\r?\n/)
        const out = [], lo = new Date(), hi = new Date()
        lo.setMonth(lo.getMonth() - 2); hi.setMonth(hi.getMonth() + 12)
        let ev = null
        for (const l of lines) {
            if (l === "BEGIN:VEVENT") ev = {}
            else if (l === "END:VEVENT" && ev) {
                if (ev.start && ev.start >= lo && ev.start <= hi)
                    out.push({ date: key(ev.start), time: ev.allDay ? "" : Qt.formatTime(ev.start, "HH:mm"), title: ev.title || "(no title)", holiday: holiday })
                ev = null
            } else if (ev && l.startsWith("SUMMARY")) ev.title = l.slice(l.indexOf(":") + 1).replace(/\\,/g, ",")
            else if (ev && l.startsWith("DTSTART")) {
                const v = l.slice(l.indexOf(":") + 1)
                const y = +v.slice(0, 4), mo = +v.slice(4, 6) - 1, d = +v.slice(6, 8)
                if (v.length === 8) { ev.start = new Date(y, mo, d); ev.allDay = true }
                else {
                    const H = +v.slice(9, 11), M = +v.slice(11, 13)
                    ev.start = v.endsWith("Z") ? new Date(Date.UTC(y, mo, d, H, M)) : new Date(y, mo, d, H, M)
                }
            }
        }
        return out
    }
    function syncFeeds() {
        const urls = Plasmoid.configuration.feeds.split(/\s+/).filter(u => /^https?:\/\//.test(u))
        let pending = urls.length, collected = []
        if (!pending) { feedEvents = []; return }
        for (const u of urls) {
            const xhr = new XMLHttpRequest()
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) collected = collected.concat(parseIcs(xhr.responseText, /holiday/i.test(decodeURIComponent(u))))
                if (--pending === 0) root.feedEvents = collected
            }
            xhr.open("GET", u); xhr.send()
        }
    }
    Timer { interval: 30 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.syncFeeds() }
    Connections { target: Plasmoid.configuration; function onFeedsChanged() { root.syncFeeds() } }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { const n = new Date(); if (n.getDate() !== root.today.getDate()) root.today = n } }

    fullRepresentation: GlassCard {
        Layout.minimumWidth: 360; Layout.preferredWidth: 400
        Layout.minimumHeight: 300; Layout.preferredHeight: 352
        Style { id: st }

        ColumnLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text { text: Qt.formatDate(root.shown, "MMMM yyyy"); color: st.text; font.pixelSize: 17 }
                Item { Layout.fillWidth: true }
                component Nav: Kirigami.Icon {
                    signal hit()
                    Layout.preferredWidth: 16; Layout.preferredHeight: 16; isMask: true
                    color: na.containsMouse ? st.accent : st.muted
                    MouseArea { id: na; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.hit() }
                }
                Nav { source: "go-previous"; onHit: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() - 1, 1) }
                Text {
                    text: "Today"; color: tm.containsMouse ? st.accent : st.muted; font.pixelSize: 12
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.shown = new Date(root.today.getFullYear(), root.today.getMonth(), 1); root.selected = root.today } }
                }
                Nav { source: "go-next"; onHit: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 1) }
            }

            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: 7; rowSpacing: 0; columnSpacing: 0
                Repeater {
                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    Text { text: modelData; color: st.muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                }
                Repeater {
                    model: 42
                    Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 26
                        readonly property int lead: (root.shown.getDay() + 6) % 7
                        readonly property date day: new Date(root.shown.getFullYear(), root.shown.getMonth(), index - lead + 1)
                        readonly property string k: root.key(day)
                        readonly property bool inMonth: day.getMonth() === root.shown.getMonth()
                        readonly property bool isToday: k === root.key(root.today)
                        readonly property bool isSel: k === root.key(root.selected)
                        readonly property var evs: root.eventsOn(k)
                        readonly property bool holiday: evs.some(e => e.holiday)
                        visible: index < 35 || lead + new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate() > 35
                        Rectangle {
                            anchors.centerIn: parent; width: 24; height: 24; radius: 12
                            color: parent.isToday ? st.accent : "transparent"
                            border.color: parent.isSel && !parent.isToday ? Qt.rgba(1, 1, 1, 0.35) : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: parent.isToday ? "white" : parent.holiday ? st.accent : st.text
                            opacity: parent.inMonth ? 1 : 0.3
                            font.family: st.mono; font.pixelSize: 12
                        }
                        Rectangle {   // event dot
                            visible: parent.evs.some(e => !e.holiday) && !parent.isToday
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                            width: 4; height: 4; radius: 2; color: st.accent
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = parent.day }
                        QQC2.ToolTip.visible: hov.hovered && evs.length > 0
                        QQC2.ToolTip.text: evs.map(e => e.title).join("\n")
                        HoverHandler { id: hov }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: st.faint }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.key(root.selected) === root.key(root.today) ? "UPCOMING" : Qt.formatDate(root.selected, "dddd d MMMM").toUpperCase()
                    color: st.muted; font.pixelSize: 11; font.letterSpacing: 2
                }
                Item { Layout.fillWidth: true }
                Kirigami.Icon {
                    source: adding.visible ? "dialog-cancel" : "list-add"; isMask: true; color: ad.containsMouse ? st.accent : st.muted
                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                    MouseArea { id: ad; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { adding.visible = !adding.visible; if (adding.visible) adding.forceActiveFocus() } }
                }
            }
            QQC2.TextField {
                id: adding
                visible: false
                Layout.fillWidth: true
                placeholderText: "09:30 Gym, on " + Qt.formatDate(root.selected, "d MMM") + " — Enter to add"
                onAccepted: { root.addEvent(text); text = ""; visible = false }
                Keys.onEscapePressed: { text = ""; visible = false }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    visible: root.agenda.length === 0
                    text: "Nothing planned"
                    color: st.muted; font.pixelSize: 13
                }
                Repeater {
                    model: root.agenda
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.preferredWidth: 92
                            text: (root.key(root.selected) === root.key(root.today) && modelData.date !== root.key(root.today)
                                   ? Qt.formatDate(new Date(modelData.date + "T00:00"), "d MMM") + " " : "") + root.fmtTime(modelData.time)
                            color: modelData.holiday ? st.accent : st.muted; font.family: st.mono; font.pixelSize: 11
                        }
                        Text { text: modelData.title; color: st.text; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            enabled: modelData.local === true
                            onTapped: root.removeEvent(modelData)
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
