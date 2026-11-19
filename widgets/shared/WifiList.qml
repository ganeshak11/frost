// Wi-Fi networks, for the Control Centre and Quick Controls: the connected one
// first, then by signal. Click a network to connect (click the connected one to
// disconnect); a new secured network asks for its password inline.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM

ColumnLayout {
    id: wl
    property int maxRows: 6
    readonly property int rowH: 40
    property string askFor: ""          // the network waiting for a password
    spacing: 4
    Style { id: st }

    PlasmaNM.Handler { id: handler }
    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.NetworkModel { id: netModel }
    PlasmaNM.MobileProxyModel { id: proxy; sourceModel: netModel }

    // scan while the list is on screen
    Timer { running: wl.visible && enabled.wirelessEnabled; interval: 15000; repeat: true; triggeredOnStart: true
            onTriggered: handler.requestScan() }

    function open(m) {
        if (m.ConnectionState === PlasmaNM.Enums.Activated) { handler.deactivateConnection(m.ConnectionPath, m.DevicePath); return }
        if (m.Uuid) handler.activateConnection(m.ConnectionPath, m.DevicePath, m.SpecificPath)
        else if (m.SecurityType === PlasmaNM.Enums.NoneSecurity || m.SecurityType === PlasmaNM.Enums.OWE)
            handler.addAndActivateConnection(m.DevicePath, m.SpecificPath)
        else { askFor = m.ItemUniqueName; return }
        askFor = ""
    }

    ListView {
        id: lv
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, wl.maxRows * wl.rowH)
        visible: enabled.wirelessEnabled
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: proxy
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

        delegate: Item {
            id: row
            required property var model
            readonly property bool active: model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property bool busy: model.ConnectionState === PlasmaNM.Enums.Activating
            readonly property bool secured: model.SecurityType > PlasmaNM.Enums.NoneSecurity && model.SecurityType !== PlasmaNM.Enums.OWE
            readonly property bool asking: wl.askFor !== "" && wl.askFor === model.ItemUniqueName
            width: ListView.view.width
            visible: !model.Duplicate
            height: visible ? wl.rowH + (asking ? 42 : 0) : 0

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: wl.rowH - 2
                radius: 10
                color: row.active ? st.accentSoft : (rm.containsMouse ? st.hover : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 10
                    Kirigami.Icon { source: row.model.ConnectionIcon; isMask: true; color: row.active ? st.accent : st.text
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                    Text { text: row.model.Name; color: st.text; font.pixelSize: 13; font.weight: row.active ? Font.DemiBold : Font.Normal
                           elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                    Text { visible: row.busy || (wl.width > 320 && (row.active || !!row.model.Uuid))
                           text: row.busy ? "Connecting…" : row.active ? "Connected" : "Saved"
                           color: row.active ? st.accent : st.muted; font.pixelSize: 11 }
                    Kirigami.Icon { visible: row.secured; source: "object-locked"; isMask: true; color: st.muted
                                    Layout.preferredWidth: 12; Layout.preferredHeight: 12 }
                    Text { text: row.model.Signal + "%"; color: st.muted; font.pixelSize: 10; font.family: st.mono
                           Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: wl.open(row.model) }
            }
            RowLayout {   // password for a new secured network
                visible: row.asking
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 4; bottomMargin: 4 }
                height: 34
                spacing: 6
                QQC2.TextField {
                    id: pw
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Password for " + row.model.Name
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.38)
                    color: st.text
                    background: Rectangle { radius: 9; color: Qt.rgba(0, 0, 0, 0.28); border.color: pw.activeFocus ? st.accent : st.border }
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                    onAccepted: if (text) { handler.addAndActivateConnection(row.model.DevicePath, row.model.SpecificPath, text); wl.askFor = "" }
                    Keys.onEscapePressed: wl.askFor = ""
                }
                Rectangle {
                    Layout.preferredWidth: 72; Layout.preferredHeight: 32
                    radius: 9; color: pw.text ? st.accent : st.faint
                    Text { anchors.centerIn: parent; text: "Join"; color: pw.text ? st.textOnAccent : st.muted; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pw.accepted() }
                }
            }
        }
    }
    Text {
        visible: !enabled.wirelessEnabled || lv.count === 0
        Layout.fillWidth: true
        Layout.topMargin: 6; Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: !enabled.wirelessEnabled ? "Wi-Fi is off" : "Looking for networks…"
        color: st.muted; font.pixelSize: 12
    }
}
