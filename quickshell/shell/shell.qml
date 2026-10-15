
//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    property string networkStatus: "Checking..."
    property string networkConnection: ""

    // Network status tracker
    Process {
        id: networkStatusProcess

        command: [
            "nmcli", "-t", "-f",
            "DEVICE,TYPE,STATE,CONNECTION",
            "device"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const ethernet = lines.find(line => line.startsWith("enp4s0:"))
                const wifi = lines.find(line => line.startsWith("wlp10s0f3u1i2:"))

                if (ethernet && ethernet.split(":")[2] === "connected") {
                    networkStatus = "Ethernet"
                    networkConnection = ethernet.split(":")[3] || "Connected"
                } else if (wifi && wifi.split(":")[2] === "connected") {
                    networkStatus = "Wi-Fi"
                    networkConnection = wifi.split(":")[3] || "Connected"
                } else {
                    networkStatus = "Disconnected"
                    networkConnection = ""
                }
            }
        }

        Component.onCompleted: running = true
        onExited: running = true
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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            // Moonforge application launcher
            Rectangle {
                implicitWidth: 38
                implicitHeight: 30
                radius: 8

                color: launcherMouse.containsMouse
                    ? "#45475a" : "#313244"

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

                    onClicked: Quickshell.execDetached([
                        "fuzzel",
                        "--config",
                        "/home/WhiteFox/.config/moonforge/fuzzel.ini"
                    ])
                }
            }

            // Workspace indicators
            RowLayout {
                spacing: 5

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        required property int index

                        readonly property bool isActive:
                            Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === index + 1

                        implicitWidth: 34
                        implicitHeight: 30
                        radius: 8

                        color: isActive ? "#89b4fa"
                            : workspaceMouse.containsMouse
                                ? "#45475a" : "#313244"

                        Behavior on color {
                            ColorAnimation { duration: 120 }
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

                            onClicked: Quickshell.execDetached([
                                "hyprctl",
                                "dispatch",
                                "workspace",
                                String(index + 1)
                            ])
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

                property bool audioPopupOpen: false

                implicitWidth: audioLabel.implicitWidth + 42
                implicitHeight: 30
                radius: 8

                color: audioMouse.containsMouse ? "#45475a" : "#313244"
                border.width: 1
                border.color: "#45475a"

                Row {
                    anchors.centerIn: parent
                    spacing: 7

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

                                    onWheel: event => {
                                        const audio = Pipewire.defaultAudioSink
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
                    spacing: 7

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
                        const pos = audioCapsule.mapToItem(
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
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: clockText.implicitWidth + 24
                implicitHeight: 30

                radius: 8
                color: "#313244"
                border.width: 1
                border.color: "#45475a"

                Text {
                    id: clockText
                    anchors.centerIn: parent

                    color: "#cdd6f4"
                    font.pixelSize: 13
                    text: Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
                }
            }

            // Update the clock every second
            Timer {
                interval: 1000
                running: true
                repeat: true

                onTriggered: clockText.text =
                    Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
            }
        }
        
        // Centered focused window title
        Rectangle {
            id: windowTitleCapsule

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(420, Math.max(180, titleText.implicitWidth + 24))
            height: 30

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
