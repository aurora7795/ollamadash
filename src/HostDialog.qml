import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Picks which Ollama server to watch. The choice is saved by the backend.
Dialog {
    id: dialog

    property bool invalid: false

    modal: true
    anchors.centerIn: Overlay.overlay
    width: 440
    title: qsTr("Ollama host")
    Material.roundedScale: theme.radius

    // Match the app's panels instead of Material's lighter popup surface.
    background: Rectangle {
        color: "#17171a"
        radius: theme.radius
        border.color: "#26262b"
    }
    Overlay.modal: Rectangle { color: "#99000000" }
    // No fade, so it is fully drawn the moment it opens.
    enter: Transition {}
    exit: Transition {}

    function connectNow() {
        if (backend.setHost(field.text))
            close()
        else
            invalid = true
    }

    onAboutToShow: {
        invalid = false
        field.text = backend.host
    }
    onOpened: {
        field.forceActiveFocus()
        field.selectAll()
    }

    contentItem: ColumnLayout {
        spacing: 10

        // The Material field floats this placeholder as its label.
        TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: qsTr("Address, for example my-server:11434")
            onAccepted: dialog.connectNow()
            onTextEdited: dialog.invalid = false
        }
        Label {
            visible: dialog.invalid
            text: qsTr("That isn't a valid address.")
            color: "#ff8f87"
            Layout.fillWidth: true
        }
        Label {
            text: qsTr("Saved for next time. “Use default” goes back to OLLAMA_HOST, or 127.0.0.1:11434 when that isn't set.")
            color: "#8a8a93"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    // The stock header paints a lighter strip; a plain title sits on the panel.
    header: Item {
        implicitHeight: 56
        Label {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: dialog.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
    }

    footer: Item {
        implicitHeight: 60

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 8
            spacing: 8

            Button {
                text: qsTr("Use default")
                flat: true
                Material.foreground: "#e8e8ea"
                focusPolicy: Qt.NoFocus
                onClicked: {
                    field.text = ""
                    dialog.connectNow()
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Cancel")
                flat: true
                Material.foreground: "#e8e8ea"
                focusPolicy: Qt.NoFocus
                onClicked: dialog.close()
            }
            Button {
                id: connect
                text: qsTr("Connect")
                focusPolicy: Qt.NoFocus
                onClicked: dialog.connectNow()
                background: Rectangle {
                    radius: Math.min(4, theme.radius)
                    color: theme.accent
                    opacity: connect.down ? 0.8 : 1
                }
                contentItem: Label {
                    text: connect.text
                    color: theme.accentForeground
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
