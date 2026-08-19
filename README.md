# Loom

A floating cross-workspace staging shelf for [Omarchy](https://omarchy.org) / [Hyprland](https://hypr.land), built as a native Quickshell `panel` plugin.

Loom lives on the Wayland `wlr-layer-shell` overlay layer, anchored to the right edge of the screen. Because layer-shell surfaces are attached to the output rather than a specific workspace, Loom stays visible and accessible as you cycle through workspaces — letting you stage an asset (image, file, text snippet) on one workspace and drag it out into an app on another.

## How it works

```
Workspace 1 (Browser / Nemo) ──► drag file to screen edge ──► [Loom shelf]
                                                                       │
                                                              (switch workspace)
                                                                       │
Workspace 3 (Discord / GIMP)  ◄── drag card out of shelf ◄────────────┘
```

### Visual states

1. **Idle** — a 6px accent strip on the right screen edge, zero interaction cost.
2. **Reveal** — hover near the right edge, or trigger via IPC / keybind, and the shelf slides out with spring motion.
3. **Staged cards** — each dropped item becomes a card with a thumbnail (images), metadata, and drag-out support.
4. **Auto-collapse** — when the last item is removed, Loom animates back to the idle strip.

### Card types

- **Images** (PNG, JPG, WebP, SVG, GIF, BMP, AVIF) — live thumbnail preview + size.
- **Files** — file icon, name, byte size.
- **Text snippets** — text icon, line/byte count.
- **Multi-file drops** — each file gets its own card.

### Micro-actions

- 📌 **Pin** — keep a card indefinitely as a persistent scratchpad item.
- 🧹 **Clear** — purge all unpinned cards.
- ✕ **Remove** — remove a single card.
- Drag-out — grab a card to start a native Wayland drag into any target window.

## Installation

### From git (recommended)

```bash
omarchy plugin add https://github.com/EF-Code/omarchy-loom.git --enable
```

### By hand

1. Clone or copy this repo into `~/.config/omarchy/plugins/ef-code.loom/`.
2. Rescan: `omarchy-shell shell rescanPlugins`.
3. Enable: `omarchy plugin enable ef-code.loom`.

## Keybinding

Add to your Hyprland config (`~/.config/hypr/hyprland.conf`):

```conf
bind = $mainMod, D, exec, omarchy-shell shell toggle ef-code.loom '{}'
```

This toggles Loom open/closed via the shell's IPC contract (`toggle <id> <payloadJson>`).

## IPC contract

The Omarchy shell exposes two ways to control Loom:

**Shell lifecycle commands** — operate on the plugin ID, work without a custom IPC target:

| Command | Effect |
|---------|--------|
| `omarchy-shell shell summon ef-code.loom '{}'` | load + open the shelf |
| `omarchy-shell shell hide ef-code.loom` | close the shelf |
| `omarchy-shell shell toggle ef-code.loom '{}'` | toggle open/closed |

**Direct method calls** — Loom registers a `loom` IPC target with these methods:

| Method | Returns | Effect |
|--------|---------|--------|
| `open <payloadJson>` | `ok` | open the shelf |
| `close` | `ok` | close the shelf |
| `toggle <payloadJson>` | `ok` | toggle open/closed |
| `state` | `open` / `closed` | current visibility |
| `count` | integer string | number of staged items |
| `clear` | `ok` | remove all unpinned items |
| `ping` | `ok` | health check |

```bash
# Toggle via the shell's built-in lifecycle command
omarchy-shell shell toggle ef-code.loom '{}'

# Call a method on the plugin's IPC target
omarchy-shell shell call ef-code.loom count ''
omarchy-shell shell call ef-code.loom state ''
omarchy-shell shell call ef-code.loom ping ''
```

## Development

### Prerequisites

- Quickshell 0.3.0+ (Wayland layer-shell support)
- Qt 6 (qt6-declarative)

### Local preview

```bash
quickshell -p qml/Loom.qml
```

### Validate the manifest

```bash
omarchy plugin validate .
```

### Hot reload

When installed under `~/.config/omarchy/plugins/`, saving any file reloads the plugin automatically. Force a rescan with:

```bash
omarchy-shell shell rescanPlugins
```

## Plugin manifest

```json
{
  "schemaVersion": 1,
  "id": "ef-code.loom",
  "name": "Loom",
  "version": "0.1.0",
  "author": "ef-code",
  "license": "MIT",
  "description": "A floating cross-workspace staging shelf for Hyprland.",
  "kinds": ["panel"],
  "keepLoaded": true,
  "entryPoints": { "panel": "qml/Loom.qml" }
}
```

- **kind: `panel`** — a persistent or summoned floating window, per the Omarchy shell contract.
- **keepLoaded: true** — the layer-shell window stays mounted between summons so edge-drag detection works continuously (an officially documented field in the [shell reference](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md)).

## Project structure

```
omarchy-loom/
├── manifest.json          # Plugin metadata + entrypoint
├── README.md
├── LICENSE                # MIT
├── assets/
│   └── icon.svg           # Marketplace icon
└── qml/
    ├── Loom.qml          # PanelWindow root: layer-shell surface + DropArea + IPC + shelf UI
    ├── StagedCard.qml     # Individual card with thumbnail + drag-out
    ├── LoomButton.qml    # Reusable footer button component
    └── utils.js           # File path, size, and MIME helpers
```

## License

MIT — see [LICENSE](LICENSE).
