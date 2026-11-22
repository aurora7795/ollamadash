import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Adds an Ollama server to the saved list and switches to it.
Dialog {
    id: dialog

    property bool invalid: false

    modal: true
    anchors.centerIn: Overlay.overlay
    width: 440
    title: qsTr("Add Ollama host")
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
        if (backend.addHost(nameField.text, field.text))
            close()
        else
            invalid = true
    }

    onAboutToShow: {
        invalid = false
        nameField.text = ""
        field.text = ""
    }
    onOpened: field.forceActiveFocus()

    contentItem: ColumnLayout {
        spacing: 10

        // The Material fields float their placeholders as labels.
        TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: qsTr("Address, for example my-server:11434")
            onAccepted: dialog.connectNow()
            onTextEdited: dialog.invalid = false
        }
        // Below the address, which is the one thing that is required and has the focus.
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: qsTr("Name (optional), for example Mac mini")
            onAccepted: dialog.connectNow()
        }
        Label {
            visible: dialog.invalid
            text: qsTr("That isn't a valid address.")
            color: "#ff8f87"
            Layout.fillWidth: true
        }
        Label {
            text: qsTr("Saved for next time. Press H to switch between saved hosts.")
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
