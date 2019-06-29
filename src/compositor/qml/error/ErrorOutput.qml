/****************************************************************************
 * This file is part of Liri.
 *
 * Copyright (C) 2018 Pier Luigi Fiorini <pierluigi.fiorini@gmail.com>
 *
 * $BEGIN_LICENSE:GPL3+$
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * $END_LICENSE$
 ***************************************************************************/

import QtQuick 2.5
import QtQuick.Window 2.3
import QtWayland.Compositor 1.0
import Liri.WaylandServer 1.0 as WS
import Liri.private.shell 1.0 as P

P.WaylandOutput {
    id: output

    readonly property bool primary: liriCompositor.defaultOutput === this

    property var screen: null

    Component.onCompleted: {
        if (output.screen) {
            for (var i = 0; i < output.screen.modes.length; i++) {
                var screenMode = output.screen.modes[i];
                var isPreferred = output.screen.preferredMode === screenMode;
                var isCurrent = output.screen.currentMode === screenMode;
                output.addOutputMode(screenMode.resolution, screenMode.refreshRate, isPreferred, isCurrent);
            }
        }
    }

    window: Window {
        id: outputWindow

        x: output.position.x
        y: output.position.y
        width: output.geometry.width
        height: output.geometry.height
        flags: Qt.Window | Qt.FramelessWindowHint
        screen: output.screen ? Qt.application.screens[output.screen.screenIndex] : null
        color: "black"
        visible: true

        // Grab surface from shell helper
        WaylandQuickItem {
            id: grabItem
            focusOnClick: false
            onSurfaceChanged: {
                shellHelper.grabCursor(WS.LiriShell.ArrowGrabCursor);
                if (output.primary)
                    grabItem.setPrimary();
            }
        }

        WaylandMouseTracker {
            id: mouseTracker
            anchors.fill: parent
            windowSystemCursorEnabled: Qt.platform.pluginName !== "liri"

            ErrorScreenView {
                id: screenView
                anchors.fill: parent
            }

            WaylandCursorItem {
                id: cursor
                seat: liriCompositor.defaultSeat
                x: mouseTracker.mouseX - hotspotX
                y: mouseTracker.mouseY - hotspotY
                visible: mouseTracker.containsMouse && !mouseTracker.windowSystemCursorEnabled
            }
        }
    }
}
