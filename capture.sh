#!/bin/sh
# capture.sh MODE DIR PATTERN [ACCENT [DELAY]]: take one screenshot and print its path.
#   MODE     region | screen (pick one output) | all (every output) | window
#   DIR      [shell.screenshot] directory ("" = XDG Pictures or ~/Pictures)
#   PATTERN  [shell.screenshot] filename_pattern ("" = Noctalia's default)
#   ACCENT   #rrggbb outlining the hovered monitor when picking a screen
#   DELAY    seconds to wait before capturing (default 0), counted after the
#            region, monitor or window is picked. A timed region is picked
#            with slurp and captured with grim instead of Noctalia's overlay.
#
# region/screen/all go through Noctalia's own capture, which saves (and copies)
# per [shell.screenshot] and is picked up as the newest file. `noctalia msg
# screenshot-region` returns as soon as its overlay opens, so region waits for
# that overlay to close: no file after that means it was cancelled.
# screen picks a monitor with slurp, dimming the others, then captures it by name.
# window clicks a window with niri, restores full opacity (niri bakes window
# rule opacity into captures), rounds the corners like on screen and adds a
# soft shadow, then saves and copies it the same way.
#
# Exit codes: 0 ok (stdout is the path), 10 cancelled, 11 nothing saved,
# 12 image processing failed, 2 bad arguments. Failures explain on stderr.
set -u

mode=${1:-}
dir=${2:-}
pattern=${3:-}
accent=${4:-#ffffff}
delay=${5:-0}
case $delay in
"" | *[!0-9]*) echo "capture.sh: DELAY must be a whole number of seconds" >&2; exit 2 ;;
esac

case $dir in
"") dir=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures") ;;
"~") dir=$HOME ;;
"~/"*) dir=$HOME/${dir#"~/"} ;;
esac
[ -n "$pattern" ] || pattern=screenshot_%Y%m%d_%H%M%S
mkdir -p "$dir"
tmp=${XDG_RUNTIME_DIR:-/tmp}/noctalia-snap
mkdir -p "$tmp"
marker=$tmp/started

# newest_saved: newest PNG in $dir written after the last `touch "$marker"`.
newest_saved() {
    find "$dir" -maxdepth 1 -type f -name '*.png' -newer "$marker" \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-
}

# wait_ready FILE: wait until FILE stops growing and decodes.
wait_ready() {
    prev= i=0
    while [ "$i" -lt 50 ]; do
        cur=$(stat -c %s "$1" 2>/dev/null || true)
        if [ -n "$cur" ] && [ "$cur" != 0 ] && [ "$cur" = "$prev" ] &&
            magick identify "$1" >/dev/null 2>&1; then
            return 0
        fi
        prev=$cur i=$((i + 1))
        sleep 0.1
    done
    return 1
}

# fail CODE MESSAGE: explain on stderr and exit.
fail() {
    printf '%s\n' "$2" >&2
    exit "$1"
}

# saved_file TRIES: print the capture saved since the marker, waiting up to
# TRIES tenths of a second for it to land.
saved_file() {
    i=0
    while [ "$i" -lt "$1" ]; do
        f=$(newest_saved)
        if [ -n "$f" ]; then
            wait_ready "$f" || fail 11 "$f was never fully written"
            printf '%s\n' "$f"
            return 0
        fi
        i=$((i + 1))
        sleep 0.1
    done
    return 1
}

# overlay_open: whether Noctalia's region or annotation overlay is on screen.
overlay_open() {
    niri msg -j layers 2>/dev/null | jq -e 'any(.[]; .namespace == "noctalia-screenshot-region"
        or .namespace == "noctalia-annotate")' >/dev/null
}

# wait_delay: sleep for the requested timer, if any.
wait_delay() {
    [ "$delay" -eq 0 ] || sleep "$delay"
}

# shell_capture ARGS...: run a non-interactive Noctalia capture and print the file.
shell_capture() {
    wait_delay
    # Let the picker panel finish closing so it isn't in the shot.
    sleep 0.3
    touch "$marker"
    why=$(noctalia msg "$@" 2>&1) || fail 11 "noctalia msg $*: $why"
    saved_file 50 || fail 11 "No screenshot appeared in $dir"
}

case $mode in
region)
    if [ "$delay" -gt 0 ]; then
        # Noctalia's overlay captures as soon as the drag ends, so a timed
        # region is picked with slurp, then captured with grim after the wait.
        sleep 0.3
        geom=$(slurp -d -b '#00000066' -c "$accent" -w 2) || exit 10
        [ -n "$geom" ] || exit 10
        wait_delay
        out=$dir/$(date "+$pattern").png
        grim -g "$geom" "$out" || fail 11 "grim couldn't capture $geom"
        wl-copy --type image/png <"$out" || true
        printf '%s\n' "$out"
        exit 0
    fi
    sleep 0.3
    touch "$marker"
    why=$(noctalia msg screenshot-region 2>&1) || fail 11 "noctalia msg screenshot-region: $why"
    # Wait for the overlay to show up, then for the user to finish with it.
    i=0
    while ! overlay_open && [ "$i" -lt 20 ]; do
        i=$((i + 1))
        sleep 0.1
    done
    while overlay_open; do
        sleep 0.1
    done
    saved_file 30 || exit 10
    ;;
screen)
    outputs=$(niri msg -j outputs | jq -r 'to_entries[] | select(.value.logical) | .key')
    if [ "$(printf '%s\n' "$outputs" | wc -l)" -le 1 ]; then
        name=$outputs
    else
        # Hovering a monitor clears its dimming and outlines it; Esc cancels.
        dim='#00000099'
        name=$(slurp -o -r -f '%o' -b "$dim" -B "$dim" -s '#00000000' -c "$accent" -w 6) || exit 10
    fi
    [ -n "$name" ] || exit 10
    shell_capture screenshot-fullscreen "$name"
    ;;
all) shell_capture screenshot-fullscreen all ;;
window)
    id=$(niri msg -j pick-window | jq -r '.id // empty')
    [ -n "$id" ] || exit 10
    wait_delay
    raw=$tmp/window.png
    rm -f "$raw"
    niri msg action screenshot-window --id "$id" --write-to-disk true --path "$raw" >/dev/null ||
        fail 11 "niri couldn't capture window $id"
    wait_ready "$raw" || fail 11 "niri never wrote $raw"
    out=$dir/$(date "+$pattern").png
    max=$(magick "$raw" -alpha extract -format '%[fx:maxima*100]' info:) || fail 12 "magick couldn't read $raw"
    size=$(magick "$raw" -format '%wx%h' info:) || fail 12 "magick couldn't read $raw"
    w=${size%x*} h=${size#*x}
    # Radius 16 matches geometry-corner-radius in the niri window rules.
    magick "$raw" -channel A -level "0,$max%" +channel \
        \( -size "$size" xc:none -fill white \
            -draw "roundrectangle 0,0 $((w - 1)),$((h - 1)) 16,16" \) \
        -compose DstIn -composite -compose Over \
        \( +clone -background black -shadow 50x30+0+22 \) +swap \
        -background none -layers merge +repage "$out" || fail 12 "magick couldn't write $out"
    wl-copy --type image/png <"$out" || true
    printf '%s\n' "$out"
    ;;
*)
    echo "usage: capture.sh region|screen|all|window DIR PATTERN [ACCENT [DELAY]]" >&2
    exit 2
    ;;
esac
