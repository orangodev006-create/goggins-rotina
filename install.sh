#!/bin/sh
# Instala o Goggins: serviço do systemd (inicia junto com o Plasma) + painel "Goggins Dashboard".
set -e
DIR=$(cd "$(dirname "$0")" && pwd)

falta=""
for c in python3 qml6 qdbus6 spectacle tesseract curl; do
    command -v "$c" >/dev/null 2>&1 || falta="$falta $c"
done
python3 -c "import gi" 2>/dev/null || falta="$falta python-gobject"
tesseract --list-langs 2>/dev/null | grep -qx por || falta="$falta tesseract-data-por"
if [ -n "$falta" ]; then
    echo "Faltando:$falta"
    echo "No Arch: sudo pacman -S python-gobject qt6-declarative qt6-multimedia qt6-tools spectacle tesseract tesseract-data-por curl"
    exit 1
fi

mkdir -p "$HOME/.config/systemd/user"
sed "s|@DIR@|$DIR|g" "$DIR/systemd/goggins.service.in" > "$HOME/.config/systemd/user/goggins.service"
systemctl --user daemon-reload
systemctl --user enable --now goggins
echo "✓ serviço goggins ativo (systemctl --user status goggins)"

if [ "$1" != "--sem-painel" ]; then
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx org.goggins.dashboard; then
        kpackagetool6 -t Plasma/Applet -u "$DIR/plasmoid"
    else
        kpackagetool6 -t Plasma/Applet -i "$DIR/plasmoid"
    fi
    echo "✓ painel instalado: clique com o botão direito na área de trabalho → Adicionar widgets → Goggins Dashboard"
fi
