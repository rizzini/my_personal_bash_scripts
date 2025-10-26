#!/bin/sh
dbus-monitor "interface='org.freedesktop.Notifications'" | while read -r line; do
    echo "$line" | grep -q "google-chrome" && paplay ~/.mixkit-software-interface-start-2574.wav &
done
