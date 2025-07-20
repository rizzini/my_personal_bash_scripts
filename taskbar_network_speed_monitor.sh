#!/bin/bash
if [[ "$1" == "loop" && -z "$2" ]]; then
    loop_mode=1
    interface=$(nmcli -p con show --active | tail -n +6 | grep -v loopback | awk '{print $4}' | head -n1)
    [[ "$interface" =~ ^ttyUSB[0-9]$ ]] && interface="ppp0"
else
    interface="${1:-}"
    if [[ -z "$interface" || "$interface" == "loop" ]]; then
        interface=$(nmcli -p con show --active | tail -n +6 | grep -v loopback | awk '{print $4}' | head -n1)
        [[ "$interface" =~ ^ttyUSB[0-9]$ ]] && interface="ppp0"
    fi
    loop_mode=0
    if [[ "$2" == "loop" ]]; then
        loop_mode=1
    fi
fi
unit_mode=2
if [[ "$2" == "loop" ]]; then
    loop_mode=1
fi
if [[ "$1" == "click" ]]; then
    connections=$(ss -tunp 2>/dev/null)
    IFS=$'\n' read -rd '' -a lines <<< "$connections"
    unset 'lines[0]'
    echo "Number of open connections per process:"
    declare -A process_counter
    declare -A process_names
    no_process=0
    for line in "${lines[@]}"; do
        if [[ "$line" == *"users:"* ]]; then
            pid="${line##*pid=}"
            pid="${pid%%,*}"
            ((process_counter[$pid]++))
            if [[ -z "${process_names[$pid]}" ]]; then
                process_names[$pid]=$(ps -p "$pid" -o comm= 2>/dev/null || echo "Unknown")
            fi
        else
            ((no_process++))
        fi
    done
    for pid in "${!process_counter[@]}"; do
        echo "${process_counter[$pid]} ${process_names[$pid]}"
    done | sort -nr
    echo -e "\nConnections without associated process: $no_process"
    echo -e "\nPress any key to exit."
    read -n 1 -s key
    echo -e "\nExiting..."
    exit 0
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
    elif (( $(echo "$value >= 11 && $value <= 30" | bc -l) )); then
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
    con_counter=0
    while IFS= read -r line; do
        ((con_counter++))
    done < <(ss -tun 2>/dev/null | tail -n +2)
    echo -e " $rx_converted |  $tx_converted |  $con_counter"
}

if [[ "$loop_mode" -eq 1 ]]; then
    while true; do
        main
        sleep 1
    done
else
    main
fi
