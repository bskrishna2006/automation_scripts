#!/usr/bin/env bash

set -e

# Colour definitions
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

echo -e "${BLUE}Installed kernels:${RESET}"
echo "-------------------------------------"

mapfile -t kernels < <(rpm -q kernel | sort -V)

current_kernel="$(uname -r)"

i=1
for k in "${kernels[@]}"; do
    if [[ "$k" == *"$current_kernel"* ]]; then
        echo -e "[${i}] ${GREEN}${k}${RESET}  (currently running)"
    else
        echo "[${i}] $k"
    fi
    ((i++))
done

echo "-------------------------------------"
echo -e "Current kernel: ${GREEN}$current_kernel${RESET}"
echo ""

echo "Choose an option:"
echo "1) Remove kernel by serial number"
echo "2) Auto-remove old kernels (keep latest + current)"
echo "3) Exit"
read -rp "Enter choice [1-3]: " choice

case "$choice" in

1)
    if [[ ${#kernels[@]} -le 1 ]]; then
        echo -e "${YELLOW}Only one kernel is installed. Nothing to remove.${RESET}"
        exit 0
    fi

    read -rp "Enter serial number of kernel to remove: " num
    idx=$((num - 1))

    if [[ -z "${kernels[$idx]}" ]]; then
        echo -e "${RED}Invalid selection.${RESET}"
        exit 1
    fi

    if [[ "${kernels[$idx]}" == *"$current_kernel"* ]]; then
        echo -e "${RED}You cannot remove the currently running kernel.${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}Removing ${kernels[$idx]}...${RESET}"
    sudo dnf remove -y "${kernels[$idx]}"
    echo -e "${GREEN}Removal completed.${RESET}"
    ;;

2)
    read -rp "How many latest kernels do you want to keep (excluding current)? [default=1]: " keep
    keep=${keep:-1}

    echo -e "${BLUE}Keeping:${RESET}"
    echo " - Current kernel"
    echo " - Latest $keep kernel(s)"
    echo ""

    # Build list of kernels to keep
    mapfile -t sorted < <(printf "%s\n" "${kernels[@]}" | sort -V)

    keep_list=()

    # Add current kernel
    for k in "${sorted[@]}"; do
        [[ "$k" == *"$current_kernel"* ]] && keep_list+=("$k")
    done

    # Add latest N kernels
    for ((i=${#sorted[@]}-1; i>=0 && ${#keep_list[@]}<$((keep+1)); i--)); do
        [[ ! " ${keep_list[*]} " =~ " ${sorted[$i]} " ]] && keep_list+=("${sorted[$i]}")
    done

    echo -e "${BLUE}Will keep:${RESET}"
    printf "  %s\n" "${keep_list[@]}"
    echo ""

    for k in "${sorted[@]}"; do
        if [[ ! " ${keep_list[*]} " =~ " $k " ]]; then
            echo -e "${YELLOW}Removing $k...${RESET}"
            sudo dnf remove -y "$k"
        fi
    done

    echo -e "${GREEN}Auto-clean completed.${RESET}"
    ;;

*)
    echo -e "${BLUE}Exit selected. No changes made.${RESET}"
    exit 0
    ;;
esac

echo -e "${GREEN}Done.${RESET}"
