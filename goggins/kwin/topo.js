// Fica carregado no KWin: janelas do Goggins sempre por cima, fora da barra de tarefas e no lugar certo
function arrumar(w) {
    if (!w || w.caption.indexOf("GOGGINS-") !== 0) return;
    // a janela de configuração é uma janela normal (aparece na barra, não fica por cima)
    var config = w.caption === "GOGGINS-CONFIG";
    w.keepAbove = !config;
    w.skipTaskbar = !config;
    w.skipSwitcher = !config;
    w.skipPager = !config;
    w.onAllDesktops = !config;
    var tela = workspace.clientArea(KWin.MaximizeArea, w);
    var g = w.frameGeometry;
    var popup = w.caption === "GOGGINS-POPUP";
    // popup no canto de cima à direita; a prova no meio
    var x = popup ? tela.x + tela.width - g.width - 12 : tela.x + (tela.width - g.width) / 2;
    var y = popup ? tela.y + 12 : tela.y + (tela.height - g.height) / 2;
    w.frameGeometry = { x: x, y: y, width: g.width, height: g.height };
    if (w.caption === "GOGGINS-PROVA") workspace.activeWindow = w;
}
workspace.windowAdded.connect(function (w) {
    arrumar(w);
    w.captionChanged.connect(function () { arrumar(w); });
});
// também arruma as que já estão abertas: o daemon roda este script de novo logo depois de abrir um popup
var abertas = workspace.windowList();
for (var i = 0; i < abertas.length; i++) arrumar(abertas[i]);
