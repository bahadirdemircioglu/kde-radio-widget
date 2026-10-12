# Radyo — KDE Plasma 6 internet radyosu widget'ı

Panelde duran, tıklayınca açılan küçük bir radyo oynatıcısı. İstasyon
adreslerini kendiniz ekler, tek tıkla dinlersiniz.

- İstasyon listesi, favoriler en üstte
- Çal / durdur, önceki / sonraki, ses kaydırıcısı
- Panel ikonunda durum: çalıyor (yeşil nokta), bağlanıyor, hata
- Orta tık ile çal/durdur, fare tekerleği ile ses
- Son istasyonu hatırlar, isteğe bağlı açılışta çalar
- `.m3u8` (HLS) ve doğrudan akışlar yanında `.pls` / `.m3u` listelerini de açar
- M3U ya da "Ad | adres" satırlarını yapıştırarak toplu ekleme

Tasarım ve araştırma notları: [docs/01-arastirma-ve-tasarim.md](docs/01-arastirma-ve-tasarim.md)

## Gereksinimler

Plasma 6 ve Qt 6 Multimedia'nın QML modülü (FFmpeg arka ucu). Paket adları:

| Dağıtım | Paket |
|---|---|
| Arch / Manjaro | `qt6-multimedia-ffmpeg` (veya `qt6-multimedia-gstreamer`) |
| Fedora | `qt6-qtmultimedia` |
| openSUSE | `qt6-multimedia` |
| Debian / Ubuntu / Kubuntu | `qml6-module-qtmultimedia` |

Modül eksikse widget hiç yüklenmez ve "module QtMultimedia is not installed"
hatası verir.

## Kurulum

```sh
git clone https://github.com/bahadirdemircioglu/kde-radio-widget.git
cd kde-radio-widget
./install.sh
```

Sonra panele sağ tık > **Widget Ekle** > **Radyo**.

Elle kurmak için:

```sh
kpackagetool6 --type Plasma/Applet --install package    # ilk kurulum
kpackagetool6 --type Plasma/Applet --upgrade package    # güncelleme
kpackagetool6 --type Plasma/Applet --remove com.github.bahadirdemircioglu.radyo
```

## Geliştirme ve test

Plasma'yı yeniden başlatmadan denemek için `plasma-sdk` paketindeki
`plasmoidviewer` kullanılır:

```sh
plasmoidviewer --applet package
plasmoidviewer --applet package --formfactor horizontal --location bottom   # panel hali
```

Değişiklik sonrası kurulu kopyayı güncelleyip Plasma'yı yeniden başlatmak:

```sh
./install.sh && plasmashell --replace & disown
```

Konsol çıktısını görmek için `plasmashell --replace` komutunu arka plana
atmadan bir terminalde çalıştırın; `console.log` ve QML hataları orada görünür.

## İstasyon ekleme

**Ayarlar > İstasyonlar** sekmesinde her satır bir ad ve bir yayın adresidir.
**Yapıştırarak ekle** ile şu biçimlerden herhangi birini toplu ekleyebilirsiniz:

```
#EXTINF:-1,TRT Radyo 3
https://radio-trtradyo3.live.trt.com.tr/master.m3u8
Power FM | https://listen.powerapp.com.tr/powerfm/abr/playlist.m3u8
Kral FM : https://ssldyg2.radyotvonline.com/smil/smil:kralfm.smil/playlist.m3u8
https://live.radyofenomen.com/fenomen/128/icecast.audio
```

Zaten listede olan adresler atlanır. Bir adresin çalıştığını hızlıca test
etmek için:

```sh
mpv https://radio-trtradyo3.live.trt.com.tr/master.m3u8
ffprobe https://listen.powerapp.com.tr/powerfm/abr/playlist.m3u8
```

Güncel Türkçe istasyon adresleri için erişilebilirliği düzenli kontrol
edilen [junguler/m3u-radio-music-playlists](https://github.com/junguler/m3u-radio-music-playlists)
deposundaki `+checked+/t/turkey.m3u` dosyası iyi bir kaynaktır.

## Bilinen sınırlar

- **Şarkı adı gösterilmez.** Qt 6'nın FFmpeg arka ucu ICY `StreamTitle`
  bilgisini QML'e aktarmıyor; yalnızca bit hızı okunabiliyor.
- **Medya tuşları (MPRIS) yok.** Kendi oynatıcımızı MPRIS olarak tanıtmak
  D-Bus servisi gerektirir ve saf QML ile yapılamıyor.
- Arayüz metinleri Türkçe yazıldı ve `i18n()` ile sarmalandı; çeviri
  altyapısı sonraki sürümde eklenecek.

## Proje düzeni

```
package/
├── metadata.json
└── contents/
    ├── config/
    │   ├── main.xml                 ayar şeması ve varsayılan istasyonlar
    │   └── config.qml               ayar penceresi sekmeleri
    └── ui/
        ├── main.qml                 PlasmoidItem, MediaPlayer, çalma mantığı
        ├── CompactRepresentation.qml  panel ikonu
        ├── FullRepresentation.qml     açılır pencere
        ├── StationDelegate.qml        liste satırı
        ├── PlaylistResolver.js        .pls/.m3u çözümleme, akış türü
        ├── StationsLogic.js           JSON okuma/yazma, yapıştırma ayrıştırıcı
        └── config/
            ├── configStations.qml   istasyon düzenleyici
            └── configGeneral.qml    genel ayarlar
```

## Lisans

GPL-3.0-or-later
