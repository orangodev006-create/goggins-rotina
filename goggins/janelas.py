"""Lista de janelas abertas no Plasma (Wayland) via script do KWin que chama o daemon de volta por D-Bus."""
from pathlib import Path

from gi.repository import Gio, GLib

NOME = "org.goggins.Rotina"
CAMINHO = "/org/goggins/Rotina"
XML = f"""<node><interface name="{NOME}">
  <method name="janelas"><arg type="s" direction="in"/></method>
</interface></node>"""
PASTA_KWIN = Path(__file__).resolve().parent / "kwin"


def _kwin(conn, caminho, iface, metodo, args, tipo, pronto=None):
    conn.call("org.kde.KWin", caminho, iface, metodo, args, GLib.VariantType(tipo) if tipo else None,
              Gio.DBusCallFlags.NONE, 3000, None,
              lambda c, res: _fim(c, res, pronto))


def _fim(conn, res, pronto):
    try:
        v = conn.call_finish(res)
    except GLib.Error:
        v = None
    if pronto:
        pronto(v.unpack()[0] if v is not None and v.n_children() else None)


def carregar_script(conn, arquivo: Path, nome: str, rodar_depois=None):
    """Descarrega a versão antiga, carrega e roda o script do KWin."""
    def rodar(sid):
        if sid is None or sid < 0:
            return
        _kwin(conn, f"/Scripting/Script{sid}", "org.kde.kwin.Script", "run", None, None, rodar_depois)

    def carregar():
        _kwin(conn, "/Scripting", "org.kde.kwin.Scripting", "loadScript",
              GLib.Variant("(ss)", (str(arquivo), nome)), "(i)", rodar)
        return False

    # o KWin só apaga o script antigo no próximo ciclo; carregar com o mesmo nome antes disso
    # devolve o script morto e o run não faz nada
    _kwin(conn, "/Scripting", "org.kde.kwin.Scripting", "unloadScript", GLib.Variant("(s)", (nome,)), "(b)",
          lambda _: GLib.timeout_add(400, carregar))


class Janelas:
    def __init__(self, conn):
        self.conn = conn
        self.lista: list[tuple[str, str, bool]] = []
        info = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]
        conn.register_object(CAMINHO, info, self._chamada, None, None)
        self._carregar_topo()

    def _carregar_topo(self):
        # nome novo a cada início: reaproveitar o nome faz o KWin devolver o script velho, que não roda
        guardado = Path(GLib.get_user_state_dir()) / "goggins" / "kwin-topo"
        try:
            antigo = guardado.read_text().strip()
        except FileNotFoundError:
            antigo = "goggins-topo"
        nome = f"goggins-topo-{GLib.get_monotonic_time()}"
        _kwin(self.conn, "/Scripting", "org.kde.kwin.Scripting", "unloadScript", GLib.Variant("(s)", (antigo,)), "(b)")
        carregar_script(self.conn, PASTA_KWIN / "topo.js", nome)
        guardado.parent.mkdir(parents=True, exist_ok=True)
        guardado.write_text(nome)

    def _chamada(self, conn, remetente, caminho, iface, metodo, params, inv):
        if metodo == "janelas":
            lista = []
            for linha in params.unpack()[0].splitlines():
                ativa, classe, titulo = (linha.split("|", 2) + ["", ""])[:3]
                lista.append((classe, titulo, ativa == "1"))
            self.lista = lista
        inv.return_value(None)

    def arrumar(self):
        """Põe as janelas do Goggins no lugar (o script fixo do KWin às vezes não pega a janela nova)."""
        carregar_script(self.conn, PASTA_KWIN / "topo.js", "goggins-arrumar")
        return False

    def atualizar(self):
        carregar_script(self.conn, PASTA_KWIN / "listar.js", "goggins-listar")

    def ativa(self) -> tuple[str, str, bool] | None:
        return next((j for j in self.lista if j[2]), None)


if __name__ == "__main__":
    loop = GLib.MainLoop()

    def pronto(conn, _nome):
        j = Janelas(conn)
        j.atualizar()

        def mostrar():
            for classe, titulo, ativa in j.lista:
                print("*" if ativa else " ", classe, "|", titulo)
            loop.quit()
        GLib.timeout_add(1500, mostrar)

    Gio.bus_own_name(Gio.BusType.SESSION, NOME, Gio.BusNameOwnerFlags.NONE, pronto, None, lambda *a: loop.quit())
    loop.run()
