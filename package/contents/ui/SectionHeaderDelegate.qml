/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Akordiyon başlığı: tıklanınca bölüm açılır/kapanır.
PlasmaComponents3.ItemDelegate {
    id: header

    required property int index
    required property var model

    readonly property bool expanded: model.expanded
    // Çalan istasyon bu bölümdeyse başlıkta küçük bir işaret göster.
    readonly property bool holdsCurrent: root.currentIndex >= 0 && root.sectionOf(root.currentIndex) === model.section

    width: ListView.view ? ListView.view.width : implicitWidth
    text: model.section

    Accessible.role: Accessible.Button
    Accessible.name: expanded ? i18n("%1 bölümünü kapat", model.section) : i18n("%1 bölümünü aç", model.section)

    onClicked: root.toggleSection(model.section)

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: header.expanded ? "arrow-down" : "arrow-right"
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: header.model.section
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.85
        }

        Kirigami.Icon {
            visible: header.holdsCurrent && !header.expanded && root.isActive
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "media-playback-start"
            isMask: true
            color: Kirigami.Theme.highlightColor
        }

        PlasmaComponents3.Label {
            text: header.model.stationCount
            font: Kirigami.Theme.smallFont
            opacity: 0.6
        }
    }
}
