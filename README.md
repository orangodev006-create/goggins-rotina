# Goggins Rotina

Um "David Goggins" pro seu Linux. Ele conhece a sua rotina da semana, mostra as tarefas do dia quando você
liga o PC, pergunta como tá indo e, se você passar do horário sem começar, **aparece a cada minuto
te cobrando**. Começou a tarefa? Ele para e te parabeniza. Quer marcar como feita? **Prova**: ele
tira um print na hora e confere se a tarefa está mesmo na tela.

Feito pra **KDE Plasma 6 no Wayland** (testado no Arch Linux). Tudo roda local, sem conta, sem chave de API
e sem serviço de fora.

> Projeto de fã, sem nenhuma ligação com o David Goggins. Não vem com foto nem voz de ninguém:
> você coloca as suas (veja [Personalizar](#personalizar)).

## Como funciona

| Momento | O que acontece |
|---|---|
| Ligou o PC | popup sem som com **as tarefas de hoje** |
| Começou o bloco de uma tarefa | 5 min calado |
| 5 min depois | popup sem som: **"Como tá indo aí?"** |
| Mais 5 min e você ainda não começou | **cobrança com áudio a cada 1 minuto** |
| Abriu a janela da tarefa (ex.: o editor, o curso) | ele para e te dá **parabéns** |
| Marcou "FIZ" no painel | o painel some e abre a **janela de prova** |
| Concluiu uma tarefa | 5 min de silêncio e o ciclo recomeça pra tarefa do bloco atual |
| Fez as metas do dia | "Dia cumprido" |
| 21:30 com menos de 2 metas feitas | cobrança até 22:00 |

**A prova** só aprova se as três coisas baterem:

1. tem uma **janela da tarefa aberta** (o título ou o app bate com as palavras de `janela` da tarefa);
2. o **print** tirado na hora (Spectacle + OCR do Tesseract) mostra palavras de `ocr` da tarefa;
3. você ficou o **tempo mínimo** com a janela da tarefa ativa (`min_minutos`).

O tempo em cima da tarefa é contado olhando, a cada 3 s, qual janela está ativa (via script do KWin).

## Instalar

```bash
sudo pacman -S python-gobject qt6-declarative qt6-multimedia qt6-tools spectacle tesseract tesseract-data-por curl
git clone https://github.com/SEU_USUARIO/goggins-rotina.git ~/goggins-rotina
cd ~/goggins-rotina
./install.sh
```

O `install.sh` cria o serviço `goggins` do systemd (ele inicia junto com o Plasma) e instala o painel
**Goggins Dashboard**. Pra colocar o painel na área de trabalho: botão direito → *Adicionar widgets* →
*Goggins Dashboard*. Só quer os popups, sem o painel? `./install.sh --sem-painel`.

## Personalizar

Tudo é arquivo de texto. Depois de mudar, rode `systemctl --user restart goggins`.

- **`rotina.json`**: as tarefas, os dias (`0` = segunda … `6` = domingo), os horários, quanto tempo mínimo,
  as palavras que ele procura nas janelas e no print, se a tarefa cobra ou não, e os tempos (`checkin_min`,
  `cobrar_depois_checkin_min`, `silencio_apos_feito_min`, `intervalo_cobranca` em segundos).
  Em `"coach"` ficam o nome, a sigla e a foto que aparecem no popup: dá pra trocar o Goggins por quem você quiser.
- **`falas.json`**: os textos de cobrança e de parabéns.
- **`audios/`**: os mp3 de cada fala ([como gravar](audios/LEIA-ME.md)).
- **`imagens/coach.png`** e **`plasmoid/contents/imagens/capa.png`**: as imagens ([detalhes](imagens/LEIA-ME.md)).
- **Visual do popup**: `qml/Cartao.qml` (moldura, cores, foto) e `qml/Popup.qml` (tamanho, tempo na tela).
  A posição na tela fica em `goggins/kwin/topo.js`.
- **Fuso horário**: usa a hora do sistema. Se o seu sistema está em UTC, defina `GOGGINS_FUSO` no serviço
  (ex.: `Environment=GOGGINS_FUSO=America/Sao_Paulo`).

## Comandos

```bash
./goggins-ctl estado            # tarefas de hoje e o que ele está fazendo
./goggins-ctl testar cobranca   # mostra um popup de teste (cobranca | parabens | fim_dia)
./goggins-ctl log               # acompanha o que ele faz
systemctl --user stop goggins   # dá um tempo pro Goggins
```

## Privacidade

- A API do daemon só escuta em `127.0.0.1:47777` (só o seu PC acessa). É por ela que o painel conversa com ele.
- Os prints das provas e o estado do dia ficam em `~/.local/state/goggins/`. Nada sai do seu computador.

## Estrutura

```
goggins/daemon.py     # loop principal, regras, popups e API local
goggins/rotina.py     # regras puras (bloco atual, quando cobrar), com testes
goggins/janelas.py    # lista de janelas via KWin (D-Bus)
goggins/prova.py      # print + OCR + avaliação
goggins/kwin/         # scripts do KWin (listar janelas, posicionar popups)
qml/                  # popup e janela de prova
plasmoid/             # painel "Goggins Dashboard" (abas discord / tarefas do dia)
```

Testes: `python3 -m unittest`.

## Licença

MIT
