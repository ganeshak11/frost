// Paired Bluetooth devices, for the Control Centre and Quick Controls: the
// connected ones first. Click a device to connect, click it again to disconnect.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt

ColumnLayout {
    id: bl
    property int maxRows: 6
    readonly property int rowH: 40
    readonly property bool on: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    property var pending: ({})          // address -> true while connecting / disconnecting
    spacing: 4
    Style { id: st }

    // re-sort when a device connects, disconnects or is paired
    property int tick: 0
    Connections { target: BluezQt.Manager; function onDeviceChanged() { bl.tick++ } }
    // paired devices, connected first, then by name
    readonly property var devices: {
        tick
        const out = []
        for (const d of BluezQt.Manager.devices) if (d.paired) out.push(d)
        return out.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    }
    function toggle(d) {
        const p = Object.assign({}, pending); p[d.address] = true; pending = p
        const done = () => { const q = Object.assign({}, bl.pending); delete q[d.address]; bl.pending = q }
        const call = d.connected ? d.disconnectFromDevice() : d.connectToDevice()
        if (call) call.finished.connect(done); else done()
    }

    ListView {
        id: lv
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, bl.maxRows * bl.rowH)
        visible: bl.on
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: bl.devices
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool busy: !!bl.pending[modelData.address]
            width: ListView.view.width
            height: bl.rowH - 2
            radius: 10
            color: modelData.connected ? st.accentSoft : (rm.containsMouse ? st.hover : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 10
                Kirigami.Icon { source: row.modelData.icon || "bluetooth"; isMask: true; color: row.modelData.connected ? st.accent : st.text
                                Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                Text { text: row.modelData.name; color: st.text; font.pixelSize: 13
                       font.weight: row.modelData.connected ? Font.DemiBold : Font.Normal
                       elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                Text {
                    readonly property int battery: row.modelData.battery ? row.modelData.battery.percentage : -1
                    visible: battery >= 0 && row.modelData.connected
                    text: battery + "%"; color: st.muted; font.pixelSize: 10; font.family: st.mono
                }
                Text { text: row.busy ? (row.modelData.connected ? "Disconnecting…" : "Connecting…") : row.modelData.connected ? "Connected" : ""
                       visible: text.length > 0
                       color: row.modelData.connected && !row.busy ? st.accent : st.muted; font.pixelSize: 11 }
            }
            MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: !row.busy; onClicked: bl.toggle(row.modelData) }
        }
    }
    Text {
        visible: !bl.on || lv.count === 0
        Layout.fillWidth: true
        Layout.topMargin: 6; Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: !bl.on ? "Bluetooth is off" : "No paired devices"
        color: st.muted; font.pixelSize: 12
    }
}
