"""Estado do dia: um JSON por data em ~/.local/state/goggins/."""
import json
from datetime import date
from pathlib import Path

NOVA_TAREFA = {"status": "pendente", "segundos": 0, "ultimo_visto": None, "parabenizado": False, "provas": []}


class Estado:
    def __init__(self, pasta: Path, hoje: date):
        self.pasta = Path(pasta)
        self.pasta.mkdir(parents=True, exist_ok=True)
        self._abrir(hoje)

    def _abrir(self, hoje: date):
        self.dia = hoje
        self.arquivo = self.pasta / f"{hoje.isoformat()}.json"
        try:
            self.dados = json.loads(self.arquivo.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            self.dados = {"tarefas": {}, "fim_dia_tocado": False}

    def recarregar_se_mudou_dia(self, hoje: date) -> bool:
        if hoje == self.dia:
            return False
        self._abrir(hoje)
        return True

    def tarefa(self, tid: str) -> dict:
        t = self.dados["tarefas"].setdefault(tid, {})
        for k, v in NOVA_TAREFA.items():
            t.setdefault(k, list(v) if isinstance(v, list) else v)
        return t

    def todas(self) -> dict:
        return self.dados["tarefas"]

    def salvar(self):
        tmp = self.arquivo.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.dados, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(self.arquivo)
