.pragma library

// Loom's pure model layer. QML uses this file directly and the Node tests
// load the exported functions after removing the QML-only pragma. Keep all
// filesystem, clipboard, process, and QML-object work outside this module.

var STATE_VERSION = 2
var MAX_ITEMS = 100
var MAX_TEXT_BYTES = 256 * 1024
var MAX_CARD_WIDTH = 640
var MIN_CARD_WIDTH = 180
var MAX_CARD_HEIGHT = 520
var MIN_CARD_HEIGHT = 120
var MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024
var MAX_EXPORT_BYTES = 80 * 1024 * 1024
var CARD_KINDS = ["file", "image", "text", "url", "note", "stack", "directory", "code"]

function asString(value) { return value === undefined || value === null ? "" : String(value) }
function finiteNumber(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : (fallback === undefined ? 0 : fallback)
}
function clamp(value, minimum, maximum) {
    var number = finiteNumber(value, minimum)
    return Math.max(minimum, Math.min(number, maximum))
}
function bounded(value, fallback, minimum, maximum) {
    return clamp(value === undefined || value === null ? fallback : value, minimum, maximum)
}
function safeInteger(value, fallback, minimum, maximum) {
    var number = Math.round(finiteNumber(value, fallback))
    if (minimum !== undefined) number = Math.max(minimum, number)
    if (maximum !== undefined) number = Math.min(maximum, number)
    return number
}

function stripQueryAndFragment(value) { return asString(value).split("#")[0].split("?")[0] }
function isWebUrl(value) { return /^https?:\/\/[^\s]+$/i.test(asString(value).trim()) }
function isFileUrl(value) {
    var text = asString(value)
    return text.startsWith("/") || text.startsWith("file:///") || text.startsWith("file://localhost/")
}
function fileUrlToPath(value) {
    var text = asString(value), raw = ""
    if (text.startsWith("file://localhost/")) raw = text.slice(16)
    else if (text.startsWith("file:///")) raw = text.slice(7)
    else if (text.startsWith("/")) raw = text
    else return ""
    try { return decodeURIComponent(raw) } catch (e) { return raw }
}
function pathToFileUrl(path) {
    var value = asString(path)
    if (!value.startsWith("/")) return ""
    return "file://" + value.split("/").map(function(part, index) {
        return index === 0 ? "" : encodeURIComponent(part)
    }).join("/")
}
function basename(value) {
    var clean = stripQueryAndFragment(value)
    var path = fileUrlToPath(clean) || clean.replace(/\/$/, "")
    var tail = path.split("/").pop()
    if (!tail) return "untitled"
    try { return decodeURIComponent(tail) } catch (e) { return tail }
}
function extension(value) {
    var name = basename(value), dot = name.lastIndexOf(".")
    return dot > 0 ? name.slice(dot + 1).toLowerCase() : ""
}
function isImageUrl(value) { return /^(png|jpe?g|webp|svg|gif|bmp|avif|ico|tiff)$/i.test(extension(value)) }
function isTextLikeUrl(value) {
    return /^(txt|md|markdown|rst|log|csv|tsv|json|jsonc|ya?ml|toml|xml|html?|css|scss|less|js|mjs|cjs|jsx|ts|tsx|py|rb|go|rs|c|h|cc|cpp|cxx|hpp|java|kt|kts|swift|php|sh|bash|zsh|fish|sql|qml)$/i.test(extension(value))
}
function mimeFor(value) {
    var types = {
        png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp",
        svg: "image/svg+xml", gif: "image/gif", bmp: "image/bmp", avif: "image/avif",
        ico: "image/x-icon", tiff: "image/tiff", txt: "text/plain", md: "text/markdown",
        json: "application/json", csv: "text/csv", js: "text/javascript", ts: "text/typescript",
        py: "text/x-python", qml: "text/x-qml", pdf: "application/pdf", zip: "application/zip"
    }
    return types[extension(value)] || "application/octet-stream"
}
function domainFor(value) {
    var match = asString(value).match(/^https?:\/\/([^\/:?#]+)/i)
    return match ? match[1].toLowerCase() : ""
}
function byteLabel(bytes) {
    var value = Number(bytes)
    if (value < 0 || isNaN(value)) return ""
    if (value < 1024) return value + " B"
    if (value < 1048576) return (value / 1024).toFixed(1) + " KB"
    if (value < 1073741824) return (value / 1048576).toFixed(1) + " MB"
    if (value < 1099511627776) return (value / 1073741824).toFixed(1) + " GB"
    return (value / 1099511627776).toFixed(1) + " TB"
}
function utf8ByteLength(value) {
    var text = asString(value), bytes = 0
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i)
        if (code < 0x80) bytes += 1
        else if (code < 0x800) bytes += 2
        else if (code >= 0xd800 && code <= 0xdbff && i + 1 < text.length
                 && text.charCodeAt(i + 1) >= 0xdc00 && text.charCodeAt(i + 1) <= 0xdfff) {
            bytes += 4; i += 1
        } else bytes += 3
    }
    return bytes
}
function truncateUtf8(value, maximum) {
    var text = asString(value)
    if (utf8ByteLength(text) <= maximum) return text
    var result = ""
    for (var i = 0; i < text.length; i++) {
        var next = result + text[i]
        if (utf8ByteLength(next) > maximum - 3) break
        result = next
    }
    return result + "…"
}
function lineCount(value) { var text = asString(value); return text ? text.split(/\r\n|\r|\n/).length : 0 }
function textSummary(value) {
    var lines = lineCount(value), bytes = utf8ByteLength(value)
    return lines + (lines === 1 ? " line" : " lines") + " · " + byteLabel(bytes)
}
function displayText(value, limit) {
    var normalized = asString(value).replace(/\s+/g, " ").trim(), maximum = limit || 44
    return normalized.length > maximum ? normalized.slice(0, maximum - 1) + "…" : normalized
}
function parseUrlList(value) {
    if (Array.isArray(value)) return value.map(asString)
    try { var parsed = JSON.parse(value || "[]"); return Array.isArray(parsed) ? parsed.map(asString) : [] }
    catch (e) { return [] }
}
function uriList(value) {
    var urls = parseUrlList(value)
    return urls.join("\r\n") + (urls.length ? "\r\n" : "")
}
function commonParentPath(urls) {
    var values = parseUrlList(urls)
    if (!values.length) return ""
    var first = fileUrlToPath(values[0])
    if (!first) return ""
    var parent = first.slice(0, first.lastIndexOf("/")) || "/"
    for (var i = 1; i < values.length; i++) {
        var path = fileUrlToPath(values[i])
        if (!path || (path.slice(0, path.lastIndexOf("/")) || "/") !== parent) return ""
    }
    return parent
}
function siblingOutputPath(url, label, outputExtension, timestamp) {
    var path = fileUrlToPath(url)
    if (!path) return ""
    var slash = path.lastIndexOf("/"), parent = slash >= 0 ? path.slice(0, slash + 1) : ""
    var name = slash >= 0 ? path.slice(slash + 1) : path, dot = name.lastIndexOf(".")
    var stem = dot > 0 ? name.slice(0, dot) : name
    return parent + stem + "-" + label + "-" + String(timestamp) + "." + outputExtension
}
function archiveOutputPath(urls, timestamp) {
    var parent = commonParentPath(urls)
    return parent ? parent.replace(/\/$/, "") + "/loom-" + String(timestamp) + ".zip" : ""
}

function cardKind(value) {
    var kind = asString(value)
    return CARD_KINDS.indexOf(kind) >= 0 ? kind : "file"
}
function stableId(value, fallback) {
    var text = asString(value).trim()
    return text && text.length <= 120 && !/[\s\/\\]/.test(text) ? text : asString(fallback)
}
function safeGeometry(raw, index) {
    var slot = Math.max(0, Number(index) || 0), column = slot % 4, row = Math.floor(slot / 4)
    return {
        x: 24 + column * 28, y: 24 + row * 28,
        width: bounded(raw && raw.width, 280, MIN_CARD_WIDTH, MAX_CARD_WIDTH),
        height: bounded(raw && raw.height, 190, MIN_CARD_HEIGHT, MAX_CARD_HEIGHT), z: slot + 1
    }
}
function normalizeGeometry(raw, index) {
    var fallback = safeGeometry({}, index), geometry = raw || {}
    return {
        x: clamp(geometry.x, 0, 4000), y: clamp(geometry.y, 0, 3000),
        width: bounded(geometry.width, fallback.width, MIN_CARD_WIDTH, MAX_CARD_WIDTH),
        height: bounded(geometry.height, fallback.height, MIN_CARD_HEIGHT, MAX_CARD_HEIGHT),
        z: safeInteger(geometry.z, fallback.z, 1, 100000)
    }
}
function cardIdentity(item) {
    if (!item) return ""
    if (item.kind === "note" || item.kind === "text") return item.kind + ":" + asString(item.text)
    if (item.kind === "stack") return "stack:" + parseUrlList(item.urlsJson || item.urls).join("\n")
    return asString(item.url)
}
function defaultCard(itemId, kind, now, index) {
    var geometry = safeGeometry({}, index)
    return {
        itemId: stableId(itemId, "card-" + String(now) + "-" + String(index)), kind: cardKind(kind),
        url: "", urlsJson: "[]", text: "", name: "Untitled context", subtitle: "", mime: "text/plain",
        domain: "", sizeBytes: -1, sizeLabel: "", dimensions: "", inInbox: true, onCanvas: false,
        x: geometry.x, y: geometry.y, width: geometry.width, height: geometry.height, z: geometry.z,
        createdAt: now, updatedAt: now, selected: false, editing: false
    }
}
function normalizeCard(raw, index, now) {
    if (!raw || typeof raw !== "object") return null
    var id = stableId(raw.itemId, "")
    if (!id) return null
    var kind = cardKind(raw.kind), createdAt = finiteNumber(raw.createdAt, now)
    var item = defaultCard(id, kind, createdAt, index)
    item.updatedAt = finiteNumber(raw.updatedAt, createdAt)
    item.url = asString(raw.url); item.urlsJson = JSON.stringify(parseUrlList(raw.urlsJson || raw.urls))
    item.text = truncateUtf8(raw.text, MAX_TEXT_BYTES)
    item.name = displayText(raw.name || (kind === "note" ? "Note" : basename(item.url)), 80) || "Untitled context"
    item.subtitle = asString(raw.subtitle); item.mime = asString(raw.mime) || mimeFor(item.url)
    item.domain = asString(raw.domain) || (isWebUrl(item.url) ? domainFor(item.url) : "")
    item.sizeBytes = finiteNumber(raw.sizeBytes, -1); item.sizeLabel = asString(raw.sizeLabel) || byteLabel(item.sizeBytes)
    item.dimensions = asString(raw.dimensions); item.inInbox = raw.inInbox !== false && raw.onCanvas !== true
    item.onCanvas = raw.onCanvas === true || !item.inInbox
    var geometry = normalizeGeometry(raw, index)
    item.x = geometry.x; item.y = geometry.y; item.width = geometry.width; item.height = geometry.height; item.z = geometry.z
    return item
}
function newFileCard(url, now, index) {
    var value = asString(url).trim(); if (value.startsWith("/")) value = pathToFileUrl(value)
    if (!isFileUrl(value) && !isWebUrl(value)) return null
    var kind = isWebUrl(value) ? "url" : (isImageUrl(value) ? "image" : (isTextLikeUrl(value) ? "code" : "file"))
    var item = defaultCard("card-" + String(now) + "-" + String(index), kind, now, index)
    item.url = value; item.name = isWebUrl(value) ? (domainFor(value) || value) : basename(value)
    item.subtitle = isWebUrl(value) ? value : (kind === "image" ? "Image asset" : (kind === "code" ? "Code / text file" : "Local reference"))
    item.mime = isWebUrl(value) ? "text/uri-list" : mimeFor(value); item.domain = isWebUrl(value) ? domainFor(value) : ""
    return item
}
function newTextCard(text, now, index) {
    var value = truncateUtf8(text, MAX_TEXT_BYTES); if (!value.trim()) return null
    if (isWebUrl(value.trim())) return newFileCard(value.trim(), now, index)
    var item = defaultCard("card-" + String(now) + "-" + String(index), "text", now, index)
    item.text = value; item.name = displayText(value, 56) || "Text snippet"; item.subtitle = textSummary(value)
    item.sizeBytes = utf8ByteLength(value); item.sizeLabel = byteLabel(item.sizeBytes); return item
}
function newNoteCard(title, body, now, index) {
    var item = defaultCard("note-" + String(now) + "-" + String(index), "note", now, index)
    item.name = displayText(title, 80) || "Note"; item.text = truncateUtf8(body, MAX_TEXT_BYTES)
    item.subtitle = lineCount(item.text) + (lineCount(item.text) === 1 ? " line" : " lines")
    item.mime = "text/plain"; item.inInbox = false; item.onCanvas = true; return item
}
function newStackCard(urls, now, index) {
    var values = parseUrlList(urls).map(function(value) {
        var entry = asString(value).trim(); return entry.startsWith("/") ? pathToFileUrl(entry) : entry
    }).filter(function(value) { return isFileUrl(value) || isWebUrl(value) })
    if (!values.length) return null
    var item = defaultCard("stack-" + String(now) + "-" + String(index), "stack", now, index)
    item.urlsJson = JSON.stringify(values); item.url = values[0]; item.name = values.length + " assets"
    item.subtitle = "Stacked context references"; item.mime = "text/uri-list"; return item
}

function normalizeStateObject(parsed) {
    if (!parsed || parsed.version !== STATE_VERSION || !Array.isArray(parsed.items)) return null
    var items = [], seen = {}
    for (var i = 0; i < parsed.items.length && items.length < MAX_ITEMS; i++) {
        var item = normalizeCard(parsed.items[i], items.length, Date.now())
        if (!item || seen[item.itemId]) continue
        seen[item.itemId] = true; items.push(item)
    }
    var board = parsed.board && typeof parsed.board === "object" ? parsed.board : {}
    return { version: STATE_VERSION, board: {
        title: displayText(board.title || "Untitled context", 80) || "Untitled context",
        viewportX: clamp(board.viewportX, 0, 4000), viewportY: clamp(board.viewportY, 0, 3000), zoom: clamp(board.zoom, 0.8, 1.2)
    }, items: items }
}
function parseState(raw) {
    if (!asString(raw).trim()) return null
    try { return normalizeStateObject(JSON.parse(raw)) } catch (e) { return null }
}
function hasVersion2State(raw) {
    if (!asString(raw).trim()) return false
    try { return !!(JSON.parse(raw) && JSON.parse(raw).version === STATE_VERSION) } catch (e) { return false }
}
function serializeState(board, items) {
    var normalized = normalizeStateObject({ version: STATE_VERSION, board: board || {}, items: items || [] })
    return JSON.stringify(normalized || { version: STATE_VERSION, board: {}, items: [] }, null, 2) + "\n"
}
function itemOrder(items, selectedIds) {
    var selected = {}, ids = selectedIds || [], source = items || []
    for (var i = 0; i < ids.length; i++) selected[asString(ids[i])] = true
    var selectedItems = source.filter(function(item) { return selected[item.itemId] && item.onCanvas })
    var result = selectedItems.length ? selectedItems : source.filter(function(item) { return item.onCanvas })
    return result.slice().sort(function(a, b) {
        var az = finiteNumber(a.z, 0), bz = finiteNumber(b.z, 0)
        return az !== bz ? az - bz : asString(a.itemId).localeCompare(asString(b.itemId))
    })
}
function promptForItems(boardTitle, items, selectedIds) {
    var selected = itemOrder(items, selectedIds)
    var lines = ["# Context from Loom", "", "Board: " + (asString(boardTitle) || "Untitled context"), "", "## Instructions", "Use the context below. Inspect referenced local files directly when available. Do not assume omitted file contents.", ""]
    var notes = selected.filter(function(item) { return item.kind === "note" })
    var files = selected.filter(function(item) { return ["file", "image", "code", "directory"].indexOf(item.kind) >= 0 })
    var links = selected.filter(function(item) { return item.kind === "url" })
    var texts = selected.filter(function(item) { return item.kind === "text" })
    var stacks = selected.filter(function(item) { return item.kind === "stack" })
    lines.push("## Notes"); if (!notes.length) lines.push("- None")
    notes.forEach(function(item) { lines.push("- " + item.name + ": " + item.text) })
    lines.push("", "## Files"); if (!files.length) lines.push("- None")
    files.forEach(function(item) { lines.push("- " + item.name + " — " + fileUrlToPath(item.url) + " — " + item.mime + " — " + (item.sizeLabel || "size unavailable")) })
    lines.push("", "## Links"); if (!links.length) lines.push("- None")
    links.forEach(function(item) { lines.push("- " + (item.name || item.domain || item.url) + ": " + item.url) })
    if (stacks.length) {
        lines.push("", "## Stacks")
        stacks.forEach(function(item) { lines.push("- " + item.name); parseUrlList(item.urlsJson).forEach(function(url) { lines.push("  - " + (isFileUrl(url) ? fileUrlToPath(url) : url)) }) })
    }
    lines.push("", "## Text snippets"); if (!texts.length) lines.push("- None")
    texts.forEach(function(item) { lines.push("### " + item.name, item.text, "") })
    return lines.join("\n").replace(/\n{3,}/g, "\n\n").replace(/\s+$/, "") + "\n"
}
function contextJson(boardTitle, items, selectedIds) {
    return { schemaVersion: 1, source: "ef-code.loom", board: { title: asString(boardTitle) || "Untitled context" },
        items: itemOrder(items, selectedIds).map(function(item) {
            return { itemId: item.itemId, kind: item.kind, name: item.name, text: item.text, url: item.url,
                urls: parseUrlList(item.urlsJson), mime: item.mime, domain: item.domain, sizeBytes: item.sizeBytes,
                sizeLabel: item.sizeLabel, onCanvas: item.onCanvas }
        }) }
}
function sanitizeFilename(value, fallback) {
    var name = asString(value).normalize("NFKC").replace(/[\\/\0<>:"|?*\x00-\x1f]/g, "_").replace(/\.\.+/g, ".").trim()
    name = name.replace(/^\.+/, "").replace(/\s+/g, " ")
    if (!name) name = "_"
    return (name || fallback || "attachment").slice(0, 160)
}
function uniqueFilename(name, used) {
    var base = sanitizeFilename(name, "attachment"), key = base.toLowerCase()
    if (!used[key]) { used[key] = true; return base }
    var dot = base.lastIndexOf("."), stem = dot > 0 ? base.slice(0, dot) : base, ext = dot > 0 ? base.slice(dot) : "", i = 2
    while (used[(stem + "-" + i + ext).toLowerCase()]) i++
    var result = stem + "-" + i + ext; used[result.toLowerCase()] = true; return result
}
function exportPlan(boardTitle, items, selectedIds) {
    var ordered = itemOrder(items, selectedIds), used = {}, total = 0, attachments = [], omitted = []
    ordered.forEach(function(item) {
        var urls = item.kind === "stack" ? parseUrlList(item.urlsJson) : [item.url]
        urls.forEach(function(url) {
            if (!isFileUrl(url)) return
            var path = fileUrlToPath(url), size = finiteNumber(item.sizeBytes, -1), isDirectory = item.kind === "directory"
            if (isDirectory || !path) { omitted.push({ itemId: item.itemId, path: path, reason: isDirectory ? "directory reference" : "unavailable path" }); return }
            if (size < 0) { omitted.push({ itemId: item.itemId, path: path, reason: "size unavailable" }); return }
            if (size > MAX_ATTACHMENT_BYTES || total + size > MAX_EXPORT_BYTES) { omitted.push({ itemId: item.itemId, path: path, reason: size > MAX_ATTACHMENT_BYTES ? "per-file cap" : "total cap" }); return }
            attachments.push({ itemId: item.itemId, source: path, filename: uniqueFilename(basename(path), used), sizeBytes: size }); total += size
        })
    })
    return { markdown: promptForItems(boardTitle, items, selectedIds), json: contextJson(boardTitle, items, selectedIds), attachments: attachments, omitted: omitted, totalBytes: total, selectedCount: ordered.length }
}
function boolSetting(value, fallback) {
    if (value === undefined || value === null) return fallback
    if (typeof value === "boolean") return value
    var text = asString(value).trim().toLowerCase()
    if (["true", "1", "yes", "on"].indexOf(text) >= 0) return true
    if (["false", "0", "no", "off"].indexOf(text) >= 0) return false
    return fallback
}
function intSetting(value, fallback, minimum, maximum) {
    if (value === undefined || value === null || typeof value === "boolean") return fallback
    var number = Number(value); if (!isFinite(number)) return fallback
    return clamp(Math.round(number), minimum === undefined ? number : minimum, maximum === undefined ? number : maximum)
}
function stateDirectory(stateDir) { return asString(stateDir).replace(/\/$/, "") + "/omarchy-loom" }
function stateFile(stateDir) { return stateDirectory(stateDir) + "/loom.json" }
function operationIsNew(operationId, recent) { var id = asString(operationId); return !!id && (recent || []).indexOf(id) < 0 }
function rememberOperation(operationId, recent, limit) {
    var next = (recent || []).slice(), id = asString(operationId)
    if (!id || next.indexOf(id) >= 0) return next
    next.push(id); while (next.length > (limit || 128)) next.shift(); return next
}

if (typeof module !== "undefined") {
    module.exports = {
        STATE_VERSION: STATE_VERSION, MAX_ITEMS: MAX_ITEMS, MAX_TEXT_BYTES: MAX_TEXT_BYTES,
        MAX_ATTACHMENT_BYTES: MAX_ATTACHMENT_BYTES, MAX_EXPORT_BYTES: MAX_EXPORT_BYTES,
        MIN_CARD_WIDTH: MIN_CARD_WIDTH, MAX_CARD_WIDTH: MAX_CARD_WIDTH, MIN_CARD_HEIGHT: MIN_CARD_HEIGHT, MAX_CARD_HEIGHT: MAX_CARD_HEIGHT,
        clamp: clamp, bounded: bounded, finiteNumber: finiteNumber, safeInteger: safeInteger, isWebUrl: isWebUrl, isFileUrl: isFileUrl,
        fileUrlToPath: fileUrlToPath, pathToFileUrl: pathToFileUrl, basename: basename, extension: extension,
        isImageUrl: isImageUrl, isTextLikeUrl: isTextLikeUrl, mimeFor: mimeFor, domainFor: domainFor,
        byteLabel: byteLabel, utf8ByteLength: utf8ByteLength, lineCount: lineCount, textSummary: textSummary,
        displayText: displayText, truncateUtf8: truncateUtf8, parseUrlList: parseUrlList, uriList: uriList,
        commonParentPath: commonParentPath, siblingOutputPath: siblingOutputPath, archiveOutputPath: archiveOutputPath,
        safeGeometry: safeGeometry, normalizeGeometry: normalizeGeometry, cardIdentity: cardIdentity,
        defaultCard: defaultCard, normalizeCard: normalizeCard, newFileCard: newFileCard, newTextCard: newTextCard,
        newNoteCard: newNoteCard, newStackCard: newStackCard, parseState: parseState, hasVersion2State: hasVersion2State,
        serializeState: serializeState, itemOrder: itemOrder, promptForItems: promptForItems,
        contextJson: contextJson, sanitizeFilename: sanitizeFilename, uniqueFilename: uniqueFilename,
        exportPlan: exportPlan, boolSetting: boolSetting, intSetting: intSetting, stateDirectory: stateDirectory,
        stateFile: stateFile, operationIsNew: operationIsNew, rememberOperation: rememberOperation
    }
}
