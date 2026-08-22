import fs from "node:fs"
import path from "node:path"

const root = path.dirname(path.dirname(new URL(import.meta.url).pathname))
const manifestPath = path.join(root, "manifest.json")
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"))
if (manifest.schemaVersion !== 1) throw new Error("schemaVersion must be 1")
if (manifest.id !== "ef-code.loom") throw new Error("manifest id must be ef-code.loom")
if (!Array.isArray(manifest.kinds) || manifest.kinds.length !== 1 || manifest.kinds[0] !== "bar-widget") throw new Error("manifest must be a bar-widget")
if (manifest.keepLoaded !== undefined) throw new Error("keepLoaded is not valid for Loom")
if (manifest.entryPoints?.barWidget !== "qml/BarWidget.qml") throw new Error("barWidget entry point mismatch")
const metadata = manifest.barWidget
if (!metadata || metadata.defaultSection !== "right" || metadata.allowMultiple !== false) throw new Error("bar metadata mismatch")
const schemaKeys = new Set((metadata.schema || []).map((entry) => entry.key))
if (!schemaKeys.has("autoClose") || !schemaKeys.has("autoCloseSeconds")) throw new Error("settings schema incomplete")
for (const field of ["id", "name", "version", "description"]) if (!manifest[field]) throw new Error(`missing manifest ${field}`)
console.log("manifest validation: passed")
