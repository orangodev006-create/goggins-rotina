import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.private.mpris as Mpris
import org.kde.notificationmanager as NotificationManager
import org.kde.coreaddons as KCoreAddons
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import QtMultimedia
import Qt.labs.folderlistmodel

PlasmoidItem {
    id: root

    // ---------- ajustes rápidos ----------
    Settings { id: guarda; category: "goggins-dashboard"; property string aba: "discord" }

    // Música padrão quando nada estiver tocando (arquivo com "monster" no nome na pasta Música)
    readonly property string musicaPadrao: "Monster"
    readonly property string artistaPadrao: "Skillet"
    // imagem do meio do painel: coloque a sua em contents/imagens/capa.png
    readonly property string wallpaper: Qt.resolvedUrl("../imagens/capa.png")

    // ---------- paleta ----------
    readonly property color cPanel: Qt.rgba(0.035, 0.020, 0.025, 0.80)
    readonly property color cCard: Qt.rgba(0.045, 0.030, 0.035, 0.86)
    readonly property color cCardSolid: "#1a1114"
    readonly property color cRed: "#e3141f"
    readonly property color cRed2: "#ff3b3b"
    readonly property color cText: "#f1ebeb"
    readonly property color cSoft: "#a39a9b"
    readonly property color cOnAccent: "#ffffff"
    readonly property color cLinha: Qt.rgba(0.89, 0.08, 0.12, 0.35)
    readonly property color cLinhaFraca: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cPontoOff: Qt.rgba(1, 1, 1, 0.16)
    readonly property color cBordaPainel: Qt.rgba(0.89, 0.08, 0.12, 0.70)
    readonly property color cBordaCard: Qt.rgba(0.89, 0.08, 0.12, 0.40)
    readonly property color cSombra: Qt.rgba(0.89, 0.04, 0.08, 0.55)
    readonly property color cMini: Qt.rgba(0.04, 0.02, 0.03, 0.78)
    readonly property real raioCard: 18
    readonly property var paleta: ["#2a1215", "#7a0a10", "#b30f18", "#e3141f", "#ff3b3b", "#d9d9d9", "#8c8c8c"]

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // F3 (atalho global do widget) esconde/mostra o painel
    property bool painelVisivel: true
    activationTogglesExpanded: false
    Connections {
        target: Plasmoid
        function onActivated() { root.painelVisivel = !root.painelVisivel }
    }

    // ---------- dados ----------
    Sensors.Sensor { id: sCpu; sensorId: "cpu/all/usage"; updateRateLimit: 1500 }
    Sensors.Sensor { id: sRam; sensorId: "memory/physical/usedPercent"; updateRateLimit: 3000 }
    Sensors.Sensor { id: sDisk; sensorId: "disk/all/usedPercent"; updateRateLimit: 30000 }
    Sensors.Sensor { id: sTemp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: 3000 }
    Sensors.Sensor { id: sOs; sensorId: "os/system/prettyName" }
    Sensors.Sensor { id: sKernel; sensorId: "os/kernel/version" }
    Sensors.Sensor { id: sUptime; sensorId: "os/system/uptime"; updateRateLimit: 60000 }
    Sensors.Sensor { id: sHost; sensorId: "os/system/hostname" }
    Sensors.Sensor { id: sPlasma; sensorId: "os/plasma/plasmaVersion" }
    KCoreAddons.KUser { id: kuser }

    // player externo (Firefox, Spotify...) via MPRIS
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool externoTocando: player !== null && player !== undefined
                                           && player.playbackStatus === Mpris.PlaybackStatus.Playing

    // player próprio do painel, em loop infinito
    FolderListModel {
        id: pastaGoggins
        folder: StandardPaths.writableLocation(StandardPaths.MusicLocation)
        nameFilters: ["mp3", "m4a", "ogg", "opus", "flac", "wav", "webm"].map(e => "*onster*." + e)
        caseSensitive: false
        showDirs: false
    }
    readonly property var pastaAtual: pastaGoggins
    readonly property url arquivoMusica: pastaAtual.count > 0 ? pastaAtual.get(0, "fileUrl") : ""
    MediaPlayer {
        id: musica
        source: root.arquivoMusica
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: 0.8 }
    }
    readonly property bool localTocando: musica.playbackState === MediaPlayer.PlayingState
    readonly property bool temArquivo: arquivoMusica.toString() !== ""
    // mostra o player externo só quando ele está tocando e o do painel não
    readonly property bool usarExterno: externoTocando && !localTocando

    readonly property bool tocando: localTocando || externoTocando
    readonly property string titulo: usarExterno && player.track ? player.track : musicaPadrao
    readonly property string artista: usarExterno && player.artist ? player.artist : artistaPadrao
    readonly property string capa: usarExterno && player.artUrl ? player.artUrl : wallpaper
    property real posExterna: 0      // segundos
    readonly property real duracao: usarExterno ? (player.length > 0 ? player.length / 1000000 : 0) : musica.duration / 1000
    readonly property real posicao: usarExterno ? posExterna : musica.position / 1000

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.posExterna = root.player.position / 1000000 }
        function onTrackChanged() { root.posExterna = 0 }
    }
    Timer {
        interval: 1000; running: root.usarExterno; repeat: true
        onTriggered: root.posExterna = Math.min(root.duracao || 1e9, root.posExterna + 1)
    }

    function tocarPausar() {
        if (usarExterno) { player.PlayPause(); return }
        if (!temArquivo) return
        if (localTocando) musica.pause()
        else {
            if (externoTocando) player.Pause()
            musica.play()
        }
    }
    function proxima() {
        if (usarExterno) player.Next()
        else musica.position = 0
    }
    function anterior() {
        if (usarExterno) player.Previous()
        else musica.position = 0
    }

    // hora local do sistema
    property date agora: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.agora = new Date() }
    readonly property var brt: agora
    readonly property var diasSemana: ["DOMINGO", "SEGUNDA", "TERÇA", "QUARTA", "QUINTA", "SEXTA", "SÁBADO"]
    readonly property var meses: ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"]
    function dois(n) { return n < 10 ? "0" + n : "" + n }

    // notificações (filtradas pro Discord no delegate)
    NotificationManager.Notifications {
        id: notificacoes
        showExpired: true
        showDismissed: true
        showJobs: false
        showNotifications: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        limit: 60
    }
    function ehDiscord(entry, app) {
        return /discord|vesktop|webcord|armcord/i.test((entry || "") + " " + (app || ""))
    }
    function tempoAtras(d) {
        if (!d) return ""
        const s = Math.max(0, (root.agora - d) / 1000)
        if (s < 60) return "agora"
        if (s < 3600) return Math.floor(s / 60) + "min"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }
    // ---------- Goggins (daemon em 127.0.0.1:47777) ----------
    property string aba: guarda.aba
    onAbaChanged: guarda.aba = aba
    property var goggins: ({ online: false, tarefas: [] })
    property var perguntando: null
    property bool escondidoPelaProva: false
    function gogginsApi(metodo, caminho, pronto) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let obj = null
            if (xhr.status === 200) { try { obj = JSON.parse(xhr.responseText) } catch (e) {} }
            if (pronto) pronto(obj)
        }
        xhr.open(metodo, "http://127.0.0.1:47777" + caminho)
        xhr.send()
    }
    function atualizarGoggins() {
        gogginsApi("GET", "/estado", function (e) {
            root.goggins = e || { online: false, tarefas: [] }
            // a prova fechou: o painel volta
            if (root.escondidoPelaProva && e && !e.prova_aberta) {
                root.escondidoPelaProva = false
                root.painelVisivel = true
            }
        })
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.atualizarGoggins() }
    function responder(fiz) {
        const t = perguntando
        perguntando = null
        if (!t) return
        gogginsApi("POST", "/responder?tarefa=" + t.id + "&fiz=" + (fiz ? 1 : 0), function (r) {
            // pra não burlar: o painel some enquanto a janela de prova está aberta
            if (r && r.acao === "prova") {
                root.escondidoPelaProva = true
                root.painelVisivel = false
            }
            root.atualizarGoggins()
        })
    }

    function semHtml(t) { return (t || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/\n+/g, " ") }

    // ================= visual =================
    fullRepresentation: Item {
        opacity: root.painelVisivel ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        Layout.preferredWidth: 1200
        Layout.preferredHeight: 650
        Layout.minimumWidth: 900
        Layout.minimumHeight: 520

        Rectangle {
            id: painel
            anchors.fill: parent
            radius: 38
            color: root.cPanel
            border.color: root.cBordaPainel
            border.width: 1.5
            visible: false
        }
        MultiEffect {
            source: painel
            anchors.fill: painel
            shadowEnabled: true
            shadowColor: root.cSombra
            shadowBlur: 1.0
            shadowVerticalOffset: 10
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            // ---------- coluna esquerda ----------
            ColumnLayout {
                Layout.preferredWidth: 360
                Layout.maximumWidth: 360
                Layout.fillHeight: true
                spacing: 14

                // progresso do dia (vem do Goggins local; sem API de fora)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    radius: root.raioCard
                    color: root.cCard
                    border.color: root.cBordaCard
                    border.width: 1

                    readonly property var tarefas: root.goggins.tarefas || []
                    readonly property int feitas: tarefas.filter(t => t.status === "feito").length
                    readonly property var proxima: tarefas.find(t => t.status !== "feito") || null

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "STAY HARD"
                            color: root.cText
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2
                        }
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: placar.implicitWidth * 0.82
                            implicitHeight: placar.implicitHeight
                            Text {
                                id: placar
                                text: parent.parent.parent.feitas + "/" + parent.parent.parent.tarefas.length
                                color: root.cRed
                                font.pixelSize: 60
                                font.weight: Font.Black
                                transform: Scale { xScale: 0.82 }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: !root.goggins.online ? "Goggins offline"
                                  : parent.parent.tarefas.length === 0 ? "Hoje é folga"
                                  : "tarefas feitas hoje"
                            color: root.cText
                            font.pixelSize: 15
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: parent.parent.proxima !== null
                            text: parent.parent.proxima ? "Próxima: " + parent.parent.proxima.inicio + " · " + parent.parent.proxima.nome : ""
                            color: root.cSoft
                            font.pixelSize: 14
                        }
                    }
                }

                // fetch / sistema
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.raioCard
                    color: root.cCard
                    border.color: root.cBordaCard
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10

                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 34; height: 34; radius: 10
                                color: root.cRed
                                Text { anchors.centerIn: parent; text: "▸"; color: root.cOnAccent; font.pixelSize: 14 }
                            }
                            Text {
                                text: kuser.loginName + "@" + (sHost.value || "archlinux")
                                color: root.cText
                                font.family: "Noto Sans Mono"
                                font.pixelSize: 16
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            Image {
                                id: archLogo
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 110
                                Layout.alignment: Qt.AlignVCenter
                                source: "file:///usr/share/pixmaps/archlinux-logo.png"
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }
                            MultiEffect {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 110
                                Layout.alignment: Qt.AlignVCenter
                                source: archLogo
                                colorization: 1.0
                                colorizationColor: root.cRed
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 6
                                rowSpacing: 5
                                Repeater {
                                    model: [
                                        ["OS", (sOs.value || "Arch Linux").replace(" Linux", "")],
                                        ["KERNEL", sKernel.value || ""],
                                        ["DE", "Plasma " + (sPlasma.value || "")],
                                        ["UPTIME", sUptime.formattedValue || ""],
                                        ["CPU", sTemp.formattedValue || ""]
                                    ]
                                    delegate: Item {
                                        Layout.columnSpan: 2
                                        Layout.fillWidth: true
                                        implicitHeight: 20
                                        Text {
                                            id: k
                                            text: modelData[0]
                                            width: 62
                                            color: root.cRed2
                                            font.family: "Noto Sans Mono"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            anchors.left: k.right
                                            anchors.right: parent.right
                                            text: ": " + modelData[1]
                                            elide: Text.ElideRight
                                            color: root.cText
                                            font.family: "Noto Sans Mono"
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 14
                            Repeater {
                                model: root.paleta
                                Rectangle { width: 26; height: 26; radius: 13; color: modelData }
                            }
                        }
                    }
                }

                // mini player
                RoundClip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: root.raioCard

                    Image {
                        id: miniArt
                        anchors.fill: parent
                        source: root.capa
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 500
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: miniArt
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 48
                        saturation: -0.4
                    }
                    Rectangle { anchors.fill: parent; color: root.cMini }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.titulo
                            elide: Text.ElideRight
                            color: root.cText
                            font.family: "Noto Sans Mono"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.artista
                            elide: Text.ElideRight
                            color: root.cSoft
                            font.family: "Noto Sans Mono"
                            font.pixelSize: 13
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            spacing: 18
                            Kirigami.Icon {
                                implicitWidth: 22; implicitHeight: 22
                                source: "media-skip-backward"
                                color: root.cRed; isMask: true
                                opacity: root.usarExterno || root.temArquivo ? 1 : 0.4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.anterior() }
                            }
                            Rectangle {
                                implicitWidth: 76; implicitHeight: 42; radius: 21
                                color: root.cRed
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: root.tocando ? "media-playback-pause" : "media-playback-start"
                                    color: root.cOnAccent; isMask: true
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tocarPausar() }
                            }
                            Kirigami.Icon {
                                implicitWidth: 22; implicitHeight: 22
                                source: "media-skip-forward"
                                color: root.cRed; isMask: true
                                opacity: root.usarExterno || root.temArquivo ? 1 : 0.4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.proxima() }
                            }
                        }
                    }
                }
            }

            // ---------- coluna central ----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Item { Layout.preferredHeight: 6 }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: relogio.implicitWidth * 0.6
                    implicitHeight: relogio.implicitHeight * 0.86
                    Text {
                        id: relogio
                        y: -relogio.implicitHeight * 0.07
                        text: root.dois(root.brt.getHours()) + ":" + root.dois(root.brt.getMinutes())
                        color: root.cRed
                        font.pixelSize: 168
                        font.weight: Font.Black
                        font.letterSpacing: -4
                        transform: Scale { xScale: 0.6 }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.diasSemana[root.brt.getDay()] + " • " + root.brt.getDate() + " " + root.meses[root.brt.getMonth()]
                    color: root.cText
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "hora local"
                    color: root.cSoft
                    font.pixelSize: 12
                }

                // capa hexagonal
                Item {
                    id: hexArea
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 230
                    SequentialAnimation on scale {
                        running: root.tocando
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { from: 1.0; to: 1.035; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.035; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }

                    Item {
                        id: bigArt
                        anchors.fill: parent
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0; color: root.cRed2 }
                                GradientStop { position: 1; color: root.cRed }
                            }
                        }
                        Image {
                            anchors.fill: parent
                            source: root.capa
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 600
                        }
                    }
                    Item {
                        id: hexMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "black"
                                strokeColor: "black"
                                strokeWidth: 40
                                joinStyle: ShapePath.RoundJoin
                                startX: 85; startY: 20
                                PathLine { x: 215; y: 20 }
                                PathLine { x: 280; y: 115 }
                                PathLine { x: 215; y: 210 }
                                PathLine { x: 85; y: 210 }
                                PathLine { x: 20; y: 115 }
                                PathLine { x: 85; y: 20 }
                            }
                        }
                    }
                    // capa padrão: imagem sem fundo (contents/imagens/capa.png)
                    Image {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 22
                        width: 290
                        height: width
                        visible: !root.usarExterno
                        source: root.wallpaper
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        visible: root.usarExterno
                        source: bigArt
                        maskEnabled: true
                        maskSource: hexMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                                            }
                    MouseArea {
                        id: playHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tocarPausar()
                    }
                }

                // barra de progresso em bolinhas
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    implicitWidth: 330
                    implicitHeight: 46
                    radius: 23
                    color: root.cCard
                    border.color: root.cBordaCard
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 6
                        Kirigami.Icon {
                            implicitWidth: 18; implicitHeight: 18
                            source: "audio-volume-high"
                            color: root.cRed2; isMask: true
                        }
                        Item { implicitWidth: 4 }
                        Repeater {
                            model: 13
                            Rectangle {
                                readonly property real frac: root.duracao > 0 ? root.posicao / root.duracao : 0
                                implicitWidth: 13; implicitHeight: 13; radius: 6.5
                                color: (index + 0.5) / 13 <= frac ? root.cRed : root.cPontoOff
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Kirigami.Icon {
                            implicitWidth: 24; implicitHeight: 24
                            source: "media-skip-forward"
                            color: root.cRed; isMask: true
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.proxima() }
                        }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.usarExterno || root.temArquivo ? root.titulo + " — " + root.artista
                          : "Coloque o arquivo da música na pasta Música"
                    color: root.cSoft
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.maximumWidth: 360
                }
                Item { Layout.fillHeight: true }
            }

            // ---------- coluna direita ----------
            ColumnLayout {
                Layout.preferredWidth: 380
                Layout.maximumWidth: 380
                Layout.fillHeight: true
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: root.raioCard
                    color: root.cCard
                    border.color: root.cBordaCard
                    border.width: 1
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        StatBlob { anel: true; fillColor: root.cRed; baseColor: root.cCardSolid; textColor: root.cText; trackColor: root.cPontoOff; label: "CPU"; iconName: "cpu"; value: sCpu.value || 0 }
                        StatBlob { anel: true; fillColor: root.cRed; baseColor: root.cCardSolid; textColor: root.cText; trackColor: root.cPontoOff; label: "RAM"; iconName: "memory"; value: sRam.value || 0 }
                        StatBlob { anel: true; fillColor: root.cRed; baseColor: root.cCardSolid; textColor: root.cText; trackColor: root.cPontoOff; label: "DISCO"; iconName: "drive-harddisk"; value: sDisk.value || 0 }
                        StatBlob {
                            anel: true; fillColor: root.cRed; baseColor: root.cCardSolid; textColor: root.cText; trackColor: root.cPontoOff; 
                            label: "TEMP"; iconName: "temperature-normal"
                            value: sTemp.value || 0
                            valueText: Math.round(sTemp.value || 0) + "°"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.raioCard
                    color: root.cCard
                    border.color: root.cBordaCard
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 8

                        // abas: discord | tarefas do dia
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            Repeater {
                                model: [["discord", "notifications", "discord"], ["tarefas", "view-task", "tarefas do dia"]]
                                delegate: Item {
                                    id: abaItem
                                    required property var modelData
                                    readonly property bool ativa: root.aba === modelData[0]
                                    implicitWidth: abaCol.implicitWidth
                                    implicitHeight: abaCol.implicitHeight
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.aba = abaItem.modelData[0]
                                    }
                                    Column {
                                        id: abaCol
                                        readonly property var modelData: abaItem.modelData
                                        readonly property bool ativa: abaItem.ativa
                                        spacing: 5
                                        RowLayout {
                                            spacing: 7
                                            Kirigami.Icon {
                                                implicitWidth: 17; implicitHeight: 17
                                                source: modelData[1]
                                                color: ativa ? root.cRed : root.cSoft; isMask: true
                                            }
                                            Text {
                                                text: modelData[2]
                                                color: ativa ? root.cText : root.cSoft
                                                font.family: "Noto Sans Mono"
                                                font.pixelSize: 15
                                                font.weight: ativa ? Font.DemiBold : Font.Normal
                                            }
                                        }
                                        Rectangle {
                                            width: parent.width; height: 2; radius: 1
                                            color: ativa ? root.cRed : "transparent"
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            // como o Goggins está agora
                            Row {
                                visible: root.aba === "tarefas"
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8; height: 8; radius: 4
                                    color: !root.goggins.online ? root.cSoft : root.goggins.cobrando ? root.cRed2 : "#3ddc6c"
                                    SequentialAnimation on opacity {
                                        running: root.goggins.online && root.goggins.cobrando
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.2; duration: 450 }
                                        NumberAnimation { to: 1; duration: 450 }
                                    }
                                }
                                Text {
                                    text: !root.goggins.online ? "offline" : root.goggins.cobrando ? "cobrando" : "calado"
                                    color: root.cSoft
                                    font.pixelSize: 12
                                }
                                // abre o "Monte sua rotina"
                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.goggins.online
                                    implicitWidth: 16; implicitHeight: 16
                                    source: "configure"
                                    color: engrenagem.containsMouse ? root.cRed2 : root.cSoft
                                    isMask: true
                                    MouseArea {
                                        id: engrenagem
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.gogginsApi("POST", "/configurar")
                                    }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.cLinha }

                        // ---------- aba tarefas ----------
                        Item {
                            visible: root.aba === "tarefas"
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: listaTarefas
                                anchors.fill: parent
                                clip: true
                                spacing: 8
                                model: root.goggins.tarefas || []
                                delegate: Rectangle {
                                    id: linhaTarefa
                                    required property var modelData
                                    readonly property bool feito: modelData.status === "feito"
                                    width: ListView.view.width
                                    height: 58
                                    radius: 12
                                    color: modelData.atual ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.12) : "transparent"
                                    border.color: modelData.atual ? root.cRed : root.cLinhaFraca
                                    border.width: 1
                                    opacity: feito ? 0.6 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12
                                        Column {
                                            Text { text: linhaTarefa.modelData.inicio; color: root.cRed2; font.family: "Noto Sans Mono"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            Text { text: linhaTarefa.modelData.fim; color: root.cSoft; font.family: "Noto Sans Mono"; font.pixelSize: 12 }
                                        }
                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                width: parent.width
                                                text: linhaTarefa.modelData.nome
                                                elide: Text.ElideRight
                                                color: root.cText
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                font.strikeout: linhaTarefa.feito
                                            }
                                            Text {
                                                text: linhaTarefa.modelData.verificacao === "prova"
                                                      ? linhaTarefa.modelData.minutos + "/" + linhaTarefa.modelData.min_minutos + " min" + (linhaTarefa.modelData.cobra ? "" : " · sem cobrança")
                                                      : "confirmação manual"
                                                color: root.cSoft
                                                font.pixelSize: 12
                                            }
                                        }
                                        Rectangle {
                                            implicitWidth: rotuloStatus.implicitWidth + 16
                                            implicitHeight: 22
                                            radius: 11
                                            color: linhaTarefa.feito ? "#1f8e3d" : linhaTarefa.modelData.status === "recusado" ? root.cRed : "transparent"
                                            border.color: linhaTarefa.feito ? "transparent" : linhaTarefa.modelData.status === "fazendo" ? root.cRed2 : root.cLinha
                                            border.width: 1
                                            Text {
                                                id: rotuloStatus
                                                anchors.centerIn: parent
                                                text: ({ pendente: "pendente", fazendo: "fazendo", feito: "✓ feito", recusado: "recusado" })[linhaTarefa.modelData.status] || ""
                                                color: linhaTarefa.feito || linhaTarefa.modelData.status === "recusado" ? "#ffffff" : root.cText
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !linhaTarefa.feito
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.perguntando = linhaTarefa.modelData
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width
                                spacing: 14
                                visible: !root.goggins.online || (root.goggins.tarefas || []).length === 0
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    text: !root.goggins.online ? "Goggins offline.\nsystemctl --user start goggins"
                                          : "Nada pra hoje.\nMonte a sua rotina e escolha o que ele vai cobrar."
                                    color: root.cSoft
                                    font.pixelSize: 13
                                }
                                Rectangle {
                                    visible: root.goggins.online
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    implicitWidth: rotuloMontar.implicitWidth + 36
                                    implicitHeight: 38
                                    radius: 19
                                    color: root.cRed
                                    Text {
                                        id: rotuloMontar
                                        anchors.centerIn: parent
                                        text: "MONTAR MINHA ROTINA"
                                        color: root.cOnAccent
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.gogginsApi("POST", "/configurar") }
                                }
                            }

                            // caixa: fez ou não fez?
                            Rectangle {
                                anchors.fill: parent
                                visible: root.perguntando !== null
                                color: Qt.rgba(root.cCardSolid.r, root.cCardSolid.g, root.cCardSolid.b, 0.94)
                                radius: 14
                                border.color: root.cRed
                                border.width: 1.5
                                MouseArea { anchors.fill: parent }  // não deixa o clique vazar pra lista

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width - 40
                                    spacing: 16
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        text: root.perguntando ? "Você fez " + root.perguntando.nome + "?" : ""
                                        color: root.cText
                                        font.pixelSize: 19
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        visible: root.perguntando && root.perguntando.verificacao === "prova"
                                        text: "Se disser que sim, o painel fecha e o Goggins pede o print."
                                        color: root.cSoft
                                        font.pixelSize: 12
                                    }
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 12
                                        Repeater {
                                            model: [["FIZ", true], ["NÃO FIZ", false]]
                                            delegate: Rectangle {
                                                required property var modelData
                                                implicitWidth: 110; implicitHeight: 40; radius: 20
                                                color: modelData[1] ? root.cRed : "transparent"
                                                border.color: root.cRed
                                                border.width: 1.5
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData[0]
                                                    color: modelData[1] ? root.cOnAccent : root.cText
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.responder(modelData[1])
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "cancelar"
                                        color: root.cSoft
                                        font.pixelSize: 12
                                        font.underline: true
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.perguntando = null }
                                    }
                                }
                            }
                        }

                        // ---------- aba discord ----------
                        ListView {
                            id: lista
                            visible: root.aba === "discord"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 0
                            model: notificacoes
                            property int visiveis: 0
                            delegate: Item {
                                id: notif
                                required property var model
                                required property int index
                                readonly property bool mostrar: root.ehDiscord(model.desktopEntry, model.applicationName)
                                width: ListView.view.width
                                height: mostrar ? conteudo.implicitHeight + 16 : 0
                                visible: mostrar

                                RowLayout {
                                    id: conteudo
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    spacing: 10

                                    RoundClip {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        Layout.alignment: Qt.AlignTop
                                        radius: 21
                                        Rectangle { anchors.fill: parent; color: root.cCardSolid }
                                        KQuickControlsAddons.QImageItem {
                                            id: avatarImg
                                            anchors.fill: parent
                                            image: notif.model.image
                                            fillMode: KQuickControlsAddons.QImageItem.PreserveAspectCrop
                                            visible: !avatarImg.null
                                        }
                                        Kirigami.Icon {
                                            anchors.fill: parent
                                            anchors.margins: avatarImg.visible ? 0 : 6
                                            visible: !avatarImg.visible
                                            source: notif.model.iconName || notif.model.applicationIconName || "com.discordapp.Discord"
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.semHtml(notif.model.summary)
                                                elide: Text.ElideRight
                                                color: root.cText
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                text: root.tempoAtras(notif.model.created)
                                                color: root.cSoft
                                                font.pixelSize: 12
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.semHtml(notif.model.body)
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            color: root.cRed2
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: root.cLinhaFraca
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // vista = some da lista; só ficam as não vistas
                                        Qt.openUrlExternally("discord://")
                                        notificacoes.close(notificacoes.index(notif.index, 0))
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.aba === "discord" && lista.contentHeight < 4
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: "Nenhuma notificação nova do Discord.\nClique numa notificação para marcá-la como vista."
                            color: root.cSoft
                            font.pixelSize: 13
                            Layout.bottomMargin: 120
                        }
                    }
                }
            }
        }

    }
}
