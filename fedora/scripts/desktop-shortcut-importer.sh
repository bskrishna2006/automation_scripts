#!/usr/bin/env bash

# Colour definitions
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Ensure executable
if [[ ! -x "$0" ]]; then
    echo -e "${YELLOW}Making script executable...${RESET}"
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

ensure_fzf() {
    if command -v fzf >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}fzf is not installed.${RESET}"
    read -rp "Do you want to install it now? (y/n): " ans

    if [[ "$ans" == "y" ]]; then
        if sudo dnf install -y fzf; then
            echo -e "${GREEN}fzf installed successfully.${RESET}"
            return 0
        else
            echo -e "${RED}Failed to install fzf. Falling back to other modes.${RESET}"
            return 1
        fi
    else
        echo -e "${YELLOW}Skipping fzf installation.${RESET}"
        return 1
    fi
}

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
    echo -e "${BLUE}Choose selection method:${RESET}"
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
        *) echo -e "${RED}Invalid option${RESET}"; menu ;;
    esac
}

fuzzy_mode() {
    if ! ensure_fzf; then
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
        echo -e "${YELLOW}No matches.${RESET}"
        return
    fi

    echo
    echo -e "${BLUE}Matches:${RESET}"
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
    echo -e "${BLUE}Available applications:${RESET}"
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
echo -e "${BLUE}========== Summary ==========${RESET}"
echo -e "Copied:  ${GREEN}${#copied[@]}${RESET}"
printf '  %s\n' "${copied[@]:-}"

echo
echo -e "Skipped: ${YELLOW}${#skipped[@]}${RESET}"
printf '  %s\n' "${skipped[@]:-}"

echo
echo -e "Failed:  ${RED}${#failed[@]}${RESET}"
printf '  %s\n' "${failed[@]:-}"
echo -e "${BLUE}=============================${RESET}"
