#!/bin/bash
interface='enp1s0'
history_file='/home/lucas/scripts/taskbar_change_route_isp.txt'
history_file_boot='/home/lucas/scripts/taskbar_change_route_isp_boot.txt'
if [ "$1" == 'startup_apply_last_used_route' ]; then
    history="$(< "$history_file_boot")"
    ip route add default via "$history"
    exit
elif [ "$1" == 'click' ]; then

    current="$(ip route show default | awk '{print $3}')"
    old="$(< "$history_file")"

    if [ "$current" != "$old" ]; then
        if [ "$current" = '192.168.1.1' ]; then
            sudo ip route replace default via 192.168.15.1
        elif [ "$current" = '192.168.15.1' ]; then
            sudo ip route replace default via 192.168.1.1
        fi
        echo "$current" > "$history_file"
        echo "$old" > "$history_file_boot"
    fi
    exit
fi
#salvar no historio a rota para bootar
convert_units() {
    local unit_mode=$1
    local is_speed=$2
    local bytes=$3
    local value unit
    local suffix=""

    if [ "$is_speed" -eq 1 ]; then
        suffix="/s"
    fi

    case "$unit_mode" in
        1)
            value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024 }")
            unit="KB"
            ;;
        2)
            value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024/1024 }")
            unit="MB"
            ;;
        3)
            if (( bytes >= 1024*1024*1024 )); then
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024/1024/1024 }")
                unit="GB"
            elif (( bytes >= 1024*1024 )); then
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024/1024 }")
                unit="MB"

            else
                value=$(awk "BEGIN { printf \"%.2f\", $bytes/1024 }")
                unit="KB"
            fi
            ;;
    esac
    echo "${value}${unit}${suffix}"
}
format_uptime() {
    local up total_days hours minutes
    up=$(cut -d. -f1 /proc/uptime)

    total_days=$((up / 86400))
    hours=$(((up % 86400) / 3600))
    minutes=$(((up % 3600) / 60))

    if [ "$total_days" -gt 0 ]; then
        printf "%dd %02dh %02dm" "$total_days" "$hours" "$minutes"
    else
        printf "%02dh %02dm" "$hours" "$minutes"
    fi
}

cache="/tmp/taskbar_network_speed_monitor_$interface"
hover_interval=1
if [ "$1" = "hover" ]; then
    now=$(date +%s)
    if [ -f "$cache" ]; then
        read -r last_ts < "$cache"
        if [ $((now - last_ts)) -lt "$hover_interval" ]; then
            tail -n +2 "$cache"
            exit 0
        fi
    fi
    read rx tx <<EOF
$(awk -v i="$interface" '$1==i":" {print $2, $10}' /proc/net/dev)
EOF

    uptime_str=$(format_uptime)

    route="$(ip route show default | awk '{print $3}')"
    if [ "$route" == '192.168.1.1' ]; then
        ISP_str='TIM'
    else
        ISP_str='VIVO'
    fi

    output="+Total+ | Uptime: $uptime_str | ISP: $ISP_str
Download: $(convert_units 3 0 "$rx") | Upload: $(convert_units 3 0 "$tx")"

    printf '%s\n%s\n' "$now" "$output" > "$cache"
    printf '%s\n' "$output"
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

colorize_speed() {
    local speed_str="$1"
    local color_reset="\e[0m"
    local color_green="\e[92m"
    local color_yellow="\e[93m"
    local color_red="\e[91m"
    local value
    value=$(echo "$speed_str" | awk -F'MB/s' '{print $1}')
    value=$(echo "$value" | tr ',' '.' | xargs)
    if (( $(echo "$value >= 2 && $value <= 25" | bc -l) )); then
        echo -e "${color_green}${speed_str}${color_reset}"
    elif (( $(echo "$value >= 25 && $value <= 50" | bc -l) )); then
        echo -e "${color_yellow}${speed_str}${color_reset}"
    elif (( $(echo "$value > 50" | bc -l) )); then
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

    rx_converted=$(convert_units 2 1 "$rx_original")
    tx_converted=$(convert_units 2 1 "$tx_original")

    rx_converted=$(colorize_speed "$rx_converted")
    tx_converted=$(colorize_speed "$tx_converted")

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

