#!/bin/bash

# Cria um arquivo temporário de forma segura
temp_file=$(mktemp)

# Garante que o arquivo temporário será removido ao sair do script
trap 'rm -f "$temp_file"' EXIT

# Verifica se o comando colordiff está instalado
if ! command -v colordiff &> /dev/null; then
    /usr/bin/notify-send -u critical 'O comando colordiff não está instalado.';
    exit 1
fi

# Baixa o arquivo para o local temporário
if ! wget -q https://raw.githubusercontent.com/Digitalone1/EasyEffects-Presets/master/LoudnessEqualizer.json -O "$temp_file"; then
    /usr/bin/notify-send -u critical 'Erro ao baixar o arquivo LoudnessEqualizer.json';
    exit 1
fi

# Compara o arquivo baixado com o existente
if ! diff -q "$temp_file" /home/lucas/.config/easyeffects/output/LoudnessEqualizer.json &> /dev/null; then
    # Substitui o arquivo existente
    if mv -f "$temp_file" /home/lucas/.config/easyeffects/output/LoudnessEqualizer.json; then
        /usr/bin/notify-send -u normal 'LoudnessEqualizer atualizado para a versão mais recente';
    else
        /usr/bin/notify-send -u critical 'Erro ao atualizar o LoudnessEqualizer';
        exit 1
    fi
else
    /usr/bin/notify-send -u normal 'LoudnessEqualizer já está na versão mais recente.';
fi