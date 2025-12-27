#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="/usr/share/applications"
DEST_DIR="$HOME/Desktop"

# 1. Get and sort .desktop files
mapfile -t files < <(find "$SRC_DIR" -maxdepth 1 -type f -name "*.desktop" | sort -V)

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No .desktop files found."
    exit 1
fi

echo "Available applications:"
echo "------------------------"
for i in "${!files[@]}"; do
    printf "[%d] %s\n" "$((i+1))" "$(basename "${files[$i]}")"
done
echo "------------------------"

# 2. User input
read -rp "Enter numbers to copy (comma separated): " input

IFS=',' read -ra selections <<< "$input"

copied=()
skipped=()
failed=()

# 3. Process each selection
for sel in "${selections[@]}"; do
    sel="$(echo "$sel" | xargs)"  # trim spaces

    if ! [[ "$sel" =~ ^[0-9]+$ ]]; then
        failed+=("$sel (invalid index)")
        continue
    fi

    idx=$((sel-1))

    if (( idx < 0 || idx >= ${#files[@]} )); then
        failed+=("$sel (out of range)")
        continue
    fi

    src="${files[$idx]}"
    dest="$DEST_DIR/$(basename "$src")"

    # 5. Handle conflicts
    if [[ -e "$dest" ]]; then
        skipped+=("$(basename "$src") (already exists)")
        continue
    fi

    # 3. Copy
    if cp "$src" "$dest"; then
        copied+=("$(basename "$src")")
    else
        failed+=("$(basename "$src") (copy failed)")
    fi
done

# 6. chmod +x
for f in "${copied[@]}"; do
    chmod +x "$DEST_DIR/$f" || failed+=("$f (chmod failed)")
done

# 7. Mark trusted
for f in "${copied[@]}"; do
    gio set "$DEST_DIR/$f" metadata::trusted true || failed+=("$f (gio trust failed)")
done

# 4 & 5. Summary
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
