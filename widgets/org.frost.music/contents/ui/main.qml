// Music: appears only while something is playing (and for 30 s after you
// pause, so you can resume). Shows the track's artwork (for videos too: only
// the thumbnail, never the video), a blurred artwork glow behind the glass,
// live beat bars, a seekable progress bar and shuffle / previous / play-pause /
// next / repeat. Works with Spotify, browsers and any MPRIS player.
// The beat bars come from beats.py (cava, local only); it runs only while
// this widget is showing music and stops itself when idle.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool hasTrack: !!player && (player.track || "").length > 0
    property double lastPlaying: 0
    property double now: Date.now()
    readonly property bool active: hasTrack && (playing || now - lastPlaying < 30000)
    onPlayingChanged: lastPlaying = Date.now()

    Timer { interval: 1000; repeat: true; running: true
            onTriggered: { root.now = Date.now(); if (root.playing) { root.lastPlaying = root.now; root.player.updatePosition() } } }

    // "Mozilla Firefox_firefox" (snap) -> "Firefox"
    readonly property string source: {
        const id = player ? (player.identity || "") : ""
        return id.split("_")[0].replace(/^Mozilla\s+/, "")
    }
    function clock(us) {
        const s = Math.max(0, Math.floor((us || 0) / 1000000))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    // ---- beat bars -----------------------------------------------------------
    readonly property int barCount: 28
    property var bars: Array(barCount).fill(0)
    property double lastStart: 0
    readonly property string helper: "setsid python3 '" + Qt.resolvedUrl("../code/beats.py").toString().replace("file://", "") + "' >/dev/null 2>&1 &"
    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }
    Timer {
        interval: 50; repeat: true
        running: root.playing && root.active
        onTriggered: {
            const xhr = new XMLHttpRequest()
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) { try { const v = JSON.parse(xhr.responseText); if (v.length) root.bars = v } catch (e) {} }
                else if (Date.now() - root.lastStart > 5000) { root.lastStart = Date.now(); exec.connectSource(root.helper) }
            }
            xhr.open("GET", "http://127.0.0.1:47821/"); xhr.send()
        }
        onRunningChanged: if (!running) root.bars = Array(root.barCount).fill(0)
    }

    fullRepresentation: GlassCard {
        id: card
        Layout.minimumWidth: 480; Layout.preferredWidth: 560
        Layout.minimumHeight: 256; Layout.preferredHeight: 272
        shown: root.active ? 1 : 0
        Style { id: st }

        // rounded mask shared by the artwork and the glow
        Rectangle { id: cardMask; anchors.fill: parent; radius: card.radius; visible: false; layer.enabled: true }

        Image {   // the artwork itself, used as a source only
            id: art
            visible: false
            source: root.player ? root.player.artUrl : ""
            asynchronous: true; cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(400, 400)
        }

        MultiEffect {   // blurred artwork glow behind the glass
            anchors.fill: parent
            source: art
            visible: art.status === Image.Ready
            opacity: 0.35
            autoPaddingEnabled: false        // keep the glow inside the card
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.2
            maskEnabled: true; maskSource: cardMask
        }
        Rectangle { anchors.fill: parent; radius: card.radius; color: Qt.rgba(10/255, 10/255, 14/255, 0.45) }

        component Ctl: Rectangle {
            id: c
            property string icon
            property bool on: false
            property bool big: false
            signal hit()
            Layout.preferredWidth: big ? 48 : 34; Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: big ? (ma.containsMouse ? "#ff3358" : st.accent) : (ma.containsMouse ? st.hover : "transparent")
            scale: ma.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: c.big ? 22 : 18; height: width
                isMask: true; source: c.icon
                color: c.big ? "white" : (c.on ? st.accent : st.text)
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.hit() }
        }

        RowLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 18

            // artwork (thumbnail only, also for videos)
            Item {
                Layout.preferredWidth: 176; Layout.preferredHeight: 176
                Layout.alignment: Qt.AlignVCenter
                Rectangle { id: artMask; anchors.fill: parent; radius: 22; visible: false; layer.enabled: true }
                Rectangle { anchors.fill: parent; radius: 22; color: st.faint; border.color: st.border }
                MultiEffect {
                    anchors.fill: parent
                    source: art
                    visible: art.status === Image.Ready
                    maskEnabled: true; maskSource: artMask
                }
                Kirigami.Icon {
                    anchors.centerIn: parent; width: 64; height: 64
                    visible: art.status !== Image.Ready
                    source: root.player ? (root.player.iconName || "media-default-album") : "media-default-album"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 4

                RowLayout {   // source chip
                    spacing: 6
                    Rectangle { width: 7; height: 7; radius: 3.5; color: root.playing ? st.accent : st.muted
                        SequentialAnimation on opacity { running: root.playing; loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
                    Text { text: (root.playing ? "NOW PLAYING" : "PAUSED") + (root.source ? "  ·  " + root.source.toUpperCase() : "")
                           color: st.muted; font.pixelSize: 10; font.letterSpacing: 1.5 }
                }
                Text { text: root.player ? root.player.track : ""; color: st.text; font.pixelSize: 20; elide: Text.ElideRight; Layout.fillWidth: true; Layout.topMargin: 2 }
                Text { text: root.player ? root.player.artist : ""; color: st.text; opacity: 0.8; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: text.length > 0; text: root.player ? (root.player.album || "") : ""; color: st.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }

                // beat bars: rounded cylinders, red at the base fading to white
                Row {
                    id: beats
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.minimumHeight: 40
                    spacing: 3
                    readonly property real barW: (width - spacing * (root.barCount - 1)) / root.barCount
                    Repeater {
                        model: root.barCount
                        Item {
                            width: beats.barW; height: beats.height
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(width, parent.height * Math.min(100, root.bars[index] || 0) / 100)
                                radius: width / 2
                                gradient: Gradient {
                                    GradientStop { position: 0; color: st.fill }
                                    GradientStop { position: 1; color: "#F21D43" }
                                }
                                opacity: root.playing ? 0.95 : 0.35
                                Behavior on height { NumberAnimation { duration: 70 } }
                            }
                        }
                    }
                }

                // progress
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: root.clock(root.player ? root.player.position : 0); color: st.muted; font.family: st.mono; font.pixelSize: 10 }
                    Rectangle {
                        Layout.fillWidth: true; height: 4; radius: 2; color: st.hover
                        readonly property real ratio: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                        Rectangle { width: parent.width * Math.min(1, parent.ratio); height: parent.height; radius: 2; color: st.accent }
                        MouseArea {
                            anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
                            enabled: !!root.player && root.player.canSeek
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (e) => root.player.position = e.x / width * root.player.length
                        }
                    }
                    Text { text: root.clock(root.player ? root.player.length : 0); color: st.muted; font.family: st.mono; font.pixelSize: 10 }
                }

                // controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14
                    Ctl { icon: "media-playlist-shuffle"; on: !!root.player && root.player.shuffle; onHit: root.player.shuffle = !root.player.shuffle }
                    Ctl { icon: "media-skip-backward"; onHit: root.player.Previous() }
                    Ctl { icon: root.playing ? "media-playback-pause" : "media-playback-start"; big: true; onHit: root.player.PlayPause() }
                    Ctl { icon: "media-skip-forward"; onHit: root.player.Next() }
                    Ctl {
                        icon: root.player && root.player.loopStatus === Mpris.LoopStatus.Track ? "media-playlist-repeat-song" : "media-playlist-repeat"
                        on: !!root.player && root.player.loopStatus !== Mpris.LoopStatus.None
                        onHit: root.player.loopStatus = root.player.loopStatus === Mpris.LoopStatus.None ? Mpris.LoopStatus.Playlist
                                                     : root.player.loopStatus === Mpris.LoopStatus.Playlist ? Mpris.LoopStatus.Track : Mpris.LoopStatus.None
                    }
                }
            }
        }
    }
}
