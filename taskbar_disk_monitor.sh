#!/bin/bash
unit_mode=2
taskbar_mode=false
declare -A data_read1 data_write1 read_total write_total counter time_alert_read time_alert_write
declare -a disk_list
hover() {
    local mode="$1"

    if [ "$taskbar_mode" == 'true' ]; then

        log_file="/tmp/taskbar_disk_monitor_hover"
        log_file_final="/tmp/taskbar_disk_monitor_hover_final"

        if [ "$mode" = "read" ]; then
            current_type="R"
        elif [ "$mode" = "write" ]; then
            current_type="W"
        fi

        [ -f "$log_file" ] || touch "$log_file"
        [ -f "$log_file_final" ] || touch "$log_file_final"

        process="$(sudo iotop -b -n 1 -o -qqq | head -n 1)"
        if [ -n "$process" ]; then

            current_proc="$(echo "$process" | awk '{print $9}')"

            last_line="$(tail -n 1 "$log_file")"
            last_type="$(echo "$last_line" | awk '{print $1}')"
            last_time="$(echo "$last_line" | awk '{print $2}')"
            last_proc="$(echo "$last_line" | awk '{print $12}')"

            now_epoch=$(date +%s)

            if [ -n "$last_time" ]; then
                last_epoch=$(date -d "$(date +%F) $last_time" +%s)
                diff_secs=$((now_epoch - last_epoch))
            else
                diff_secs=999
            fi

            if [ "$current_type" != "$last_type" ] || [ "$current_proc" != "$last_proc" ] || [ "$diff_secs" -gt 3 ]; then
                if [ "$mode" == "read" ];then
                    echo "R $(date +%H:%M:%S) - $process" | tee -a "$log_file" &> /dev/null
                    sed -En '${s@^R[[:space:]]+([0-9]{2}:[0-9]{2}):[0-9]{2}[[:space:]]+-[[:space:]]+.* ([0-9.]+)[[:space:]]+M/s .*  ([^ ]+).*@R \1 \3 \2 MB/s@p; s@^R[[:space:]]+([0-9]{2}:[0-9]{2}):[0-9]{2}[[:space:]]+-[[:space:]]+.* ([0-9.]+)[[:space:]]+K/s .*  ([^ ]+).*@R \1 \3 \2 KB/s@p}' "$log_file" | tee -a "$log_file_final" &> /dev/null
                elif [ "$mode" == "write" ];then
                    echo "W $(date +%H:%M:%S) - $process" | tee -a "$log_file" &> /dev/null
                    sed -En '${s@^W[[:space:]]+([0-9]{2}:[0-9]{2}):[0-9]{2}[[:space:]]+-[[:space:]]+.* ([0-9.]+)[[:space:]]+M/s .*  ([^ ]+).*@W \1 \3 \2 MB/s@p; s@^W[[:space:]]+([0-9]{2}:[0-9]{2}):[0-9]{2}[[:space:]]+-[[:space:]]+.* ([0-9.]+)[[:space:]]+K/s .*  ([^ ]+).*@W \1 \3 \2 KB/s@p}' "$log_file" | tee -a "$log_file_final" &> /dev/null
                fi
            fi

            if [ "$(wc -l < "$log_file_final")" -gt 10 ]; then
                tail -n 10 "$log_file_final" > taskbar_disk_monitor_hover_final.tmp && mv taskbar_disk_monitor_hover_final.tmp "$log_file_final"
            fi

            if [ "$(wc -l < "$log_file")" -gt 10 ]; then
                tail -n 10 "$log_file" > taskbar_disk_monitor_hover.tmp && mv taskbar_disk_monitor_hover.tmp "$log_file"
            fi
        fi

    fi
}


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
        if [[ ${read_total[$disk]} -ge 4096 ]]; then #transfer threshold -> 4MB/s
            time_alert_read["$disk"]=$current_time
        fi
        if [[ ${write_total[$disk]} -ge 4096 ]]; then #transfer threshold -> 4MB/s
            time_alert_write["$disk"]=$current_time
        fi
    done
}
display_data() {
    local output=""
    local use_mb read_kb write_kb read_integer read_fraction write_integer write_fraction
    if [ -z "$1" ] || [ "$1" == 'all' ]; then
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
                if [ "${value_read%.*}" -ge 4 ] && [ "${value_read%.*}" -lt 15 ]; then
                    value_read="\e[92m${value_read}${unit_read}\e[0m"
                elif [ "${value_read%.*}" -ge 15 ] && [ "${value_read%.*}" -lt 65 ]; then
                    value_read="\e[93m${value_read}${unit_read}\e[0m"
                elif [ "${value_read%.*}" -ge 65 ]; then
                    value_read="\e[91m${value_read}${unit_read}\e[0m"
                fi
            else
                value_read="${value_read}${unit_read}"
            fi

            if [[ -n "${time_alert_write[$disk]}" && $((current_time - time_alert_write[$disk])) -le 3 ]]; then
                if [ "${value_write%.*}" -ge 4 ] && [ "${value_write%.*}" -lt 15 ]; then
                    value_write="\e[92m${value_write}${unit_write}\e[0m"
                elif [ "${value_write%.*}" -ge 15 ] && [ "${value_write%.*}" -lt 65 ]; then
                    value_write="\e[93m${value_write}${unit_write}\e[0m"
                elif [ "${value_write%.*}" -ge 65 ]; then
                    value_write="\e[91m${value_write}${unit_write}\e[0m"
                fi
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
                if [ "${value_read%.*}" -ge 4 ] && [ "${value_read%.*}" -lt 15 ]; then
                    value_read="\e[92m${value_read}${unit_read}\e[0m"
                elif [ "${value_read%.*}" -ge 15 ] && [ "${value_read%.*}" -lt 65 ]; then
                    value_read="\e[93m${value_read}${unit_read}\e[0m"
                    hover read
                elif [ "${value_read%.*}" -ge 65 ]; then
                    value_read="\e[91m${value_read}${unit_read}\e[0m"
                    hover read
                fi
            else
            value_read="${value_read}${unit_read}"
            fi

            if [[ -n "${time_alert_write[$specified_disk]}" && $((current_time - time_alert_write[$specified_disk])) -le 3 ]]; then
                if [ "${value_write%.*}" -ge 4 ] && [ "${value_write%.*}" -lt 15 ]; then
                    value_write="\e[92m${value_write}${unit_write}\e[0m"
                elif [ "${value_write%.*}" -ge 15 ] && [ "${value_write%.*}" -lt 65 ]; then
                    value_write="\e[93m${value_write}${unit_write}\e[0m"
                    hover write
                elif [ "${value_write%.*}" -ge 65 ]; then
                    value_write="\e[91m${value_write}${unit_write}\e[0m"
                    hover write
                fi
            else
                value_write="${value_write}${unit_write}"
            fi
            output="${specified_disk} -> 📄 ${value_read} | 📝 ${value_write}"
        fi
    fi
    echo -ne "$output"
}
show_help() {
    cat <<'EOF'
Usage: taskbar_disk_monitor.sh [OPTIONS] [--loop [INTERVAL]]

Options:
  -h, --help                 Show this help
  -u, --unit N               Force unit: 1=KB/s, 2=MB/s, 3=Auto (also accepts 'kb','mb','auto'; default: 2)
  -d, --device DEVICE        Specify the device to display (ex: sda). Use 'all' to show all devices.

Additional arguments:
  --loop                     Run in continuous mode (optional INTERVAL). Can be used alone for the default 1 second interval; in that case, it shows all devices (all).
  --interval N               Set the interval in seconds for loop mode (default: 1)

Note:
  Positional arguments are not accepted to specify devices; use -d|--device. As a shortcut you can use `all` as the only argument to show all devices.

Examples:
  # Show a specific device
  ./taskbar_disk_monitor.sh -d sda
  ./taskbar_disk_monitor.sh --device=sda

  # Force unit: KB/MB/Auto
  ./taskbar_disk_monitor.sh -u kb -d sda
  ./taskbar_disk_monitor.sh --unit=mb --device=sda
  ./taskbar_disk_monitor.sh --unit=auto --device=sda

  # Continuous mode (loop)
  ./taskbar_disk_monitor.sh --loop           # loop with default interval (1s), shows all devices
  ./taskbar_disk_monitor.sh --loop 2         # loop with a 2-second interval
  ./taskbar_disk_monitor.sh --loop --interval 2
  ./taskbar_disk_monitor.sh -d sda --loop 1  # loop showing only 'sda'

  # Shortcut to show all devices
  ./taskbar_disk_monitor.sh all

Notes:
  - Colors indicate recent activity: green(>4), yellow(>15), red(>65) MB/s
EOF
} 

loop_mode=false
interval=1
specified_disk=""

ARGS=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
    show_help
    exit 0
fi
arg_index=0
while [ $arg_index -lt ${#ARGS[@]} ]; do
    arg="${ARGS[$arg_index]}"
    case "$arg" in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--unit|--unit=*)
            if [[ "$arg" == --unit=* ]]; then
                val="${arg#--unit=}"
            else
                arg_index=$((arg_index+1))
                val="${ARGS[$arg_index]:-}"
            fi

            if [ -z "$val" ]; then
                echo "Error: missing argument for $arg" >&2
                exit 1
            fi

            case "${val,,}" in
                1|kb)
                    unit_mode=1
                    ;;
                2|mb)
                    unit_mode=2
                    ;;
                3|auto)
                    unit_mode=3
                    ;;
                *)
                    echo "Error: invalid value for --unit: '$val'. Use 1|2|3 or kb|mb|auto" >&2
                    exit 1
                    ;;
            esac
            ;;
        -d|--device|--device=*)
            if [[ "$arg" == --device=* ]]; then
                val="${arg#--device=}"
            else
                arg_index=$((arg_index+1))
                val="${ARGS[$arg_index]:-}"
            fi

            if [ -z "$val" ]; then
                echo "Error: missing argument for $arg" >&2
                exit 1
            fi

            specified_disk="$val"
            ;;
        --interval)
            arg_index=$((arg_index+1))
            interval="${ARGS[$arg_index]:-1}"
            ;;
        --interval=*)
            interval="${arg#*=}"
            ;;
        --taskbar)
            taskbar_mode=true
            ;;
        --loop)
            loop_mode=true
            next="${ARGS[$((arg_index+1))]:-}"
            if [[ "$next" =~ ^[0-9]+$ ]]; then
                interval="$next"
                arg_index=$((arg_index+1))
            fi
            ;;
        *)
            if [[ "$arg" == "all" ]]; then
                specified_disk="all"
#             else
#                 echo "Unrecognized command; use -d|--device to specify a device" >&2
#                 exit 1
            fi
            ;;
    esac
    arg_index=$((arg_index+1))
done

if [ "$loop_mode" = true ]; then
    while true; do
        collect_data
        output=$(display_data "$specified_disk")
        printf "\r$output"
        sleep "$interval"
    done
else
    collect_data
    display_data "$specified_disk"
fi
