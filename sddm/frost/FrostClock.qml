// Frost login clock: date above a large time. Based on Breeze's Clock (LGPL-2.0-or-later).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: 0
    PlasmaComponents3.Label {
        text: Qt.formatDate(timeSource.dateTime, "dddd, d MMMM")
        color: "white"; opacity: 0.9
        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.9)
        font.weight: Font.Medium
        Layout.alignment: Qt.AlignHCenter
    }
    PlasmaComponents3.Label {
        text: (timeSource.dateTime.getHours() % 12 || 12) + Qt.formatTime(timeSource.dateTime, ":mm")
        color: "white"
        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 10)
        font.weight: Font.DemiBold
        font.letterSpacing: -2
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -Kirigami.Units.gridUnit
    }
    PlasmaClock.Clock { id: timeSource; trackSeconds: false }
}
