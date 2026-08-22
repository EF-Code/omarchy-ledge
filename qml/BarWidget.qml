import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "utils.js" as Utils

// Loom is a bar-owned BarWidget: the bar chip is always present, while the
// exact-size popup only maps when the controller is open. One instance exists
// per monitor; mutations are replayed to every peer through bar.moduleWidgets.
Ui.BarWidget {
    id: root

    moduleName: "ef-code.loom"

    // BarWidget provides the per-monitor slot, settings, and module registry
    // contract. Loom owns its own canonical IPC target below, so there is no
    // second handler to enable here.
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    readonly property bool opened: controller.open
    property bool popoutSwitchClosing: false

    Ui.PanelController { id: controller }

    readonly property string version: "0.3.0"
    readonly property string stateRoot: Quickshell.stateDir
    readonly property string stateDirectory: Utils.stateDirectory(stateRoot)
    readonly property string statePath: Utils.stateFile(stateRoot)
    readonly property string legacyStatePath: stateRoot + "/loom-state.json"
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property bool barVertical: bar ? bar.vertical : false
    readonly property string glyphLoom: "\u{F1294}"
    readonly property string glyphDrop: "\u{F0120}"

    property string boardTitle: "Untitled context"
    property string statusMessage: ""
    property bool statusIsError: false
    property bool barDropActive: false
    property bool pointerHasVisited: false
    property bool restoreStarted: false
    property bool stateReady: false
    property bool directoriesReady: false
    property bool legacyReadPending: false
    property int operationSequence: 0
    property var recentOperationIds: []
    property var metadataQueue: []
    property var selectedIds: []
    property bool exportBusy: false
    property string lastExportPath: ""

    readonly property bool autoCloseWanted: Utils.boolSetting(setting("autoClose", true), true)
    readonly property int autoCloseSeconds: Utils.intSetting(setting("autoCloseSeconds", 3), 3, 1, 15)
    readonly property bool pointerOnLoom: popup.hovered || button.tooltipHovered
    readonly property bool autoCloseArmed: opened && autoCloseWanted && pointerHasVisited && !pointerOnLoom
        && !barDropActive && selectedIds.length === 0 && !workspace.editingActive && !exportBusy
    readonly property int inboxCount: inboxItems
    readonly property int canvasCount: canvasItems
    property int inboxItems: 0
    property int canvasItems: 0
    ListModel { id: itemModel }
    LoomTheme { id: theme }

    function showStatus(message, error) {
        statusMessage = String(message || "")
        statusIsError = error === true
        statusTimer.restart()
    }

    function newId(prefix) {
        operationSequence += 1
        return String(prefix || "card") + "-" + Date.now().toString(36) + "-" + operationSequence.toString(36)
    }

    function refreshCounts() {
        var inbox = 0, canvas = 0
        for (var i = 0; i < itemModel.count; i++) {
            if (itemModel.get(i).inInbox) inbox++
            if (itemModel.get(i).onCanvas) canvas++
        }
        inboxItems = inbox
        canvasItems = canvas
    }

    function indexForId(itemId) {
        for (var i = 0; i < itemModel.count; i++) if (itemModel.get(i).itemId === itemId) return i
        return -1
    }

    function modelItem(item) {
        return {
            itemId: String(item.itemId), kind: String(item.kind || "file"), url: String(item.url || ""),
            urlsJson: String(item.urlsJson || "[]"), text: String(item.text || ""), name: String(item.name || "Untitled context"),
            subtitle: String(item.subtitle || ""), mime: String(item.mime || "text/plain"), domain: String(item.domain || ""),
            sizeBytes: Number(item.sizeBytes === undefined ? -1 : item.sizeBytes), sizeLabel: String(item.sizeLabel || ""),
            dimensions: String(item.dimensions || ""), inInbox: item.inInbox === true, onCanvas: item.onCanvas === true,
            xPosition: Number(item.x || 0), yPosition: Number(item.y || 0), cardWidth: Number(item.width || 280),
            cardHeight: Number(item.height || 190), zIndex: Number(item.z || 1), createdAt: Number(item.createdAt || Date.now()),
            updatedAt: Number(item.updatedAt || Date.now()), selected: false
        }
    }

    function plainItems() {
        var result = []
        for (var i = 0; i < itemModel.count; i++) {
            var row = itemModel.get(i)
            result.push({ itemId: row.itemId, kind: row.kind, url: row.url, urlsJson: row.urlsJson, text: row.text,
                name: row.name, subtitle: row.subtitle, mime: row.mime, domain: row.domain, sizeBytes: row.sizeBytes,
                sizeLabel: row.sizeLabel, dimensions: row.dimensions, inInbox: row.inInbox, onCanvas: row.onCanvas,
                x: row.xPosition, y: row.yPosition, width: row.cardWidth, height: row.cardHeight, z: row.zIndex,
                createdAt: row.createdAt, updatedAt: row.updatedAt })
        }
        return result
    }

    function persistState() {
        if (!stateReady || !directoriesReady) return
        stateFile.setText(Utils.serializeState({ title: boardTitle, viewportX: 0, viewportY: 0, zoom: 1 }, plainItems()))
    }

    function schedulePersistence() { if (stateReady) persistenceTimer.restart() }

    function appendModelItem(item) {
        if (!item || itemModel.count >= Utils.MAX_ITEMS || indexForId(item.itemId) >= 0) return false
        itemModel.append(modelItem(item))
        if (Utils.isFileUrl(item.url)) queueMetadata(item.itemId, item.url)
        return true
    }

    function nextOperation(kind, payload) {
        operationSequence += 1
        return { operationId: Date.now().toString(36) + "-" + operationSequence.toString(36), kind: kind, timestamp: Date.now(), payload: payload || {} }
    }

    function applyOperation(operation) {
        if (!operation || !Utils.operationIsNew(operation.operationId, recentOperationIds)) return false
        recentOperationIds = Utils.rememberOperation(operation.operationId, recentOperationIds, 128)
        var payload = operation.payload || {}, index, i
        if (operation.kind === "add") {
            var added = payload.items || []
            for (i = 0; i < added.length; i++) appendModelItem(added[i])
        } else if (operation.kind === "remove") {
            var ids = payload.itemIds || []
            for (i = ids.length - 1; i >= 0; i--) { index = indexForId(ids[i]); if (index >= 0) itemModel.remove(index) }
        } else if (operation.kind === "clearInbox") {
            for (i = itemModel.count - 1; i >= 0; i--) if (itemModel.get(i).inInbox) itemModel.remove(i)
        } else if (operation.kind === "update") {
            index = indexForId(payload.itemId)
            if (index >= 0) {
                var row = itemModel.get(index)
                var fields = payload.fields || {}
                for (var key in fields) if (["itemId", "selected", "editing"].indexOf(key) < 0) itemModel.setProperty(index, key, fields[key])
                if (fields.updatedAt === undefined) itemModel.setProperty(index, "updatedAt", operation.timestamp)
            }
        } else if (operation.kind === "tidy") {
            var changes = payload.changes || []
            for (i = 0; i < changes.length; i++) {
                index = indexForId(changes[i].itemId)
                if (index < 0) continue
                itemModel.setProperty(index, "xPosition", changes[i].x)
                itemModel.setProperty(index, "yPosition", changes[i].y)
                itemModel.setProperty(index, "zIndex", changes[i].z)
            }
        } else if (operation.kind === "title") {
            boardTitle = Utils.displayText(payload.title || "Untitled context", 80) || "Untitled context"
        }
        refreshCounts()
        return true
    }

    function commitOperation(kind, payload) {
        var operation = nextOperation(kind, payload)
        var peers = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root]
        if (!peers || !peers.length) peers = [root]
        for (var i = 0; i < peers.length; i++) if (peers[i] && typeof peers[i].applyOperation === "function") peers[i].applyOperation(operation)
        schedulePersistence()
        return operation.operationId
    }

    function maxZ() {
        var value = 0
        for (var i = 0; i < itemModel.count; i++) value = Math.max(value, Number(itemModel.get(i).zIndex) || 0)
        return value
    }

    function canvasSlot(index) {
        var slot = Math.max(0, Number(index) || 0)
        return { x: 34 + (slot % 3) * 300, y: 32 + Math.floor(slot / 3) * 210 }
    }

    function identityAlreadyPresent(item) {
        var identity = Utils.cardIdentity(item)
        if (!identity) return false
        for (var i = 0; i < itemModel.count; i++) if (Utils.cardIdentity(plainItems()[i]) === identity) return true
        return false
    }

    function addCards(cards, target, x, y, quiet) {
        var accepted = [], baseX = Number(x), baseY = Number(y)
        for (var i = 0; i < cards.length && itemModel.count + accepted.length < Utils.MAX_ITEMS; i++) {
            var item = cards[i]
            if (!item || identityAlreadyPresent(item)) continue
            if (target === "canvas") {
                item.inInbox = false; item.onCanvas = true
                var slot = canvasSlot(canvasCount + accepted.length)
                item.x = isFinite(baseX) ? Math.max(12, baseX + accepted.length * 24) : slot.x
                item.y = isFinite(baseY) ? Math.max(12, baseY + accepted.length * 24) : slot.y
                item.z = maxZ() + accepted.length + 1
            }
            accepted.push(item)
        }
        if (accepted.length) {
            commitOperation("add", { items: accepted })
            if (!quiet) open()
            showStatus("Added " + accepted.length + " context card" + (accepted.length === 1 ? "" : "s"), false)
        } else if (cards.length) showStatus("That context is already in Loom", false)
        return accepted.length
    }

    function addValues(values, target, x, y, quiet) {
        var entries = [], list = values || []
        for (var i = 0; i < list.length; i++) {
            var value = String(list[i] || "").trim()
            if (Utils.isFileUrl(value) || Utils.isWebUrl(value) || value.startsWith("/")) entries.push(value)
        }
        if (!entries.length) { showStatus("No supported local file or web URL was received", true); return 0 }
        var now = Date.now(), cards = entries.length > 1 ? [Utils.newStackCard(entries, now, itemModel.count)] : [Utils.newFileCard(entries[0], now, itemModel.count)]
        return addCards(cards, target, x, y, quiet)
    }

    function addTextValue(text, target, x, y, quiet) {
        var item = Utils.newTextCard(text, Date.now(), itemModel.count)
        return item ? addCards([item], target, x, y, quiet) : 0
    }

    function addNote() {
        var item = Utils.newNoteCard("New note", "", Date.now(), itemModel.count)
        var slot = canvasSlot(canvasCount)
        item.x = slot.x; item.y = slot.y; item.z = maxZ() + 1
        commitOperation("add", { items: [item] })
        open(); Qt.callLater(function() { selectItem(item.itemId, false) })
        return "ok"
    }

    function addPayload(raw, quiet) {
        var payload
        try { payload = JSON.parse(raw || "{}") } catch (e) { showStatus("Invalid Loom payload", true); return "error" }
        if (payload && Array.isArray(payload.paths)) return addValues(payload.paths, payload.target || "inbox", payload.x, payload.y, quiet) > 0 ? "ok" : "ignored"
        if (payload && Array.isArray(payload.urls)) return addValues(payload.urls, payload.target || "inbox", payload.x, payload.y, quiet) > 0 ? "ok" : "ignored"
        if (payload && payload.text !== undefined) return addTextValue(payload.text, payload.target || "inbox", payload.x, payload.y, quiet) > 0 ? "ok" : "ignored"
        if (payload && payload.note) return addNote()
        showStatus("Nothing supported was found in the payload", true)
        return "ignored"
    }

    function clearSelection() {
        for (var i = 0; i < itemModel.count; i++) itemModel.setProperty(i, "selected", false)
        selectedIds = []
    }

    function selectItem(itemId, additive) {
        if (!itemId) { clearSelection(); return }
        var next = selectedIds.slice(), position = next.indexOf(itemId)
        if (additive) { if (position >= 0) next.splice(position, 1); else next.push(itemId) }
        else next = [itemId]
        for (var i = 0; i < itemModel.count; i++) itemModel.setProperty(i, "selected", next.indexOf(itemModel.get(i).itemId) >= 0)
        selectedIds = next
    }

    function placeItem(itemId) {
        var index = indexForId(itemId); if (index < 0) return
        var slot = canvasSlot(canvasCount)
        commitOperation("update", { itemId: itemId, fields: { inInbox: false, onCanvas: true, xPosition: slot.x, yPosition: slot.y, zIndex: maxZ() + 1 } })
    }

    function removeItems(ids) { if (ids && ids.length) { commitOperation("remove", { itemIds: ids }); clearSelection() } }
    function removeItem(itemId) { removeItems([itemId]) }
    function deleteSelected() { removeItems(selectedIds.length ? selectedIds : []) }
    function clearInbox() { commitOperation("clearInbox", {}); clearSelection(); return "ok" }

    function updateGeometry(itemId, x, y, width, height) {
        var index = indexForId(itemId); if (index < 0) return
        var row = itemModel.get(index), nextZ = maxZ() + 1
        commitOperation("update", { itemId: itemId, fields: { xPosition: Utils.clamp(x, 0, 4000), yPosition: Utils.clamp(y, 0, 3000),
            cardWidth: Utils.clamp(width, Utils.MIN_CARD_WIDTH, Utils.MAX_CARD_WIDTH), cardHeight: Utils.clamp(height, Utils.MIN_CARD_HEIGHT, Utils.MAX_CARD_HEIGHT), zIndex: nextZ } })
    }

    function editText(itemId, title, body) {
        var index = indexForId(itemId); if (index < 0) return
        var text = Utils.truncateUtf8(body, Utils.MAX_TEXT_BYTES)
        commitOperation("update", { itemId: itemId, fields: { name: Utils.displayText(title, 80) || "Note", text: text,
            subtitle: Utils.lineCount(text) + (Utils.lineCount(text) === 1 ? " line" : " lines"), updatedAt: Date.now() } })
    }

    function tidy() {
        var rows = plainItems().filter(function(item) { return item.onCanvas && (!selectedIds.length || selectedIds.indexOf(item.itemId) >= 0) })
        rows.sort(function(a, b) { return Number(a.z) - Number(b.z) || a.itemId.localeCompare(b.itemId) })
        var changes = []
        for (var i = 0; i < rows.length; i++) changes.push({ itemId: rows[i].itemId, x: 34 + (i % 4) * 300, y: 32 + Math.floor(i / 4) * 210, z: i + 1 })
        if (changes.length) commitOperation("tidy", { changes: changes })
        return "ok"
    }

    function list() {
        return JSON.stringify(plainItems().map(function(item) { return { itemId: item.itemId, kind: item.kind, name: item.name, inInbox: item.inInbox, onCanvas: item.onCanvas } }))
    }
    function count() { return String(itemModel.count) }
    function copyPrompt() {
        if (canvasCount === 0) { showStatus("Add or place context before copying a prompt", false); return "empty" }
        var prompt = Utils.promptForItems(boardTitle, plainItems(), selectedIds)
        Quickshell.clipboardText = prompt
        showStatus(prompt.indexOf(" — /") >= 0 ? "Agent prompt copied · contains local paths; keep it local" : "Agent prompt copied", false)
        return "ok"
    }
    function exportContext() {
        if (exportBusy) { showStatus("An export is already running", true); return "busy" }
        var result = exportController.start(boardTitle, plainItems(), selectedIds)
        if (result === "busy") { showStatus("An export is already running", true); return result }
        exportBusy = true; return result
    }

    function open() {
        var peers = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : []
        for (var i = 0; i < peers.length; i++) if (peers[i] && peers[i] !== root && peers[i].opened && peers[i].closeForPopoutSwitch) peers[i].closeForPopoutSwitch()
        controller.show(); pointerHasVisited = true
        return "ok"
    }
    function close() { controller.hide(); pointerHasVisited = false; clearSelection(); return "ok" }
    function closeForPopoutSwitch() { popoutSwitchClosing = true; controller.hide(); Qt.callLater(function() { popoutSwitchClosing = false }) }
    function toggle() { return opened ? close() : open() }

    onOpenedChanged: {
        if (opened) { pointerHasVisited = true; if (bar) bar.requestPopout(root) }
        else if (bar && bar.activePopout === root) bar.releasePopout(root)
    }
    onPointerOnLoomChanged: if (pointerOnLoom) pointerHasVisited = true
    onAutoCloseArmedChanged: autoCloseArmed ? autoCloseTimer.restart() : autoCloseTimer.stop()

    Timer { id: autoCloseTimer; interval: root.autoCloseSeconds * 1000; onTriggered: if (root.autoCloseArmed) root.close() }
    Timer { id: springTimer; interval: 700; onTriggered: if (root.barDropActive) root.open() }
    Timer { id: persistenceTimer; interval: 180; onTriggered: root.persistState() }
    Timer { id: statusTimer; interval: 4800; onTriggered: root.statusMessage = "" }

    Process {
        id: ensureDirs
        command: ["mkdir", "-p", root.stateDirectory]
        running: false
        onExited: function(exitCode) {
            root.directoriesReady = exitCode === 0
            if (root.directoriesReady) stateFile.reload()
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: root.restorePrimary(text())
        onLoadFailed: root.restorePrimary("")
    }
    FileView {
        id: legacyFile
        path: root.legacyStatePath
        watchChanges: false
        printErrors: false
        onLoaded: root.restoreLegacy(text())
        onLoadFailed: root.restoreLegacy("")
    }

    function restorePrimary(raw) {
        if (!directoriesReady || restoreStarted) return
        restoreStarted = true
        if (Utils.hasVersion2State(raw)) {
            var state = Utils.parseState(raw)
            if (state) {
                boardTitle = state.board.title
                for (var i = 0; i < state.items.length; i++) appendModelItem(state.items[i])
                refreshCounts(); stateReady = true; return
            }
        }
        if (String(raw || "").trim() !== "") {
            showStatus("Loom state was malformed; starting with an empty board", true)
            stateReady = true; refreshCounts(); return
        }
        restoreStarted = false; legacyReadPending = true; legacyFile.reload()
    }
    function restoreLegacy(raw) {
        if (!legacyReadPending || stateReady) return
        legacyReadPending = false
        var migrated = Utils.migrateLegacy(raw, Date.now())
        for (var i = 0; i < migrated.state.items.length; i++) appendModelItem(migrated.state.items[i])
        boardTitle = migrated.state.board.title
        refreshCounts(); stateReady = true
        if (migrated.state.items.length) { persistState(); showStatus("Imported " + migrated.state.items.length + " saved Loom card(s)", false) }
    }

    Process {
        id: metadataProcess
        property string itemId: ""
        property string task: ""
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            var index = root.indexForId(itemId)
            if (index >= 0 && exitCode === 0) {
                var output = stdout.text.trim()
                if (task === "stat") {
                    var fields = output.split("\t"), bytes = Number(fields[0])
                    if (fields.slice(1).join("\t").indexOf("directory") >= 0) itemModel.setProperty(index, "kind", "directory")
                    else if (isFinite(bytes)) { itemModel.setProperty(index, "sizeBytes", bytes); itemModel.setProperty(index, "sizeLabel", Utils.byteLabel(bytes)) }
                } else {
                    var lines = Number(output); if (isFinite(lines)) itemModel.setProperty(index, "subtitle", lines + (lines === 1 ? " line" : " lines"))
                }
            }
            itemId = ""; task = ""; root.runNextMetadata()
        }
    }
    function queueMetadata(itemId, url) {
        var path = Utils.fileUrlToPath(url); if (!path) return
        var queue = metadataQueue.slice(); queue.push({ itemId: itemId, path: path, task: "stat" });
        if (Utils.isTextLikeUrl(url)) queue.push({ itemId: itemId, path: path, task: "lines" })
        metadataQueue = queue; runNextMetadata()
    }
    function runNextMetadata() {
        if (metadataProcess.running || !metadataQueue.length) return
        var queue = metadataQueue.slice(), job = queue.shift(); metadataQueue = queue
        metadataProcess.itemId = job.itemId; metadataProcess.task = job.task
        metadataProcess.command = job.task === "stat" ? ["stat", "-Lc", "%s\t%F", "--", job.path] : ["awk", "END { print NR }", "--", job.path]
        metadataProcess.running = true
    }

    ExportController {
        id: exportController
        stateDirectory: root.stateDirectory
        onCompleted: function(success, path, report) { root.exportBusy = false; root.lastExportPath = success ? path : ""; root.showStatus(report, !success) }
    }

    Component.onCompleted: ensureDirs.running = true

    IpcHandler {
        target: "ef-code.loom"
        function open(payload: string): string { return root.open() }
        function close(): string { return root.close() }
        function show(): string { return root.open() }
        function hide(): string { return root.close() }
        function toggle(): string { return root.toggle() }
        function add(payload: string): string { return root.addPayload(payload, false) }
        function addQuiet(payload: string): string { return root.addPayload(payload, true) }
        function stageText(text: string): string { return root.addTextValue(text, "inbox", 0, 0, false) > 0 ? "ok" : "ignored" }
        function stageUrl(url: string): string { return root.addValues([url], "inbox", 0, 0, false) > 0 ? "ok" : "ignored" }
        function list(): string { return root.list() }
        function count(): string { return root.count() }
        function clearInbox(): string { return root.clearInbox() }
        function copyPrompt(): string { return root.copyPrompt() }
        function exportContext(): string { return root.exportContext() }
        function state(): string { return root.opened ? "open" : "closed" }
        function ping(): string { return "ok" }
    }

    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.barDropActive ? root.glyphDrop : (root.barVertical ? root.glyphLoom : root.glyphLoom + (itemModel.count ? " " + itemModel.count : ""))
        fontFamily: root.fontFamily
        hasVisualContent: true
        dimmed: itemModel.count === 0 && !root.opened
        tooltipText: itemModel.count ? "Loom: " + itemModel.count + " context card(s) — click to open" : "Loom: drop context or click to open"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) {
                if (root.canvasCount) root.copyPrompt()
                else { root.open(); root.showStatus("Loom is empty — drop context or add a note", false) }
            } else root.toggle()
        }
    }

    DropArea {
        id: barDrop
        anchors.fill: parent
        z: 20
        keys: ["text/uri-list", "text/plain"]
        onEntered: function(drag) {
            console.log("[Loom] bar drag entered urls=" + (drag.hasUrls ? drag.urls.length : 0) + " text=" + (drag.hasText ? "yes" : "no"))
            root.barDropActive = true; springTimer.restart(); drag.acceptProposedAction()
        }
        onExited: { root.barDropActive = false; springTimer.stop() }
        onDropped: function(drop) {
            root.barDropActive = false; springTimer.stop()
            if (drop.hasUrls) {
                var urls = []; for (var i = 0; i < drop.urls.length; i++) urls.push(drop.urls[i].toString())
                root.addValues(urls, "inbox", 0, 0, true)
            } else if (drop.hasText) root.addTextValue(drop.text, "inbox", 0, 0, true)
            drop.acceptProposedAction()
        }
    }

    LoomPopup {
        id: popup
        anchorItem: button
        bar: root.bar
        open: root.opened
        focusTarget: workspace.focusTarget
        theme: theme
        desiredWidth: 880
        desiredHeight: 600

        LoomWorkspace {
            id: workspace
            anchors.fill: parent
            theme: root.theme
            model: itemModel
            boardTitle: root.boardTitle
            inboxCount: root.inboxCount
            canvasCount: root.canvasCount
            selectionCount: root.selectedIds.length
            actionBusy: root.exportBusy
            statusMessage: root.statusMessage
            onCloseRequested: root.close()
            onCopyPromptRequested: root.copyPrompt()
            onExportRequested: root.exportContext()
            onTidyRequested: root.tidy()
            onCreateNoteRequested: root.addNote()
            onClearInboxRequested: root.clearInbox()
            onDeleteSelectedRequested: root.deleteSelected()
            onSelectRequested: (itemId, additive) => root.selectItem(itemId, additive)
            onPlaceRequested: (itemId) => root.placeItem(itemId)
            onRemoveRequested: (itemId) => root.removeItem(itemId)
            onGeometryRequested: (itemId, x, y, w, h) => root.updateGeometry(itemId, x, y, w, h)
            onTextEdited: (itemId, title, body) => root.editText(itemId, title, body)
            onEditCancelled: (itemId, discard) => { if (discard) root.removeItem(itemId) }
            onDropUrlsRequested: (urls, target, x, y) => root.addValues(urls, target, x, y, false)
            onDropTextRequested: (text, target, x, y) => root.addTextValue(text, target, x, y, false)
            onCopyExportPathRequested: Quickshell.clipboardText = root.lastExportPath
            onOpenExportFolderRequested: if (root.lastExportPath) Quickshell.execDetached(["xdg-open", root.lastExportPath])
            exportPath: root.lastExportPath
        }
    }
}
