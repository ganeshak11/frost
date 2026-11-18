// Spotlight: a centred black-glass search bar, opened with the Meta key on its
// own (it registers as the app launcher; Meta+Space stays with KRunner).
// Results come from Plasma's own
// search runners (the same ones KRunner uses), grouped by kind:
// applications, windows, System Settings, calculator ("= 1250 * 1.18"),
// unit / currency conversion ("10 km in miles"), recent documents, places,
// web shortcuts ("gg:frost kde"), commands ("> ls") and more.
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

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    activationTogglesExpanded: false

    readonly property color accent: "#F21D43"
    readonly property color text: "#F2F2F5"
    readonly property color muted: "#9A9AA6"
    readonly property string mono: "JetBrains Mono"

    // the shortcut fires activated() and also sets `expanded`: either toggles, once
    property double lastToggle: 0
    // Plasma restores `expanded` when it starts: ignore anything in the first seconds
    property bool ready: false
    Timer { interval: 3000; running: true; onTriggered: root.ready = true }
    // ignore a close that arrives within a second of opening (a key that both
    // opens it and, on release, counts as the launcher key would close it again)
    property double openedAt: 0
    function toggle() {
        if (!ready || Date.now() - lastToggle < 400) return
        if (win.visible && Date.now() - openedAt < 1000) return
        lastToggle = Date.now()
        win.visible ? close() : open()
    }
    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    onExpandedChanged: (on) => { if (on) { root.toggle(); Qt.callLater(() => root.expanded = false) } }

    function open() {
        openedAt = Date.now()
        field.text = ""
        win.visible = true
        win.requestActivate()
        field.forceActiveFocus()
        card.opacity = 0; card.scale = 0.96
        card.opacity = 1; card.scale = 1
    }
    function close() { win.visible = false; field.text = "" }

    fullRepresentation: Item {
        Layout.preferredWidth: 1; Layout.minimumWidth: 1; Layout.maximumWidth: 1
        Layout.preferredHeight: 1
    }

    readonly property rect scr: Plasmoid.containment && Plasmoid.containment.screenGeometry.width > 0
                                ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, Screen.width || 1920, Screen.height || 1080)
    readonly property int cardW: 680
    readonly property int rowH: 46
    readonly property int maxRows: 8

    PlasmaCore.Dialog {
        id: win
        visible: false
        type: PlasmaCore.Dialog.Normal
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        x: root.scr.x + root.scr.width / 2 - root.cardW / 2
        y: root.scr.y + Math.round(root.scr.height * 0.18)

        mainItem: Item {
            width: root.cardW
            // fixed height (the window doesn't resize while you type); the card grows inside it
            height: 76 + root.maxRows * root.rowH + 40
            Keys.onEscapePressed: root.close()

            Rectangle {
                id: card
                width: parent.width
                height: 64 + (list.count ? Math.min(list.contentHeight, root.maxRows * root.rowH) + 14 : (field.text ? 44 : 112))
                radius: 22
                color: "#0a0a0d"
                border.color: Qt.rgba(1, 1, 1, 0.12)
                clip: true
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                // ---- the search field
                RowLayout {
                    id: bar
                    anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 18 }
                    height: 64
                    spacing: 14
                    Kirigami.Icon { source: "search"; isMask: true; color: field.text ? root.accent : root.muted
                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    QQC2.TextField {
                        id: field
                        Layout.fillWidth: true
                        background: null
                        color: root.text
                        placeholderText: "Spotlight Search"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 22
                        selectByMouse: true
                        Keys.onEscapePressed: root.close()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onTabPressed: list.nextGroup()
                        Keys.onReturnPressed: (e) => list.runCurrent(e)
                        Keys.onEnterPressed: (e) => list.runCurrent(e)
                    }
                    Text { visible: results.querying; text: "…"; color: root.muted; font.pixelSize: 18 }
                }
                Rectangle { anchors { top: bar.bottom; left: parent.left; right: parent.right } height: 1
                            color: Qt.rgba(1, 1, 1, 0.08) }

                // ---- tips while empty
                ColumnLayout {
                    visible: !field.text
                    anchors { top: bar.bottom; left: parent.left; right: parent.right; topMargin: 14; leftMargin: 22; rightMargin: 22 }
                    spacing: 6
                    component Tip: RowLayout {
                        property string k
                        property string v
                        spacing: 12
                        Text { text: parent.k; color: root.accent; font.family: root.mono; font.pixelSize: 12; Layout.preferredWidth: 150 }
                        Text { text: parent.v; color: root.muted; font.pixelSize: 12 }
                    }
                    Tip { k: "firefox"; v: "apps, open windows, settings pages" }
                    Tip { k: "= 1250 * 1.18"; v: "calculator" }
                    Tip { k: "10 km in miles"; v: "units and currencies" }
                    Tip { k: "gg: frost kde"; v: "web search  (dd: duckduckgo, yt: youtube)" }
                }
                Text {
                    visible: field.text.length > 0 && list.count === 0 && !results.querying
                    anchors { top: bar.bottom; left: parent.left; topMargin: 12; leftMargin: 22 }
                    text: "No results"; color: root.muted; font.pixelSize: 13
                }

                // ---- results
                ListView {
                    id: list
                    anchors { top: bar.bottom; left: parent.left; right: parent.right; topMargin: 7; leftMargin: 8; rightMargin: 8 }
                    height: Math.min(contentHeight, root.maxRows * root.rowH)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    keyNavigationWraps: true
                    currentIndex: 0
                    cacheBuffer: 2000          // keep every result instantiated, for Tab between groups
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

                    model: Milou.ResultsModel {
                        id: results
                        queryString: field.text
                        limit: 24
                        onQueryStringChanged: list.currentIndex = 0
                        onModelReset: list.currentIndex = 0
                        onQueryStringChangeRequested: (q, pos) => { field.text = q; field.cursorPosition = pos }
                    }

                    section.property: "category"
                    section.criteria: ViewSection.FullString
                    section.delegate: Item {
                        required property string section
                        width: ListView.view.width; height: 26
                        Text { anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 4 }
                               text: parent.section.toUpperCase(); color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.6 }
                    }

                    delegate: Item {
                        id: row
                        required property int index
                        required property var model
                        readonly property bool current: ListView.isCurrentItem
                        width: ListView.view.width; height: root.rowH
                        Rectangle {
                            anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
                            radius: 12
                            color: row.current ? Qt.rgba(242/255, 29/255, 67/255, 0.22) : (rm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            Rectangle { visible: row.current; width: 3; height: parent.height - 16; radius: 1.5; color: root.accent
                                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } }
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 14 }
                            spacing: 12
                            Kirigami.Icon { source: row.model.decoration; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { text: row.model.display || ""; color: root.text; font.pixelSize: 15; elide: Text.ElideRight; Layout.fillWidth: true
                                       textFormat: Text.PlainText }
                                Text { text: row.model.subtext || ""; visible: text.length > 0; color: root.muted; font.pixelSize: 11
                                       elide: Text.ElideMiddle; Layout.fillWidth: true; textFormat: Text.PlainText }
                            }
                            Text { visible: row.current; text: "↵"; color: root.accent; font.pixelSize: 15 }
                        }
                        MouseArea {
                            id: rm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { list.currentIndex = row.index; list.runCurrent(null) }
                        }
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
            }
        }
    }
}
