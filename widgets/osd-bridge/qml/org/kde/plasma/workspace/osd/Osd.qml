// Frost: stands in for Plasma's on-screen display (volume, brightness, mute,
// microphone, keyboard layout...) inside plasmashell only, and hands each one
// to the Dynamic Island instead of showing a pop-up. Loaded through
// QML_IMPORT_PATH set for plasmashell's service (see widgets/install-widgets.sh);
// without it Plasma shows its own OSD as usual.
import QtQuick
import org.frost.osd

QtObject {
    // what plasmashell sets before showing an OSD
    property int timeout: 1800
    property var osdValue
    property int osdMaxValue: 100
    property string osdAdditionalText
    property string icon
    property bool showingProgress: false
    property bool visible: false

    function forward() {
        if (!visible) return
        if (showingProgress) OsdBus.shown(icon, Math.round(Number(osdValue) || 0), osdMaxValue || 100, osdAdditionalText)
        else OsdBus.shown(icon, -1, 0, String(osdValue || osdAdditionalText || ""))
    }
    onVisibleChanged: forward()
    // repeated key presses update the values while it's still "visible"
    onOsdValueChanged: forward()
    onIconChanged: forward()
}
