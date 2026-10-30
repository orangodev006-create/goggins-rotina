import os
import stat
import tempfile
import unittest
from pathlib import Path

from goggins.canais import Caixa


class TestCaixa(unittest.TestCase):
    def test_pasta_privada(self):
        with tempfile.TemporaryDirectory() as d:
            c = Caixa(Path(d) / "goggins" / "caixa")
            for p in (c.pasta, c.pasta.parent):
                self.assertEqual(stat.S_IMODE(os.stat(p).st_mode), 0o700)
            c.escrever("x.json", {"a": 1})
            self.assertEqual(stat.S_IMODE(os.stat(c.pasta / "x.json").st_mode), 0o600)

    def test_pegar_le_uma_vez(self):
        with tempfile.TemporaryDirectory() as d:
            c = Caixa(Path(d) / "caixa")
            c.escrever("pedido.json", {"tarefa": "programar", "id": "1"})
            self.assertEqual(c.pegar("pedido.json"), {"tarefa": "programar", "id": "1"})
            self.assertIsNone(c.pegar("pedido.json"))

    def test_pedido_quebrado_e_descartado(self):
        with tempfile.TemporaryDirectory() as d:
            c = Caixa(Path(d) / "caixa")
            (c.pasta / "pedido.json").write_text("{meio arquivo")
            self.assertIsNone(c.pegar("pedido.json"))
            self.assertFalse((c.pasta / "pedido.json").exists())
            (c.pasta / "pedido.json").write_text("[1, 2]")
            self.assertIsNone(c.pegar("pedido.json"))


if __name__ == "__main__":
    unittest.main()
