
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 40
        color: "#1e1e2e"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                implicitWidth: 34
                implicitHeight: 28
                radius: 7
                color: launcherMouse.containsMouse
                    ? "#45475a" : "#313244"

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

            RowLayout {
                spacing: 5

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        required property int index

                        readonly property bool isActive:
                            Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === index + 1

                        implicitWidth: 32
                        implicitHeight: 28
                        radius: 6

                        color: isActive ? "#89b4fa"
                            : workspaceMouse.containsMouse
                                ? "#45475a" : "#313244"

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
                                "hyprctl", "dispatch", "workspace",
                                String(index + 1)
                            ])
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                Layout.maximumWidth: 450
                Layout.alignment: Qt.AlignVCenter

                text: Hyprland.activeToplevel
                    ? Hyprland.activeToplevel.title : "Desktop"

                color: "#a6adc8"
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }

            Text {
                id: clock
                color: "#cdd6f4"
                font.pixelSize: 13
                text: Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
            }

            Timer {
                interval: 1000
                running: true
                repeat: true

                onTriggered: clock.text =
                    Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
            }
        }
    }
}
