import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 1040
    height: 700
    minimumWidth: 760
    minimumHeight: 480
    visible: true
    title: "Ollama Dash"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false

    readonly property real loadedBytes: {
        var total = 0
        for (var i = 0; i < backend.running.length; ++i)
            total += backend.running[i].size
        return total
    }

    // Single-key shortcuts would fire while typing an address.
    readonly property bool typing: hostDialog.visible

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: win.helpVisible && !win.typing; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: backend.refresh() }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: backend.refresh() }
    Shortcut { sequence: "H"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: hostDialog.open() }

    HostDialog { id: hostDialog }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Label {
                    text: "Ollama Dash"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    // A true circle, so it keeps a fixed radius.
                    width: 10
                    height: 10
                    radius: 5
                    color: !backend.checked ? "#8a8a93" : backend.connected ? "#30d158" : "#ff453a"
                }
                Label {
                    text: !backend.checked ? qsTr("Connecting…") : backend.connected ? qsTr("Connected") : qsTr("Not connected")
                    font.pixelSize: 13
                }
                Button {
                    text: backend.host
                    font.pixelSize: 13
                    flat: true
                    // Keeps Space free for the refresh shortcut.
                    focusPolicy: Qt.NoFocus
                    onClicked: hostDialog.open()
                }
                Label {
                    visible: backend.connected && backend.version.length > 0
                    text: qsTr("Ollama %1").arg(backend.version)
                    color: "#8a8a93"
                    font.pixelSize: 13
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 320
                    Layout.fillHeight: true
                    spacing: 16

                    // Said plainly in the window, not hidden behind an empty dashboard.
                    Panel {
                        visible: backend.checked && !backend.connected
                        Layout.fillWidth: true
                        title: qsTr("Offline")

                        Label {
                            text: qsTr("Can't reach Ollama at %1").arg(backend.host)
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Label {
                            text: backend.error
                            color: "#ff8f87"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("Start the server with “ollama serve” or “systemctl start ollama”. To watch a different server, choose its address below.")
                            color: "#8a8a93"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Button {
                            text: qsTr("Change host…")
                            highlighted: true
                            focusPolicy: Qt.NoFocus
                            onClicked: hostDialog.open()
                        }
                    }

                    Panel {
                        visible: backend.connected
                        Layout.fillWidth: true
                        title: qsTr("Running now")
                        subtitle: backend.running.length > 0
                                  ? qsTr("%1 in memory").arg((translator.language, backend.formatBytes(win.loadedBytes)))
                                  : ""

                        Label {
                            visible: backend.running.length === 0
                            text: qsTr("No model is loaded. Models show up here while they're in memory and unload after a few idle minutes.")
                            color: "#8a8a93"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: backend.running
                            RunningCard {}
                        }
                    }

                    Panel {
                        visible: backend.connected
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: qsTr("Installed")
                        subtitle: qsTr("%n models", "", backend.installed.length)

                        Label {
                            visible: backend.installed.length === 0
                            text: qsTr("No models pulled yet. Try “ollama pull llama3.2”.")
                            color: "#8a8a93"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: backend.installed
                            delegate: InstalledRow {}
                            ScrollBar.vertical: ScrollBar {}
                        }
                    }
                }

                ColumnLayout {
                    // Nested layouts fill by default, which let this column
                    // swallow the model lists; pin it to its width.
                    Layout.fillWidth: false
                    Layout.preferredWidth: 300
                    Layout.maximumWidth: 300
                    Layout.fillHeight: true
                    spacing: 16

                    Panel {
                        visible: !backend.local
                        Layout.fillWidth: true
                        title: qsTr("System")

                        Label {
                            text: qsTr("CPU and memory graphs show this computer, so they're hidden while watching Ollama on %1.").arg(backend.host)
                            color: "#8a8a93"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Panel {
                        visible: backend.local
                        Layout.fillWidth: true
                        title: qsTr("System")
                        subtitle: qsTr("Last 2 minutes")

                        Label { text: qsTr("CPU"); color: "#8a8a93"; font.pixelSize: 12 }
                        Label {
                            text: (translator.language, Math.round(backend.cpu).toLocaleString(Qt.locale(), 'f', 0)) + "%"
                            font.pixelSize: 30
                            font.weight: Font.DemiBold
                        }
                        Sparkline {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            values: backend.cpuHistory
                        }

                        Label { text: qsTr("Memory"); color: "#8a8a93"; font.pixelSize: 12; Layout.topMargin: 6 }
                        Label {
                            text: qsTr("%1 of %2")
                                      .arg((translator.language, backend.formatBytes(backend.memoryUsed)))
                                      .arg((translator.language, backend.formatBytes(backend.memoryTotal)))
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Sparkline {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            values: backend.memoryHistory
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // The shortcuts overlay, dismissed by a click anywhere.
        Rectangle {
            anchors.fill: parent
            visible: win.helpVisible
            color: "#cc000000"

            MouseArea { anchors.fill: parent; onClicked: win.helpVisible = false }

            Panel {
                anchors.centerIn: parent
                width: 340
                title: qsTr("Shortcuts")

                GridLayout {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 8
                    Layout.fillWidth: true

                    Label { text: "Space  /  R"; font.family: "monospace" }
                    Label { text: qsTr("Refresh now"); color: "#8a8a93" }
                    Label { text: "?"; font.family: "monospace" }
                    Label { text: qsTr("Show or hide this help"); color: "#8a8a93" }
                    Label { text: "H"; font.family: "monospace" }
                    Label { text: qsTr("Change the Ollama host"); color: "#8a8a93" }
                    Label { text: "Q"; font.family: "monospace" }
                    Label { text: qsTr("Quit"); color: "#8a8a93" }
                }
            }
        }
    }
}
