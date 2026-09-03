#!/bin/bash

LOG_FILE="/var/log/auth.log"
SHOW_LIMIT=""
OUTPUT_FILE=""
FAILED_ONLY=false
DATE_FILTER=""
TOP_COUNT=""
PORT_FILTER=""
REVERSE=false
EXCLUDE_IP=""
BEFORE_DATE=""
PROTOCOL_FILTER=""
SHOW_ANOMALIES=false

RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "Использование: chinp [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  -h, --help              Показать эту справку"
    echo "  -n, --limit N           Ограничить вывод N записями"
    echo "  -o, --output FILE       Сохранить результат в файл"
    echo "  -f, --failed-only       Показать только неудачные попытки входа"
    echo "  -d, --date DATE         Показать IP за конкретную дату (2024-01-15)"
    echo "  -t, --top N             Показать топ N самых частых IP"
    echo "  -p, --port PORT         Фильтр по порту (22, 2222)"
    echo "  -r, --reverse           Показать с конца (последние заходы)"
    echo "  -e, --exclude IP        Исключить IP из вывода"
    echo "  -b, --before DATE       Показать IP до даты (2024-01-15)"
    echo "  --protocol TYPE         Фильтр по протоколу (ssh, ftp)"
    echo "  --anomalies             Показать аномальную активность"
    echo ""
    echo "Примеры:"
    echo "  chinp -n 10                        Показать первые 10 IP"
    echo "  chinp -f                           Только неудачные попытки"
    echo "  chinp -d 2024-01-15                За конкретную дату"
    echo "  chinp -t 5                         Топ 5 самых частых IP"
    echo "  chinp -p 22                        Только SSH подключения"
    echo "  chinp -r                           Последние заходы"
    echo "  chinp -e 192.168.1.1               Исключить IP"
    echo "  chinp -b 2024-01-15                До определенной даты"
    echo "  chinp --protocol ssh               Только SSH"
    echo "  chinp --anomalies                  Аномальная активность"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -n|--limit)
            SHOW_LIMIT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -f|--failed-only)
            FAILED_ONLY=true
            shift
            ;;
        -d|--date)
            DATE_FILTER="$2"
            shift 2
            ;;
        -t|--top)
            TOP_COUNT="$2"
            shift 2
            ;;
        -p|--port)
            PORT_FILTER="$2"
            shift 2
            ;;
        -r|--reverse)
            REVERSE=true
            shift
            ;;
        -e|--exclude)
            EXCLUDE_IP="$2"
            shift 2
            ;;
        -b|--before)
            BEFORE_DATE="$2"
            shift 2
            ;;
        --protocol)
            PROTOCOL_FILTER="$2"
            shift 2
            ;;
        --anomalies)
            SHOW_ANOMALIES=true
            shift
            ;;
        *)
            echo -e "${RED}Неизвестная опция: $1${NC}" >&2
            usage
            ;;
    esac
done

if [[ ! -f "$LOG_FILE" ]]; then
    echo -e "${RED}Ошибка: файл $LOG_FILE не найден${NC}" >&2
    exit 1
fi

if [[ ! -r "$LOG_FILE" ]]; then
    echo -e "${RED}Ошибка: недостаточно прав для чтения $LOG_FILE${NC}" >&2
    echo -e "${RED}Запустите с sudo${NC}" >&2
    exit 1
fi

print_output() {
    local line="$1"
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$line" >> "$OUTPUT_FILE"
    else
        echo "$line"
    fi
}

get_all_ips() {
    local lines=$(cat "$LOG_FILE")
    
    if [[ -n "$DATE_FILTER" ]]; then
        lines=$(echo "$lines" | grep "$DATE_FILTER")
    elif [[ -n "$BEFORE_DATE" ]]; then
        lines=$(echo "$lines" | awk -v date="$BEFORE_DATE" '$0 < date')
    fi
    
    if [[ "$FAILED_ONLY" == true ]]; then
        lines=$(echo "$lines" | grep -iE 'failed|invalid|error|refused|denied')
    fi
    
    if [[ -n "$PORT_FILTER" ]]; then
        lines=$(echo "$lines" | grep -E "port $PORT_FILTER|:$PORT_FILTER")
    fi
    
    if [[ -n "$PROTOCOL_FILTER" ]]; then
        lines=$(echo "$lines" | grep -i "$PROTOCOL_FILTER")
    fi
    
    local ips=$(echo "$lines" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')
    
    if [[ -n "$EXCLUDE_IP" ]]; then
        ips=$(echo "$ips" | grep -v "$EXCLUDE_IP")
    fi
    
    if [[ "$REVERSE" == true ]]; then
        ips=$(echo "$ips" | tac)
    fi
    
    echo "$ips" | grep -v '^0\.0\.0\.0$'
}

get_unique_ips() {
    local all_ips=$(get_all_ips)
    
    if [[ -n "$TOP_COUNT" ]]; then
        echo "$all_ips" | sort | uniq -c | sort -rn | head -n "$TOP_COUNT" | awk '{print $2}'
    else
        echo "$all_ips" | sort -u
    fi
}

echo "Анализ IP-адресов из $LOG_FILE"
echo "Для остановки нажмите Ctrl+C"
echo ""

if [[ -n "$OUTPUT_FILE" ]]; then
    : > "$OUTPUT_FILE"
fi

if [[ "$SHOW_ANOMALIES" == true ]]; then
    echo "Поиск аномальной активности..."
    echo ""
    
    all_ips=$(get_all_ips)
    total_ips=$(echo "$all_ips" | sort | uniq -c | sort -rn)
    
    avg_attempts=$(echo "$total_ips" | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    threshold=$(echo "$avg_attempts * 3" | bc)
    
    echo "Среднее количество попыток: $avg_attempts"
    echo "Порог аномальности (3x среднего): $threshold"
    echo ""
    
    echo "$total_ips" | awk -v threshold="$threshold" '$1 > threshold {print $2}' | while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        
        response=$(curl -s --max-time 5 "http://ip-api.com/json/$ip?lang=ru")
        
        country=$(echo "$response" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$response" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        attempts=$(echo "$total_ips" | grep "$ip$" | awk '{print $1}')
        
        [[ -z "$country" ]] && country="Неизвестно"
        [[ -z "$city" ]] && city="Неизвестно"
        
        print_output "$ip | $country | $city | Попыток: $attempts"
    done
else
    ips=$(get_unique_ips)
    
    if [[ -z "$ips" ]]; then
        echo -e "${RED}IP-адреса не найдены${NC}"
        exit 0
    fi
    
    count=$(echo "$ips" | wc -l)
    echo "Найдено уникальных IP: $count"
    echo ""
    
    limited_ips="$ips"
    if [[ -n "$SHOW_LIMIT" ]]; then
        limited_ips=$(echo "$ips" | head -n "$SHOW_LIMIT")
    fi
    
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        
        response=$(curl -s --max-time 5 "http://ip-api.com/json/$ip?lang=ru")
        
        country=$(echo "$response" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$response" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        
        [[ -z "$country" ]] && country="Неизвестно"
        [[ -z "$city" ]] && city="Неизвестно"
        
        print_output "$ip | $country | $city"
    done <<< "$limited_ips"
fi

if [[ -n "$OUTPUT_FILE" ]]; then
    echo ""
    echo "Результат сохранен в: $OUTPUT_FILE"
fi
