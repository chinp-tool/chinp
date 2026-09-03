#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Установка chinp..."
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ошибка: скрипт должен запускаться с sudo${NC}"
    exit 1
fi

echo "Загрузка chinp..."
curl -sSL -o /usr/local/bin/chinp https://raw.githubusercontent.com/chinp-tool/chinp/main/s/ru/chinp-ru.sh

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Ошибка загрузки${NC}"
    exit 1
fi

chmod +x /usr/local/bin/chinp

echo -e "${GREEN}Установка завершена${NC}"
echo ""
echo "Используйте: chinp --help"
