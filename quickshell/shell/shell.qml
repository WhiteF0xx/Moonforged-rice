
//@ pragma UseQApplication

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

ShellRoot {
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

            // Moonforge launcher
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

            // Focused window title
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.min(420, Math.max(180, titleText.implicitWidth + 24))
                Layout.minimumWidth: 180
                Layout.maximumWidth: 420
                implicitHeight: 30

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

            //System Tray Capsule
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

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayEntry

                            required property var modelData

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

                                    const pos = trayEntry.mapToItem(
                                        barWindow.contentItem,
                                        0,
                                        trayEntry.height
                                    );

                                    item.display(barWindow, pos.x, pos.y);
                                }
                            }
                        }
                    }
                }
            }

            // Clock
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

            Timer {
                interval: 1000
                running: true
                repeat: true

                onTriggered: clockText.text =
                    Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
            }
        }
    }
}
