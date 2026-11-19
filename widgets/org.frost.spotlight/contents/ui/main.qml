// Spotlight: a KRunner-style glass search popup, opened with the Meta key on its
// own (it registers as the app launcher; Meta+Space stays with KRunner).
// Results come from Plasma's own
// search runners (the same ones KRunner uses), grouped by kind:
// applications, windows, System Settings, calculator ("= 1250 * 1.18"),
// unit / currency conversion ("10 km in miles"), recent documents, places,
// web shortcuts ("gg:frost kde") and more.
// Developer extras on top of those:
//   project names   your folders in ~/dev: Enter = VS Code, Ctrl+Enter = kitty, Shift+Enter = Dolphin
//   file names      anywhere in your home (plocate's daily index): Enter = open, Shift+Enter = show in Dolphin
//   > command       runs it in a new kitty window
//   gh: words       your GitHub repositories, or a GitHub search
//
//   type        search            Up / Down    move           Enter   open
//   Shift+Enter first extra action  Esc        close          Tab     next group
//
// The widget itself is a 1 px item in a panel; the search bar is its own window.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    activationTogglesExpanded: false


    // the shortcut fires activated() and also sets `expanded`: either toggles, once
    property double lastToggle: 0
    // Plasma restores `expanded` when it starts: ignore anything in the first seconds
    property bool ready: false
    Timer { interval: 3000; running: true; onTriggered: root.ready = true }
    // ignore a close that arrives within a second of opening (a key that both
    // opens it and, on release, counts as the launcher key would close it again)
    property double openedAt: 0
    property double projectsAt: 0
    function toggle() {
        if (!ready || Date.now() - lastToggle < 400) return
        if (win.visible && Date.now() - openedAt < 1000) return
        lastToggle = Date.now()
        win.visible ? close() : open()
    }
    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    onExpandedChanged: (on) => { if (on) { root.toggle(); Qt.callLater(() => root.expanded = false) } }

    // ---- developer sources ------------------------------------------------------
    readonly property string devPy: "python3 '" + Qt.resolvedUrl("../code/dev.py").toString().replace("file://", "") + "'"
    function q(x) { return "'" + String(x).replace(/'/g, "'\\''") + "'" }
    function run(cmd) { exec.connectSource("setsid " + cmd + " >/dev/null 2>&1 &") }
    property var projects: []
    property var repos: []
    property var files: []
    property string filesFor: ""
    P5Support.DataSource {
        id: exec; engine: "executable"
        onNewData: (src, data) => {
            try {
                if (src === root.devPy + " projects") root.projects = JSON.parse(data["stdout"])
                else if (src === root.devPy + " repos") root.repos = JSON.parse(data["stdout"])
                else if (src.startsWith(root.devPy + " files ") && src === root.devPy + " files " + root.q(root.filesFor)) root.files = JSON.parse(data["stdout"])
                else if (src === root.devPy + " info " + root.q(root.infoFor)) root.info = JSON.parse(data["stdout"])
            } catch (e) {}
            disconnectSource(src)
        }
    }
    readonly property string query: field.text
    readonly property bool isCmd: query.startsWith(">")
    readonly property bool isGh: query.toLowerCase().startsWith("gh:")
    readonly property bool special: isCmd || isGh
    Timer {   // file names: a short pause after typing, then one plocate call
        id: fileTimer; interval: 160
        onTriggered: {
            const t = root.query.trim()
            if (root.special || t.length < 3) { root.files = []; return }
            root.filesFor = t
            exec.connectSource(root.devPy + " files " + root.q(t))
        }
    }
    // decide from `query` itself: isGh may not be re-evaluated yet inside this handler
    onQueryChanged: { fileTimer.restart(); if (query.toLowerCase().startsWith("gh:") && !repos.length) exec.connectSource(devPy + " repos") }

    // fuzzy: whole-word prefix > substring > letters in order (fr -> frost, fortis)
    function score(text, t) {
        text = text.toLowerCase(); t = t.toLowerCase()
        if (text.startsWith(t)) return 3
        if (text.split(/[\/\-_ .]/).some(w => w.startsWith(t))) return 2.5
        if (text.includes(t)) return 2
        let i = 0
        for (const c of text) if (c === t[i]) i++
        return i === t.length ? 1 : 0
    }
    readonly property var devItems: {
        const t = query.trim(), out = []
        if (isCmd) {
            const c = query.slice(1).trim()
            if (c) out.push({ group: "Terminal", title: c, sub: "Run in a new kitty window", icon: "utilities-terminal", kind: "cmd", arg: c })
            return out
        }
        if (isGh) {
            const g = query.slice(3).trim()
            const mine = repos.map(r => ({ r: r, s: g ? Math.max(score(r.nameWithOwner.split("/")[1], g), score(r.nameWithOwner, g)) : 1 }))
                              .filter(x => x.s > 0).sort((a, b) => b.s - a.s).slice(0, 6)
            for (const x of mine) out.push({ group: "GitHub", title: x.r.nameWithOwner, sub: x.r.description || "Open on GitHub", icon: "internet-web-browser", kind: "url", arg: x.r.url })
            if (g) out.push({ group: "GitHub", title: "Search GitHub for “" + g + "”", sub: "github.com/search", icon: "search", kind: "url",
                              arg: "https://github.com/search?q=" + encodeURIComponent(g) + "&type=repositories" })
            return out
        }
        if (!t) return out
        const ps = projects.map(pr => ({ pr: pr, s: Math.max(score(pr.name, t), score(pr.rel, t) - 0.5) }))
                           .filter(x => x.s > 0).sort((a, b) => b.s - a.s || b.pr.t - a.pr.t).slice(0, 5)
        for (const x of ps) out.push({ group: "Projects", title: x.pr.name, sub: "~/dev/" + x.pr.rel + (x.pr.git ? "  ·  git" : ""), icon: "folder-development", kind: "project", arg: x.pr.path })
        if (files.length && filesFor === t)
            for (const f of files) out.push({ group: "Files", title: f.name, sub: f.path.replace(/^\/home\/[^/]+/, "~"), icon: f.dir ? "folder" : "text-x-generic", kind: "file", arg: f.path })
        return out
    }
    function runDev(it, mods) {
        if (!it) return
        const ctrl = mods & Qt.ControlModifier, shift = mods & Qt.ShiftModifier
        if (it.kind === "project") run(ctrl ? "kitty --directory " + q(it.arg) : shift ? "dolphin " + q(it.arg) : "code " + q(it.arg))
        else if (it.kind === "file") run(shift ? "dolphin --select " + q(it.arg) : "xdg-open " + q(it.arg))
        else if (it.kind === "cmd") run("kitty --hold --directory \"$HOME\" bash -lc " + q(it.arg))
        else if (it.kind === "url") Qt.openUrlExternally(it.arg)
        close()
    }

    // two lists, one selection: developer results on top, Plasma's below
    property bool devActive: true
    onDevItemsChanged: { devActive = devItems.length > 0; devList.currentIndex = 0 }
    function moveDown() {
        if (devActive && devList.count) {
            if (devList.currentIndex < devList.count - 1) devList.currentIndex++
            else if (list.count) { devActive = false; list.currentIndex = 0 }
            else devList.currentIndex = 0
        } else if (list.count) {
            if (list.currentIndex < list.count - 1) list.currentIndex++
            else if (devList.count) { devActive = true; devList.currentIndex = 0 }
            else list.currentIndex = 0
        }
    }
    function moveUp() {
        if (devActive && devList.count) {
            if (devList.currentIndex > 0) devList.currentIndex--
            else if (list.count) { devActive = false; list.currentIndex = list.count - 1 }
            else devList.currentIndex = devList.count - 1
        } else if (list.count) {
            if (list.currentIndex > 0) list.currentIndex--
            else if (devList.count) { devActive = true; devList.currentIndex = devList.count - 1 }
            else list.currentIndex = list.count - 1
        }
    }
    // ---- preview pane: details of the selected result -------------------------
    // {icon, title, sub, group, target}: target is a path / URL dev.py can describe
    readonly property var selected: devActive && devList.count ? devList.currentItem && devList.currentItem.info
                                   : list.currentItem ? list.currentItem.info : null
    property var info: ({})
    property string infoFor: ""
    onSelectedChanged: { info = ({}); infoTimer.restart() }
    Timer {   // ask dev.py once the selection settles
        id: infoTimer; interval: 90
        onTriggered: {
            const t = root.selected ? root.selected.target : ""
            root.infoFor = t
            if (t) exec.connectSource(root.devPy + " info " + root.q(t))
        }
    }

    function runSelected(e) {
        if (devActive && devList.count) runDev(devItems[devList.currentIndex], e ? e.modifiers : 0)
        else list.runCurrent(e)
    }


    property bool showTips: false   // the "?" button: syntax tips instead of results
    property bool pinned: false     // the pin button: stay open when another window takes focus

    function open() {
        openedAt = Date.now()
        if (!projects.length || Date.now() - projectsAt > 60000) { projectsAt = Date.now(); exec.connectSource(devPy + " projects") }
        field.text = ""
        showTips = false
        win.visible = true
        win.requestActivate()
        field.forceActiveFocus()
    }
    function close() { win.visible = false; field.text = "" }

    // for testing the window on its own: `plasmawindowed org.frost.spotlight frost-test:QUERY`
    // (add frost-shot:/path.png to save a picture of it and quit)
    Timer {
        interval: 1500; running: Qt.application.name === "plasmawindowed"
        onTriggered: {
            const args = Qt.application.arguments
            const a = args.find(x => x.startsWith("frost-test:"))
            if (!a) return
            root.ready = true; root.open()
            const t = a.slice(11)
            if (t === "?") root.showTips = true; else field.text = t
            if (args.find(x => x === "frost-pin")) root.pinned = true
            const shot = args.find(x => x.startsWith("frost-shot:"))
            if (shot) shotTimer.start()
        }
    }
    Timer {
        id: shotTimer; interval: 2500
        onTriggered: panel.grabToImage(r => { r.saveToFile(Qt.application.arguments.find(x => x.startsWith("frost-shot:")).slice(11)); Qt.quit() })
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 1; Layout.minimumWidth: 1; Layout.maximumWidth: 1
        Layout.preferredHeight: 1
    }

    Style { id: st }
    readonly property rect scr: Plasmoid.containment && Plasmoid.containment.screenGeometry.width > 0
                                ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, Screen.width || 1920, Screen.height || 1080)
    readonly property bool anyResults: devList.count + list.count > 0
    readonly property int listW: 590
    readonly property int previewW: 300
    readonly property int cardW: anyResults ? listW + previewW + 1 : 640
    readonly property int catW: 152        // the category column, names right-aligned
    readonly property int rowH: 34
    readonly property int maxListH: 11 * rowH

    // a small round icon button for the top row (gear, clear, ?, pin)
    component IconButton: Rectangle {
        id: ib
        property string icon
        property bool checked: false
        property int size: 30
        property string tip
        signal clicked()
        implicitWidth: size; implicitHeight: size
        radius: size / 2 - 4
        color: checked ? st.accentSoft : (ibm.containsMouse ? st.hover : "transparent")
        border.color: checked ? Qt.rgba(242/255, 29/255, 67/255, 0.55) : "transparent"
        scale: ibm.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(ib.size * 0.56); height: width
            source: ib.icon; isMask: true
            color: ib.checked ? st.accent : (ibm.containsMouse ? st.text : st.muted)
        }
        MouseArea { id: ibm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
        QQC2.ToolTip.visible: tip.length > 0 && ibm.containsMouse
        QQC2.ToolTip.delay: 700
        QQC2.ToolTip.text: tip
    }

    // one result row, KRunner style: [category, right-aligned] [icon] name  subtext ... hint
    component ResultRow: Item {
        id: r
        property string category
        property bool firstInGroup: false
        property bool sepAbove: false
        property var icon
        property string title
        property string sub
        property string hint
        property bool current: false
        property bool mono: false
        signal activated(int mods)
        height: root.rowH + (sepAbove ? 9 : 0)

        Rectangle {   // thin line between groups
            visible: r.sepAbove
            anchors { top: parent.top; topMargin: 4; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
            height: 1; color: st.faint
        }
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: root.rowH
            Rectangle {   // selection / hover
                anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                radius: 9
                color: r.current ? Qt.rgba(242/255, 29/255, 67/255, 0.42) : (rm.containsMouse ? st.faint : "transparent")
                border.color: r.current ? Qt.rgba(1, 0.35, 0.45, 0.75) : "transparent"
                Behavior on color { ColorAnimation { duration: 90 } }
            }
            Text {
                visible: r.firstInGroup
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: root.catW - 14
                horizontalAlignment: Text.AlignRight
                text: r.category
                color: r.current ? st.textOnAccent : st.muted
                font.pixelSize: 12
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            RowLayout {
                anchors { fill: parent; leftMargin: root.catW; rightMargin: 12 }
                spacing: 10
                Kirigami.Icon { source: r.icon; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                Text {
                    id: tt
                    text: r.title; color: r.current ? st.textOnAccent : st.text
                    font.pixelSize: 14; font.family: r.mono ? st.mono : Qt.application.font.family
                    elide: Text.ElideRight; textFormat: Text.PlainText
                    // the name comes first; the subtext gets what is left
                    Layout.preferredWidth: Math.min(implicitWidth, r.sub ? Math.max(140, (r.width - root.catW - 60) * 0.62) : implicitWidth)
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.minimumWidth: Math.min(implicitWidth, 60)
                }
                Text {
                    text: r.sub; visible: text.length > 0
                    color: r.current ? Qt.rgba(1, 1, 1, 0.72) : st.muted
                    font.pixelSize: 12; elide: Text.ElideMiddle; textFormat: Text.PlainText
                    Layout.fillWidth: true
                    Layout.minimumWidth: Math.min(implicitWidth, 60)
                }
                Item { Layout.fillWidth: true; visible: r.sub.length === 0 }
                Text {
                    id: hintText
                    visible: false   // shown in the preview pane instead
                    text: r.hint; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 11
                }
            }
            MouseArea {
                id: rm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (m) => r.activated(m.modifiers)
            }
        }
    }

    // the preview pane on the right: a big icon (or the picture itself), the
    // name, a line about it, details from dev.py and, for text files, the start of the file
    component Preview: Item {
        id: pv
        readonly property var sel: root.selected
        readonly property var inf: root.info || ({})
        readonly property var rows: inf.rows || []
        clip: true
        visible: sel !== null
        ColumnLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 14; topMargin: 8; bottomMargin: 6 }
            spacing: 6
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: pv.inf.kind === "image" ? 140 : 60
                Layout.topMargin: 4
                Image {
                    id: thumb
                    visible: pv.inf.kind === "image" && status === Image.Ready
                    anchors.fill: parent
                    source: pv.inf.kind === "image" ? "file://" + encodeURI(pv.inf.path) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize { width: 560; height: 280 }
                }
                Kirigami.Icon {
                    visible: !thumb.visible
                    anchors.centerIn: parent
                    width: 60; height: 60
                    source: pv.sel ? pv.sel.icon : ""
                }
            }
            Text {
                Layout.fillWidth: true
                text: pv.sel ? pv.sel.title : ""
                // a bare answer (calculator, units) gets shown large
                readonly property bool answer: pv.rows.length === 0 && pv.sel && !pv.sel.sub && String(pv.sel.title).length < 18
                color: st.text; font.pixelSize: answer ? 30 : 15; font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Text {
                Layout.fillWidth: true
                readonly property string about: pv.inf.about || (pv.sel ? pv.sel.sub : "")
                visible: about.length > 0
                text: about
                color: st.muted; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: pv.sel ? String(pv.sel.group).toUpperCase() : ""
                color: st.accent; font.pixelSize: 10; font.letterSpacing: 1.4
            }
            Rectangle { visible: pv.rows.length > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 2; color: st.faint }
            Repeater {
                model: pv.rows
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: modelData[0]; color: st.muted; font.pixelSize: 11; horizontalAlignment: Text.AlignRight
                           Layout.preferredWidth: 78 }
                    Text { text: modelData[1]; color: st.text; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.fillWidth: true
                           textFormat: Text.PlainText }
                }
            }
            Rectangle {   // the start of a text file
                visible: !!pv.inf.text
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 40
                Layout.topMargin: 4
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.28)
                border.color: st.faint
                clip: true
                Text {
                    anchors { fill: parent; margins: 8 }
                    text: pv.inf.text || ""
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.family: st.mono; font.pixelSize: 10
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
            }
            Item { Layout.fillHeight: true; visible: !pv.inf.text }
            Text {   // what Enter / Shift+Enter do
                Layout.fillWidth: true
                readonly property var acts: pv.sel && pv.sel.actions ? pv.sel.actions : []
                text: pv.sel && pv.sel.hint && pv.sel.hint !== "↵" ? pv.sel.hint
                      : "↵ Open" + (acts.length ? "  ·  Shift ↵ " + acts[0] : "")
                color: st.muted; font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    PlasmaCore.Dialog {
        id: win
        visible: false
        type: PlasmaCore.Dialog.Normal
        // the Frost theme's dialog frame: translucent, blurred and contrast-boosted
        // by KWin (the same glass KRunner and every Plasma popup get)
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: !root.pinned
        x: root.scr.x + root.scr.width / 2 - width / 2
        y: root.scr.y + Math.round(root.scr.height * 0.2)

        mainItem: FocusScope {
            id: panel
            width: root.cardW
            height: col.implicitHeight
            Keys.onEscapePressed: root.close()
            readonly property bool hasResults: devList.count + list.count > 0

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 0

                // ---- top row: gear, search field, ?, pin
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 6
                    IconButton { icon: "configure"; tip: "Search settings"
                                 onClicked: { root.run("systemsettings kcm_plasmasearch"); root.close() } }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 11
                        color: Qt.rgba(0, 0, 0, 0.28)
                        border.width: 1.5
                        border.color: field.activeFocus ? st.accent : st.border
                        Rectangle {   // glass top edge inside the field
                            anchors { top: parent.top; topMargin: 2; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                            height: 1; color: st.highlight
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 5 }
                            spacing: 8
                            Kirigami.Icon { source: "search"; isMask: true; color: field.text ? st.text : st.muted
                                            Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                            QQC2.TextField {
                                id: field
                                Layout.fillWidth: true
                                focus: true
                                background: null
                                leftPadding: 0; rightPadding: 0
                                color: st.text
                                selectionColor: st.accent
                                selectedTextColor: st.textOnAccent
                                placeholderText: "Search"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.38)
                                font.pixelSize: 15
                                selectByMouse: true
                                onTextChanged: if (text) root.showTips = false
                                Keys.onEscapePressed: root.close()
                                Keys.onDownPressed: root.moveDown()
                                Keys.onUpPressed: root.moveUp()
                                Keys.onTabPressed: { if (root.devActive && devList.count) { root.devActive = false; list.currentIndex = 0 } else list.nextGroup() }
                                Keys.onReturnPressed: (e) => root.runSelected(e)
                                Keys.onEnterPressed: (e) => root.runSelected(e)
                            }
                            Text { visible: results.querying; text: "…"; color: st.muted; font.pixelSize: 15 }
                            IconButton { icon: "edit-clear-locationbar-rtl"; size: 28; tip: "Clear"
                                         visible: field.text.length > 0
                                         onClicked: { field.text = ""; field.forceActiveFocus() } }
                        }
                    }
                    IconButton { icon: "question"; tip: "What can I type?"; checked: root.showTips
                                 onClicked: { root.showTips = !root.showTips; if (root.showTips) field.text = ""; field.forceActiveFocus() } }
                    IconButton { icon: "window-pin"; tip: root.pinned ? "Unpin" : "Keep open"; checked: root.pinned
                                 onClicked: { root.pinned = !root.pinned; field.forceActiveFocus() } }
                }

                Item { Layout.preferredHeight: 6; visible: panel.hasResults || tips.visible || noResults.visible }

                RowLayout {
                visible: panel.hasResults
                Layout.fillWidth: true
                spacing: 0
                ColumnLayout {
                Layout.preferredWidth: root.listW
                Layout.alignment: Qt.AlignTop
                spacing: 0
                // ---- developer results (projects, files, commands, GitHub)
                ListView {
                    id: devList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, root.maxListH)
                    visible: count > 0
                    interactive: false
                    clip: true                 // more results than fit would draw over Plasma's list below
                    model: root.devItems
                    onCountChanged: Qt.callLater(forceLayout)
                    section.property: "group"
                    section.criteria: ViewSection.FullString
                    delegate: ResultRow {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        category: modelData.group
                        firstInGroup: ListView.section !== ListView.previousSection
                        sepAbove: index > 0 && firstInGroup
                        icon: modelData.icon
                        title: modelData.title
                        sub: modelData.sub
                        mono: modelData.kind === "cmd"
                        current: root.devActive && ListView.isCurrentItem
                        hint: modelData.kind === "project" ? "↵ Code · Ctrl ↵ kitty · Shift ↵ Dolphin"
                            : modelData.kind === "file" ? "↵ Open · Shift ↵ Show" : "↵"
                        onActivated: (mods) => root.runDev(modelData, mods)
                        readonly property var info: ({ icon: modelData.icon, title: modelData.title, sub: modelData.sub, group: modelData.group,
                                                       target: modelData.kind === "project" || modelData.kind === "file" ? modelData.arg : "",
                                                       hint: hint })
                    }
                }

                // ---- Plasma's results
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, Math.max(0, root.maxListH - (devList.visible ? devList.height : 0)))
                    visible: count > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    keyNavigationWraps: true
                    currentIndex: 0
                    cacheBuffer: 2000          // keep every result instantiated, for Tab between groups
                    // row heights depend on the group headers, which settle a moment after the rows are
                    // created; while typing fast that left stale rows drawn on top of each other
                    onCountChanged: Qt.callLater(forceLayout)
                    onContentHeightChanged: Qt.callLater(forceLayout)
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

                    model: Milou.ResultsModel {
                        id: results
                        queryString: root.special ? "" : field.text
                        limit: 24
                        onQueryStringChanged: list.currentIndex = 0
                        onModelReset: list.currentIndex = 0
                        onQueryStringChangeRequested: (q, pos) => { field.text = q; field.cursorPosition = pos }
                    }

                    section.property: "category"
                    section.criteria: ViewSection.FullString

                    delegate: ResultRow {
                        id: row
                        required property int index
                        required property var model
                        width: ListView.view.width
                        category: ListView.section
                        firstInGroup: ListView.section !== ListView.previousSection
                        sepAbove: (index > 0 && firstInGroup) || (index === 0 && devList.count > 0)
                        icon: model.decoration
                        title: model.display || ""
                        sub: model.subtext || ""
                        current: !root.devActive && ListView.isCurrentItem
                        hint: "↵"
                        onActivated: { root.devActive = false; list.currentIndex = row.index; list.runCurrent(null) }
                        readonly property var info: ({ icon: model.decoration, title: model.display || "", sub: model.subtext || "", group: ListView.section,
                                                       target: model.urls && model.urls.length ? model.urls[0].toString() : "",
                                                       actions: (model.actions || []).map(a => a.text || "").filter(t => t) })
                    }

                    function runCurrent(e) {
                        if (count === 0) return
                        const ix = results.index(currentIndex, 0)
                        const ok = (e && e.modifiers & Qt.ShiftModifier) ? results.runAction(ix, 0) : results.run(ix)
                        if (ok) root.close()
                    }
                    // Tab: jump to the first result of the next group (wraps around)
                    function nextGroup() {
                        if (count === 0) return
                        const sec = currentItem ? currentItem.ListView.section : ""
                        for (let i = currentIndex + 1; i < count; i++) {
                            const it = itemAtIndex(i)
                            if (it && it.ListView.section !== sec) { currentIndex = i; return }
                        }
                        currentIndex = 0
                    }
                }

                }   // the lists
                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.topMargin: 4; Layout.bottomMargin: 4; color: st.faint }
                Preview {
                    Layout.preferredWidth: root.previewW
                    Layout.fillHeight: true
                    Layout.minimumHeight: 300
                }
                }   // lists + preview

                // ---- nothing found
                Item {
                    id: noResults
                    visible: field.text.length > 0 && !panel.hasResults && !results.querying
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowH
                    Text { x: root.catW; anchors.verticalCenter: parent.verticalCenter
                           text: "No results"; color: st.muted; font.pixelSize: 13 }
                }

                // ---- the "?" tips, in the same two-column layout as results
                ColumnLayout {
                    id: tips
                    visible: root.showTips && !field.text
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 0
                    component Tip: RowLayout {
                        property string k
                        property string v
                        spacing: 0
                        Layout.preferredHeight: 28
                        Text { text: parent.k; color: st.accent; font.family: st.mono; font.pixelSize: 12
                               horizontalAlignment: Text.AlignRight; Layout.preferredWidth: root.catW - 14 }
                        Item { Layout.preferredWidth: 14 }
                        Text { text: parent.v; color: st.muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Tip { k: "firefox"; v: "apps, open windows, settings pages" }
                    Tip { k: "= 1250 * 1.18"; v: "calculator" }
                    Tip { k: "10 km in miles"; v: "units and currencies" }
                    Tip { k: "gg: frost kde"; v: "web search  (dd: duckduckgo, yt: youtube)" }
                    Tip { k: "fr"; v: "projects in ~/dev   ↵ Code · Ctrl+↵ kitty · Shift+↵ Dolphin" }
                    Tip { k: "> ls -la"; v: "run a command in kitty" }
                    Tip { k: "gh: frost"; v: "your GitHub repos, or search GitHub" }
                    Tip { k: "↑ ↓  Tab  Esc"; v: "move, next group, close   ·   Shift+↵ first extra action" }
                }
            }
        }
    }
}
