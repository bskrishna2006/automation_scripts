#!/usr/bin/env bash

set -e

# Colour definitions
BLUE="\033[0;34m"
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

scripts=(
    "desktop-shortcut-importer.sh"
    "kernel_manager.sh"
)

echo -e "${BLUE}Available scripts:${RESET}"
for i in "${!scripts[@]}"; do
    printf "[%d] %s\n" "$((i+1))" "${scripts[$i]}"
done

echo "[0] Exit"
read -rp "Select a script to run: " choice

if [[ "$choice" == "0" ]]; then
    exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Invalid input.${RESET}"
    exit 1
fi

idx=$((choice-1))

if (( idx < 0 || idx >= ${#scripts[@]} )); then
    echo -e "${RED}Invalid selection.${RESET}"
    exit 1
fi

script_path="$SCRIPTS_DIR/${scripts[$idx]}"

if [[ ! -f "$script_path" ]]; then
    echo -e "${RED}Script not found: $script_path${RESET}"
    exit 1
fi

if [[ ! -x "$script_path" ]]; then
    echo "Making $script_path executable..."
    chmod +x "$script_path"
fi

echo -e "${GREEN}Running ${scripts[$idx]}...${RESET}"
exec "$script_path"
