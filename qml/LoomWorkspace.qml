import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

FocusScope {
    id: root

    property var theme: null
    property alias model: canvasRepeater.model
    property string boardTitle: "Untitled context"
    property int inboxCount: 0
    property int canvasCount: 0
    property int selectionCount: 0
    property bool actionBusy: false
    property string statusMessage: ""
    property string exportPath: ""
    property bool editingActive: false
    property bool popupNarrow: width < 760
    property bool inboxOpen: !popupNarrow
    readonly property Item focusTarget: root

    signal closeRequested()
    signal copyPromptRequested()
    signal exportRequested()
    signal tidyRequested()
    signal createNoteRequested()
    signal clearInboxRequested()
    signal deleteSelectedRequested()
    signal selectRequested(string itemId, bool additive)
    signal placeRequested(string itemId)
    signal removeRequested(string itemId)
    signal geometryRequested(string itemId, real x, real y, real width, real height)
    signal textEdited(string itemId, string title, string body)
    signal editCancelled(string itemId, bool discard)
    signal dropUrlsRequested(var urls, string target, real x, real y)
    signal dropTextRequested(string text, string target, real x, real y)
    signal copyExportPathRequested()
    signal openExportFolderRequested()

    focus: true
    activeFocusOnTab: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.deleteSelectedRequested(); event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (root.editingActive) root.cancelAllEditing()
            else if (root.selectionCount > 0) root.selectRequested("", false)
            else root.closeRequested()
            event.accepted = true
        }
    }

    function cancelAllEditing() {
        for (var i = 0; i < canvasRepeater.count; i++) {
            var item = canvasRepeater.itemAt(i)
            if (item && item.cardEditing) item.cancelEditing()
        }
        root.editingActive = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: "transparent"
            border.color: theme ? theme.border : Color.muted
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 9

                Rectangle {
                    width: 32
                    height: 32
                    radius: theme ? theme.smallRadius : 8
                    color: theme ? theme.accent : Color.accent
                    Text {
                        anchors.centerIn: parent
                        text: "L"
                        color: theme ? theme.surface : Color.background
                        font.family: Style.font.family
                        font.bold: true
                        font.pixelSize: 16
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Loom"
                        color: theme ? theme.text : Color.foreground
                        font.family: Style.font.family
                        font.bold: true
                        font.pixelSize: 15
                    }
                    Text {
                        text: root.canvasCount + " on canvas · " + root.inboxCount + " inbox" + (root.selectionCount ? " · " + root.selectionCount + " selected" : "")
                        color: theme ? theme.muted : Color.muted
                        font.family: Style.font.family
                        font.pixelSize: 10
                    }
                }
                Item { Layout.fillWidth: true }
                LoomIconButton { theme: root.theme; glyph: "＋"; label: "Note"; onClicked: root.createNoteRequested() }
                LoomIconButton { theme: root.theme; glyph: "≋"; label: "Tidy"; enabled: root.canvasCount > 1; onClicked: root.tidyRequested() }
                LoomIconButton { theme: root.theme; glyph: "⧉"; label: "Prompt"; enabled: root.canvasCount > 0; onClicked: root.copyPromptRequested() }
                LoomIconButton { theme: root.theme; glyph: "⇩"; label: "Export"; enabled: root.canvasCount > 0 && !root.actionBusy; onClicked: root.exportRequested() }
                LoomIconButton { theme: root.theme; glyph: "×"; onClicked: root.closeRequested() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                id: inboxPanel
                visible: root.inboxOpen
                Layout.preferredWidth: root.popupNarrow ? root.width : 236
                Layout.fillHeight: true
                color: theme ? theme.surface : Color.background
                border.color: theme ? theme.border : Color.muted
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Inbox"
                            color: theme ? theme.text : Color.foreground
                            font.family: Style.font.family
                            font.bold: true
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.inboxCount
                            color: theme ? theme.accent : Color.accent
                            font.pixelSize: 11
                        }
                        Text {
                            text: "Clear"
                            color: theme ? theme.muted : Color.muted
                            font.pixelSize: 10
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearInboxRequested()
                            }
                        }
                    }
                    DropCollector {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        onDragEntered: dropLabel.color = root.theme ? root.theme.accent : Color.accent
                        onDragExited: dropLabel.color = root.theme ? root.theme.muted : Color.muted
                        onUrlsDropped: (urls, x, y) => root.dropUrlsRequested(urls, "inbox", x, y)
                        onTextDropped: (text, x, y) => root.dropTextRequested(text, "inbox", x, y)
                        Rectangle {
                            anchors.fill: parent
                            radius: root.theme ? root.theme.smallRadius : 7
                            color: root.theme ? root.theme.raised : Color.background
                            border.color: root.theme ? root.theme.border : Color.muted
                            border.width: 1
                        }
                        Text {
                            id: dropLabel
                            anchors.centerIn: parent
                            text: "Drop or paste context"
                            color: root.theme ? root.theme.muted : Color.muted
                            font.pixelSize: 10
                        }
                    }
                    ListView {
                        id: inboxList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        clip: true
                        model: root.model
                        delegate: InboxCard {
                            required property string itemId
                            required property string kind
                            required property string url
                            required property string urlsJson
                            required property string text
                            required property string name
                            required property string subtitle
                            required property bool inInbox
                            required property bool selected
                            width: inboxList.width
                            visible: inInbox
                            height: inInbox ? 72 : 0
                            theme: root.theme
                            cardId: itemId
                            cardKind: kind
                            cardUrl: url
                            cardUrlsJson: urlsJson
                            cardText: text
                            cardName: name
                            cardSubtitle: subtitle
                            cardSelected: selected
                            onPlaceRequested: root.placeRequested(itemId)
                            onSelectedRequested: (id, additive) => root.selectRequested(id, additive)
                            onRemoveRequested: root.removeRequested(itemId)
                        }
                    }
                    Text {
                        visible: root.inboxCount === 0
                        text: "New drops wait here\nuntil you place them."
                        color: root.theme ? root.theme.muted : Color.muted
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                id: canvasPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme ? theme.surface : Color.background

                Flickable {
                    id: canvasFlick
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    contentWidth: Math.max(width, 1800)
                    contentHeight: Math.max(height, 1250)
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalAndVerticalFlick

                    Item {
                        id: canvasContent
                        width: canvasFlick.contentWidth
                        height: canvasFlick.contentHeight

                        Repeater {
                            id: canvasRepeater
                            delegate: CanvasCard {
                                required property string itemId
                                required property string kind
                                required property string url
                                required property string urlsJson
                                required property string text
                                required property string name
                                required property string subtitle
                                required property string mime
                                required property string domain
                                required property string sizeLabel
                                required property string dimensions
                                required property bool onCanvas
                                required property bool selected
                                required property real xPosition
                                required property real yPosition
                                required property real cardWidth
                                required property real cardHeight
                                required property real zIndex
                                visible: onCanvas
                                theme: root.theme
                                cardId: itemId
                                cardKind: kind
                                cardUrl: url
                                cardUrlsJson: urlsJson
                                cardText: text
                                cardName: name
                                cardSubtitle: subtitle
                                cardMime: mime
                                cardDomain: domain
                                cardSizeLabel: sizeLabel
                                cardDimensions: dimensions
                                cardSelected: selected
                                storedX: xPosition
                                storedY: yPosition
                                storedWidth: cardWidth
                                storedHeight: cardHeight
                                storedZ: zIndex
                                onSelectedRequested: (id, additive) => root.selectRequested(id, additive)
                                onGeometryChanged: (id, x, y, w, h) => root.geometryRequested(id, x, y, w, h)
                                onRemoveRequested: (id) => root.removeRequested(id)
                                onTextEdited: (id, title, body) => root.textEdited(id, title, body)
                                onEditCancelled: (id, discard) => root.editCancelled(id, discard)
                                onEditStateChanged: (editing) => root.editingActive = editing
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -100
                            onClicked: root.selectRequested("", false)
                        }

                        DropCollector {
                            anchors.fill: parent
                            z: 200
                            onUrlsDropped: (urls, x, y) => root.dropUrlsRequested(urls, "canvas", x, y)
                            onTextDropped: (text, x, y) => root.dropTextRequested(text, "canvas", x, y)
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    z: -1
                    color: "transparent"
                    Repeater {
                        model: Math.ceil(parent.width / 28)
                        Rectangle { x: index * 28; width: 1; height: parent.height; color: root.theme ? root.theme.grid : "#ffffff12" }
                    }
                    Repeater {
                        model: Math.ceil(parent.height / 28)
                        Rectangle { y: index * 28; height: 1; width: parent.width; color: root.theme ? root.theme.grid : "#ffffff12" }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    visible: root.canvasCount === 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Loom canvas"; color: root.theme ? root.theme.text : Color.foreground; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Drop onto the chip · add a note · place inbox cards"; color: root.theme ? root.theme.muted : Color.muted; font.pixelSize: 11 }
                }

                Rectangle {
                    visible: root.statusMessage !== ""
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    height: 28
                    radius: root.theme ? root.theme.smallRadius : 7
                    color: root.theme ? root.theme.raised : Color.background
                    border.color: root.theme ? root.theme.border : Color.muted
                    Text {
                        id: statusLabel
                        anchors.fill: parent
                        anchors.margins: 7
                        anchors.rightMargin: root.exportPath !== "" ? 170 : 7
                        text: root.statusMessage
                        color: root.theme ? root.theme.text : Color.foreground
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Row {
                        visible: root.exportPath !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Text {
                            text: "Copy path"
                            color: root.theme ? root.theme.accent : Color.accent
                            font.pixelSize: 9
                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.copyExportPathRequested() }
                        }
                        Text {
                            text: "Open folder"
                            color: root.theme ? root.theme.accent : Color.accent
                            font.pixelSize: 9
                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.openExportFolderRequested() }
                        }
                    }
                }

                LoomIconButton {
                    visible: root.popupNarrow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 8
                    theme: root.theme
                    glyph: "☷"
                    label: "Inbox"
                    onClicked: root.inboxOpen = !root.inboxOpen
                }
            }
        }
    }
}
