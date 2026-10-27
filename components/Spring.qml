import QtQuick
import qs.services

// Пружина в стиле iOS. Сохраняет скорость при перенацеливании,
// поэтому прерванная анимация продолжается плавно, без рывка.
SpringAnimation {
    spring: Theme.springK
    damping: Theme.springDamp
    epsilon: 0.25
}
