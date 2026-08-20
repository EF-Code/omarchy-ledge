# Loom

Loom is a floating cross-workspace staging shelf for [Omarchy](https://omarchy.org) and Hyprland. Drop an asset onto the right screen edge, change workspaces, then drag it from Loom into another application.

It runs as a native Quickshell `panel` plugin on Wayland's overlay layer. The collapsed surface is a 4 px accent strip; entering it with the pointer or a compositor drag expands the shelf without reserving desktop workspace.

## Current feature set

- Local files with names and asynchronously collected byte sizes.
- Images with live thumbnails, intrinsic dimensions, and file sizes.
- Text snippets with UTF-8 byte and line counts.
- Web links with a domain badge.
- Multi-file drops collected into one stack card and dragged back out as a URI list.
- Native Wayland drag-out with automatic removal after a successful drop.
- Persistent pins that survive shell restarts and are excluded from bulk clearing.
- Shell lifecycle and direct IPC methods for keybindings and scripts.

Hover a card to reveal its contextual actions:

- **Copy** copies a path, link, text snippet, or stack path list.
- **Base64** copies a data URI for local files up to 10 MB.
- **PNG / JPG** converts an image beside the source and stages the result.
- **Archive** creates a ZIP beside a same-directory multi-file stack and stages it.

Pinned cards remain after a successful drag-out. Unpinned cards are removed after the target accepts the drop, and the shelf collapses when its last card is removed.

## Installation

```bash
omarchy plugin add https://github.com/EF-Code/omarchy-loom.git --enable
```

To install a local checkout by hand:

1. Copy it to `~/.config/omarchy/plugins/ef-code.loom/`.
2. Run `omarchy-shell shell rescanPlugins`.
3. Run `omarchy plugin enable ef-code.loom`.

Plugins execute unsandboxed inside the long-running Omarchy shell. Review the source before enabling third-party plugins.

## Removal

```bash
omarchy plugin remove ef-code.loom
```

The Omarchy plugin manager disables and unloads Loom before removing its checkout.

## Keybinding

Add this to `~/.config/hypr/hyprland.conf`:

```conf
bind = $mainMod, D, exec, omarchy-shell shell toggle ef-code.loom '{}'
```

## IPC

Omarchy lifecycle commands operate on the plugin ID:

```bash
omarchy-shell shell summon ef-code.loom '{}'
omarchy-shell shell hide ef-code.loom
omarchy-shell shell toggle ef-code.loom '{}'
```

The shell can also call methods on the loaded plugin:

```bash
omarchy-shell shell call ef-code.loom state ''
omarchy-shell shell call ef-code.loom count ''
omarchy-shell shell call ef-code.loom clear ''
omarchy-shell shell call ef-code.loom stageText 'Remember this'
omarchy-shell shell call ef-code.loom stageUrl 'file:///path/to/asset.png'
omarchy-shell shell call ef-code.loom ping ''
```

`clear` removes only transient cards. Remove a pinned card explicitly or unpin it first.

## Runtime requirements

Loom requires Quickshell 0.3.0 or newer and Qt 6 on Wayland. Core staging uses standard GNU utilities already expected on Omarchy:

| Feature | Command |
|---|---|
| File sizes | `stat` |
| Code/text file line counts | `awk` |
| Base64 data URI | `base64` |
| PNG/JPG conversion | `magick` from ImageMagick |
| Stack archive | `zip` |

Conversion and archive buttons fail visibly when their optional command is unavailable. Dropped paths are always passed as distinct process arguments; Loom does not interpolate them into shell commands.

Pinned state is written atomically to `loom-state.json` inside `Quickshell.stateDir`. Transient drops are deliberately session-only.

## Development

The Omarchy entry point is an `Item` that owns a `PanelWindow`, matching the shell's loader contract. Use the standalone wrapper for local preview:

```bash
quickshell -p qml/Preview.qml
```

Run static and utility checks with:

```bash
qmllint qml/Loom.qml qml/ShelfView.qml qml/DropCollector.qml qml/StagedCard.qml qml/LoomButton.qml qml/Preview.qml
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests -import qml
```

On Omarchy, validate the manifest and reload an installed development copy with:

```bash
omarchy plugin validate .
omarchy-shell shell rescanPlugins
```

## Structure

```text
omarchy-loom/
├── manifest.json
├── assets/icon.svg
├── tests/tst_utils.qml
└── qml/
    ├── Loom.qml          # Host lifecycle, model, persistence, processes, window
    ├── ShelfView.qml      # Shelf layout and card list
    ├── DropCollector.qml  # Compositor drag/drop boundary
    ├── StagedCard.qml     # Preview, drag-out, pin and micro-actions
    ├── LoomButton.qml
    ├── Preview.qml        # Standalone development host
    └── utils.js           # Pure URL, text, MIME and output-path helpers
```

## Known integration boundaries

- A layer-shell surface cannot see a drag before the compositor moves it into the 4 px edge target.
- The current build creates one panel surface; multi-monitor placement needs verification in Omarchy before claiming per-output behavior.
- Stack archiving is intentionally limited to local items sharing one parent directory.
- URL cards display a domain badge but do not fetch favicons, avoiding an automatic third-party network request.

## License

MIT — see [LICENSE](LICENSE).
