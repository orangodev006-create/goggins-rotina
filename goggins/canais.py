"""Como os outros programas falam com o daemon, sem servidor HTTP (que um site no navegador alcançaria).

- D-Bus da sessão (painel e goggins-ctl): só processos do seu usuário chegam nele.
- Caixa de arquivos em ~/.local/state/goggins/caixa (janelas QML): pasta 700, só você lê e escreve.
"""
import json
import os
import threading
from pathlib import Path

from gi.repository import Gio, GLib

CAMINHO_API = "/org/goggins/Api"
API_XML = """<node><interface name="org.goggins.Api">
  <method name="Estado"><arg type="s" direction="out"/></method>
  <method name="Responder"><arg type="s" direction="in"/><arg type="b" direction="in"/><arg type="s" direction="out"/></method>
  <method name="Provar"><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
  <method name="Testar"><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
  <method name="Configurar"><arg type="s" direction="out"/></method>
</interface></node>"""


def registrar_api(conn, g):
    """Expõe o daemon em org.goggins.Rotina /org/goggins/Api. Cada método devolve JSON."""
    def responder(inv, obj):
        inv.return_value(GLib.Variant("(s)", (json.dumps(obj, ensure_ascii=False),)))

    def chamada(conn, remetente, caminho, iface, metodo, params, inv):
        args = params.unpack()
        if metodo == "Estado":
            responder(inv, g.resumo())
        elif metodo == "Responder":
            responder(inv, g.responder(args[0], args[1]))
        elif metodo == "Provar":
            # print + OCR levam uns 10 s: roda fora do loop principal
            threading.Thread(target=lambda: responder(inv, g.provar(args[0])), daemon=True).start()
        elif metodo == "Testar":
            ok = args[0] in g.falas and g.falar(args[0])
            responder(inv, {"ok": bool(ok)})
        elif metodo == "Configurar":
            abrir = getattr(g, "abrir_config", None)
            if abrir:
                abrir()
            responder(inv, {"ok": abrir is not None})

    info = Gio.DBusNodeInfo.new_for_xml(API_XML).interfaces[0]
    conn.register_object(CAMINHO_API, info, chamada, None, None)


class Caixa:
    """Arquivos JSON trocados com as janelas QML (que não falam D-Bus)."""

    def __init__(self, pasta: Path):
        self.pasta = Path(pasta)
        self.pasta.mkdir(parents=True, exist_ok=True)
        for p in (self.pasta.parent, self.pasta):
            os.chmod(p, 0o700)

    def url(self) -> str:
        return self.pasta.as_uri() + "/"

    def escrever(self, nome: str, obj):
        tmp = self.pasta / f".{nome}.tmp"
        tmp.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
        os.chmod(tmp, 0o600)
        tmp.replace(self.pasta / nome)

    def pegar(self, nome: str):
        """Lê e apaga um pedido. None se não tem pedido (ou se veio quebrado)."""
        arquivo = self.pasta / nome
        try:
            dados = json.loads(arquivo.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError, UnicodeDecodeError):
            arquivo.unlink(missing_ok=True)
            return None
        arquivo.unlink(missing_ok=True)
        return dados if isinstance(dados, dict) else None

    def limpar(self, *nomes: str):
        for n in nomes:
            (self.pasta / n).unlink(missing_ok=True)


# as janelas QML só podem ler/gravar arquivo com isso ligado (e só elas recebem)
AMBIENTE_QML = {**os.environ, "QML_XHR_ALLOW_FILE_READ": "1", "QML_XHR_ALLOW_FILE_WRITE": "1"}
