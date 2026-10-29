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
