import QtQuick
import QtQuick.Shapes
import qs.services

// Форма «чёлки»: тело, прилипшее к верхнему краю экрана,
// скруглённые нижние углы и вогнутые «ушки» сверху.
//
//   ╭──╮                 ╭──╮   ← fillet (вогнутые)
//      │                 │
//      ╰─────────────────╯     ← radius
Shape {
    id: s
    property real bodyW: 180
    property real bodyH: 38
    property real radius: 15
    property real fillet: 10
    property color color: "black"

    readonly property real r: Math.max(0, Math.min(radius, bodyH / 2, bodyW / 2))
    readonly property real f: fillet

    width: bodyW + 2 * f
    height: bodyH
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: s.color
        strokeWidth: -1
        startX: 0; startY: 0

        PathArc { x: s.f; y: s.f; radiusX: s.f; radiusY: s.f; direction: PathArc.Clockwise }
        PathLine { x: s.f; y: s.bodyH - s.r }
        PathArc { x: s.f + s.r; y: s.bodyH; radiusX: s.r; radiusY: s.r; direction: PathArc.Counterclockwise }
        PathLine { x: s.f + s.bodyW - s.r; y: s.bodyH }
        PathArc { x: s.f + s.bodyW; y: s.bodyH - s.r; radiusX: s.r; radiusY: s.r; direction: PathArc.Counterclockwise }
        PathLine { x: s.f + s.bodyW; y: s.f }
        PathArc { x: s.width; y: 0; radiusX: s.f; radiusY: s.f; direction: PathArc.Clockwise }
        PathLine { x: 0; y: 0 }
    }
}
