/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  İstasyon listesinin JSON ile okunup yazılması ve dışarıdan yapıştırılan
 *  metinlerin (M3U, "Ad | adres", düz adres satırları) ayrıştırılması.
 */
.pragma library

.import "PlaylistResolver.js" as Playlist

function normalize(entry) {
    if (!entry || typeof entry.url !== "string") return null;
    var url = entry.url.trim();
    if (!url) return null;
    var name = typeof entry.name === "string" ? entry.name.trim() : "";
    return {
        name: name || Playlist.hostOf(url) || url,
        url: url,
        favorite: entry.favorite === true
    };
}

function parse(json) {
    var list;
    try {
        list = JSON.parse(json);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list)) return [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var s = normalize(list[i]);
        if (s) out.push(s);
    }
    return out;
}

function serialize(list) {
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var s = list[i];
        out.push({
            name: String(s.name || ""),
            url: String(s.url || ""),
            favorite: s.favorite === true
        });
    }
    return JSON.stringify(out);
}

// Desteklenen biçimler, satır satır:
//   #EXTINF:-1,Radyo Adı          (bir sonraki satır adres)
//   https://...                    (ad = sunucu adı)
//   Radyo Adı | https://...
//   Radyo Adı : https://...
//   Radyo Adı - https://...
//   Radyo Adı<TAB>https://...
function parseImport(text) {
    var lines = String(text).split(/\r?\n/);
    var results = [];
    var seen = {};
    var pendingName = "";
    for (var i = 0; i < lines.length; i++) {
        var t = lines[i].trim();
        if (!t) continue;
        if (/^#EXTINF/i.test(t)) {
            var comma = t.indexOf(",");
            pendingName = comma >= 0 ? t.substring(comma + 1).trim() : "";
            continue;
        }
        if (t.charAt(0) === "#") continue;
        var m = t.match(/(https?:\/\/[^\s"'<>]+)/i);
        if (!m) continue;
        var url = m[1].replace(/[),.;\]]+$/, "");
        var rest = t.replace(m[1], " ")
            .replace(/^[\s|:\-–—\t]+|[\s|:\-–—\t]+$/g, "")
            .trim();
        var name = pendingName || rest;
        pendingName = "";
        var key = url.toLowerCase();
        if (seen[key]) continue;
        seen[key] = true;
        results.push({
            name: name || Playlist.hostOf(url) || url,
            url: url,
            favorite: false
        });
    }
    return results;
}
