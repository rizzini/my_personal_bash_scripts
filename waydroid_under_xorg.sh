#!/bin/bash

copy_userdata_to_mem() {
    if [[ -e ~/.local/share/waydroid_bkp || -e /dev/shm/waydroid ]]; then
        msg="Erro: "
        exists=""
        if [[ -e ~/.local/share/waydroid_bkp ]]; then
            exists+="~/.local/share/waydroid_bkp"
        fi
        if [[ -e ~/.local/share/waydroid_bkp && -e /dev/shm/waydroid ]]; then
            exists+=", "
        fi
        if [[ -e /dev/shm/waydroid ]]; then
            exists+="/dev/shm/waydroid"
        fi
        msg+="$exists já existe(m). Remova manualmente com cuidado antes de continuar."
        notify-send -u critical "$msg"
        echo "$msg Abortando."
        exit 1
    fi
    sudo cp -a --preserve=all /home/lucas/.local/share/waydroid /home/lucas/.local/share/waydroid_bkp

    src_size=$(sudo du -sb /home/lucas/.local/share/waydroid | awk '{print $1}')
    (
        cd /home/lucas/.local/share
        sudo tar cf - waydroid | pv -n -s "$src_size" | sudo tar xf - -C /dev/shm/
    ) 2>&1 | \
    yad --progress --title="Waydroid" --center --width=400 \
        --text="Copiando dados para a memória.." \
        --percentage=0 --auto-close --auto-kill

    if [[ "${PIPESTATUS[2]}" -ne 0 ]]; then
        erro_msg="Erro ao copiar arquivos de /home/lucas/.local/share/waydroid para /dev/shm/waydroid."
        notify-send -u critical "$erro_msg"
        echo "$erro_msg"
        exit 1
    fi

    sudo rm -rf /home/lucas/.local/share/waydroid
    sudo ln -s /dev/shm/waydroid /home/lucas/.local/share/waydroid

    src_count=$(sudo find /home/lucas/.local/share/waydroid_bkp -type f | wc -l)
    dst_count=$(sudo find /dev/shm/waydroid -type f | wc -l)
    src_size=$(sudo du -sb /home/lucas/.local/share/waydroid_bkp | awk '{print $1}')
    dst_size=$(sudo du -sb /dev/shm/waydroid | awk '{print $1}')

    if [[ "$src_count" -ne "$dst_count" || "$src_size" -ne "$dst_size" ]]; then
        erro_cmd=""
        sudo rm -rf /dev/shm/waydroid
        if [[ $? -ne 0 ]]; then
            erro_cmd="sudo rm -rf /dev/shm/waydroid"
        fi
        rm /home/lucas/.local/share/waydroid
        if [[ $? -ne 0 && -z "$erro_cmd" ]]; then
            erro_cmd="rm /home/lucas/.local/share/waydroid"
        fi
        sudo mv /home/lucas/.local/share/waydroid_bkp /home/lucas/.local/share/waydroid
        if [[ $? -ne 0 && -z "$erro_cmd" ]]; then
            erro_cmd="sudo mv /home/lucas/.local/share/waydroid_bkp /home/lucas/.local/share/waydroid"
        fi
        if [[ -z "$erro_cmd" ]]; then
            notify-send -u critical "Erro na cópia! Dados revertidos com sucesso."
            echo "Erro na cópia! Dados revertidos com sucesso."
        else
            notify-send -u critical "Erro na cópia! Verifique manualmente."
            echo "Erro na cópia! Verifique manualmente."
        fi
        exit 1
    fi

}
copy_userdata_to_disk() {
    rm -f /home/lucas/.local/share/waydroid

    src_size=$(sudo du -sb /dev/shm/waydroid | awk '{print $1}')
    (
        cd /dev/shm
        sudo tar cf - waydroid | pv -n -s "$src_size" | sudo tar xf - -C /home/lucas/.local/share/
    ) 2>&1 | \
    yad --progress --title="Waydroid" --center --width=400 \
        --text="Retornando dados para o disco.." \
        --percentage=0 --auto-close --auto-kill

    src_count=$(sudo find /dev/shm/waydroid -type f | wc -l)
    dst_count=$(sudo find /home/lucas/.local/share/waydroid -type f | wc -l)
    src_size=$(sudo du -sb /dev/shm/waydroid | awk '{print $1}')
    dst_size=$(sudo du -sb /home/lucas/.local/share/waydroid | awk '{print $1}')

    if [[ "$src_count" -ne "$dst_count" || "$src_size" -ne "$dst_size" ]]; then
        erro_cmd=""
        sudo rm -rf /home/.lucas/.local/share/waydroid
        if [[ $? -ne 0 ]]; then
            erro_cmd="sudo rm -rf /home/lucas/.local/share/waydroid"
        fi
        notify-send -u critical "Erro na restauração! Verifique manualmente."
        echo "Erro na restauração! Verifique manualmente."
        exit 1
    else
        notify-send "Waydroid encerrado com sucesso."
        sudo rm -rf /dev/shm/waydroid
        sudo rm -rf /home/lucas/.local/share/waydroid_bkp
    fi
}


if systemctl is-active "waydroid-container.service" &> /dev/null || lsns | grep -E 'android|lineageos' &> /dev/null || pgrep weston; then
    pkill -9 weston
    sudo pkill --cgroup=/lxc.payload.waydroid2
    sudo pkill -9 lxc-start
    sudo systemctl stop "waydroid-container.service"
    if [ "$data_in_mem" = 'true' ]; then
        copy_userdata_to_disk
        data_in_mem=false
    fi
else
    if yad --title="Waydroid" --center --question --text="Copiar dados para a memória?" \
        --button=Não:1 --button=Sim:0 --button=Cancelar:2; then
        copy_userdata_to_mem
        data_in_mem=true
    else
        if [[ $? -eq 2 ]]; then
            echo "Operação cancelada pelo usuário."
            exit
        fi
        data_in_mem=false
    fi
    sudo systemctl restart "waydroid-container.service"
    pkill -9 adb
    weston --width=700 --height=900 --xwayland --idle-time=0 &> /dev/null &

    timeout=20
    while [[ $timeout -gt 0 ]]; do
        wmctrl -l | grep -q "Weston Compositor" && break
        sleep 1
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
    sleep 1
    DISPLAY=':1' alacritty -e bash -c "sleep 1; WAYLAND_DISPLAY='wayland-1' XDG_SESSION_TYPE='wayland' DISPLAY=':1' /usr/bin/waydroid show-full-ui" &> /dev/null &
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
    if [ "$data_in_mem" = 'true' ]; then
        copy_userdata_to_disk
        data_in_mem=false
    fi
fi
