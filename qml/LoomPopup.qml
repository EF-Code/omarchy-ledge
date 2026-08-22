import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Exact-size layer-shell surface anchored to the bar chip. There is no
// fullscreen dismissal catcher: the only input surface is this rectangle, so
// a file dragged from another application can still reach its target.
PanelWindow {
    id: popup

    property Item anchorItem: null
    property QtObject bar: null
    property bool open: false
    property Item focusTarget: null
    property int desiredWidth: 880
    property int desiredHeight: 600
    property int gap: 0
    property int screenMargin: Style.gapsOut
    property var theme: null

    signal closeRequested()

    default property alias content: holder.children
    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property string barPos: bar && bar.position ? String(bar.position) : "top"
    readonly property real screenW: screen ? screen.width : 0
    readonly property real screenH: screen ? screen.height : 0
    readonly property real barW: anchorWindow ? anchorWindow.width : 0
    readonly property real barH: anchorWindow ? anchorWindow.height : 0
    readonly property bool hovered: hover.hovered

    function fittedWidth(value) {
        var maximum = screenW > 0 ? screenW - screenMargin * 2 : value
        if (barPos === "left" || barPos === "right") maximum = Math.min(maximum, screenW - barW - gap - screenMargin)
        return Math.round(Math.max(360, Math.min(value, Math.max(360, maximum))))
    }
    function fittedHeight(value) {
        var maximum = screenH > 0 ? screenH - screenMargin * 2 : value
        if (barPos === "top" || barPos === "bottom") maximum = Math.min(maximum, screenH - barH - gap - screenMargin)
        return Math.round(Math.max(300, Math.min(value, Math.max(300, maximum))))
    }

    readonly property int popupWidth: fittedWidth(desiredWidth)
    readonly property int popupHeight: fittedHeight(desiredHeight)

    TransformWatcher {
        id: anchorWatcher
        a: popup.anchorWindow ? popup.anchorWindow.contentItem : null
        b: popup.anchorItem
    }

    readonly property point anchorPos: {
        anchorWatcher.transform
        if (!anchorItem || !anchorWindow) return Qt.point(0, 0)
        return anchorItem.mapToItem(anchorWindow.contentItem, 0, 0)
    }

    readonly property point popupOrigin: {
        var x = screenMargin, y = screenMargin
        if (anchorItem && anchorWindow) {
            if (barPos === "bottom") {
                x = anchorPos.x + anchorItem.width / 2 - popupWidth / 2
                y = screenH - barH - popupHeight - gap
            } else if (barPos === "left") {
                x = barW + gap
                y = anchorPos.y + anchorItem.height / 2 - popupHeight / 2
            } else if (barPos === "right") {
                x = screenW - barW - popupWidth - gap
                y = anchorPos.y + anchorItem.height / 2 - popupHeight / 2
            } else {
                x = anchorPos.x + anchorItem.width / 2 - popupWidth / 2
                y = barH + gap
            }
        }
        x = Math.max(screenMargin, Math.min(x, Math.max(screenMargin, screenW - popupWidth - screenMargin)))
        y = Math.max(screenMargin, Math.min(y, Math.max(screenMargin, screenH - popupHeight - screenMargin)))
        return Qt.point(Math.round(x), Math.round(y))
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: open || shell.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: popupWidth
    implicitHeight: popupHeight

    WlrLayershell.namespace: "omarchy-loom"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
    }
    margins {
        top: popup.popupOrigin.y
        left: popup.popupOrigin.x
    }

    onOpenChanged: {
        if (!open || !focusTarget) return
        Qt.callLater(function() {
            if (popup.open && popup.focusTarget) popup.focusTarget.forceActiveFocus()
        })
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: theme ? theme.radius : 12
        color: theme ? theme.surface : Color.background
        border.color: theme ? theme.border : Color.muted
        border.width: 1
        opacity: popup.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover }

        Item {
            id: holder
            anchors.fill: parent
            anchors.margins: 1
        }
    }
}
