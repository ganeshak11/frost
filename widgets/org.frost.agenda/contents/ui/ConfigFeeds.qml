import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    property alias cfg_feeds: feeds.text
    spacing: Kirigami.Units.smallSpacing
    QQC2.Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "Calendar feeds (iCal / .ics links), one per line. Feeds whose link contains \"holiday\" are shown as holidays.\n" +
              "For your Google Calendar: Google Calendar settings → your calendar → \"Secret address in iCal format\". Keep that link private."
    }
    QQC2.TextArea { id: feeds; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 140; wrapMode: TextEdit.WrapAnywhere }
}
