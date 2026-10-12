/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_autoplayLast: autoplayLast.checked
    property alias cfg_showHost: showHost.checked
    property alias cfg_middleClickToggles: middleClick.checked
    property int cfg_volume
    property string cfg_stations
    property string cfg_lastStationUrl

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: autoplayLast
            Kirigami.FormData.label: i18n("Başlangıç:")
            text: i18n("Widget yüklendiğinde son istasyonu çal")
        }

        QQC2.SpinBox {
            id: volumeBox
            Kirigami.FormData.label: i18n("Ses seviyesi:")
            from: 0
            to: 100
            stepSize: 5
            editable: true
            value: page.cfg_volume
            onValueModified: page.cfg_volume = value
            textFromValue: function (value) { return value + "%"; }
            valueFromText: function (text) { return parseInt(text.replace("%", "")) || 0; }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showHost
            Kirigami.FormData.label: i18n("İstasyon listesi:")
            text: i18n("Adın altında sunucu adını ve akış türünü göster")
        }

        QQC2.CheckBox {
            id: middleClick
            Kirigami.FormData.label: i18n("Panel ikonu:")
            text: i18n("Orta tık ile çal / durdur")
        }

        QQC2.Label {
            Kirigami.FormData.label: ""
            text: i18n("Sol tık pencereyi açar, fare tekerleği sesi değiştirir.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
