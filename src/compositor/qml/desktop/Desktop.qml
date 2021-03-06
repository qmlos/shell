// SPDX-FileCopyrightText: 2017 Michael Spencer <sonrisesoftware@gmail.com>
// SPDX-FileCopyrightText: 2018 Pier Luigi Fiorini <pierluigi.fiorini@gmail.com>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtWayland.Compositor 1.0 as QtWaylandCompositor
import QtGraphicalEffects 1.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import Fluid.Controls 1.0 as FluidControls
import Fluid.Effects 1.0 as FluidEffects
import Liri.WaylandServer 1.0 as WS
import Liri.Shell 1.0 as LS
import Liri.private.shell 1.0 as P
import ".."
import "../components" as Components
import "../indicators" as Indicators
import "../screens" as Screens

Item {
    id: desktop

    Material.theme: Material.Dark
    Material.primary: Material.Blue
    Material.accent: Material.Blue

    property bool cursorVisible: true

    readonly property alias backgroundLayer: backgroundLayer
    readonly property alias bottomLayer: bottomLayer
    readonly property alias topLayer: topLayer
    readonly property alias overlayLayer: overlayLayer
    readonly property alias workspacesView: workspacesView
    readonly property alias surfacesArea: workspacesView.currentWorkspace
    readonly property alias currentWorkspace: workspacesView.currentWorkspace

    readonly property var layers: QtObject {
        readonly property alias fullScreen: fullScreenLayer
    }

    readonly property alias shell: shell
    readonly property var panel: shell.panel
    readonly property alias runCommand: runCommand
    readonly property alias authDialog: authDialog
    readonly property alias windowSwitcher: windowSwitcher

    property alias showFps: fpsIndicator.visible
    property alias showInformation: outputInfo.visible
    property alias zoomEnabled: zoomArea.enabled

    state: "splash"
    states: [
        State {
            name: "splash"
            PropertyChanges { target: desktop; cursorVisible: false }
            PropertyChanges { target: splashScreen; opacity: 1.0 }
        },
        State {
            name: "session"
            PropertyChanges { target: desktop; cursorVisible: true }
        },
        State {
            name: "logout"
            PropertyChanges { target: desktop; cursorVisible: true }
            PropertyChanges { target: logoutScreen; active: true }
        },
        State {
            name: "poweroff"
            PropertyChanges { target: desktop; cursorVisible: true }
            PropertyChanges { target: powerScreen; active: true }
        },
        State {
            name: "restart"
            PropertyChanges { target: desktop; cursorVisible: true }
            PropertyChanges { target: powerScreen; active: true }
        },
        State {
            name: "lock"
            PropertyChanges { target: desktop   ; cursorVisible: true }
            PropertyChanges { target: lockScreenLoader; loadComponent: true }
            // FIXME: Before suspend we lock the screen, but turning the output off has a side effect:
            // when the system is resumed it won't flip so we comment this out but unfortunately
            // it means that the lock screen will not turn off the screen
            //StateChangeScript { script: output.idle() }
        }
    ]

    transform: Scale {
        id: screenScaler

        origin.x: zoomArea.x2
        origin.y: zoomArea.y2
        xScale: zoomArea.zoom2
        yScale: zoomArea.zoom2
    }

    ScreenZoom {
        id: zoomArea

        anchors.fill: parent
        scaler: screenScaler
        enabled: false
    }

    Connections {
        target: SessionInterface

        function onSessionLocked() {
            desktop.state = "lock";
        }
        function onSessionUnlocked() {
            desktop.state = "session";
        }
        function onIdleInhibitRequested() {
            liriCompositor.idleInhibit++;
        }
        function onIdleUninhibitRequested() {
            liriCompositor.idleInhibit--;
        }
    }

    /*
     * Workspace
     */

    // Background
    Item {
        id: backgroundLayer

        anchors.fill: parent
    }

    // Bottom
    Item {
        id: bottomLayer

        anchors.fill: parent
    }

    WorkspacesView {
        id: workspacesView
    }

    // Top
    Item {
        id: topLayer

        anchors.fill: parent
    }

    // Overlays
    Item {
        id: overlayLayer

        anchors.fill: parent
    }

    // Panels
    Shell {
        id: shell

        anchors.fill: parent
        opacity: currentWorkspace.state == "present" ? 0.0 : 1.0
        visible: output.primary

        Behavior on opacity {
            NumberAnimation {
                easing.type: Easing.OutQuad
                duration: 250
            }
        }
    }

    // Full screen windows can cover application windows and panels
    Rectangle {
        id: fullScreenLayer

        anchors.fill: parent
        color: "black"
        opacity: children.length > 0 ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                easing.type: Easing.InSine
                duration: FluidControls.Units.mediumDuration
            }
        }
    }

    /*
     * Run command dialog
     */

    RunCommand {
        id: runCommand

        x: (parent.width - height) / 2
        y: (parent.height - height) / 2
    }

    /*
     * Authentication
     */

    Screens.AuthDialog {
        id: authDialog

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
    }

    /*
     * Windows switcher
     */

    WindowSwitcher {
        id: windowSwitcher

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
    }

    /*
     * Logout and power off
     */

    Screens.LogoutScreen {
        id: logoutScreen

        onCanceled: desktop.state = "session"
    }

    Screens.PowerScreen {
        id: powerScreen

        onCanceled: desktop.state = "session"
    }

    /*
     * Hot corners
     */

    Item {
        anchors.fill: parent

        // Top-left corner
        Components.HotCorner {
            corner: Qt.TopLeftCorner
        }

        // Top-right corner
        Components.HotCorner {
            corner: Qt.TopRightCorner
        }

        // Bottom-left corner
        Components.HotCorner {
            corner: Qt.BottomLeftCorner
            onTriggered: {
                if (workspacesView.currentWorkspace.state === "normal")
                    workspacesView.currentWorkspace.state = "present";
                else
                    workspacesView.currentWorkspace.state = "normal";
            }
        }

        // Bottom-right corner
        Components.HotCorner {
            corner: Qt.BottomRightCorner
        }
    }

    /*
     * Lock screen
     */

    Component {
        id: primaryLockScreenComponent

        Screens.LockScreen {
            primary: true
        }
    }

    Component {
        id: secondaryLockScreenComponent

        Screens.LockScreen {
            primary: false
        }
    }

    FluidControls.Loadable {
        id: lockScreenLoader

        property bool loadComponent: false

        x: 0
        y: 0
        width: parent.width
        height: parent.height
        asynchronous: true
        component: output.primary ? primaryLockScreenComponent : secondaryLockScreenComponent
        onLoadComponentChanged: if (loadComponent) show(); else hide();
    }

    /*
     * Splash screen
     */

    Loader {
        id: splashScreen

        anchors.fill: parent
        source: "../screens/SplashScreen.qml"
        opacity: 0.0
        active: false
        z: 900
        onOpacityChanged: {
            if (opacity == 1.0)
                splashScreen.active = true;
            else if (opacity == 0.0)
                splashScreenTimer.start();
        }

        // Unload after a while so that the opacity animation is visible
        Timer {
            id: splashScreenTimer

            running: false
            interval: 5000
            onTriggered: splashScreen.active = false
        }

        Behavior on opacity {
            NumberAnimation {
                easing.type: Easing.InSine
                duration: FluidControls.Units.longDuration
            }
        }
    }

    /*
     * Full screen indicators
     */

    Text {
        id: fpsIndicator

        anchors {
            top: parent.top
            right: parent.right
        }
        text: fpsCounter.framesPerSecond.toFixed(2)
        font.pointSize: 36
        style: Text.Raised
        styleColor: "#222"
        color: "white"
        z: 1000
        visible: false

        P.FpsCounter {
            id: fpsCounter
        }
    }

    OutputInfo {
        id: outputInfo

        anchors {
            left: parent.left
            top: parent.top
        }
        z: 1000
        visible: false
    }

    /*
     * Methods
     */

    function handleKeyPressed(event) {
        // Handle Meta modifier
        if (event.modifiers & Qt.MetaModifier) {
            // Open window switcher
            if (output.primary) {
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    desktop.windowSwitcher.next();
                    return;
                } else if (event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                    desktop.windowSwitcher.previous();
                    return;
                }
            }
        }

        // Power off and suspend
        switch (event.key) {
        case Qt.Key_PowerOff:
        case Qt.Key_PowerDown:
        case Qt.Key_Suspend:
        case Qt.Key_Hibernate:
            if (desktop.state != "lock")
                desktop.state = "poweroff";
            event.accepted = true;
            return;
        default:
            break;
        }

        event.accepted = false;
    }

    function handleKeyReleased(event) {
        // Handle Meta modifier
        if (event.modifiers & Qt.MetaModifier) {
            // Close window switcher
            if (output.primary) {
                if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                    event.accepted = true;
                    desktop.windowSwitcher.close();
                    desktop.windowSwitcher.activate();
                    return;
                }
            }
        }

        event.accepted = false;
    }
}
