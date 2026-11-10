import QtQuick
import qs.services

// iOS-style spring. Preserves velocity when retargeted,
// so an interrupted animation continues smoothly without jarring.
SpringAnimation {
    spring: Theme.springK
    damping: Theme.springDamp
    epsilon: 0.25
}
