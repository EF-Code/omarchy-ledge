# Loom test matrix

## Automated gates

From the repository root:

```bash
node scripts/validate-plugin.mjs
node scripts/check-qml.mjs
node scripts/test-model.mjs
bash -n bin/omarchy-loom
shellcheck bin/omarchy-loom
qmllint -I "$OMARCHY_PATH/shell" qml/*.qml
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests -import qml
omarchy plugin validate .
git diff --check
```

The pure model gate covers URL/path conversion, MIME and Unicode accounting,
settings parsing, geometry bounds, v2 round-trip, partial recovery, v1
migration, deterministic selection ordering, Markdown/JSON generation,
filename collisions, attachment caps, and operation idempotency. The QML test
runner covers the QML-facing utility suite.

## Live Omarchy gates

Validate and install the local development checkout with the supported plugin
commands, put `ef-code.loom` in the bar, restart/rescan the shell, and verify:

- chip renders with no edge strip or full-screen surface;
- click, shell summon, hide, toggle, and right-click prompt routing;
- one-popup-at-a-time behavior with another bar popup;
- top, bottom, left, and right bar placement and narrow-output fitting;
- light and dark themes;
- shell restart state restoration and legacy migration without deleting the
  legacy file;
- disable/remove leaves the shell healthy.

## Canvas/export gates

Add file, image, URL, text, note, and stack cards. Move and resize repeatedly,
select one/several/none, copy prompts, tidy, restart, and inspect exports.
Include Unicode, multiline text, unavailable and oversized files, a directory,
and duplicate names. Verify `context.md`, `context.json`, sanitized names,
omitted-file reporting, directory export when `zip` is unavailable, and a
second export request returning busy.

## Multi-monitor gates

With two active bars, drop on monitor A and observe B's count, open on A then B
with only one popup, add a note on B and observe A, summon from focused windows
on both outputs, restart, and remove one output while the popup is open. A
successful IPC or offscreen call is not evidence for these compositor checks.
