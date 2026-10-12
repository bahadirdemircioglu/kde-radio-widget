/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtMultimedia
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "PlaylistResolver.js" as Playlist
import "StationsLogic.js" as Stations

PlasmoidItem {
    id: root

    // ---- İstasyonlar -------------------------------------------------------

    // Ayarlardaki JSON dizisinin okunmuş hali: [{name, url, favorite}]
    readonly property var stations: Stations.parse(Plasmoid.configuration.stations)

    // Listede önce "Favoriler" bölümü, sonra kategoriler (alfabetik), en sonda
    // kategorisi olmayanlar "Diğer" altında. Her öğenin section alanı bölüm
    // başlığıdır; hiç kategori ve favori yoksa başlık gösterilmez. origIndex,
    // stations dizisindeki gerçek konumdur; çalma/favori işlemleri onu kullanır.
    readonly property var displayStations: {
        var fav = [];
        var byCategory = {};
        var categories = [];
        var anySection = false;
        for (var i = 0; i < stations.length; i++) {
            var s = Object.assign({}, stations[i], { origIndex: i });
            if (s.favorite) {
                s.section = i18n("Favoriler");
                fav.push(s);
                anySection = true;
                continue;
            }
            var c = (s.category || "").trim();
            if (c !== "") anySection = true;
            if (!byCategory[c]) {
                byCategory[c] = [];
                categories.push(c);
            }
            byCategory[c].push(s);
        }
        categories.sort(function (a, b) {
            if (a === "") return 1;
            if (b === "") return -1;
            return a.localeCompare(b);
        });
        var out = fav;
        for (var k = 0; k < categories.length; k++) {
            var group = byCategory[categories[k]];
            for (var j = 0; j < group.length; j++) {
                group[j].section = categories[k] !== "" ? categories[k] : i18n("Diğer");
                out.push(group[j]);
            }
        }
        if (!anySection)
            for (var n = 0; n < out.length; n++) out[n].section = "";
        return out;
    }

    property int currentIndex: -1
    property string currentUrl: ""
    property string currentNameCache: ""
    readonly property var currentStation: currentIndex >= 0 && currentIndex < stations.length
                                          ? stations[currentIndex] : null
    readonly property string currentName: currentStation ? currentStation.name : currentNameCache

    // ---- Durum -------------------------------------------------------------

    // "idle" | "connecting" | "playing" | "error"
    property string status: "idle"
    property string errorText: ""
    property int bitrateKbps: 0
    readonly property bool isPlaying: status === "playing"
    readonly property bool isActive: status === "playing" || status === "connecting"

    // Her çalma isteği bir nesil numarası alır; gecikmiş .pls çözümlemeleri
    // eski nesle aitse yok sayılır.
    property int requestGeneration: 0

    property int volume: Plasmoid.configuration.volume

    // ---- Plasmoid ----------------------------------------------------------

    Plasmoid.icon: "radio"

    // Panelde tek ikon + açılır pencere; masaüstünde doğrudan tam görünüm.
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation

    // Masaüstünde Plasma'nın standart arka planı; düzenleme kipinden kapatılabilir.
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    // Masaüstünde bu boyutun altına inilirse ikon görünümüne düşer.
    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 8

    toolTipMainText: isActive && currentName !== "" ? currentName : Plasmoid.title
    toolTipSubText: statusText()

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.isActive ? i18n("Durdur") : i18n("Son istasyonu çal")
            icon.name: root.isActive ? "media-playback-stop" : "media-playback-start"
            enabled: root.stations.length > 0
            onTriggered: root.toggle()
        }
    ]

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    // ---- Oynatıcı ----------------------------------------------------------

    MediaPlayer {
        id: player

        audioOutput: AudioOutput {
            volume: QtMultimedia.convertVolume(root.volume / 100,
                                               QtMultimedia.LogarithmicVolumeScale,
                                               QtMultimedia.LinearVolumeScale)
        }

        onErrorOccurred: (error, errorString) => {
            if (root.status === "idle" || root.status === "error") return;
            root.fail(errorString && errorString !== "" ? errorString : i18n("Yayın açılamadı"));
        }
        onMediaStatusChanged: root.updateStatus()
        onPlaybackStateChanged: root.updateStatus()
        onMetaDataChanged: {
            var br = player.metaData.value(MediaMetaData.AudioBitRate);
            root.bitrateKbps = (br && br > 0) ? Math.round(br / 1000) : 0;
        }
    }

    // Bağlanma 20 saniyeden uzun sürerse hata say.
    Timer {
        id: connectWatchdog
        interval: 20000
        repeat: false
        onTriggered: {
            if (root.status === "connecting")
                root.fail(i18n("Zaman aşımı: yayına bağlanılamadı"));
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onStationsChanged() {
            root.currentIndex = root.indexOfUrl(root.currentUrl);
        }
        function onVolumeChanged() {
            root.volume = Plasmoid.configuration.volume;
        }
    }

    Component.onCompleted: {
        if (Plasmoid.configuration.autoplayLast && stations.length > 0)
            playLast();
    }

    // ---- İşlevler ----------------------------------------------------------

    function statusText() {
        switch (status) {
        case "playing": {
            var parts = [i18n("Çalıyor")];
            if (bitrateKbps > 0) parts.push(i18n("%1 kbps", bitrateKbps));
            var kind = currentStation ? Playlist.streamKind(currentStation.url) : "";
            if (kind !== "") parts.push(kind);
            return parts.join(" · ");
        }
        case "connecting":
            return i18n("Bağlanıyor…");
        case "error":
            return errorText !== "" ? errorText : i18n("Hata");
        default:
            return stations.length > 0 ? i18n("Durduruldu") : i18n("İstasyon eklenmedi");
        }
    }

    function indexOfUrl(url) {
        if (!url) return -1;
        for (var i = 0; i < stations.length; i++)
            if (stations[i].url === url) return i;
        return -1;
    }

    function playStation(index) {
        if (index < 0 || index >= stations.length) return;
        var st = stations[index];

        requestGeneration++;
        var generation = requestGeneration;

        currentIndex = index;
        currentUrl = st.url;
        currentNameCache = st.name;
        errorText = "";
        bitrateKbps = 0;
        status = "connecting";
        connectWatchdog.restart();
        player.stop();

        Plasmoid.configuration.lastStationUrl = st.url;

        if (Playlist.isWrapper(st.url)) {
            Playlist.resolve(st.url, function (resolved, errorCode) {
                if (generation !== root.requestGeneration) return;
                if (!resolved) {
                    root.fail(errorCode === "empty"
                              ? i18n("Oynatma listesinde yayın adresi bulunamadı")
                              : i18n("Oynatma listesi indirilemedi"));
                    return;
                }
                root.startSource(resolved);
            });
        } else {
            startSource(st.url);
        }
    }

    function startSource(url) {
        player.source = url;
        player.play();
    }

    function fail(message) {
        connectWatchdog.stop();
        status = "error";
        errorText = message;
        player.stop();
    }

    function stop() {
        requestGeneration++;
        connectWatchdog.stop();
        status = "idle";
        errorText = "";
        bitrateKbps = 0;
        player.stop();
        player.source = "";
    }

    function toggle() {
        if (isActive) stop();
        else playLast();
    }

    function playLast() {
        var i = indexOfUrl(Plasmoid.configuration.lastStationUrl);
        if (i < 0 && stations.length > 0) i = 0;
        if (i >= 0) playStation(i);
    }

    // Önceki/sonraki, listede görünen sırayı (favoriler, kategoriler) izler.
    function displayPosition() {
        for (var i = 0; i < displayStations.length; i++)
            if (displayStations[i].origIndex === currentIndex) return i;
        return -1;
    }

    function next() {
        var n = displayStations.length;
        if (n === 0) return;
        var p = displayPosition();
        playStation(displayStations[(p + 1) % n].origIndex);
    }

    function previous() {
        var n = displayStations.length;
        if (n === 0) return;
        var p = displayPosition();
        var i = p < 0 ? n - 1 : (p - 1 + n) % n;
        playStation(displayStations[i].origIndex);
    }

    function setVolume(value) {
        var v = Math.max(0, Math.min(100, Math.round(value)));
        volume = v;
        Plasmoid.configuration.volume = v;
    }

    function toggleFavorite(index) {
        if (index < 0 || index >= stations.length) return;
        var list = stations.slice();
        list[index] = Object.assign({}, list[index], { favorite: !list[index].favorite });
        Plasmoid.configuration.stations = Stations.serialize(list);
    }

    function openSettings() {
        Plasmoid.internalAction("configure").trigger();
    }

    function updateStatus() {
        if (status === "idle" || status === "error") return;

        var playing = player.playbackState === MediaPlayer.PlayingState;
        var ms = player.mediaStatus;

        if (ms === MediaPlayer.InvalidMedia) {
            fail(i18n("Geçersiz yayın adresi"));
        } else if (ms === MediaPlayer.EndOfMedia) {
            fail(i18n("Yayın sona erdi"));
        } else if (playing && (ms === MediaPlayer.BufferedMedia || ms === MediaPlayer.BufferingMedia)) {
            status = "playing";
            connectWatchdog.stop();
        } else if (playing) {
            // LoadingMedia, LoadedMedia veya StalledMedia: bekleniyor
            status = "connecting";
            if (!connectWatchdog.running) connectWatchdog.restart();
        } else if (player.playbackState === MediaPlayer.StoppedState && status === "playing") {
            fail(i18n("Bağlantı kesildi"));
        }
    }
}
