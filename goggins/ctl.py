"""Cliente do daemon pelo D-Bus da sessão (o painel e o goggins-ctl usam isto)."""
import json
import sys

from gi.repository import Gio, GLib

from goggins.canais import CAMINHO_API
from goggins.janelas import NOME

USO = "goggins-ctl estado | json | configurar | testar cobranca|parabens|fim_dia | fiz <tarefa> | naofiz <tarefa> | provar <tarefa>"


def chamar(metodo: str, args: GLib.Variant | None = None, timeout_ms: int = 5000) -> dict:
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    res = conn.call_sync(NOME, CAMINHO_API, "org.goggins.Api", metodo, args, GLib.VariantType("(s)"),
                         Gio.DBusCallFlags.NONE, timeout_ms, None)
    return json.loads(res.unpack()[0])


def main(argv: list[str]) -> int:
    cmd, resto = (argv[0], argv[1:]) if argv else ("", [])
    try:
        if cmd in ("estado", "json"):
            res = chamar("Estado")
        elif cmd in ("fiz", "naofiz") and resto:
            res = chamar("Responder", GLib.Variant("(sb)", (resto[0], cmd == "fiz")))
        elif cmd == "provar" and resto:
            res = chamar("Provar", GLib.Variant("(s)", (resto[0],)), timeout_ms=90_000)
        elif cmd == "testar":
            res = chamar("Testar", GLib.Variant("(s)", (resto[0] if resto else "cobranca",)))
        elif cmd == "configurar":
            res = chamar("Configurar")
        else:
            print(USO)
            return 2
    except GLib.Error:
        # o painel lê isto: Goggins desligado
        res = {"online": False, "erro": "o Goggins não está rodando (systemctl --user start goggins)"}
        print(json.dumps(res, ensure_ascii=False))
        return 1
    print(json.dumps(res, ensure_ascii=False) if cmd == "json" else json.dumps(res, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
