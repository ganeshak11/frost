// Frost Dock: the app row of a Mac-style dock, built on Plasma's own task manager.
// It sits in the dock panel between the app menu (Kickoff) and the system tray
// and trash; the panel itself draws the glass bar behind all of them (Frost
// theme, south-* panel background), see desktop.sh.
//  - pinned apps and running windows (grouped per app), in your order
//  - gentle magnification under the pointer; neighbours make room. Sizes come
//    from the icons' resting positions, so nothing shifts under the pointer
//  - a dot under running apps (red for the active one), a pulsing ring when
//    an app wants attention, a small bounce while an app is starting
//  - click: open / focus; click the active app again: minimise
//  - middle-click: new window; scroll on an app: focus it
//  - right-click: New window, Keep in Dock / Remove, Minimise, Maximise, Close
//  - press and hold, then drag sideways to reorder
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property int icon: Plasmoid.configuration.iconSize
    readonly property real maxScale: Plasmoid.configuration.magnification
    readonly property int spacing: 10
    readonly property int pitch: icon + spacing          // resting distance between icon centres
    readonly property real range: icon * 2.4             // how far the magnification reaches
    readonly property int sepW: spacing * 2 + 1          // a divider at each end of the row
    // extra room the row needs at full magnification (sum of the growth of the
    // icons near the pointer), so it grows inside our own box
    readonly property real growRoom: icon * (maxScale - 1) * (range / pitch) + 8

    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        filterByActivity: true
        filterByVirtualDesktop: false
        filterByScreen: false
        activity: activityInfo.currentActivity
        virtualDesktop: desktopInfo.currentDesktop
        launcherList: Plasmoid.configuration.launchers.split(",").filter(s => s.length)
        onLauncherListChanged: {
            const joined = launcherList.join(",")
            if (joined !== Plasmoid.configuration.launchers) Plasmoid.configuration.launchers = joined
        }
    }
    function idx(i) { return tasks.makeModelIndex(i) }

    // ---- context menu (a real Plasma menu, so it isn't clipped by the panel) --
    property int menuIndex: -1
    property var menuModel: ({})
    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        PlasmaExtras.MenuItem { text: root.menuModel.AppName || root.menuModel.display || ""; enabled: false }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: "New Window"; icon: "window-new"
            onClicked: tasks.requestNewInstance(root.idx(root.menuIndex))
        }
        PlasmaExtras.MenuItem {
            readonly property bool pinned: tasks.launcherPosition(root.menuModel.LauncherUrlWithoutIcon || "") >= 0
            text: pinned ? "Remove from Dock" : "Keep in Dock"
            icon: pinned ? "window-unpin" : "window-pin"
            onClicked: pinned ? tasks.requestRemoveLauncher(root.menuModel.LauncherUrlWithoutIcon)
                              : tasks.requestAddLauncher(root.menuModel.LauncherUrlWithoutIcon)
        }
        PlasmaExtras.MenuItem {
            visible: !root.menuModel.IsLauncher
            text: root.menuModel.IsMinimized ? "Restore" : "Minimise"; icon: "window-minimize"
            onClicked: tasks.requestToggleMinimized(root.idx(root.menuIndex))
        }
        PlasmaExtras.MenuItem {
            visible: !root.menuModel.IsLauncher
            text: "Maximise"; icon: "window-maximize"
            onClicked: tasks.requestToggleMaximized(root.idx(root.menuIndex))
        }
        PlasmaExtras.MenuItem { visible: !root.menuModel.IsLauncher; separator: true }
        PlasmaExtras.MenuItem {
            visible: !root.menuModel.IsLauncher
            text: (root.menuModel.ChildCount || 0) > 1 ? "Close All Windows" : "Close"; icon: "window-close"
            onClicked: tasks.requestClose(root.idx(root.menuIndex))
        }
    }

    fullRepresentation: Item {
        id: dock
        // Fixed size: magnified icons grow into the spare room at both ends and
        // upwards out of the bar, so the panel never resizes under the pointer.
        Layout.preferredWidth: tasks.count * root.pitch + 2 * root.sepW + root.growRoom
        Layout.minimumWidth: Layout.preferredWidth
        Layout.preferredHeight: root.icon
        Style { id: st }

        // left edge of the row at rest; magnification is computed from these
        // resting positions only (no feedback from the magnified layout)
        readonly property real restLeft: (width - tasks.count * root.pitch) / 2
        property real mx: -1e6                         // pointer x, or far away when outside
        Item {   // tracks the pointer, including over the magnified icons above the bar
            anchors { fill: parent; topMargin: -root.icon * (root.maxScale - 1) - 6 }
            HoverHandler {
                onPointChanged: dock.mx = point.position.x
                onHoveredChanged: if (!hovered) dock.mx = -1e6
            }
        }
        function scaleOf(i) {
            const d = Math.abs(dock.mx - (restLeft + (i + 0.5) * root.pitch))
            if (d >= root.range) return 1
            const t = 1 - d / root.range
            return 1 + (root.maxScale - 1) * (t * t * (3 - 2 * t))     // smoothstep falloff
        }

        Rectangle {   // divider after the app menu
            anchors { left: parent.left; leftMargin: root.spacing; verticalCenter: parent.verticalCenter }
            width: 1; height: root.icon * 0.7; color: st.border
        }
        Rectangle {   // divider before the tray
            anchors { right: parent.right; rightMargin: root.spacing; verticalCenter: parent.verticalCenter }
            width: 1; height: root.icon * 0.7; color: st.border
        }

        // a single dock item; `s` is its magnification
        component DockIcon: Item {
            id: di
            property var source
            property real s: 1
            property bool bounce: false
            property bool attention: false
            property int dots: 0             // 0 = not running
            property bool activeApp: false
            property string tip
            signal leftClick()
            signal middleClick()
            signal rightClick()
            signal wheel(int delta)
            signal holdStart()
            signal holdMove(real rowX)
            signal holdEnd()
            property bool holding: false
            width: root.icon * s + root.spacing
            height: root.icon * s
            Behavior on s { enabled: dock.dragging === null; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Kirigami.Icon {
                id: ic
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: root.icon * di.s; height: width
                source: di.source
                active: ma.containsMouse
                transform: Translate { id: lift }
                SequentialAnimation {
                    running: di.bounce; loops: Animation.Infinite
                    NumberAnimation { target: lift; property: "y"; to: -root.icon * 0.22; duration: 300; easing.type: Easing.OutQuad }
                    NumberAnimation { target: lift; property: "y"; to: 0; duration: 300; easing.type: Easing.InQuad }
                    PauseAnimation { duration: 250 }
                    onRunningChanged: if (!running) lift.y = 0
                }
            }
            Rectangle {   // wants attention
                anchors.centerIn: ic
                width: ic.width + 8; height: width; radius: width / 2
                color: "transparent"; border.color: st.accent; border.width: 2
                visible: di.attention
                SequentialAnimation on opacity { running: di.attention; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
            }
            Row {         // running dots
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 3 }
                spacing: 3
                Repeater {
                    model: Math.min(3, di.dots)
                    Rectangle { width: 4; height: 4; radius: 2; color: di.activeApp ? st.accent : st.text; opacity: di.activeApp ? 1 : 0.75 }
                }
            }
            PlasmaCore.ToolTipArea {
                anchors.fill: ic
                mainText: di.tip
                location: PlasmaCore.Types.BottomEdge
                interactive: false
            }
            MouseArea {
                id: ma
                anchors.fill: ic
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                pressAndHoldInterval: 350
                onClicked: (e) => {
                    if (di.holding) return
                    e.button === Qt.MiddleButton ? di.middleClick() : e.button === Qt.RightButton ? di.rightClick() : di.leftClick()
                }
                onWheel: (w) => di.wheel(w.angleDelta.y)
                onPressAndHold: (e) => { if (e.button === Qt.LeftButton) { di.holding = true; di.holdStart() } }
                onPositionChanged: (e) => { if (di.holding) di.holdMove(mapToItem(row, e.x, e.y).x) }
                onReleased: { if (di.holding) { di.holdEnd(); Qt.callLater(() => di.holding = false) } }
            }
        }

        property var dragging: null      // the task delegate being dragged
        Row {
            id: row
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            spacing: 0

            Repeater {
                id: taskRepeater
                model: tasks
                DockIcon {
                    id: task
                    required property int index
                    required property var model
                    s: dock.scaleOf(index)
                    source: model.decoration
                    tip: model.AppName || model.display
                    bounce: model.IsStartup === true
                    attention: model.IsDemandingAttention === true
                    dots: model.IsLauncher ? 0 : Math.max(1, model.ChildCount || 1)
                    activeApp: model.IsActive === true
                    z: dock.dragging === task ? 10 : 0
                    opacity: dock.dragging === task ? 0.85 : 1

                    onLeftClick: {
                        if (model.IsLauncher || model.IsStartup) tasks.requestActivate(root.idx(index))
                        else if (model.IsActive && (model.ChildCount || 0) <= 1) tasks.requestToggleMinimized(root.idx(index))
                        else tasks.requestActivate(root.idx(index))
                    }
                    onMiddleClick: tasks.requestNewInstance(root.idx(index))
                    onRightClick: { root.menuIndex = index; root.menuModel = model; menu.visualParent = task; menu.openRelative() }
                    onWheel: (d) => tasks.requestActivate(root.idx(index))

                    // press and hold, then drag sideways to reorder
                    onHoldStart: dock.dragging = task
                    onHoldMove: (gx) => {
                        for (let i = 0; i < taskRepeater.count; i++) {
                            const it = taskRepeater.itemAt(i)
                            if (it && it !== task && gx > it.x && gx < it.x + it.width) { tasks.move(task.index, i); break }
                        }
                    }
                    onHoldEnd: { dock.dragging = null; tasks.syncLaunchers() }
                }
            }
        }
    }
}
