import QtQuick

// A 0-100 history line. The window is a fixed number of samples, so the line
// grows in from the right instead of stretching as data arrives.
Canvas {
    id: spark

    property var values: []
    property color lineColor: theme.accent
    readonly property int window: 60

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        // Faint guides at the quarters keep an empty graph from looking broken.
        ctx.strokeStyle = "#26262b"
        ctx.lineWidth = 1
        for (var g = 1; g < 4; ++g) {
            var gy = Math.round(height * g / 4) + 0.5
            ctx.beginPath()
            ctx.moveTo(0, gy)
            ctx.lineTo(width, gy)
            ctx.stroke()
        }

        var n = values.length
        if (n < 2)
            return

        var step = width / (window - 1)
        var firstX = width - (n - 1) * step
        function y(v) { return height - 2 - (height - 4) * Math.max(0, Math.min(100, v)) / 100 }

        ctx.beginPath()
        ctx.moveTo(firstX, y(values[0]))
        for (var i = 1; i < n; ++i)
            ctx.lineTo(firstX + i * step, y(values[i]))

        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.stroke()

        ctx.lineTo(width, height)
        ctx.lineTo(firstX, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.14)
        ctx.fill()
    }
}
