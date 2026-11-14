import QtQuick
import QtQuick.Shapes
import qs.services

// Lightweight vector progress ring using QtQuick.Shapes.
// Supports determinate progress (0..1) with iOS spring smoothing and indeterminate spin.
Item {
    id: root

    property real size: Theme.px(15)
    property real strokeWidth: Theme.px(1.8)
    property real value: 0
    property bool indeterminate: false
    property color trackColor: Qt.rgba(1, 1, 1, 0.16)
    property color fillColor: Theme.text

    width: size
    height: size

    readonly property real _cx: width / 2
    readonly property real _cy: height / 2
    readonly property real _r: Math.max(1, (Math.min(width, height) - strokeWidth) / 2)
    property real _animValue: Math.max(0, Math.min(1, value))

    onValueChanged: _animValue = Math.max(0, Math.min(1, value))
    Behavior on _animValue { Spring { epsilon: 0.005 } }

    Shape {
        id: ringShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        RotationAnimation on rotation {
            running: root.indeterminate && root.visible
            from: 0
            to: 360
            duration: 950
            loops: Animation.Infinite
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root._cx
                centerY: root._cy
                radiusX: root._r
                radiusY: root._r
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.fillColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root._cx
                centerY: root._cy
                radiusX: root._r
                radiusY: root._r
                startAngle: -90
                sweepAngle: root.indeterminate ? 110 : (root._animValue * 360)
            }
        }
    }
}
