import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_focusMinutes: f.value
    property alias cfg_breakMinutes: b.value
    property alias cfg_longBreakMinutes: lb.value
    property alias cfg_dndDuringFocus: dnd.checked
    QQC2.SpinBox { id: f; from: 5; to: 120; Kirigami.FormData.label: "Focus (minutes):" }
    QQC2.SpinBox { id: b; from: 1; to: 30; Kirigami.FormData.label: "Short break (minutes):" }
    QQC2.SpinBox { id: lb; from: 5; to: 60; Kirigami.FormData.label: "Long break, every 4th (minutes):" }
    QQC2.CheckBox { id: dnd; text: "Turn on Do Not Disturb while focusing" }
}
