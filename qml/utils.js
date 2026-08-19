// utils.js — File path, size, and MIME helpers for Loom.
// Pure JS (no Qt imports) so it can be imported as a JS module.
//
// Security note: the external command (stat) is spawned via Quickshell's
// Process with `command` set to a string array. The path is passed as a
// single argv element and is NEVER interpolated into a QML source string
// or a shell. This makes command injection impossible regardless of
// filename content.

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

// ── Size formatting ──────────────────────────────────────────────────────

function byteLabel(bytes) {
    if (bytes < 0 || isNaN(bytes)) return ""
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
    return (bytes / 1073741824).toFixed(1) + " GB"
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
