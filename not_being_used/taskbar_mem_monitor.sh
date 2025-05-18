#!/bin/bash
export LANG=C LC_ALL=C;
size () {
    local -a units
    local -i scale
    scale=1000
    units=(B KB MB GB TB EB PB YB ZB)
    local -i unit=0
    if [ -z "${units[0]}" ]
    then
        unit=1
    fi
    local -i whole=${1:-0}
    local -i remainder=0
    while (( whole >= scale ))
    do
        remainder=$(( whole % scale ))
        whole=$((whole / scale))
        unit=$(( unit + 1 ))
    done
    local decimal
    if [ $remainder -gt 0 ]
    then
        local -i fraction="$(( (remainder * 10 / scale)))"
        if [ "$fraction" -gt 0 ]
        then
            decimal=".$fraction"
        fi
    fi
    echo "${whole}${decimal}${units[$unit]}"
}
if [[ "$1" && $(/usr/bin/grep 'Dirty:' /proc/meminfo | /usr/bin/awk '{print $2}') -gt 100000 ]];then
    writeback=$(size "$(/usr/bin/grep 'Writeback:' /proc/meminfo | /usr/bin/awk '{print $2}')"000)
    dirty=$(size "$(/usr/bin/grep 'Dirty:' /proc/meminfo | /usr/bin/awk '{print $2}')"000)
    echo "Dirty: ""$dirty" "|" "Writeback: ""$writeback"
    exit
elif [ -z "$1" ];then
    writeback=$(size "$(/usr/bin/grep 'Writeback:' /proc/meminfo | /usr/bin/awk '{print $2}')"000)
    dirty=$(size "$(/usr/bin/grep 'Dirty:' /proc/meminfo | /usr/bin/awk '{print $2}')"000)
    echo "Dirty: ""$dirty" "|" "Writeback: ""$writeback"
fi


