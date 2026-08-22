import fs from "node:fs"
import path from "node:path"

const root = path.dirname(path.dirname(new URL(import.meta.url).pathname))
const required = [
  "qml/BarWidget.qml", "qml/LoomPopup.qml", "qml/LoomWorkspace.qml", "qml/CanvasCard.qml",
  "qml/InboxCard.qml", "qml/LoomIconButton.qml", "qml/LoomTheme.qml", "qml/ExportController.qml",
  "qml/DropCollector.qml", "qml/Preview.qml", "qml/utils.js"
]
for (const file of required) {
  if (!fs.existsSync(path.join(root, file))) throw new Error(`missing ${file}`)
}
const files = required.filter((file) => file.endsWith(".qml")).map((file) => fs.readFileSync(path.join(root, file), "utf8"))
const joined = files.join("\n")
const barWidget = fs.readFileSync(path.join(root, "qml/BarWidget.qml"), "utf8")
if (!barWidget.includes("Ui.BarWidget")) throw new Error("BarWidget.qml must use the current qs.Ui.BarWidget contract")
if (!barWidget.includes("Ui.WidgetButton")) throw new Error("BarWidget.qml must use the current qs.Ui.WidgetButton contract")
if (/ef-code\.loom|omarchy-loom|text\s*:\s*["']Loom["']/.test(joined)) throw new Error("runtime QML still contains the old Loom identity")
if (/sh\s+-c|bash\s+-c|eval\s+/.test(joined)) throw new Error("QML contains a shell interpolation boundary")
if (!joined.includes("WlrLayershell.namespace: \"omarchy-loom\"")) throw new Error("missing Loom layer namespace")
if (!joined.includes("interval: 700")) throw new Error("missing 700ms spring-open timer")
if (!joined.includes("Drag.startDrag")) throw new Error("missing explicit external drag start")
console.log(`qml structure: ${required.length} files checked`)
