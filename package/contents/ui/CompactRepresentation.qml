/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    property int wheelAccumulator: 0

    Layout.minimumWidth: Kirigami.Units.iconSizes.small
    Layout.minimumHeight: Kirigami.Units.iconSizes.small

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: root.toolTipMainText
    Accessible.description: root.toolTipSubText
    Accessible.onPressAction: root.expanded = !root.expanded

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            if (Plasmoid.configuration.middleClickToggles) root.toggle();
        } else {
            root.expanded = !root.expanded;
        }
    }

    // Tekerlek: her 120 birimlik adımda %5 ses
    onWheel: wheel => {
        wheelAccumulator += wheel.angleDelta.y;
        while (Math.abs(wheelAccumulator) >= 120) {
            var step = wheelAccumulator > 0 ? 5 : -5;
            root.setVolume(root.volume + step);
            wheelAccumulator -= (wheelAccumulator > 0 ? 120 : -120);
        }
    }

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: Plasmoid.icon
        active: compact.containsMouse
        isMask: true
        color: {
            switch (root.status) {
            case "playing": return Kirigami.Theme.highlightColor;
            case "error": return Kirigami.Theme.negativeTextColor;
            case "connecting": return Kirigami.Theme.disabledTextColor;
            default: return Kirigami.Theme.textColor;
            }
        }
    }

    // Çalıyor: yeşil nokta
    Rectangle {
        visible: root.status === "playing"
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(5, Math.round(parent.width / 3.5))
        height: width
        radius: width / 2
        color: Kirigami.Theme.positiveTextColor
        border.width: 1
        border.color: Kirigami.Theme.backgroundColor
    }

    // Bağlanıyor: dönen gösterge
    PlasmaComponents3.BusyIndicator {
        visible: root.status === "connecting"
        running: visible
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(8, Math.round(parent.width / 2))
        height: width
        padding: 0
    }

    // Hata: kırmızı ünlem rozeti
    Rectangle {
        visible: root.status === "error"
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(7, Math.round(parent.width / 2.4))
        height: width
        radius: width / 2
        color: Kirigami.Theme.negativeTextColor
        border.width: 1
        border.color: Kirigami.Theme.backgroundColor

        Text {
            anchors.centerIn: parent
            text: "!"
            color: Kirigami.Theme.highlightedTextColor
            font.bold: true
            font.pixelSize: Math.max(6, Math.round(parent.height * 0.75))
        }
    }
}
