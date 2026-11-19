// Shortcut Sheet: a glass cheat sheet of every Frost and desktop shortcut.
// Meta+/ opens it (or type ? in Spotlight); Esc, the same key or a click
// elsewhere closes it. The keys are read live from KDE's shortcut settings
// (contents/code/keys.py) each time it opens, so they're always the real ones.
// The widget itself is a 1 px item in the top panel.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    activationTogglesExpanded: false
    Style { id: st }

    // ---- open / close (the shortcut fires both activated() and expanded)
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
    function open() {
        exec.connectSource(cmd)
        win.visible = true
        win.requestActivate()
        sheet.forceActiveFocus()
    }
    function close() { win.visible = false }

    fullRepresentation: Item {
        Layout.preferredWidth: 1; Layout.minimumWidth: 1; Layout.maximumWidth: 1
        Layout.preferredHeight: 1
    }

    // ---- the shortcuts
    property var groups: []
    readonly property string cmd: "python3 '" + Qt.resolvedUrl("../code/keys.py").toString().replace("file://", "") + "'"
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (src, data) => {
            if (src === root.cmd) { try { root.groups = JSON.parse(data["stdout"]) } catch (e) {} }
            disconnectSource(src)
        }
    }
    Component.onCompleted: exec.connectSource(cmd)
    // the groups in three columns of about the same height
    readonly property var columns: {
        const cols = [[], [], []], h = [0, 0, 0]
        for (const g of groups) {
            const i = h.indexOf(Math.min(...h))
            cols[i].push(g); h[i] += g.items.length + 2
        }
        return cols
    }
    // key names as they're printed on keycaps
    function cap(k) {
        return ({ Shift: "⇧", Enter: "↵", Return: "↵", Left: "←", Right: "→", Up: "↑", Down: "↓",
                  Tab: "⇥", Backspace: "⌫", Space: "Space" })[k] || k
    }
    function caps(combo) {
        // "Meta++" would be Meta and the + key
        const parts = combo.endsWith("++") ? combo.slice(0, -2).split("+").concat(["+"]) : combo.split("+")
        return parts.filter(p => p.length).map(cap)
    }

    // for testing on its own: `plasmawindowed org.frost.shortcuts frost-test [frost-shot:/path.png]`
    Timer {
        interval: 1500; running: Qt.application.name === "plasmawindowed"
        onTriggered: {
            const args = Qt.application.arguments
            if (!args.includes("frost-test")) return
            root.ready = true; root.open()
            if (args.find(x => x.startsWith("frost-shot:"))) shotTimer.start()
        }
    }
    Timer {
        id: shotTimer; interval: 2500
        onTriggered: sheet.grabToImage(r => { r.saveToFile(Qt.application.arguments.find(x => x.startsWith("frost-shot:")).slice(11)); Qt.quit() })
    }

    readonly property rect scr: Plasmoid.containment && Plasmoid.containment.screenGeometry.width > 0
                                ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, Screen.width || 1920, Screen.height || 1080)

    component Keycap: Rectangle {
        property string label
        implicitWidth: Math.max(24, kt.implicitWidth + 14); implicitHeight: 24
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.10)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        Rectangle {   // a little depth along the bottom edge
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 3; rightMargin: 3 }
            height: 1; color: Qt.rgba(0, 0, 0, 0.45)
        }
        Text { id: kt; anchors.centerIn: parent; anchors.verticalCenterOffset: -0.5; text: parent.label
               color: st.text; font.family: st.mono; font.pixelSize: 11 }
    }

    PlasmaCore.Dialog {
        id: win
        visible: false
        type: PlasmaCore.Dialog.Normal
        backgroundHints: PlasmaCore.Dialog.StandardBackground      // the Frost glass frame, blurred by KWin
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        x: root.scr.x + root.scr.width / 2 - width / 2
        y: root.scr.y + Math.max(60, root.scr.height / 2 - height / 2 - 30)

        mainItem: FocusScope {
            id: sheet
            width: 860
            height: body.implicitHeight
            Keys.onEscapePressed: root.close()
            Keys.onPressed: (e) => { if (e.key === Qt.Key_Slash || e.key === Qt.Key_Question) { root.close(); e.accepted = true } }

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6; Layout.rightMargin: 6; Layout.topMargin: 4
                    Text { text: "Shortcuts"; color: st.text; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Text { text: "Esc to close"; color: st.muted; font.pixelSize: 11 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: root.columns
                        ColumnLayout {
                            id: col
                            required property var modelData
                            Layout.preferredWidth: (sheet.width - 24) / 3
                            Layout.maximumWidth: (sheet.width - 24) / 3
                            Layout.alignment: Qt.AlignTop
                            spacing: 12
                            Repeater {
                                model: col.modelData
                                Rectangle {   // a group, as a glass module
                                    id: grp
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: gcol.implicitHeight + 24
                                    radius: 18
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.06)
                                    ColumnLayout {
                                        id: gcol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 14; rightMargin: 12 }
                                        spacing: 6
                                        Text { text: grp.modelData.group.toUpperCase(); color: st.accent; font.pixelSize: 10
                                               font.letterSpacing: 1.6; font.weight: Font.DemiBold; Layout.bottomMargin: 2 }
                                        Repeater {
                                            model: grp.modelData.items
                                            RowLayout {
                                                id: item
                                                required property var modelData
                                                Layout.fillWidth: true
                                                spacing: 4
                                                Text { text: item.modelData.label; color: st.text; font.pixelSize: 12
                                                       elide: Text.ElideRight; Layout.fillWidth: true; Layout.rightMargin: 6 }
                                                Repeater {
                                                    model: item.modelData.keys
                                                    RowLayout {
                                                        id: combo
                                                        required property var modelData
                                                        required property int index
                                                        spacing: 3
                                                        Text { visible: combo.index > 0; text: "or"; color: st.muted; font.pixelSize: 10
                                                               Layout.leftMargin: 2; Layout.rightMargin: 2 }
                                                        Repeater {
                                                            model: root.caps(combo.modelData)
                                                            Keycap { required property var modelData; label: modelData }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
