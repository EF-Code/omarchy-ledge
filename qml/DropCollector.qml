import QtQuick

// Converts Qt drop events into plain URL/text signals. Keeping this separate
// makes the compositor-facing boundary small and easy to exercise in the VM.
DropArea {
    id: collector

    signal dragEntered()
    signal urlsDropped(var urls)
    signal textDropped(string text)

    keys: ["text/uri-list", "text/plain"]

    onEntered: (drag) => {
        collector.dragEntered()
        drag.acceptProposedAction()
    }

    onDropped: (drop) => {
        if (drop.hasUrls) {
            const urls = []
            for (let i = 0; i < drop.urls.length; i++) urls.push(drop.urls[i].toString())
            collector.urlsDropped(urls)
        } else if (drop.hasText) {
            collector.textDropped(drop.text)
        }
        drop.acceptProposedAction()
    }
}
