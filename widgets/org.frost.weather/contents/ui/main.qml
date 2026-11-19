// Weather Intelligence: current conditions, feels-like, humidity, wind,
// today's high/low, a rain alert for the next 6 hours, and a forecast strip
// you can flip between the next hours and the next 5 days (click it).
// Data: Open-Meteo (free, no account). Only the configured city's
// coordinates are sent. Refreshes every 15 minutes.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property var wx: null
    property string status: "Loading…"
    property bool showDaily: true

    function wmo(code, night) {   // WMO weather code -> [text, icon]
        const n = night ? "-night" : ""
        if (code === 0) return ["Clear", "weather-clear" + n]
        if (code <= 2) return ["Partly cloudy", "weather-few-clouds" + n]
        if (code === 3) return ["Overcast", "weather-overcast"]
        if (code <= 48) return ["Fog", "weather-fog"]
        if (code <= 57) return ["Drizzle", "weather-showers-scattered" + n]
        if (code <= 67) return ["Rain", "weather-showers"]
        if (code <= 77) return ["Snow", "weather-snow"]
        if (code <= 82) return ["Rain showers", "weather-showers-scattered" + n]
        if (code <= 86) return ["Snow showers", "weather-snow-scattered"]
        return ["Thunderstorm", "weather-storm"]
    }

    function refresh() {
        const c = Plasmoid.configuration
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + c.latitude + "&longitude=" + c.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=5&forecast_hours=12"
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try { root.wx = JSON.parse(xhr.responseText); root.status = ""; timer.interval = 15 * 60000 }
                catch (e) { root.status = "Bad data" }
            } else {
                root.status = root.wx ? "" : "Offline"
                timer.interval = 2 * 60000
            }
        }
        xhr.open("GET", url); xhr.send()
    }
    Timer { id: timer; interval: 15 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    // a new place in the settings: fetch it now, not at the next 15-minute tick
    Timer { id: placeChanged; interval: 800; onTriggered: root.refresh() }
    Connections {
        target: Plasmoid.configuration
        function onLatitudeChanged() { placeChanged.restart() }
        function onLongitudeChanged() { placeChanged.restart() }
    }

    readonly property var cur: wx ? wx.current : null
    readonly property var now: cur ? wmo(cur.weather_code, !cur.is_day) : ["", "weather-none-available"]
    readonly property string rainAlert: {
        if (!wx) return ""
        const h = wx.hourly
        for (let i = 0; i < Math.min(6, h.time.length); i++)
            if (h.precipitation_probability[i] >= 60)
                return "Rain likely around " + Qt.formatTime(new Date(h.time[i]), "h AP") + " (" + h.precipitation_probability[i] + "%)"
        return ""
    }

    fullRepresentation: GlassCard {
        id: card
        Layout.minimumWidth: 256; Layout.preferredWidth: 272
        Layout.minimumHeight: 224; Layout.preferredHeight: 240
        Style { id: st }
        // narrow card: details go under the temperature instead of beside it
        readonly property bool compact: width < 380

        component K: Text { color: st.muted; font.pixelSize: 11 }
        component V: Text { color: st.text; font.family: st.mono; font.pixelSize: 11; Layout.alignment: Qt.AlignRight }
        component Details: GridLayout {
            columnSpacing: 10; rowSpacing: 1
            K { text: "Feels like" }  V { text: root.cur ? Math.round(root.cur.apparent_temperature) + "°" : "–" }
            K { text: "Hi / Lo" }     V { text: root.wx ? Math.round(root.wx.daily.temperature_2m_max[0]) + "°/" + Math.round(root.wx.daily.temperature_2m_min[0]) + "°" : "–" }
            K { text: "Humidity" }    V { text: root.cur ? root.cur.relative_humidity_2m + "%" : "–" }
            K { text: "Wind" }        V { text: root.cur ? Math.round(root.cur.wind_speed_10m) + " km/h" : "–" }
        }

        ColumnLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text { text: Plasmoid.configuration.city.toUpperCase(); color: st.muted; font.pixelSize: 11; font.letterSpacing: 2.5 }
                Item { Layout.fillWidth: true }
                Text { text: root.status; color: st.accent; font.pixelSize: 11; visible: text.length > 0 }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Kirigami.Icon { source: root.now[1]; Layout.preferredWidth: 52; Layout.preferredHeight: 52 }
                ColumnLayout {
                    spacing: 0
                    Text { text: root.cur ? Math.round(root.cur.temperature_2m) + "°" : "–"; color: st.text; font.family: st.mono; font.pixelSize: 38 }
                    Text { text: root.now[0]; color: st.text; font.pixelSize: 14 }
                }
                Item { Layout.fillWidth: true }
                Details { visible: !card.compact; columns: 2 }
            }
            Details { visible: card.compact; columns: 4; Layout.fillWidth: true }

            Text {
                text: root.rainAlert
                visible: text.length > 0
                color: st.accent; font.pixelSize: 11
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: st.faint }

            // forecast strip: click to flip between 5 days and the next hours
            Row {
                id: strip
                Layout.fillWidth: true
                Layout.fillHeight: true
                Repeater {
                    model: root.wx ? 5 : 0
                    ColumnLayout {
                        width: strip.width / 5
                        spacing: 1
                        readonly property var d: root.wx
                        readonly property int hi: root.showDaily ? index : index * 2 + 1   // hourly: every 2nd hour
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: st.muted; font.pixelSize: 10
                            text: root.showDaily ? (index === 0 ? "Today" : Qt.formatDate(new Date(d.daily.time[index]), "ddd"))
                                                 : Qt.formatTime(new Date(d.hourly.time[hi]), "h AP")
                        }
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            source: root.showDaily ? root.wmo(d.daily.weather_code[index], false)[1]
                                                   : root.wmo(d.hourly.weather_code[hi], !d.hourly.is_day[hi])[1]
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: st.text; font.family: st.mono; font.pixelSize: 10
                            text: root.showDaily ? Math.round(d.daily.temperature_2m_max[index]) + "°/" + Math.round(d.daily.temperature_2m_min[index]) + "°"
                                                 : Math.round(d.hourly.temperature_2m[hi]) + "°"
                        }
                    }
                }
            }
        }
        MouseArea {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 60
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showDaily = !root.showDaily
        }
    }
}
