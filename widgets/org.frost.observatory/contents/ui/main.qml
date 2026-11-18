// System Observatory: live CPU, memory, GPU and disk, plus a 60-second
// network graph. Data comes from KDE's ksystemstats service (the same one
// System Monitor uses), so nothing here runs shell commands or polls /proc.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property int rate: 1500
    Sensors.Sensor { id: cpu;     sensorId: "cpu/all/usage";               updateRateLimit: root.rate }
    Sensors.Sensor { id: cpuTemp; sensorId: "cpu/all/averageTemperature";  updateRateLimit: root.rate }
    Sensors.Sensor { id: memUsed; sensorId: "memory/physical/used";        updateRateLimit: root.rate }
    Sensors.Sensor { id: memTot;  sensorId: "memory/physical/total";       updateRateLimit: 60000 }
    Sensors.Sensor { id: gpu;     sensorId: "gpu/all/usage";               updateRateLimit: root.rate }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu1/temperature";        updateRateLimit: root.rate }
    Sensors.Sensor { id: dRead;   sensorId: "disk/all/read";               updateRateLimit: root.rate }
    Sensors.Sensor { id: dWrite;  sensorId: "disk/all/write";              updateRateLimit: root.rate }
    Sensors.Sensor { id: dUsed;   sensorId: "disk/all/usedPercent";        updateRateLimit: 60000 }
    Sensors.Sensor { id: down;    sensorId: "network/all/download";        updateRateLimit: 1000 }
    Sensors.Sensor { id: up;      sensorId: "network/all/upload";          updateRateLimit: 1000 }
    Sensors.Sensor { id: totDown; sensorId: "network/all/totalDownload";   updateRateLimit: 5000 }
    Sensors.Sensor { id: totUp;   sensorId: "network/all/totalUpload";     updateRateLimit: 5000 }

    function bytes(v, perSec) {
        const u = ["B", "KiB", "MiB", "GiB", "TiB"]; let i = 0; v = Number(v) || 0
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (i === 0 ? v.toFixed(0) : v.toFixed(v < 10 ? 1 : 0)) + " " + u[i] + (perSec ? "/s" : "")
    }
    function compact(v) {   // 48K, 1.2M: short enough for the metric header
        const u = ["B", "K", "M", "G"]; let i = 0
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (i === 0 || v >= 10 ? v.toFixed(0) : v.toFixed(1)) + u[i]
    }
    function deg(v) { return (Number(v) || 0) > 0 ? Math.round(v) + "°C" : "" }
    function openMonitor(page) { exec.connectSource("plasma-systemmonitor --page-name " + page) }

    // 60 seconds of network history
    signal tick()
    property var downHist: []
    property var upHist: []
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.downHist = root.downHist.concat([Number(down.value) || 0]).slice(-60)
            root.upHist = root.upHist.concat([Number(up.value) || 0]).slice(-60)
            root.tick()
        }
    }

    // only used to open System Monitor on click
    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }

    fullRepresentation: GlassCard {
        Layout.minimumWidth: 600; Layout.preferredWidth: 640
        Layout.minimumHeight: 192; Layout.preferredHeight: 208
        Style { id: st }

        ColumnLayout {
            anchors { fill: parent; margins: st.pad }
            spacing: 10

            Text { text: "SYSTEM OBSERVATORY"; color: st.muted; font.pixelSize: 11; font.letterSpacing: 2.5 }

            GridLayout {
                Layout.fillWidth: true
                columns: 4; columnSpacing: 14
                Metric {
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    iconName: "cpu"; label: "CPU"
                    value: Math.round(cpu.value || 0) + "%"; detail: root.deg(cpuTemp.value)
                    ratio: (cpu.value || 0) / 100
                    onClicked: root.openMonitor("Processes")
                }
                Metric {
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    iconName: "memory"; label: "RAM"
                    value: root.bytes(memUsed.value).replace(" GiB", "G"); detail: "/" + Math.round((memTot.value || 0) / 1073741824) + "G"
                    ratio: memTot.value > 0 ? memUsed.value / memTot.value : 0
                    onClicked: root.openMonitor("Processes")
                }
                Metric {
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    iconName: "video-display"; label: "GPU"
                    value: Math.round(gpu.value || 0) + "%"; detail: root.deg(gpuTemp.value)
                    ratio: (gpu.value || 0) / 100
                    onClicked: root.openMonitor("Overview")
                }
                Metric {
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    iconName: "drive-harddisk"; label: "DISK"
                    value: Math.round(dUsed.value || 0) + "%"
                    detail: root.compact((Number(dRead.value) || 0) + (Number(dWrite.value) || 0)) + "/s"
                    ratio: (dUsed.value || 0) / 100; warnAt: 0.9
                    onClicked: root.openMonitor("Overview")
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: st.faint }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { width: 8; height: 8; radius: 4; color: st.accent }
                Text { text: "↓ " + root.bytes(down.value, true); color: st.text; font.family: st.mono; font.pixelSize: 12 }
                Rectangle { width: 8; height: 8; radius: 4; color: st.text; opacity: 0.7 }
                Text { text: "↑ " + root.bytes(up.value, true); color: st.text; font.family: st.mono; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text { text: "Σ " + root.bytes(totDown.value) + " / " + root.bytes(totUp.value); color: st.muted; font.family: st.mono; font.pixelSize: 10 }
            }

            Canvas {
                id: graph
                Connections { target: root; function onTick() { graph.requestPaint() } }
                Connections { target: st; function onLightChanged() { graph.requestPaint() } }
                Layout.fillWidth: true
                Layout.fillHeight: true
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const all = root.downHist.concat(root.upHist)
                    const max = Math.max(1024, ...all) * 1.15
                    const step = width / 59
                    function line(h, color, fill) {
                        if (h.length < 2) return
                        const off = 60 - h.length
                        ctx.beginPath()
                        for (let i = 0; i < h.length; i++) {
                            const x = (off + i) * step, y = height - h[i] / max * height
                            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.stroke()
                        if (fill) {
                            ctx.lineTo((off + h.length - 1) * step, height); ctx.lineTo(off * step, height); ctx.closePath()
                            ctx.fillStyle = fill; ctx.fill()
                        }
                    }
                    line(root.upHist, st.light ? "rgba(29,29,34,0.55)" : "rgba(242,242,245,0.55)", null)
                    line(root.downHist, "#F21D43", "rgba(242,29,67,0.15)")
                }
            }
        }
    }
}
