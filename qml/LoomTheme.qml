import QtQuick
import qs.Commons

// Guarded theme roles. Omarchy's Color and Style singletons are the source of
// truth; fallbacks keep a preview usable if a future shell renames a role.
QtObject {
    id: theme

    readonly property color surface: Color.popups && Color.popups.background ? Color.popups.background : Color.background
    readonly property color raised: Color.popups && Color.popups.surface ? Color.popups.surface : Color.background
    readonly property color hover: Color.popups && Color.popups.surfaceHover ? Color.popups.surfaceHover : Color.foreground
    readonly property color text: Color.popups && Color.popups.text ? Color.popups.text : Color.foreground
    readonly property color muted: Color.muted ? Color.muted : Color.foreground
    readonly property color accent: Color.accent ? Color.accent : Color.foreground
    readonly property color danger: Color.urgent ? Color.urgent : accent
    readonly property color border: Color.popups && Color.popups.border ? Color.popups.border : Color.muted
    readonly property color selection: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color grid: Qt.rgba(text.r, text.g, text.b, 0.07)
    readonly property color tooltipSurface: Color.tooltip && Color.tooltip.background ? Color.tooltip.background : surface
    readonly property color tooltipText: Color.tooltip && Color.tooltip.text ? Color.tooltip.text : text
    readonly property color tooltipBorder: Color.tooltip && Color.tooltip.border ? Color.tooltip.border : border

    readonly property int radius: Math.min(Style.cornerRadius, Style.space(12))
    readonly property int smallRadius: Math.min(radius, Style.space(8))
    readonly property int spacing: Style.spacing.lg
    readonly property int padding: Style.spacing.popupPadding
}
