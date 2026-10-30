# Goggins Rotina

Um "David Goggins" pro seu Linux. **Você escolhe o que ele vai cobrar**: monta a sua rotina da semana
numa janela no mesmo estilo dos popups. Depois ele mostra as tarefas do dia quando você liga o PC,
pergunta como tá indo e, se você passar do horário sem começar, **aparece a cada minuto te cobrando**. Começou a tarefa? Ele para e te parabeniza. Quer marcar como feita? **Prova**: ele
tira um print na hora e confere se a tarefa está mesmo na tela.

Feito pra **KDE Plasma 6 no Wayland**. Tudo roda local, sem conta, sem chave de API e sem serviço de fora.

> [!WARNING]
> **Testado só no Arch Linux com KDE Plasma 6.8 (Wayland).** Em outra distro, outro desktop (GNOME, XFCE…),
> no X11 ou em outra versão do Plasma, pode não funcionar ou precisar de ajustes. O projeto mexe no seu
> sistema: cria um serviço do systemd que inicia sozinho, carrega scripts no KWin, instala um widget no
> Plasma e tira prints da sua tela.
>
> **Antes de instalar, mande os arquivos pra uma IA avaliar** (Claude, ChatGPT, Gemini…). Peça pra ela ler
> o `install.sh`, o `goggins/daemon.py` e o resto, dizer o que cada parte faz no seu PC e se vai funcionar
> na sua distro e no seu desktop, e adaptar o que for preciso. Um pedido que funciona bem:
>
> *"Leia todos os arquivos deste projeto e me diga: o que ele instala e altera no meu sistema, se tem algo
> perigoso, e se vai funcionar no meu sistema ([sua distro], [seu desktop], X11 ou Wayland). Se precisar,
> adapte pra mim."*
>
> Use por sua conta e risco: o software vem sem garantia (veja a [licença](LICENSE)).

> Projeto de fã, sem nenhuma ligação com o David Goggins. Não vem com foto nem voz de ninguém:
> você coloca as suas (veja [Personalizar](#personalizar)).

## Como funciona

| Momento | O que acontece |
|---|---|
| Primeira vez | abre a janela **"Monte sua rotina"**: você cria as tarefas, os dias e os horários |
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

> Leu o aviso lá em cima? Peça pra uma IA revisar os arquivos antes, principalmente se você não usa
> Arch + KDE Plasma 6 no Wayland.

```bash
sudo pacman -S python-gobject qt6-declarative qt6-multimedia qt6-tools spectacle tesseract tesseract-data-por
git clone https://github.com/orangodev006-create/goggins-rotina.git ~/goggins-rotina
cd ~/goggins-rotina
./install.sh
```

O `install.sh` cria o serviço `goggins` do systemd (ele inicia junto com o Plasma) e instala o painel
**Goggins Dashboard**. Na primeira vez abre a janela **"Monte sua rotina"**: o projeto vem sem nenhuma
tarefa, quem decide o que vai ser cobrado é você. Pra colocar o painel na área de trabalho: botão direito → *Adicionar widgets* →
*Goggins Dashboard*. Só quer os popups, sem o painel? `./install.sh --sem-painel`.

## Monte sua rotina

Abra a janela quando quiser: pela engrenagem na aba **tarefas do dia** do painel, ou com
`./goggins-ctl configurar`. Pra cada tarefa você escolhe:

- **o que** é (ex.: Estudar inglês, Treinar, Programar) e **em quais dias** / **de que horas a que horas**;
- se ele **cobra** quando você passa do horário;
- se precisa de **prova com print** pra marcar como feita. Se sim, quais palavras aparecem no **título da janela**
  da tarefa (ex.: `duolingo`, `code`), quais aparecem **na tela** quando você está fazendo (pro OCR do print)
  e o **mínimo de minutos** com essa janela ativa.

Ali também dá pra trocar **quem cobra**: o nome e a sigla que aparecem no popup.

## Personalizar

Tudo é arquivo de texto. Depois de mudar à mão, rode `systemctl --user restart goggins`.

- **`rotina.json`**: o que a janela "Monte sua rotina" salva, mais os ajustes gerais em minutos/segundos
  (`checkin_min`, `cobrar_depois_checkin_min`, `silencio_apos_feito_min`, `intervalo_cobranca`, `minimo_metas`).
  Em `"coach"` ficam o nome, a sigla e a foto do popup.
- **`falas.json`**: os textos de cobrança e de parabéns.
- **`audios/`**: os mp3 de cada fala ([como gravar](audios/LEIA-ME.md)).
- **`imagens/coach.png`** e **`plasmoid/contents/imagens/capa.png`**: as imagens ([detalhes](imagens/LEIA-ME.md)).
- **Visual do popup**: `qml/Cartao.qml` (moldura, cores, foto) e `qml/Popup.qml` (tamanho, tempo na tela).
  A posição na tela fica em `goggins/kwin/topo.js`.
- **Fuso horário**: usa a hora do sistema. Se o seu sistema está em UTC, defina `GOGGINS_FUSO` no serviço
  (ex.: `Environment=GOGGINS_FUSO=America/Sao_Paulo`).

## Comandos

```bash
./goggins-ctl configurar        # abre a janela "Monte sua rotina"
./goggins-ctl estado            # tarefas de hoje e o que ele está fazendo
./goggins-ctl testar cobranca   # mostra um popup de teste (cobranca | parabens | fim_dia)
./goggins-ctl log               # acompanha o que ele faz
systemctl --user stop goggins   # dá um tempo pro Goggins
```

## Privacidade

- **Não tem servidor nem porta de rede.** O painel e o `goggins-ctl` falam com o daemon pelo **D-Bus da sua sessão**,
  que só programas rodando como o seu usuário alcançam (um site aberto no navegador não consegue mandar comandos).
  As janelas de prova e de configuração trocam arquivos numa pasta privada (`~/.local/state/goggins/caixa`, permissão 700).
- Os prints das provas e o estado do dia ficam em `~/.local/state/goggins/`. Nada sai do seu computador.

## Estrutura

```
goggins/daemon.py     # loop principal, regras, popups e API local
goggins/rotina.py     # regras puras (bloco atual, quando cobrar), com testes
goggins/janelas.py    # lista de janelas via KWin (D-Bus)
goggins/prova.py      # print + OCR + avaliação
goggins/kwin/         # scripts do KWin (listar janelas, posicionar popups)
qml/                  # popup, janela de prova e "Monte sua rotina"
plasmoid/             # painel "Goggins Dashboard" (abas discord / tarefas do dia)
```

Testes: `python3 -m unittest`.

## Licença

MIT
