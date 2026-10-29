// Janela separada de prova: o Goggins só aceita "fiz" com print tirado na hora.
// Uso: qml6 Prova.qml -- tarefa=trabalho porta=47777
import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: janela
    title: "GOGGINS-PROVA"
    width: 900
    height: 520
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    readonly property var args: {
        const a = {}
        for (const s of Qt.application.arguments) {
            const i = s.indexOf("=")
            if (i > 0) a[s.slice(0, i)] = s.slice(i + 1)
        }
        return a
    }
    readonly property string api: "http://127.0.0.1:" + (args.porta || "47777")
    readonly property color vermelho: "#e3141f"

    property var tarefa: null
    property string janelaAtiva: ""
    // fase: "pedir" -> "contando" -> "analisando" -> "resultado"
    property string fase: "pedir"
    property int contagem: 5
    property var resultado: null

    function pedir(metodo, caminho, pronto) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let obj = null
            try { obj = JSON.parse(xhr.responseText) } catch (e) {}
            pronto(obj)
        }
        xhr.open(metodo, api + caminho)
        xhr.send()
    }
    function atualizar() {
        pedir("GET", "/estado", function (e) {
            if (!e) return
            janela.janelaAtiva = e.janela_ativa
            for (const t of e.tarefas) if (t.id === args.tarefa) janela.tarefa = t
        })
    }
    Component.onCompleted: atualizar()
    Timer { interval: 3000; repeat: true; running: janela.fase === "pedir" || janela.fase === "resultado"; onTriggered: janela.atualizar() }

    function comecar() {
        fase = "contando"
        contagem = 5
        janela.visible = false
        tique.start()
    }
    Timer {
        id: tique
        interval: 1000; repeat: true
        onTriggered: {
            if (--janela.contagem > 0) return
            stop()
            janela.fase = "analisando"
            janela.pedir("POST", "/provar?tarefa=" + janela.args.tarefa, function (r) {
                janela.resultado = r || { aprovado: false, checagens: [{ ok: false, motivo: "o Goggins (daemon) não respondeu" }] }
                janela.fase = "resultado"
                janela.atualizar()
            })
            // volta a aparecer enquanto o OCR roda (o print já foi tirado)
            reaparecer.start()
        }
    }
    Timer { id: reaparecer; interval: 3000; onTriggered: janela.visible = true }

    Cartao {
        anchors.fill: parent
        anchors.margins: 22
        nome: janela.args.nome || "DAVID GOGGINS"
        sigla: janela.args.sigla || "DG"
        foto: janela.args.foto || ""
        recorte: janela.args.recorte ? janela.args.recorte.split(",").map(Number) : undefined
        subtitulo: "VERIFICAÇÃO • " + (janela.tarefa ? janela.tarefa.nome.toUpperCase() : "")
        onFechar: Qt.quit()

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#f4f0f0"
                font.pixelSize: 24
                font.weight: Font.Bold
                text: janela.fase === "resultado"
                      ? (janela.resultado.aprovado ? "Aprovado. Isso é ser duro consigo mesmo." : "Recusado. Você não me engana.")
                      : janela.fase === "analisando" ? "Analisando o seu print…"
                      : "Diz que fez? Prova. Deixa " + (janela.tarefa ? janela.tarefa.nome : "a tarefa") + " aberta na tela que eu tiro o print."
            }

            // checagens
            Column {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: janela.fase === "resultado" ? janela.resultado.checagens : []
                    delegate: Row {
                        spacing: 10
                        Text { text: modelData.ok ? "✓" : "✕"; color: modelData.ok ? "#3ddc6c" : janela.vermelho; font.pixelSize: 17; font.weight: Font.Black }
                        Text { text: modelData.motivo; color: "#d8d2d2"; font.pixelSize: 15 }
                    }
                }
            }

            // o que ele já viu
            Column {
                Layout.fillWidth: true
                spacing: 4
                visible: janela.fase === "pedir"
                Text {
                    color: "#a39a9b"; font.pixelSize: 14
                    text: janela.tarefa ? "Tempo em cima da tarefa: " + janela.tarefa.minutos + " de " + janela.tarefa.min_minutos + " min" : ""
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    color: "#a39a9b"; font.pixelSize: 14
                    text: "Janela ativa agora: " + (janela.janelaAtiva || "—")
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    visible: janela.fase === "pedir" || (janela.fase === "resultado" && !janela.resultado.aprovado)
                    implicitWidth: rotulo.implicitWidth + 44; implicitHeight: 48; radius: 24
                    color: botao.containsMouse ? "#ff3b3b" : janela.vermelho
                    Text {
                        id: rotulo
                        anchors.centerIn: parent
                        text: janela.fase === "pedir" ? "TIRAR PRINT EM 5 s" : "TENTAR DE NOVO"
                        color: "white"; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1
                    }
                    MouseArea {
                        id: botao
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.comecar()
                    }
                }
                Rectangle {
                    implicitWidth: rotulo2.implicitWidth + 44; implicitHeight: 48; radius: 24
                    color: "transparent"
                    border.color: janela.vermelho; border.width: 1.5
                    Text {
                        id: rotulo2
                        anchors.centerIn: parent
                        text: "FECHAR"
                        color: "#f4f0f0"; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: janela.fase === "pedir"
                    text: "a janela some, você tem 5 s\npra deixar a tarefa na tela"
                    color: "#a39a9b"; font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
