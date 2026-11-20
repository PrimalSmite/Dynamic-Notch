#!/bin/sh
MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"
export MAGICK_CONFIGURE_PATH

# Warm cache of clipboard-image thumbnails, driven by Clipboard.qml on every
# clipboard change. Only image entries get a thumbnail (named by cliphist id);
# missing ones are decoded through the ImageMagick decode cage
# (MAGICK_CONFIGURE_PATH above — clipboard bytes are untrusted input), and
# thumbs whose source entry no longer exists are pruned.
command -v cliphist >/dev/null 2>&1 || exit 0

IM_CMD=""
if command -v magick >/dev/null 2>&1; then
    IM_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
    IM_CMD="convert"
else
    exit 0
fi

cache="${XDG_CACHE_HOME:-$HOME/.cache}/dynamic-notch/cliphist-thumbs"
mkdir -p "$cache"

# One cliphist list snapshot drives both passes, so a refresh never prunes and
# regenerates against two different states.
list="$(cliphist list 2>/dev/null)"

ids="$(mktemp)"
have="$(mktemp)"
trap 'rm -f "$ids" "$have"' EXIT INT TERM

# Only prune when the snapshot actually has entries: an empty list here means
# cliphist hiccuped mid-refresh (or history is empty). Guard on non-empty $list
# because printf '%s\n' "" still writes 1 byte.
if [ -n "$list" ]; then
    printf '%s\n' "$list" | cut -f1 | LC_ALL=C sort -u > "$ids"
    find "$cache" -maxdepth 1 -type f -name '*.png' -exec basename {} .png \; \
        | LC_ALL=C sort -u > "$have"
    comm -23 "$have" "$ids" | while IFS= read -r id; do
        [ -n "$id" ] && rm -f "$cache/$id.png"
    done
fi

[ -n "$list" ] || exit 0

printf '%s\n' "$list" | awk -F '\t' '/\[\[ binary data / && /(png|jpg|jpeg|gif|bmp|webp)/ {print $1}' | while IFS= read -r id; do
    thumb="$cache/$id.png"
    [ -s "$thumb" ] && continue
    if cliphist decode "$id" 2>/dev/null | "$IM_CMD" - -strip -resize 128x128 "png:$thumb.tmp" 2>/dev/null; then
        if [ -s "$thumb.tmp" ]; then
            mv "$thumb.tmp" "$thumb"
        else
            rm -f "$thumb.tmp"
        fi
    else
        rm -f "$thumb.tmp"
    fi
done