/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  Yayın adresleri hakkında ağa dokunmadan bilinebilenler (sunucu adı, akış
 *  türü) ve .pls / .m3u sarmalayıcı dosyalarının içindeki gerçek yayın
 *  adresini bulan çözümleyici. Saf fonksiyonlar; i18n yok, hata kodu döner.
 */
.pragma library

function pathOf(url) {
    return String(url).split("#")[0].split("?")[0].toLowerCase();
}

function hostOf(url) {
    var m = String(url).match(/^https?:\/\/(?:[^\/?#@]*@)?(\[[^\]]*\]|[^\/:?#]+)/i);
    return m ? m[1] : "";
}

// Qt'nin FFmpeg arka ucu HLS (.m3u8) ve doğrudan akışları kendisi çalar.
// .pls ve düz .m3u dosyaları ise yalnızca gerçek adresi içeren metin
// dosyalarıdır; önce indirilip içinden adres çıkarılmalıdır.
function isWrapper(url) {
    var p = pathOf(url);
    return p.endsWith(".pls") || p.endsWith(".m3u");
}

function streamKind(url) {
    var p = pathOf(url);
    if (p.endsWith(".m3u8")) return "HLS";
    if (p.endsWith(".pls")) return "PLS";
    if (p.endsWith(".m3u")) return "M3U";
    if (p.endsWith(".mp3")) return "MP3";
    if (p.endsWith(".aac") || p.endsWith(".aacp")) return "AAC";
    if (p.endsWith(".ogg") || p.endsWith(".oga")) return "OGG";
    if (p.endsWith(".opus")) return "Opus";
    if (p.endsWith(".flac")) return "FLAC";
    if (p.indexOf("aac") !== -1) return "AAC";
    if (p.indexOf("mp3") !== -1) return "MP3";
    return "";
}

function _resolveRelative(candidate, baseUrl) {
    if (/^https?:\/\//i.test(candidate)) return candidate;
    var m = String(baseUrl).match(/^(https?:\/\/[^\/?#]+)([^?#]*)/i);
    if (!m) return "";
    if (candidate.charAt(0) === "/") return m[1] + candidate;
    var dir = m[2].substring(0, m[2].lastIndexOf("/") + 1);
    return m[1] + dir + candidate;
}

// .pls: "File1=http://..." satırları.  .m3u: # ile başlamayan ilk satır.
// İlk kullanılabilir http(s) adresini döndürür, bulamazsa "".
function parsePlaylist(text, baseUrl) {
    var lines = String(text).split(/\r?\n/);
    var plsFiles = [];
    var plain = [];
    for (var i = 0; i < lines.length; i++) {
        var t = lines[i].trim();
        if (!t) continue;
        if (/^File\d*\s*=/i.test(t)) {
            plsFiles.push(t.substring(t.indexOf("=") + 1).trim());
            continue;
        }
        if (t.charAt(0) === "#" || t.charAt(0) === "[") continue;
        if (/^(Title|Length|NumberOfEntries|Version)\d*\s*=/i.test(t)) continue;
        plain.push(t);
    }
    var candidates = plsFiles.length ? plsFiles : plain;
    for (var j = 0; j < candidates.length; j++) {
        var u = _resolveRelative(candidates[j], baseUrl);
        if (/^https?:\/\//i.test(u)) return u;
    }
    return "";
}

// callback(resolvedUrl, errorCode)  errorCode: "" | "http" | "empty"
function resolve(url, callback) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status >= 200 && xhr.status < 400) {
            var found = parsePlaylist(xhr.responseText, url);
            if (found) callback(found, "");
            else callback("", "empty");
        } else {
            callback("", "http");
        }
    };
    try {
        xhr.open("GET", url);
        xhr.send();
    } catch (e) {
        callback("", "http");
    }
}
