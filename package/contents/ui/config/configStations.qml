/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtMultimedia
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../PlaylistResolver.js" as Playlist
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

    // Listedeki benzersiz kategoriler (kategori menüsü için).
    property var categories: []

    // Kalıcı liste. testState / testMessage yalnızca bu oturumda yaşar.
    ListModel { id: stationsModel }

    // "Yapıştırarak ekle" penceresinde kontrol edilen adaylar.
    ListModel { id: candidatesModel }

    function rowObject(s) {
        return {
            name: String(s.name || ""),
            url: String(s.url || ""),
            favorite: s.favorite === true,
            category: String(s.category || ""),
            testState: String(s.testState || ""),
            testMessage: String(s.testMessage || ""),
            urlEdited: false
        };
    }

    function loadFromConfig() {
        stationsModel.clear();
        var list = Stations.parse(cfg_stations);
        for (var i = 0; i < list.length; i++)
            stationsModel.append(rowObject(list[i]));
        _lastWritten = cfg_stations;
        refreshCategories();
    }

    function modelToList(model) {
        var list = [];
        for (var i = 0; i < model.count; i++) {
            var row = model.get(i);
            list.push({
                name: row.name, url: row.url, favorite: row.favorite === true,
                category: row.category, testState: row.testState, testMessage: row.testMessage
            });
        }
        return list;
    }

    function save() {
        _lastWritten = Stations.serialize(modelToList(stationsModel));
        cfg_stations = _lastWritten;
        refreshCategories();
    }

    function refreshCategories() {
        categories = Stations.categoriesOf(modelToList(stationsModel));
    }

    function addStation(name, url, category) {
        stationsModel.append(rowObject({ name: name, url: url, category: category }));
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

    function hasUrl(url) {
        var key = String(url).trim().toLowerCase();
        for (var i = 0; i < stationsModel.count; i++)
            if (stationsModel.get(i).url.trim().toLowerCase() === key) return true;
        return false;
    }

    // Adayları listeye ekler; zaten olan adresler atlanır. Eklenen sayıyı döner.
    function importRows(rows, fallbackCategory) {
        var added = 0;
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i];
            if (!r.url || hasUrl(r.url)) continue;
            stationsModel.append(rowObject({
                name: r.name, url: r.url,
                category: r.category || fallbackCategory || "",
                testState: r.testState === "ok" || r.testState === "fail" ? r.testState : "",
                testMessage: r.testMessage
            }));
            added++;
        }
        if (added > 0) save();
        return added;
    }

    onCfg_stationsChanged: {
        if (cfg_stations !== _lastWritten) loadFromConfig();
    }

    Component.onCompleted: loadFromConfig()
    Component.onDestruction: cancelTests()

    // ---- Bağlantı testi ---------------------------------------------------
    // Adresler sırayla, sessiz bir oynatıcıda gerçekten açılmayı dener:
    // tamponlama başlarsa "ok", hata veya 15 sn içinde ses yoksa "fail".

    property var _testQueue: []
    property string _testingUrl: ""
    property int _testGeneration: 0
    readonly property bool testing: _testingUrl !== "" || _testQueue.length > 0

    signal testsFinished()

    function setTestState(url, state, message) {
        var key = String(url).trim().toLowerCase();
        var models = [stationsModel, candidatesModel];
        for (var m = 0; m < models.length; m++) {
            for (var i = 0; i < models[m].count; i++) {
                if (models[m].get(i).url.trim().toLowerCase() !== key) continue;
                models[m].setProperty(i, "testState", state);
                models[m].setProperty(i, "testMessage", message || "");
            }
        }
    }

    function testUrl(url) {
        url = String(url || "").trim();
        if (url === "") return;
        if (url === _testingUrl || _testQueue.indexOf(url) !== -1) return;
        _testQueue.push(url);
        setTestState(url, "queued", "");
        _startNextTest();
    }

    function testAll() {
        for (var i = 0; i < stationsModel.count; i++)
            testUrl(stationsModel.get(i).url);
    }

    function testCandidates() {
        for (var i = 0; i < candidatesModel.count; i++) {
            var row = candidatesModel.get(i);
            if (row.testState !== "exists") testUrl(row.url);
        }
    }

    function cancelTests() {
        var queued = _testQueue;
        _testQueue = [];
        for (var i = 0; i < queued.length; i++) setTestState(queued[i], "", "");
        if (_testingUrl !== "") {
            var url = _testingUrl;
            _testingUrl = "";
            _testGeneration++;
            testTimer.stop();
            testPlayer.stop();
            testPlayer.source = "";
            setTestState(url, "", "");
        }
    }

    function _startNextTest() {
        if (_testingUrl !== "" || _testQueue.length === 0) return;
        var url = _testQueue.shift();
        _testingUrl = url;
        _testGeneration++;
        var generation = _testGeneration;
        setTestState(url, "testing", "");

        if (!/^https?:\/\//i.test(url)) {
            _finishTest(false, i18n("Adres http:// veya https:// ile başlamalı"));
            return;
        }
        if (Playlist.isWrapper(url)) {
            Playlist.resolve(url, function (resolved, errorCode) {
                if (generation !== page._testGeneration) return;
                if (!resolved) {
                    page._finishTest(false, errorCode === "empty"
                                     ? i18n("Oynatma listesinde yayın adresi yok")
                                     : i18n("Oynatma listesi indirilemedi"));
                    return;
                }
                page._startTestSource(resolved);
            });
        } else {
            _startTestSource(url);
        }
    }

    function _startTestSource(source) {
        testPlayer.source = source;
        testPlayer.play();
        testTimer.restart();
    }

    function _finishTest(ok, message) {
        var url = _testingUrl;
        if (url === "") return;
        _testingUrl = "";
        _testGeneration++;
        testTimer.stop();
        testPlayer.stop();
        testPlayer.source = "";
        setTestState(url, ok ? "ok" : "fail", message || "");
        if (_testQueue.length === 0) testsFinished();
        else _startNextTest();
    }

    function _checkTestStatus() {
        if (_testingUrl === "") return;
        var ms = testPlayer.mediaStatus;
        if (ms === MediaPlayer.InvalidMedia) {
            _finishTest(false, i18n("Geçersiz yayın"));
        } else if (ms === MediaPlayer.EndOfMedia) {
            _finishTest(false, i18n("Yayın hemen sona erdi"));
        } else if (testPlayer.playbackState === MediaPlayer.PlayingState
                   && (ms === MediaPlayer.BufferedMedia || ms === MediaPlayer.BufferingMedia)) {
            var br = testPlayer.metaData.value(MediaMetaData.AudioBitRate);
            _finishTest(true, (br && br > 0) ? i18n("Çalışıyor · %1 kbps", Math.round(br / 1000))
                                             : i18n("Çalışıyor"));
        }
    }

    function countStates(model) {
        var c = { ok: 0, fail: 0, pending: 0, exists: 0 };
        for (var i = 0; i < model.count; i++) {
            var s = model.get(i).testState;
            if (s === "ok") c.ok++;
            else if (s === "fail") c.fail++;
            else if (s === "exists") c.exists++;
            else if (s === "testing" || s === "queued") c.pending++;
        }
        return c;
    }

    onTestsFinished: {
        var c = countStates(stationsModel);
        if (c.ok + c.fail === 0) return;
        resultMessage.type = c.fail > 0 ? Kirigami.MessageType.Warning : Kirigami.MessageType.Positive;
        resultMessage.text = c.fail > 0
            ? i18n("%1 istasyon çalışıyor, %2 istasyon çalışmıyor.", c.ok, c.fail)
            : i18n("Test edilen %1 istasyonun hepsi çalışıyor.", c.ok);
        resultMessage.visible = true;
    }

    MediaPlayer {
        id: testPlayer
        audioOutput: AudioOutput {
            muted: true
            volume: 0
        }
        onErrorOccurred: (error, errorString) => {
            if (page._testingUrl === "") return;
            page._finishTest(false, errorString && errorString !== "" ? errorString : i18n("Yayın açılamadı"));
        }
        onMediaStatusChanged: page._checkTestStatus()
        onPlaybackStateChanged: page._checkTestStatus()
    }

    Timer {
        id: testTimer
        interval: 15000
        repeat: false
        onTriggered: page._finishTest(false, i18n("Zaman aşımı: 15 saniyede ses gelmedi"))
    }

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
                text: i18n("Ad, yayın adresi ve kategori girin. Favoriler en üstte, kalanlar kategori başlıkları altında listelenir. Adres girildiğinde bağlantı kendiliğinden test edilir.")
            }

            QQC2.Button {
                icon.name: "network-connect"
                text: page.testing ? i18n("Test ediliyor…") : i18n("Tümünü test et")
                enabled: !page.testing && stationsModel.count > 0
                onClicked: {
                    resultMessage.visible = false;
                    page.testAll();
                }
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
                    page.addStation("", "", "");
                    stationList.positionViewAtEnd();
                }
            }
        }

        Kirigami.InlineMessage {
            id: resultMessage
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: false
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

            readonly property string testState: model.testState

            width: ListView.view.width
            hoverEnabled: false
            down: false
            highlighted: false
            background: Rectangle {
                color: row.index % 2 === 0 ? "transparent" : Kirigami.Theme.alternateBackgroundColor
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                // Bağlantı durumu / test düğmesi
                QQC2.ToolButton {
                    id: testButton
                    display: QQC2.AbstractButton.IconOnly
                    enabled: row.testState !== "testing" && row.testState !== "queued" && row.model.url.trim() !== ""
                    icon.name: row.testState === "ok" ? "dialog-ok-apply"
                             : row.testState === "fail" ? "dialog-error"
                             : row.testState === "queued" ? "chronometer"
                             : row.testState === "testing" ? ""
                             : "network-connect"
                    icon.color: row.testState === "ok" ? Kirigami.Theme.positiveTextColor
                              : row.testState === "fail" ? Kirigami.Theme.negativeTextColor
                              : "transparent"
                    text: row.testState === "ok" ? row.model.testMessage
                        : row.testState === "fail" ? i18n("Çalışmıyor: %1", row.model.testMessage)
                        : row.testState === "testing" ? i18n("Deneniyor…")
                        : row.testState === "queued" ? i18n("Sırada bekliyor")
                        : i18n("Bağlantıyı test et")
                    onClicked: page.testUrl(row.model.url)

                    QQC2.BusyIndicator {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.6)
                        height: width
                        visible: row.testState === "testing"
                        running: visible
                    }

                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered && text !== ""
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

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
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
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
                        stationsModel.setProperty(row.index, "testState", "");
                        stationsModel.setProperty(row.index, "testMessage", "");
                        stationsModel.setProperty(row.index, "urlEdited", true);
                        page.save();
                    }
                    // Adres yazılıp alandan çıkılınca kendiliğinden test et.
                    onEditingFinished: {
                        if (row.model.urlEdited && text.trim() !== "") {
                            stationsModel.setProperty(row.index, "urlEdited", false);
                            page.testUrl(text.trim());
                        }
                    }
                    Accessible.name: i18n("Yayın adresi")
                }

                QQC2.TextField {
                    id: categoryField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    placeholderText: i18n("Kategori")
                    text: row.model.category
                    onTextEdited: {
                        stationsModel.setProperty(row.index, "category", text);
                        page.save();
                    }
                    Accessible.name: i18n("Kategori")
                }

                QQC2.ToolButton {
                    id: categoryMenuButton
                    icon.name: "arrow-down"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Mevcut kategorilerden seç")
                    enabled: page.categories.length > 0
                    onClicked: categoryMenu.popup()
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                    QQC2.Menu {
                        id: categoryMenu
                        Instantiator {
                            model: page.categories
                            delegate: QQC2.MenuItem {
                                required property string modelData
                                text: modelData
                                onTriggered: {
                                    stationsModel.setProperty(row.index, "category", modelData);
                                    page.save();
                                }
                            }
                            onObjectAdded: (index, object) => categoryMenu.insertItem(index, object)
                            onObjectRemoved: (index, object) => categoryMenu.removeItem(object)
                        }
                    }
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
            text: i18n("Test, yayını birkaç saniye sessiz olarak açmayı dener. .pls ve .m3u adresleri önce açılır ve içindeki gerçek yayın adresi kullanılır; .m3u8 (HLS) doğrudan çalınır.")
        }
    }

    // ---- Yapıştırarak ekle penceresi -------------------------------------
    Kirigami.Dialog {
        id: importDialog

        // "input": metin yapıştırılır; "review": bulunanlar test edilir ve eklenir.
        property string phase: "input"
        property var counts: ({ ok: 0, fail: 0, pending: 0, exists: 0 })

        function refreshCounts() { counts = page.countStates(candidatesModel); }

        title: phase === "input" ? i18n("Yapıştırarak istasyon ekle") : i18n("Bulunan istasyonlar")
        standardButtons: Kirigami.Dialog.NoButton
        showCloseButton: true
        preferredWidth: Kirigami.Units.gridUnit * 34
        preferredHeight: Kirigami.Units.gridUnit * 24
        padding: Kirigami.Units.largeSpacing

        customFooterActions: phase === "input" ? [checkAction, cancelAction]
                                               : [backAction, addWorkingAction, addAllAction]

        Kirigami.Action {
            id: checkAction
            text: i18n("Kontrol et")
            icon.name: "network-connect"
            enabled: importArea.text.trim() !== ""
            onTriggered: importDialog.startReview()
        }
        Kirigami.Action {
            id: cancelAction
            text: i18n("İptal")
            icon.name: "dialog-cancel"
            onTriggered: importDialog.close()
        }
        Kirigami.Action {
            id: backAction
            text: i18n("Geri")
            icon.name: "go-previous"
            onTriggered: {
                page.cancelTests();
                importDialog.phase = "input";
            }
        }
        Kirigami.Action {
            id: addWorkingAction
            text: importDialog.counts.pending > 0
                  ? i18n("Çalışanları ekle (%1, test sürüyor…)", importDialog.counts.ok)
                  : i18n("Çalışanları ekle (%1)", importDialog.counts.ok)
            icon.name: "dialog-ok-apply"
            enabled: importDialog.counts.ok > 0
            onTriggered: importDialog.addCandidates(true)
        }
        Kirigami.Action {
            id: addAllAction
            text: i18n("Hepsini ekle")
            icon.name: "list-add"
            enabled: candidatesModel.count - importDialog.counts.exists > 0
            onTriggered: importDialog.addCandidates(false)
        }

        function startReview() {
            var rows = Stations.parseImport(importArea.text);
            candidatesModel.clear();
            for (var i = 0; i < rows.length; i++) {
                var r = rowObject(rows[i]);
                if (page.hasUrl(r.url)) {
                    r.testState = "exists";
                    r.testMessage = i18n("Zaten listede");
                }
                candidatesModel.append(r);
            }
            phase = "review";
            refreshCounts();
            page.testCandidates();
        }

        function addCandidates(onlyWorking) {
            page.cancelTests();
            var rows = [];
            for (var i = 0; i < candidatesModel.count; i++) {
                var r = candidatesModel.get(i);
                if (r.testState === "exists") continue;
                if (onlyWorking && r.testState !== "ok") continue;
                rows.push({ name: r.name, url: r.url, category: r.category,
                            testState: r.testState, testMessage: r.testMessage });
            }
            var added = page.importRows(rows, batchCategory.text.trim());
            resultMessage.type = added > 0 ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning;
            resultMessage.text = added > 0
                ? i18np("%1 istasyon eklendi.", "%1 istasyon eklendi.", added)
                : i18n("Eklenecek yeni istasyon yok.");
            resultMessage.visible = true;
            close();
        }

        Connections {
            target: candidatesModel
            function onDataChanged() { importDialog.refreshCounts(); }
            function onCountChanged() { importDialog.refreshCounts(); }
        }

        onClosed: {
            page.cancelTests();
            candidatesModel.clear();
            importArea.text = "";
            batchCategory.text = "";
            phase = "input";
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            // Aşama 1: metin
            QQC2.Label {
                visible: importDialog.phase === "input"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Bir M3U listesi ya da her satırda “Radyo Adı | https://adres” veya yalnızca adres bulunan metni yapıştırın. Kategori için “Kategori > Radyo Adı | adres” yazın ya da M3U'daki group-title kullanılır. Adresler eklenmeden önce tek tek denenir.")
            }

            QQC2.ScrollView {
                visible: importDialog.phase === "input"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 14

                QQC2.TextArea {
                    id: importArea
                    wrapMode: TextEdit.NoWrap
                    placeholderText: "#EXTINF:-1 group-title=\"Haber\",TRT Radyo Haber\nhttps://radio-trtradyohaber.live.trt.com.tr/master.m3u8\nPop > Power FM | https://listen.powerapp.com.tr/powerfm/abr/playlist.m3u8"
                    font.family: "monospace"
                }
            }

            // Aşama 2: kontrol sonuçları
            QQC2.Label {
                visible: importDialog.phase === "review"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: candidatesModel.count === 0
                      ? i18n("Metinde http(s) adresi bulunamadı.")
                      : i18n("%1 adres bulundu: %2 çalışıyor, %3 çalışmıyor, %4 deneniyor, %5 zaten listede.",
                             candidatesModel.count, importDialog.counts.ok, importDialog.counts.fail,
                             importDialog.counts.pending, importDialog.counts.exists)
            }

            QQC2.TextField {
                id: batchCategory
                visible: importDialog.phase === "review" && candidatesModel.count > 0
                Layout.fillWidth: true
                placeholderText: i18n("Kategorisi olmayanlar için kategori (isteğe bağlı)")
            }

            QQC2.ScrollView {
                visible: importDialog.phase === "review"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 14

                ListView {
                    id: candidateList
                    model: candidatesModel
                    clip: true

                    delegate: QQC2.ItemDelegate {
                        id: candidate
                        required property int index
                        required property var model
                        width: ListView.view.width
                        hoverEnabled: false
                        down: false

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Item {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: candidate.model.testState !== "testing" && candidate.model.testState !== "queued"
                                    source: candidate.model.testState === "ok" ? "dialog-ok-apply"
                                          : candidate.model.testState === "fail" ? "dialog-error"
                                          : candidate.model.testState === "exists" ? "dialog-information"
                                          : "network-connect"
                                    color: candidate.model.testState === "ok" ? Kirigami.Theme.positiveTextColor
                                         : candidate.model.testState === "fail" ? Kirigami.Theme.negativeTextColor
                                         : Kirigami.Theme.textColor
                                    isMask: candidate.model.testState === "ok" || candidate.model.testState === "fail"
                                }
                                QQC2.BusyIndicator {
                                    anchors.fill: parent
                                    visible: candidate.model.testState === "testing"
                                    running: visible
                                    padding: 0
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: candidate.model.category !== ""
                                          ? i18nc("kategori · ad", "%1 · %2", candidate.model.category, candidate.model.name)
                                          : candidate.model.name
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                    font: Kirigami.Theme.smallFont
                                    opacity: candidate.model.testState === "fail" ? 1 : 0.7
                                    color: candidate.model.testState === "fail" ? Kirigami.Theme.negativeTextColor
                                                                                : Kirigami.Theme.textColor
                                    text: candidate.model.testMessage !== ""
                                          ? candidate.model.testMessage + " · " + candidate.model.url
                                          : candidate.model.url
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
