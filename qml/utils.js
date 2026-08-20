// Pure data helpers for Loom. External processes are owned by Loom.qml so
// every command is passed as an argv array and no dropped value reaches a shell.

.pragma library

function stripQueryAndFragment(value) {
    return String(value || "").split("#")[0].split("?")[0]
}

function isWebUrl(value) {
    return /^https?:\/\/[^\s]+$/i.test(String(value || "").trim())
}

function isFileUrl(value) {
    const text = String(value || "")
    return text.startsWith("/") || text.startsWith("file:///") || text.startsWith("file://localhost/")
}

function fileUrlToPath(value) {
    const text = String(value || "")
    let raw = ""
    if (text.startsWith("file://localhost/")) raw = text.slice(16)
    else if (text.startsWith("file:///")) raw = text.slice(7)
    else if (text.startsWith("/")) raw = text
    else return ""

    try {
        return decodeURIComponent(raw)
    } catch (e) {
        return raw
    }
}

function pathToFileUrl(path) {
    if (!path) return ""
    return "file://" + String(path).split("/").map(function(part, index) {
        return index === 0 ? "" : encodeURIComponent(part)
    }).join("/")
}

function basename(value) {
    const clean = stripQueryAndFragment(value)
    const path = fileUrlToPath(clean) || clean.replace(/\/$/, "")
    const tail = path.split("/").pop()
    if (!tail) return "untitled"
    try { return decodeURIComponent(tail) } catch (e) { return tail }
}

function extension(value) {
    const name = basename(value)
    const dot = name.lastIndexOf(".")
    return dot > 0 ? name.slice(dot + 1).toLowerCase() : ""
}

function isImageUrl(value) {
    return /^(png|jpe?g|webp|svg|gif|bmp|avif)$/i.test(extension(value))
}

function isTextLikeUrl(value) {
    return /^(txt|md|markdown|rst|log|csv|tsv|json|jsonc|ya?ml|toml|xml|html?|css|scss|less|js|mjs|cjs|jsx|ts|tsx|py|rb|go|rs|c|h|cc|cpp|cxx|hpp|java|kt|kts|swift|php|sh|bash|zsh|fish|sql|qml)$/i.test(extension(value))
}

function mimeFor(value) {
    const ext = extension(value)
    const types = {
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
        "webp": "image/webp", "svg": "image/svg+xml", "gif": "image/gif",
        "bmp": "image/bmp", "avif": "image/avif", "txt": "text/plain",
        "md": "text/markdown", "json": "application/json", "csv": "text/csv",
        "js": "text/javascript", "ts": "text/typescript", "py": "text/x-python",
        "pdf": "application/pdf", "zip": "application/zip"
    }
    return types[ext] || "application/octet-stream"
}

function domainFor(value) {
    const match = String(value || "").match(/^https?:\/\/([^\/:?#]+)/i)
    return match ? match[1].toLowerCase() : ""
}

function byteLabel(bytes) {
    const value = Number(bytes)
    if (value < 0 || isNaN(value)) return ""
    if (value < 1024) return value + " B"
    if (value < 1048576) return (value / 1024).toFixed(1) + " KB"
    if (value < 1073741824) return (value / 1048576).toFixed(1) + " MB"
    if (value < 1099511627776) return (value / 1073741824).toFixed(1) + " GB"
    return (value / 1099511627776).toFixed(1) + " TB"
}

function utf8ByteLength(value) {
    const text = String(value || "")
    let bytes = 0
    for (let i = 0; i < text.length; i++) {
        const code = text.charCodeAt(i)
        if (code < 0x80) bytes += 1
        else if (code < 0x800) bytes += 2
        else if (code >= 0xd800 && code <= 0xdbff
                 && i + 1 < text.length
                 && text.charCodeAt(i + 1) >= 0xdc00
                 && text.charCodeAt(i + 1) <= 0xdfff) {
            bytes += 4
            i += 1
        } else bytes += 3
    }
    return bytes
}

function lineCount(value) {
    const text = String(value || "")
    if (!text) return 0
    return text.split(/\r\n|\r|\n/).length
}

function textSummary(value) {
    const lines = lineCount(value)
    const bytes = utf8ByteLength(value)
    return lines + (lines === 1 ? " line" : " lines") + " · " + byteLabel(bytes)
}

function displayText(value, limit) {
    const normalized = String(value || "").replace(/\s+/g, " ").trim()
    const maximum = limit || 44
    return normalized.length > maximum ? normalized.slice(0, maximum - 1) + "…" : normalized
}

function parseUrlList(json) {
    try {
        const result = JSON.parse(json || "[]")
        return Array.isArray(result) ? result.map(String) : []
    } catch (e) {
        return []
    }
}

function uriList(json) {
    return parseUrlList(json).join("\r\n")
}

function commonParentPath(urls) {
    if (!urls || urls.length === 0) return ""
    const first = fileUrlToPath(urls[0])
    if (!first) return ""
    const parent = first.slice(0, first.lastIndexOf("/")) || "/"
    for (let i = 1; i < urls.length; i++) {
        const path = fileUrlToPath(urls[i])
        if (!path || (path.slice(0, path.lastIndexOf("/")) || "/") !== parent) return ""
    }
    return parent
}

function siblingOutputPath(url, label, outputExtension, timestamp) {
    const path = fileUrlToPath(url)
    if (!path) return ""
    const slash = path.lastIndexOf("/")
    const parent = slash >= 0 ? path.slice(0, slash + 1) : ""
    const name = slash >= 0 ? path.slice(slash + 1) : path
    const dot = name.lastIndexOf(".")
    const stem = dot > 0 ? name.slice(0, dot) : name
    return parent + stem + "-" + label + "-" + String(timestamp) + "." + outputExtension
}

function archiveOutputPath(urls, timestamp) {
    const parent = commonParentPath(urls)
    if (!parent) return ""
    return parent.replace(/\/$/, "") + "/loom-" + String(timestamp) + ".zip"
}
