import unittest
from datetime import datetime, date
from pathlib import Path

from goggins import rotina as r

ROTINA = r.carregar_rotina(Path(__file__).resolve().parent.parent / "rotina.json")
QUINTA = date(2026, 10, 29)
SABADO = date(2026, 10, 31)


def em(d, hhmm):
    h, m = map(int, hhmm.split(":"))
    return datetime(d.year, d.month, d.day, h, m)


class TestRotina(unittest.TestCase):
    def test_tarefas_dia_util(self):
        ids = [t["id"] for t in r.tarefas_do_dia(ROTINA, QUINTA)]
        self.assertEqual(ids, ["coisas", "trabalho", "programar", "estudar"])

    def test_bloco_atual_quinta(self):
        t = r.bloco_atual(r.tarefas_do_dia(ROTINA, QUINTA), em(QUINTA, "18:00"))
        self.assertEqual(t["id"], "trabalho")
        self.assertTrue(t["cobra"])

    def test_bloco_atual_sabado_nao_cobra(self):
        t = r.bloco_atual(r.tarefas_do_dia(ROTINA, SABADO), em(SABADO, "15:00"))
        self.assertEqual(t["id"], "trabalho_fds")
        self.assertFalse(t["cobra"])

    def test_sem_bloco_de_manha(self):
        self.assertIsNone(r.bloco_atual(r.tarefas_do_dia(ROTINA, QUINTA), em(QUINTA, "10:00")))

    def test_fim_do_bloco_exclusivo(self):
        t = r.bloco_atual(r.tarefas_do_dia(ROTINA, QUINTA), em(QUINTA, "20:30"))
        self.assertEqual(t["id"], "estudar")

    def _decidir(self, hhmm, et, ultimo_feito=None, dia=QUINTA):
        agora = em(dia, hhmm)
        t = r.bloco_atual(r.tarefas_do_dia(ROTINA, dia), agora)
        return r.decidir(ROTINA, t, et, agora, agora.timestamp(), ultimo_feito)

    def test_decidir_linha_do_tempo_do_bloco(self):
        # trabalho começa 17:30: calado até 17:35, pergunta, xinga 5 min depois da pergunta
        self.assertEqual(self._decidir("17:32", {"status": "pendente"}), "calado")
        self.assertEqual(self._decidir("17:35", {"status": "pendente"}), "checkin")
        checkin = em(QUINTA, "17:35").timestamp()
        self.assertEqual(self._decidir("17:38", {"status": "pendente", "checkin": checkin}), "calado")
        self.assertEqual(self._decidir("17:40", {"status": "pendente", "checkin": checkin}), "cobrar")

    def test_decidir_checkin_de_outro_bloco_nao_vale(self):
        velho = em(QUINTA, "16:10").timestamp()
        self.assertEqual(self._decidir("17:40", {"status": "pendente", "checkin": velho}), "checkin")

    def test_decidir_trabalhando_ou_feito_fica_calado(self):
        agora = em(QUINTA, "18:00").timestamp()
        self.assertEqual(self._decidir("18:00", {"status": "fazendo", "ultimo_visto": agora - 60}), "calado")
        self.assertEqual(self._decidir("18:00", {"status": "feito"}), "calado")

    def test_decidir_depois_de_concluir_outra_tarefa(self):
        # concluiu algo 17:50: 5 min calado, depois pergunta de novo mesmo com checkin antigo
        feito = em(QUINTA, "17:50").timestamp()
        et = {"status": "pendente", "checkin": em(QUINTA, "17:35").timestamp()}
        self.assertEqual(self._decidir("17:53", et, feito), "calado")
        self.assertEqual(self._decidir("17:56", et, feito), "checkin")

    def test_silencio_depois_de_concluir(self):
        agora = em(QUINTA, "19:55").timestamp()
        self.assertTrue(r.em_silencio(ROTINA, agora, agora - 4 * 60))
        self.assertFalse(r.em_silencio(ROTINA, agora, agora - 6 * 60))
        self.assertFalse(r.em_silencio(ROTINA, agora, None))

    def test_nao_cobra_fim_de_semana(self):
        self.assertEqual(self._decidir("16:00", {"status": "pendente"}, dia=SABADO), "calado")

    def test_cobranca_fim_do_dia(self):
        tarefas = r.tarefas_do_dia(ROTINA, QUINTA)
        um = {"trabalho": {"status": "feito"}}
        dois = {"trabalho": {"status": "feito"}, "programar": {"status": "feito"}}
        self.assertTrue(r.cobranca_fim_do_dia(ROTINA, tarefas, um, em(QUINTA, "21:40")))
        self.assertFalse(r.cobranca_fim_do_dia(ROTINA, tarefas, dois, em(QUINTA, "21:40")))
        self.assertFalse(r.cobranca_fim_do_dia(ROTINA, tarefas, um, em(QUINTA, "22:00")))
        self.assertFalse(r.cobranca_fim_do_dia(ROTINA, r.tarefas_do_dia(ROTINA, SABADO), {}, em(SABADO, "21:40")))

    def test_janela_bate(self):
        tr = next(t for t in ROTINA["tarefas"] if t["id"] == "trabalho")
        claude = [("com.anthropic.Claude", "planilha do trabalho", True)]
        ff = [("firefox", "Planilha do trabalho — Mozilla Firefox", False)]
        self.assertFalse(r.janela_bate(tr, claude))
        self.assertTrue(r.janela_bate(tr, ff))
        self.assertFalse(r.janela_bate(tr, ff, so_ativa=True))

    def test_texto_bate(self):
        tr = next(t for t in ROTINA["tarefas"] if t["id"] == "trabalho")
        self.assertEqual(r.texto_bate(tr, "PLANILHA do Cliente"), ["planilha", "cliente"])
        self.assertEqual(r.texto_bate(tr, "nada aqui"), [])

if __name__ == "__main__":
    unittest.main()
