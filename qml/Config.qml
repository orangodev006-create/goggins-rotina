// "Monte sua rotina": a pessoa escolhe o que o Goggins cobra. O daemon abre: qml6 Config.qml -- caixa=file:///…/caixa/
// Conversa com o daemon por arquivos na caixa (pasta privada), sem rede.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic

Window {
    id: janela
    title: "GOGGINS-CONFIG"
    width: 1020
    height: 700
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    readonly property var args: {
        const a = {}
        for (const s of Qt.application.arguments) {
            const i = s.indexOf("=")
            if (i > 0) a[s.slice(0, i)] = s.slice(i + 1)
        }
        return a
    }
    readonly property string caixa: args.caixa || ""
    readonly property color vermelho: "#e3141f"
    readonly property color texto: "#f1ebeb"
    readonly property color suave: "#a39a9b"
    readonly property color campo: "#140b0d"
    readonly property var nomesDias: ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"]

    property var tarefas: []
    property int sel: -1
    property int versao: 0          // muda quando uma tarefa é editada, pra lista redesenhar
    property var erros: []
    property string aviso: ""
    readonly property var atual: sel >= 0 && sel < tarefas.length ? tarefas[sel] : null

    property string pedidoId: ""

    function ler(nome, pronto) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let obj = null
            try { obj = JSON.parse(xhr.responseText) } catch (e) {}
            pronto(obj)
        }
        xhr.open("GET", caixa + nome)
        xhr.send()
    }
    function escrever(nome, obj) {
        const xhr = new XMLHttpRequest()
        xhr.open("PUT", caixa + nome)
        xhr.send(JSON.stringify(obj))
    }
    function lista(v) { return Array.isArray(v) ? v.join(", ") : (v || "") }
    function nova() {
        return { nome: "", dias: [0, 1, 2, 3, 4], inicio: "19:00", fim: "20:00", cobra: true,
                 verificacao: "manual", janela: "", ocr: "", min_minutos: 20 }
    }
    function adicionar() {
        const t = tarefas.slice()
        t.push(nova())
        tarefas = t
        selecionar(t.length - 1)
    }
    function apagar(i) {
        const t = tarefas.slice()
        t.splice(i, 1)
        tarefas = t
        selecionar(Math.min(sel, t.length - 1))
    }
    function selecionar(i) {
        sel = i
        aviso = ""
        if (!atual) return
        fNome.text = atual.nome
        fInicio.text = atual.inicio
        fFim.text = atual.fim
        fJanela.text = lista(atual.janela)
        fOcr.text = lista(atual.ocr)
        fMin.text = String(atual.min_minutos === undefined ? 20 : atual.min_minutos)
        fNome.forceActiveFocus()
    }
    function setar(campo, valor) {
        if (!atual) return
        atual[campo] = valor
        versao++
        aviso = ""
    }
    function salvar() {
        pedidoId = String(Date.now())
        escrever("pedido-config.json", { id: pedidoId, coach: { nome: fCoach.text, sigla: fSigla.text }, tarefas: tarefas })
        aviso = ""
        esperando.tentativas = 0
        esperando.start()
    }
    // o daemon olha a caixa a cada segundo e deixa a resposta lá
    Timer {
        id: esperando
        property int tentativas: 0
        interval: 400; repeat: true
        onTriggered: {
            if (++tentativas > 25) {
                stop()
                janela.erros = ["O Goggins (daemon) não respondeu. Ele está rodando?"]
                return
            }
            janela.ler("resultado-config.json", function (r) {
                if (!r || r.id !== janela.pedidoId || !esperando.running) return
                esperando.stop()
                janela.erros = r.erros || []
                if (r.ok) {
                    janela.aviso = "Salvo. O Goggins já está cobrando a rotina nova."
                    janela.carregar()
                }
            })
        }
    }
    function carregar() {
        ler("config.json", function (c) {
            if (!c) { janela.erros = ["O Goggins (daemon) não respondeu. Ele está rodando?"]; return }
            fCoach.text = c.coach.nome || ""
            fSigla.text = c.coach.sigla || ""
            janela.tarefas = c.tarefas
            if (c.tarefas.length === 0) janela.adicionar()
            else janela.selecionar(Math.max(0, Math.min(janela.sel, c.tarefas.length - 1)))
        })
    }
    Component.onCompleted: carregar()

    // ---------- peças ----------
    component Campo: TextField {
        color: janela.texto
        placeholderTextColor: "#6d6466"
        selectByMouse: true
        font.pixelSize: 15
        leftPadding: 12
        background: Rectangle {
            implicitHeight: 38
            radius: 10
            color: janela.campo
            border.color: parent.activeFocus ? janela.vermelho : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
        }
    }
    component Rotulo: Text {
        color: janela.suave
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 1.5
    }
    component Alternar: Item {
        id: alt
        property bool ligado: false
        property string texto: ""
        signal trocou(bool valor)
        implicitWidth: linhaAlt.implicitWidth
        implicitHeight: 30
        Row {
            id: linhaAlt
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: 44; height: 24; radius: 12
                color: alt.ligado ? janela.vermelho : janela.campo
                border.color: alt.ligado ? janela.vermelho : Qt.rgba(1, 1, 1, 0.2)
                Rectangle {
                    width: 18; height: 18; radius: 9
                    y: 3; x: alt.ligado ? 23 : 3
                    color: "white"
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
            }
            Text { text: alt.texto; color: janela.texto; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: alt.trocou(!alt.ligado) }
    }
    component Botao: Rectangle {
        id: bt
        property string texto: ""
        property bool cheio: true
        signal clicado()
        implicitWidth: rot.implicitWidth + 40
        implicitHeight: 42
        radius: 21
        color: cheio ? (m.containsMouse ? "#ff3b3b" : janela.vermelho) : "transparent"
        border.color: janela.vermelho
        border.width: 1.5
        Text { id: rot; anchors.centerIn: parent; text: bt.texto; color: "white"; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1 }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.clicado() }
    }

    Cartao {
        id: cartao
        anchors.fill: parent
        anchors.margins: 22
        comFoto: false
        nome: janela.args.nome || "DAVID GOGGINS"
        sigla: janela.args.sigla || "DG"
        subtitulo: "MONTE SUA ROTINA • O QUE EU VOU COBRAR"
        onFechar: Qt.quit()

        RowLayout {
            anchors.fill: parent
            spacing: 20

            // ---------- lista de tarefas ----------
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Rotulo { text: "SUAS TAREFAS" }
                    Item { Layout.fillWidth: true }
                    Botao { texto: "+ NOVA"; implicitHeight: 32; onClicado: janela.adicionar() }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: janela.tarefas
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property int v: janela.versao   // redesenha ao editar
                        width: ListView.view.width
                        height: 60
                        radius: 12
                        color: index === janela.sel ? Qt.rgba(0.89, 0.08, 0.12, 0.14) : "transparent"
                        border.color: index === janela.sel ? janela.vermelho : Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.selecionar(item.index) }
                        Column {
                            anchors.left: parent.left
                            anchors.right: lixo.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            spacing: 3
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: (item.v, item.modelData.nome || "(sem nome)")
                                color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold
                            }
                            Text {
                                text: (item.v, item.modelData.inicio + "–" + item.modelData.fim + "  ·  "
                                       + item.modelData.dias.map(d => janela.nomesDias[d]).join(" "))
                                color: janela.suave; font.pixelSize: 12; font.family: "Noto Sans Mono"
                            }
                        }
                        Text {
                            id: lixo
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            color: lm.containsMouse ? "#ff3b3b" : janela.suave
                            font.pixelSize: 16
                            MouseArea { id: lm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.apagar(item.index) }
                        }
                    }
                }
                Rotulo { text: "QUEM COBRA (NOME NO POPUP)" }
                RowLayout {
                    Layout.fillWidth: true
                    Campo { id: fCoach; Layout.fillWidth: true; placeholderText: "DAVID GOGGINS" }
                    Campo { id: fSigla; Layout.preferredWidth: 64; placeholderText: "DG"; maximumLength: 3 }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Qt.rgba(0.89, 0.08, 0.12, 0.3) }

            // ---------- tarefa selecionada ----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                enabled: janela.atual !== null
                opacity: enabled ? 1 : 0.4

                Rotulo { text: "O QUE VOCÊ TEM QUE FAZER" }
                Campo { id: fNome; Layout.fillWidth: true; placeholderText: "ex.: Estudar inglês, Treinar, Programar"; maximumLength: 40; onTextEdited: janela.setar("nome", text) }

                Rotulo { text: "EM QUAIS DIAS"; Layout.topMargin: 6 }
                Row {
                    spacing: 8
                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            required property int index
                            readonly property bool marcado: (janela.versao, janela.atual && janela.atual.dias.indexOf(index) >= 0)
                            width: 52; height: 34; radius: 17
                            color: marcado ? janela.vermelho : janela.campo
                            border.color: marcado ? janela.vermelho : Qt.rgba(1, 1, 1, 0.15)
                            Text { anchors.centerIn: parent; text: janela.nomesDias[index]; color: "white"; font.pixelSize: 12; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = janela.atual.dias.filter(x => x !== index)
                                    if (!parent.marcado) d.push(index)
                                    janela.setar("dias", d.sort())
                                }
                            }
                        }
                    }
                }

                Rotulo { text: "HORÁRIO"; Layout.topMargin: 6 }
                RowLayout {
                    spacing: 10
                    Text { text: "das"; color: janela.suave; font.pixelSize: 14 }
                    Campo { id: fInicio; Layout.preferredWidth: 90; placeholderText: "19:00"; inputMask: "99:99"; onTextEdited: janela.setar("inicio", text) }
                    Text { text: "até"; color: janela.suave; font.pixelSize: 14 }
                    Campo { id: fFim; Layout.preferredWidth: 90; placeholderText: "20:00"; inputMask: "99:99"; onTextEdited: janela.setar("fim", text) }
                }

                Alternar {
                    Layout.topMargin: 8
                    texto: "Cobrar se eu passar do horário (popup a cada minuto)"
                    ligado: (janela.versao, janela.atual ? janela.atual.cobra : false)
                    onTrocou: v => janela.setar("cobra", v)
                }
                Alternar {
                    texto: "Pedir prova com print pra marcar como feita"
                    ligado: (janela.versao, janela.atual ? janela.atual.verificacao === "prova" : false)
                    onTrocou: v => janela.setar("verificacao", v ? "prova" : "manual")
                }

                // só quando pede prova
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: (janela.versao, janela.atual ? janela.atual.verificacao === "prova" : false)
                    Rotulo { text: "PALAVRAS NO TÍTULO DA JANELA DA TAREFA (separe por vírgula)" }
                    Campo { id: fJanela; Layout.fillWidth: true; placeholderText: "ex.: code, github, duolingo"; onTextEdited: janela.setar("janela", text) }
                    Rotulo { text: "PALAVRAS QUE APARECEM NA TELA QUANDO VOCÊ FAZ" }
                    Campo { id: fOcr; Layout.fillWidth: true; placeholderText: "ex.: function, return, lição"; onTextEdited: janela.setar("ocr", text) }
                    RowLayout {
                        spacing: 10
                        Rotulo { text: "MÍNIMO DE MINUTOS COM A JANELA ATIVA" }
                        Campo {
                            id: fMin
                            Layout.preferredWidth: 70
                            validator: IntValidator { bottom: 0; top: 600 }
                            onTextEdited: janela.setar("min_minutos", parseInt(text) || 0)
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    visible: janela.erros.length > 0 || janela.aviso !== ""
                    wrapMode: Text.WordWrap
                    text: janela.erros.length ? "✕ " + janela.erros.join("\n✕ ") : "✓ " + janela.aviso
                    color: janela.erros.length ? "#ff5a5a" : "#3ddc6c"
                    font.pixelSize: 13
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Botao { texto: "FECHAR"; cheio: false; onClicado: Qt.quit() }
                    Botao { texto: "SALVAR ROTINA"; onClicado: janela.salvar() }
                }
            }
        }
    }

    // arrastar a janela pelo cabeçalho (ela não tem barra de título)
    Item {
        x: 22; y: 22
        width: parent.width - 120
        height: 86
        DragHandler { target: null; onActiveChanged: if (active) janela.startSystemMove() }
    }
}
