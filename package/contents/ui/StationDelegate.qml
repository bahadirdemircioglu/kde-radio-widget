/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "PlaylistResolver.js" as Playlist

PlasmaComponents3.ItemDelegate {
    id: delegate

    required property int index
    required property var model

    readonly property int stationIndex: model.origIndex
    readonly property bool isCurrent: stationIndex === root.currentIndex
    readonly property bool isErrored: isCurrent && root.status === "error"
    readonly property string subtitle: {
        var host = Playlist.hostOf(model.url);
        var kind = Playlist.streamKind(model.url);
        if (host && kind) return host + " · " + kind;
        return host || kind || model.url;
    }

    width: ListView.view ? ListView.view.width : implicitWidth
    highlighted: isCurrent
    text: model.name

    Accessible.name: model.name
    Accessible.description: isCurrent ? root.statusText() : subtitle

    onClicked: {
        if (isCurrent && root.isActive) root.stop();
        else root.playStation(stationIndex);
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: root.status === "connecting" ? "view-refresh"
                  : root.status === "error" ? "dialog-error"
                  : "media-playback-start"
            opacity: delegate.isCurrent && root.status !== "idle" ? 1 : 0
            isMask: true
            color: root.status === "error" ? Kirigami.Theme.negativeTextColor
                                           : Kirigami.Theme.highlightColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: delegate.model.name
                elide: Text.ElideRight
                font.weight: delegate.isCurrent ? Font.DemiBold : Font.Normal
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showHost || delegate.isErrored
                text: delegate.isErrored ? root.errorText : delegate.subtitle
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: delegate.isErrored ? 1 : 0.65
                color: delegate.isErrored ? Kirigami.Theme.negativeTextColor
                                          : Kirigami.Theme.textColor
            }
        }

        PlasmaComponents3.ToolButton {
            icon.name: delegate.model.favorite ? "starred-symbolic" : "non-starred-symbolic"
            display: QQC2.AbstractButton.IconOnly
            text: delegate.model.favorite ? i18n("Favorilerden çıkar") : i18n("Favorilere ekle")
            opacity: delegate.model.favorite || delegate.hovered ? 1 : 0.35
            onClicked: root.toggleFavorite(delegate.stationIndex)

            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }
}
