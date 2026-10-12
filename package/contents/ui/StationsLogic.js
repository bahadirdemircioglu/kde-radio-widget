/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 *
 *  İstasyon listesinin JSON ile okunup yazılması ve dışarıdan yapıştırılan
 *  metinlerin (M3U, "Kategori > Ad | adres", düz adres satırları)
 *  ayrıştırılması.
 */
.pragma library

.import "PlaylistResolver.js" as Playlist

function normalize(entry) {
    if (!entry || typeof entry.url !== "string") return null;
    var url = entry.url.trim();
    if (!url) return null;
    var name = typeof entry.name === "string" ? entry.name.trim() : "";
    var category = typeof entry.category === "string" ? entry.category.trim() : "";
    return {
        name: name || Playlist.hostOf(url) || url,
        url: url,
        favorite: entry.favorite === true,
        category: category
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
            favorite: s.favorite === true,
            category: String(s.category || "").trim()
        });
    }
    return JSON.stringify(out);
}

// Listedeki benzersiz kategoriler, Türkçe sıralı; boş kategori dışarıda.
function categoriesOf(list) {
    var seen = {};
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var c = String(list[i].category || "").trim();
        if (!c || seen[c.toLowerCase()]) continue;
        seen[c.toLowerCase()] = true;
        out.push(c);
    }
    out.sort(function (a, b) { return a.localeCompare(b); });
    return out;
}

// Desteklenen biçimler, satır satır:
//   #EXTINF:-1 group-title="Haber",Radyo Adı   (bir sonraki satır adres)
//   #EXTGRP:Haber                                (sonraki girdinin kategorisi)
//   https://...                                  (ad = sunucu adı)
//   Radyo Adı | https://...
//   Kategori > Radyo Adı | https://...
//   Radyo Adı : https://...      Radyo Adı - https://...      Radyo Adı<TAB>https://...
function parseImport(text) {
    var lines = String(text).split(/\r?\n/);
    var results = [];
    var seen = {};
    var pendingName = "";
    var pendingCategory = "";
    for (var i = 0; i < lines.length; i++) {
        var t = lines[i].trim();
        if (!t) continue;
        if (/^#EXTINF/i.test(t)) {
            var comma = t.indexOf(",");
            pendingName = comma >= 0 ? t.substring(comma + 1).trim() : "";
            var g = t.match(/group-title="([^"]*)"/i);
            if (g) pendingCategory = g[1].trim();
            continue;
        }
        if (/^#EXTGRP:/i.test(t)) {
            pendingCategory = t.substring(8).trim();
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
        var category = pendingCategory;
        if (!pendingName && rest.indexOf(">") !== -1) {
            var parts = rest.split(">");
            category = parts[0].trim();
            name = parts.slice(1).join(">").trim();
        }
        pendingName = "";
        pendingCategory = "";
        var key = url.toLowerCase();
        if (seen[key]) continue;
        seen[key] = true;
        results.push({
            name: name || Playlist.hostOf(url) || url,
            url: url,
            favorite: false,
            category: category
        });
    }
    return results;
}
