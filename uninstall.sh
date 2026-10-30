#!/bin/sh
# Tira tudo que o install.sh colocou no sistema. Não apaga esta pasta.
# Só remove o que é do Goggins (confere antes de apagar cada coisa).
DIR=$(cd "$(dirname "$0")" && pwd)
SERVICO="$HOME/.config/systemd/user/goggins.service"
CTL="$HOME/.local/bin/goggins-ctl"
ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/goggins"

# 1. serviço do systemd
if [ -f "$SERVICO" ] && grep -q "^# goggins-rotina" "$SERVICO"; then
    systemctl --user disable --now goggins 2>/dev/null
    rm -f "$SERVICO"
    systemctl --user daemon-reload
    echo "✓ serviço goggins parado e removido"
elif [ -f "$SERVICO" ]; then
    echo "• $SERVICO não foi criado por este projeto: deixei como está"
fi

# 2. atalho do goggins-ctl
if [ -L "$CTL" ] && [ "$(readlink "$CTL")" = "$DIR/goggins-ctl" ]; then
    rm -f "$CTL"
    echo "✓ $CTL removido"
fi

# 3. scripts que o Goggins carregou no KWin (somem também no próximo login)
if command -v qdbus6 >/dev/null 2>&1; then
    for nome in goggins-listar goggins-arrumar $(cat "$ESTADO/kwin-topo" 2>/dev/null); do
        qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$nome" >/dev/null 2>&1
    done
    echo "✓ scripts do KWin descarregados"
fi

# 4. painel (tire o widget da área de trabalho antes, senão fica um espaço vazio lá)
if command -v kpackagetool6 >/dev/null 2>&1 && kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx org.goggins.dashboard; then
    kpackagetool6 -t Plasma/Applet -r org.goggins.dashboard >/dev/null && echo "✓ painel Goggins Dashboard desinstalado"
fi

# 5. dados: prints das provas e histórico de cada dia
if [ -d "$ESTADO" ]; then
    printf "Apagar também os prints das provas e o histórico em %s? [s/N] " "$ESTADO"
    read -r resposta
    case "$resposta" in
        s|S|sim|SIM) rm -rf "$ESTADO" && echo "✓ dados apagados" ;;
        *) echo "• dados mantidos em $ESTADO" ;;
    esac
fi

echo "Pronto. Esta pasta ($DIR) continua aí; pode apagar quando quiser."
