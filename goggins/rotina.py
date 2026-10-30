"""Rotina da semana e as regras de quando o Goggins cobra (lógica pura, sem I/O além de ler o JSON)."""
import json
from datetime import date, datetime
from pathlib import Path


def carregar_rotina(path: Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _minutos(hhmm: str) -> int:
    h, m = map(int, hhmm.split(":"))
    return h * 60 + m


def tarefas_do_dia(rotina: dict, dia: date) -> list[dict]:
    tarefas = [t for t in rotina["tarefas"] if dia.weekday() in t["dias"]]
    return sorted(tarefas, key=lambda t: _minutos(t["inicio"]))


def bloco_atual(tarefas: list[dict], agora: datetime) -> dict | None:
    m = agora.hour * 60 + agora.minute
    for t in tarefas:
        if _minutos(t["inicio"]) <= m < _minutos(t["fim"]):
            return t
    return None


def decidir(rotina: dict, tarefa: dict, estado_tarefa: dict, agora_dt: datetime, ts: float,
            ultimo_feito: float | None) -> str:
    """O que o Goggins faz agora no bloco: "calado", "checkin" (pergunta sem som) ou "cobrar".

    Bloco começou (ou acabou de concluir uma tarefa): fica calado uns minutos, pergunta
    "como tá indo aí?" e, se mesmo assim você não começou, passou do horário: xinga.
    """
    if not tarefa.get("cobra") or estado_tarefa.get("status") == "feito":
        return "calado"
    visto = estado_tarefa.get("ultimo_visto")
    if visto is not None and ts - visto <= rotina.get("tolerancia_segundos", 120):
        return "calado"
    if em_silencio(rotina, ts, ultimo_feito):
        return "calado"
    no_bloco = (agora_dt.hour * 60 + agora_dt.minute - _minutos(tarefa["inicio"])) * 60 + agora_dt.second
    if no_bloco < rotina.get("checkin_min", 5) * 60:
        return "calado"
    checkin = estado_tarefa.get("checkin")
    if checkin is None or checkin < max(ts - no_bloco, ultimo_feito or 0):
        return "checkin"
    if ts - checkin < rotina.get("cobrar_depois_checkin_min", 5) * 60:
        return "calado"
    return "cobrar"


def em_silencio(rotina: dict, agora: float, ultimo_feito: float | None) -> bool:
    """Concluiu uma tarefa: o Goggins dá um respiro antes de voltar a cobrar."""
    if ultimo_feito is None:
        return False
    return agora - ultimo_feito < rotina.get("silencio_apos_feito_min", 20) * 60


def cobranca_fim_do_dia(rotina: dict, tarefas: list[dict], estados: dict, agora: datetime) -> bool:
    metas = [t for t in tarefas if t.get("meta") and t.get("cobra")]
    if not metas:
        return False
    janela = rotina["fim_do_dia"]
    m = agora.hour * 60 + agora.minute
    if not _minutos(janela["inicio"]) <= m < _minutos(janela["fim"]):
        return False
    feitas = sum(1 for t in metas if estados.get(t["id"], {}).get("status") == "feito")
    return feitas < rotina.get("minimo_metas", 2)


def janela_bate(tarefa: dict, janelas: list[tuple[str, str, bool]], so_ativa: bool = False) -> bool:
    chaves = tarefa.get("janela", [])
    ignorar = [i.lower() for i in tarefa.get("janela_ignorar", [])]
    for classe, titulo, ativa in janelas:
        if so_ativa and not ativa:
            continue
        classe_l = classe.lower()
        # o app do Claude mostra títulos de conversas na barra lateral; nunca conta como a tarefa
        if classe_l == "com.anthropic.claude" or classe_l in ignorar:
            continue
        alvo = f"{classe_l} {titulo.lower()}"
        if any(c in alvo for c in chaves):
            return True
    return False


def texto_bate(tarefa: dict, texto: str) -> list[str]:
    t = texto.lower()
    return [c for c in tarefa.get("ocr", []) if c in t]


# ---------- configuração feita pela janela "Monte sua rotina" ----------

def _palavras(v) -> list[str]:
    itens = v.split(",") if isinstance(v, str) else (v or [])
    saida = []
    for p in itens:
        p = str(p).strip().lower()
        if p and p not in saida:
            saida.append(p)
    return saida


def _slug(nome: str) -> str:
    import unicodedata
    s = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode().lower()
    s = "".join(c if c.isalnum() else "-" for c in s)
    return "-".join(p for p in s.split("-") if p) or "tarefa"


def _hora_ok(hhmm) -> bool:
    try:
        h, m = map(int, str(hhmm).split(":"))
    except ValueError:
        return False
    return 0 <= h <= 23 and 0 <= m <= 59


def normalizar_rotina(atual: dict, enviado: dict) -> tuple[dict, list[str]]:
    """Junta o que veio da janela de configuração com os ajustes gerais. Devolve (rotina nova, erros)."""
    import copy
    nova = copy.deepcopy(atual)
    erros = []

    coach = enviado.get("coach")
    if coach:
        c = nova.setdefault("coach", {})
        nome = str(coach.get("nome", c.get("nome", ""))).strip().upper()[:30]
        c["nome"] = nome or "DAVID GOGGINS"
        c["sigla"] = (str(coach.get("sigla", c.get("sigla", ""))).strip().upper()[:3]) or c["nome"][:2]

    tarefas, ids = [], set()
    for n, t in enumerate(enviado.get("tarefas", []), 1):
        nome = str(t.get("nome", "")).strip()[:40]
        rotulo = f"Tarefa {n}" + (f" ({nome})" if nome else "")
        if not nome:
            erros.append(f"{rotulo}: falta o nome")
        dias = sorted({int(d) for d in t.get("dias", []) if str(d).isdigit() and 0 <= int(d) <= 6})
        if not dias:
            erros.append(f"{rotulo}: escolha pelo menos um dia")
        inicio, fim = str(t.get("inicio", "")).strip(), str(t.get("fim", "")).strip()
        if not (_hora_ok(inicio) and _hora_ok(fim)):
            erros.append(f"{rotulo}: horário no formato HH:MM, ex. 19:30")
        elif _minutos(inicio) >= _minutos(fim):
            erros.append(f"{rotulo}: o fim tem que ser depois do início")
        else:
            inicio, fim = f"{_minutos(inicio) // 60:02d}:{_minutos(inicio) % 60:02d}", \
                          f"{_minutos(fim) // 60:02d}:{_minutos(fim) % 60:02d}"

        tid = base = _slug(nome)
        k = 2
        while tid in ids:
            tid, k = f"{base}-{k}", k + 1
        ids.add(tid)
        cobra = bool(t.get("cobra", True))
        nova_t = {"id": tid, "nome": nome, "dias": dias, "inicio": inicio, "fim": fim,
                  "cobra": cobra, "meta": bool(t.get("meta", cobra)),
                  "verificacao": "prova" if t.get("verificacao") == "prova" else "manual"}
        if nova_t["verificacao"] == "prova":
            nova_t["janela"], nova_t["ocr"] = _palavras(t.get("janela")), _palavras(t.get("ocr"))
            if not nova_t["janela"] or not nova_t["ocr"]:
                erros.append(f"{rotulo}: com prova, diga o que procurar na janela e no print")
            try:
                nova_t["min_minutos"] = max(0, min(600, int(t.get("min_minutos", 0) or 0)))
            except (TypeError, ValueError):
                erros.append(f"{rotulo}: minutos mínimos tem que ser um número")
        tarefas.append(nova_t)

    # duas tarefas no mesmo dia e no mesmo horário: o Goggins não saberia qual cobrar
    for i, a in enumerate(tarefas):
        for b in tarefas[i + 1:]:
            if set(a["dias"]) & set(b["dias"]) and _hora_ok(a["inicio"]) and _hora_ok(b["inicio"]) \
                    and _minutos(a["inicio"]) < _minutos(b["fim"]) and _minutos(b["inicio"]) < _minutos(a["fim"]):
                erros.append(f"\"{a['nome']}\" e \"{b['nome']}\" estão ao mesmo tempo no mesmo dia")

    nova["tarefas"] = sorted(tarefas, key=lambda t: (_minutos(t["inicio"]) if _hora_ok(t["inicio"]) else 0))
    return nova, erros
