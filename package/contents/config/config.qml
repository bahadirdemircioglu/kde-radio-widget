/*
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("İstasyonlar")
        icon: "radio"
        source: "config/configStations.qml"
    }
    ConfigCategory {
        name: i18n("Genel")
        icon: "configure"
        source: "config/configGeneral.qml"
    }
}
