#!/bin/bash
if systemctl is-active "waydroid-container.service" &> /dev/null || lsns | grep -E 'android|lineageos' &> /dev/null || pgrep weston; then
    pkill -9 weston
    sudo pkill --cgroup=/lxc.payload.waydroid2
    sudo pkill -9 lxc-start
    sudo systemctl stop "waydroid-container.service"
else
    sudo systemctl restart "waydroid-container.service"
    pkill -9 adb
    weston --width=700 --height=900 --xwayland &> /dev/null &
    timeout=20
    while [[ $timeout -gt 0 ]]; do
        wmctrl -l | grep -q "Weston Compositor" && break
        sleep 0.5
        ((timeout--))
    done
    if [[ $timeout -eq 0 ]]; then
        if command -v notify-send &> /dev/null; then
            notify-send "Weston window failed to come up for some reason. Bummer.."
        else
            echo "Weston window failed to come up for some reason. Bummer.."
        fi
        exit 1
    fi
    DISPLAY=':1' alacritty -e bash -c "WAYLAND_DISPLAY='wayland-1' XDG_SESSION_TYPE='wayland' DISPLAY=':1' /usr/bin/waydroid show-full-ui" &> /dev/null &
    sleep 3
    if pgrep 'weston' > /dev/null; then
        while pgrep 'weston' > /dev/null; do
            sleep 1
        done
    fi
    pkill -9 weston
    sudo pkill --cgroup=/lxc.payload.waydroid2
    sudo pkill -9 lxc-start
    sudo systemctl stop "waydroid-container.service"
fi
