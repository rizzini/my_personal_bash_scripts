#!/bin/bash
swaps=$(< /proc/swaps)
enable_zram() {
    swapoff -a
    echo 0 > /sys/module/zswap/parameters/enabled
    if ! lsmod | grep -q "^zram"; then
        sleep 1
        modprobe zram
        sleep 1
    fi
#   echo /dev/sda8 > /sys/block/zram0/backing_dev
    echo lzo > /sys/block/zram0/comp_algorithm
    echo 6G > /sys/block/zram0/disksize
    mkswap -U clear /dev/zram0
    swapon --discard --priority 100 /dev/zram0
    sysctl -w vm.watermark_boost_factor=0 vm.watermark_scale_factor=125 vm.page-cluster=0 vm.swappiness=180
    swapon --priority 0 /dev/sda8
}
disable_zram() {
    swapoff -a
    echo 1 > /sys/module/zswap/parameters/enabled
    while ! modprobe -r zram; do
        sleep 1;
    done
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
while read -r name _ _ used _; do
    if [[ "$name" == /dev/zram* ]]; then
        swap_used_zram_total=$((swap_used_zram_total + used))
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
case "$swaps" in
    *"/dev/zram0"*) printf "Mem: %b / ZRAM: %s\n" "$mem_used_gb_colored" "$(adjust_unit "$swap_used_zram_total")" ;;
    *) printf "Mem: %b / \e[91mOFF\e[0m\n" "$mem_used_gb_colored" ;;
esac
