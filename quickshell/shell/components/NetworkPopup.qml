import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: networkPopup

    property bool wifiEnabled: false
    property var wifiNetworks: []
    property string selectedSsid: ""
    property bool passwordDialogVisible: false
    property bool networkActionsVisible: false
    property string passwordText: ""
    property string connectionStatus: ""
    property string connectedSsid: ""
    property var savedNetworks: []
    property string ethernetStatus: "Checking..."

    // Check if WiFi is is enabled.
    Process {
        id: wifiStatusProcess
        command: ["nmcli", "-t", "-f", "WIFI", "general"] 

        stdout: StdioCollector {
            onStreamFinished: {
                networkPopup.wifiEnabled = text.trim() === "enabled"
            }
        }
    }

    // Check Ethernet status.
    Process {
        id: ethernetStatusProcess
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"] 

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                let status = "Not connected"

                for (const line of lines) {
                    const fields = line.split(":")

                    if (fields[0] === "ethernet") {
                        status = fields[1] === "connected"
                            ? "Connected"
                            : "Not connected"
                        break
                    }
                }

                networkPopup.ethernetStatus = status
            }
        }
    }

    // Scan available Wi-Fi networks.
    Process {
        id: wifiScanProcess
        command: [
            "nmcli", "-t",
            "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list",
            "--rescan", "yes"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const networks = []

                for (const line of text.trim().split("\n")) {
                    if (!line.trim())
                        continue

                    const fields = line.split(":")

                    if (fields.length >= 4) {
                        networks.push({
                            inUse: fields[0].trim() === "*",
                            ssid: fields[1].trim(),
                            signal: Number(fields[2].trim()),
                            security: fields[3].trim()
                        })
                    }
                }

                networkPopup.wifiNetworks = networks
            }
        }
    }

    // Connect to the selected Wi-Fi network.
    Process {
        id: wifiConnectProcess

        command: networkPopup.passwordText.length > 0
            ? [
                "nmcli", "--wait", "30",
                "device", "wifi", "connect",
                networkPopup.selectedSsid,
                "password", networkPopup.passwordText
            ]
            : [
                "nmcli", "--wait", "30",
                "device", "wifi", "connect",
                networkPopup.selectedSsid
            ]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Wi-Fi:", text.trim())
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                networkPopup.connectionStatus = text.trim()
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                networkPopup.connectionStatus = "Connected"
                networkPopup.passwordDialogVisible = false
                networkPopup.passwordText = ""
                wifiScanProcess.running = true
            } else {
                console.log("Wi-Fi connection failed:", networkPopup.connectionStatus)
            }
        }
    }

    // Connected to Wi-Fi network.
    Process {
        id: wifiConnectedProcess
        command: [
            "nmcli", "-t",
            "-f", "NAME,TYPE",
            "connection", "show",
            "--active"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let connected = ""

                for (const line of text.trim().split("\n")) {
                    const fields = line.split(":")

                    if (fields.length >= 2 && fields[1] === "802-11-wireless") {
                        connected = fields[0]
                        break
                    }
                }

                networkPopup.connectedSsid = connected
            }
        }
    }

    // Retrieve saved Wi-Fi connection profiles.
    Process {
        id: savedNetworksProcess

        command: [
            "nmcli", "-t",
            "-f", "NAME,TYPE",
            "connection", "show"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const networks = []

                for (const line of text.trim().split("\n")) {
                    if (!line.trim())
                        continue

                    const fields = line.split(":")

                    if (fields.length >= 2 && fields[1] === "802-11-wireless")
                        networks.push(fields[0])
                }

                networkPopup.savedNetworks = networks
                console.log("Saved Wi-Fi networks:", JSON.stringify(networkPopup.savedNetworks))
            }
        }
    }

    // Refresh network status every 5 secs.
    Timer {
        interval: 5000
        running: networkPopup.visible
        repeat: true

        onTriggered: {
            wifiStatusProcess.running = true
            ethernetStatusProcess.running = true
        }
    }

    // Inicial status check when popup opens.
    onVisibleChanged: {
        if (visible) {
            wifiStatusProcess.running = true
            wifiScanProcess.running = true
            wifiConnectedProcess.running = true
            ethernetStatusProcess.running = true
            savedNetworksProcess.running = true
        }
    }

    implicitWidth: 360
    implicitHeight: 390

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
                    text: "Network"
                    color: "#cdd6f4"
                    font.pixelSize: 18
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "󰖩"
                    color: "#89b4fa"
                    font.pixelSize: 20
                }
            }

            // Wi-Fi section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 145
                radius: 10
                color: "#313244"
                border.width: 1
                border.color: "#45475a"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Wi-Fi"
                            color: "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: networkPopup.wifiEnabled ? "ON" : "OFF"
                            color: networkPopup.wifiEnabled ? "#a6e3a1" : "#f38ba8"
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        text: networkPopup.wifiEnabled ? "Wi-Fi is enabled" : "Wi-Fi is disabled"
                        color: "#a6adc8"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#45475a"
                        clip: true

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4
                            model: networkPopup.wifiNetworks

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: 38
                                radius: 6
                                color: networkPopup.selectedSsid === modelData.ssid
                                    ? "#45475a" : "#313244"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: modelData.ssid === networkPopup.connectedSsid
                                            ? "󰤨"
                                            : "󰤯"
                                        color: modelData.ssid === networkPopup.connectedSsid
                                            ? "#a6e3a1"
                                            : "#89b4fa"
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: "#cdd6f4"
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.ssid === networkPopup.connectedSsid
                                            ? "Connected"
                                            : modelData.signal + "%"
                                        color: modelData.ssid === networkPopup.connectedSsid
                                            ? "#a6e3a1"
                                            : "#a6adc8"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        text: modelData.security === "--" ? "󰌾" : "󰌿"
                                        color: "#a6adc8"
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        networkPopup.selectedSsid = modelData.ssid

                                        const isConnected =
                                            modelData.ssid === networkPopup.connectedSsid

                                        const isSaved =
                                            networkPopup.savedNetworks.indexOf(modelData.ssid) !== -1

                                        if (isConnected || isSaved) {
                                            networkPopup.networkActionsVisible = true
                                        } else {
                                            networkPopup.networkActionsVisible = false
                                            networkPopup.passwordText = ""

                                            if (modelData.security === "--") {
                                                wifiConnectProcess.running = true
                                            } else {
                                                networkPopup.passwordDialogVisible = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: networkPopup.passwordDialogVisible
                    z: 10
                    color: "#cc11111b"
                    radius: 14

                    Rectangle {
                        width: 300
                        height: 190
                        anchors.centerIn: parent
                        radius: 12
                        color: "#313244"
                        border.width: 1
                        border.color: "#45475a"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                text: "Connect to " + networkPopup.selectedSsid
                                color: "#cdd6f4"
                                font.pixelSize: 14
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            TextInput {
                                Layout.fillWidth: true
                                color: "#cdd6f4"
                                font.pixelSize: 13
                                echoMode: TextInput.Password
                                clip: true
                                focus: networkPopup.passwordDialogVisible
                                onTextChanged: networkPopup.passwordText = text

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: "#89b4fa"
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: 10

                                Text {
                                    text: "Cancel"
                                    color: "#a6adc8"
                                    font.pixelSize: 12

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: networkPopup.passwordDialogVisible = false
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                Text {
                                    text: "Continue"
                                    color: "#89b4fa"
                                    font.pixelSize: 12
                                    font.bold: true

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            onClicked: {
                                                wifiConnectProcess.running = true
                                            }
                                        }
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Ethernet section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 10
                color: "#313244"
                border.width: 1
                border.color: "#45475a"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Text {
                        text: "Ethernet"
                        color: "#cdd6f4"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: networkPopup.ethernetStatus 
                        color: networkPopup.ethernetStatus === "Connected" 
                            ? "#a6e3a1" : "#a6adc8"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
