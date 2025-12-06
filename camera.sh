#!/bin/bash
err_count=0
LOCKFILE=/tmp/$(basename "$0").lock

if [ -e "$LOCKFILE" ]; then
    notify-send "Erro: A script da camera já está em execução."
    exit 1
fi

touch "$LOCKFILE"

run_mpv() {
    WAYLAND_DISPLAY=0 mpv --load-scripts=no --cache=no --demuxer-thread=no --no-config --untimed --profile=low-latency --video-sync=desync --hwdec=vaapi --hwdec-software-fallback=no --volume=0 --no-ytdl --geometry=1809x1018 --vo=gpu-next --gpu-api=vulkan --rtsp-transport=udp rtsp://admin:12morango34@192.168.0.3/onvif1 &
    mpv_pid=$!

    if ! timeout 7 xdotool search --sync --name 'H.264 Video, RtspServer_0.0.0.2'; then
        rm -f "$LOCKFILE"
        kill -9 "$mpv_pid" || true
        notify-send "Falha ao iniciar a janela do mpv."
        exit 1
    fi

    while kill -0 "$mpv_pid"; do
        sleep 0.2
    done

    wait "$mpv_pid"    
    mpv_exit_code=$?

    rm -f "$LOCKFILE"

    if [ $mpv_exit_code -ne 0 ]; then
        notify-send "Camera instável.."
        exit $mpv_exit_code
    else
        exit 0
    fi
}

trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

if [ -f '/tmp/camera.sh.ip' ]; then
    rm -f /tmp/camera.sh.ip
    run_mpv
else
    while [ $err_count -le 10 ]; do
        if ! ping -w 1 192.168.0.3 && [ ! $err_count -eq 20 ]; then
            err_count=$((err_count+1))
            new_ip="$(arp-scan --localnet | grep -i 'cc:64:1a:84:b3:87' | awk '{print $1}' | tr -d '[:space:]\n')"
            if [ -n "$new_ip" ]; then
                sed -i "s/192.168.0.3/$new_ip/" "$0"
                touch /tmp/camera.sh.ip
                rm -f "$LOCKFILE"
                exec "$0"
            fi
        else
            run_mpv
        fi
    done
    notify-send "Erro: Nenhum IP encontrado para o MAC address especificado."
    exit 1
fi
