#!/usr/bin/env bash

set -euo pipefail

# Usage check
if [ $# -eq 0 ]; then
    echo "Usage: $0 <process_name_or_substring>"
    exit 1
fi

# Force decimal point instead of comma for formatting
export LC_NUMERIC=C

SEARCH_RAW="$1"
SEARCH=$(printf '%s' "$SEARCH_RAW" | tr '[:upper:]' '[:lower:]')
SELF_PID=$$
TOTAL_PSS=0
declare -a MATCH_PIDS=()

# Convert KB to human-readable (KB/MB/GB). Input expected in integer KB.
convert_to_human_readable() {
    local kb=$1
    if [ "$kb" -ge 1048576 ]; then
        awk -v k=$kb 'BEGIN{printf "%.2f GB", k/1048576}'
    elif [ "$kb" -ge 1024 ]; then
        awk -v k=$kb 'BEGIN{printf "%.2f MB", k/1024}'
    else
        printf "%d KB" "$kb"
    fi
}

# Check whether $pid itself or any of its ancestors contain the search string
is_descendant_of_search() {
    local pid=$1
    while [ "$pid" -gt 1 ]; do
        # avoid matching our own script
        if [ "$pid" -eq "$SELF_PID" ]; then
            return 1
        fi

        if [ -r "/proc/$pid/comm" ]; then
            comm=$(tr '[:upper:]' '[:lower:]' < "/proc/$pid/comm" 2>/dev/null || true)
            if printf '%s' "$comm" | grep -Fqi -- "$SEARCH"; then
                return 0
            fi
        fi

        if [ -r "/proc/$pid/cmdline" ]; then
            cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
            if printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]' | grep -Fqi -- "$SEARCH"; then
                return 0
            fi
        fi

        # climb to parent
        if [ -r "/proc/$pid/status" ]; then
            pid=$(awk '/^PPid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null || echo 0)
        else
            break
        fi
    done
    return 1
}


# --- Faster PID collection using a single `ps` snapshot ---
# By default, restrict to the current user to reduce scanning time.
# Use -a/--all to scan system-wide (slower).

SCAN_ALL=0
if [ "${1:-}" = "-a" ] || [ "${1:-}" = "--all" ]; then
    SCAN_ALL=1
    # shift search arg if user passed the flag first
    SEARCH_RAW="${2:-}"
    SEARCH=$(printf '%s' "$SEARCH_RAW" | tr '[:upper:]' '[:lower:]')
fi

ps_source=""
if [ "$SCAN_ALL" -eq 1 ]; then
    # full system scan (slower)
    ps_source=$(ps -eo pid=,ppid=,comm=,cmd= -ww 2>/dev/null)
else
    # restrict to current user's processes (much faster)
    USERNAME=$(id -un)
    ps_source=$(ps -u "$USERNAME" -o pid=,ppid=,comm=,cmd= -ww 2>/dev/null)
fi

if [ -z "$ps_source" ]; then
    echo "Nenhum processo encontrado para escanear. (tente executar com sudo ou --all)"
    exit 1
fi

# Use awk to find root matches and collect all their descendants efficiently
MATCH_PIDS=( $(printf '%s\n' "$ps_source" | awk -v search="$SEARCH" '
    BEGIN{IGNORECASE=1}
    {
        pid=$1; ppid=$2; comm=$3;
        # rebuild cmd from remaining fields (4..)
        cmd=""; for(i=4;i<=NF;i++){ cmd = cmd (i==4?"":" ") $i }
        procs[pid] = pid " " ppid " " comm " " cmd;
        children[ppid] = children[ppid] " " pid;
        # if comm or cmd contains the search substring, mark as root
        if (index(tolower(comm), search) || index(tolower(cmd), search)) roots[pid]=1;
    }
    END{
        # BFS from each root to collect descendants
        PROCSEP=" ";
        for (r in roots) {
            if (seen[r]) continue;
            queue[0]=r; qh=0; qt=1; seen[r]=1;
            while (qh<qt) {
                cur=queue[qh++];
                printf "%s ", cur;
                split(children[cur], arr);
                for (i in arr) if (arr[i] != "") {
                    if (!seen[arr[i]]) { queue[qt++]=arr[i]; seen[arr[i]]=1 }
                }
            }
        }
    }'
) )

# Remove any instance of our own PID if present
TMP=()
for p in "${MATCH_PIDS[@]}"; do
    if [ "$p" -ne "$SELF_PID" ] 2>/dev/null; then
        TMP+=("$p")
    fi
done
MATCH_PIDS=("${TMP[@]}")

if [ ${#MATCH_PIDS[@]} -eq 0 ]; then
    echo "Nenhum processo encontrado correspondendo a: $SEARCH_RAW"
    exit 1
fi

echo "Uso de memória para: $SEARCH_RAW"
echo "----------------------------------------"

# For each matched PID, prefer smaps_rollup, fallback to smaps. Sum integer KB values.
for pid in "${MATCH_PIDS[@]}"; do
    pss=0
    if [ -r "/proc/$pid/smaps_rollup" ]; then
        pss=$(awk '/^Pss:/ {print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)
    elif [ -r "/proc/$pid/smaps" ]; then
        pss=$(awk '/^Pss:/ {sum += $2} END {print sum+0}' "/proc/$pid/smaps" 2>/dev/null || echo 0)
    else
        pss=0
    fi

    # Normalize to integer KB (smaps/smaps_rollup already report KB)
    pss=${pss%%.*}
    [ -z "$pss" ] && pss=0

    if [ "$pss" -gt 0 ] 2>/dev/null; then
        comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "N/A")
        printf "%s - PID: %s (%s)\n" "$(convert_to_human_readable "$pss")" "$pid" "$comm"
        TOTAL_PSS=$((TOTAL_PSS + pss))
    fi
done

echo "----------------------------------------"
echo "Memória total utilizada: $(convert_to_human_readable "$TOTAL_PSS")"
