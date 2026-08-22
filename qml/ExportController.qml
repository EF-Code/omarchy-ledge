import QtQuick
import Quickshell
import Quickshell.Io
import "utils.js" as Utils

// One serialized export at a time. FileView performs the atomic Markdown and
// JSON writes; attachment copies are then issued as argv-safe Process calls.
Item {
    id: controller

    visible: false
    width: 0
    height: 0

    property string stateDirectory: ""
    property bool busy: false
    property string outputPath: ""
    property string statusMessage: ""
    property var activePlan: null
    property int copyIndex: 0
    property string boardTitle: "Untitled context"
    property var sourceItems: []
    property var sourceSelection: []

    signal completed(bool success, string path, string report)

    function start(title, items, selectedIds) {
        if (busy) {
            statusMessage = "An export is already running"
            return "busy"
        }
        boardTitle = String(title || "Untitled context")
        sourceItems = items || []
        sourceSelection = selectedIds || []
        activePlan = Utils.exportPlan(boardTitle, sourceItems, sourceSelection)
        var stamp = Date.now()
        outputPath = stateDirectory.replace(/\/$/, "") + "/exports/loom-context-" + String(stamp)
        copyIndex = 0
        busy = true
        statusMessage = "Preparing context bundle…"
        mkdirProcess.command = ["mkdir", "-p", outputPath + "/assets"]
        // Keep the accepted state observable to IPC callers and give the UI a
        // frame to render its busy affordance before filesystem work starts.
        startDelay.restart()
        return "accepted"
    }

    function finish(success, report) {
        busy = false
        statusMessage = report
        completed(success, outputPath, report)
    }

    function writeDocuments() {
        var json = activePlan.json
        json.export = {
            bundleDirectory: outputPath,
            attachmentCount: activePlan.attachments.length,
            omitted: activePlan.omitted,
            totalAttachmentBytes: activePlan.totalBytes
        }
        markdownFile.path = outputPath + "/context.md"
        jsonFile.path = outputPath + "/context.json"
        readmeFile.path = outputPath + "/README.md"
        markdownFile.setText(activePlan.markdown)
        jsonFile.setText(JSON.stringify(json, null, 2) + "\n")
        readmeFile.setText("# Loom context bundle\n\nThis directory was created locally by Loom. `context.md` is the readable prompt, `context.json` is the structured manifest, and `assets/` contains only bounded local attachments. URLs are references; they were not fetched.\n\n")
        Qt.callLater(controller.copyNext)
    }

    function copyNext() {
        if (!busy || !activePlan) return
        if (copyIndex >= activePlan.attachments.length) {
            zipProbe.running = true
            return
        }
        var attachment = activePlan.attachments[copyIndex]
        copyProcess.command = ["cp", "--", attachment.source, outputPath + "/assets/" + attachment.filename]
        copyProcess.running = true
    }

    function finishDirectory() {
        var omittedText = activePlan.omitted.length ? " Omitted " + activePlan.omitted.length + " attachment(s) by policy or because they were unavailable." : ""
        finish(true, "Exported " + activePlan.selectedCount + " card(s) to " + outputPath + "." + omittedText)
    }

    FileView { id: markdownFile; atomicWrites: true; printErrors: false }
    FileView { id: jsonFile; atomicWrites: true; printErrors: false }
    FileView { id: readmeFile; atomicWrites: true; printErrors: false }

    Timer {
        id: startDelay
        interval: 80
        repeat: false
        onTriggered: if (controller.busy) mkdirProcess.running = true
    }

    Process {
        id: mkdirProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                finish(false, "Could not create the export directory")
                return
            }
            writeDocuments()
        }
    }

    Process {
        id: copyProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                finish(false, "Export stopped while copying " + activePlan.attachments[copyIndex].filename + "; the directory was kept")
                return
            }
            copyIndex += 1
            copyNext()
        }
    }

    Process {
        id: zipProbe
        running: false
        command: ["which", "zip"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                zipProcess.workingDirectory = outputPath.replace(/\/[^\/]+$/, "")
                zipProcess.command = ["zip", "-qr", outputPath + ".zip", outputPath.split("/").pop()]
                zipProcess.running = true
            } else {
                finishDirectory()
            }
        }
    }

    Process {
        id: zipProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) finishDirectory()
            else finish(true, "Exported directory to " + outputPath + "; ZIP creation was unavailable")
        }
    }
}
