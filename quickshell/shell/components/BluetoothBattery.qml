import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: batteryReader

    property var devices: []
    property var batteryDevices: {
        const groups = {}

        for (const battery of devices) {
            if (!groups[battery.device]) {
                groups[battery.device] = {
                    device: battery.device,
                    name: battery.name,
                    icon: battery.icon,
                    deviceClass: battery.deviceClass,
                    batteries: []
                }
            }

            groups[battery.device].batteries.push(battery)
        }

        return Object.values(groups).map(device => {
            const left = device.batteries.find(
                battery => battery.identifier === "left"
            )
            const right = device.batteries.find(
                battery => battery.identifier === "right"
            )

            const earbuds = [left, right].filter(Boolean)

            const readings = earbuds.length > 0
                ? earbuds
                : device.batteries

            device.averagePercentage = Math.round(
                readings.reduce((sum, battery) => sum + battery.percentage, 0)
                / readings.length
            )

            return device
        })
    }
    property int averagePercentage: {
        const left = devices.find(device => device.identifier === "left")
        const right = devices.find(device => device.identifier === "right")

        if (!left || !right)
            return 0

        return Math.round((left.percentage + right.percentage) / 2)
    }
    property Item anchorItem: null
    property alias popupVisible: batteryPopup.visible

    //

    function refresh() {
        batteryProcess.running = true
    }

    function batteryPercentage(identifier) {
        const battery = devices.find(
            device => device.identifier === identifier
        )

        return battery ? battery.percentage + "%" : "--"
    }

    function deviceAddress(path) {
        return path.substring(path.lastIndexOf("/dev_") + 5)
            .replace(/_/g, ":")
    }

    Process {
        id: batteryProcess

        command: [
            "sh", "-c",
            "busctl --system --list tree org.bluez | grep 'battery_' | while IFS= read -r path; do " +
            "device=${path%/battery_*}; " +
            "connected=$(busctl --system get-property org.bluez \"$device\" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}'); " +
            "name=$(busctl --system get-property org.bluez \"$device\" org.bluez.Device1 Name 2>/dev/null | cut -d '\"' -f 2); " +
            "icon=$(busctl --system get-property org.bluez \"$device\" org.bluez.Device1 Icon 2>/dev/null | cut -d '\"' -f 2); " +
            "class=$(busctl --system get-property org.bluez \"$device\" org.bluez.Device1 Class 2>/dev/null | awk '{print $2}'); " +
            "identifier=$(busctl --system get-property org.bluez \"$path\" org.bluez.Battery1 Identifier 2>/dev/null | cut -d '\"' -f 2); " +
            "percentage=$(busctl --system get-property org.bluez \"$path\" org.bluez.Battery1 Percentage 2>/dev/null | awk '{print $2}'); " +
            "charging=$(busctl --system get-property org.bluez \"$path\" org.bluez.Battery1 Charging 2>/dev/null | awk '{print $2}'); " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$device\" \"$identifier\" \"$percentage\" \"$charging\" \"$connected\" \"$name\" \"$icon\" \"$class\"; " +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const result = []

                for (const line of text.trim().split("\n")) {
                    const parts = line.split("|")

                    if (parts.length === 8 && parts[0] && parts[1]
                        && parts[4] === "true") {
                        result.push({
                            device: parts[0],
                            identifier: parts[1],
                            percentage: Number(parts[2]),
                            charging: parts[3] === "true",
                            connected: true,
                            name: parts[5],
                            icon: parts[6],
                            deviceClass: parts[7]
                        })
                    }
                }

                batteryReader.devices = result
                //console.log("Bluetooth batteries:", JSON.stringify(result))
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryReader.refresh()
    }

    PopupWindow {
        id: batteryPopup

        anchor.item: batteryReader.anchorItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom

        visible: false
        color: "transparent"
        implicitWidth: 290
        implicitHeight: 190
        grabFocus: true

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 12
            border.width: 1
            border.color: "#45475a"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14
                width: parent.width

                Text {
                    text: "Redmi Buds 5"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    id: batteryRow

                    Layout.fillWidth: true
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: [
                            { name: "Left", id: "left", icon: "󰋎" },
                            { name: "Case", id: "case", icon: "󰂯" },
                            { name: "Right", id: "right", icon: "󰋎" }
                        ]

                        delegate: ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: batteryRow.width / 3
                            spacing: 5

                            Text {
                                text: modelData.icon
                                color: "#cba6f7"
                                font.pixelSize: 27
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.name
                                color: "#a6adc8"
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: batteryReader.batteryPercentage(
                                    modelData.id
                                )
                                color: modelData.id === "case"
                                    && batteryReader.batteryPercentage("case") !== "--"
                                    && Number(batteryReader.batteryPercentage("case").replace("%", "")) <= 10
                                    ? "#f38ba8" : "#cdd6f4"
                                font.pixelSize: 14
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 250
                    Layout.alignment: Qt.AlignHCenter
                    radius: 7
                    color: "#f38ba8"

                    Text {
                        anchors.centerIn: parent
                        text: "Disconnect"
                        color: "#1e1e2e"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            const device = batteryReader.devices[0]

                            if (device) {
                                disconnectProcess.deviceAddress =
                                    batteryReader.deviceAddress(device.device)
                                disconnectProcess.running = true
                                batteryPopup.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: disconnectProcess

        property string deviceAddress: ""

        command: ["bluetoothctl", "disconnect", deviceAddress]

        onExited: batteryReader.refresh()
    }

}
