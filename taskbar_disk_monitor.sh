#!/bin/bash
unit_mode=2
declare -A data_read1 data_write1 read_total write_total counter time_alert_read time_alert_write
declare -a disk_list=()
contains() {
    local target="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$target" ]] && return 0
    done
    return 1
}
collect_data() {
    while read -r _ _ _ name; do
        [[ "$name" =~ [0-9]$ ]] && continue
        contains "$name" "${disk_list[@]}" || disk_list+=("$name")
    done < <(tail -n +3 /proc/partitions)
    for disk in "${disk_list[@]}"; do
        counter["$disk"]=$((counter["$disk"]+1))
        while read -ra line; do
            if [[ "${line[2]}" == "$disk" ]]; then
                data_read1["$disk"]="${line[5]}"
                data_write1["$disk"]="${line[9]}"
                break
            fi
        done < /proc/diskstats
    done
    sleep 0.5
    for disk in "${disk_list[@]}"; do
        while read -ra line; do
            if [[ "${line[2]}" == "$disk" ]]; then
                data_read2["$disk"]="${line[5]}"
                data_write2["$disk"]="${line[9]}"
                break
            fi
        done < /proc/diskstats
        read_total["$disk"]=$((data_read2[$disk] - data_read1[$disk]))
        write_total["$disk"]=$((data_write2[$disk] - data_write1[$disk]))
        current_time=$(date +%s)
        if [[ ${read_total[$disk]} -ge 20480 ]]; then
            time_alert_read["$disk"]=$current_time
        fi
        if [[ ${write_total[$disk]} -ge 20480 ]]; then
            time_alert_write["$disk"]=$current_time
        fi
    done
}
display_data() {
    local output=""
    local use_mb read_kb write_kb read_integer read_fraction write_integer write_fraction
    if [ "$1" == 'all' ]; then
        for disk in "${disk_list[@]}"; do
            case "$unit_mode" in
                1)
                    value_read=${read_total[$disk]}
                    unit_read="KB/s"
                    ;;
                2)
                    read_kb=$((read_total[$disk] * 100 / 1024))
                    read_integer=$((read_kb / 100))
                    read_fraction=$(printf "%02d" $((read_kb % 100)))
                    value_read="${read_integer}.${read_fraction}"
                    unit_read="MB/s"
                    ;;
                3)
                    if [[ ${read_total[$disk]} -ge 1024 ]]; then
                        read_kb=$((read_total[$disk] * 100 / 1024))
                        read_integer=$((read_kb / 100))
                        read_fraction=$(printf "%02d" $((read_kb % 100)))
                        value_read="${read_integer}.${read_fraction}"
                        unit_read="MB/s"
                    else
                        value_read=${read_total[$disk]}
                        unit_read="KB/s"
                    fi
                    ;;
            esac
            case "$unit_mode" in
                1)
                    value_write=${write_total[$disk]}
                    unit_write="KB/s"
                    ;;
                2)
                    write_kb=$((write_total[$disk] * 100 / 1024))
                    write_integer=$((write_kb / 100))
                    write_fraction=$(printf "%02d" $((write_kb % 100)))
                    value_write="${write_integer}.${write_fraction}"
                    unit_write="MB/s"
                    ;;
                3)
                    if [[ ${write_total[$disk]} -ge 1024 ]]; then
                        write_kb=$((write_total[$disk] * 100 / 1024))
                        write_integer=$((write_kb / 100))
                        write_fraction=$(printf "%02d" $((write_kb % 100)))
                        value_write="${write_integer}.${write_fraction}"
                        unit_write="MB/s"
                    else
                        value_write=${write_total[$disk]}
                        unit_write="KB/s"
                    fi
                    ;;
            esac
            current_time=$(date +%s)
            if [[ -n "${time_alert_read[$disk]}" && $((current_time - time_alert_read[$disk])) -le 3 ]]; then
                value_read="\e[91m${value_read}${unit_read}\e[0m"
            else
                value_read="${value_read}${unit_read}"
            fi

            if [[ -n "${time_alert_write[$disk]}" && $((current_time - time_alert_write[$disk])) -le 3 ]]; then
                value_write="\e[91m${value_write}${unit_write}\e[0m"
            else
                value_write="${value_write}${unit_write}"
            fi
            output+="${disk} -> 📄 ${value_read} | 📝 ${value_write} "
        done
    elif [ -n "$1" ]; then
        specified_disk="$1"
        if [[ ! " ${disk_list[@]} " =~ " ${specified_disk} " ]]; then
            output="Error: Device '${specified_disk}' is not present in the system."
        else
            case "$unit_mode" in
                1)
                    value_read=${read_total[$specified_disk]}
                    unit_read="KB/s"
                    ;;
                2)
                    read_kb=$((read_total[$specified_disk] * 100 / 1024))
                    read_integer=$((read_kb / 100))
                    read_fraction=$(printf "%02d" $((read_kb % 100)))
                    value_read="${read_integer}.${read_fraction}"
                    unit_read="MB/s"
                    ;;
                3)
                    if [[ ${read_total[$specified_disk]} -ge 1024 ]]; then
                        read_kb=$((read_total[$specified_disk] * 100 / 1024))
                        read_integer=$((read_kb / 100))
                        read_fraction=$(printf "%02d" $((read_kb % 100)))
                        value_read="${read_integer}.${read_fraction}"
                        unit_read="MB/s"
                    else
                        value_read=${read_total[$specified_disk]}
                        unit_read="KB/s"
                    fi
                    ;;
            esac

            case "$unit_mode" in
                1)
                    value_write=${write_total[$specified_disk]}
                    unit_write="KB/s"
                    ;;
                2)
                    write_kb=$((write_total[$specified_disk] * 100 / 1024))
                    write_integer=$((write_kb / 100))
                    write_fraction=$(printf "%02d" $((write_kb % 100)))
                    value_write="${write_integer}.${write_fraction}"
                    unit_write="MB/s"
                    ;;
                3)
                    if [[ ${write_total[$specified_disk]} -ge 1024 ]]; then
                        write_kb=$((write_total[$specified_disk] * 100 / 1024))
                        write_integer=$((write_kb / 100))
                        write_fraction=$(printf "%02d" $((write_kb % 100)))
                        value_write="${write_integer}.${write_fraction}"
                        unit_write="MB/s"
                    else
                        value_write=${write_total[$specified_disk]}
                        unit_write="KB/s"
                    fi
                    ;;
            esac

            current_time=$(date +%s)
            if [[ -n "${time_alert_read[$specified_disk]}" && $((current_time - time_alert_read[$specified_disk])) -le 3 ]]; then
                value_read="\e[91m${value_read}${unit_read}\e[0m"
            else
                value_read="${value_read}${unit_read}"
            fi

            if [[ -n "${time_alert_write[$specified_disk]}" && $((current_time - time_alert_write[$specified_disk])) -le 3 ]]; then
                value_write="\e[91m${value_write}${unit_write}\e[0m"
            else
                value_write="${value_write}${unit_write}"
            fi

            output="${specified_disk} -> 📄 ${value_read} | 📝 ${value_write}"
        fi
    fi
    echo -ne "$output"
}
if [ "$2" == 'loop' ]; then
    interval=${3:-1}
    while true; do
        collect_data
        output=$(display_data "$1")
        printf "\r$output"
        sleep "$interval"
    done
else
    collect_data
    display_data "$1"
fi
