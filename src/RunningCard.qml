import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One model that is in memory right now.
Rectangle {
    id: card

    required property var modelData

    // Asks the window to show this model's details.
    signal activated(string name)

    readonly property bool onCpuOnly: modelData.sizeVram <= 0
    readonly property string expiry: {
        if (modelData.expiresIn < 0)
            return qsTr("Stays loaded")
        var s = modelData.expiresIn
        var time = s >= 60 ? Math.floor(s / 60) + "m " + (s % 60) + "s" : s + "s"
        return qsTr("Unloads in %1").arg(time)
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 28
    color: area.containsMouse ? "#25252a" : "#1d1d21"
    radius: Math.min(4, theme.radius)

    // Sits behind the content, so the Unload button still gets its own clicks.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated(card.modelData.name)
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: 2
                Label {
                    text: card.modelData.name
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: [card.modelData.parameterSize, card.modelData.quantization]
                              .filter(function (part) { return part.length > 0 }).join(" · ")
                    color: "#8a8a93"
                    font.pixelSize: 12
                }
            }
            Item { Layout.fillWidth: true }
            Label {
                text: card.expiry
                color: "#8a8a93"
                font.pixelSize: 12
            }
            Button {
                text: qsTr("Unload")
                flat: true
                // Keeps Space free for the refresh shortcut.
                focusPolicy: Qt.NoFocus
                onClicked: backend.unload(card.modelData.name)
            }
        }

        // How much of the model sits in GPU memory; the rest runs from system RAM.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: Math.min(3, theme.radius)
            color: "#2a2a30"

            Rectangle {
                width: parent.width * Math.min(100, card.modelData.vramPercent) / 100
                height: parent.height
                radius: parent.radius
                color: theme.accent
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                color: "#8a8a93"
                font.pixelSize: 12
                text: card.onCpuOnly
                      ? qsTr("Running on CPU · %1").arg((translator.language, backend.formatBytes(card.modelData.size)))
                      : qsTr("%1% on GPU · %2").arg((translator.language, card.modelData.vramPercent))
                            .arg((translator.language, backend.formatBytes(card.modelData.size)))
            }
            Item { Layout.fillWidth: true }
            Label {
                visible: card.modelData.contextLength > 0
                color: "#8a8a93"
                font.pixelSize: 12
                text: qsTr("%1 context").arg((translator.language,
                          card.modelData.contextLength.toLocaleString(Qt.locale(), 'f', 0)))
            }
        }
    }
}
