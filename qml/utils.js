// utils.js — File path, size, and MIME helpers for Loom.
// Pure JS (no Qt imports) so it can be imported as a JS module.
//
// Security note: every external command is spawned via Quickshell's Process
// with `command` set to a string array. Paths are passed as a single argv
// element and are NEVER interpolated into a QML source string or a shell.
// This makes command injection impossible regardless of filename content.

.pragma library

// ── URL / path helpers ───────────────────────────────────────────────────

// Strip a leading file:// scheme and percent-decode the remainder.
function urlToPath(url) {
    if (!url) return ""
    // file:///home/user/foo -> /home/user/foo
    const raw = url.startsWith("file://") ? url.slice(7) : url
    try {
        return decodeURIComponent(raw)
    } catch (e) {
        // Malformed percent-encoding; fall back to the raw string.
        return raw
    }
}

function basename(url) {
    const path = urlToPath(url)
    const tail = path.split("/").pop()
    return tail || "untitled"
}

function isImageUrl(url) {
    return /\.(png|jpe?g|webp|svg|gif|bmp|avif)$/i.test(url)
}

function isTextSnippet(kind) {
    return kind === "text"
}

// ── Size formatting ──────────────────────────────────────────────────────

function byteLabel(bytes) {
    if (bytes < 0 || isNaN(bytes)) return ""
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
}

// ── Async file size fetch ────────────────────────────────────────────────
// Uses Quickshell's Process to stat a file path. The callback receives a
// human-readable size label (e.g. "2.3 KB") or "" on failure.
//
// The path is passed as a discrete argv element to `stat`, so a filename
// containing quotes, semicolons, backticks, or any other shell metacharacter
// cannot break out of its argument slot.

function fetchFileSize(url, callback) {
    const path = urlToPath(url)
    if (!path) { callback(""); return }

    const proc = Qt.createQmlObject(
        "import Quickshell.Io; Process { stdout: SplitParser {} }",
        null, "fetchFileSize"
    )
    proc.command = ["stat", "-c", "%s", path]

    let out = ""
    proc.stdout.onRead = function(data) { out += data }

    proc.onFinished = function(exitCode, exitStatus) {
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

// Copy text to the Wayland clipboard via wl-copy. The text is written to
// the process's stdin so that even multiline or binary-safe content is
// handled correctly — wl-copy reads from stdin, not argv.
function copyToClipboard(text) {
    const proc = Qt.createQmlObject(
        "import Quickshell.Io; Process { stdinEnabled: true }",
        null, "copyToClipboard"
    )
    proc.command = ["wl-copy"]
    proc.onStarted = function() {
        // write() sends to the process's stdin; wl-copy reads it from there.
        proc.write(text)
    }
    proc.onFinished = function(exitCode, exitStatus) {
        proc.destroy()
    }
    proc.running = true
}

// ── Base64 data URI for images ───────────────────────────────────────────

function base64DataUri(url, callback) {
    const path = urlToPath(url)
    if (!path) { callback(""); return }

    const proc = Qt.createQmlObject(
        "import Quickshell.Io; Process { stdout: SplitParser {} }",
        null, "base64DataUri"
    )
    proc.command = ["base64", "-w0", path]

    let out = ""
    proc.stdout.onRead = function(data) { out += data }

    proc.onFinished = function(exitCode, exitStatus) {
        if (exitCode !== 0) { callback(""); proc.destroy(); return }
        const ext = path.split(".").pop().toLowerCase()
        const mime = ext === "svg" ? "image/svg+xml" : "image/" + ext
        callback("data:" + mime + ";base64," + out.trim())
        proc.destroy()
    }
    proc.running = true
}
