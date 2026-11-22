import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// The saved Ollama servers, one click (or key 1 to 9) apart. Picking one
// switches the whole window to it.
Popup {
    id: menu

    // Asks the window to open the add-host dialog; a popup can't own two modal layers.
    signal addRequested()

    readonly property int rowHeight: 48
    // Saved hosts first, then the two actions, as one list so the arrow keys walk all of it.
    readonly property var entries: {
        var out = []
        var hosts = backend.hosts
        for (var i = 0; i < hosts.length; ++i)
            out.push({ kind: "host", index: i, label: hosts[i].label, address: hosts[i].address,
                       named: hosts[i].name.length > 0, current: hosts[i].current })
        out.push({ kind: "default", label: qsTr("Use default"), address: "OLLAMA_HOST, 127.0.0.1:11434" })
        out.push({ kind: "add", label: qsTr("Add host…"), address: "" })
        return out
    }

    function activate(entry) {
        close()
        if (entry.kind === "host")
            backend.selectHost(entry.index)
        else if (entry.kind === "default")
            backend.useDefaultHost()
        else
            addRequested()
    }

    width: 360
    padding: 6
    modal: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Material.roundedScale: theme.radius
    // No fade, so it is fully drawn the moment it opens.
    enter: Transition {}
    exit: Transition {}

    background: Rectangle {
        color: "#17171a"
        radius: theme.radius
        border.color: "#26262b"
    }

    onOpened: {
        list.currentIndex = Math.max(0, backend.hostIndex)
        list.forceActiveFocus()
    }

    contentItem: ListView {
        id: list
        implicitHeight: contentHeight
        interactive: false
        clip: true
        model: menu.entries
        keyNavigationEnabled: true
        highlightMoveDuration: 0
        Keys.onReturnPressed: menu.activate(menu.entries[currentIndex])
        Keys.onEnterPressed: menu.activate(menu.entries[currentIndex])
        Keys.onDeletePressed: {
            var entry = menu.entries[currentIndex]
            if (entry.kind === "host")
                backend.removeHost(entry.index)
        }

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isHost: modelData.kind === "host"

            width: ListView.view.width
            height: menu.rowHeight
            radius: Math.min(4, theme.radius)
            color: ListView.isCurrentItem || hover.hovered ? "#222226" : "transparent"

            HoverHandler { id: hover }
            MouseArea {
                anchors.fill: parent
                onClicked: menu.activate(row.modelData)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 10

                // Which key jumps here; only the first nine hosts get one.
                Label {
                    Layout.preferredWidth: 14
                    text: row.isHost && row.modelData.index < 9 ? row.modelData.index + 1 : ""
                    color: "#8a8a93"
                    font.family: "monospace"
                    font.pixelSize: 12
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: row.modelData.label
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        font.pixelSize: 14
                        font.weight: row.modelData.current ? Font.DemiBold : Font.Normal
                    }
                    Label {
                        // Shown under a name, so the address is never hidden; the add row has none.
                        visible: text.length > 0 && (!row.isHost || row.modelData.named)
                        text: row.modelData.address
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        color: "#8a8a93"
                        font.pixelSize: 11
                    }
                }
                // A true circle marks the host on screen.
                Rectangle {
                    visible: row.isHost && row.modelData.current
                    width: 8
                    height: 8
                    radius: 4
                    color: theme.accent
                }
                Button {
                    visible: row.isHost && (hover.hovered || row.ListView.isCurrentItem)
                    text: "✕"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    implicitWidth: 32
                    implicitHeight: 32
                    Material.foreground: "#8a8a93"
                    onClicked: backend.removeHost(row.modelData.index)
                }
            }
        }
    }
}
