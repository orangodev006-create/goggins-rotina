import tempfile
import unittest
from datetime import date
from pathlib import Path

from goggins.estado import Estado
from goggins.prova import avaliar

AF = {"id": "trabalho", "janela": ["planilha"], "ocr": ["planilha"], "min_minutos": 30}
FF = [("firefox", "Planilha do trabalho — Mozilla Firefox", True)]


class TestEstado(unittest.TestCase):
    def test_persiste_e_rele(self):
        with tempfile.TemporaryDirectory() as d:
            e = Estado(Path(d), date(2026, 10, 29))
            e.tarefa("trabalho")["status"] = "feito"
            e.salvar()
            self.assertEqual(Estado(Path(d), date(2026, 10, 29)).tarefa("trabalho")["status"], "feito")
            self.assertTrue((Path(d) / "2026-10-29.json").exists())

    def test_virada_do_dia_zera(self):
        with tempfile.TemporaryDirectory() as d:
            e = Estado(Path(d), date(2026, 10, 29))
            e.tarefa("trabalho")["status"] = "feito"
            e.salvar()
            self.assertTrue(e.recarregar_se_mudou_dia(date(2026, 10, 30)))
            self.assertEqual(e.tarefa("trabalho")["status"], "pendente")
            self.assertFalse(e.recarregar_se_mudou_dia(date(2026, 10, 30)))

    def test_tarefa_nova_nao_compartilha_lista(self):
        with tempfile.TemporaryDirectory() as d:
            e = Estado(Path(d), date(2026, 10, 29))
            e.tarefa("a")["provas"].append(1)
            self.assertEqual(e.tarefa("b")["provas"], [])


class TestAvaliar(unittest.TestCase):
    def test_aprovado(self):
        self.assertTrue(avaliar(AF, FF, "PLANILHA", 31 * 60)["aprovado"])

    def test_cada_checagem_falha_sozinha(self):
        casos = {"janela": (AF, [], "planilha", 3600), "print": (AF, FF, "nada", 3600), "tempo": (AF, FF, "planilha", 60)}
        for nome, args in casos.items():
            r = avaliar(*args)
            self.assertFalse(r["aprovado"], nome)
            falhas = [c["nome"] for c in r["checagens"] if not c["ok"]]
            self.assertEqual(falhas, [nome])


if __name__ == "__main__":
    unittest.main()
