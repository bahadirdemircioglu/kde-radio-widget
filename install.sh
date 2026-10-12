#!/usr/bin/env bash
# Widget'ı kullanıcı için kurar veya günceller.
set -euo pipefail

cd "$(dirname "$0")"

PLUGIN_ID="com.github.bahadirdemircioglu.radyo"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 bulunamadı. Plasma 6 geliştirme araçlarını kurun (örn. plasma-sdk / plasma-framework)." >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Güncelleniyor: $PLUGIN_ID"
    kpackagetool6 --type Plasma/Applet --upgrade package
else
    echo "Kuruluyor: $PLUGIN_ID"
    kpackagetool6 --type Plasma/Applet --install package
fi

cat <<'EOF'

Tamam. Widget'ı panele eklemek için panele sağ tıklayın > "Widget Ekle" > "Radyo".
Zaten ekliyse değişiklikleri görmek için Plasma'yı yeniden başlatın:
    plasmashell --replace & disown
Yeniden başlatmadan denemek için:
    plasmoidviewer --applet package
EOF
