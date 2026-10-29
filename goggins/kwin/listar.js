// Manda a lista de janelas normais de volta pro daemon: "1|classe|título" por linha (1 = ativa)
var linhas = [];
var ws = workspace.windowList();
for (var i = 0; i < ws.length; i++) {
    var w = ws[i];
    if (!w.normalWindow || w.caption.indexOf("GOGGINS-") === 0) continue;
    linhas.push((w === workspace.activeWindow ? "1" : "0") + "|" + w.resourceClass + "|" + w.caption.replace(/\n/g, " "));
}
callDBus("org.goggins.Rotina", "/org/goggins/Rotina", "org.goggins.Rotina", "janelas", linhas.join("\n"));
