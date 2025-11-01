#!/bin/bash
swaps=$(< /proc/swaps)
enable_zram() {
    swapoff -a
    echo 0 > /sys/module/zswap/parameters/enabled
    if ! lsmod | grep -q "^zram"; then
        sleep 1
        modprobe zram num_devices=1 max_comp_streams=4
        sleep 1
    fi
#   echo /dev/sda8 > /sys/block/zram0/backing_dev
    echo lzo > /sys/block/zram0/comp_algorithm
    echo 6G > /sys/block/zram0/disksize
    mkswap -U clear /dev/zram0
    swapon --discard --priority 100 /dev/zram0
    sysctl -w vm.watermark_boost_factor=0 vm.watermark_scale_factor=125 vm.page-cluster=0 vm.swappiness=180
    swapon --priority 10 /dev/sda8
    sysctl vm.swappiness=10
}
disable_zram() {
    sysctl vm.swappiness=60

    can_disable_zram
    if ! (( mem_available_kb + other_swap_free_kb >= zram_used_kb )); then
        notify-send -u critical "Refusing to disable zram" "Not enough memory/swap to relocate ${zram_used_kb} KB from zram.\nMemAvailable=${mem_available_kb} KB, other swap free=${other_swap_free_kb} KB"
        return 1
    fi

    for s in $(awk 'NR>1 {print $1}' /proc/swaps); do
        swapoff "$s" || { notify-send -u critical "Failed to swapoff $s"; return 1; }
    done

    echo 1 > /sys/module/zswap/parameters/enabled
    while ! modprobe -r zram; do
        sleep 1;
    done
}


can_disable_zram() {
    mem_available_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
    if [ -z "$mem_available_kb" ]; then
        mem_free=$(awk '/MemFree:/ {print $2}' /proc/meminfo)
        buffers=$(awk '/Buffers:/ {print $2}' /proc/meminfo)
        cached=$(awk '/Cached:/ {print $2}' /proc/meminfo)
        sreclaimable=$(awk '/SReclaimable:/ {print $2}' /proc/meminfo)
        mem_available_kb=$((mem_free + buffers + cached + sreclaimable))
    fi

    other_swap_free_kb=0
    zram_used_kb=0
    while read -r name type size used pr; do
        if [[ "$name" == /dev/zram* ]]; then
            zram_used_kb=$((zram_used_kb + used))
        else
            other_swap_free_kb=$((other_swap_free_kb + (size - used)))
        fi
    done < <(tail -n +2 /proc/swaps)
}
if [ "$1" == 'click' ]; then
    if [[ "$swaps" != *"/dev/zram0"* ]]; then
        enable_zram
        exit
    else
        disable_zram
        exit
    fi

elif [ "$1" == 'startup' ]; then
    enable_zram
    exit
fi
adjust_unit() {
    local scale=1024
    local units=("KB" "MB" "GB")
    local unit=0
    local value=${1:-0}
    local original_value=$value
    while (( value >= scale && unit < ${#units[@]} - 1 )); do
        value=$((value / scale))
        ((unit++))
    done

    if [[ "${units[unit]}" == "GB" ]]; then
        value_gb=$(echo "scale=2; $original_value / ($scale ^ $unit)" | bc)
        echo -e "\e[91m${value_gb}${units[unit]}\e[0m"
    else
        echo "${value}${units[unit]}"
    fi
}
while read -r key val _; do
    case "$key" in
        "MemTotal:") mem_total=$val ;;
        "MemFree:") mem_free=$val ;;
        "Buffers:") buffers=$val ;;
        "Cached:") cached=$val ;;
        "SReclaimable:") sreclaimable=$val ;;
        "Shmem:") shmem=$val ;;
    esac
done < /proc/meminfo
swap_used_zram_total=0
swap_used_disk_total=0
while read -r name _ _ used _; do
    if [[ "$name" == /dev/zram* ]]; then
        swap_used_zram_total=$((swap_used_zram_total + used))
    else
        swap_used_disk_total=$((swap_used_disk_total + used))
    fi
done < /proc/swaps
mem_used=$((mem_total - mem_free - buffers - cached - sreclaimable + shmem))
mem_used_mb=$((mem_used / 1024))
if ((mem_used_mb >= 1024)); then
    mem_used_gb=$(echo "scale=2; $mem_used_mb / 1024" | bc)
    if (( $(echo "$mem_used_gb > 5" | bc -l) )); then
        mem_used_gb_colored="\e[91m${mem_used_gb}GB\e[0m"
    else
        mem_used_gb_colored="${mem_used_gb}GB"
    fi
else
    mem_used_gb_colored="${mem_used_mb}MB"
fi
output="Mem: $mem_used_gb_colored"
if [[ "$swaps" == *"/dev/zram0"* ]]; then
    output="$output / ZRAM: $(adjust_unit "$swap_used_zram_total")"
    if (( swap_used_disk_total > 0 )); then
        output="$output / Disco: $(adjust_unit "$swap_used_disk_total")"
    fi
else
    output="$output / \e[91mOFF\e[0m"
fi
printf "%b\n" "$output"
