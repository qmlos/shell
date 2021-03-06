// SPDX-FileCopyrightText: 2018 Pier Luigi Fiorini <pierluigi.fiorini@gmail.com>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtWayland.Compositor 1.15
import Fluid.Effects 1.0 as FluidEffects
import Liri.WaylandServer 1.0 as WS
import Liri.private.shell 1.0 as P

P.ChromeItem {
    id: chrome

    property QtObject window

    property rect taskIconGeometry: Qt.rect(0, 0, 32, 32)

    x: chrome.window.moveItem.x - shellSurfaceItem.output.position.x
    y: chrome.window.moveItem.y - shellSurfaceItem.output.position.y

    implicitWidth: chrome.window.surfaceGeometry.width + (2 * chrome.window.borderSize)
    implicitHeight: chrome.window.surfaceGeometry.height + (2 * chrome.window.borderSize) + chrome.window.titleBarHeight

    shellSurfaceItem: shellSurfaceItem

    // FIXME: Transparent backgrounds will be opaque due to shadows
    layer.enabled: chrome.window.mapped && chrome.window.bordered
    layer.effect: FluidEffects.Elevation {
        elevation: shellSurfaceItem.focus ? 24 : 8
    }

    transform: [
        Scale {
            id: scaleTransform
            origin.x: chrome.width / 2
            origin.y: chrome.height / 2
        },
        Scale {
            id: scaleTransformPos
            origin.x: chrome.width / 2
            origin.y: chrome.y - shellSurfaceItem.output.position.y - chrome.height
        }
    ]

    QtObject {
        id: __private

        property point moveItemPosition

        function setPosition() {
            if (chrome.window.windowType === Qt.Popup)
                return;

            var parentSurfaceItem = shellSurfaceItem.output.viewsBySurface[chrome.window.parentSurface];
            if (parentSurfaceItem) {
                chrome.window.moveItem.x = parentSurfaceItem.window.moveItem.x + ((parentSurfaceItem.width - chrome.width) / 2);
                chrome.window.moveItem.y = parentSurfaceItem.window.moveItem.y + ((parentSurfaceItem.height - chrome.height) / 2);
            } else {
                var pos = chrome.randomPosition(liriCompositor.mousePos);
                chrome.window.moveItem.x = pos.x;
                chrome.window.moveItem.y = pos.y;
            }
        }

        function giveFocusToParent() {
            // Give focus back to the parent
            var parentSurfaceItem = shellSurfaceItem.output.viewsBySurface[chrome.window.parentSurface];
            if (parentSurfaceItem)
                parentSurfaceItem.takeFocus();
        }
    }

    Connections {
        target: chrome.window
        ignoreUnknownSignals: true

        function onMappedChanged() {
            if (chrome.window.mapped) {
                if (chrome.window.focusable)
                    takeFocus();
                __private.setPosition();
                mapAnimation.start();
            }
        }
        function onActivatedChanged() {
            if (chrome.window.activated)
                chrome.raise();
        }
        function onMinimizedChanged() {
            if (chrome.window.minimized)
                minimizeAnimation.start();
            else
                unminimizeAnimation.start();
        }
        function onShowWindowMenu(seat, localSurfacePosition) {
            showWindowMenu(localSurfacePosition.x, localSurfacePosition.y);
        }
    }

    Connections {
        target: shellSurfaceItem.output

        function onGeometryChanged() {
            if (!chrome.primary)
                return;

            // Resize fullscreen windows as the geometry changes
            if (chrome.window.fullscreen)
                chrome.window.sendFullscreen(shellSurfaceItem.output);
        }
        function onAvailableGeometryChanged() {
            if (!chrome.primary)
                return;

            // Resize maximized windows as the available geometry changes
            if (chrome.window.maximized)
                chrome.window.sendMaximized(shellSurfaceItem.output);
        }
    }

    Decoration {
        id: decoration

        anchors.fill: parent
        drag.target: chrome.window.moveItem
        enabled: chrome.window.decorated
        visible: chrome.window.mapped && enabled
    }

    ShellSurfaceItem {
        id: shellSurfaceItem

        x: chrome.window.borderSize
        y: chrome.window.borderSize + chrome.window.titleBarHeight

        shellSurface: chrome.window.shellSurface
        moveItem: chrome.window.moveItem

        inputEventsEnabled: !output.locked
        autoCreatePopupItems: true

        focusOnClick: chrome.window.focusable

        onSurfaceDestroyed: {
            bufferLocked = true;
            destroyAnimation.start();
        }

        // Drag windows with Meta
        DragHandler {
            id: dragHandler

            acceptedModifiers: liriCompositor.settings.windowActionModifier
            target: shellSurfaceItem.moveItem
            property var movingBinding: Binding {
                target: shellSurfaceItem.moveItem
                property: "moving"
                value: dragHandler.active
            }
        }

        /*
         * Animations
         */

        Behavior on width {
            SmoothedAnimation { alwaysRunToEnd: true; easing.type: Easing.InOutQuad; duration: 350 }
        }

        Behavior on height {
            SmoothedAnimation { alwaysRunToEnd: true; easing.type: Easing.InOutQuad; duration: 350 }
        }
    }

    ChromeMenu {
        id: chromeMenu
    }

    /*
     * Animations for creation and destruction
     */

    ParallelAnimation {
        id: mapAnimation

        alwaysRunToEnd: true

        NumberAnimation { target: chrome; property: "scale"; from: 0.9; to: 1.0; easing.type: Easing.OutQuint; duration: 220 }
        NumberAnimation { target: chrome; property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.OutCubic; duration: 150 }
    }

    SequentialAnimation {
        id: destroyAnimation

        alwaysRunToEnd: true

        ParallelAnimation {
            NumberAnimation { target: chrome; property: "scale"; from: 1.0; to: 0.9; easing.type: Easing.OutQuint; duration: 220 }
            NumberAnimation { target: chrome; property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.OutCubic; duration: 150 }
        }

        ScriptAction {
            script: {
                __private.giveFocusToParent();
                chrome.destroy();

                if (chrome.primary)
                    liriCompositor.handleShellSurfaceDestroyed(window);
            }
        }
    }

    /*
     * Animations when the window is minimized or unminimized
     */

    SequentialAnimation {
        id: minimizeAnimation

        alwaysRunToEnd: true

        ScriptAction {
            script: {
                __private.moveItemPosition.x = shellSurfaceItem.moveItem.x;
                __private.moveItemPosition.y = shellSurfaceItem.moveItem.y;
                moveItem.animateTo(taskIconGeometry.x, taskIconGeometry.y);
            }
        }

        ParallelAnimation {
            NumberAnimation { target: chrome; property: "scale"; easing.type: Easing.OutQuad; to: 0.0; duration: 550 }
            NumberAnimation { target: chrome; property: "opacity"; easing.type: Easing.Linear; to: 0.0; duration: 500 }
        }
    }

    SequentialAnimation {
        id: unminimizeAnimation

        alwaysRunToEnd: true

        ScriptAction {
            script: {
                moveItem.animateTo(__private.moveItemPosition.x, __private.moveItemPosition.y);
            }
        }

        ParallelAnimation {
            NumberAnimation { target: chrome; property: "scale"; easing.type: Easing.OutQuad; to: 1.0; duration: 550 }
            NumberAnimation { target: chrome; property: "opacity"; easing.type: Easing.Linear; to: 1.0; duration: 500 }
        }
    }

    /*
     * Methods
     */

    function showWindowMenu(x, y) {
        chromeMenu.x = x;
        chromeMenu.y = y;
        chromeMenu.open();
    }
}
