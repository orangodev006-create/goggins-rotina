#!/bin/sh
# Instala o Goggins: serviço do systemd (inicia junto com o Plasma) + painel "Goggins Dashboard".
set -e
DIR=$(cd "$(dirname "$0")" && pwd)

echo "Goggins Rotina: testado só no Arch Linux com KDE Plasma 6 (Wayland)."
echo "Leia o README e, se puder, peça pra uma IA revisar os arquivos antes de instalar."
case "$XDG_CURRENT_DESKTOP" in *KDE*) kde=1 ;; *) kde=0 ;; esac
if [ "$kde" = 0 ] || [ "$XDG_SESSION_TYPE" != "wayland" ]; then
    echo
    echo "⚠ Você está em: desktop=${XDG_CURRENT_DESKTOP:-?} sessão=${XDG_SESSION_TYPE:-?}"
    echo "  O Goggins precisa do KDE Plasma 6 no Wayland (KWin, Spectacle, widgets do Plasma)."
    printf "  Instalar mesmo assim? [s/N] "
    read -r resposta
    case "$resposta" in s|S|sim|SIM) ;; *) echo "Cancelado."; exit 1 ;; esac
fi

falta=""
for c in python3 qml6 qdbus6 spectacle tesseract; do
    command -v "$c" >/dev/null 2>&1 || falta="$falta $c"
done
python3 -c "import gi" 2>/dev/null || falta="$falta python-gobject"
tesseract --list-langs 2>/dev/null | grep -qx por || falta="$falta tesseract-data-por"
if [ -n "$falta" ]; then
    echo "Faltando:$falta"
    echo "No Arch: sudo pacman -S python-gobject qt6-declarative qt6-multimedia qt6-tools spectacle tesseract tesseract-data-por"
    exit 1
fi

SERVICO="$HOME/.config/systemd/user/goggins.service"
CTL="$HOME/.local/bin/goggins-ctl"
# não sobrescreve nada que não foi o Goggins que criou
if [ -e "$SERVICO" ] && ! grep -q "^# goggins-rotina" "$SERVICO"; then
    echo "Já existe um $SERVICO que não é deste projeto. Nada foi alterado."
    exit 1
fi
if { [ -e "$CTL" ] || [ -L "$CTL" ]; } && [ "$(readlink "$CTL")" != "$DIR/goggins-ctl" ]; then
    echo "Já existe um $CTL que não é deste projeto. Nada foi alterado."
    exit 1
fi

mkdir -p "$HOME/.config/systemd/user"
sed "s|@DIR@|$DIR|g" "$DIR/systemd/goggins.service.in" > "$SERVICO"
# o painel chama o goggins-ctl por este caminho
mkdir -p "$HOME/.local/bin"
ln -sfn "$DIR/goggins-ctl" "$CTL"
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
echo "Pra tirar tudo depois: ./uninstall.sh"
