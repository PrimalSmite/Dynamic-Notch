#!/usr/bin/env sh
# Low-memory launcher for dynamic-notch Quickshell config.
# - QSG_RENDER_LOOP=basic: share a single render thread/GL context across windows
# - MALLOC_ARENA_MAX=2: limit per-thread glibc heap arenas
# - GLIBC_TUNABLES=glibc.malloc.hugetlb=0: disable 2MB THP bloat in malloc

DIR="$(cd "$(dirname "$0")/.." && pwd)"

export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-basic}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export GLIBC_TUNABLES="${GLIBC_TUNABLES:-glibc.malloc.hugetlb=0}"

exec qs -p "$DIR" "$@"
