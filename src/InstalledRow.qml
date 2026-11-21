import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One pulled model in the installed list. A ListView pins delegates to x: 0,
// so the delegate is a full-width Item and the row sits inside it.
Item {
    id: row

    required property var modelData

    // Asks the window to show this model's details.
    signal activated(string name)

    readonly property bool loaded: {
        for (var i = 0; i < backend.running.length; ++i)
            if (backend.running[i].name === modelData.name)
                return true
        return false
    }

    width: ListView.view ? ListView.view.width : 0
    height: 44

    Rectangle {
        anchors.fill: parent
        color: area.containsMouse ? "#1d1d21" : "transparent"
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated(row.modelData.name)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            // A true circle, so it keeps a fixed radius.
            width: 8
            height: 8
            radius: 4
            color: row.loaded ? theme.accent : "#2a2a30"
        }
        Label {
            text: row.modelData.name
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Label {
            text: [row.modelData.parameterSize, row.modelData.quantization]
                      .filter(function (part) { return part.length > 0 }).join(" · ")
            color: "#8a8a93"
            font.pixelSize: 12
        }
        Label {
            text: (translator.language, backend.formatBytes(row.modelData.size))
            color: "#e8e8ea"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 72
        }
        Label {
            text: (translator.language, row.modelData.modified.toLocaleDateString(Qt.locale(), Locale.ShortFormat))
            color: "#8a8a93"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 88
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#222226"
    }
}
