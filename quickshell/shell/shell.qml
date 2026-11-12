
//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

ShellRoot {
    id: shellRoot

    property string networkStatus: "Checking..."
    property string networkConnection: ""
    property string currentUsername: Quickshell.env("USER") || "User"
    property string sessionUptime: "--"
    property int unreadNotifications: 0
    property int nextNotificationId: 1
    property var notificationGroups: []

    // Session uptime tracker.
    Process {
        id: uptimeProcess
        command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime"]

        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = Math.floor(parseFloat(text.trim()))
                if (isNaN(seconds))
                    return

                const days = Math.floor(seconds / 86400)
                const hours = Math.floor((seconds % 86400) / 3600)
                const minutes = Math.floor((seconds % 3600) / 60)

                const parts = []

                if (days > 0)
                    parts.push(`${days} ${days === 1 ? "day" : "days"}`)

                if (hours > 0)
                    parts.push(`${hours} ${hours === 1 ? "hour" : "hours"}`)

                if (minutes > 0 || parts.length === 0)
                    parts.push(`${minutes} ${minutes === 1 ? "minute" : "minutes"}`)

                shellRoot.sessionUptime = parts.join(" ")
            }
        }
    }

    // Hyprlock process.
    Process {
        id: lockProcess
        command: ["hyprlock"]
    }

    // Suspend process.
    Process {
        id: suspendProcess
        command: ["systemctl", "suspend"]
    }

    // Reboot process.
    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
    }

    // Power off process.
    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
    }

    // Update the uptime every 10 seconds, and also immediately on startup.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeProcess.running = true
    }

    // Network status tracker.
    Process {
        id: networkStatusProcess

        command: [
            "nmcli", "-t", "-f",
            "DEVICE,TYPE,STATE,CONNECTION",
            "device"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const devices = text.trim().split("\n")
                    .filter(line => line.length > 0)
                    .map(line => line.split(":"))

                // Detect any connected Ethernet or Wi-Fi device by type,
                // rather than relying on machine-specific interface names.
                const ethernet = devices.find(fields =>
                    fields[1] === "ethernet" && fields[2] === "connected"
                )
                const wifi = devices.find(fields =>
                    fields[1] === "wifi" && fields[2] === "connected"
                )

                if (ethernet) {
                    networkStatus = "Ethernet"
                    networkConnection = ethernet.slice(3).join(":") || "Connected"
                } else if (wifi) {
                    networkStatus = "Wi-Fi"
                    networkConnection = wifi.slice(3).join(":") || "Connected"
                } else {
                    networkStatus = "Disconnected"
                    networkConnection = ""
                }
            }
        }

        Component.onCompleted: running = true
        onExited: running = true
    }

    //// Functions ////
        // Resolve the icon path for a given application name
        function resolveAppIcon(appName) {
            if (!appName)
                return ""

            const entry = DesktopEntries.heuristicLookup(appName)

            if (entry && entry.icon)
                return Quickshell.iconPath(entry.icon, true)

            return Quickshell.iconPath(
                appName.toLowerCase(),
                true
            )
        }

        // Add a notification to the notification center and popup
        function addNotification(notification) {
            const appName = notification.appName || "Unknown"
            const appIcon = resolveAppIcon(appName)

            const newNotification = {
                id: nextNotificationId++,
                summary: notification.summary || "",
                body: notification.body || "",
                receivedAt: Qt.formatTime(new Date(), "hh:mm")
            }

            // Copy the outer array so QML detects the change.
            let groups = notificationGroups.slice()
            let groupIndex = groups.findIndex(
                group => group.appName === appName
            )

            if (groupIndex === -1) {
                groups.unshift({
                    appName: appName,
                    appIcon: appIcon,
                    expanded: true,
                    notifications: [newNotification]
                })
            } else {
                let group = Object.assign({}, groups[groupIndex])
                group.notifications = group.notifications.slice()
                group.notifications.unshift(newNotification)
                group.appIcon = group.appIcon || appIcon

                // Move the updated app stack to the top.
                groups.splice(groupIndex, 1)
                groups.unshift(group)
            }

            // Enforce the 50-notification limit across all groups.
            let total = groups.reduce(
                (count, group) => count + group.notifications.length,
                0
            )

            while (total > 50) {
                const lastGroup = groups[groups.length - 1]
                lastGroup.notifications.pop()
                total--

                if (lastGroup.notifications.length === 0)
                    groups.pop()
            }

            notificationGroups = groups
        }

        // Remove by stable notification ID instead of a delegate index.
        // This remains safe if another notification arrives during the exit animation.
        function removeNotificationById(appName, notificationId) {
            let groups = notificationGroups.slice()
            const groupIndex = groups.findIndex(group => group.appName === appName)

            if (groupIndex === -1)
                return

            let group = Object.assign({}, groups[groupIndex])
            group.notifications = group.notifications.slice()

            const notificationIndex = group.notifications.findIndex(
                notification => notification.id === notificationId
            )

            if (notificationIndex === -1)
                return

            group.notifications.splice(notificationIndex, 1)

            if (group.notifications.length === 0) {
                groups.splice(groupIndex, 1)
            } else {
                groups[groupIndex] = group
            }

            notificationGroups = groups

            // Dismissing a history item also clears one unread notification.
            unreadNotifications = Math.max(0, unreadNotifications - 1)
        }

        // Toggle the expanded/collapsed state of a notification group
        function toggleNotificationGroup(groupIndex) {
            let groups = notificationGroups.slice()
            let group = Object.assign({}, groups[groupIndex])

            group.expanded = !group.expanded
            groups[groupIndex] = group

            notificationGroups = groups
        }

        // Remove an entire notification group from the notification center
        function removeNotificationGroup(groupIndex) {
            let groups = notificationGroups.slice()
            groups.splice(groupIndex, 1)
            notificationGroups = groups
        }

        // Clear every saved notification group and reset the unread indicator.
        function clearNotificationHistory() {
            notificationGroups = []
            unreadNotifications = 0
        }
    //////////////////

    // Notification center popup
    PopupWindow {
        id: notificationCenterPopup

        anchor.window: barWindow
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right

        Connections {
            target: notificationCenterPopup.anchor

            function onAnchoring() {
                const pos = notificationCenterButton.mapToItem(
                    barWindow.contentItem, 0, 0
                )

                notificationCenterPopup.anchor.rect.x = pos.x
                notificationCenterPopup.anchor.rect.y = barWindow.height
                notificationCenterPopup.anchor.rect.width =
                    notificationCenterButton.width
                notificationCenterPopup.anchor.rect.height =
                    notificationCenterButton.height
            }
        }

        implicitWidth: 360
        implicitHeight: 420

        visible: false
        color: "transparent"
        grabFocus: true

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#1e1e2e"
            border.width: 1
            border.color: "#45475a"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notifications"
                        color: "#cdd6f4"
                        font.pixelSize: 18
                        font.bold: true

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Clear all"
                        color: "#89b4fa"
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor

                            onClicked: clearNotificationHistory()
                        }
                    }
                }

                // Divider line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#45475a"
                }

                // Notification history
                ListView {
                    id: notificationHistoryList

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    model: notificationGroups
                    spacing: 10
                    clip: true

                    delegate: Rectangle {
                        id: notificationGroupDelegate

                        required property int index
                        required property var modelData

                        property int stackIndex: index
                        property string stackAppName: modelData.appName

                        width: notificationHistoryList.width
                        height: groupContent.implicitHeight + 20

                        radius: 9
                        color: groupHover.hovered ? "#38384d" : "#313244"
                        border.width: 1
                        border.color: groupHover.hovered ? "#585875" : "#45475a"

                        HoverHandler {
                            id: groupHover
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            id: groupContent

                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // Application stack header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Application icon
                                Image {
                                    source: modelData.appIcon
                                    sourceSize.width: 22
                                    sourceSize.height: 22
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                // Application name
                                Text {
                                    text: modelData.appName
                                    color: "#89b4fa"
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                // Notification count for the application stack
                                Text {
                                    text: modelData.notifications.length
                                    color: "#cdd6f4"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Remove notification group button
                                Text {
                                    text: "×"
                                    color: "#f38ba8"
                                    font.pixelSize: 20
                                    font.bold: true
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: removeNotificationGroup(stackIndex)
                                    }
                                }

                                // Expand/collapse arrow for the application stack
                                Text {
                                    id: groupArrow

                                    text: "⌄"
                                    color: "#cba6f7"
                                    font.pixelSize: 19

                                    rotation: modelData.expanded ? 0 : -90

                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                    Behavior on rotation {
                                        SpringAnimation {
                                            spring: 3.2
                                            damping: 0.28
                                            mass: 1.0
                                            epsilon: 0.01
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: toggleNotificationGroup(stackIndex)
                                    }
                                }

                            }

                            // Notification items for the application stack
                            Item {
                                id: notificationsArea

                                Layout.fillWidth: true
                                Layout.minimumHeight: 0
                                clip: true

                                // Keep the cards alive while collapsed. A spring controls
                                // the stack height while a short fade runs alongside it.
                                property real revealProgress: modelData.expanded ? 1 : 0

                                implicitHeight: notificationItems.implicitHeight
                                Layout.preferredHeight: implicitHeight * revealProgress
                                opacity: revealProgress

                                Behavior on revealProgress {
                                    SpringAnimation {
                                        spring: 3.0
                                        damping: 0.32
                                        mass: 1.0
                                        epsilon: 0.01
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 170
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                ColumnLayout {
                                    id: notificationItems

                                    width: notificationsArea.width
                                    spacing: 8

                                    // One delegate per notification in this app's stack.
                                    // This inner delegate is intentionally separate from the
                                    // outer ListView delegate, which represents the app group.
                                    Repeater {
                                        model: modelData.notifications

                                        delegate: Rectangle {
                                            id: notificationHistoryCard

                                            required property int index
                                            required property var modelData

                                            property bool dismissing: false

                                            Layout.fillWidth: true
                                            Layout.minimumHeight: 0
                                            clip: true
                                            implicitHeight: dismissing ? 0 : notificationContent.implicitHeight + 12
                                            radius: 6
                                            color: cardHover.hovered ? "#343449" : "#262638"
                                            opacity: 0
                                            scale: 0.98

                                            // Cards rise and fade in with a short stagger.
                                            transform: Translate {
                                                id: cardEntranceOffset
                                                y: 8
                                            }

                                            HoverHandler {
                                                id: cardHover
                                            }

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 130
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Behavior on implicitHeight {
                                                NumberAnimation {
                                                    duration: 190
                                                    easing.type: Easing.InOutCubic
                                                }
                                            }

                                            SequentialAnimation {
                                                id: cardEntrance

                                                PauseAnimation {
                                                    duration: Math.min(notificationHistoryCard.index * 34, 204)
                                                }

                                                ParallelAnimation {
                                                    NumberAnimation {
                                                        target: notificationHistoryCard
                                                        property: "opacity"
                                                        from: 0
                                                        to: 1
                                                        duration: 190
                                                        easing.type: Easing.OutCubic
                                                    }

                                                    NumberAnimation {
                                                        target: cardEntranceOffset
                                                        property: "y"
                                                        from: 8
                                                        to: 0
                                                        duration: 230
                                                        easing.type: Easing.OutCubic
                                                    }

                                                    NumberAnimation {
                                                        target: notificationHistoryCard
                                                        property: "scale"
                                                        from: 0.98
                                                        to: 1
                                                        duration: 230
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }

                                            SequentialAnimation {
                                                id: cardDismiss

                                                ParallelAnimation {
                                                    NumberAnimation {
                                                        target: notificationHistoryCard
                                                        property: "opacity"
                                                        to: 0
                                                        duration: 140
                                                        easing.type: Easing.InCubic
                                                    }

                                                    NumberAnimation {
                                                        target: cardEntranceOffset
                                                        property: "y"
                                                        to: -5
                                                        duration: 180
                                                        easing.type: Easing.InCubic
                                                    }

                                                    NumberAnimation {
                                                        target: notificationHistoryCard
                                                        property: "scale"
                                                        to: 0.96
                                                        duration: 180
                                                        easing.type: Easing.InCubic
                                                    }

                                                    NumberAnimation {
                                                        target: notificationHistoryCard
                                                        property: "implicitHeight"
                                                        to: 0
                                                        duration: 190
                                                        easing.type: Easing.InOutCubic
                                                    }
                                                }

                                                // Commit the data removal only after the exit animation finishes.
                                                onFinished: {
                                                    shellRoot.removeNotificationById(
                                                        notificationGroupDelegate.stackAppName,
                                                        notificationHistoryCard.modelData.id
                                                    )
                                                }
                                            }

                                            Component.onCompleted: cardEntrance.start()

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8

                                                Rectangle {
                                                    Layout.fillHeight: true
                                                    Layout.preferredWidth: 2
                                                    radius: 2
                                                    color: "#89b4fa"
                                                }

                                                ColumnLayout {
                                                    id: notificationContent
                                                    Layout.fillWidth: true
                                                    spacing: 5

                                                    Text {
                                                        text: modelData.summary
                                                        color: "#cdd6f4"
                                                        font.bold: true
                                                        wrapMode: Text.Wrap
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        visible: modelData.body.length > 0
                                                        text: modelData.body
                                                        color: "#a6adc8"
                                                        wrapMode: Text.Wrap
                                                        Layout.fillWidth: true
                                                    }

                                                    RowLayout {
                                                        Item {
                                                            Layout.fillWidth: true
                                                        }

                                                        Text {
                                                            text: modelData.receivedAt
                                                            color: "#6c7086"
                                                            font.pixelSize: 10
                                                        }

                                                        Text {
                                                            text: "×"
                                                            color: "#f38ba8"
                                                            font.pixelSize: 16

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    if (!notificationHistoryCard.dismissing) {
                                                                        notificationHistoryCard.dismissing = true
                                                                        cardDismiss.start()
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }

                    // Display a message when there are no notifications
                    Text {
                        anchors.centerIn: parent
                        visible: notificationGroups.length === 0
                        text: "No notifications yet"
                        color: "#a6adc8"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    // Moonforge notification server
    NotificationServer {
        id: notificationServer

        keepOnReload: true


        onNotification: notification => {
            notification.tracked = true
            unreadNotifications++

            addNotification(notification)

            console.info(
                "Moonforge received:",
                notification.appName,
                "-",
                notification.summary
            )
        }
    }

    // Moonforge notification popups
    PanelWindow {
        id: notificationPopupWindow

        anchors {
            top: true
            right: true
        }

        margins {
            top: 15
            right: 16
        }

        implicitWidth: 360
        implicitHeight: notificationColumn.implicitHeight + 16

        color: "transparent"

        ColumnLayout {
            id: notificationColumn

            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Repeater {
                model: notificationServer.trackedNotifications

                delegate: Rectangle {
                    id: notificationCard

                    required property var modelData

                    opacity: 1

                    Layout.fillWidth: true
                    implicitHeight: popupContent.implicitHeight + 24

                    radius: 12
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: "#89b4fa"

                    Timer {
                        interval: 2500
                        running: true
                        repeat: false

                        onTriggered: fadeOut.start()
                    }

                    NumberAnimation {
                        id: fadeOut

                        target: notificationCard
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 350

                        onFinished: modelData.expire()
                    }

                    ColumnLayout {
                        id: popupContent

                        anchors {
                            fill: parent
                            margins: 12
                        }

                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true

                                text: modelData.appName
                                color: "#89b4fa"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "×"
                                color: "#cba6f7"
                                font.pixelSize: 20

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6

                                    onClicked: modelData.dismiss()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            text: modelData.summary
                            color: "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true

                            visible: modelData.body.length > 0
                            text: modelData.body
                            color: "#a6adc8"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    // Periodically check network status every 5 seconds
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!networkStatusProcess.running)
                networkStatusProcess.running = true
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    PanelWindow {
        id: barWindow

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 44
        color: "#1e1e2e"

        // The main bar layout: launcher, workspace indicators, audio and network capsules, and system tray.
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8

            // Moonforge application launcher button.
            Rectangle {
                implicitWidth: 38
                implicitHeight: 30
                radius: 8

                color: launcherMouse.containsMouse
                    ? "#45475a" : "#313244"

                // Match the border used by the other bar capsules.
                border.width: 1
                border.color: "#45475a"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    color: "#89b4fa"
                    font.pixelSize: 19
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: Quickshell.execDetached(["fuzzel"])
                }
            }

            // Workspace indicators
            RowLayout {
                spacing: 4

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        required property int index

                        readonly property bool isActive:
                            Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === index + 1

                        implicitWidth: isActive ? 38 : 30
                        implicitHeight: 30
                        radius: 8

                        color: isActive ? "#89b4fa"
                            : workspaceMouse.containsMouse
                                ? "#45475a" : "#313244"

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            color: isActive ? "#1e1e2e" : "#cdd6f4"
                            font.pixelSize: 13
                            font.bold: isActive
                        }

                        MouseArea {
                            id: workspaceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (Hyprland.usingLua) {
                                    Hyprland.dispatch(
                                        `hl.dsp.focus({ workspace = ${index + 1} })`
                                    )
                                } else {
                                    Hyprland.dispatch(
                                        `workspace ${index + 1}`
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Flexible space separates controls from status
            Item {
                Layout.fillWidth: true
            }

            // Moonforge Audio Capsule
            Rectangle {
                id: audioCapsule

                implicitWidth: audioLabel.implicitWidth + 42
                implicitHeight: 30
                radius: 8

                color: audioMouse.containsMouse ? "#45475a" : "#313244"
                border.width: 1
                border.color: "#45475a"

                // Audio icon and volume percentage display
                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                            ? (Pipewire.defaultAudioSink.audio.muted ? "󰝟" : "󰕾")
                            : "󰝟"
                        color: "#89b4fa"
                        font.pixelSize: 16
                    }

                    Text {
                        id: audioLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                            ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%"
                            : "--%"
                        color: "#cdd6f4"
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: audioMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: audioPopup.visible = !audioPopup.visible

                    onWheel: wheel => {
                        const audio = Pipewire.defaultAudioSink
                            ? Pipewire.defaultAudioSink.audio
                            : null

                        if (!audio)
                            return

                        const step = 0.02

                        if (wheel.angleDelta.y > 0) {
                            audio.volume = Math.min(1.0, audio.volume + step)
                        } else if (wheel.angleDelta.y < 0) {
                            audio.volume = Math.max(0.0, audio.volume - step)
                        }

                        wheel.accepted = true
                    }

                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Audio Popup
            PopupWindow {
                id: audioPopup

                color: "transparent"
                anchor.window: barWindow
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right
                Connections {
                    target: audioPopup.anchor

                    function onAnchoring() {
                        const pos = audioCapsule.mapToItem(
                            barWindow.contentItem, 0, 0
                        )

                        audioPopup.anchor.rect.x = pos.x - 20
                        audioPopup.anchor.rect.y = barWindow.height
                        audioPopup.anchor.rect.width = audioCapsule.width
                        audioPopup.anchor.rect.height = audioCapsule.height
                    }
                }

                implicitWidth: 280
                implicitHeight: 112

                visible: false
                grabFocus: true

                Rectangle {
                    anchors.fill: parent
                    color: "#1e1e2e"
                    radius: 10
                    border.width: 1
                    border.color: "#45475a"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // Audio popup header.
                        Row {
                            width: parent.width
                            height: 24
                            spacing: 8

                            Text {
                                width: parent.width - 44
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: "Output volume"
                                color: "#cdd6f4"
                                font.pixelSize: 12
                            }
                        }

                        // Master volume control row.
                        Row {
                            width: parent.width
                            spacing: 8

                            // Popup mute button
                            Rectangle {
                                id: popupMuteButton

                                width: 30
                                height: 30
                                radius: 7

                                color: popupMuteMouse.containsMouse
                                    ? "#45475a"
                                    : "#313244"

                                // Popup mute button icon
                                Text {
                                    anchors.centerIn: parent

                                    text: Pipewire.defaultAudioSink?.audio
                                        ? (Pipewire.defaultAudioSink.audio.muted
                                            ? "󰝟"
                                            : "󰕾")
                                        : "󰝟"

                                    color: "#89b4fa"
                                    font.pixelSize: 18
                                }

                                // Popup mute button click handler
                                MouseArea {
                                    id: popupMuteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        const audio = Pipewire.defaultAudioSink
                                            ? Pipewire.defaultAudioSink.audio
                                            : null

                                        if (audio)
                                            audio.muted = !audio.muted
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }
                            }

                            // Master volume slider
                            Slider {
                                id: volumeSlider

                                width: parent.width - 30 - 36 - 16
                                height: 30

                                leftPadding: 8
                                rightPadding: 8

                                from: 0.0
                                to: 1.0
                                stepSize: 0.01

                                value: Pipewire.defaultAudioSink?.audio
                                    ? Pipewire.defaultAudioSink.audio.volume
                                    : 0.0

                                // Master volume slider handle
                                handle: Rectangle {
                                    x: volumeSlider.leftPadding
                                        + volumeSlider.visualPosition
                                            * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.topPadding
                                        + volumeSlider.availableHeight / 2 - height / 2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: volumeSlider.pressed ? "#cba6f7" : "#89b4fa"
                                    border.width: 2
                                    border.color: "#cdd6f4"
                                }

                                // Master volume slider background
                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding
                                        + volumeSlider.availableHeight / 2 - height / 2
                                    width: volumeSlider.width - volumeSlider.leftPadding - volumeSlider.rightPadding
                                    height: 6
                                    radius: 3
                                    color: "#45475a"

                                    Rectangle {
                                        width: volumeSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 3
                                        color: "#89b4fa"
                                    }
                                }

                                // Update the Pipewire audio volume when the slider is moved
                                onMoved: {
                                    if (Pipewire.defaultAudioSink?.audio)
                                        Pipewire.defaultAudioSink.audio.volume = value
                                }

                                // Master volume wheel control
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                    onWheel: event => {                                        const audio = Pipewire.defaultAudioSink
                                            ? Pipewire.defaultAudioSink.audio
                                            : null

                                        if (!audio)
                                            return

                                        const step = 0.02

                                        if (event.angleDelta.y > 0) {
                                            audio.volume = Math.min(1.0, audio.volume + step)
                                        } else if (event.angleDelta.y < 0) {
                                            audio.volume = Math.max(0.0, audio.volume - step)
                                        }

                                        event.accepted = true
                                    }
                                }
                            }

                            // Master volume percentage display
                            Text {
                                width: 36
                                height: 30

                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignRight

                                text: Pipewire.defaultAudioSink?.audio
                                    ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%"
                                    : "--%"

                                color: "#89b4fa"
                                font.pixelSize: 12
                            }


                        }
                    }
                }
            }

            // Moonforge Network Capsule
            Rectangle {
                id: networkCapsule

                implicitWidth: networkLabel.implicitWidth + 42
                implicitHeight: 30
                radius: 8

                color: networkMouse.containsMouse ? "#45475a" : "#313244"
                border.width: 1
                border.color: "#45475a"

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: networkStatus === "Ethernet"
                            ? "󰈀"
                            : networkStatus === "Wi-Fi"
                                ? "󰖩"
                                : "󰖪"
                        color: "#89b4fa"
                        font.pixelSize: 16
                    }

                    Text {
                        id: networkLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: networkStatus
                        color: "#cdd6f4"
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: networkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: networkPopup.visible = !networkPopup.visible
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Popup for network status and settings
            PopupWindow {
                id: networkPopup

                anchor.window: barWindow
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right
                Connections {
                    target: networkPopup.anchor

                    function onAnchoring() {
                        const pos = networkCapsule.mapToItem(
                            barWindow.contentItem, 0, 0
                        )

                        networkPopup.anchor.rect.x = pos.x
                        networkPopup.anchor.rect.y = barWindow.height
                        networkPopup.anchor.rect.width = networkCapsule.width
                        networkPopup.anchor.rect.height = networkCapsule.height
                    }
                }

                implicitWidth: 280
                implicitHeight: 150
                visible: false
                color: "transparent"
                grabFocus: true

                Rectangle {
                    anchors.fill: parent
                    color: "#1e1e2e"
                    radius: 10
                    border.width: 1
                    border.color: "#45475a"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "Network"
                            color: "#cdd6f4"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: networkStatus === "Disconnected"
                                ? "No active connection"
                                : networkStatus + "\n" + networkConnection
                            color: "#a6adc8"
                            font.pixelSize: 12
                        }

                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 7
                            color: networkSettingsMouse.containsMouse
                                ? "#45475a"
                                : "#313244"
                            border.width: 1
                            border.color: "#45475a"

                            Text {
                                anchors.centerIn: parent
                                text: "Open Network Settings"
                                color: "#89b4fa"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: networkSettingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    networkPopup.visible = false
                                    Quickshell.execDetached(["kitty", "-e", "nmtui"])
                                }
                            }
                        }
                    }
                }
            }

            // System tray capsule
            Rectangle {
                id: systemTrayCapsule

                visible: SystemTray.items.values.length > 0

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: trayLayout.implicitWidth + 16
                implicitHeight: 30

                radius: 8
                color: "#313244"
                border.width: 1
                border.color: "#45475a"

                RowLayout {
                    id: trayLayout

                    anchors.centerIn: parent
                    spacing: 8

                    // System tray icons
                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayEntry

                            required property var modelData

                            // QsMenuOpener for the tray icon
                            QsMenuOpener {
                                id: trayMenuOpener
                                menu: trayEntry.modelData.menu
                            }

                            // Popup for the tray icon menu
                            PopupWindow {
                                id: trayPopup

                                color: "transparent"
                                anchor.window: barWindow
                                anchor.edges: Edges.Top | Edges.Left
                                anchor.gravity: Edges.Bottom | Edges.Right
                                Connections {
                                    target: trayPopup.anchor

                                    function onAnchoring() {
                                        const pos = trayEntry.mapToItem(
                                            barWindow.contentItem, 0, 0
                                        )

                                        trayPopup.anchor.rect.x = pos.x - 20
                                        trayPopup.anchor.rect.y = barWindow.height
                                        trayPopup.anchor.rect.width = trayEntry.width
                                        trayPopup.anchor.rect.height = trayEntry.height
                                    }
                                }

                                implicitWidth: 240
                                implicitHeight: menuColumn.implicitHeight + 12

                                visible: false
                                grabFocus: true

                                property int itemHeight: 34
                                property color menuBackground: "#1e1e2e"
                                property color hoverBackground: "#45475a"
                                property color accentColor: "#89b4fa"
                                property color textColor: "#cdd6f4"

                                // Tray icon menu background
                                Rectangle {
                                    id: menuBackgroundRect

                                    anchors.fill: parent
                                    color: trayPopup.menuBackground
                                    radius: 10
                                    border.width: 0
                                    clip: true

                                    Column {
                                        id: menuColumn

                                        width: parent.width - 12
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        spacing: 2

                                        Repeater {
                                            model: trayMenuOpener.children

                                            delegate: Item {
                                                id: menuEntry
                                                required property var modelData

                                                 QsMenuOpener {
                                                    id: submenuOpener
                                                    menu: menuEntry.modelData
                                                }

                                                PopupWindow {
                                                    id: submenuPopup

                                                    color: "transparent"

                                                    anchor.item: menuItemBackground
                                                    anchor.edges: Edges.Right | Edges.Top
                                                    anchor.gravity: Edges.Left | Edges.Top

                                                    implicitWidth: 240
                                                    implicitHeight: submenuColumn.implicitHeight + 12

                                                    visible: false
                                                    grabFocus: false

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: trayPopup.menuBackground
                                                        radius: 10
                                                        border.width: 0
                                                        clip: true

                                                        Column {
                                                            id: submenuColumn

                                                            width: parent.width - 12
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            anchors.top: parent.top
                                                            anchors.topMargin: 6
                                                            spacing: 2

                                                            Repeater {
                                                                model: submenuOpener.children

                                                                delegate: Item {
                                                                    id: submenuEntry

                                                                    required property var modelData

                                                                    width: submenuColumn.width
                                                                    height: modelData.isSeparator ? 9 : trayPopup.itemHeight

                                                                    Rectangle {
                                                                        visible: submenuEntry.modelData.isSeparator
                                                                        width: parent.width - 12
                                                                        height: 1
                                                                        anchors.centerIn: parent
                                                                        color: trayPopup.hoverBackground
                                                                    }

                                                                    Rectangle {
                                                                        id: submenuItemBackground

                                                                        anchors.fill: parent
                                                                        visible: !submenuEntry.modelData.isSeparator
                                                                        radius: 6
                                                                        color: submenuMouse.containsMouse
                                                                            ? trayPopup.hoverBackground
                                                                            : "transparent"

                                                                        Row {
                                                                            anchors.fill: parent
                                                                            anchors.leftMargin: 10
                                                                            anchors.rightMargin: 10
                                                                            spacing: 10

                                                                            Image {
                                                                                width: 16
                                                                                height: 16
                                                                                anchors.verticalCenter: parent.verticalCenter
                                                                                source: submenuEntry.modelData.icon
                                                                                visible: source.toString() !== ""
                                                                                fillMode: Image.PreserveAspectFit
                                                                            }

                                                                            Text {
                                                                                width: parent.width - 50
                                                                                height: parent.height
                                                                                verticalAlignment: Text.AlignVCenter
                                                                                elide: Text.ElideRight
                                                                                text: submenuEntry.modelData.text
                                                                                color: submenuEntry.modelData.enabled
                                                                                    ? trayPopup.textColor : "#6c7086"
                                                                                font.pixelSize: 12
                                                                            }

                                                                            Text {
                                                                                visible: submenuEntry.modelData.hasChildren
                                                                                anchors.verticalCenter: parent.verticalCenter
                                                                                text: "›"
                                                                                color: trayPopup.accentColor
                                                                                font.pixelSize: 18
                                                                            }
                                                                        }

                                                                        MouseArea {
                                                                            id: submenuMouse

                                                                            anchors.fill: parent
                                                                            hoverEnabled: true
                                                                            enabled: !submenuEntry.modelData.isSeparator
                                                                                && submenuEntry.modelData.enabled
                                                                                && !submenuEntry.modelData.hasChildren

                                                                            cursorShape: enabled
                                                                                ? Qt.PointingHandCursor
                                                                                : Qt.ArrowCursor

                                                                            onClicked: {
                                                                                submenuEntry.modelData.triggered()
                                                                                trayPopup.visible = false
                                                                                submenuPopup.visible = false
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }


                                                width: menuColumn.width
                                                height: modelData.isSeparator ? 9 : trayPopup.itemHeight

                                                // Separator
                                                Rectangle {
                                                    visible: menuEntry.modelData.isSeparator
                                                    width: parent.width - 12
                                                    height: 1
                                                    anchors.centerIn: parent
                                                    color: trayPopup.hoverBackground
                                                }

                                                // Regular menu entry
                                                Rectangle {
                                                    id: menuItemBackground

                                                    anchors.fill: parent
                                                    visible: !menuEntry.modelData.isSeparator
                                                    radius: 6
                                                    color: menuMouse.containsMouse
                                                        ? trayPopup.hoverBackground
                                                        : "transparent"

                                                    Row {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 10
                                                        spacing: 10

                                                        Image {
                                                            width: 16
                                                            height: 16
                                                            anchors.verticalCenter: parent.verticalCenter

                                                            source: menuEntry.modelData.icon
                                                            visible: source.toString() !== ""
                                                            fillMode: Image.PreserveAspectFit
                                                        }

                                                        Text {
                                                            width: parent.width - 50
                                                            height: parent.height

                                                            verticalAlignment: Text.AlignVCenter
                                                            elide: Text.ElideRight

                                                            text: menuEntry.modelData.text
                                                            color: menuEntry.modelData.enabled
                                                                ? trayPopup.textColor
                                                                : "#6c7086"

                                                            font.pixelSize: 12
                                                        }

                                                        Text {
                                                            visible: menuEntry.modelData.hasChildren
                                                            anchors.verticalCenter: parent.verticalCenter

                                                            text: "›"
                                                            color: trayPopup.accentColor
                                                            font.pixelSize: 18
                                                        }
                                                    }


                                                    MouseArea {
                                                        id: menuMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true

                                                        enabled: !menuEntry.modelData.isSeparator
                                                            && menuEntry.modelData.enabled

                                                        cursorShape: enabled
                                                            ? Qt.PointingHandCursor
                                                            : Qt.ArrowCursor

                                                        onEntered: {
                                                            if (menuEntry.modelData.hasChildren) {
                                                                submenuPopup.visible = true
                                                            } else {
                                                                submenuPopup.visible = false
                                                            }
                                                        }

                                                        onClicked: {
                                                            if (menuEntry.modelData.hasChildren) {
                                                                submenuPopup.visible = !submenuPopup.visible
                                                            } else {
                                                                menuEntry.modelData.triggered()
                                                                submenuPopup.visible = false
                                                                trayPopup.visible = false
                                                            }
                                                        }
                                                    }

                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            implicitWidth: 18
                            implicitHeight: 18

                            Image {
                                anchors.fill: parent

                                source: trayEntry.modelData.icon
                                sourceSize.width: 18
                                sourceSize.height: 18
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }


                            MouseArea {
                                id: trayMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                acceptedButtons: Qt.LeftButton
                                    | Qt.MiddleButton
                                    | Qt.RightButton

                                onClicked: mouse => {
                                    const item = trayEntry.modelData;

                                    if (mouse.button === Qt.LeftButton) {
                                        if (item.onlyMenu)
                                            openMenu();
                                        else
                                            item.activate();
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        item.secondaryActivate();
                                    } else if (mouse.button === Qt.RightButton) {
                                        openMenu();
                                    }
                                }

                                function openMenu() {
                                    const item = trayEntry.modelData;

                                    if (!item.hasMenu)
                                        return;

                                    trayPopup.visible = true;
                                }

                            }
                        }
                    }
                }
            }

            // Date and time display
            Rectangle {
                id: clockCapsule

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: clockText.implicitWidth + 24
                implicitHeight: 30

                radius: 8
                color: clockMouse.containsMouse ? "#45475a" : "#313244"
                border.width: 1
                border.color: "#45475a"

                Text {
                    id: clockText
                    anchors.centerIn: parent

                    color: "#cdd6f4"
                    font.pixelSize: 13
                    text: Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        clockPopup.visible = !clockPopup.visible
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Popup for date and time
            PopupWindow {
                id: clockPopup

                color: "transparent"
                anchor.window: barWindow
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right

                Connections {
                    target: clockPopup.anchor

                    function onAnchoring() {
                        const pos = clockCapsule.mapToItem(
                            barWindow.contentItem, 0, 0
                        )

                        clockPopup.anchor.rect.x = pos.x - 110
                        clockPopup.anchor.rect.y = barWindow.height
                        clockPopup.anchor.rect.width = clockCapsule.width
                        clockPopup.anchor.rect.height = clockCapsule.height
                    }
                }

                implicitWidth: 300
                implicitHeight: 370

                visible: false
                grabFocus: true

                Rectangle {
                    anchors.fill: parent
                    color: "#1e1e2e"
                    radius: 12
                    border.width: 1
                    border.color: "#45475a"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        // Date & Time header
                        Text {
                            text: "Date & Time"
                            color: "#89b4fa"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        // Current date display
                        Text {
                            text: Qt.formatDateTime(new Date(), "dddd, dd MMMM yyyy")
                            color: "#cdd6f4"
                            font.pixelSize: 14
                        }

                        // Current time display
                        Text {
                            id: popupTimeText

                            text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                            color: "#cba6f7"
                            font.pixelSize: 28
                            font.bold: true
                        }

                        // Interactive monthly calendar
                        Column {
                            id: calendarSection

                            width: parent.width
                            spacing: 9

                            // Today's date, used to highlight the current day.
                            readonly property var today: new Date()

                            // The month currently displayed in the calendar.
                            property var displayedMonth:
                                new Date(new Date().getFullYear(), new Date().getMonth(), 1)

                            // Move to the previous or next month.
                            function changeMonth(amount) {
                                displayedMonth = new Date(
                                    displayedMonth.getFullYear(),
                                    displayedMonth.getMonth() + amount,
                                    1
                                )
                            }

                            // Calendar month header and navigation.
                            RowLayout {
                                width: parent.width
                                height: 28
                                spacing: 0

                                // Previous month button.
                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 28
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "‹"
                                        color: "#cba6f7"
                                        font.pixelSize: 24
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calendarSection.changeMonth(-1)
                                    }
                                }

                                // Current month and year.
                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28

                                    text: Qt.formatDate(
                                        calendarSection.displayedMonth,
                                        "MMMM yyyy"
                                    )

                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Next month button.
                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 28
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "›"
                                        color: "#cba6f7"
                                        font.pixelSize: 24
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calendarSection.changeMonth(1)
                                    }
                                }
                            }
                        }

                        // Weekday names and calendar dates.
                        GridLayout {
                            width: parent.width
                            columns: 7
                            columnSpacing: 3
                            rowSpacing: 4

                            // Weekday names
                            Repeater {
                                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                                delegate: Text {
                                    required property var modelData

                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 20

                                    text: modelData
                                    color: "#a6adc8"
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            // Six rows of calendar dates.
                            Repeater {
                                model: 42

                                delegate: Rectangle {
                                    required property int index

                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 20

                                    radius: 7

                                    readonly property var cellDate: {
                                        const month = calendarSection.displayedMonth
                                        const firstDay = new Date(
                                            month.getFullYear(),
                                            month.getMonth(),
                                            1
                                        )

                                        // Convert Sunday-first JS weekday to Monday-first.
                                        const offset = (firstDay.getDay() + 6) % 7

                                        return new Date(
                                            month.getFullYear(),
                                            month.getMonth(),
                                            1 - offset + index
                                        )
                                    }

                                    // Check whether this date belongs to the displayed month.
                                    readonly property bool isCurrentMonth:
                                        cellDate.getMonth()
                                        === calendarSection.displayedMonth.getMonth()

                                    // Check whether this date is today.
                                    readonly property bool isToday:
                                        cellDate.getFullYear() === calendarSection.today.getFullYear()
                                        && cellDate.getMonth() === calendarSection.today.getMonth()
                                        && cellDate.getDate() === calendarSection.today.getDate()

                                    // Displays the day number.
                                    color: isToday
                                        ? "#89b4fa"
                                        : dayHoverer.hovered ? "#45475a" : "transparent"

                                    // The day number text.
                                    Text {
                                        anchors.centerIn: parent

                                        text: parent.cellDate.getDate()


                                        color: parent.isToday
                                            ? "#1e1e2e"
                                            : parent.isCurrentMonth ? "#cdd6f4" : "#585b70"

                                        font.pixelSize: 12
                                        font.bold: parent.isToday
                                        font.weight: parent.isCurrentMonth
                                            ? Font.DemiBold : Font.Normal
                                    }

                                    // Mouse area for hover effect.
                                    HoverHandler {
                                        id: dayHoverer
                                    }

                                    // Animated background color when hovering.
                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Update the clock every second
            Timer {
                interval: 1000
                running: true
                repeat: true

                onTriggered: {
                    const now = new Date()

                    // Update the clock text in the bar.
                    clockText.text = Qt.formatDateTime(now, "ddd dd MMM  hh:mm")

                    // Update the clock text in the popup.
                    popupTimeText.text = Qt.formatDateTime(now, "hh:mm:ss")
                }
            }

            // Moonforge settings popup
            PopupWindow {
                id: settingsPopup

                anchor.window: barWindow
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right

                Connections {
                    target: settingsPopup.anchor

                    function onAnchoring() {
                        const pos = settingsButton.mapToItem(
                            barWindow.contentItem, 0, 0
                        )

                        settingsPopup.anchor.rect.x = pos.x
                        settingsPopup.anchor.rect.y = barWindow.height
                        settingsPopup.anchor.rect.width = settingsButton.width
                        settingsPopup.anchor.rect.height = settingsButton.height
                    }
                }

                implicitWidth: 440
                implicitHeight: 440

                visible: false
                color: "transparent"
                grabFocus: true

                // Settings content
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: "#45475a"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        // Profile and session section
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // User avatar.
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 100
                                radius: 20
                                color: "transparent"
                                clip: true

                                Image {
                                    id: avatarImage
                                    anchors.fill: parent
                                    source: "file:///home/" + shellRoot.currentUsername + "/.config/moonforge/avatar.jpg"
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                    smooth: true
                                    visible: false
                                }

                                Rectangle {
                                    id: avatarMask
                                    anchors.fill: parent
                                    radius: 20
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: avatarImage
                                    maskSource: avatarMask
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 20
                                    color: "transparent"
                                    border.width: 2
                                    border.color: "#45475a"
                                }
                            }

                            // Welcome message and session information.
                            ColumnLayout {
                                spacing: 5

                                Text {
                                    text: shellRoot.currentUsername
                                    color: "#cdd6f4"
                                    font.pixelSize: 25
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 6

                                    Text {
                                        text: "󰣇"
                                        color: "#89b4fa"
                                        font.pixelSize: 15
                                    }

                                    Text {
                                        text: "Arch Linux · Hyprland"
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                    }
                                }

                                Text {
                                    text: "󰣇  Session: " + shellRoot.sessionUptime
                                    color: "#a6adc8"
                                    font.pixelSize: 15
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // Settings actions (e.g., logout, lock, etc.)
                            ColumnLayout {
                                spacing: 9

                                // Power menu button.
                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 21
                                    color: "#313244"
                                    border.width: 1
                                    border.color: "#45475a"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: "#f38ba8"
                                        font.pixelSize: 19
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: powerMenuPopup.visible = !powerMenuPopup.visible
                                    }
                                }

                                // Lock screen button.
                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 21
                                    color: "#313244"
                                    border.width: 1
                                    border.color: "#45475a"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰌾"
                                        color: "#89b4fa"
                                        font.pixelSize: 19
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: lockProcess.running = true
                                    }
                                }
                            }
                        }

                        // Quick Controls section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // Section divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: "#45475a"
                                opacity: 0.8
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 9

                                Repeater {
                                    model: [
                                        { icon: "󰖩", label: "Wi-Fi" },
                                        { icon: "󰂯", label: "Bluetooth" },
                                        { icon: "󰖔", label: "Night Light" },
                                        { icon: "󰂛", label: "Do Not Disturb" },
                                        { icon: "󰏘", label: "Appearance" },
                                        { icon: "󰍹", label: "Desktop" },
                                        { icon: "󰂚", label: "Notifications" },
                                        { icon: "󰕾", label: "Audio" },
                                        { icon: "󰍹", label: "Display" }
                                    ]

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        radius: 10
                                        color: "#313244"
                                        border.width: 1
                                        border.color: "#45475a"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 9
                                            spacing: 8

                                            Text {
                                                text: modelData.icon
                                                color: "#89b4fa"
                                                font.pixelSize: 17
                                            }

                                            Text {
                                                text: modelData.label
                                                color: "#cdd6f4"
                                                font.pixelSize: 12
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: "›"
                                                color: "#a6adc8"
                                                font.pixelSize: 20
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }
                }
            }

            // Power menu popup
            PopupWindow {
                id: powerMenuPopup

                anchor.window: barWindow
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right

                implicitWidth: 190
                implicitHeight: 220

                visible: false
                color: "transparent"
                grabFocus: true

                Rectangle {
                    id: powerMenuButton

                    anchors.fill: parent
                    radius: 12
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: "#45475a"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Repeater {
                            model: [
                                { icon: "󰌾", label: "Lock", color: "#89b4fa" },
                                { icon: "󰒲", label: "Suspend", color: "#cba6f7" },
                                { icon: "󰜉", label: "Reboot", color: "#89b4fa" },
                                { icon: "󰐥", label: "Shut Down", color: "#f38ba8" }
                            ]

                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                // Separator before Reboot
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: "#45475a"
                                    visible: index === 2
                                }

                                Rectangle {
                                    id: actionRow
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: 9

                                    color: actionMouse.containsMouse ? "#313244" : "transparent"
                                    scale: actionMouse.containsMouse ? 1.015 : 1.0

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Text {
                                            text: modelData.icon
                                            color: modelData.color
                                            font.pixelSize: 17
                                        }

                                        Text {
                                            text: modelData.label
                                            color: "#cdd6f4"
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: actionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            powerMenuPopup.visible = false

                                            if (modelData.label === "Lock")
                                                lockProcess.running = true
                                            else if (modelData.label === "Suspend") {
                                                lockProcess.running = true
                                                suspendProcess.running = true
                                            }
                                            else if (modelData.label === "Reboot") {
                                                powerConfirmPopup.action = "reboot"
                                                powerConfirmPopup.visible = true
                                            }
                                            else if (modelData.label === "Shut Down") {
                                                powerConfirmPopup.action = "shutdown"
                                                powerConfirmPopup.visible = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Confirmation menu for power popup
            PopupWindow {
                id: powerConfirmPopup

                anchor.window: barWindow
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right

                Connections {
                    target: powerConfirmPopup.anchor

                    function onAnchoring() {
                        const pos = powerMenuButton.mapToItem(
                            barWindow.contentItem, 0, 0
                        )

                        powerConfirmPopup.anchor.rect.x = pos.x
                        powerConfirmPopup.anchor.rect.y = barWindow.height
                        powerConfirmPopup.anchor.rect.width = powerMenuButton.width
                        powerConfirmPopup.anchor.rect.height = powerMenuButton.height
                    }
                }

                implicitWidth: 280
                implicitHeight: 150
                visible: false
                color: "transparent"
                grabFocus: true

                property string action: ""

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: "#45475a"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            text: powerConfirmPopup.action === "reboot"
                                ? "Restart Moonforge?"
                                : "Shut down Moonforge?"
                            color: "#cdd6f4"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: "Are you sure you want to continue?"
                            color: "#a6adc8"
                            font.pixelSize: 12
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item { Layout.fillWidth: true }

                            // Cancel
                            Rectangle {
                                Layout.preferredWidth: 82
                                Layout.preferredHeight: 34
                                radius: 9
                                color: cancelMouse.containsMouse ? "#45475a" : "#313244"

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: powerConfirmPopup.visible = false
                                }
                            }

                            // Confirm
                            Rectangle {
                                Layout.preferredWidth: 94
                                Layout.preferredHeight: 34
                                radius: 9
                                color: cancelMouse.containsMouse ? "#eba0ac" : "#f38ba8"

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Confirm"
                                    color: "#1e1e2e"
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: confirmMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        powerConfirmPopup.visible = false

                                        if (powerConfirmPopup.action === "reboot")
                                            rebootProcess.running = true
                                        else if (powerConfirmPopup.action === "shutdown")
                                            shutdownProcess.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Moonforge notification center button
            Rectangle {
                id: notificationCenterButton

                implicitWidth: 34
                implicitHeight: 30
                radius: 8

                color: notificationCenterMouse.containsMouse
                    ? "#45475a" : "#313244"

                border.width: 1
                border.color: "#45475a"

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: "#89b4fa"
                    font.pixelSize: 17
                }

                MouseArea {
                    id: notificationCenterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        notificationCenterPopup.visible =
                            !notificationCenterPopup.visible

                        if (notificationCenterPopup.visible) {
                            unreadNotifications = 0
                        }
                    }
                }

                // Unread notification indicator
                Rectangle {
                    id: unreadIndicator

                    visible: unreadNotifications > 0

                    width: 9
                    height: 9
                    radius: 5

                    color: "#89b4fa"

                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 3
                    anchors.rightMargin: 3

                    border.width: 1
                    border.color: "#1e1e2e"
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Moonforge settings button
            Rectangle {
                id: settingsButton

                implicitWidth: 34
                implicitHeight: 30
                radius: 8

                color: settingsMouse.containsMouse
                    ? "#45475a" : "#313244"

                border.width: 1
                border.color: "#45475a"

                Text {
                    anchors.centerIn: parent
                    text: "󰒓"
                    color: "#89b4fa"
                    font.pixelSize: 17
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        notificationCenterPopup.visible = false
                        settingsPopup.visible = !settingsPopup.visible
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }
        }

        // Centered focused window title
        Rectangle {
            id: windowTitleCapsule

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(420, Math.max(180, titleText.implicitWidth + 24))
            height: 30

            // Smoothly resize the capsule when the title changes
            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            radius: 8
            color: "#313244"
            border.width: 1
            border.color: "#45475a"

            Text {
                id: titleText

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter

                text: Hyprland.activeToplevel
                    ? Hyprland.activeToplevel.title : "Desktop"

                color: "#a6adc8"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}