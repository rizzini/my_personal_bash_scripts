#!/bin/bash
# script it not detecting ppp0 activity at the moment
if [[ "$1" == "loop" && -z "$2" ]]; then
    loop_mode=1
    shopt -s nullglob 2>/dev/null
    ttymods=(/dev/ttyUSB*)
    if ((${#ttymods[@]} > 0)); then
        if ip link show ppp0 >/dev/null 2>&1; then
            interface="ppp0"
        else
            first_ppp=$(ls /sys/class/net 2>/dev/null | grep '^ppp' | head -n1 )
            if [[ -n "$first_ppp" ]]; then
                interface="$first_ppp"
            else
                interface=""
            fi
        fi
    else
        interface=$(awk -F: 'NR>2 { gsub(/^ +| +$/, "", $1); if ($1 != "lo") print $1 }' /proc/net/dev | head -n1)
    fi
else
    interface="${1:-}"
    if [[ -z "$interface" || "$interface" == "loop" ]]; then
        shopt -s nullglob 2>/dev/null
        ttymods=(/dev/ttyUSB*)
        if ((${#ttymods[@]} > 0)); then
            if ip link show ppp0 >/dev/null 2>&1; then
                interface="ppp0"
            else
                first_ppp=$(ls /sys/class/net 2>/dev/null | grep '^ppp' | head -n1 )
                if [[ -n "$first_ppp" ]]; then
                    interface="$first_ppp"
                else
                    interface=""
                fi
            fi
        else
            interface=$(awk -F: 'NR>2 { gsub(/^ +| +$/, "", $1); if ($1 != "lo") print $1 }' /proc/net/dev | head -n1)
        fi
    fi
    loop_mode=0
    if [[ "$2" == "loop" ]]; then
        loop_mode=1
    fi
fi
interface=enp1s0
unit_mode=2
if [[ "$2" == "loop" ]]; then
    loop_mode=1
fi

get_data() {
    local iface="$1"
    while IFS= read -r line; do
        dev="${line%%:*}"
        dev="${dev// /}"
        if [[ "$dev" == "$iface" ]]; then
            data="${line#*:}"
            read -ra fields <<< "$data"
            rx="${fields[0]}"
            tx="${fields[8]}"
            echo "$rx $tx"
            return
        fi
    done < /proc/net/dev
}

convert_units() {
    local bytes=$1
    local value unit
    case "$unit_mode" in
        1)
            value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024 }")
            unit="KB/s"
            ;;
        2)
            value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024/1024 }")
            unit="MB/s"
            ;;
        3)
            if (( bytes >= 1024*1024 )); then
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024/1024 }")
                unit="MB/s"
            else
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024 }")
                unit="KB/s"
            fi
            ;;
        *)
            if (( bytes >= 1024*1024 )); then
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024/1024 }")
                unit="MB/s"
            else
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024 }")
                unit="KB/s"
            fi
            ;;
    esac
    echo "${value}${unit}"
}

colorize_speed() {
    local speed_str="$1"
    local color_reset="\e[0m"
    local color_green="\e[92m"
    local color_yellow="\e[93m"
    local color_red="\e[91m"
    local value
    value=$(echo "$speed_str" | awk -F'MB/s' '{print $1}')
    value=$(echo "$value" | tr ',' '.' | xargs)
    if (( $(echo "$value >= 2 && $value <= 10" | bc -l) )); then
        echo -e "${color_green}${speed_str}${color_reset}"
    elif (( $(echo "$value >= 10 && $value <= 30" | bc -l) )); then
        echo -e "${color_yellow}${speed_str}${color_reset}"
    elif (( $(echo "$value > 30" | bc -l) )); then
        echo -e "${color_red}${speed_str}${color_reset}"
    else
        echo "$speed_str"
    fi
}

main() {
    IFS=' ' read -r rx1 tx1 <<< "$(get_data "$interface")"
    sleep 1
    IFS=' ' read -r rx2 tx2 <<< "$(get_data "$interface")"
    rx_original=$((rx2 - rx1))
    tx_original=$((tx2 - tx1))
    rx_converted=$(convert_units "$rx_original")
    tx_converted=$(convert_units "$tx_original")
    if [[ "$unit_mode" -eq 2 || "$unit_mode" -eq 3 ]]; then
        if [[ "$rx_converted" == *"MB/s" ]]; then
            rx_converted=$(colorize_speed "$rx_converted")
        fi
        if [[ "$tx_converted" == *"MB/s" ]]; then
            tx_converted=$(colorize_speed "$tx_converted")
        fi
    fi
    echo -e " $rx_converted |  $tx_converted"
}

if [[ "$loop_mode" -eq 1 ]]; then
    while true; do
        main
        sleep 1
    done
else
    main
fi
