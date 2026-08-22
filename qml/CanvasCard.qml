import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "utils.js" as Utils

Rectangle {
    id: card

    property var theme: null
    property string cardId: ""
    property string cardKind: "file"
    property string cardUrl: ""
    property string cardUrlsJson: "[]"
    property string cardText: ""
    property string cardName: ""
    property string cardSubtitle: ""
    property string cardMime: "text/plain"
    property string cardDomain: ""
    property string cardSizeLabel: ""
    property string cardDimensions: ""
    property bool cardSelected: false
    property bool cardEditing: false
    property real storedX: 24
    property real storedY: 24
    property real storedWidth: 280
    property real storedHeight: 190
    property real storedZ: 1
    property bool draggingCard: false
    property real resizeStartWidth: 0
    property real resizeStartHeight: 0
    property real resizeStartX: 0
    property real resizeStartY: 0

    signal selectedRequested(string itemId, bool additive)
    signal geometryChanged(string itemId, real x, real y, real width, real height)
    signal removeRequested(string itemId)
    signal textEdited(string itemId, string title, string body)
    signal editStateChanged(bool editing)
    signal editCancelled(string itemId, bool discard)

    function cancelEditing() {
        if (!card.cardEditing) return
        var discard = card.cardKind === "note" && card.cardName === "New note" && !String(editor.text || "").trim()
        card.cardEditing = false
        card.editStateChanged(false)
        editor.clearFocus()
        card.editCancelled(card.cardId, discard)
    }

    x: storedX
    y: storedY
    width: storedWidth
    height: storedHeight
    z: storedZ
    radius: theme ? theme.radius : 10
    color: theme ? theme.raised : "#1e1e2e"
    border.width: cardSelected ? 2 : 1
    border.color: cardSelected ? (theme ? theme.accent : "#89b4fa") : (theme ? theme.border : "#45475a")
    clip: true

    // Re-apply remote model geometry without disturbing an active local drag.
    onStoredXChanged: if (!draggingCard) x = storedX
    onStoredYChanged: if (!draggingCard) y = storedY
    onStoredWidthChanged: if (!draggingCard) width = storedWidth
    onStoredHeightChanged: if (!draggingCard) height = storedHeight

    Drag.active: exportHandle.pressed
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: {
        if (cardKind === "text" || cardKind === "note") return { "text/plain": cardText }
        if (cardKind === "stack") return { "text/uri-list": Utils.uriList(cardUrlsJson) }
        return { "text/uri-list": cardUrl + "\r\n" }
    }
    Drag.imageSource: cardKind === "image" ? cardUrl : ""

    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        color: cardSelected ? (theme ? theme.selection : "#334155") : "transparent"

        MouseArea {
            id: moveHandle
            anchors.left: parent.left
            anchors.right: actionCluster.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            preventStealing: true
            drag.target: card
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: Math.max(0, card.parent ? card.parent.width - card.width : 4000)
            drag.maximumY: Math.max(0, card.parent ? card.parent.height - card.height : 3000)
            onPressed: function(mouse) {
                card.draggingCard = true
                card.selectedRequested(card.cardId, (mouse.modifiers & Qt.ControlModifier) !== 0)
            }
            onReleased: {
                card.draggingCard = false
                card.geometryChanged(card.cardId, card.x, card.y, card.width, card.height)
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: actionCluster.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                text: card.cardKind === "note" ? "✎" : card.cardKind === "url" ? "↗" : card.cardKind === "stack" ? "≡" : card.cardKind === "image" ? "▧" : "•"
                color: theme ? theme.accent : "#89b4fa"
                font.family: Style.font.family
                font.pixelSize: 16
            }
            Text {
                text: card.cardName
                color: theme ? theme.text : "#cdd6f4"
                font.family: Style.font.family
                font.bold: true
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }

        Row {
            id: actionCluster
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                visible: ["file", "image", "stack", "directory", "code"].indexOf(card.cardKind) >= 0
                text: "↗"
                color: theme ? theme.accent : "#89b4fa"
                font.pixelSize: 16
                MouseArea {
                    id: exportHandle
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.DragCopyCursor
                    onPressed: {
                        card.selectedRequested(card.cardId, (mouse.modifiers & Qt.ControlModifier) !== 0)
                        card.Drag.active = true
                        card.Drag.startDrag(Qt.CopyAction)
                    }
                    onReleased: card.Drag.active = false
                }
            }
            Text {
                text: "×"
                color: theme ? theme.danger : "#f38ba8"
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.removeRequested(card.cardId)
                }
            }
        }
    }

    Image {
        id: thumbnail
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: card.cardKind === "image" && card.cardUrl !== "" ? Math.min(92, parent.height * 0.38) : 0
        source: card.cardKind === "image" ? card.cardUrl : ""
        sourceSize.width: 640
        sourceSize.height: 240
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: height > 0
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: thumbnail.visible ? thumbnail.bottom : header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 5

        Text {
            visible: card.cardKind !== "note" && card.cardKind !== "text"
            text: card.cardSubtitle || card.cardUrl
            color: theme ? theme.muted : "#7f849c"
            font.family: Style.font.family
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            visible: !card.cardEditing && (card.cardKind === "text" || card.cardKind === "note")
            text: card.cardText
            color: theme ? theme.text : "#cdd6f4"
            font.family: Style.font.family
            font.pixelSize: 11
            wrapMode: Text.Wrap
            maximumLineCount: 5
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        TextArea {
            id: editor
            visible: card.cardEditing
            text: card.cardText
            color: theme ? theme.text : "#cdd6f4"
            placeholderText: "Write a plain-text note…"
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: Rectangle { color: theme ? theme.surface : "#181825"; radius: 6; border.color: theme ? theme.border : "#45475a" }
            Layout.fillWidth: true
            Layout.fillHeight: true
            onActiveFocusChanged: if (!activeFocus && card.cardEditing) {
                card.textEdited(card.cardId, card.cardName, text)
                card.editStateChanged(false)
            }
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    card.cancelEditing()
                    event.accepted = true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.cardKind === "note" || card.cardKind === "text"
            Text {
                text: card.cardSubtitle || card.cardDimensions
                color: theme ? theme.muted : "#7f849c"
                font.pixelSize: 9
                Layout.fillWidth: true
            }
            Text {
                visible: card.cardKind === "note"
                text: card.cardEditing ? "Done" : "Edit"
                color: theme ? theme.accent : "#89b4fa"
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.cardEditing) {
                            card.textEdited(card.cardId, card.cardName, editor.text)
                            card.editStateChanged(false)
                        } else {
                            card.editStateChanged(true)
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: card.cardKind === "url" && card.cardDomain !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        text: card.cardDomain
        color: theme ? theme.accent : "#89b4fa"
        font.pixelSize: 9
        elide: Text.ElideRight
    }

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 16
        height: 16
        color: "transparent"
        border.color: theme ? theme.muted : "#7f849c"
        opacity: resizeHandle.containsMouse || card.cardSelected ? 0.8 : 0.35

        MouseArea {
            id: resizeHandle
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: {
                card.resizeStartWidth = card.width
                card.resizeStartHeight = card.height
                card.resizeStartX = mouse.x
                card.resizeStartY = mouse.y
            }
            onPositionChanged: if (pressed) {
                card.width = Math.max(180, Math.min(640, card.resizeStartWidth + mouse.x - card.resizeStartX))
                card.height = Math.max(120, Math.min(520, card.resizeStartHeight + mouse.y - card.resizeStartY))
            }
            onReleased: card.geometryChanged(card.cardId, card.x, card.y, card.width, card.height)
        }
    }
}
