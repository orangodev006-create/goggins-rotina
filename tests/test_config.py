import unittest

from goggins.rotina import normalizar_rotina

BASE = {"minimo_metas": 2, "intervalo_cobranca": 60, "coach": {"nome": "DAVID GOGGINS", "sigla": "DG"}, "tarefas": []}


def tarefa(**kw):
    t = {"nome": "Estudar", "dias": [0, 1, 2], "inicio": "19:00", "fim": "20:00", "cobra": True,
         "verificacao": "manual"}
    t.update(kw)
    return t


class TestNormalizar(unittest.TestCase):
    def test_mantem_ajustes_gerais_e_troca_tarefas(self):
        nova, erros = normalizar_rotina(BASE, {"tarefas": [tarefa()]})
        self.assertEqual(erros, [])
        self.assertEqual(nova["intervalo_cobranca"], 60)
        self.assertEqual(nova["tarefas"][0]["id"], "estudar")
        nova, _ = normalizar_rotina(BASE, {"tarefas": [tarefa(id="estudar_fds")]})
        self.assertEqual(nova["tarefas"][0]["id"], "estudar_fds")
        self.assertEqual(BASE["tarefas"], [])  # não mexe no original

    def test_ids_unicos_e_sem_acento(self):
        nova, _ = normalizar_rotina(BASE, {"tarefas": [
            tarefa(nome="Ação diária"), tarefa(nome="Ação diária", inicio="20:00", fim="21:00")]})
        self.assertEqual([t["id"] for t in nova["tarefas"]], ["acao-diaria", "acao-diaria-2"])

    def test_tarefa_existente_mantem_id_ao_renomear(self):
        nova, _ = normalizar_rotina(BASE, {"tarefas": [tarefa(id="estudar", nome="Estudar muito")]})
        self.assertEqual(nova["tarefas"][0]["id"], "estudar")
        nova, _ = normalizar_rotina(BASE, {"tarefas": [tarefa(id="estudar_fds")]})
        self.assertEqual(nova["tarefas"][0]["id"], "estudar_fds")

    def test_palavras_de_texto_viram_lista(self):
        nova, erros = normalizar_rotina(BASE, {"tarefas": [tarefa(
            verificacao="prova", janela=" VS Code, github ,, ", ocr="def , Return", min_minutos="15")]})
        self.assertEqual(erros, [])
        t = nova["tarefas"][0]
        self.assertEqual((t["janela"], t["ocr"], t["min_minutos"]), (["vs code", "github"], ["def", "return"], 15))

    def test_mantem_janela_ignorar(self):
        nova, erros = normalizar_rotina(BASE, {"tarefas": [tarefa(
            verificacao="prova", janela="planilha", ocr="planilha", janela_ignorar=["com.anthropic.claude"])]})
        self.assertEqual(erros, [])
        self.assertEqual(nova["tarefas"][0]["janela_ignorar"], ["com.anthropic.claude"])

    def test_erros(self):
        casos = {
            "sem nome": tarefa(nome="  "),
            "sem dia": tarefa(dias=[]),
            "hora inválida": tarefa(inicio="25:00"),
            "fim antes do início": tarefa(inicio="20:00", fim="19:00"),
            "prova sem palavras": tarefa(verificacao="prova", janela="", ocr=""),
        }
        for caso, t in casos.items():
            _, erros = normalizar_rotina(BASE, {"tarefas": [t]})
            self.assertTrue(erros, caso)

    def test_sobreposicao_no_mesmo_dia(self):
        _, erros = normalizar_rotina(BASE, {"tarefas": [
            tarefa(nome="A", inicio="19:00", fim="20:00"), tarefa(nome="B", inicio="19:30", fim="21:00", dias=[2])]})
        self.assertTrue(any("ao mesmo tempo" in e for e in erros))
        _, erros = normalizar_rotina(BASE, {"tarefas": [
            tarefa(nome="A", inicio="19:00", fim="20:00"), tarefa(nome="B", inicio="19:30", fim="21:00", dias=[5])]})
        self.assertEqual(erros, [])

    def test_coach(self):
        nova, _ = normalizar_rotina(BASE, {"tarefas": [], "coach": {"nome": " sargento ", "sigla": "sgt"}})
        self.assertEqual((nova["coach"]["nome"], nova["coach"]["sigla"]), ("SARGENTO", "SGT"))


if __name__ == "__main__":
    unittest.main()
