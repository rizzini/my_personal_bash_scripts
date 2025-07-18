#!/bin/bash
set_brightness_ddcutil() {
    local brightness=$1
    ddcutil setvcp 0x10 "$brightness" 0x12 "$brightness" --disable-cross-instance-locks --skip-ddc-checks --bus=4 2>&1 &
}
set_brightness_xrandr() {
    local brightness=$1
    xrandr --output 'DP-2' --brightness "$brightness" 2>&1 &
}
control_brightness() {
    local tool=$1
    local initial_brightness=$2
    local fifo_path="/tmp/yad_brightness_fifo_$tool"
    local current_brightness
    local min_value max_value scale_factor
    local off_btn=102
    local sw_btn=101
    if [[ "$tool" == "xrandr" ]]; then
        current_brightness=${initial_brightness:-$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')}
        if [[ -z "$current_brightness" ]]; then
            current_brightness=1.0
        fi
        current_brightness=$(LC_NUMERIC=C echo "$current_brightness * 100" | bc | awk '{printf "%d", $1}')
        min_value=20 # avoid the screen to be too dark that you can't easily revert, which can happen on xrandr..
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
        --button="Switch:101" --button="Off:102" > "$fifo_path" &
    yad_pid=$!
    {
        while read -r input; do
            echo "reset" > "/tmp/yad_idle_reset_$tool"
            if [[ "$tool" == "xrandr" ]]; then
                input=$(LC_NUMERIC=C echo "$input / $scale_factor" | bc -l | awk '{printf "%.1f", $0}')
                set_brightness_xrandr "$input"
            else
                set_brightness_ddcutil "$input"
            fi
        done < "$fifo_path"
    } &
    wait "$yad_pid"
    exit_code=$?
    if [[ "$exit_code" -eq 0 ]]; then
        if [[ "$tool" == "xrandr" ]]; then
            current_brightness=$(xrandr --verbose | grep -i brightness | head -n1 | awk '{print $2}')
            ddcutil_brightness=$(LC_NUMERIC=C echo "$current_brightness * 100" | bc | awk '{printf "%d", $1}')
            "$0" choose_ddcutil "$ddcutil_brightness"
        else
            current_brightness=$(ddcutil getvcp 0x10 | awk '{print $9}' | tr -cd '[:digit:]')
            if [[ -z "$current_brightness" ]]; then
                current_brightness=100
            fi
            xrandr_brightness=$(LC_NUMERIC=C echo "scale=2; $current_brightness / 100" | bc)
            "$0" choose_xrandr "$xrandr_brightness"
        fi
    elif  [[ "$exit_code" -eq "$off_btn" ]]; then
        ddcutil setvcp D6 04;
    elif [[ "$exit_code" -eq "$sw_btn" ]]; then
        if [[ "$tool" == "xrandr" ]]; then
            control_brightness "ddcutil"
        else
            control_brightness "xrandr"
        fi
        return
    fi
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
            echo "Error: Invalid tool. Use 'xrandr' or 'ddcutil'."
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
            "$0" choose_ddcutil
            exit 0
        fi
        pkill -9 -f "$0 choose_ddcutil" 2>/dev/null
        pkill -9 yad
        control_brightness "xrandr"
        ;;
    'choose_ddcutil')
        if pgrep -f "$0 choose_ddcutil" | grep -v $$ > /dev/null; then
            echo "Switching to 'choose_xrandr'."
            "$0" choose_xrandr
            exit 0
        fi
        pkill -9 -f "$0 choose_xrandr" 2>/dev/null
        pkill -9 yad
        control_brightness "ddcutil"
        ;;
esac
