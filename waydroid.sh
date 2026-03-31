#!/bin/bash
#usar rsync para copyar somente arquivos modificados de volta para o disco.. usar backup como base
LOG_DIR="/tmp/waydroid_script_"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/log_$(date +%H_%M_%S)_$$_$RANDOM.log"
exec > >(tee -a "$LOG_FILE") 2>&1
set -x

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

        sudo mv system.img system.img_bkp || error=1
        sudo mv vendor.img vendor.img_bkp || error=1

        sudo ln -sf /tmp/system.img system.img || error=1
        sudo ln -sf /tmp/vendor.img vendor.img || error=1

        if [ $error -eq 0 ]; then
            touch /tmp/waydroid_IMGs_on_mem
        fi
    fi


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

    sudo umount /home/lucas/.local/share/waydroid/data/media

    sudo cp -a --preserve=all /home/lucas/.local/share/waydroid /home/lucas/.local/share/waydroid_bkp

    src_size=$(sudo du -sb /home/lucas/.local/share/waydroid | awk '{print $1}')

    (
        cd /home/lucas/.local/share
        sudo tar cf - waydroid | pv -n -s "$src_size" | sudo tar xf - -C /dev/shm/
    ) 2>&1 | yad --progress \
        --title="Waydroid" \
        --center \
        --width=400 \
        --text="Copiando dados para a memória.." \
        --percentage=0 \
        --auto-close \
        --auto-kill

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

        sudo mkdir -p /home/lucas/.local/share/waydroid/data/media

        if ! sudo mount --bind /home/lucas/.local/share/waydroid_media /home/lucas/.local/share/waydroid/data/media || \
           ! mountpoint -q /home/lucas/.local/share/waydroid/data/media; then
            notify-send -u critical "Erro ao restaurar bind após rollback"
        fi

        exit 1
    fi

    sudo mkdir -p /dev/shm/waydroid/data/media

    if ! sudo mount --bind /home/lucas/.local/share/waydroid_media /dev/shm/waydroid/data/media; then
        notify-send -u critical "Erro ao montar bind (memória)"
        exit 1
    fi

    if ! mountpoint -q /dev/shm/waydroid/data/media; then
        notify-send -u critical "Bind na memória não foi aplicado corretamente"
        exit 1
    fi
}

copy_userdata_to_disk() {

    if [ -f '/tmp/waydroid_IMGs_on_mem' ]; then
        rm '/tmp/waydroid_IMGs_on_mem'

        rm /tmp/vendor.img /tmp/system.img

        cd /usr/share/waydroid-extra/images/

        if [[ -L "system.img" ]]; then
            sudo rm system.img
        else
            notify-send -u critical "system.img não era symlink. Não removido."
            exit 1
        fi

        if [[ -L "vendor.img" ]]; then
            sudo rm vendor.img
        else
            notify-send -u critical "vendor.img não era symlink. Não removido."
            exit 1
        fi

        sudo mv system.img_bkp system.img
        sudo mv vendor.img_bkp vendor.img
    fi

    sudo umount /dev/shm/waydroid/data/media

    rm -f /home/lucas/.local/share/waydroid

    src_size=$(sudo du -sb /dev/shm/waydroid | awk '{print $1}')

    (
        cd /dev/shm
        sudo tar cf - waydroid | pv -n -s "$src_size" | sudo tar xf - -C /home/lucas/.local/share/
    ) 2>&1 | yad --progress \
        --title="Waydroid" \
        --center \
        --width=400 \
        --text="Retornando dados para o disco.." \
        --percentage=0 \
        --auto-close \
        --auto-kill

    src_count=$(sudo find /dev/shm/waydroid -type f | wc -l)
    dst_count=$(sudo find /home/lucas/.local/share/waydroid -type f | wc -l)
    src_size=$(sudo du -sb /dev/shm/waydroid | awk '{print $1}')
    dst_size=$(sudo du -sb /home/lucas/.local/share/waydroid | awk '{print $1}')

    if [[ "$src_count" -ne "$dst_count" || "$src_size" -ne "$dst_size" ]]; then
        erro_cmd=""

        sudo rm -rf /home/lucas/.local/share/waydroid
        if [[ $? -ne 0 ]]; then
            erro_cmd="sudo rm -rf /home/lucas/.local/share/waydroid"
        fi

        notify-send -u critical "Erro na restauração! Verifique manualmente."
    else
        sudo mkdir -p /home/lucas/.local/share/waydroid/data/media

        if ! sudo mount --bind /home/lucas/.local/share/waydroid_media /home/lucas/.local/share/waydroid/data/media; then
            notify-send -u critical "Erro ao montar bind"
            exit 1
        fi

        if ! mountpoint -q /home/lucas/.local/share/waydroid/data/media; then
            notify-send -u critical "Bind não foi aplicado corretamente"
            exit 1
        fi

        notify-send "Waydroid encerrado com sucesso."

        sudo rm -rf /dev/shm/waydroid
        sudo rm -rf /home/lucas/.local/share/waydroid_bkp
    fi
}

if systemctl is-active "waydroid-container.service" &> /dev/null || \
   lsns | grep -E 'android|lineageos' &> /dev/null; then

    sudo pkill --cgroup=/lxc.payload.waydroid2
    sudo pkill -9 lxc-start
    sudo systemctl stop waydroid-container.service

    if [ "$data_in_mem" = 'true' ]; then
        copy_userdata_to_disk
        data_in_mem=false
    fi

else
    choice=$(yad --title="Waydroid" \
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
            echo "Operação cancelada pelo usuário."
            exit
            ;;

        1|"")
            data_in_mem=false
            ;;
    esac

    sudo systemctl restart waydroid-container.service
    pkill -9 adb

    /usr/bin/waydroid show-full-ui

    sudo pkill --cgroup=/lxc.payload.waydroid2
    sudo pkill -9 lxc-start
    sudo systemctl stop "waydroid-container.service"

    if [ "$data_in_mem" = 'true' ]; then
        copy_userdata_to_disk
        data_in_mem=false
    fi
fi
