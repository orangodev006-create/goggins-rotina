// Moldura comum do Goggins: card preto, borda vermelha com brilho, cabeçalho com o nome do coach e o X
import QtQuick
import QtQuick.Effects

Item {
    id: cartao
    property string subtitulo: ""
    // vêm do rotina.json ("coach") pelos argumentos da janela
    property string nome: "DAVID GOGGINS"
    property string sigla: "DG"
    property string foto: ""
    property var recorte: undefined
    property bool comFoto: true
    property real escala: 1.0
    default property alias conteudo: corpo.data
    signal fechar()

    readonly property color vermelho: "#e3141f"

    Rectangle {
        id: fundo
        anchors.fill: parent
        radius: 26 * cartao.escala
        color: "#050304"
        border.color: cartao.vermelho
        border.width: 2
        visible: false
    }
    MultiEffect {
        source: fundo
        anchors.fill: fundo
        shadowEnabled: true
        shadowColor: cartao.vermelho
        shadowBlur: 1.0
        shadowScale: 1.02
    }

    // foto P&B à esquerda, sumindo pro preto
    Item {
        id: foto
        visible: cartao.comFoto && cartao.foto !== ""
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2
        width: visible ? Math.min(parent.width * 0.32, 300 * cartao.escala) : 0
        clip: true
        Image {
            anchors.fill: parent
            source: cartao.foto ? "file://" + cartao.foto : ""
            sourceClipRect: cartao.recorte ? Qt.rect(cartao.recorte[0], cartao.recorte[1], cartao.recorte[2], cartao.recorte[3]) : undefined
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop
            smooth: true; mipmap: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1.0; color: "#050304" }
            }
        }
    }

    // cabeçalho
    Item {
        id: cabecalho
        anchors.left: foto.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 18 * cartao.escala
        anchors.rightMargin: 22 * cartao.escala
        height: 86 * cartao.escala

        Rectangle {
            id: selo
            anchors.verticalCenter: parent.verticalCenter
            width: 52 * cartao.escala; height: width; radius: 10 * cartao.escala
            color: cartao.vermelho
            Text {
                anchors.centerIn: parent
                text: cartao.sigla
                color: "#0a0204"
                font.pixelSize: 22 * cartao.escala
                font.weight: Font.Black
            }
        }
        Column {
            anchors.left: selo.right
            anchors.leftMargin: 16 * cartao.escala
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: cartao.nome
                color: "#e9e6e6"
                font.pixelSize: 25 * cartao.escala
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
            }
            Text {
                visible: text !== ""
                text: cartao.subtitulo
                color: cartao.vermelho
                font.pixelSize: Math.max(10, 12 * cartao.escala)
                font.weight: Font.Bold
                font.letterSpacing: 2
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: xMouse.containsMouse ? "#ff4b4b" : cartao.vermelho
            font.pixelSize: 30 * cartao.escala
            MouseArea {
                id: xMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cartao.fechar()
            }
        }
    }
    Rectangle {
        anchors.left: cabecalho.left
        anchors.leftMargin: -18 * cartao.escala
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.top: cabecalho.bottom
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: cartao.vermelho }
            GradientStop { position: 1.0; color: Qt.rgba(0.89, 0.08, 0.12, 0.25) }
        }
    }

    Item {
        id: corpo
        anchors.left: cabecalho.left
        anchors.right: cabecalho.right
        anchors.top: cabecalho.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 14 * cartao.escala
        anchors.bottomMargin: 18 * cartao.escala
    }
}
