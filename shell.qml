//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// Динамический остров для Hyprland.
// Запуск:  qs -p /путь/к/этой/папке   (или скопируй в ~/.config/quickshell)
ShellRoot {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bgWin
            required property ShellScreen modelData
            screen: modelData
            visible: Wallpapers.active && Wallpapers.currentWall !== ""
            color: "#000000"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "dynamic-island-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            readonly property string targetSource: Wallpapers.fileUrl(Wallpapers.currentWall)

            onTargetSourceChanged: {
                if (!targetSource) return;
                fadeAnim.stop();
                frontImg.opacity = 0;
                frontImg.scale = 1.03;
                frontImg.source = targetSource;
                if (frontImg.status === Image.Ready)
                    fadeAnim.restart();
            }

            Component.onCompleted: {
                if (targetSource) {
                    backImg.source = targetSource;
                    frontImg.source = targetSource;
                    frontImg.opacity = 1;
                    frontImg.scale = 1.0;
                }
            }

            Image {
                id: backImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: modelData ? Qt.size(modelData.width, modelData.height) : undefined
            }

            Image {
                id: frontImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: modelData ? Qt.size(modelData.width, modelData.height) : undefined
                opacity: 0
                scale: 1.03

                onStatusChanged: {
                    if (status === Image.Ready && opacity < 1 && !fadeAnim.running)
                        fadeAnim.restart();
                }

                ParallelAnimation {
                    id: fadeAnim
                    NumberAnimation {
                        target: frontImg
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 420
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: frontImg
                        property: "scale"
                        from: 1.03
                        to: 1.0
                        duration: 480
                        easing.type: Easing.OutCubic
                    }
                    onFinished: {
                        backImg.source = frontImg.source;
                        frontImg.source = "";
                        frontImg.opacity = 0;
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        Island {}
    }

    Component.onCompleted: {
        void Clipboard.count;
    }
}
