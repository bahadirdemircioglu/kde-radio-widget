# KDE Plasma 6 Radyo Widget'ı: Araştırma ve Tasarım Notları

Tarih: 2026-10-12. Bu belge kodlamaya başlamadan önce yapılan araştırmanın
özetidir ve tasarım tartışmasına temel olur.

## 1. Mevcut durum: benzer projeler

| Proje | Nasıl çalar | Ayarlar | Not |
|---|---|---|---|
| On Air (Mendior/on-air-plasmoid, LGPL-2.0+) | QtMultimedia `MediaPlayer` + `AudioOutput` | İstasyonlar tek bir JSON string ayarında (`servers`) | Plasma 6 için en güncel ve en kapsamlı örnek. 30 bin satırın üzerinde QML, ayrıca Python yardımcıları (MPRIS, ICY okuyucu, kayıt). Bizim için "ne mümkün" referansı, kopyalanacak şablon değil. |
| Advanced Radio Player (saurov/arp) | QtMultimedia | JSON string | On Air'in atası. Plasma 6 portu KDE Store'da (p/2136933). |
| Simple Radio Player (espaker) | `QtWebEngine` ile bir web sayfası gömer | URL | Gerçek bir oynatıcı değil, sadece web görünümü. |

Çıkarım: Plasma 6'da yerleşik yol **QML `MediaPlayer`**. Ek işlem (mpv, ffplay)
çalıştırmaya gerek yok, ancak `qt6-multimedia` ve FFmpeg arka ucunun kurulu
olması şart (openSUSE'de ayrı paket olarak kurulması gerekmiş).

## 2. Plasma 6 plasmoid iskeleti (doğrulanmış)

```
package/
├── metadata.json                 # KPackageStructure: Plasma/Applet,
│                                 # X-Plasma-API-Minimum-Version: "6.0" (zorunlu)
└── contents/
    ├── config/
    │   ├── main.xml              # KConfigXT şeması (ayar anahtarları + varsayılanlar)
    │   └── config.qml            # Ayar penceresindeki sekmeler (ConfigModel/ConfigCategory)
    ├── ui/
    │   ├── main.qml              # Kök öğe: PlasmoidItem
    │   ├── CompactRepresentation.qml   # Paneldeki küçük hal
    │   ├── FullRepresentation.qml      # Açılan popup
    │   └── config/configGeneral.qml    # KCM.SimpleKCM / ScrollViewKCM, cfg_ önekli alanlar
    └── icons/
```

Kullanılan QML modülleri: `org.kde.plasma.plasmoid`, `org.kde.plasma.components`,
`org.kde.plasma.extras`, `org.kde.kirigami`, `org.kde.kcmutils`, `QtMultimedia`,
`QtQuick.Layouts`.

Kurma ve test:

```
kpackagetool6 --type Plasma/Applet --install package/     # ilk kurulum
kpackagetool6 --type Plasma/Applet --upgrade package/     # güncelleme
plasmoidviewer --applet package/                           # plasmashell'i yeniden başlatmadan dene
plasmashell --replace &                                    # son test
```

## 3. Teknik riskler ve kararlar

1. **Çalma motoru**: QML `MediaPlayer { audioOutput: AudioOutput {} }`.
   Durum takibi `playbackState`, `mediaStatus`, `errorOccurred` ile.
2. **Şarkı adı (ICY StreamTitle) Qt 6'da gelmiyor.** FFmpeg arka ucu
   `metaData`'da yalnızca bit hızı gibi temel alanları veriyor. On Air bunu ayrı
   bir Python okuyucu süreciyle çözmüş. İlk sürümde "şu an çalan" özelliği
   kapsam dışı tutulmalı; istersek sonra eklenir.
3. **Playlist sarmalayıcıları**: `.m3u8` (HLS) doğrudan çalınır. `.pls` ve düz
   `.m3u` dosyaları ise gerçek yayın adresini içinde taşır; bunları
   `XMLHttpRequest` ile indirip ilk `http` satırını çıkarmak gerekir. Türkçe
   listede 30 adet `.pls`, 3 adet `.m3u` var; TRT, Kral, Power gibi büyük
   istasyonlar `.m3u8` kullanıyor.
4. **İstasyon depolama**: KConfigXT `StringList` türü URL'leri ad ile
   eşleştirmede zayıf. On Air/ARP gibi tek bir `String` ayarında JSON dizisi
   tutmak pratik: `[{"name":"TRT FM","url":"https://..."}]`.
5. **Ses seviyesi ve son istasyon**: `volume` ve `lastStation` ayar olarak
   saklanır; isteğe bağlı "açılışta son istasyonu çal".
6. **MPRIS / medya tuşları**: Plasma'da `org.kde.plasma.private.mpris` yalnızca
   okuma tarafı sunar. Kendi oynatıcımızı MPRIS olarak tanıtmak için D-Bus
   servisi gerekir ve bu QML'den doğrudan yapılamaz (On Air Python kullanmış).
   İlk sürümde kapsam dışı.
7. **Bağımlılık uyarısı**: `QtMultimedia` QML modülü yoksa widget hiç yüklenmez.
   README'de dağıtım bazında paket adları listelenmeli
   (Arch: `qt6-multimedia-ffmpeg`, Fedora: `qt6-qtmultimedia`,
   openSUSE: `qt6-multimedia`, Debian/Ubuntu: `qml6-module-qtmultimedia`).

## 4. Radyo linkleri

- Verilen sayfa (harsitvadisi.com) bu çalışma ortamının ağ politikası
  tarafından engellendi; arşiv ve önbellek aynaları da erişilemez. Linkler
  kullanıcı tarafından sağlanacak ya da aşağıdaki açık kaynaktan alınacak.
- Arama sonuçlarına göre o sayfa yaklaşık 2020 tarihli ve il bazlı yerel
  radyoları içeriyor; IP:port biçimli adreslerin çoğu artık çalışmayabilir.
- Alternatif ve güncel kaynak: `junguler/m3u-radio-music-playlists`
  (GitHub). `+checked+/t/turkey.m3u` dosyasında erişilebilirliği kontrol
  edilmiş 1849 Türkçe istasyon var. Örnekler:

| İstasyon | Adres | Tür |
|---|---|---|
| TRT Radyo 3 | https://radio-trtradyo3.live.trt.com.tr/master.m3u8 | HLS |
| TRT Türkü | https://radio-trtturku.live.trt.com.tr/master.m3u8 | HLS |
| TRT Radyo Haber | https://radio-trtradyohaber.live.trt.com.tr/master.m3u8 | HLS |
| Power FM | https://listen.powerapp.com.tr/powerfm/abr/playlist.m3u8 | HLS |
| PowerTürk | https://live.powerapp.com.tr/powerturk/abr/playlist.m3u8 | HLS |
| Kral FM | https://ssldyg2.radyotvonline.com/smil/smil:kralfm.smil/playlist.m3u8 | HLS |
| Metro FM | https://23543.live.streamtheworld.com/METRO_FM_SC | AAC akış |
| Joy FM | https://provisioning.streamtheworld.com/pls/JOY_FMAAC.pls | .pls sarmalayıcı |

- Programatik kaynak: radio-browser.info API'si
  (`/json/stations/bycountrycodeexact/TR`). İleride "istasyon ara" sekmesi
  için kullanılabilir.
- Bu ortamdan yayın adreslerine erişim yok; adresler kullanıcı makinesinde
  `mpv <url>` veya `ffprobe <url>` ile doğrulanmalı.

## 5. Önerilen tasarım (tartışmaya açık)

### Panel görünümü (compact)
- Radyo ikonu; çalarken renk vurgusu.
- Sol tık: popup aç/kapat. Orta tık: çal/durdur. Tekerlek: ses.
- Araç ipucu: istasyon adı ve durum (Çalıyor / Bağlanıyor / Hata).

### Popup (full)
```
┌──────────────────────────────────┐
│  ▶  TRT Radyo 3                   │  <- şu anki istasyon, durum satırı
│  ●──────────── 🔊 70%            │  <- ses kaydırıcı
├──────────────────────────────────┤
│  ★ TRT Radyo 3                    │  <- istasyon listesi, tıkla ve çal
│    Power FM                       │
│    Kral FM                        │
│    ...                            │
├──────────────────────────────────┤
│  [+ İstasyon ekle]  [⚙ Ayarlar]   │
└──────────────────────────────────┘
```

### Ayarlar penceresi
- **İstasyonlar** sekmesi: ad + URL alanları olan düzenlenebilir liste
  (ekle, sil, yukarı/aşağı taşı). İsteğe bağlı: M3U dosyasından içe aktar.
- **Genel** sekmesi: başlangıç ses seviyesi, açılışta son istasyonu çal,
  panel ikonu.

### Dosya planı
- `main.qml`: `PlasmoidItem`, `MediaPlayer`, çal/durdur/sonraki/önceki
  fonksiyonları, istasyon JSON'unu okuyan `ListModel`.
- `CompactRepresentation.qml`, `FullRepresentation.qml`, `StationDelegate.qml`.
- `PlaylistResolver.js`: `.pls`/`.m3u` çözümleme.
- `config/main.xml`, `config/config.qml`, `ui/config/configStations.qml`,
  `ui/config/configGeneral.qml`.

### Sürüm 1 kapsamı
Dahil: istasyon listesi, çal/durdur, ses, hata gösterimi, son istasyonu
hatırlama, `.pls/.m3u` çözümleme, Türkçe ve İngilizce arayüz metinleri.

Hariç (sonraki sürümler): şarkı adı gösterimi, MPRIS/medya tuşları,
radio-browser araması, kayıt, favicon/logo indirme.

## 6. Kaynaklar
- KDE geliştirici belgeleri: https://develop.kde.org/docs/plasma/widget/setup/ ,
  https://develop.kde.org/docs/plasma/widget/porting_kf6 ,
  https://develop.kde.org/docs/plasma/widget/testing
- On Air kaynak kodu: https://github.com/Mendior/on-air-plasmoid
- On Air duyurusu ve Qt 6 metadata sınırı tartışması:
  https://discuss.kde.org/t/on-air-internet-radio-podcasts-in-a-plasma-6-applet/48839
- Advanced Radio Player Plasma 6: https://store.kde.org/p/2136933
- Simple Radio Player: https://github.com/espaker/com.espaker.simpleradioplayer-plasma6
- Qt MediaPlayer QML: https://doc.qt.io/qt-6/qml-qtmultimedia-mediaplayer.html
- Qt 6 ICY metadata forum konusu: https://forum.qt.io/post/836338
- Türkçe istasyon listesi: https://github.com/junguler/m3u-radio-music-playlists
- Verilen liste (bu ortamdan erişilemedi): https://www.harsitvadisi.com/guncel-radyo-url-adresleri.html
