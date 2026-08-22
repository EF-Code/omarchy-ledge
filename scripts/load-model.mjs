import fs from "node:fs"
import vm from "node:vm"
import { fileURLToPath } from "node:url"
import path from "node:path"

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const sourcePath = path.join(root, "qml", "utils.js")
const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\s*/m, "")
const module = { exports: {} }
const context = vm.createContext({ module, exports: module.exports, console, Date, JSON, Math, Number, String, Array, Object, isFinite, isNaN, decodeURIComponent, encodeURIComponent })
new vm.Script(source, { filename: sourcePath }).runInContext(context)
export default module.exports
