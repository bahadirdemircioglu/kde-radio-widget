/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: full

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 20
    Layout.preferredWidth: Kirigami.Units.gridUnit * 23
    Layout.preferredHeight: Kirigami.Units.gridUnit * 30

    collapseMarginsHint: true

    function volumeIconName(v) {
        if (v <= 0) return "audio-volume-muted";
        if (v <= 33) return "audio-volume-low";
        if (v <= 66) return "audio-volume-medium";
        return "audio-volume-high";
    }

    function statusColor() {
        switch (root.status) {
        case "playing": return Kirigami.Theme.positiveTextColor;
        case "connecting": return Kirigami.Theme.neutralTextColor;
        case "error": return Kirigami.Theme.negativeTextColor;
        default: return Kirigami.Theme.disabledTextColor;
        }
    }

    // ---- Üst bölüm: çalan istasyon + ses --------------------------------
    header: PlasmaExtras.PlasmoidHeading {
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2

                PlasmaComponents3.ToolButton {
                    id: playButton
                    icon.name: root.isActive ? "media-playback-stop" : "media-playback-start"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    display: QQC2.AbstractButton.IconOnly
                    text: root.isActive ? i18n("Durdur") : i18n("Çal")
                    enabled: root.stations.length > 0
                    onClicked: root.toggle()

                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaExtras.Heading {
                        Layout.fillWidth: true
                        level: 4
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: root.currentName !== "" ? root.currentName : i18n("İstasyon seçilmedi")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            width: Kirigami.Units.smallSpacing * 2
                            height: width
                            radius: width / 2
                            color: full.statusColor()
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: root.statusText()
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                            elide: Text.ElideRight
                            color: root.status === "error" ? Kirigami.Theme.negativeTextColor
                                                           : Kirigami.Theme.textColor
                        }
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "media-skip-backward"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Önceki istasyon")
                    enabled: root.stations.length > 1
                    onClicked: root.previous()

                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "media-skip-forward"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Sonraki istasyon")
                    enabled: root.stations.length > 1
                    onClicked: root.next()

                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2

                Kirigami.Icon {
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: full.volumeIconName(root.volume)
                }

                PlasmaComponents3.Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    stepSize: 1
                    value: root.volume
                    onMoved: root.setVolume(value)
                    Accessible.name: i18n("Ses seviyesi")
                }

                PlasmaComponents3.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                    horizontalAlignment: Text.AlignRight
                    text: i18nc("ses yüzdesi", "%1%", root.volume)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
            }
        }
    }

    // ---- Orta bölüm: istasyon listesi -----------------------------------
    PlasmaComponents3.ScrollView {
        id: scrollView
        anchors.fill: parent
        visible: root.stations.length > 0

        ListView {
            id: stationList
            model: root.displayStations
            clip: true
            reuseItems: false
            delegate: StationDelegate {}
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: root.stations.length === 0
        iconName: "radio"
        text: i18n("Henüz istasyon yok")
        explanation: i18n("Ayarlardan istasyon ekleyin ya da bir M3U listesi yapıştırın.")
        helpfulAction: Kirigami.Action {
            text: i18n("İstasyon ekle")
            icon.name: "list-add"
            onTriggered: root.openSettings()
        }
    }

    // ---- Alt bölüm --------------------------------------------------------
    footer: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                icon.name: "list-add"
                text: i18n("İstasyon ekle")
                onClicked: root.openSettings()
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents3.Label {
                visible: root.stations.length > 0
                text: i18np("%1 istasyon", "%1 istasyon", root.stations.length)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            PlasmaComponents3.ToolButton {
                icon.name: "configure"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Ayarlar")
                onClicked: root.openSettings()

                PlasmaComponents3.ToolTip.text: text
                PlasmaComponents3.ToolTip.visible: hovered
                PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
