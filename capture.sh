#!/bin/sh
# capture.sh MODE DIR PATTERN: take one screenshot and print its path.
#   MODE     region | screen (pick one output) | all (every output) | window
#   DIR      [shell.screenshot] directory ("" = XDG Pictures or ~/Pictures)
#   PATTERN  [shell.screenshot] filename_pattern ("" = Noctalia's default)
#
# region/screen/all go through Noctalia's own capture, which saves (and copies)
# per [shell.screenshot]; `noctalia msg` prints "ok" once the capture is taken
# and the file lands shortly after, so it's picked up as the newest file.
# window clicks a window with niri, restores full opacity (niri bakes window
# rule opacity into captures), rounds the corners like on screen and adds a
# soft shadow, then saves and copies it the same way.
#
# Exit codes: 0 ok (stdout is the path), 10 cancelled, 11 nothing saved,
# 12 image processing failed, 2 bad arguments.
set -u

mode=${1:-}
dir=${2:-}
pattern=${3:-}

case $dir in
"") dir=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures") ;;
"~") dir=$HOME ;;
"~/"*) dir=$HOME/${dir#"~/"} ;;
esac
[ -n "$pattern" ] || pattern=screenshot_%Y%m%d_%H%M%S
mkdir -p "$dir"

# newest_since START: newest file in $dir modified at or after START - 1s.
newest_since() {
    find "$dir" -maxdepth 1 -type f -name '*.png' -newermt "@$(($1 - 1))" \
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

# shell_capture ARGS...: run a Noctalia capture and print the saved file.
shell_capture() {
    # Let the picker panel finish closing so it isn't in the shot.
    sleep 0.3
    start=$(date +%s)
    noctalia msg "$@" >/dev/null 2>&1 || exit 10
    i=0
    while [ "$i" -lt 50 ]; do
        f=$(newest_since "$start")
        if [ -n "$f" ]; then
            wait_ready "$f" || exit 11
            printf '%s\n' "$f"
            exit 0
        fi
        i=$((i + 1))
        sleep 0.1
    done
    exit 11
}

case $mode in
region) shell_capture screenshot-region ;;
screen) shell_capture screenshot-fullscreen pick ;;
all) shell_capture screenshot-fullscreen all ;;
window)
    id=$(niri msg -j pick-window | jq -r '.id // empty')
    [ -n "$id" ] || exit 10
    tmp=${XDG_RUNTIME_DIR:-/tmp}/noctalia-snap
    mkdir -p "$tmp"
    raw=$tmp/window.png
    rm -f "$raw"
    niri msg action screenshot-window --id "$id" --write-to-disk true --path "$raw" >/dev/null || exit 11
    wait_ready "$raw" || exit 11
    out=$dir/$(date "+$pattern").png
    max=$(magick "$raw" -alpha extract -format '%[fx:maxima*100]' info:) || exit 12
    size=$(magick "$raw" -format '%wx%h' info:) || exit 12
    w=${size%x*} h=${size#*x}
    # Radius 16 matches geometry-corner-radius in the niri window rules.
    magick "$raw" -channel A -level "0,$max%" +channel \
        \( -size "$size" xc:none -fill white \
            -draw "roundrectangle 0,0 $((w - 1)),$((h - 1)) 16,16" \) \
        -compose DstIn -composite -compose Over \
        \( +clone -background black -shadow 50x30+0+22 \) +swap \
        -background none -layers merge +repage "$out" || exit 12
    wl-copy --type image/png <"$out" || true
    printf '%s\n' "$out"
    ;;
*)
    echo "usage: capture.sh region|screen|all|window DIR PATTERN" >&2
    exit 2
    ;;
esac
