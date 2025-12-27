#!/usr/bin/env bash

# Ensure executable
if [[ ! -x "$0" ]]; then
    echo "Making script executable..."
    chmod +x "$0"
    exec "$0" "$@"
fi

set -euo pipefail

SRC_DIR="/usr/share/applications"
DEST_DIR="$HOME/Desktop"

mapfile -t ALL_FILES < <(find "$SRC_DIR" -maxdepth 1 -type f -name "*.desktop" | sort -V)

copied=()
skipped=()
failed=()

copy_and_trust() {
    local src="$1"
    local dest="$DEST_DIR/$(basename "$src")"

    if [[ -e "$dest" ]]; then
        skipped+=("$(basename "$src") (already exists)")
        return
    fi

    if cp "$src" "$dest"; then
        chmod +x "$dest" || failed+=("$(basename "$src") (chmod failed)")
        gio set "$dest" metadata::trusted true || failed+=("$(basename "$src") (gio trust failed)")
        copied+=("$(basename "$src")")
    else
        failed+=("$(basename "$src") (copy failed)")
    fi
}

menu() {
    echo
    echo "Choose selection method:"
    echo "1) Fuzzy search (fzf)"
    echo "2) Search by name (grep)"
    echo "3) List all and select by number"
    echo "4) Exit"
    read -rp "> " choice

    case "$choice" in
        1) fuzzy_mode ;;
        2) grep_mode ;;
        3) list_mode ;;
        4) exit 0 ;;
        *) echo "Invalid option"; menu ;;
    esac
}

fuzzy_mode() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf not installed. Install with: sudo dnf install fzf"
        return
    fi

    local selected
    selected=$(printf '%s\n' "${ALL_FILES[@]}" | fzf --multi --prompt="Select apps > ")

    [[ -z "$selected" ]] && return

    while IFS= read -r file; do
        copy_and_trust "$file"
    done <<< "$selected"
}

grep_mode() {
    read -rp "Enter search term: " term

    mapfile -t matches < <(printf '%s\n' "${ALL_FILES[@]}" | grep -i "$term" || true)

    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "No matches."
        return
    fi

    echo
    echo "Matches:"
    for i in "${!matches[@]}"; do
        printf "[%d] %s\n" "$((i+1))" "$(basename "${matches[$i]}")"
    done

    read -rp "Copy all these? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    for f in "${matches[@]}"; do
        copy_and_trust "$f"
    done
}

list_mode() {
    echo
    echo "Available applications:"
    for i in "${!ALL_FILES[@]}"; do
        printf "[%d] %s\n" "$((i+1))" "$(basename "${ALL_FILES[$i]}")"
    done

    read -rp "Enter numbers (comma separated): " input
    IFS=',' read -ra nums <<< "$input"

    for n in "${nums[@]}"; do
        n="$(echo "$n" | xargs)"

        if ! [[ "$n" =~ ^[0-9]+$ ]]; then
            failed+=("$n (invalid)")
            continue
        fi

        idx=$((n-1))
        if (( idx < 0 || idx >= ${#ALL_FILES[@]} )); then
            failed+=("$n (out of range)")
            continue
        fi

        copy_and_trust "${ALL_FILES[$idx]}"
    done
}

menu

echo
echo "========== Summary =========="
echo "Copied:  ${#copied[@]}"
printf '  %s\n' "${copied[@]:-}"

echo
echo "Skipped: ${#skipped[@]}"
printf '  %s\n' "${skipped[@]:-}"

echo
echo "Failed:  ${#failed[@]}"
printf '  %s\n' "${failed[@]:-}"
echo "============================="
