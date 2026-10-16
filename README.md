# Snap

macOS-style screenshots for [Noctalia](https://github.com/noctalia-dev/noctalia) on niri.

A picker panel chooses what to capture: **Region**, **Window**, **Screen** (pick a monitor) or **All screens**. Use
a click, the key on each tile (`R` `W` `S` `A`, or `1`–`4`), or the arrows and `Enter`. The capture is saved and
copied according to your `[shell.screenshot]` settings. A preview then opens bottom-right with **Annotate**
(Noctalia's editor), **Open**, **Copy**, **Folder** (show in the file manager) and **Delete**, each with a key
(`A` `O` `C` `F` `D`).

Window captures come from niri. Snap restores full opacity (niri bakes window-rule opacity into captures), rounds
the corners to match on-screen windows (16 px), and adds a soft drop shadow.

## Requirements

- niri, for window picking and capture
- ImageMagick (`magick`), for the window shadow
- `wl-clipboard`, to copy window captures and for the preview's Copy
- `jq`
- `gdbus` and a file manager implementing `org.freedesktop.FileManager1` (e.g. Nautilus) for **Folder**; without
  it Snap opens the folder instead

Set `annotate = false` under `[shell.screenshot]`: otherwise Region and Screen captures open the editor before
Snap's preview.

## Install

Clone this repository into Noctalia's local plugin folder and enable it:

```sh
git clone https://github.com/filedesless/noctalia-snap ~/.local/share/noctalia/plugins/snap
noctalia msg plugins enable filedesless/snap
```

## Use

Bind the picker to a key in your compositor, e.g. in niri:

```kdl
Print { spawn "noctalia" "msg" "panel-toggle" "filedesless/snap:picker"; }
```

To capture without the picker, send a mode (`region`, `window`, `screen` or `all`) to the service:

```sh
noctalia msg plugin filedesless/snap:service all capture region
```

## What it runs

Everything Snap does is in `capture.sh` and the three `.luau` entries:

- `noctalia msg` (screenshots, the annotation editor, opening the preview panel)
- `niri msg` (`pick-window`, `screenshot-window` into `$XDG_RUNTIME_DIR/noctalia-snap/`)
- `magick`, `wl-copy`, `xdg-open`, `gdbus`
- files: it writes window captures into your screenshot folder, and **Delete** removes the previewed file. It makes
  no network requests.
