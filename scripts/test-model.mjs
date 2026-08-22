import assert from "node:assert/strict"
import Utils from "./load-model.mjs"

const now = 1700000000000
const file = Utils.newFileCard("/tmp/hello world.txt", now, 0)
const image = Utils.newFileCard("file:///tmp/photo.png", now, 1)
const url = Utils.newFileCard("https://example.com/docs?q=1", now, 2)
const text = Utils.newTextCard("café\n😀", now, 3)
const note = Utils.newNoteCard("Plan", "one\ntwo", now, 4)
const stack = Utils.newStackCard(["/tmp/a.txt", "file:///tmp/b.png"], now, 5)

assert.equal(Utils.fileUrlToPath(Utils.pathToFileUrl("/tmp/hello world.txt")), "/tmp/hello world.txt")
assert.equal(Utils.fileUrlToPath("file://remote/tmp/a"), "")
assert.equal(Utils.isWebUrl("https://example.com/a"), true)
assert.equal(Utils.isWebUrl("ftp://example.com/a"), false)
assert.equal(Utils.utf8ByteLength("café"), 5)
assert.equal(Utils.utf8ByteLength("😀"), 4)
assert.equal(Utils.lineCount("one\ntwo\nthree"), 3)
assert.equal(Utils.boolSetting("true", false), true)
assert.equal(Utils.boolSetting("off", true), false)
assert.equal(Utils.intSetting("abc", 3, 1, 15), 3)
assert.equal(Utils.intSetting("99", 3, 1, 15), 15)
assert.equal(Utils.clamp(Number.NaN, 2, 4), 2)
assert.equal(Utils.normalizeGeometry({ x: Number.NaN, y: -4, width: 9999, height: 2, z: Infinity }, 0).width, Utils.MAX_CARD_WIDTH)

const state = { version: 2, board: { title: "Demo" }, items: [file, image, url, text, note, stack] }
const serialized = Utils.serializeState(state.board, state.items.map((item) => ({ ...item, inInbox: false, onCanvas: true })))
const parsed = Utils.parseState(serialized)
assert.equal(parsed.version, 2)
assert.equal(parsed.items.length, 6)
assert.equal(parsed.items[0].name, "hello world.txt")

const ordered = [note, file, url, text].map((item, index) => ({ ...item, onCanvas: true, inInbox: false, z: index + 1 }))
assert.equal(Utils.itemOrder(ordered, [url.itemId])[0].itemId, url.itemId)
assert.match(Utils.promptForItems("Demo", ordered, []), /# Context from Loom/)
assert.match(Utils.promptForItems("Demo", ordered, []), /café/)
assert.match(Utils.promptForItems("Demo", [{ ...stack, onCanvas: true, inInbox: false }], []), /## Stacks/)
assert.equal(Utils.contextJson("Demo", ordered, []).schemaVersion, 1)

const used = {}
assert.equal(Utils.uniqueFilename("../a.txt", used), "_a.txt")
assert.equal(Utils.uniqueFilename("a.txt", used), "a.txt")
assert.equal(Utils.uniqueFilename("a.txt", used), "a-2.txt")
const plan = Utils.exportPlan("Demo", [file, note, url, stack], [])
assert.ok(plan.markdown.includes("# Context from Loom"))
assert.ok(Array.isArray(plan.attachments))
assert.equal(Utils.operationIsNew("op-1", []), true)
const recent = Utils.rememberOperation("op-1", [], 2)
assert.equal(Utils.operationIsNew("op-1", recent), false)
assert.equal(Utils.operationIsNew("op-2", recent), true)

console.log("model tests: 32 passed")
