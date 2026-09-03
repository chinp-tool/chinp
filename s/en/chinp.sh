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
    echo "Usage: chinp [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help"
    echo "  -n, --limit N           Limit output to N records"
    echo "  -o, --output FILE       Save result to file"
    echo "  -f, --failed-only       Show only failed login attempts"
    echo "  -d, --date DATE         Show IPs for specific date (2024-01-15)"
    echo "  -t, --top N             Show top N most frequent IPs"
    echo "  -p, --port PORT         Filter by port (22, 2222)"
    echo "  -r, --reverse           Show from end (latest entries)"
    echo "  -e, --exclude IP        Exclude IP from output"
    echo "  -b, --before DATE       Show IPs before date (2024-01-15)"
    echo "  --protocol TYPE         Filter by protocol (ssh, ftp)"
    echo "  --anomalies             Show anomalous activity"
    echo ""
    echo "Examples:"
    echo "  chinp -n 10                        Show first 10 IPs"
    echo "  chinp -f                           Only failed attempts"
    echo "  chinp -d 2024-01-15                For specific date"
    echo "  chinp -t 5                         Top 5 most frequent IPs"
    echo "  chinp -p 22                        Only SSH connections"
    echo "  chinp -r                           Latest entries"
    echo "  chinp -e 192.168.1.1               Exclude IP"
    echo "  chinp -b 2024-01-15                Before date"
    echo "  chinp --protocol ssh               Only SSH"
    echo "  chinp --anomalies                  Anomalous activity"
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
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage
            ;;
    esac
done

if [[ ! -f "$LOG_FILE" ]]; then
    echo -e "${RED}Error: file $LOG_FILE not found${NC}" >&2
    exit 1
fi

if [[ ! -r "$LOG_FILE" ]]; then
    echo -e "${RED}Error: insufficient permissions to read $LOG_FILE${NC}" >&2
    echo -e "${RED}Run with sudo${NC}" >&2
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

echo "Analyzing IP addresses from $LOG_FILE"
echo "Press Ctrl+C to stop"
echo ""

if [[ -n "$OUTPUT_FILE" ]]; then
    : > "$OUTPUT_FILE"
fi

if [[ "$SHOW_ANOMALIES" == true ]]; then
    echo "Searching for anomalous activity..."
    echo ""
    
    all_ips=$(get_all_ips)
    total_ips=$(echo "$all_ips" | sort | uniq -c | sort -rn)
    
    avg_attempts=$(echo "$total_ips" | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    threshold=$(echo "$avg_attempts * 3" | bc)
    
    echo "Average attempts: $avg_attempts"
    echo "Anomaly threshold (3x average): $threshold"
    echo ""
    
    echo "$total_ips" | awk -v threshold="$threshold" '$1 > threshold {print $2}' | while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        
        response=$(curl -s --max-time 5 "http://ip-api.com/json/$ip?lang=en")
        
        country=$(echo "$response" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$response" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        attempts=$(echo "$total_ips" | grep "$ip$" | awk '{print $1}')
        
        [[ -z "$country" ]] && country="Unknown"
        [[ -z "$city" ]] && city="Unknown"
        
        print_output "$ip | $country | $city | Attempts: $attempts"
    done
else
    ips=$(get_unique_ips)
    
    if [[ -z "$ips" ]]; then
        echo -e "${RED}No IP addresses found${NC}"
        exit 0
    fi
    
    count=$(echo "$ips" | wc -l)
    echo "Found unique IPs: $count"
    echo ""
    
    limited_ips="$ips"
    if [[ -n "$SHOW_LIMIT" ]]; then
        limited_ips=$(echo "$ips" | head -n "$SHOW_LIMIT")
    fi
    
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        
        response=$(curl -s --max-time 5 "http://ip-api.com/json/$ip?lang=en")
        
        country=$(echo "$response" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$response" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        
        [[ -z "$country" ]] && country="Unknown"
        [[ -z "$city" ]] && city="Unknown"
        
        print_output "$ip | $country | $city"
    done <<< "$limited_ips"
fi

if [[ -n "$OUTPUT_FILE" ]]; then
    echo ""
    echo "Result saved to: $OUTPUT_FILE"
fi
