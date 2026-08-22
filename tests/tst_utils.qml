import QtQuick
import QtTest
import "../qml/utils.js" as Utils

TestCase {
    name: "LoomUtils"

    function test_local_file_urls() {
        compare(Utils.fileUrlToPath("file:///tmp/hello%20world.png"), "/tmp/hello world.png")
        compare(Utils.fileUrlToPath("file://localhost/tmp/example.txt"), "/tmp/example.txt")
        compare(Utils.fileUrlToPath("file://remote/tmp/example.txt"), "")
        verify(!Utils.isFileUrl("file://remote/tmp/example.txt"))
        compare(Utils.fileUrlToPath(Utils.pathToFileUrl("/tmp/café image.png")), "/tmp/café image.png")
    }

    function test_names_and_types() {
        compare(Utils.basename("file:///tmp/photo.png"), "photo.png")
        verify(Utils.isImageUrl("https://example.com/assets/photo.webp?size=2"))
        verify(Utils.isTextLikeUrl("file:///tmp/component.qml"))
        verify(!Utils.isTextLikeUrl("file:///tmp/archive.zip"))
        compare(Utils.mimeFor("photo.JPG"), "image/jpeg")
        compare(Utils.domainFor("https://Docs.Example.com/path"), "docs.example.com")
    }

    function test_text_metadata_is_utf8_aware() {
        compare(Utils.utf8ByteLength("hello"), 5)
        compare(Utils.utf8ByteLength("café"), 5)
        compare(Utils.utf8ByteLength("😀"), 4)
        compare(Utils.lineCount("one\ntwo\nthree"), 3)
        compare(Utils.textSummary("one\ntwo"), "2 lines · 7 B")
    }

    function test_settings_geometry_and_state() {
        compare(Utils.boolSetting("yes", false), true)
        compare(Utils.intSetting("999", 3, 1, 15), 15)
        compare(Utils.normalizeGeometry({ x: NaN, width: 9000 }, 2).width, Utils.MAX_CARD_WIDTH)
        var item = Utils.newTextCard("hello", 10, 0)
        item.inInbox = false
        item.onCanvas = true
        var state = Utils.parseState(Utils.serializeState({ title: "Board" }, [item]))
        compare(state.version, 2)
        compare(state.items.length, 1)
        compare(state.board.title, "Board")
    }

    function test_stacks_exports_and_operations() {
        var stack = Utils.newStackCard(["file:///tmp/a.png", "file:///tmp/b.txt"], 10, 0)
        stack.inInbox = false
        stack.onCanvas = true
        compare(Utils.parseUrlList(stack.urlsJson).length, 2)
        compare(Utils.uriList(stack.urlsJson), "file:///tmp/a.png\r\nfile:///tmp/b.txt\r\n")
        var plan = Utils.exportPlan("Board", [stack], [])
        verify(plan.markdown.indexOf("## Stacks") >= 0)
        compare(Utils.uniqueFilename("../a.txt", {}), "_a.txt")
        verify(Utils.operationIsNew("one", []))
        var recent = Utils.rememberOperation("one", [], 2)
        verify(!Utils.operationIsNew("one", recent))
    }
}
