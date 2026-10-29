// Popup do Goggins: frase digitando + áudio (opcional).
// Uso: qml6 Popup.qml -- tipo=cobranca texto="..." [audio=/caminho.mp3] [sub="SUBTÍTULO"]
import QtQuick
import QtQuick.Window
import QtMultimedia

Window {
    id: janela
    title: "GOGGINS-POPUP"
    width: 600
    // a lista do dia precisa de mais altura
    height: agenda ? 120 + 30 * Math.max(1, frase.split("\n").length) : 200
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus

    readonly property var args: {
        const a = {}
        for (const s of Qt.application.arguments) {
            const i = s.indexOf("=")
            if (i > 0) a[s.slice(0, i)] = s.slice(i + 1)
        }
        return a
    }
    readonly property string tipo: args.tipo || "cobranca"
    readonly property string frase: args.texto || "Stay hard."
    readonly property bool agenda: tipo === "agenda"
    property int letras: 0

    Cartao {
        id: cartao
        anchors.fill: parent
        anchors.margins: 18
        escala: 0.7
        nome: janela.args.nome || "DAVID GOGGINS"
        sigla: janela.args.sigla || "DG"
        foto: janela.args.foto || ""
        recorte: janela.args.recorte ? janela.args.recorte.split(",").map(Number) : undefined
        subtitulo: janela.args.sub ? janela.args.sub
                 : ({ cobranca: "COBRANÇA", fim_dia: "DIA CUMPRIDO", checkin: "CHECK-IN" })[janela.tipo] || "STAY HARD"
        opacity: 0
        scale: 0.94
        onFechar: Qt.quit()

        Text {
            anchors.fill: parent
            text: janela.frase.slice(0, janela.letras)
            color: "#f4f0f0"
            font.pixelSize: janela.agenda ? 16 : 21
            font.family: janela.agenda ? "Noto Sans Mono" : "Noto Sans"
            lineHeight: janela.agenda ? 1.35 : 1.0
            minimumPixelSize: 12
            fontSizeMode: Text.Fit
            font.weight: janela.agenda ? Font.DemiBold : Font.Bold
            wrapMode: Text.WordWrap
            verticalAlignment: janela.agenda ? Text.AlignTop : Text.AlignVCenter
        }

        ParallelAnimation {
            running: true
            NumberAnimation { target: cartao; property: "opacity"; to: 1; duration: 220 }
            NumberAnimation { target: cartao; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
        }
    }

    Timer {
        interval: janela.agenda ? 8 : 28; repeat: true
        running: janela.letras < janela.frase.length
        onTriggered: janela.letras++
    }

    MediaPlayer {
        id: voz
        source: janela.args.audio ? "file://" + janela.args.audio : ""
        audioOutput: AudioOutput { volume: 1.0 }
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) saida.restart()
        Component.onCompleted: if (janela.args.audio) play()
    }
    // fecha um pouco depois do áudio; sem áudio fica um tempo fixo (a lista do dia, mais)
    Timer { id: saida; interval: 2500; onTriggered: Qt.quit() }
    Timer { interval: janela.agenda ? 15000 : 9000; running: true; onTriggered: Qt.quit() }
}
