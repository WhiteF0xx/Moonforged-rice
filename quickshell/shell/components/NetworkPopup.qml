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
    property string selectedConnectionUuid: ""
    property bool selectedNetworkConnected: false
    property string networkAction: ""
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

        stdinEnabled: true

        command: networkPopup.passwordText.length > 0
            ? [
                "sh", "-c",
                `
                umask 077

                password_file=$(mktemp) || exit 1
                trap 'rm -f "$password_file"' EXIT

                IFS= read -r password || exit 1

                printf '%s\n' \
                    "802-11-wireless-security.psk:$password" \
                    > "$password_file" || exit 1

                unset password

                nmcli connection add \
                    type wifi \
                    con-name "$1" \
                    ifname "*" \
                    ssid "$1" \
                    -- wifi-sec.key-mgmt wpa-psk || exit 1

                nmcli --wait 30 connection up \
                    id "$1" \
                    passwd-file "$password_file"
                `,
                "moonforge-wifi",
                networkPopup.selectedSsid
            ]
            : [
                "nmcli", "--wait", "30",
                "device", "wifi", "connect",
                networkPopup.selectedSsid
            ]

        onStarted: {
            if (networkPopup.passwordText.length > 0) {
                write(networkPopup.passwordText + "\n")
                networkPopup.passwordText = ""
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
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
                savedNetworksProcess.running = true
                wifiConnectedProcess.running = true
            } else {
                networkPopup.passwordText = ""
            }
        }
    }

    // Detect the currently connected Wi-Fi network.
    Process {
        id: wifiConnectedProcess

        command: [
            "nmcli", "-t",
            "-f", "IN-USE,SSID",
            "device", "wifi", "list"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let connected = ""

                for (const line of text.trim().split("\n")) {
                    if (line.startsWith("*:")) {
                        connected = line.substring(2)
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
            "-f", "NAME,UUID,TYPE",
            "connection", "show"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = text.trim().split("\n")
                const networks = []

                for (const line of profiles) {
                    if (!line.trim())
                        continue

                    const fields = line.split(":")

                    if (fields.length < 3 || fields[2] !== "802-11-wireless")
                        continue

                    networks.push({
                        name: fields[0],
                        uuid: fields[1],
                        ssid: ""
                    })
                }

                networkPopup.savedNetworks = networks
                savedNetworkSsidProcess.startFetching()
            }
        }
    }

    // Retrieve the actual SSID for each saved Wi-Fi profile.
    Process {
        id: savedNetworkSsidProcess

        property int currentIndex: 0

        function fetchNext() {
            if (currentIndex >= networkPopup.savedNetworks.length) {
                return
            }

            command = [
                "nmcli", "-g",
                "802-11-wireless.ssid",
                "connection", "show", "uuid",
                networkPopup.savedNetworks[currentIndex].uuid
            ]

            running = true
        }

        stdout: StdioCollector {
            id: savedNetworkSsidOutput
        }

        onExited: (exitCode, exitStatus) => {
            const networks = networkPopup.savedNetworks.slice()

            if (exitCode === 0 && currentIndex < networks.length) {
                networks[currentIndex].ssid = savedNetworkSsidOutput.text.trim()
                networkPopup.savedNetworks = networks
            }

            currentIndex++
            fetchNext()
        }

        function startFetching() {
            currentIndex = 0
            fetchNext()
        }
    }

    // Connect, disconnect, or forget a saved Wi-Fi profile.
    Process {
        id: networkActionProcess

        command: {
            if (networkPopup.networkAction === "connect") {
                return [
                    "nmcli", "--wait", "30",
                    "connection", "up", "uuid",
                    networkPopup.selectedConnectionUuid
                ]
            }

            if (networkPopup.networkAction === "disconnect") {
                return [
                    "nmcli",
                    "connection", "down", "uuid",
                    networkPopup.selectedConnectionUuid
                ]
            }

            if (networkPopup.networkAction === "forget") {
                return [
                    "nmcli",
                    "connection", "delete", "uuid",
                    networkPopup.selectedConnectionUuid
                ]
            }

            return []
        }

        stdout: StdioCollector {
            onStreamFinished: {
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                networkPopup.connectionStatus = text.trim()
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                networkPopup.connectionStatus = "Action completed"
                networkPopup.networkActionsVisible = false

                wifiConnectedProcess.running = true
                savedNetworksProcess.running = true
                wifiScanProcess.running = true
            } else {
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
    implicitHeight: 490

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
                Layout.preferredHeight: 250
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
                                height: networkPopup.selectedSsid === modelData.ssid
                                    && networkPopup.networkActionsVisible ? 76 : 38
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

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.bottomMargin: 5
                                    spacing: 6

                                    visible: networkPopup.selectedSsid === modelData.ssid
                                            && networkPopup.networkActionsVisible

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 25
                                        radius: 5
                                        color: "#45475a"

                                        Text {
                                            anchors.centerIn: parent
                                            text: networkPopup.selectedNetworkConnected
                                                ? "Disconnect" : "Connect"
                                            color: "#cdd6f4"
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                networkPopup.networkAction =
                                                    networkPopup.selectedNetworkConnected
                                                    ? "disconnect" : "connect"

                                                networkActionProcess.running = true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 25
                                        radius: 5
                                        color: "#585064"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Forget"
                                            color: "#f38ba8"
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                networkPopup.networkAction = "forget"
                                                networkActionProcess.running = true
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 38
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        const alreadySelected =
                                            networkPopup.selectedSsid === modelData.ssid
                                            && networkPopup.networkActionsVisible

                                        if (alreadySelected) {
                                            networkPopup.networkActionsVisible = false
                                            networkPopup.selectedSsid = ""
                                            return
                                        }

                                        networkPopup.selectedSsid = modelData.ssid

                                        const isConnected =
                                            modelData.ssid === networkPopup.connectedSsid

                                        const isSaved =
                                            networkPopup.savedNetworks.some(
                                                network => network.ssid === modelData.ssid
                                            )

                                        const savedNetwork = networkPopup.savedNetworks.find(
                                            network => network.ssid === modelData.ssid
                                        )

                                        if (savedNetwork) {
                                            networkPopup.selectedConnectionUuid = savedNetwork.uuid
                                            networkPopup.selectedNetworkConnected = isConnected
                                            networkPopup.networkActionsVisible = true
                                        } else if (!modelData.security || modelData.security === "--") {
                                            networkPopup.selectedConnectionUuid = ""
                                            networkPopup.networkActionsVisible = false
                                            networkPopup.passwordText = ""
                                            wifiConnectProcess.running = true
                                        } else {
                                            networkPopup.selectedConnectionUuid = ""
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
