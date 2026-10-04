import QtQuick
import qs.Commons

// DSpinner: 12 short ticks in a ring with descending alpha, rotating (DESIGN §3.5.4)
Item {
  id: root

  property bool running: true
  property color color: Color.onShell
  property int size: Style.baseWidgetSize
  property int strokeWidth: Style.borderM
  property int duration: Style.animationSlow * 2

  implicitWidth: size
  implicitHeight: size

  onColorChanged: canvas.requestPaint()
  onStrokeWidthChanged: canvas.requestPaint()

  // GPU-optimized spinner - draw once, rotate with GPU transform
  Item {
    id: spinner
    anchors.fill: parent

    // Static canvas - drawn ONCE, then cached
    Canvas {
      id: canvas
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative // Better performance than Threaded for simple shapes
      renderTarget: Canvas.FramebufferObject // GPU texture

      // Enable layer caching - critical for performance!
      layer.enabled: true
      layer.smooth: true

      Component.onCompleted: {
        requestPaint();
      }

      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        var cx = width / 2;
        var cy = height / 2;
        var ticks = 12;
        var outer = Math.min(width, height) / 2 - Math.max(1, root.strokeWidth) / 2;
        var inner = outer * 0.45;
        var c = root.color;

        ctx.lineWidth = Math.max(1, root.strokeWidth);
        ctx.lineCap = "round";

        for (var i = 0; i < ticks; i++) {
          var angle = (i * Math.PI * 2 / ticks) - Math.PI / 2;
          var alpha = 1.0 - (i / ticks) * 0.85;
          ctx.strokeStyle = "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (alpha * c.a).toFixed(3) + ")";
          ctx.beginPath();
          ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
          ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
          ctx.stroke();
        }
      }
    }

    // Smooth rotation animation - uses GPU transform, NO canvas repaints!
    RotationAnimation on rotation {
      running: root.running
      from: 0
      to: 360
      duration: root.duration
      loops: Animation.Infinite
    }
  }
}
