#!/bin/bash
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
    local line rx tx
    while IFS=: read -r dev data; do
        dev="${dev%% *}"
        if [[ "$dev" == "$iface" ]]; then
            IFS=' ' read -ra fields <<< "$data"
            rx="${fields[0]}"
            tx="${fields[8]}"
            echo "$rx $tx"
            return
        fi
    done < /proc/net/dev
}
IFS=' ' read -r rx1 tx1 <<< "$(get_data 'enp1s0')"
sleep 1
IFS=' ' read -r rx2 tx2 <<< "$(get_data 'enp1s0')"
rx_original=$((rx2 - rx1))
tx_original=$((tx2 - tx1))
convert_units() {
    local bytes=$1
    local units=("B/s" "KB/s" "MB/s")
    local i=0
    while (( bytes >= 1024 && i < ${#units[@]} - 1 )); do
        bytes=$((bytes / 1024))
        ((i++))
    done
    echo "${bytes}${units[i]}"
}
rx_converted=$(convert_units "$rx_original")
tx_converted=$(convert_units "$tx_original")
if (( rx_original >= 2 * 1024 * 1024 && rx_original < 10 * 1024 * 1024 )); then
    rx_converted="\e[92m$rx_converted\e[0m"
elif (( rx_original >= 11 * 1024 * 1024 && rx_original < 30 * 1024 * 1024 )); then
    rx_converted="\e[93m$rx_converted\e[0m"
elif (( rx_original >= 31 * 1024 * 1024 )); then
    rx_converted="\e[91m$rx_converted\e[0m"
fi
if (( tx_original >= 1999 * 1024 )); then
    tx_converted="\e[91m$tx_converted\e[0m"
fi
con_counter=0
while IFS= read -r line; do
    ((con_counter++))
done < <(ss -tun 2>/dev/null | tail -n +2)
echo -e " $rx_converted |  $tx_converted |  $con_counter"
