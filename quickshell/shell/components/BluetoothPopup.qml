
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
    id: bluetoothPopup

    property bool bluetoothEnabled: false
    property string bluetoothAction: ""
    property var bluetoothDevices: []
    property var connectedBluetoothDevices: []
    property bool bluetoothScanning: false
    property var discoveredBluetoothDevices: []

    // Check Bluetooth adapter status.
    Process {
        id: bluetoothStatusProcess
        command: ["bluetoothctl", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (line.trim().startsWith("Powered:")) {
                        bluetoothPopup.bluetoothEnabled =
                            line.trim().endsWith("yes")
                        break
                    }
                }
            }
        }
    }

    // Enable or disable Bluetooth.
    Process {
        id: bluetoothPowerProcess
        command: [
            "bluetoothctl",
            "power",
            bluetoothPopup.bluetoothAction
        ]

        onExited: (exitCode, exitStatus) => {
            bluetoothStatusProcess.running = true
        }
    }

    // Retrieve paired Bluetooth devices.
    Process {
        id: bluetoothDevicesProcess
        command: ["bluetoothctl", "devices", "Paired"]

        stdout: StdioCollector {
            onStreamFinished: {
                const devices = []

                for (const line of text.trim().split("\n")) {
                    const match = line.match(/^Device\s+([0-9A-F:]+)\s+(.+)$/)

                    if (match) {
                        devices.push({
                            mac: match[1],
                            name: match[2]
                        })
                    }
                }

                bluetoothPopup.bluetoothDevices = devices
            }
        }
    }

    // Retrieve currently connected Bluetooth devices.
    Process {
        id: bluetoothConnectedProcess
        command: ["bluetoothctl", "devices", "Connected"]

        stdout: StdioCollector {
            onStreamFinished: {
                const connected = []

                for (const line of text.trim().split("\n")) {
                    const match = line.match(/^Device\s+([0-9A-F:]+)/)

                    if (match)
                        connected.push(match[1])
                }

                bluetoothPopup.connectedBluetoothDevices = connected
            }
        }
    }

    // Connect / Disconnect functionality.
    Process {
        id: bluetoothDeviceActionProcess

        property string action: ""
        property string deviceMac: ""

        command: ["bluetoothctl", action, deviceMac]

        onExited: (exitCode, exitStatus) => {
            bluetoothConnectedProcess.running = true
        }
    }

    // Forget action to remove devices.
    Process {
        id: bluetoothForgetProcess

        property string deviceMac: ""

        command: ["bluetoothctl", "remove", deviceMac]

        onExited: (exitCode, exitStatus) => {
            bluetoothDevicesProcess.running = true
            bluetoothConnectedProcess.running = true
        }
    }

    // Scan for nearby Bluetooth devices.
    Process {
        id: bluetoothScanProcess
        command: ["bluetoothctl", "--timeout", "10", "scan", "on"]

        onStarted: {
            bluetoothPopup.bluetoothScanning = true
            bluetoothPopup.discoveredBluetoothDevices = []
        }

        onExited: (exitCode, exitStatus) => {
            bluetoothPopup.bluetoothScanning = false
            bluetoothDiscoveredProcess.running = true
        }
    }

    // Retrieve discovered devices.
    Process {
        id: bluetoothDiscoveredProcess
        command: ["bluetoothctl", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                const devices = []

                for (const line of text.trim().split("\n")) {
                    const match = line.match(/^Device\s+([0-9A-F:]+)\s+(.+)$/)

                    if (match) {
                        const alreadyPaired = bluetoothPopup.bluetoothDevices
                            .some(device => device.mac === match[1])

                        if (!alreadyPaired) {
                            devices.push({
                                mac: match[1],
                                name: match[2]
                            })
                        }
                    }
                }

                bluetoothPopup.discoveredBluetoothDevices = devices
            }
        }
    }

    // Pair a discovered Bluetooth device.
    Process {
        id: bluetoothPairProcess

        property string deviceMac: ""

        command: ["bluetoothctl", "pair", deviceMac]

        onExited: (exitCode, exitStatus) => {
            bluetoothDevicesProcess.running = true
            bluetoothConnectedProcess.running = true
            bluetoothDiscoveredProcess.running = true
        }
    }

    // Refresh status while the popup is open.
    Timer {
        interval: 5000
        running: bluetoothPopup.visible
        repeat: true

        onTriggered: bluetoothStatusProcess.running = true
    }

    onVisibleChanged: {
        if (visible)
            bluetoothStatusProcess.running = true
            bluetoothDevicesProcess.running = true
            bluetoothConnectedProcess.running = true
    }

    implicitWidth: 360
    implicitHeight: 480

    visible: false
    color: "transparent"
    grabFocus: true

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#1e1e2e"
        border.width: 1
        border.color: "#45475a"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Bluetooth"
                    color: "#cdd6f4"
                    font.pixelSize: 18
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "󰂯"
                    color: "#89b4fa"
                    font.pixelSize: 20
                }
            }

            // Bluetooth power control
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.minimumHeight: 64
                Layout.maximumHeight: 64
                radius: 10
                color: "#313244"
                border.width: 1
                border.color: "#45475a"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: bluetoothPopup.bluetoothEnabled
                                ? "Bluetooth is enabled"
                                : "Bluetooth is disabled"
                            color: "#cdd6f4"
                            font.pixelSize: 12
                        }

                        Text {
                            text: bluetoothPopup.bluetoothEnabled
                                ? "Ready to connect devices"
                                : "Turn on to use Bluetooth"
                            color: "#a6adc8"
                            font.pixelSize: 10
                        }
                    }

                    Rectangle {
                        width: 58
                        height: 28
                        radius: 7
                        color: bluetoothPopup.bluetoothEnabled
                            ? "#45475a" : "#313244"
                        border.width: 1
                        border.color: bluetoothPopup.bluetoothEnabled
                            ? "#89b4fa" : "#585b70"

                        Text {
                            anchors.centerIn: parent
                            text: bluetoothPopup.bluetoothEnabled
                                ? "ON" : "OFF"
                            color: bluetoothPopup.bluetoothEnabled
                                ? "#a6e3a1" : "#f38ba8"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                bluetoothPopup.bluetoothAction =
                                    bluetoothPopup.bluetoothEnabled
                                    ? "off" : "on"

                                bluetoothPowerProcess.running = true
                            }
                        }
                    }
                }
            }

            // Paired devices
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Paired devices"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                }

                Repeater {
                    model: bluetoothPopup.bluetoothDevices

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 9
                        color: "#313244"
                        border.width: 1
                        border.color: "#45475a"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: "󰂯"
                                color: "#89b4fa"
                                font.pixelSize: 18
                            }

                            Text {
                                text: modelData.name
                                color: "#cdd6f4"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight
                            }

                            // Connect / disconnect function.
                            Rectangle {
                                Layout.preferredWidth: 88
                                Layout.preferredHeight: 28
                                radius: 7

                                color: bluetoothPopup.connectedBluetoothDevices.includes(modelData.mac)
                                    ? "#45475a" : "#313244"

                                border.width: 1
                                border.color: "#585b70"

                                Text {
                                    anchors.centerIn: parent

                                    text: bluetoothPopup.connectedBluetoothDevices.includes(modelData.mac)
                                        ? "Disconnect" : "Connect"

                                    color: "#89b4fa"
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        bluetoothDeviceActionProcess.action =
                                            bluetoothPopup.connectedBluetoothDevices.includes(modelData.mac)
                                            ? "disconnect" : "connect"

                                        bluetoothDeviceActionProcess.deviceMac = modelData.mac
                                        bluetoothDeviceActionProcess.running = true
                                    }
                                }
                            }

                            // Forget function.
                            Rectangle {
                                Layout.preferredWidth: 58
                                Layout.preferredHeight: 28
                                radius: 7
                                color: "#313244"
                                border.width: 1
                                border.color: "#585b70"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Forget"
                                    color: "#f38ba8"
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        bluetoothForgetProcess.deviceMac = modelData.mac
                                        bluetoothForgetProcess.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Scan for nearby devices
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 9
                color: bluetoothPopup.bluetoothScanning
                    ? "#45475a" : "#313244"
                border.width: 1
                border.color: "#585b70"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: bluetoothPopup.bluetoothScanning ? "󰑐" : "󰂰"
                        color: "#89b4fa"
                        font.pixelSize: 15
                    }

                    Text {
                        text: bluetoothPopup.bluetoothScanning
                            ? "Scanning nearby devices..."
                            : "Scan for devices"
                        color: "#cdd6f4"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !bluetoothPopup.bluetoothScanning
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        bluetoothScanProcess.running = true
                    }
                }
            }

            // Nearby devices
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                spacing: 8

                Text {
                    text: "Nearby devices"
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                }

                // Available devices section.
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    clip: true

                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: bluetoothPopup.discoveredBluetoothDevices

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                radius: 9
                                color: "#313244"
                                border.width: 1
                                border.color: "#45475a"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        text: "󰂯"
                                        color: "#89b4fa"
                                        font.pixelSize: 17
                                    }

                                    Text {
                                        text: modelData.name
                                        color: "#cdd6f4"
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 58
                                        Layout.preferredHeight: 28
                                        radius: 7
                                        color: "#313244"
                                        border.width: 1
                                        border.color: "#585b70"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Pair"
                                            color: "#a6e3a1"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                bluetoothPairProcess.deviceMac = modelData.mac
                                                bluetoothPairProcess.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !bluetoothPopup.bluetoothScanning
                        && bluetoothPopup.discoveredBluetoothDevices.length === 0

                    text: "No new devices found"
                    color: "#a6adc8"
                    font.pixelSize: 11
                }
            }
        }
    }
}
