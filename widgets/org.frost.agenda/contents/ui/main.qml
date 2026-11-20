// Calendar & Agenda: Monday-first month grid (today in red, coloured dots on
// days with events, holidays in red text) and an agenda below that grows with
// what's coming up. Click a day to see its events; "+" adds an event to the
// selected day ("09:30 Gym", "Gym", or "05/03/2004 Mom's birthday" for another
// date), once or repeating weekly / monthly / yearly, tagged birthday /
// anniversary / important (each has its own colour). Right-click one of your
// events to delete it (a repeating one goes with all its dates).
// Calendar feeds (Google "secret iCal address", holidays, fixtures) are set in
// the widget settings, one per line: "<link> [#colour] [Name] [+Word ...]";
// +Words keep only events whose title contains one of them. Refreshed every
// 30 minutes; the last good copy of each feed is saved, so feeds still show
// offline, and a failed download is retried every minute. Reminders go out as notifications (shown by the Dynamic Island):
// 10 minutes before and at the start of timed events, at 9:00 for all-day ones.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property date today: new Date()
    property date shown: new Date(today.getFullYear(), today.getMonth(), 1)
    property date selected: today
    // your own events: {id, date, time, title, repeat: ""|weekly|monthly|yearly, kind: ""|birthday|anniversary|important}
    readonly property var localEvents: { try { return JSON.parse(Plasmoid.configuration.events) } catch (e) { return [] } }

    Style { id: rs }                     // the card's colours, for untagged events
    readonly property var kinds: [
        { kind: "", label: "No tag", color: "#cfcfd6" },
        { kind: "birthday", label: "Birthday", color: "#f472b6" },
        { kind: "anniversary", label: "Anniversary", color: "#a78bfa" },
        { kind: "important", label: "Important", color: "#F21D43" }
    ]
    function kindColor(k) { const m = kinds.find(x => x.kind === (k || "")); return m ? m.color : kinds[0].color }
    function colorOf(e) { return e.holiday ? "#F21D43" : e.color || kindColor(e.kind) }

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd") }
    function dayOf(k) { return new Date(k + "T00:00") }

    // does a (possibly repeating) local event fall on day d?
    function occursOn(e, d) {
        const k = key(d)
        if (!e.repeat) return e.date === k
        if (k < e.date) return false
        const s = dayOf(e.date)
        if (e.repeat === "weekly") return d.getDay() === s.getDay()
        const last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        const day = Math.min(s.getDate(), last)            // 31st -> last day; 29 Feb -> 28 Feb
        if (e.repeat === "monthly") return d.getDate() === day
        if (e.repeat === "yearly") return d.getMonth() === s.getMonth() && d.getDate() === day
        return false
    }
    // one dated copy of a local event; yearly ones know how many years it's been
    function occurrence(e, d) {
        const years = e.repeat === "yearly" ? d.getFullYear() - dayOf(e.date).getFullYear() : 0
        return Object.assign({ local: true, source: "Calendar", years: years }, e, { date: key(d), origDate: e.date })
    }
    function eventsOn(k) {
        const d = dayOf(k)
        return localEvents.filter(e => occursOn(e, d)).map(e => occurrence(e, d))
            .concat(feedEvents.filter(e => e.date === k))
            .sort((a, b) => (a.time || "").localeCompare(b.time || ""))
    }
    function nextOccurrence(e, from) {
        if (!e.repeat) return e.date >= key(from) ? occurrence(e, dayOf(e.date)) : null
        for (let i = 0; i < 400; i++) {
            const d = new Date(from.getFullYear(), from.getMonth(), from.getDate() + i)
            if (occursOn(e, d)) return occurrence(e, d)
        }
        return null
    }
    readonly property var upcoming: {
        const t = key(today)
        return localEvents.map(e => nextOccurrence(e, today)).filter(e => e)
            .concat(feedEvents.filter(e => e.date >= t && !e.holiday))
            .sort((a, b) => (a.date + (a.time || "")).localeCompare(b.date + (b.time || "")))
    }
    readonly property var agenda: key(selected) === key(today) ? upcoming : eventsOn(key(selected))

    function titleOf(e) {
        if (!(e.years > 0)) return e.title
        return e.title + (e.kind === "birthday" ? "  ·  turns " + e.years : "  ·  " + e.years + (e.years === 1 ? " year" : " years"))
    }

    // ---- adding and removing your events --------------------------------------
    property string newRepeat: ""
    property string newKind: ""
    property bool pickedByHand: false
    function guess(text) {        // "bday" / "birthday" / "anniversary" set repeat and tag for you
        if (pickedByHand) return
        if (/b'?day|birthday/i.test(text)) { newRepeat = "yearly"; newKind = "birthday" }
        else if (/anniversary/i.test(text)) { newRepeat = "yearly"; newKind = "anniversary" }
        else { newRepeat = ""; newKind = "" }
    }
    function addEvent(text) {
        let s = text.trim(), date = key(selected)
        let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})\s+/) || s.match(/^(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{4})\s+/)
        if (m) {
            const [y, mo, d] = m[1].length === 4 ? [+m[1], +m[2], +m[3]] : [+m[3], +m[2], +m[1]]   // ISO, or day/month/year
            const dt = new Date(y, mo - 1, d)
            if (dt.getMonth() === mo - 1) { date = key(dt); s = s.slice(m[0].length) }
        }
        m = s.match(/^(\d{1,2}[:.]\d{2}\s*(?:am|pm)?)?\s*(.+)$/i)
        if (!m || !m[2]) return
        let time = "", title = m[2]
        if (m[1]) {
            let [h, mi] = m[1].replace(".", ":").replace(/\s*(am|pm)/i, "").split(":").map(Number)
            const ampm = /am|pm/i.test(m[1])
            if (/pm/i.test(m[1]) && h < 12) h += 12
            if (/am/i.test(m[1]) && h === 12) h = 0
            if (h < 24 && mi < 60 && !(ampm && (h > 23 || +m[1].split(/[:.]/)[0] > 12)))
                time = String(h).padStart(2, "0") + ":" + String(mi).padStart(2, "0")
            else title = s                                 // not a real time: it's part of the title
        }
        const ev = { id: Date.now().toString(36), date: date, time: time, title: title, repeat: newRepeat, kind: newKind }
        Plasmoid.configuration.events = JSON.stringify(localEvents.concat([ev]))
    }
    function removeEvent(ev) {
        const date = ev.origDate || ev.date
        Plasmoid.configuration.events = JSON.stringify(localEvents.filter(e =>
            ev.id ? e.id !== ev.id : !(e.date === date && e.time === ev.time && e.title === ev.title)))
    }
    function fmtTime(t) {
        if (!t) return "All day"
        const [h, m] = t.split(":").map(Number)
        return (h % 12 || 12) + ":" + String(m).padStart(2, "0") + (h < 12 ? " AM" : " PM")
    }

    // ---- iCal feeds -------------------------------------------------------
    // one feed per line: "<link> [#rrggbb] [Name words] [+Keep +Words]"
    function feedList() {
        const out = []
        for (const line of Plasmoid.configuration.feeds.split("\n")) {
            for (const tok of line.trim().split(/\s+/)) {
                if (/^https?:\/\//.test(tok)) out.push({ url: tok, color: "", name: "", keep: [] })
                else if (!out.length || !tok) continue
                else if (/^#[0-9a-f]{6}$/i.test(tok)) out[out.length - 1].color = tok
                else if (tok.startsWith("+") && tok.length > 1) out[out.length - 1].keep.push(tok.slice(1).toLowerCase())
                else out[out.length - 1].name += (out[out.length - 1].name ? " " : "") + tok
            }
        }
        return out
    }
    // a feed's events as saved: [{date:"2026-11-18", time:"09:30", title}], 2 months back to 12 ahead.
    // Repeating events (RRULE: DAILY / WEEKLY with BYDAY / MONTHLY / YEARLY, with
    // INTERVAL, COUNT, UNTIL) are expanded; EXDATEs and moved occurrences
    // (RECURRENCE-ID) are left out of the series.
    function icsDate(v) {      // "20261119" / "20261119T093000[Z]" -> {d: Date, allDay}
        const y = +v.slice(0, 4), mo = +v.slice(4, 6) - 1, d = +v.slice(6, 8)
        if (v.length === 8) return { d: new Date(y, mo, d), allDay: true }
        const H = +v.slice(9, 11), M = +v.slice(11, 13)
        return { d: v.endsWith("Z") ? new Date(Date.UTC(y, mo, d, H, M)) : new Date(y, mo, d, H, M), allDay: false }
    }
    function stamp(d, allDay) { return key(d) + (allDay ? "" : Qt.formatTime(d, "HH:mm")) }
    function expand(ev, lo, hi) {
        if (!ev.rrule) return [ev.start]
        const r = {}
        for (const part of ev.rrule.split(";")) { const [k, v] = part.split("="); r[k] = v }
        const step = Math.max(1, +(r.INTERVAL || 1)), count = r.COUNT ? +r.COUNT : Infinity
        const until = r.UNTIL ? icsDate(r.UNTIL).d : null
        const s = ev.start, out = []
        const at = (y, m, d) => new Date(y, m, d, s.getHours(), s.getMinutes())
        const days = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        const byday = (r.BYDAY || "").split(",").map(x => days.indexOf(x.slice(-2))).filter(x => x >= 0)
        let n = 0
        // walks the series in order; false once it's over
        const take = (d) => {
            if (d < s) return true
            if ((until && d > until) || n >= count || d > hi) return false
            n++
            if (d >= lo && !ev.skip.includes(stamp(d, ev.allDay))) out.push(d)
            return true
        }
        // with no COUNT to honour, start a step or two before the window (an old
        // daily series would otherwise run out of steps before reaching today)
        let i0 = 0
        if (!r.COUNT && lo > s) {
            const months = (lo.getFullYear() - s.getFullYear()) * 12 + lo.getMonth() - s.getMonth()
            i0 = Math.max(0, Math.floor(r.FREQ === "DAILY" ? (lo - s) / 86400000 / step
                                      : r.FREQ === "WEEKLY" ? (lo - s) / 604800000 / step
                                      : r.FREQ === "MONTHLY" ? months / step : months / 12 / step) - 2)
        }
        for (let i = i0; i < i0 + 3000; i++) {
            if (r.FREQ === "DAILY") { if (!take(at(s.getFullYear(), s.getMonth(), s.getDate() + i * step))) break }
            else if (r.FREQ === "WEEKLY") {
                const week = at(s.getFullYear(), s.getMonth(), s.getDate() - s.getDay() + i * 7 * step)   // that week's Sunday
                const which = byday.length ? byday.slice().sort() : [s.getDay()]
                let go = true
                for (const wd of which) if (!(go = take(at(week.getFullYear(), week.getMonth(), week.getDate() + wd)))) break
                if (!go) break
            } else if (r.FREQ === "MONTHLY") {
                const d = at(s.getFullYear(), s.getMonth() + i * step, s.getDate())
                if (d.getDate() === s.getDate() && !take(d)) break                    // months without that day are skipped
            } else if (r.FREQ === "YEARLY") {
                const d = at(s.getFullYear() + i * step, s.getMonth(), s.getDate())
                if (d.getMonth() === s.getMonth() && !take(d)) break                  // 29 Feb only in leap years
            } else return [s]
        }
        return out
    }
    function parseIcs(text) {
        const lines = text.replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
        const lo = new Date(), hi = new Date()
        lo.setMonth(lo.getMonth() - 2); hi.setMonth(hi.getMonth() + 12)
        const evs = [], moved = {}          // uid -> stamps of occurrences moved to their own event
        let ev = null
        for (const l of lines) {
            const val = l.slice(l.indexOf(":") + 1)
            if (l === "BEGIN:VEVENT") ev = { skip: [] }
            else if (l === "END:VEVENT" && ev) { if (ev.start) evs.push(ev); ev = null }
            else if (!ev) continue
            else if (l.startsWith("SUMMARY")) ev.title = val.replace(/\\([,;\\])/g, "$1")
            else if (l.startsWith("UID")) ev.uid = val
            else if (l.startsWith("RRULE")) ev.rrule = val
            else if (l.startsWith("DTSTART")) { const t = icsDate(val); ev.start = t.d; ev.allDay = t.allDay }
            else if (l.startsWith("EXDATE")) for (const x of val.split(",")) { const t = icsDate(x); ev.skip.push(stamp(t.d, t.allDay)) }
            else if (l.startsWith("RECURRENCE-ID")) ev.recId = icsDate(val)
        }
        for (const e of evs) if (e.recId && e.uid) (moved[e.uid] = moved[e.uid] || []).push(stamp(e.recId.d, e.recId.allDay))
        const out = []
        for (const e of evs) {
            if (e.rrule && e.uid && moved[e.uid]) e.skip = e.skip.concat(moved[e.uid])
            for (const d of expand(e, lo, hi))
                if (d >= lo && d <= hi)
                    out.push({ date: key(d), time: e.allDay ? "" : Qt.formatTime(d, "HH:mm"), title: e.title || "(no title)" })
        }
        return out
    }
    // the feed's colour, name, holiday flag and +Words are applied when shown, so
    // editing them works offline too
    function decorate(f, evs) {
        let link = f.url
        try { link = decodeURIComponent(link) } catch (e) {}
        const holiday = /holiday/i.test(link)
        return evs.filter(e => !f.keep.length || f.keep.some(w => e.title.toLowerCase().includes(w)))
            .map(e => ({ date: e.date, time: e.time, title: e.title, holiday: holiday, color: f.color,
                         source: f.name || (holiday ? "Holidays" : "Calendar") }))
    }
    // last good download of each feed, by link, saved in the config
    readonly property var savedFeeds: { try { return JSON.parse(Plasmoid.configuration.feedCache) } catch (e) { return {} } }
    readonly property var feedEvents: {    // [{date, time, title, holiday, color, source}]
        const saved = savedFeeds
        return [].concat(...feedList().map(f => decorate(f, saved[f.url] || [])))
    }
    function saveFeed(url, evs) {
        const links = feedList().map(f => f.url)
        if (!links.includes(url)) return                 // removed while it downloaded
        const next = {}
        for (const u of links) if (savedFeeds[u]) next[u] = savedFeeds[u]   // drops removed feeds
        next[url] = evs
        const s = JSON.stringify(next)
        if (s !== Plasmoid.configuration.feedCache) Plasmoid.configuration.feedCache = s
    }

    property var feedsFailing: []        // links whose last download failed (offline, or the link is down)
    property var inflight: ({})          // link -> download in progress
    function fetchFeed(f) {
        const busy = inflight[f.url]
        if (busy && Date.now() - busy.started < 90000) return
        const req = { xhr: new XMLHttpRequest(), started: Date.now() }
        inflight[f.url] = req
        req.xhr.onreadystatechange = () => {
            if (req.xhr.readyState !== XMLHttpRequest.DONE) return
            // a Wi-Fi login page also answers 200, so it has to look like a calendar
            const ok = req.xhr.status === 200 && req.xhr.responseText.indexOf("BEGIN:VCALENDAR") >= 0
            if (ok) root.saveFeed(f.url, root.parseIcs(req.xhr.responseText))   // a failure keeps the saved copy
            if (root.inflight[f.url] !== req) return      // a newer try for this link took over
            delete root.inflight[f.url]
            const rest = root.feedsFailing.filter(u => u !== f.url)
            root.feedsFailing = ok ? rest : rest.concat([f.url])
        }
        req.xhr.open("GET", f.url); req.xhr.send()
    }
    function syncFeeds(onlyFailing) {
        for (const f of feedList())
            if (!onlyFailing || feedsFailing.includes(f.url)) fetchFeed(f)
    }
    Timer { interval: 30 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.syncFeeds(false) }
    Timer { interval: 60000; running: root.feedsFailing.length > 0; repeat: true; onTriggered: root.syncFeeds(true) }
    Connections { target: Plasmoid.configuration; function onFeedsChanged() { root.feedsFailing = []; root.syncFeeds(false) } }
    // a new day (also after sleeping through one, or a month): move today, and the
    // selection and month with it when they were on today
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
            const n = new Date()
            if (root.key(n) === root.key(root.today)) return
            const wasToday = root.key(root.selected) === root.key(root.today)
            const wasThisMonth = root.shown.getFullYear() === root.today.getFullYear() && root.shown.getMonth() === root.today.getMonth()
            root.today = n
            if (wasToday) root.selected = n
            if (wasThisMonth) root.shown = new Date(n.getFullYear(), n.getMonth(), 1)
        }
    }

    // ---- reminders (as notifications, so the Dynamic Island shows them) --------
    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }
    readonly property var reminded: { try { return JSON.parse(Plasmoid.configuration.reminded) } catch (e) { return [] } }
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function remind(id, e, body) {
        if (reminded.includes(id)) return
        const since = key(new Date(Date.now() - 2 * 86400000))
        Plasmoid.configuration.reminded = JSON.stringify(reminded.filter(r => r.slice(0, 10) >= since).concat([id]))
        const icon = e.kind === "birthday" ? "view-calendar-birthday" : e.kind === "anniversary" ? "view-calendar-special-occasion" : "view-calendar-upcoming-events"
        exec.connectSource("notify-send -a " + q(e.source || "Calendar") + " -i " + icon + " -- " + q(titleOf(e)) + " " + q(body))
    }
    function checkReminders() {
        if (!Plasmoid.configuration.reminders) return
        const now = new Date(), tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
        for (const e of eventsOn(key(now)).concat(eventsOn(key(tomorrow)))) {
            if (e.holiday) continue
            const id = e.date + "|" + (e.time || "") + "|" + e.title
            if (!e.time) {
                if (e.date === key(now) && now.getHours() >= 9) remind(id + "|day", e, "Today")
                continue
            }
            const mins = (new Date(e.date + "T" + e.time) - now) / 60000
            if (mins > 0 && mins <= 10) remind(id + "|soon", e, "In " + Math.ceil(mins) + " min  ·  " + fmtTime(e.time))
            else if (mins <= 0 && mins > -5) remind(id + "|now", e, "Now  ·  " + fmtTime(e.time))
        }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.checkReminders() }   // first check 30 s after start

    fullRepresentation: GlassCard {
        Layout.minimumWidth: 360; Layout.preferredWidth: 360
        Layout.minimumHeight: 288; Layout.preferredHeight: 288
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
                        readonly property var special: evs.find(e => e.kind)            // birthday / anniversary / important
                        readonly property var dots: [...new Set(evs.filter(e => !e.holiday).map(e => root.colorOf(e)))].slice(0, 3)
                        visible: index < 35 || lead + new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate() > 35
                        Rectangle {
                            anchors.centerIn: parent; width: 24; height: 24; radius: 12
                            color: parent.isToday ? st.accent : "transparent"
                            border.color: parent.isSel && !parent.isToday ? st.subtle : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: parent.isToday ? "white" : parent.special ? root.kindColor(parent.special.kind) : parent.holiday ? st.accent : st.text
                            opacity: parent.inMonth ? 1 : 0.3
                            font.family: st.mono; font.pixelSize: 12
                        }
                        Row {         // one dot per colour of that day's events
                            visible: !parent.isToday
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                            spacing: 2
                            Repeater { model: parent.parent.dots; Rectangle { width: 4; height: 4; radius: 2; color: modelData } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = parent.day }
                        QQC2.ToolTip.visible: hov.hovered && evs.length > 0
                        QQC2.ToolTip.text: evs.map(e => (e.time ? root.fmtTime(e.time) + "  " : "") + root.titleOf(e)).join("\n")
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
                    source: addBox.visible ? "dialog-cancel" : "list-add"; isMask: true; color: ad.containsMouse ? st.accent : st.muted
                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                    MouseArea { id: ad; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { addBox.visible = !addBox.visible; if (addBox.visible) { root.pickedByHand = false; root.guess(""); adding.forceActiveFocus() } } }
                }
            }

            // ---- add an event: text, then how often and which colour ----------
            ColumnLayout {
                id: addBox
                visible: false
                Layout.fillWidth: true
                spacing: 4
                function close() { adding.text = ""; visible = false }
                QQC2.TextField {
                    id: adding
                    Layout.fillWidth: true
                    placeholderText: "09:30 Gym  or  05/03/2004 Mom's bday  (" + Qt.formatDate(root.selected, "d MMM") + ")"
                    onTextChanged: root.guess(text)
                    onAccepted: { root.addEvent(text); addBox.close() }
                    Keys.onEscapePressed: addBox.close()
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    component Chip: Rectangle {
                        id: chip
                        property string label
                        property bool on: false
                        signal hit()
                        implicitWidth: ct.implicitWidth + 14; implicitHeight: 20; radius: 10
                        color: on ? st.accentSoft : (cm.containsMouse ? st.hover : st.faint)
                        border.color: on ? st.accent : "transparent"
                        Text { id: ct; anchors.centerIn: parent; text: chip.label; color: chip.on ? st.text : st.muted; font.pixelSize: 11 }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.hit() }
                    }
                    Repeater {
                        model: [["", "Once"], ["weekly", "Weekly"], ["monthly", "Monthly"], ["yearly", "Yearly"]]
                        Chip { label: modelData[1]; on: root.newRepeat === modelData[0]
                               onHit: { root.newRepeat = modelData[0]; root.pickedByHand = true } }
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: root.kinds
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: modelData.kind ? modelData.color : "transparent"
                            border.width: root.newKind === modelData.kind ? 2 : 1
                            border.color: root.newKind === modelData.kind ? st.text : st.border
                            QQC2.ToolTip.visible: km.containsMouse
                            QQC2.ToolTip.text: modelData.label
                            MouseArea { id: km; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.newKind = modelData.kind; root.pickedByHand = true } }
                        }
                    }
                }
            }

            // ---- the agenda: as many rows as fit -----------------------------
            Item {
                id: list
                visible: !addBox.visible
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int rowH: 21
                Text {
                    visible: root.agenda.length === 0
                    text: "Nothing planned"
                    color: st.muted; font.pixelSize: 13
                }
                Column {
                    width: parent.width
                    Repeater {
                        model: root.agenda.slice(0, Math.max(1, Math.floor(list.height / list.rowH)))
                        RowLayout {
                            width: parent.width; height: list.rowH
                            spacing: 8
                            Rectangle { width: 6; height: 6; radius: 3; color: root.colorOf(modelData) }
                            Text {
                                Layout.preferredWidth: 104
                                text: (root.key(root.selected) === root.key(root.today) && modelData.date !== root.key(root.today)
                                       ? Qt.formatDate(root.dayOf(modelData.date), "d MMM") + " " : "") + root.fmtTime(modelData.time)
                                color: modelData.holiday ? st.accent : st.muted; font.family: st.mono; font.pixelSize: 11
                            }
                            Text { text: root.titleOf(modelData); color: st.text; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                enabled: modelData.local === true
                                onTapped: root.removeEvent(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
