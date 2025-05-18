#!/bin/bash

# Arquivos temporários para armazenar as médias de ping
PING_FILE_1="/tmp/ping_8.8.8.8.txt"
PING_FILE_2="/tmp/ping_192.168.0.1.txt"

# Endereços de destino
ADDRESS_1="8.8.8.8"
ADDRESS_2="192.168.0.1"

# Loop infinito
while true; do
    # Executa o fping para os dois endereços
    fping -C 4 -q $ADDRESS_1 $ADDRESS_2 2>&1 | while read -r line; do
        # Extrai o endereço e os tempos de resposta
        address=$(echo "$line" | awk '{print $1}')
        latencies=$(echo "$line" | awk '{for (i=2; i<=NF; i++) if ($i != "-") print $i}')

        # Calcula a média das latências
        if [[ -n "$latencies" ]]; then
            avg_latency=$(echo "$latencies" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count; else print "N/A"}')
        else
            avg_latency="N/A"
        fi

        # Salva no arquivo correspondente
        if [[ "$address" == "$ADDRESS_1" ]]; then
            echo "$avg_latency" > "$PING_FILE_1"
        elif [[ "$address" == "$ADDRESS_2" ]]; then
            echo "$avg_latency" > "$PING_FILE_2"
        fi
    done

    # Aguarda 2 segundos antes de repetir
    sleep 2
done
