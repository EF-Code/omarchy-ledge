# Wayland drag-and-drop notes

Loom has two distinct gestures:

1. The bar chip and popup `DropArea` accept `text/uri-list` and `text/plain`.
   Holding a compatible drag over the chip for 700 ms opens the popup; dropping
   on the chip adds quietly to the inbox.
2. A canvas card moves through its title/header handle. External drag-out can
   start only from the visible `↗` handle, which sets `Drag.active` and calls
   `Drag.startDrag()` inside the real pointer press. The move handle never owns
   the external `Drag` object.

The popup surface is exactly its rectangle. Loom does not install a full-screen
input catcher, so a drag leaving Loom can reach a file manager, browser upload
control, or chat application. `Drag.onDragFinished` is not treated as proof of
acceptance; Loom keeps the source reference after drag-out.

## Manual Wayland matrix

Run this on the real Hyprland session, not through `qmltestrunner`:

- file manager → chip, one file and several files;
- hold a file over the chip and observe the 700 ms spring opening;
- file manager/browser/terminal source → inbox and canvas;
- browser URL drop remains a URL reference and never triggers a request;
- card title moves without starting an external drag;
- `↗` handle drags a file/image/stack to a file manager, browser upload, and
  chat target;
- an empty-space click clears selection and still reaches the underlying app;
- journal output shows the receiving DropArea when a compositor delivers a
  drag, and silence is recorded as an unavailable compositor path rather than
  a passing test.

Useful diagnosis:

```bash
journalctl --user -t omarchy-shell -f | grep -E 'omarchy-shell|loom'
```
