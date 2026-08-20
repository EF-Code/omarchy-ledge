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
        compare(Utils.fileUrlToPath("https://example.com/file.png"), "")
        compare(Utils.fileUrlToPath(Utils.pathToFileUrl("/tmp/café image.png")), "/tmp/café image.png")
    }

    function test_names_and_types() {
        compare(Utils.basename("file:///tmp/photo.png"), "photo.png")
        compare(Utils.basename("https://example.com/assets/photo.webp?size=2#hero"), "photo.webp")
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

    function test_stacks_and_outputs() {
        const urls = ["file:///tmp/a.png", "file:///tmp/b.txt"]
        compare(Utils.parseUrlList(JSON.stringify(urls)).length, 2)
        compare(Utils.uriList(JSON.stringify(urls)), urls.join("\r\n"))
        compare(Utils.commonParentPath(urls), "/tmp")
        compare(Utils.archiveOutputPath(urls, 123), "/tmp/loom-123.zip")
        compare(Utils.archiveOutputPath([urls[0], "file:///var/b.txt"], 123), "")
        compare(Utils.siblingOutputPath(urls[0], "loom", "jpg", 123), "/tmp/a-loom-123.jpg")
    }

    function test_size_labels() {
        compare(Utils.byteLabel(0), "0 B")
        compare(Utils.byteLabel(1024), "1.0 KB")
        compare(Utils.byteLabel(1073741824), "1.0 GB")
        compare(Utils.byteLabel(-1), "")
    }
}
