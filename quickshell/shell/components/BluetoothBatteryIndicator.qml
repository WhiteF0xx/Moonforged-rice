import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: indicator

    property var deviceData: ({})
    property alias popupVisible: batteryPopup.visible

    implicitWidth: batteryCapsule.implicitWidth
    implicitHeight: batteryCapsule.implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    function bluetoothDeviceIcon(device) {
        const classValue = Number(device.deviceClass)

        if (classValue > 0) {
            const minorClass = (classValue >> 2) & 0x3F

            switch (minorClass) {
            case 0x05:
                return "󰓃"

            case 0x06:
                return "󰋋"

            case 0x01:
                return "󰋎"
            }
        }

        switch (device.icon) {
        case "audio-card":
            return "󰓃"

        case "audio-headphones":
            return "󰋋"

        case "audio-headset":
            return "󰋎"

        default:
            return "󰂯"
        }
    }

    Rectangle {
        id: batteryCapsule

        implicitWidth: batteryContent.implicitWidth + 16
        implicitHeight: 30
        radius: 8
        color: "#313244"
        border.width: 1
        border.color: "#45475a"

        RowLayout {
            id: batteryContent

            anchors.centerIn: parent
            spacing: 6

            Text {
                text: indicator.bluetoothDeviceIcon(indicator.deviceData)
                color: "#cba6f7"
                font.pixelSize: 17
            }

            Text {
                text: (indicator.deviceData.averagePercentage ?? 0) + "%"
                color: "#cdd6f4"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: batteryPopup.visible = !batteryPopup.visible
        }
    }

    PopupWindow {
        id: batteryPopup

        anchor.item: batteryCapsule
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom

        visible: false
        color: "transparent"
        implicitWidth: 290
        implicitHeight: 220
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

                Text {
                    text: indicator.deviceData.name ?? "Bluetooth device"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    spacing: 0

                    Repeater {
                        model: {
                            const batteries = indicator.deviceData.batteries ?? []
                            const order = ["left", "case", "right"]
                            return order
                                .map(id => batteries.find(battery => battery.identifier === id))
                                .filter(Boolean)
                        }

                        delegate: Column {
                            required property var modelData

                            width: 262 / 3
                            height: 90
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    switch (modelData.identifier) {
                                    case "left": return "󰋎"
                                    case "right": return "󰋎"
                                    case "case": return "󰄀"
                                    default: return "󰂯"
                                    }
                                }
                                color: "#cba6f7"
                                font.pixelSize: 20
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.identifier.charAt(0).toUpperCase()
                                    + modelData.identifier.slice(1)
                                color: "#a6adc8"
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.percentage + "%"
                                color: modelData.percentage <= 10
                                    ? "#f38ba8" : "#cdd6f4"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
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
                            disconnectProcess.deviceAddress =
                                indicator.deviceData.device
                                .substring(
                                    indicator.deviceData.device.lastIndexOf("/dev_") + 5
                                ).replace(/_/g, ":")

                            disconnectProcess.running = true
                            batteryPopup.visible = false
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
    }
}