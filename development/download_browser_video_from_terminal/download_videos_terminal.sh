#!/bin/bash
xclip -sel clip < /dev/null
rm -f /home/lucas/Documentos/scripts/.download_videos_terminal_progress_files/*
export LC_ALL=C
counter=0
regex='(https|http?)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
max_downloads=1
queue_file="/home/lucas/Documentos/scripts/download_queue.db"
progress_dir="/home/lucas/Documentos/scripts/.download_videos_terminal_progress_files"
mkdir -p "$progress_dir"

paused=false
pause_state_file="/home/lucas/Documentos/scripts/pause_state.txt"
echo "resumed" > "$pause_state_file"

cleanup() {
    echo "Cleaning up..."
    active_pids=$(pgrep yt-dlp)
    for pid in $active_pids; do
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
        url=$(echo "$cmdline" | grep -oP "$regex")
        if [[ -n "$url" && ! $(grep -Fx "$url" "$queue_file") ]]; then
            echo "Movendo download ativo para a fila: $url"
            echo "$url" >> "$queue_file"
        fi
    done
    echo "Finalizando processos remanescentes..."
    pkill -f yt-dlp
    pkill -P $$
    rm -rf "$progress_dir"/*
    exit 0
}

trap cleanup SIGINT SIGTERM

notify_error() {
    echo "$url" >> /home/lucas/error.txt
}

get_domain() {
    local url="$1"
    echo "$url" | awk -F[/:] '{print $4}'
}

baixar() {
    local url="$1"
    local domain=$(get_domain "$url")
    local progress_file="$progress_dir/$(echo "$url" | md5sum | awk '{print $1}').txt"
    touch "$progress_file"
    cd /mnt/data/Videos/new || exit

    paplay /home/lucas/Documentos/scripts/ok.mp3 &
    yt-dlp -P "temp:tmp" -N30  -f "bestvideo[height<=?1080]+bestaudio/best" "$url" --newline 2>&1 | while IFS= read -r line; do
#         yt-dlp -P "temp:tmp" "$url" --newline 2>&1 | while IFS= read -r line; do
        if [[ "$line" =~ ([0-9]{1,3}\.[0-9])% ]]; then
            progress="${BASH_REMATCH[1]}%"
        fi
        if [[ "$line" =~ ([0-9\.]+[KM]iB/s) ]]; then
            speed="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$progress" && -n "$speed" ]]; then
            echo "$domain | $progress | $speed" > "$progress_file"
            progress=""
            speed=""
        fi
        if [[ "$line" == *"ERROR: Unsupported URL:"* ]]; then
            paplay /home/lucas/Documentos/scripts/wrong-47985.mp3 &
            notify_error
            break
        fi
    done

    if [ $? -eq 0 ]; then
        echo "$url" >> /home/lucas/Documentos/scripts/download_videos_terminal.db
        echo 'finalizado..'
    else
        paplay /home/lucas/Documentos/scripts/wrong-47985.mp3 &
        notify_error
    fi
    rm -f "$progress_file"
}

process_url() {
    local url="$1"
    local domain=$(get_domain "$url")

    while [ "$(pgrep -c yt-dlp)" -ge "$max_downloads" ]; do
        sleep 1
    done

    if grep -qF "$domain" "/home/lucas/Documentos/scripts/download_videos_terminal_not_supp.db"; then
        echo "Domínio não suportado: $domain"
        mpv --no-config --no-terminal /home/lucas/Documentos/scripts/wrong-47985.mp3 &
        return
    fi
    if grep -qF "$url" "/home/lucas/Documentos/scripts/download_videos_terminal_not_supp.db"; then
        if ! grep -qF "$url" "/home/lucas/error.txt"; then
            notify_error
        fi
    else
        baixar "$url" &
    fi
}

process_queue() {
    while [ "$(pgrep -c yt-dlp)" -lt "$max_downloads" ] && [ -s "$queue_file" ]; do
        if [ "$(pgrep -c yt-dlp)" -ge "$max_downloads" ]; then
            break
        fi

        url=$(head -n 1 "$queue_file")
        sed -i '1d' "$queue_file"

        if ! pgrep -f "yt-dlp.*$url" > /dev/null; then
            process_url "$url"
        fi
    done
}

display_status() {
    while :; do
        clear
        echo "Active downloads: $(pgrep -c yt-dlp)"
        queue_count=$(wc -l < "$queue_file")
        echo "Queue: $queue_count"
        echo "Progress:"
        for progress_file in "$progress_dir"/*.txt; do
            [ -e "$progress_file" ] || continue
            cat "$progress_file"
        done
        echo "State: $(cat "$pause_state_file")"
        sleep 1
    done
}

toggle_pause() {
    if $paused; then
        paused=false
        echo "Resuming downloads..."
        echo "resumed" > "$pause_state_file"
        pkill -CONT yt-dlp
    else
        paused=true
        echo "Pausing downloads..."
        echo "paused" > "$pause_state_file"
        pkill -STOP yt-dlp
    fi
}

display_status &

while :; do
    counter=$((counter + 1))
    url="$(timeout 1 xsel -b)"
    if [[ "$url" =~ $regex && $(wc -l <<< "$url") -eq 1 ]]; then
        if ! pgrep -f "yt-dlp.*$url" > /dev/null; then
            if ! grep -qF "$url" "/home/lucas/Documentos/scripts/download_videos_terminal.db" && ! grep -qF "$url" "$queue_file"; then
                if [ "$(pgrep -c yt-dlp)" -ge "$max_downloads" ]; then
                    echo "$url" >> "$queue_file"
                    paplay /home/lucas/Documentos/scripts/ok.mp3 &
                else
                    process_url "$url"
                fi
            fi
        else
            echo "O URL já está sendo baixado: $url"
        fi
        xclip -sel clip < /dev/null
    fi

    if read -t 0.1 -n 1 key; then
        if [[ "$key" == "q" ]]; then
            echo "Exiting script..."
            cleanup
        elif [[ "$key" == "p" ]]; then
            toggle_pause
        fi
    fi

    if ! $paused; then
        sleep 0.5
        if [ $counter -ge 10 ]; then
            counter=0
        fi
        process_queue
    else
        sleep 1
    fi
done
