# Loom architecture

Loom is a bar-widget plugin with one live widget per Omarchy output. The
widget owns the canonical model and IPC target (`ef-code.loom`); its popup is
an exact-size `PanelWindow` anchored to the clicked `WidgetButton`.

## Runtime layers

- `qml/BarWidget.qml` extends Omarchy's `qs.Ui.Panel`. It owns the bar chip,
  direct chip drop target, spring timer, lifecycle routing, ListModel, state
  restore/migration, metadata queue, prompt generation, and export controller.
- `qml/LoomPopup.qml` owns only output selection, bar-relative geometry,
  keyboard policy, opacity, hover tracking, and popup hosting. It has no
  fullscreen dismissal surface.
- `qml/LoomWorkspace.qml` owns the header, inbox rail/drawer, canvas viewport,
  selection presentation, and user-facing signals.
- `qml/CanvasCard.qml` owns canvas movement, bounded resizing, note editing,
  selection clicks, and the dedicated external drag handle.
- `qml/InboxCard.qml` keeps newly received cards dense until they are placed.
- `qml/ExportController.qml` serializes one bounded directory/ZIP export.
- `qml/utils.js` is pure and is tested independently of QML.

## State and trust boundary

State is version 2 at `<Quickshell.stateDir>/omarchy-loom/loom.json`, written
by atomic `FileView` writes. A card stores a reference, metadata, bounded text,
and finite geometry; transient selection/editing/drag state is not persisted.
URLs are never fetched. Legacy `loom-state.json` is read only when no valid
Loom state exists, converted to a deterministic canvas grid, and never deleted.

The plugin runs unsandboxed in `omarchy-shell`, so untrusted paths and text are
kept away from shell strings. Metadata, directory creation, and attachment
copying use argv arrays. Export names are sanitized, each attachment is capped
at 20 MiB, the total is capped at 80 MiB, and directories are references only.

## Multi-monitor synchronization

Every mutation is wrapped in an operation containing an ID, timestamp, kind,
and payload. The initiating widget calls `bar.moduleWidgets(moduleName)` and
each peer applies the operation through an idempotent bounded recent-ID set.
Only the initiating widget schedules the atomic state write. Opening one
popup closes peer popups before asking `bar.requestPopout(root)` to coordinate
with other shell popouts.

Selection is intentionally local to the visible popup. Geometry, content,
placement, deletion, tidy, and title mutations are shared operations.

## Popup geometry

The popup selects `anchorItem.QsWindow.window.screen`, follows the anchor
coordinates inside that bar window, then clamps a fitted 880×600 target to the
active output. Top, bottom, left, and right bar positions are handled without
assuming a 1920×1080 output or scale 1.0. `WlrLayer.Top` and
`ExclusionMode.Ignore` keep it above normal windows without reserving desktop
space.
