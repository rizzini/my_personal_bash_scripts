#!/bin/bash
error_ionice=0
error_renice=0
if [ "$EUID" -ne 0 ]; then
    xhost +
    pkexec /bin/bash -c 'DISPLAY=:0 /home/lucas/Documentos/scripts/proc.sh' & exit 0
fi
LOG_FILE="/tmp/process_priorities.log"
HISTORICO_BUSCAS="/home/lucas/Documentos/scripts/proc_historico_buscas.txt"
salvar_busca_no_historico() {
    local busca="$1"
    # Verifica se a busca não está vazia e se o histórico já não contém a busca
    if [[ -n "$busca" ]]; then
        if ! grep -Fxq "$busca" "$HISTORICO_BUSCAS" 2>/dev/null; then
            echo "$busca" >> "$HISTORICO_BUSCAS"
        fi
    fi
}
carregar_historico() {
    if [ -f "$HISTORICO_BUSCAS" ]; then
        # Remove linhas vazias e retorna o histórico formatado
        grep -v '^[[:space:]]*$' "$HISTORICO_BUSCAS" | tr '\n' '!' | sed 's/!$//'
    else
        echo ""
    fi
}
remover_do_historico() {
    local historico_selecionado=$(yad --title="Remover do Histórico" \
        --width=300 --center --on-top \
        --form --field="Selecione para remover:CB" "Nenhum!$(carregar_historico)" \
        --button="Remover:0" \
        --buttons-layout=center)

    if [ $? -ne 0 ] || [ -z "$historico_selecionado" ] || [ "$historico_selecionado" == "Nenhum" ]; then
        return
    fi

    sed -i "/^$historico_selecionado$/d" "$HISTORICO_BUSCAS"
}
selecionar_opcao() {
    local titulo="$1"
    local largura="$2"
    local altura="$3"
    local colunas="$4"
    local botoes="$5"
    yad --title="$titulo" --width="$largura" --height="$altura" --center --on-top \
        --list --radiolist --column="Selecionar" --column="$colunas" $botoes
}
menu_principal() {
    opcao=$(yad --title="Controle de Prioridades de Processos" \
        --center --on-top \
        --width=300 --height=150 \
        --list --radiolist \
        --column="Selecionar" --column="Opção" \
        TRUE "Alterar prioridade com ambos" \
        FALSE "Restaurar permissões padrão" \
        --button="OK:0" \
        --buttons-layout=center)

    if [ $? -ne 0 ]; then
        exit 0  # Sai do script
    fi

    echo "$opcao"
}
obter_processos() {
    ps -eo pid,user,comm --no-headers | awk '{print $1 "\t" $2 "\t$3}' | sort -k3
}
configurar_ambos() {
    ULTIMO_FILTRO="/tmp/ultimo_filtro.txt"

    if [ -f "$ULTIMO_FILTRO" ]; then
        filtro_anterior=$(cat "$ULTIMO_FILTRO")
    else
        filtro_anterior="*"  # Valor padrão
    fi

    while true; do
        historico=$(carregar_historico)

        filtro=$(yad --title="Filtro de Processos" \
            --width=400 --center --on-top \
            --form \
            --field="Digite parte do nome do processo ou use * para todos:" "$filtro_anterior" \
            --field="Histórico de buscas:CB" "Nenhum!$historico" \
            --button="OK:0" \
            --buttons-layout=center \
            --bind="Escape:close")

        if [ $? -eq 1 ]; then

            historico_selecionado=$(echo "$filtro" | awk -F'|' '{print $2}')
            
            if [ -z "$historico_selecionado" ]; then
                historico_selecionado=$(echo "$filtro" | awk -F'|' '{print $1}')
            fi

            historico_selecionado=$(echo "$historico_selecionado" | sed 's/^ *//;s/ *$//')

            if [ "$historico_selecionado" != "Nenhum" ] && [ -n "$historico_selecionado" ]; then
                sed -i "/^$historico_selecionado$/d" "$HISTORICO_BUSCAS"
            fi
            continue  # Volta para o início do loop para recarregar o formulário
        fi

        if [ $? -ne 0 ]; then
            break  # Sai do loop e retorna ao menu principal
        fi

        filtro_digitado=$(echo "$filtro" | awk -F'|' '{print $1}')
        historico_selecionado=$(echo "$filtro" | awk -F'|' '{print $2}')

        historico_selecionado=$(echo "$historico_selecionado" | sed 's/^ *//;s/ *$//')

        if [ "$historico_selecionado" != "Nenhum" ] && [ -n "$historico_selecionado" ]; then
            filtro="$historico_selecionado"
        else
            filtro="$filtro_digitado"
        fi

        if [ -z "$filtro" ]; then
            filtro="*"
        fi

        echo "$filtro" > "$ULTIMO_FILTRO"

        if [ "$filtro" != "*" ] && [ "$filtro" != "Nenhum" ]; then
            salvar_busca_no_historico "$filtro"
        fi

        if [ "$filtro" == "*" ]; then
            nomes_processos=$(ps -eo pid,comm --no-headers | sort -k2 | awk '{print $1 "|" $2}' | tr '\n' '!' | sed 's/!$//')
        else
            nomes_processos=$(ps -eo pid,comm --no-headers | awk -v filtro="$filtro" '$2 ~ filtro {print $1 "|" $2}' | sort -k2 | tr '\n' '!' | sed 's/!$//')
        fi

        if [ -z "$nomes_processos" ]; then
            yad --title="Erro" --width=300 --height=200 --center --on-top --error \
                --text="Nenhum processo encontrado contendo '$filtro'." \
                --button="OK:0" \
                --buttons-layout=center
            continue  # Volta para a etapa anterior
        fi
        num_processos=$(echo "$nomes_processos" | tr '!' '\n' | wc -l)

        if [ "$num_processos" -le 5 ]; then
            processos=$(echo "$nomes_processos" | tr '!' '\n' | awk -F'|' '{print "TRUE", $1 "|" $2}' | tr '\n' ' ')
        else
            processos=$(echo "$nomes_processos" | tr '!' '\n' | awk -F'|' '{print "FALSE", $1 "|" $2}' | tr '\n' ' ')
        fi

        processos_selecionados=$(yad --title="Seleção de Processos" \
            --width=500 --height=400 \
            --center --on-top \
            --list --checklist \
            --column="Selecionar" --column="PID|Nome do Processo" \
            $processos \
            --button="OK:0" \
            --buttons-layout=center \
            --bind="Escape:close")

        if [ $? -ne 0 ] || [ -z "$processos_selecionados" ]; then
            break  # Sai do loop e retorna ao menu principal
        fi
        processos=$(echo "$processos_selecionados" | sed 's/|/ /g')
        while true; do
            classe=$(yad --title="Configuração do ionice" \
                --width=300 --height=200 \
                --center --on-top \
                --list --radiolist \
                --column="Selecionar" --column="Classe" \
                FALSE "None (0)" \
                TRUE "Real-time (1)" \
                FALSE "Best-effort (2)" \
                FALSE "Idle (3)" \
                --button="OK:0" \
                --buttons-layout=center \
                --bind="Escape:close")

            if [ $? -ne 0 ] || [ -z "$classe" ]; then
                break
            fi
            if [ "$classe" != 'TRUE|Idle (3)|' ];then
                nivel=$(yad --title="Nível de Prioridade" \
                    --width=150 --height=300 \
                    --center --on-top \
                    --button="OK:0" \
                    --buttons-layout=center \
                    --scale --text="Selecione o nível de prioridade (0-7, onde 0 é o mais alto):" \
                    --min-value=0 --max-value=7 --value=0 --step=1 --vertical \
                    --orientation=vert)
                renice_start_value=-20
                if [ $? -ne 0 ] || [ -z "$nivel" ]; then
                    return
                fi
            else
                renice_start_value=20
            fi
            prioridade=$(yad --title="Configuração do renice" \
                --width=150 --height=300 \
                --center --on-top \
                --scale --text="Selecione o valor de prioridade (-20 a 19, onde -20 é o mais alto):" \
                --min-value=-20 --max-value=20 --value="$renice_start_value" --step=1 --vertical \
                --orientation=vert \
                --button="OK:0" \
                --buttons-layout=center \
                --bind="Escape:close")

            if [ $? -ne 0 ] || [ -z "$prioridade" ]; then
                continue  # Volta para a etapa anterior
            fi
                for processo in $processos; do
            pid=$(ps -eo pid,comm --no-headers | awk -v proc="$processo" 'tolower($2) == tolower(proc) {print $1; exit}')
            if [ -n "$pid" ]; then
                sed -i "/^$pid /d" $LOG_FILE

                original_class=$(ionice -p $pid | awk '{print $1}' | tr -d ':')
                original_level=$(ionice -p $pid | awk '{print $3}')
                echo "$pid ionice $original_class $original_level" >> $LOG_FILE
                if [ -z $nivel ]; then
                    if ! ionice -c ${classe: -3:1} -p $pid; then
                        error_ionice=1
                    fi
                else
                    if ! ionice -c ${classe: -3:1} -n $nivel -p $pid; then
                        error_ionice=1
                    fi
                fi
            fi
        done
            for processo in $processos; do
                pid=$(echo "$processo" | cut -d'|' -f1)  # Extrai o PID corretamente usando 'cut'
                if [[ -n "$pid" && ! "$pid" =~ [^0-9] ]]; then
                    # Remove entradas antigas do arquivo de log para o mesmo PID
                    sed -i "/^$pid /d" $LOG_FILE

                    # Obtém a prioridade original do renice
                    original_priority=$(ps -o ni -p $pid --no-headers | tr -d ' ')
                    echo "$pid renice $original_priority $prioridade" >> $LOG_FILE

                    # Aplica a configuração de renice
                    if ! renice -n $prioridade -p $pid; then
                        error_renice=1
                    fi

                fi
            done

            break
        done
        exit 0;
    done
}
restaurar_permissoes() {
    if [ ! -f $LOG_FILE ]; then
        yad --title="Erro" --width=300 --center --on-top --error --text="Nenhuma alteração registrada para restaurar."
        return
    fi

    while read -r line; do
        pid=$(echo $line | awk '{print $1}')
        tipo=$(echo $line | awk '{print $2}')
        if [ "$tipo" == "ionice" ]; then
            classe=$(echo $line | awk '{print $3}')
            nivel=$(echo $line | awk '{print $4}')
            echo "ionice -c $classe -n $nivel -p $pid"
            ionice -c $classe -n $nivel -p $pid
        elif [ "$tipo" == "renice" ]; then
            prioridade=$(echo $line | awk '{print $3}')
            echo "renice $prioridade -p $pid"
            renice $prioridade -p $pid
        fi
    done < $LOG_FILE

     > $LOG_FILE
#     yad --title="Sucesso" --width=300 --center --on-top --info --text="Permissões restauradas com sucesso!"
}
while true; do
    opcao=$(menu_principal)

    if [ -z "$opcao" ]; then
        exit 0
    fi
    opcao=$(echo "$opcao" | awk -F'|' '{print $2}')
    case $opcao in
        "Alterar prioridade com ambos")
            configurar_ambos
            ;;
        "Restaurar permissões padrão")
            restaurar_permissoes
            ;;
    esac
done
