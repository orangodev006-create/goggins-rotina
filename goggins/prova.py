"""Prova de que a tarefa foi feita: print tirado na hora + OCR + janela aberta + tempo em cima dela."""
import subprocess
import time
from pathlib import Path

from goggins.rotina import janela_bate, texto_bate


def tirar_print(destino: Path, espera: float = 10.0) -> Path:
    destino = Path(destino)
    destino.unlink(missing_ok=True)
    subprocess.run(["spectacle", "-b", "-n", "-f", "-o", str(destino)], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # o spectacle volta antes de gravar o arquivo
    fim = time.monotonic() + espera
    while time.monotonic() < fim:
        if destino.exists() and destino.stat().st_size > 0:
            time.sleep(0.3)
            return destino
        time.sleep(0.2)
    raise RuntimeError("o Spectacle não gerou o print")


def ocr(imagem: Path) -> str:
    r = subprocess.run(["tesseract", str(imagem), "-", "-l", "por"], capture_output=True, text=True, timeout=60)
    return r.stdout


def avaliar(tarefa: dict, janelas: list[tuple[str, str, bool]], texto: str, segundos: float) -> dict:
    minimo = tarefa.get("min_minutos", 0)
    minutos = int(segundos // 60)
    achados = texto_bate(tarefa, texto)
    checagens = [
        ("janela", janela_bate(tarefa, janelas),
         "janela da tarefa aberta" if janela_bate(tarefa, janelas) else "não achei nenhuma janela da tarefa aberta"),
        ("print", bool(achados),
         f"o print mostra: {', '.join(achados)}" if achados else "o print não mostra nada da tarefa"),
        ("tempo", minutos >= minimo,
         f"{minutos} de {minimo} min em cima da tarefa"),
    ]
    return {
        "aprovado": all(ok for _, ok, _ in checagens),
        "checagens": [{"nome": n, "ok": ok, "motivo": m} for n, ok, m in checagens],
        "minutos": minutos,
    }
