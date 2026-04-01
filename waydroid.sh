#!/bin/bash
LOG_DIR="/tmp/waydroid_script_"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/log_$(date +%H_%M_%S)_$$_$RANDOM.log"
exec > >(tee -a "$LOG_FILE") 2>&1
set -x

notify() {
    if [ "$2" == critical ]; then
        sudo -u lucas XDG_RUNTIME_DIR=/run/user/$(id -u lucas) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u lucas)/bus systemd-run --user --scope notify-send -u critical "$1"
    elif [ -z "$2" ]; then
        sudo -u lucas XDG_RUNTIME_DIR=/run/user/$(id -u lucas) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u lucas)/bus systemd-run --user --scope notify-send "$1"
    fi
}

copy_userdata_to_mem() {
    if [ $copy_IMGs -eq 1 ]; then
    error=0

    src1="/usr/share/waydroid-extra/images/system.img"
    src2="/usr/share/waydroid-extra/images/vendor.img"

    dest="/tmp"

    size1=$(stat -c%s "$src1")
    size2=$(stat -c%s "$src2")
    total=$((size1 + size2))

    (
        pv -n -s "$total" "$src1" > "$dest/system.img"
        [ ${PIPESTATUS[0]} -ne 0 ] && error=1
        pv -n -s "$total" "$src2" > "$dest/vendor.img"
        [ ${PIPESTATUS[0]} -ne 0 ] && error=1
    ) 2>&1 | yad --progress \
        --title="Waydroid" \
        --center \
        --width=400 \
        --text="Copiando imagens para memória..." \
        --auto-close \
        --auto-kill

        cd /usr/share/waydroid-extra/images/ || error=1

        mv system.img system.img_bkp || error=1
        mv vendor.img vendor.img_bkp || error=1

        ln -sf /tmp/system.img system.img || error=1
        ln -sf /tmp/vendor.img vendor.img || error=1

        if [ $error -eq 0 ]; then
            touch /tmp/waydroid_IMGs_on_mem
        fi
    fi

    if [[ -e ~/.local/share/waydroid_bkp || -e /dev/shm/waydroid ]]; then
        msg="Erro: "
        exists=""

        if [[ -e /home/lucas/.local/share/waydroid_bkp ]]; then
            exists+="/home/lucas/.local/share/waydroid_bkp"
        fi

        if [[ -e /home/lucas/.local/share/waydroid_bkp && -e /dev/shm/waydroid ]]; then
            exists+=", "
        fi

        if [[ -e /dev/shm/waydroid ]]; then
            exists+="/dev/shm/waydroid"
        fi

        msg+="$exists já existe(m). Remova manualmente com cuidado antes de continuar."
        notify "$msg" critical
        exit 1
    fi

    umount /home/lucas/.local/share/waydroid/data/media

    cp -a /home/lucas/.local/share/waydroid /home/lucas/.local/share/waydroid_bkp

    src_size=$(du -sb /home/lucas/.local/share/waydroid | awk '{print $1}')

    (
        cd /home/lucas/.local/share
        tar cf - waydroid | pv -n -s "$src_size" | tar xf - -C /dev/shm/
    ) 2>&1 | sudo -u lucas XDG_RUNTIME_DIR=/run/user/$(id -u lucas) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u lucas)/bus yad --progress \
        --title="Waydroid" \
        --center \
        --width=400 \
        --text="Copiando dados para a memória.." \
        --percentage=0 \
        --auto-close \
        --auto-kill

    if [[ "${PIPESTATUS[2]}" -ne 0 ]]; then
        erro_msg="Erro ao copiar arquivos de /home/lucas/.local/share/waydroid para /dev/shm/waydroid."
        notify "$erro_msg" critical
        exit 1
    fi

    rm -rf /home/lucas/.local/share/waydroid
    ln -s /dev/shm/waydroid /home/lucas/.local/share/waydroid

    src_count=$(find /home/lucas/.local/share/waydroid_bkp -type f | wc -l)
    dst_count=$(find /dev/shm/waydroid -type f | wc -l)
    src_size=$(du -sb /home/lucas/.local/share/waydroid_bkp | awk '{print $1}')
    dst_size=$(du -sb /dev/shm/waydroid | awk '{print $1}')

    if [[ "$src_count" -ne "$dst_count" || "$src_size" -ne "$dst_size" ]]; then
        erro_cmd=""

        rm -rf /dev/shm/waydroid
        if [[ $? -ne 0 ]]; then
            erro_cmd="rm -rf /dev/shm/waydroid"
        fi

        rm /home/lucas/.local/share/waydroid
        if [[ $? -ne 0 && -z "$erro_cmd" ]]; then
            erro_cmd="rm /home/lucas/.local/share/waydroid"
        fi

        mv /home/lucas/.local/share/waydroid_bkp /home/lucas/.local/share/waydroid
        if [[ $? -ne 0 && -z "$erro_cmd" ]]; then
            erro_cmd="mv /home/lucas/.local/share/waydroid_bkp /home/lucas/.local/share/waydroid"
        fi

        if [[ -z "$erro_cmd" ]]; then
            notify "Erro na cópia! Dados revertidos com sucesso." critical
        else
            notify "Erro na cópia! Verifique manualmente." critical
        fi

        mkdir -p /home/lucas/.local/share/waydroid/data/media

        if ! mount --bind /home/lucas/.local/share/waydroid_media /home/lucas/.local/share/waydroid/data/media || \
           ! mountpoint -q /home/lucas/.local/share/waydroid/data/media; then
            notify "Erro ao restaurar bind após rollback"
        fi

        exit 1
    fi

    mkdir -p /dev/shm/waydroid/data/media

    if ! mount --bind /home/lucas/.local/share/waydroid_media /dev/shm/waydroid/data/media; then
        notify "Erro ao montar bind (memória)" critical
        exit 1
    fi

    if ! mountpoint -q /dev/shm/waydroid/data/media; then
        notify "Bind na memória não foi aplicado corretamente" critical
        exit 1
    fi
}

copy_userdata_to_disk() {

    if [ -f '/tmp/waydroid_IMGs_on_mem' ]; then
        rm '/tmp/waydroid_IMGs_on_mem'

        rm /tmp/vendor.img /tmp/system.img

        cd /usr/share/waydroid-extra/images/

        if [[ -L "system.img" ]]; then
            rm system.img
        else
            notify "system.img não era symlink. Não removido." critical
            exit 1
        fi

        if [[ -L "vendor.img" ]]; then
            rm vendor.img
        else
            notify "vendor.img não era symlink. Não removido." critical
            exit 1
        fi

        mv system.img_bkp system.img
        mv vendor.img_bkp vendor.img
    fi

    umount /dev/shm/waydroid/data/media


    if [ -L "/home/lucas/.local/share/waydroid" ]; then
        rm -f /home/lucas/.local/share/waydroid
    else
        notify "Erro na restauração! Verifique manualmente. Dados ainda na memória." critical
        exit 1
    fi

    src_size=$(du -sb /dev/shm/waydroid | awk '{print $1}')

    (
        cd /dev/shm
        tar cf - waydroid | pv -n -s "$src_size" | tar xf - -C /home/lucas/.local/share/
    ) 2>&1 | sudo -u lucas XDG_RUNTIME_DIR=/run/user/$(id -u lucas) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u lucas)/bus yad --progress \
        --title="Waydroid" \
        --center \
        --width=400 \
        --text="Retornando dados para o disco.." \
        --percentage=0 \
        --auto-close \
        --auto-kill

    src_count=$(find /dev/shm/waydroid -type f | wc -l)
    dst_count=$(find /home/lucas/.local/share/waydroid -type f | wc -l)
    src_size=$(du -sb /dev/shm/waydroid | awk '{print $1}')
    dst_size=$(du -sb /home/lucas/.local/share/waydroid | awk '{print $1}')

    if [[ "$src_count" -ne "$dst_count" || "$src_size" -ne "$dst_size" ]]; then
        erro_cmd=""

        rm -rf /home/lucas/.local/share/waydroid
        if [[ $? -ne 0 ]]; then
            erro_cmd="rm -rf /home/lucas/.local/share/waydroid"
        fi

        notify "Erro na restauração! Verifique manualmente." critical
    else
        mkdir -p /home/lucas/.local/share/waydroid/data/media

        if ! mount --bind /home/lucas/.local/share/waydroid_media /home/lucas/.local/share/waydroid/data/media; then
            notify "Erro ao montar bind" critical
            exit 1
        fi

        if ! mountpoint -q /home/lucas/.local/share/waydroid/data/media; then
            notify "Bind não foi aplicado corretamente" critical
            exit 1
        fi

        notify "Dados retornados para o disco com sucesso."

        rm -rf /dev/shm/waydroid
        rm -rf /home/lucas/.local/share/waydroid_bkp
    fi
}

if systemctl is-active "waydroid-container.service" &> /dev/null || \
   lsns | grep -E 'android|lineageos' &> /dev/null; then

    pkill --cgroup=/lxc.payload.waydroid2
    pkill -9 lxc-start
    systemctl stop waydroid-container.service

    if [ "$data_in_mem" = 'true' ]; then
        copy_userdata_to_disk
        data_in_mem=false
    fi

else
    choice=$(sudo -u lucas XDG_RUNTIME_DIR=/run/user/$(id -u lucas) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u lucas)/bus yad --title="Waydroid" \
        --center \
        --question \
        --text="Copiar dados para a memória?" \
        --button=Não:1 \
        --button=Sim:0 \
        --button='Sim + IMGs':3 \
        --button=Cancelar:2)

    choice=$?

    case "$choice" in
        0)
            copy_IMGs=0
            copy_userdata_to_mem
            data_in_mem=true
            ;;

        3)
            copy_IMGs=1
            copy_userdata_to_mem
            data_in_mem=true
            ;;

        2)
            exit
            ;;

        1|"")
            data_in_mem=false
            ;;
    esac

    systemctl restart waydroid-container.service
    pkill -9 adb

    sudo -u lucas XDG_RUNTIME_DIR=/run/user/$(id -u lucas) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u lucas)/bus systemd-run --user --scope waydroid show-full-ui

    pkill --cgroup=/lxc.payload.waydroid2
    pkill -9 lxc-start
    systemctl stop "waydroid-container.service"

    if [ "$data_in_mem" = 'true' ]; then
        copy_userdata_to_disk
        data_in_mem=false
    fi
fi
