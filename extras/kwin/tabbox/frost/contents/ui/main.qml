/*
 Frost window switcher (Alt+Tab): large live thumbnails on a black glass card,
 the selected window outlined in Frost red with its title underneath, the app
 icon on each thumbnail. Arrow keys, mouse click and the close button (×)
 work as in Plasma's thumbnail grid, which this is based on.

 SPDX-FileCopyrightText: 2020 Chris Holland <zrenfire@gmail.com>
 SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
 SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin as KWin
import org.kde.kirigami as Kirigami

KWin.TabBoxSwitcher {
    id: tabBox

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            visible: true
            backgroundHints: PlasmaCore.Dialog.NoBackground
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + tabBox.screenGeometry.width * 0.5 - dialogMainItem.width * 0.5
            y: tabBox.screenGeometry.y + tabBox.screenGeometry.height * 0.5 - dialogMainItem.height * 0.5

            mainItem: FocusScope {
                id: dialogMainItem
                focus: true

                readonly property int pad: 22
                readonly property real screenFactor: tabBox.screenGeometry.width / tabBox.screenGeometry.height
                readonly property int maxCols: Math.max(1, Math.floor((tabBox.screenGeometry.width * 0.9 - 2 * pad) / grid.cellWidth))
                readonly property int cols: Math.max(1, Math.min(grid.count, maxCols))
                readonly property int rows: Math.ceil(grid.count / cols)
                width: Math.max(grid.cellWidth, cols * grid.cellWidth) + 2 * pad
                height: Math.min(Math.max(grid.cellHeight, rows * grid.cellHeight), tabBox.screenGeometry.height * 0.75) + 2 * pad

                Rectangle {   // the glass card
                    anchors.fill: parent
                    radius: 26
                    color: Qt.rgba(10/255, 10/255, 13/255, 0.94)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                }

                GridView {
                    id: grid
                    anchors { fill: parent; margins: dialogMainItem.pad }
                    clip: true
                    focus: true
                    model: tabBox.model
                    currentIndex: tabBox.currentIndex
                    keyNavigationWraps: true
                    highlightMoveDuration: 0

                    readonly property int thumbW: 300
                    readonly property int thumbH: Math.round(thumbW / dialogMainItem.screenFactor)
                    cellWidth: thumbW + 28
                    cellHeight: thumbH + 64

                    delegate: MouseArea {
                        id: cell
                        width: grid.cellWidth; height: grid.cellHeight
                        hoverEnabled: true
                        readonly property bool sel: GridView.isCurrentItem
                        onClicked: tabBox.model.activate(index)

                        Rectangle {   // frame: red when selected
                            id: frame
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                            width: grid.thumbW + 12; height: grid.thumbH + 12
                            radius: 16
                            color: cell.sel ? Qt.rgba(242/255, 29/255, 67/255, 0.16) : (cell.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.width: cell.sel ? 2 : 1
                            border.color: cell.sel ? "#F21D43" : Qt.rgba(1, 1, 1, 0.08)
                            scale: cell.sel ? 1.0 : 0.94
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            Item {   // WindowThumbnail needs a container
                                anchors { fill: parent; margins: 6 }
                                KWin.WindowThumbnail { anchors.fill: parent; wId: windowId }
                            }
                            Rectangle {   // app icon badge
                                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 12 }
                                width: 42; height: 42; radius: 12
                                color: Qt.rgba(10/255, 10/255, 13/255, 0.85)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                Kirigami.Icon { anchors.centerIn: parent; width: 30; height: 30; source: model.icon }
                            }
                            Rectangle {   // close
                                visible: model.closeable && typeof tabBox.model.close !== "undefined" && (cell.containsMouse || cell.sel)
                                anchors { right: parent.right; top: parent.top; margins: 10 }
                                width: 26; height: 26; radius: 13
                                color: xm.containsMouse ? "#F21D43" : Qt.rgba(10/255, 10/255, 13/255, 0.85)
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                Kirigami.Icon { anchors.centerIn: parent; width: 14; height: 14; source: "window-close-symbolic"; isMask: true; color: "white" }
                                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; onClicked: tabBox.model.close(index) }
                            }
                        }
                        Text {
                            anchors { top: frame.bottom; topMargin: 10; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
                            text: model.caption
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: cell.sel ? "#F2F2F5" : "#9A9AA6"
                            font.pixelSize: cell.sel ? 14 : 12
                        }
                    }
                    onCurrentIndexChanged: tabBox.currentIndex = grid.currentIndex
                }

                Text {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    text: "No open windows"; color: "#9A9AA6"; font.pixelSize: 14
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft()
                    else if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight()
                    else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp()
                    else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown()
                    else return
                    grid.currentIndexChanged(grid.currentIndex)
                }
            }

            onSceneGraphError: () => {}   // stay quiet on a graphics reset (as upstream)
        }
    }
}
