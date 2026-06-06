#!/usr/bin/env bash
set -u

dry_run=0
target_dir=""
moved=0
skipped=0
errors=0

usage() {
    printf 'Usage: %s [--dry-run|-n] [folder]\n' "$0"
    printf 'Sorts files into Images, Documents, Videos, Music, Archives, Installers, Torrents, Code, and Others.\n'
}

default_downloads_dir() {
    if [ -z "${HOME:-}" ]; then
        return 1
    fi
    printf '%s/Downloads\n' "$HOME"
}

category_for_extension() {
    ext=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        .jpg|.jpeg|.png|.gif|.bmp|.webp|.svg|.heic)
            printf 'Images' ;;
        .txt|.pdf|.doc|.docx|.xls|.xlsx|.ppt|.pptx|.md|.rtf|.csv|.html|.htm)
            printf 'Documents' ;;
        .mp4|.mkv|.mov|.avi|.webm|.wmv|.flv)
            printf 'Videos' ;;
        .mp3|.wav|.flac|.aac|.ogg|.m4a)
            printf 'Music' ;;
        .zip|.rar|.7z|.tar|.gz|.xz|.bz2)
            printf 'Archives' ;;
        .exe|.msi|.pkg|.dmg|.deb|.rpm|.apk|.appimage|.msixbundle)
            printf 'Installers' ;;
        .torrent)
            printf 'Torrents' ;;
        .c|.h|.cpp|.hpp|.py|.js|.ts|.java|.cs|.go|.rs|.swift|.json|.xml|.ini|.yaml|.yml)
            printf 'Code' ;;
        *)
            printf 'Others' ;;
    esac
}

extension_of() {
    name=$1
    base=${name##*/}

    case "$base" in
        .*|*.)
            printf '' ;;
        *.*)
            printf '.%s' "${base##*.}" ;;
        *)
            printf '' ;;
    esac
}

unique_destination() {
    dir=$1
    name=$2
    destination=$dir/$name

    if [ ! -e "$destination" ]; then
        printf '%s\n' "$destination"
        return 0
    fi

    ext=$(extension_of "$name")
    if [ -n "$ext" ]; then
        base=${name%"$ext"}
    else
        base=$name
    fi

    i=1
    while [ "$i" -lt 10000 ]; do
        candidate=$dir/$base' ('"$i"')'$ext
        if [ ! -e "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        i=$((i + 1))
    done

    return 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run|-n)
            dry_run=1 ;;
        --help|-h)
            usage
            exit 0 ;;
        *)
            if [ -z "$target_dir" ]; then
                target_dir=$1
            else
                printf 'Unexpected argument: %s\n' "$1" >&2
                usage >&2
                exit 1
            fi ;;
    esac
    shift
done

if [ -z "$target_dir" ]; then
    if ! target_dir=$(default_downloads_dir); then
        printf 'Could not find your Downloads folder. Pass a folder path explicitly.\n' >&2
        exit 1
    fi
fi

if [ ! -d "$target_dir" ]; then
    printf "Could not open folder '%s'\n" "$target_dir" >&2
    exit 1
fi

target_dir=${target_dir%/}
if [ "$dry_run" -eq 1 ]; then
    printf 'Previewing %s\n' "$target_dir"
else
    printf 'Sorting %s\n' "$target_dir"
fi

while IFS= read -r path; do
    name=${path##*/}

    if [ ! -f "$path" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    ext=$(extension_of "$name")
    category=$(category_for_extension "$ext")
    category_dir=$target_dir/$category

    if [ "$dry_run" -eq 0 ] && ! mkdir -p "$category_dir"; then
        printf "Could not create folder '%s'\n" "$category_dir" >&2
        errors=$((errors + 1))
        continue
    fi

    if ! destination=$(unique_destination "$category_dir" "$name"); then
        printf "Could not build destination for '%s'\n" "$name" >&2
        errors=$((errors + 1))
        continue
    fi

    if [ "$dry_run" -eq 1 ]; then
        printf 'Would move %s -> %s\n' "$name" "$category"
    else
        printf 'Moving %s -> %s\n' "$name" "$category"
        if ! mv -- "$path" "$destination" 2>/dev/null; then
            if ! mv "$path" "$destination"; then
                printf "Could not move '%s'\n" "$name" >&2
                errors=$((errors + 1))
                continue
            fi
        fi
    fi

    moved=$((moved + 1))
done < <(find "$target_dir" -mindepth 1 -maxdepth 1 -print)

printf '\nDone. '
if [ "$dry_run" -eq 1 ]; then
    printf 'would move'
else
    printf 'moved'
fi
printf ': %s, skipped: %s, errors: %s\n' "$moved" "$skipped" "$errors"

if [ "$errors" -gt 0 ]; then
    exit 1
fi
