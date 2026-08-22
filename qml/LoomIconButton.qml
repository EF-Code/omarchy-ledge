import QtQuick
import qs.Commons

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property var theme: null
    property bool active: false
    property bool enabled: true
    signal clicked()

    implicitWidth: Math.max(28, labelText.implicitWidth + 18)
    implicitHeight: 28
    radius: theme ? theme.smallRadius : 7
    color: !enabled ? "transparent" : (mouse.containsMouse || active ? (theme ? theme.selection : "#334155") : "transparent")
    border.width: active ? 1 : 0
    border.color: theme ? theme.accent : Color.accent
    opacity: enabled ? 1 : 0.42

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: root.glyph !== ""
            text: root.glyph
            color: root.theme ? root.theme.text : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
        Text {
            id: labelText
            text: root.label
            color: root.theme ? root.theme.text : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
