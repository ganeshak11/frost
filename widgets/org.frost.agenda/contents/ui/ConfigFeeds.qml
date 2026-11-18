import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    property alias cfg_feeds: feeds.text
    property alias cfg_reminders: reminders.checked
    spacing: Kirigami.Units.smallSpacing
    QQC2.Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "Calendar feeds (iCal / .ics links), one per line:  link  #colour  Name  +Word +Word\n" +
              "All but the link are optional. #colour (like #facc15) colours its events; Name shows on its reminders; " +
              "+Words keep only events whose title contains one of them (e.g. +Race +Qualifying). " +
              "Feeds whose link contains \"holiday\" are shown as holidays.\n" +
              "For your Google Calendar: Google Calendar settings → your calendar → \"Secret address in iCal format\". Keep that link private."
    }
    QQC2.CheckBox {
        id: reminders
        text: "Reminders (10 minutes before and at the start of timed events, 9:00 for all-day ones)"
    }
    QQC2.TextArea { id: feeds; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 140; wrapMode: TextEdit.WrapAnywhere }
}
