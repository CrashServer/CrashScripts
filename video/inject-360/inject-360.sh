#!/usr/bin/env bash
# inject-360 — inject (or check) 360° spherical metadata on an MP4 using
# Google's spatial-media tool. Self-installs on first run.
#
# Usage:
#   inject-360                          # interactive menu
#   inject-360 [options] INPUT [OUTPUT] # one-shot
#   inject-360 --check INPUT
#
# Options:
#   -s, --stereo MODE     Stereo mode: none | top-bottom | left-right (default: none)
#   -p, --projection TYPE Projection: equirectangular | none (default: equirectangular)
#   -f, --force           Overwrite OUTPUT if it exists
#   -c, --check           Only print the 360° metadata status of INPUT (no injection)
#   -I, --interactive     Force interactive menu (default when no INPUT given)
#       --update          Pull the latest spatial-media from GitHub before running
#   -h, --help            Show this help
#
# If OUTPUT is omitted, defaults to INPUT with "_360" appended before the extension.

set -euo pipefail

REPO_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/spatial-media"
VENV_DIR="$REPO_DIR/.venv"
REPO_URL="https://github.com/google/spatial-media.git"

die() { printf 'inject-360: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

ensure_install() {
    local need_update="${1:-0}"
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        command -v git >/dev/null || die "git is required (install with: sudo pacman -S git)"
        command -v python3 >/dev/null || die "python3 is required"
        mkdir -p "$(dirname "$REPO_DIR")"
        echo "installing spatial-media -> $REPO_DIR"
        git clone --depth 1 "$REPO_URL" "$REPO_DIR"
    elif [[ "$need_update" == "1" ]]; then
        echo "updating spatial-media"
        git -C "$REPO_DIR" pull --ff-only
    fi
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
        echo "creating venv -> $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi
    command -v ffmpeg >/dev/null || \
        echo "warning: ffmpeg not found — metadata checks need it (install with: sudo pacman -S ffmpeg)" >&2
}

# Clean a path the user might paste in: strip surrounding quotes, unescape
# backslash-escaped spaces, drop a leading file:// prefix (common from file
# managers / drag-and-drop), expand ~.
clean_path() {
    local p="$1"
    p="${p#\"}"; p="${p%\"}"
    p="${p#\'}"; p="${p%\'}"
    p="${p#file://}"
    p="${p//\\ / }"
    p="${p/#\~/$HOME}"
    printf '%s' "$p"
}

check_metadata() {
    local file="$1"
    [[ -f "$file" ]] || { echo "file not found: $file" >&2; return 2; }
    command -v ffmpeg >/dev/null || { echo "ffmpeg required for metadata check" >&2; return 2; }
    local out
    out=$(ffmpeg -i "$file" -t 0.1 -f null /dev/null 2>&1 || true)
    if grep -qi "Spherical Mapping" <<<"$out"; then
        echo "360° metadata: PRESENT"
        grep -i "Spherical Mapping\|Stereo 3D" <<<"$out" | sed 's/^ *//'
        return 0
    else
        echo "360° metadata: ABSENT"
        return 1
    fi
}

default_output_for() {
    local in="$1"
    local base="${in%.*}" ext="${in##*.}"
    [[ "$base" == "$in" ]] && printf '%s_360' "$in" || printf '%s_360.%s' "$base" "$ext"
}

do_inject() {
    local input="$1" output="$2" stereo="$3" projection="$4" force="$5"
    [[ -f "$input" ]] || { echo "input not found: $input" >&2; return 1; }
    [[ "$input" == "$output" ]] && { echo "input and output must differ" >&2; return 1; }
    if [[ -e "$output" && "$force" != "1" ]]; then
        echo "output exists: $output" >&2
        return 1
    fi
    case "$stereo" in none|top-bottom|left-right) ;; *) echo "invalid stereo: $stereo" >&2; return 1 ;; esac
    case "$projection" in equirectangular|none) ;; *) echo "invalid projection: $projection" >&2; return 1 ;; esac

    echo "injecting: projection=$projection stereo=$stereo"
    echo "  in : $input"
    echo "  out: $output"
    PYTHONPATH="$REPO_DIR" "$VENV_DIR/bin/python" -m spatialmedia -i \
        --stereo "$stereo" --projection "$projection" "$input" "$output"

    if command -v ffmpeg >/dev/null; then
        echo
        check_metadata "$output" || { echo "injection produced no metadata" >&2; return 1; }
    fi
}

# ------------------------------------------------------------------ interactive

prompt_input_file() {
    local path
    while true; do
        read -e -r -p "Video file (tab-completes, empty to cancel): " path || return 1
        [[ -z "$path" ]] && return 1
        path=$(clean_path "$path")
        if [[ -f "$path" ]]; then
            printf '%s' "$path"
            return 0
        fi
        echo "  not a file: $path" >&2
    done
}

prompt_output_file() {
    local default="$1" path
    read -e -r -p "Output file [$default]: " path || return 1
    path="${path:-$default}"
    path=$(clean_path "$path")
    printf '%s' "$path"
}

confirm() {
    local prompt="$1" reply
    read -r -p "$prompt [y/N] " reply || return 1
    [[ "$reply" =~ ^[Yy]$ ]]
}

interactive_loop() {
    printf '\n=== inject-360 interactive ===\n'
    while true; do
        printf '\n'
        local input
        input=$(prompt_input_file) || { echo "bye."; return 0; }

        printf '\n--- current status ---\n'
        if command -v ffmpeg >/dev/null; then
            check_metadata "$input" || true
        else
            echo "(ffmpeg missing — skipping metadata check)"
        fi

        printf '\n--- action ---\n'
        local action=""
        select action in \
            "Inject: equirectangular, mono (most common)" \
            "Inject: equirectangular, stereo top-bottom" \
            "Inject: equirectangular, stereo left-right" \
            "Inject: custom (pick projection + stereo)" \
            "Check metadata only (done)" \
            "Pick a different file" \
            "Quit"
        do
            [[ -n "$action" ]] && break
            echo "  pick a number from the list."
        done
        [[ -z "$action" ]] && { echo "bye."; return 0; }

        local stereo="none" projection="equirectangular"
        case "$action" in
            "Inject: equirectangular, mono (most common)") ;;
            "Inject: equirectangular, stereo top-bottom") stereo="top-bottom" ;;
            "Inject: equirectangular, stereo left-right") stereo="left-right" ;;
            "Inject: custom (pick projection + stereo)")
                local p="" s=""
                echo "Projection:"
                select p in equirectangular none; do [[ -n "$p" ]] && { projection="$p"; break; }; done
                [[ -z "$p" ]] && continue
                echo "Stereo mode:"
                select s in none top-bottom left-right; do [[ -n "$s" ]] && { stereo="$s"; break; }; done
                [[ -z "$s" ]] && continue
                ;;
            "Check metadata only (done)") continue ;;
            "Pick a different file") continue ;;
            "Quit") echo "bye."; return 0 ;;
        esac

        local default_out
        default_out=$(default_output_for "$input")
        local output
        output=$(prompt_output_file "$default_out") || continue

        local force=0
        if [[ -e "$output" ]]; then
            if confirm "Output exists. Overwrite?"; then force=1; else continue; fi
        fi

        printf '\n'
        if do_inject "$input" "$output" "$stereo" "$projection" "$force"; then
            echo
            echo "done -> $output"
        else
            echo
            echo "failed."
        fi
    done
}

# ----------------------------------------------------------------- arg parsing

STEREO="none"
PROJECTION="equirectangular"
FORCE=0
CHECK=0
UPDATE=0
INTERACTIVE=0
POSITIONAL=()

while (( $# )); do
    case "$1" in
        -s|--stereo)      STEREO="${2:?}"; shift 2 ;;
        -p|--projection)  PROJECTION="${2:?}"; shift 2 ;;
        -f|--force)       FORCE=1; shift ;;
        -c|--check)       CHECK=1; shift ;;
        -I|--interactive) INTERACTIVE=1; shift ;;
        --update)         UPDATE=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        --) shift; POSITIONAL+=("$@"); break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *)  POSITIONAL+=("$1"); shift ;;
    esac
done

if (( INTERACTIVE )) || (( ${#POSITIONAL[@]} == 0 )); then
    ensure_install "$UPDATE"
    interactive_loop
    exit 0
fi

INPUT=$(clean_path "${POSITIONAL[0]}")
[[ -f "$INPUT" ]] || die "input not found: $INPUT"

ensure_install "$UPDATE"

if (( CHECK )); then
    check_metadata "$INPUT"
    exit $?
fi

if (( ${#POSITIONAL[@]} >= 2 )); then
    OUTPUT=$(clean_path "${POSITIONAL[1]}")
else
    OUTPUT=$(default_output_for "$INPUT")
fi

do_inject "$INPUT" "$OUTPUT" "$STEREO" "$PROJECTION" "$FORCE"
