#!/usr/bin/env bash

set -e

echo "Installed kernels:"
echo "-------------------------------------"

mapfile -t kernels < <(rpm -q kernel | sort -V)

current_kernel="$(uname -r)"

i=1
for k in "${kernels[@]}"; do
    if [[ "$k" == *"$current_kernel"* ]]; then
        echo "[$i] $k  ← currently running"
    else
        echo "[$i] $k"
    fi
    ((i++))
done

echo "-------------------------------------"
echo "Current kernel: $current_kernel"
echo ""

echo "Choose an option:"
echo "1) Remove kernel by serial number"
echo "2) Auto-remove old kernels (keep latest + current)"
echo "3) Exit"
read -rp "Enter choice [1-3]: " choice

case "$choice" in

1)
    read -rp "Enter serial number of kernel to remove: " num
    idx=$((num - 1))

    if [[ -z "${kernels[$idx]}" ]]; then
        echo "Invalid selection."
        exit 1
    fi

    if [[ "${kernels[$idx]}" == *"$current_kernel"* ]]; then
        echo "You cannot remove the currently running kernel!"
        exit 1
    fi

    echo "Removing ${kernels[$idx]}..."
    sudo dnf remove -y "${kernels[$idx]}"
    ;;

2)
    read -rp "How many latest kernels do you want to keep (excluding current)? [default=1]: " keep
    keep=${keep:-1}

    echo "Keeping:"
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

    echo "Will keep:"
    printf "  %s\n" "${keep_list[@]}"
    echo ""

    for k in "${sorted[@]}"; do
        if [[ ! " ${keep_list[*]} " =~ " $k " ]]; then
            echo "Removing $k..."
            sudo dnf remove -y "$k"
        fi
    done
    ;;

*)
    echo "Removed Successfully"
    exit 0
    ;;
esac

echo "Done."
