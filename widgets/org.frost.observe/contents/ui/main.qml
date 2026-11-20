// Fortis Observe: today's traffic on ganeshangadi.online, from the Fortis
// Observe dashboard's read-only /api/widget/summary (set the address and
// WIDGET_TOKEN in the widget settings). People and visits today with the
// change against the same part of yesterday, a 24-hour strip (humans red,
// bots white), the site's uptime check and the latest page views.
// Refreshes every minute; click to open the dashboard.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property var summary: null  // not "data": every Item already has a data property
    property string status: "Loading…"

    // for testing on its own:
    //   plasmawindowed org.frost.observe frost-api:<url> frost-token:<token> [frost-shot:/path.png]
    function arg(prefix) {
        const a = Qt.application.arguments.find(x => x.startsWith(prefix))
        return a ? a.slice(prefix.length) : ""
    }
    readonly property string baseUrl: (arg("frost-api:") || Plasmoid.configuration.url || "").replace(/\/+$/, "")
    readonly property string token: arg("frost-token:") || Plasmoid.configuration.token || ""

    function refresh() {
        if (!baseUrl || !token) { status = "Add the dashboard token in the settings"; return }
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try { root.summary = JSON.parse(xhr.responseText); root.status = ""; timer.interval = 60000 }
                catch (e) { root.status = "Bad data" }
            } else {
                root.status = xhr.status === 401 ? "Token rejected"
                            : xhr.status === 503 ? "Token not set on the dashboard"
                            : (root.summary ? "" : "Offline")
                timer.interval = 2 * 60000
            }
        }
        xhr.open("GET", baseUrl + "/api/widget/summary")
        xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.send()
    }
    Timer { id: timer; interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    // new address or token in the settings: try straight away
    Timer { id: configChanged; interval: 800; onTriggered: root.refresh() }
    Connections {
        target: Plasmoid.configuration
        function onUrlChanged() { configChanged.restart() }
        function onTokenChanged() { configChanged.restart() }
    }
    Timer {
        interval: 3500; running: Qt.application.name === "plasmawindowed" && root.arg("frost-shot:") !== ""
        onTriggered: root.fullRepresentationItem.grabToImage(r => { r.saveToFile(root.arg("frost-shot:")); Qt.quit() })
    }

    function change(now, before) {
        if (before === undefined || before === null) return ""
        const d = now - before
        return d === 0 ? "= yesterday" : (d > 0 ? "▲ " : "▼ ") + Math.abs(d) + " vs yesterday"
    }
    function hourLabel(h) { return h === 0 ? "12a" : h === 12 ? "12p" : h < 12 ? h + "a" : (h - 12) + "p" }
    function clock(iso) {
        const d = new Date(iso)
        return Qt.formatTime(d, "HH:mm")
    }

    fullRepresentation: GlassCard {
        id: card
        Layout.minimumWidth: 400; Layout.preferredWidth: 440
        Layout.minimumHeight: 300; Layout.preferredHeight: 316
        Style { id: st }

        readonly property var today: root.summary ? root.summary.today : null
        readonly property var yest: root.summary ? root.summary.yesterday : null
        readonly property var hours: root.summary ? root.summary.hours : []
        readonly property int peak: Math.max(1, ...hours.map(h => h.human + h.bot))

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(root.baseUrl || "https://analytics.ganeshangadi.online")
        }

        ColumnLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 10

            // header: caption + site status
            RowLayout {
                Layout.fillWidth: true
                Text { text: "FORTIS OBSERVE"; color: st.muted; font.pixelSize: 11; font.letterSpacing: 2.5 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    visible: !!root.summary
                    color: !root.summary ? st.subtle
                         : root.summary.site.state === "up" ? "#34C759"
                         : root.summary.site.state === "down" ? st.accent : st.subtle
                }
                Text {
                    text: root.status || (root.summary ? root.summary.site.label : "")
                    color: root.status ? st.accent : st.muted
                    font.family: st.mono; font.pixelSize: 10
                }
            }

            // people today, big; visits and page views beside
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                ColumnLayout {
                    spacing: 0
                    RowLayout {
                        spacing: 8
                        Text { text: card.today ? card.today.visitors : "–"; color: st.text; font.family: st.mono; font.pixelSize: 38 }
                        Text { text: "people today"; color: st.muted; font.pixelSize: 12; Layout.alignment: Qt.AlignBaseline }
                    }
                    Text {
                        readonly property string c: card.today && card.yest ? root.change(card.today.visitors, card.yest.visitors) : ""
                        text: c; visible: c !== ""
                        color: c.startsWith("▲") ? st.accent : st.muted
                        font.family: st.mono; font.pixelSize: 10
                    }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [["VISITS", card.today ? card.today.visits : "–"], ["VIEWS", card.today ? card.today.pageViews : "–"], ["BOTS", card.today ? card.today.botEvents : "–"]]
                    ColumnLayout {
                        spacing: 2
                        Text { text: modelData[0]; color: st.muted; font.pixelSize: 10; font.letterSpacing: 1.5 }
                        Text { text: modelData[1]; color: st.text; font.family: st.mono; font.pixelSize: 17 }
                    }
                }
            }

            // 24-hour strip: humans red at the bottom, bots white on top
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Row {
                    id: strip
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: labels.top; bottomMargin: 4 }
                    spacing: 3
                    readonly property real cell: (width - 23 * spacing) / 24
                    Repeater {
                        model: card.hours
                        Item {
                            width: strip.cell; height: strip.height
                            readonly property bool now: index === card.hours.length - 1
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: st.faint }
                            Rectangle {
                                id: humanBar
                                anchors.bottom: parent.bottom; width: parent.width; radius: Math.min(2, width / 2)
                                height: modelData.human > 0 ? Math.max(2, modelData.human / card.peak * parent.height) : 0
                                color: st.accent; opacity: parent.now ? 1 : 0.7
                            }
                            Rectangle {
                                anchors.bottom: humanBar.top; width: parent.width; radius: Math.min(2, width / 2)
                                height: modelData.bot > 0 ? Math.max(2, modelData.bot / card.peak * parent.height) : 0
                                color: st.fill; opacity: parent.now ? 0.95 : 0.5
                            }
                        }
                    }
                }
                Item {
                    id: labels
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 10
                    Repeater {
                        model: card.hours
                        Text {
                            visible: modelData.hour % 6 === 0
                            x: index * (strip.cell + strip.spacing)
                            text: root.hourLabel(modelData.hour)
                            color: st.muted; font.family: st.mono; font.pixelSize: 9
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: st.faint }

            // latest page views
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5
                Repeater {
                    model: root.summary ? root.summary.recent.slice(0, 4) : []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: root.clock(modelData.time); color: st.muted; font.family: st.mono; font.pixelSize: 11 }
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 15; radius: 7.5
                            color: modelData.bot ? st.accentSoft : "transparent"
                            border.width: 1; border.color: modelData.bot ? st.accent : st.border
                            Text {
                                anchors.centerIn: parent
                                text: modelData.bot ? "bot" : "in"
                                color: modelData.bot ? st.accent : st.text
                                font.family: st.mono; font.pixelSize: 9
                            }
                        }
                        Text {
                            text: modelData.path
                            color: st.text; font.family: st.mono; font.pixelSize: 11
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.city || modelData.country || ""
                            color: st.muted; font.pixelSize: 11
                            elide: Text.ElideRight; Layout.maximumWidth: 110
                        }
                    }
                }
                Text {
                    visible: !!root.summary && root.summary.recent.length === 0
                    text: "No page views yet."
                    color: st.muted; font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
