import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Everything Ollama will tell us about one model, from /api/show, plus how it
// is loaded right now when it is.
Dialog {
    id: dialog

    readonly property var info: backend.detail

    // The live entry for this model while it is in memory.
    readonly property var loaded: {
        for (var i = 0; i < backend.running.length; ++i)
            if (backend.running[i].name === info.name)
                return backend.running[i]
        return null
    }

    function count(n) {
        if (n >= 1e9) return (n / 1e9).toLocaleString(Qt.locale(), 'f', 1) + "B"
        if (n >= 1e6) return (n / 1e6).toLocaleString(Qt.locale(), 'f', 0) + "M"
        return n.toLocaleString(Qt.locale(), 'f', 0)
    }

    // Label and value pairs; anything Ollama didn't report is left out.
    readonly property var rows: {
        translator.language
        var d = info, out = []
        function add(label, value) {
            if (value !== undefined && value !== null && value !== "" && value !== 0)
                out.push({ label: label, value: value })
        }
        if (loaded)
            add(qsTr("Loaded"), loaded.sizeVram <= 0
                ? qsTr("On CPU, %1 context").arg(loaded.contextLength.toLocaleString(Qt.locale(), 'f', 0))
                : qsTr("%1% on GPU, %2 context").arg(loaded.vramPercent)
                      .arg(loaded.contextLength.toLocaleString(Qt.locale(), 'f', 0)))
        add(qsTr("Architecture"), d.architecture)
        add(qsTr("Parameters"), d.parameterCount > 0 ? count(d.parameterCount) : d.parameterSize)
        add(qsTr("Quantization"), d.quantization)
        add(qsTr("Format"), d.format)
        add(qsTr("Runner"), d.runner)
        add(qsTr("Layers"), d.blockCount > 0 ? d.blockCount.toLocaleString(Qt.locale(), 'f', 0) : "")
        add(qsTr("Embedding size"), d.embeddingLength > 0 ? d.embeddingLength.toLocaleString(Qt.locale(), 'f', 0) : "")
        add(qsTr("Max context"), d.contextLength > 0 ? d.contextLength.toLocaleString(Qt.locale(), 'f', 0) : "")
        add(qsTr("Size on disk"), d.size > 0 ? backend.formatBytes(d.size) : "")
        add(qsTr("Modified"), d.modified && d.modified.getTime() > 0
            ? d.modified.toLocaleDateString(Qt.locale(), Locale.LongFormat) : "")
        add(qsTr("License"), d.license)
        add(qsTr("Digest"), d.digest ? String(d.digest).replace("sha256:", "").substring(0, 12) : "")
        return out
    }

    modal: true
    anchors.centerIn: Overlay.overlay
    width: 520
    height: Math.min(parent ? parent.height - 80 : 640, 680)
    Material.roundedScale: theme.radius

    background: Rectangle {
        color: "#17171a"
        radius: theme.radius
        border.color: "#26262b"
    }
    Overlay.modal: Rectangle { color: "#99000000" }
    // No fade, so it is fully drawn the moment it opens.
    enter: Transition {}
    exit: Transition {}

    header: Item {
        implicitHeight: 64
        Label {
            x: 24
            width: parent.width - 48
            anchors.verticalCenter: parent.verticalCenter
            text: dialog.info.name || ""
            elide: Text.ElideRight
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    contentItem: ScrollView {
        id: scroll
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 16

            Label {
                visible: backend.detailLoading
                text: qsTr("Loading…")
                color: "#8a8a93"
            }
            Label {
                visible: backend.detailError.length > 0
                text: qsTr("Couldn't read this model: %1").arg(backend.detailError)
                color: "#ff8f87"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Ollama's own capability names, so they are not translated.
            Flow {
                visible: (dialog.info.capabilities || []).length > 0
                spacing: 6
                Layout.fillWidth: true

                Repeater {
                    model: dialog.info.capabilities || []
                    Rectangle {
                        required property string modelData
                        implicitWidth: chip.implicitWidth + 20
                        implicitHeight: chip.implicitHeight + 8
                        radius: Math.min(4, theme.radius)
                        color: "#222226"
                        Label {
                            id: chip
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.pixelSize: 12
                        }
                    }
                }
            }

            GridLayout {
                columns: 2
                columnSpacing: 24
                rowSpacing: 8
                Layout.fillWidth: true

                Repeater {
                    model: dialog.rows
                    delegate: Item {
                        id: cell
                        required property var modelData
                        // Two grid cells per row: this label, then its value below.
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        implicitHeight: Math.max(name.implicitHeight, value.implicitHeight)

                        Label {
                            id: name
                            width: 140
                            text: cell.modelData.label
                            color: "#8a8a93"
                            font.pixelSize: 13
                        }
                        Label {
                            id: value
                            x: 150
                            width: parent.width - 150
                            text: String(cell.modelData.value)
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                        }
                    }
                }
            }

            ColumnLayout {
                visible: (dialog.info.parameters || "").length > 0
                spacing: 6
                Layout.fillWidth: true

                Label {
                    text: qsTr("Default parameters")
                    color: "#8a8a93"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Label {
                    text: dialog.info.parameters || ""
                    font.family: "monospace"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                visible: (dialog.info.template || "").length > 0
                spacing: 6
                Layout.fillWidth: true

                Label {
                    text: qsTr("Template")
                    color: "#8a8a93"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Label {
                    // Chat templates can run to pages; the start is enough to recognise one.
                    text: {
                        var t = dialog.info.template || ""
                        return t.length > 600 ? t.substring(0, 600) + "…" : t
                    }
                    font.family: "monospace"
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                }
            }
        }
    }

    footer: Item {
        implicitHeight: 60

        Button {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Close")
            flat: true
            Material.foreground: "#e8e8ea"
            focusPolicy: Qt.NoFocus
            onClicked: dialog.close()
        }
    }
}
