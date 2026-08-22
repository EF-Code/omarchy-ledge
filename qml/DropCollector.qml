import QtQuick

// Small compositor-facing boundary. It deliberately emits plain values and
// the local drop position; consumers decide whether a drop belongs in the
// inbox or on the canvas.
DropArea {
    id: collector

    signal dragEntered()
    signal dragExited()
    signal urlsDropped(var urls, real x, real y)
    signal textDropped(string text, real x, real y)

    keys: ["text/uri-list", "text/plain"]

    onEntered: function(drag) {
        console.log("[Loom] drag entered urls=" + (drag.hasUrls ? drag.urls.length : 0) + " text=" + (drag.hasText ? "yes" : "no"))
        collector.dragEntered()
        drag.acceptProposedAction()
    }
    onExited: collector.dragExited()
    onDropped: function(drop) {
        var point = drop.position || Qt.point(0, 0)
        if (drop.hasUrls) {
            var urls = []
            for (var i = 0; i < drop.urls.length; i++) urls.push(drop.urls[i].toString())
            collector.urlsDropped(urls, point.x, point.y)
        } else if (drop.hasText) {
            collector.textDropped(drop.text, point.x, point.y)
        }
        drop.acceptProposedAction()
    }
}
