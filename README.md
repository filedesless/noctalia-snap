# Snap

macOS-style screenshots for [Noctalia](https://github.com/noctalia-dev/noctalia) on niri.

A picker panel chooses what to capture: **Region**, **Window**, **Screen** (click a monitor) or **All screens**. Use
a click, the key on each tile (`R` `W` `S` `A`, or `1`–`4`), or the arrows and `Enter`. The capture is saved and
copied according to your `[shell.screenshot]` settings. A preview then opens bottom-right with **Annotate**
(Noctalia's editor), **Open**, **Copy**, **Folder** (show in the file manager) and **Delete**, each with a key
(`A` `O` `C` `F` `D`).

Press `T` (or click the timer under the tiles) to cycle a delay: off, 3, 5 or 10 seconds. Snap remembers it.
**Region**, **Screen** and **Window** wait after you pick the area, monitor or window, so you can open a menu or
hover something first; **All screens** waits right away. A timed region is picked with `slurp` and captured with
`grim` (then copied), since Noctalia's own overlay captures as soon as you release. A notification counts down
and closes just before the capture, so it stays out of the shot.

Picking a screen dims every monitor except the one under the pointer, which gets an outline in your theme's
accent color. Press `Esc` in any picker to cancel quietly.

Window captures come from niri. Snap restores full opacity (niri bakes window-rule opacity into captures), rounds
the corners to match on-screen windows (16 px), and adds a soft drop shadow.

## Requirements

- niri, for window picking and capture
- `slurp`, to click a monitor for **Screen** and to pick a timed **Region**
- `grim`, to capture a timed **Region**
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

To capture without the picker, send a mode (`region`, `window`, `screen` or `all`) to the service, optionally
followed by a delay in seconds:

```sh
noctalia msg plugin filedesless/snap:service all capture region
noctalia msg plugin filedesless/snap:service all capture "screen 5"
```

## What it runs

Everything Snap does is in `capture.sh` and the three `.luau` entries:

- `noctalia msg` (screenshots, the annotation editor, opening the preview panel)
- `niri msg` (`pick-window`, `screenshot-window` into `$XDG_RUNTIME_DIR/noctalia-snap/`, and `outputs`/`layers` to
  find monitors and tell when the region overlay closes)
- `slurp`, `grim`, `magick`, `wl-copy`, `busctl` (the countdown notification), `xdg-open`, `gdbus`
- files: it writes window captures into your screenshot folder, and **Delete** removes the previewed file. It makes
  no network requests.
