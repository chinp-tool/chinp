#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Installing chinp..."
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: script must be run with sudo${NC}"
    exit 1
fi

echo "Downloading chinp..."
curl -sSL -o /usr/local/bin/chinp https://raw.githubusercontent.com/chinp-tool/chinp/main/s/en/chinp.sh

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Download error${NC}"
    exit 1
fi

chmod +x /usr/local/bin/chinp

echo -e "${GREEN}Installation complete${NC}"
echo ""
echo "Use: chinp --help"
