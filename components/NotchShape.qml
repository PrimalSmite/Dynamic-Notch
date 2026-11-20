import QtQuick
import QtQuick.Shapes

// Notch shape: body attached to the top edge of the screen,
// rounded bottom corners and concave upper ears (fillets).
// Uses native Rectangle primitives for the resizing body + static corner ear Shapes
// so bw/bh spring animations never trigger expensive curve re-tessellation on GPU.
Item {
    id: s
    property real bodyW: 180
    property real bodyH: 38
    property real radius: 15
    property real fillet: 10
    property color color: "black"
    property color glowColor: "transparent"
    property real glowOpacity: 0

    readonly property real r: Math.max(0, Math.min(radius, bodyH / 2, bodyW / 2))
    readonly property real f: fillet

    width: bodyW + 2 * f
    height: bodyH

    // Upper flush cap (covers top rounded corners of the body Rectangle)
    Rectangle {
        x: s.f
        y: 0
        width: s.bodyW
        height: Math.min(s.bodyH, s.r)
        color: s.color
    }

    // Main rounded-bottom body
    Rectangle {
        x: s.f
        y: 0
        width: s.bodyW
        height: s.bodyH
        radius: s.r
        color: s.color
        clip: true

        // Subtle ambient rim glow (no shader/tessellation overhead)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: -s.r
            radius: s.r
            color: "transparent"
            border.width: 1.25
            border.color: s.glowColor
            opacity: s.glowOpacity
            visible: opacity > 0.005
            Behavior on border.color { ColorAnimation { duration: 240 } }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }
    }

    // Static left concave ear
    Shape {
        x: 0
        y: 0
        width: s.f + 1
        height: s.f
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: s.color
            strokeWidth: -1
            startX: 0; startY: 0
            PathArc { x: s.f; y: s.f; radiusX: s.f; radiusY: s.f; direction: PathArc.Clockwise }
            PathLine { x: s.f + 1; y: s.f }
            PathLine { x: s.f + 1; y: 0 }
            PathLine { x: 0; y: 0 }
        }
    }

    // Static right concave ear
    Shape {
        x: s.f + s.bodyW - 1
        y: 0
        width: s.f + 1
        height: s.f
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: s.color
            strokeWidth: -1
            startX: 0; startY: 0
            PathLine { x: s.f + 1; y: 0 }
            PathArc { x: 1; y: s.f; radiusX: s.f; radiusY: s.f; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: s.f }
            PathLine { x: 0; y: 0 }
        }
    }
}
