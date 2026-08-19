// utils.js — File path, size, and MIME helpers for Loom.
// Pure JS (no Qt imports) so it can be imported as a JS module.

.pragma library

// ── URL / path helpers ───────────────────────────────────────────────────

function basename(url) {
    const path = url.startsWith("file://") ? url.slice(7) : url
    return decodeURIComponent(path.split("/").pop()) || "untitled"
}

function isImageUrl(url) {
    return /\.(png|jpe?g|webp|svg|gif|bmp|avif)$/i.test(url)
}

function isTextSnippet(kind) {
    return kind === "text"
}

// ── Size formatting ──────────────────────────────────────────────────────

function byteLabel(bytes) {
    if (bytes < 0) return ""
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
}

// ── Async file size fetch ────────────────────────────────────────────────
// Uses Quickshell's Process to stat a file path. The callback receives a
// human-readable size label (e.g. "2.3 KB") or "" on failure.

function fetchFileSize(url, callback) {
    const path = url.startsWith("file://") ? url.slice(7) : url
    if (!path) { callback(""); return }

    const proc = Qt.createQmlObject(
        "import Quickshell.Io; Process { command: [\"stat\", \"-c\", \"%s\", \"" + path.replace(/"/g, "\\\"") + "\"] }",
        null, "fetchFileSize"
    )
    proc.onFinished = function(exitCode, exitStatus) {
        const out = proc.stdout ? proc.stdout.text : ""
        const bytes = parseInt(out.trim(), 10)
        callback(isNaN(bytes) ? "" : byteLabel(bytes))
        proc.destroy()
    }
    proc.running = true
}

// ── Clipboard helpers ────────────────────────────────────────────────────

function toFileUri(path) {
    if (path.startsWith("file://")) return path
    return "file://" + path
}

function copyToClipboard(text) {
    // Quickshell exposes clipboard via Quickshell.Io; fallback to wl-copy.
    const proc = Qt.createQmlObject(
        "import Quickshell.Io; Process { stdinEnabled: true }",
        null, "copyToClipboard"
    )
    proc.command = ["wl-copy", text]
    proc.running = true
}

// ── Base64 data URI for images ───────────────────────────────────────────

function base64DataUri(url, callback) {
    const path = url.startsWith("file://") ? url.slice(7) : url
    if (!path) { callback(""); return }

    const proc = Qt.createQmlObject(
        "import Quickshell.Io; Process { command: [\"base64\", \"-w0\", \"" + path.replace(/"/g, "\\\"") + "\"] }",
        null, "base64DataUri"
    )
    proc.stdout = Qt.createQmlObject(
        "import Quickshell.Io; SplitParser {}",
        proc, "base64Parser"
    )
    let out = ""
    proc.stdout.onRead = function(line) { out += line }
    proc.onFinished = function(exitCode) {
        const ext = path.split(".").pop().toLowerCase()
        const mime = ext === "svg" ? "image/svg+xml" : "image/" + ext
        callback("data:" + mime + ";base64," + out.trim())
        proc.destroy()
    }
    proc.running = true
}
