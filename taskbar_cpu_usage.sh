#!/bin/bash
get_cpu_values() {
    read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice))
    echo "$idle $total"
}
read idle1 total1 < <(get_cpu_values)
sleep 1
read idle2 total2 < <(get_cpu_values)
delta_idle=$((idle2 - idle1))
delta_total=$((total2 - total1))
cpu_usage=$((100 * (delta_total - delta_idle) / delta_total))
if ((cpu_usage > 90)); then
    echo -e " \e[91m${cpu_usage}%\e[0m |"
else
    echo " ${cpu_usage}%"
fi
