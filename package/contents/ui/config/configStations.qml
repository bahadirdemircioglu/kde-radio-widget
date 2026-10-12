/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../StationsLogic.js" as Stations

KCM.ScrollViewKCM {
    id: page

    // Ayar penceresi bu özellikleri main.xml'deki anahtarlarla doldurur ve
    // Tamam/Uygula'da geri okur.
    property string cfg_stations
    property string cfg_lastStationUrl
    property int cfg_volume
    property bool cfg_autoplayLast
    property bool cfg_showHost
    property bool cfg_middleClickToggles

    // Kendi yazdığımız JSON; dışarıdan gelen bir değişiklikle ayırt etmek için.
    property string _lastWritten: ""

    ListModel {
        id: stationsModel
    }

    function loadFromConfig() {
        stationsModel.clear();
        var list = Stations.parse(cfg_stations);
        for (var i = 0; i < list.length; i++)
            stationsModel.append(list[i]);
        _lastWritten = cfg_stations;
    }

    function save() {
        var list = [];
        for (var i = 0; i < stationsModel.count; i++) {
            var row = stationsModel.get(i);
            list.push({ name: row.name, url: row.url, favorite: row.favorite === true });
        }
        _lastWritten = Stations.serialize(list);
        cfg_stations = _lastWritten;
    }

    function addStation(name, url, favorite) {
        stationsModel.append({ name: name || "", url: url || "", favorite: favorite === true });
        save();
    }

    function removeStation(index) {
        stationsModel.remove(index);
        save();
    }

    function moveStation(from, to) {
        if (to < 0 || to >= stationsModel.count || from === to) return;
        stationsModel.move(from, to, 1);
        save();
    }

    function importText(text) {
        var incoming = Stations.parseImport(text);
        var existing = {};
        for (var i = 0; i < stationsModel.count; i++)
            existing[stationsModel.get(i).url.toLowerCase()] = true;
        var added = 0;
        for (var j = 0; j < incoming.length; j++) {
            if (existing[incoming[j].url.toLowerCase()]) continue;
            stationsModel.append(incoming[j]);
            added++;
        }
        if (added > 0) save();
        return added;
    }

    onCfg_stationsChanged: {
        if (cfg_stations !== _lastWritten) loadFromConfig();
    }

    Component.onCompleted: loadFromConfig()

    // ---- Üst --------------------------------------------------------------
    header: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Ad ve yayın adresi girin. Buradaki sıra, açılır penceredeki sırayı belirler; favoriler en üstte gösterilir.")
            }

            QQC2.Button {
                icon.name: "document-import"
                text: i18n("Yapıştırarak ekle…")
                onClicked: importDialog.open()
            }

            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Ekle")
                onClicked: {
                    page.addStation("", "", false);
                    stationList.positionViewAtEnd();
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: importResult.text !== ""
            id: importResult
            type: Kirigami.MessageType.Positive
            showCloseButton: true
        }
    }

    // ---- Liste ------------------------------------------------------------
    view: ListView {
        id: stationList
        model: stationsModel
        clip: true
        reuseItems: false

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: stationsModel.count === 0
            icon.name: "radio"
            text: i18n("Liste boş")
            explanation: i18n("“Ekle” ile tek tek girin ya da “Yapıştırarak ekle” ile bir M3U listesi veya adres satırları yapıştırın.")
        }

        delegate: QQC2.ItemDelegate {
            id: row

            required property int index
            required property var model

            width: ListView.view.width
            hoverEnabled: false
            down: false
            highlighted: false
            background: Rectangle {
                color: row.index % 2 === 0 ? "transparent" : Kirigami.Theme.alternateBackgroundColor
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.ToolButton {
                    icon.name: row.model.favorite ? "starred-symbolic" : "non-starred-symbolic"
                    display: QQC2.AbstractButton.IconOnly
                    text: row.model.favorite ? i18n("Favorilerden çıkar") : i18n("Favorilere ekle")
                    onClicked: {
                        stationsModel.setProperty(row.index, "favorite", !row.model.favorite);
                        page.save();
                    }
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                QQC2.TextField {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                    placeholderText: i18n("İstasyon adı")
                    text: row.model.name
                    onTextEdited: {
                        stationsModel.setProperty(row.index, "name", text);
                        page.save();
                    }
                    Accessible.name: i18n("İstasyon adı")
                }

                QQC2.TextField {
                    id: urlField
                    Layout.fillWidth: true
                    placeholderText: i18n("https://… yayın adresi")
                    text: row.model.url
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    color: text === "" || /^https?:\/\//i.test(text) ? Kirigami.Theme.textColor
                                                                       : Kirigami.Theme.negativeTextColor
                    onTextEdited: {
                        stationsModel.setProperty(row.index, "url", text.trim());
                        page.save();
                    }
                    Accessible.name: i18n("Yayın adresi")
                }

                QQC2.ToolButton {
                    icon.name: "go-up"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Yukarı taşı")
                    enabled: row.index > 0
                    onClicked: page.moveStation(row.index, row.index - 1)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                QQC2.ToolButton {
                    icon.name: "go-down"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Aşağı taşı")
                    enabled: row.index < stationsModel.count - 1
                    onClicked: page.moveStation(row.index, row.index + 1)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Sil")
                    onClicked: page.removeStation(row.index)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    // ---- Alt --------------------------------------------------------------
    footer: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "dialog-information"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18n(".pls ve .m3u adresleri çalınırken açılır ve içindeki gerçek yayın adresi kullanılır. .m3u8 (HLS) adresleri doğrudan çalınır.")
        }
    }

    // ---- Yapıştırarak ekle penceresi -------------------------------------
    Kirigami.Dialog {
        id: importDialog
        title: i18n("Yapıştırarak istasyon ekle")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        preferredWidth: Kirigami.Units.gridUnit * 32
        preferredHeight: Kirigami.Units.gridUnit * 22
        padding: Kirigami.Units.largeSpacing

        onAccepted: {
            var added = page.importText(importArea.text);
            importResult.text = added > 0
                ? i18np("%1 istasyon eklendi.", "%1 istasyon eklendi.", added)
                : i18n("Yeni istasyon bulunamadı. Satırlarda http(s) adresi olmalı.");
            importResult.type = added > 0 ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning;
            importArea.text = "";
        }
        onRejected: importArea.text = ""

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Bir M3U listesi (#EXTINF satırlı) ya da her satırda “Radyo Adı | https://adres” veya yalnızca adres bulunan metni yapıştırın. Zaten listede olan adresler atlanır.")
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                QQC2.TextArea {
                    id: importArea
                    wrapMode: TextEdit.NoWrap
                    placeholderText: "#EXTINF:-1,TRT Radyo 3\nhttps://radio-trtradyo3.live.trt.com.tr/master.m3u8\nPower FM | https://listen.powerapp.com.tr/powerfm/abr/playlist.m3u8"
                    font.family: "monospace"
                }
            }
        }
    }
}
