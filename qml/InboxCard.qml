import QtQuick
import QtQuick.Layouts
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
    property bool cardSelected: false

    signal placeRequested(string itemId)
    signal selectedRequested(string itemId, bool additive)
    signal removeRequested(string itemId)

    height: 72
    radius: theme ? theme.smallRadius : 8
    color: cardSelected ? (theme ? theme.selection : "#334155") : (theme ? theme.raised : "#1e1e2e")
    border.color: cardSelected ? (theme ? theme.accent : "#89b4fa") : (theme ? theme.border : "#45475a")
    border.width: cardSelected ? 2 : 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: card.cardKind === "note" ? "✎" : card.cardKind === "url" ? "↗" : card.cardKind === "stack" ? "≡" : card.cardKind === "image" ? "▧" : "•"
            color: theme ? theme.accent : "#89b4fa"
            font.pixelSize: 16
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: card.cardName
                color: theme ? theme.text : "#cdd6f4"
                font.bold: true
                font.pixelSize: 11
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            Text {
                text: card.cardSubtitle || card.cardUrl || card.cardText
                color: theme ? theme.muted : "#7f849c"
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        Text {
            text: "＋"
            color: theme ? theme.accent : "#89b4fa"
            font.pixelSize: 17
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: card.placeRequested(card.cardId)
            }
        }
        Text {
            text: "×"
            color: theme ? theme.danger : "#f38ba8"
            font.pixelSize: 17
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: card.removeRequested(card.cardId)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: card.selectedRequested(card.cardId, (mouse.modifiers & Qt.ControlModifier) !== 0)
    }
}
