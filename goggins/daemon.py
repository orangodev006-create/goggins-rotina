"""Daemon do Goggins: vigia a rotina, cobra/parabeniza com popups e serve a API local pro dashboard."""
import json
import os
import random
import subprocess
import threading
import time
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from zoneinfo import ZoneInfo

from gi.repository import Gio, GLib

from goggins import prova, rotina as r
from goggins.estado import Estado
from goggins.janelas import NOME, Janelas

BASE = Path(__file__).resolve().parent.parent
QML = BASE / "qml"
AUDIOS = BASE / "audios"
PASTA_ESTADO = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "goggins"
PORTA = 47777
TICK = 1
JANELAS_A_CADA = 3  # ticks
# hora local do sistema; GOGGINS_FUSO=America/Sao_Paulo (por ex.) força outro fuso
FUSO = ZoneInfo(os.environ["GOGGINS_FUSO"]) if os.environ.get("GOGGINS_FUSO") else None
DIAS = ["SEGUNDA", "TERÇA", "QUARTA", "QUINTA", "SEXTA", "SÁBADO", "DOMINGO"]

# GOGGINS_AGORA=2026-10-29T17:45 simula outro horário (o relógio continua andando a partir dele)
_DESVIO = timedelta(0)
if os.environ.get("GOGGINS_AGORA"):
    _DESVIO = datetime.fromisoformat(os.environ["GOGGINS_AGORA"]) - datetime.now(FUSO).replace(tzinfo=None)


def agora() -> datetime:
    return datetime.now(FUSO).replace(tzinfo=None) + _DESVIO


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


class Goggins:
    def __init__(self):
        self.rotina = r.carregar_rotina(BASE / "rotina.json")
        self.falas = json.loads((BASE / "falas.json").read_text(encoding="utf-8"))
        self.estado = Estado(PASTA_ESTADO, agora().date())
        self.lock = threading.RLock()
        self.janelas: Janelas | None = None
        self.popup: subprocess.Popen | None = None
        self.popup_tipo = None
        self.popup_desde = 0.0
        self.ultima_cobranca = 0.0
        self.prova_proc: subprocess.Popen | None = None
        self.prova_tarefa = None
        self.ultimo_tick = time.monotonic()
        self.ticks = 0
        self.ultima_fala = {}
        self.agenda_mostrada = False

    # ---------- popups ----------
    def falar(self, tipo: str, texto: str | None = None, sub: str = ""):
        """Popup do Goggins. Tipos de falas.json têm áudio; os outros (checkin, agenda) são só texto."""
        with self.lock:
            # ao ligar, a lista do dia vem antes de qualquer outra coisa
            if not self.agenda_mostrada and tipo != "agenda":
                return False
            aberto = self.popup and self.popup.poll() is None
            idade = time.monotonic() - self.popup_desde
            # a lista do dia fica na tela um tempo; parabéns recém aberto não é atropelado por cobrança
            if aberto and self.popup_tipo == "agenda" and idade < 12:
                return False
            if aberto and self.popup_tipo != "cobranca" and tipo == "cobranca" and idade < 6:
                return False
            args = [f"tipo={tipo}", f"sub={sub}", *self.coach_args()]
            if tipo in self.falas:
                opcoes = self.falas[tipo]
                if len(opcoes) > 1:
                    opcoes = [f for f in opcoes if f["audio"] != self.ultima_fala.get(tipo)]
                fala = random.choice(opcoes)
                self.ultima_fala[tipo] = fala["audio"]
                texto = texto or fala["texto"]
                # sem o arquivo de áudio o popup aparece mudo
                if (AUDIOS / fala["audio"]).exists():
                    args.append(f"audio={AUDIOS / fala['audio']}")
            if self.popup and self.popup.poll() is None:
                self.popup.terminate()
            log("popup", tipo, "→", texto.replace("\n", " | "))
            self.popup = subprocess.Popen(["qml6", str(QML / "Popup.qml"), "--", f"texto={texto}", *args],
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.popup_tipo = tipo
            self.popup_desde = time.monotonic()
            self.arrumar_depois()
            if tipo == "cobranca":
                self.ultima_cobranca = time.monotonic()
            return True

    def coach_args(self) -> list[str]:
        """Nome, sigla e foto de quem aparece nos popups (rotina.json → "coach")."""
        c = self.rotina.get("coach", {})
        args = [f"nome={c.get('nome', 'DAVID GOGGINS')}", f"sigla={c.get('sigla', 'DG')}"]
        if c.get("foto") and (BASE / c["foto"]).exists():
            args.append(f"foto={BASE / c['foto']}")
            if c.get("recorte"):
                args.append("recorte=" + ",".join(str(int(v)) for v in c["recorte"]))
        return args

    def arrumar_depois(self):
        # a janela do qml6 leva ~1 s pra aparecer; GLib.timeout_add é seguro de chamar da thread da API
        if self.janelas:
            for ms in (900, 1800):
                GLib.timeout_add(ms, self.janelas.arrumar)

    def prova_aberta(self) -> bool:
        return self.prova_proc is not None and self.prova_proc.poll() is None

    def abrir_prova(self, tid: str):
        with self.lock:
            if self.prova_aberta():
                self.prova_proc.terminate()
            if self.popup and self.popup.poll() is None:
                self.popup.terminate()
            self.prova_tarefa = tid
            self.prova_proc = subprocess.Popen(["qml6", str(QML / "Prova.qml"), "--", f"tarefa={tid}", f"porta={PORTA}",
                                                *self.coach_args()],
                                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.arrumar_depois()

    # ---------- regras ----------
    def tarefas_hoje(self):
        return r.tarefas_do_dia(self.rotina, agora().date())

    def tick(self):
        try:
            self._tick()
        except Exception as e:  # o loop nunca pode morrer
            log("erro no tick:", repr(e))
        return True

    def _tick(self):
        with self.lock:
            dt = min(time.monotonic() - self.ultimo_tick, TICK * 3)
            self.ultimo_tick = time.monotonic()
            now = agora()
            if self.estado.recarregar_se_mudou_dia(now.date()):
                log("dia novo:", now.date())
            self.ticks += 1
            if self.janelas and self.ticks % JANELAS_A_CADA == 0:
                self.janelas.atualizar()
            lista = self.janelas.lista if self.janelas else []
            tarefas = self.tarefas_hoje()
            bloco = r.bloco_atual(tarefas, now)
            ts = time.time()
            cobrar = False

            if bloco:
                et = self.estado.tarefa(bloco["id"])
                if bloco.get("janela") and r.janela_bate(bloco, lista, so_ativa=True):
                    et["segundos"] += dt
                    et["ultimo_visto"] = ts
                    if et["status"] in ("pendente", "recusado"):
                        et["status"] = "fazendo"
                    if not et["parabenizado"] and et["status"] != "feito" and self.falar("parabens"):
                        et["parabenizado"] = True
                acao = r.decidir(self.rotina, bloco, et, now, ts, self.estado.dados.get("ultimo_feito"))
                if acao == "checkin" and not self.prova_aberta() and \
                        self.falar("checkin", "Como tá indo aí?", sub=bloco["nome"].upper()):
                    et["checkin"] = ts
                cobrar = acao == "cobrar"
            if not cobrar:
                estados = self.estado.todas()
                cobrar = r.cobranca_fim_do_dia(self.rotina, tarefas, estados, now)
            if r.em_silencio(self.rotina, ts, self.estado.dados.get("ultimo_feito")):
                cobrar = False

            # enquanto a janela de prova está aberta ele espera
            if cobrar and not self.prova_aberta() and \
                    time.monotonic() - self.ultima_cobranca >= self.rotina.get("intervalo_cobranca", 10) - 0.5:
                self.falar("cobranca")
            self.cobrando = cobrar
            self.estado.salvar()

    def mostrar_agenda(self):
        """Ao ligar o PC: as tarefas de hoje, sem som."""
        with self.lock:
            linhas = []
            for t in self.tarefas_hoje():
                feito = self.estado.tarefa(t["id"])["status"] == "feito"
                linhas.append(f"{'✓' if feito else '•'}  {t['inicio']}–{t['fim']}   {t['nome']}")
        self.falar("agenda", "\n".join(linhas) or "Hoje é folga. Descansa, amanhã tem mais.",
                   sub="TAREFAS DE HOJE • " + DIAS[agora().weekday()])
        self.agenda_mostrada = True
        return False

    def checar_fim_dia(self):
        with self.lock:
            self._checar_fim_dia()

    def _checar_fim_dia(self):
        metas = [t for t in self.tarefas_hoje() if t.get("meta") and t.get("cobra")]
        if metas and all(self.estado.tarefa(t["id"])["status"] == "feito" for t in metas) \
                and not self.estado.dados.get("fim_dia_tocado"):
            self.estado.dados["fim_dia_tocado"] = True
            GLib.timeout_add_seconds(6, lambda: self.falar("fim_dia") and False)

    # ---------- API ----------
    def resumo(self) -> dict:
        with self.lock:
            now = agora()
            tarefas = self.tarefas_hoje()
            bloco = r.bloco_atual(tarefas, now)
            ativa = self.janelas.ativa() if self.janelas else None
            saida = []
            for t in tarefas:
                et = self.estado.tarefa(t["id"])
                saida.append({
                    "id": t["id"], "nome": t["nome"], "inicio": t["inicio"], "fim": t["fim"],
                    "cobra": t.get("cobra", False), "meta": t.get("meta", False),
                    "verificacao": t.get("verificacao", "manual"), "status": et["status"],
                    "minutos": int(et["segundos"] // 60), "min_minutos": t.get("min_minutos", 0),
                    "atual": bool(bloco and bloco["id"] == t["id"]),
                })
            return {
                "online": True, "agora": now.strftime("%H:%M"), "dia": DIAS[now.weekday()],
                "bloco": bloco["id"] if bloco else None, "cobrando": getattr(self, "cobrando", False),
                "prova_aberta": self.prova_tarefa if self.prova_aberta() else None,
                "janela_ativa": f"{ativa[0]} — {ativa[1]}" if ativa else "", "tarefas": saida,
            }

    def _tarefa_cfg(self, tid):
        return next((t for t in self.tarefas_hoje() if t["id"] == tid), None)

    def responder(self, tid: str, fiz: bool) -> dict:
        t = self._tarefa_cfg(tid)
        if not t:
            return {"ok": False, "erro": "essa tarefa não é de hoje"}
        if not fiz:
            self.falar("cobranca")
            return {"ok": True, "acao": "cobranca"}
        if t.get("verificacao") == "manual":
            with self.lock:
                self.estado.tarefa(tid)["status"] = "feito"
                self.estado.dados["ultimo_feito"] = time.time()
                self.estado.salvar()
            self.falar("parabens")
            self.checar_fim_dia()
            return {"ok": True, "acao": "feito"}
        self.abrir_prova(tid)
        return {"ok": True, "acao": "prova"}

    def provar(self, tid: str) -> dict:
        t = self._tarefa_cfg(tid)
        if not t:
            return {"aprovado": False, "checagens": [{"nome": "tarefa", "ok": False, "motivo": "essa tarefa não é de hoje"}]}
        arquivo = PASTA_ESTADO / "provas" / f"{agora():%Y-%m-%d_%H%M%S}_{tid}.png"
        arquivo.parent.mkdir(parents=True, exist_ok=True)
        try:
            prova.tirar_print(arquivo)
        except RuntimeError as e:
            return {"aprovado": False, "checagens": [{"nome": "print", "ok": False, "motivo": str(e)}]}
        # lista de janelas fresquinha, do momento do print
        if self.janelas:
            GLib.idle_add(lambda: self.janelas.atualizar() and False)
            time.sleep(1.2)
        lista = list(self.janelas.lista) if self.janelas else []
        texto = prova.ocr(arquivo)
        with self.lock:
            et = self.estado.tarefa(tid)
            res = prova.avaliar(t, lista, texto, et["segundos"])
            et["provas"].append({"hora": agora().strftime("%H:%M:%S"), "arquivo": str(arquivo),
                                 "aprovado": res["aprovado"]})
            if res["aprovado"]:
                et["status"] = "feito"
                self.estado.dados["ultimo_feito"] = time.time()
            elif et["status"] != "feito":
                et["status"] = "recusado"
            self.estado.salvar()
        log("prova", tid, "aprovada" if res["aprovado"] else "recusada", res["checagens"])
        if res["aprovado"]:
            self.falar("parabens")
            self.checar_fim_dia()
        else:
            self.falar("cobranca")
        return res


def servidor(g: Goggins):
    class H(BaseHTTPRequestHandler):
        def _json(self, obj, code=200):
            corpo = json.dumps(obj, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(corpo)))
            self.end_headers()
            self.wfile.write(corpo)

        def do_GET(self):
            if urlparse(self.path).path == "/estado":
                return self._json(g.resumo())
            self._json({"erro": "não existe"}, 404)

        def do_POST(self):
            u = urlparse(self.path)
            q = {k: v[0] for k, v in parse_qs(u.query).items()}
            if u.path == "/responder":
                return self._json(g.responder(q.get("tarefa", ""), q.get("fiz") == "1"))
            if u.path == "/provar":
                return self._json(g.provar(q.get("tarefa", "")))
            if u.path == "/testar" and q.get("tipo") in g.falas:
                g.falar(q["tipo"])
                return self._json({"ok": True})
            self._json({"erro": "não existe"}, 404)

        def log_message(self, *a):
            pass

    srv = ThreadingHTTPServer(("127.0.0.1", PORTA), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    log(f"API em http://127.0.0.1:{PORTA}")


def main():
    g = Goggins()
    loop = GLib.MainLoop()

    def pronto(conn, _nome):
        g.janelas = Janelas(conn)
        log("conectado ao KWin")

    def perdeu(*_):
        log("não consegui o nome D-Bus (outro daemon rodando?)")
        loop.quit()

    Gio.bus_own_name(Gio.BusType.SESSION, NOME, Gio.BusNameOwnerFlags.NONE, pronto, None, perdeu)
    servidor(g)
    GLib.timeout_add_seconds(TICK, g.tick)
    # espera o KWin carregar o script que posiciona os popups
    GLib.timeout_add_seconds(4, g.mostrar_agenda)
    log("Goggins acordado. Stay hard.", agora())
    loop.run()


if __name__ == "__main__":
    main()
