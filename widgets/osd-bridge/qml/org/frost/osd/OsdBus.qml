// Carries Plasma's on-screen displays to the Dynamic Island. Both run in
// plasmashell's shared QML engine, so they see the same singleton.
pragma Singleton
import QtQuick

QtObject {
    // value: 0..maxValue for a level (volume, brightness), -1 for a text OSD
    signal shown(string icon, int value, int maxValue, string text)
}
