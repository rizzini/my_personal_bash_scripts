#!/bin/bash
set_brightness_ddcutil() {
    local brightness=$1
    ddcutil setvcp 0x10 "$brightness" 0x12 "$brightness" --disable-cross-instance-locks --skip-ddc-checks --bus=4 2>&1 &
}
set_brightness_xrandr() {
    local brightness=$1
    xrandr --output 'DP-2' --brightness "$brightness" 2>&1
}
control_brightness() {
    local tool=$1
    local initial_brightness=$2
    local fifo_path="/tmp/yad_brightness_fifo_$tool"
    local current_brightness
    local min_value max_value scale_factor
    if [[ "$tool" == "xrandr" ]]; then
        current_brightness=${initial_brightness:-$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')}
        current_brightness=$(printf "%.0f" "$(LC_NUMERIC=C echo "$current_brightness * 100" | bc)")
        min_value=20
        max_value=100
        scale_factor=100
    elif [[ "$tool" == "ddcutil" ]]; then
        current_brightness=${initial_brightness:-$(ddcutil getvcp 0x10 | awk '{print $9}' | tr -cd '[:digit:]')}
        if [[ -z "$current_brightness" ]]; then
            current_brightness=100
        fi
        min_value=0
        max_value=100
        scale_factor=1
    else
        echo "Error: Invalid tool.."
        exit 1
    fi
    [ -p "$fifo_path" ] || mkfifo "$fifo_path"
    yad --scale --vertical --width=100 --close-on-unfocus --step=5 --on-top --height=250 --value="$current_brightness" \
        --min-value="$min_value" --max-value="$max_value" --text="$tool" --text-align=center --print-partial \
        --button="Switch:0" > "$fifo_path" &
    yad_pid=$!
    {
        while read -r new_brightness; do
            echo "reset" > "/tmp/yad_idle_reset_$tool"
            if [[ "$tool" == "xrandr" ]]; then
                new_brightness=$(LC_NUMERIC=C echo "$new_brightness / $scale_factor" | bc -l | awk '{printf "%.1f", $0}')
                set_brightness_xrandr "$new_brightness"
            else
                set_brightness_ddcutil "$new_brightness"
            fi
        done < "$fifo_path"
    } &
    monitor_idle "$yad_pid" "$tool" &
    wait "$yad_pid"
    if [[ $? -eq 0 ]]; then
        if [[ "$tool" == "xrandr" ]]; then
            current_brightness=$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')
            current_brightness=$(printf "%.0f" "$(LC_NUMERIC=C echo "$current_brightness * 100" | bc)")
            "$0" choose_ddcutil "$current_brightness"
        else
            current_brightness=$(ddcutil getvcp 0x10 | awk '{print $9}' | tr -cd '[:digit:]')
            if [[ -z "$current_brightness" ]]; then
                current_brightness=100
            fi
            "$0" choose_xrandr "$current_brightness"
        fi
    fi
    rm -f "$fifo_path" "/tmp/yad_idle_reset_$tool"
}
monitor_idle() {
    local yad_pid=$1
    local tool=$2
    local idle_time=0
    while kill -0 "$yad_pid" 2>/dev/null; do
        sleep 1
        if [[ -f "/tmp/yad_idle_reset_$tool" ]]; then
            idle_time=0
            rm -f "/tmp/yad_idle_reset_$tool"
        else
            idle_time=$((idle_time + 1))
        fi

        if [[ $idle_time -ge 5 ]]; then
            kill "$yad_pid" 2>/dev/null
            break
        fi
    done
}
validate_brightness() {
    local value=$1
    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 0 ] && [ "$value" -le 100 ]; then
        return 0
    elif [[ "$value" =~ ^0(\.[0-9]+)?$|^1(\.0+)?$ ]]; then
        return 0
    else
        echo "Error: The value must be betwen 0 e 100 (ddcutil) or 0.1 a 1.0 (xrandr)."
        return 1
    fi
}
case $1 in
    'increase')
        if [[ "$2" == "xrandr" ]]; then
            current_brightness=$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')
            new_brightness=$(echo "$current_brightness + 0.1" | bc)
            if (( $(echo "$new_brightness > 1.0" | bc -l) )); then
                new_brightness=1.0
            fi
            set_brightness_xrandr "$new_brightness"
        elif [[ "$2" == "ddcutil" ]]; then
            current_brightness=$(ddcutil getvcp 0x10 | awk '{print $9}' | tr -cd '[:digit:]')
            if [[ -z "$current_brightness" ]]; then
                echo "Error: Could not retrieve the current brightness using ddcutil."
                exit 1
            fi
            new_brightness=$((current_brightness + 5))
            [ "$new_brightness" -gt 100 ] && new_brightness=100
            set_brightness_ddcutil "$new_brightness"
        else
            echo "Error: Invalid tool. Use 'xrandr' or 'ddcutil'"
            exit 1
        fi
        ;;
    'decrease')
        if [[ "$2" == "xrandr" ]]; then
            current_brightness=$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')
            new_brightness=$(echo "$current_brightness - 0.1" | bc)
            if (( $(echo "$new_brightness < 0.1" | bc -l) )); then
                new_brightness=0.1
            fi
            set_brightness_xrandr "$new_brightness"
        elif [[ "$2" == "ddcutil" ]]; then
            current_brightness=$(ddcutil getvcp 0x10 | awk '{print $9}' | tr -cd '[:digit:]')
            if [[ -z "$current_brightness" ]]; then
                echo "Error: Could not retrieve the current brightness with ddcutil."
                exit 1
            fi
            new_brightness=$((current_brightness - 5))
            [ "$new_brightness" -lt 0 ] && new_brightness=0
            set_brightness_ddcutil "$new_brightness"
        else
            echo "Erro: Ferramenta inválida. Use 'xrandr' ou 'ddcutil'."
            exit 1
        fi
        ;;
    'show_xrandr')
        current_brightness=$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')
        current_brightness=$(printf "%.0f" "$(echo "$current_brightness * 100" | bc)")
        echo "$current_brightness%"
        ;;
    'show_ddcutil')
        current_brightness=$(ddcutil getvcp 0x10 | awk '{print $9}' | tr -cd '[:digit:]')
        echo "☀️  $current_brightness%"
        ;;
    'choose_xrandr')
        if pgrep -f "$0 choose_xrandr" | grep -v $$ > /dev/null; then
            echo "Switching to 'choose_ddcutil'."
            "$0" choose_ddcutil "$2"
            exit 0
        fi
        pkill -9 -f "$0 choose_ddcutil" 2>/dev/null
        pkill -9 yad
        control_brightness "xrandr" "$2"
        ;;
    'choose_ddcutil')
        if pgrep -f "$0 choose_ddcutil" | grep -v $$ > /dev/null; then
            echo "Switching to 'choose_xrandr'."
            "$0" choose_xrandr "$2"
            exit 0
        fi
        pkill -9 -f "$0 choose_xrandr" 2>/dev/null
        pkill -9 yad
        control_brightness "ddcutil" "$2"
        ;;
esac
