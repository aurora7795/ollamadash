import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// A titled card; children land in the body column below the heading.
Rectangle {
    id: panel

    property string title: ""
    property string subtitle: ""
    default property alias content: body.data

    color: "#17171a"
    radius: theme.radius
    border.color: "#26262b"
    implicitHeight: column.implicitHeight + 32

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: panel.title
                color: "#8a8a93"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
            Label {
                text: panel.subtitle
                color: "#8a8a93"
                font.pixelSize: 12
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
        }
    }
}
