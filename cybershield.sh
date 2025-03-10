#!/bin/bash

# Ultimate CyberShield Suite v7.0
# Author: admknight
# GitHub: https://github.com/admknight/cybershield
# License: MIT

# ========================
# Configuration
# ========================
declare -A TOOLS=(
    ["nmap"]="nmap"
    ["nikto"]="nikto"
    ["sqlmap"]="sqlmap"
    ["wpscan"]="wpscan"
    ["nuclei"]="nuclei"
    ["masscan"]="masscan"
    ["jq"]="jq"
    ["curl"]="curl"
)

DARKWEB_API="https://psbdmp.ws/api/v3"
REPORT_DIR="cybershield_reports"
LOG_FILE="cybershield.log"

# ========================
# Color Configuration
# ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ========================
# Core Functions
# ========================
ethical_warning() {
    clear
    echo -e "${RED}"
    cat << "EOF"
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
▓                                                                              ▓
▓  WARNING: This tool contains capabilities that could damage computer systems  ▓
▓  Use only on systems you own or have explicit written authorization to test   ▓
▓                                                                              ▓
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}╭──────────────────────────────────────────────────────────────╮"
    echo -e "│ ${CYAN}➤ Version: ${PINK}7.0 ${CYAN}| ${CYAN}Release Date: ${PINK}2025-03-01 ${CYAN}| ${CYAN}Author: ${PINK}ADMKNIGHT ${CYAN}│"
    echo -e "│ ${CYAN}➤ GitHub: ${PINK}https://github.com/admknight/cybershield ${CYAN}                    │"
    echo -e "╰──────────────────────────────────────────────────────────────╯${NC}"
    
    read -p "[❗] Confirm Authorization (yes/no): " auth
    [[ $auth != "yes" ]] && exit 0
    echo -e "${GREEN}[+] Authorization confirmed. Starting CyberShield...${NC}"
    sleep 2
}

sanitize_target() {
    echo "$1" | sed -e 's/[^A-Za-z0-9._-]/_/g' -e 's/^https*:\/\///' -e 's/\/$//'
}

generate_filename() {
    local target=$1
    local scan_type=$2
    local sanitized=$(sanitize_target "$target")
    echo "${REPORT_DIR}/${sanitized}_${scan_type}_$(date +%Y%m%d_%H%M%S).txt"
}

# ========================
# Scanning Modules
# ========================
web_scan() {
    while true; do
        read -p "Enter target URL (or 'back'): " url
        [[ "$url" == "back" ]] && return
        
        confirm_action "$url" "web scan" || continue
        
        report_file=$(generate_filename "$url" "web_scan")
        echo -e "${BLUE}[+] Starting Nmap scan...${NC}"
        nmap -sV -sC -oN "$report_file" "$url"
        
        echo -e "\n${BLUE}[+] Running Nikto...${NC}"
        nikto -h "$url" >> "$report_file"
        
        echo -e "\n${BLUE}[+] Nuclei scan...${NC}"
        nuclei -u "$url" -t ~/nuclei-templates/ >> "$report_file"
        
        echo -e "${GREEN}[+] Web scan completed. Report: ${report_file}${NC}"
        return
    done
}

network_scan() {
    while true; do
        read -p "Enter target IP (or 'back'): " ip
        [[ "$ip" == "back" ]] && return
        
        confirm_action "$ip" "network scan" || continue
        
        report_file=$(generate_filename "$ip" "network_scan")
        echo -e "${BLUE}[+] Starting Masscan...${NC}"
        masscan -p1-65535 "$ip" --rate=1000 >> "$report_file"
        echo -e "${GREEN}[+] Network scan completed. Report: ${report_file}${NC}"
        return
    done
}

# ========================
# SQLMap Data Dump Module
# ========================
sqlmap_dump() {
    while true; do
        read -p "Enter vulnerable URL (or 'back'): " url
        [[ "$url" == "back" ]] && return
        
        confirm_action "$url" "SQL dump" || continue
        
        report_file=$(generate_filename "$url" "sqldump").csv
        echo -e "${BLUE}[+] Enumerating databases...${NC}"
        databases=$(sqlmap -u "$url" --dbs --batch 2>/dev/null | grep -E '\| [\w-]+' | awk -F'|' '{print $2}' | tr -d ' ')
        
        if [ -z "$databases" ]; then
            echo -e "${RED}[-] No databases found!${NC}"
            continue
        fi

        PS3="Select database (or 'back'): "
        select db in $databases "Back"; do
            [[ "$db" == "Back" ]] && continue 2
            [[ -n "$db" ]] && break
            echo -e "${RED}Invalid selection!${NC}"
        done

        PS3="Select table (or 'back'): "
        while true; do
            tables=$(sqlmap -u "$url" -D "$db" --tables --batch 2>/dev/null | grep -E '\| [\w-]+' | awk -F'|' '{print $2}' | tr -d ' ')
            select table in $tables "Back"; do
                [[ "$table" == "Back" ]] && continue 3
                [[ -n "$table" ]] && break 2
                echo -e "${RED}Invalid selection!${NC}"
            done
        done

        columns=$(sqlmap -u "$url" -D "$db" -T "$table" --columns --batch 2>/dev/null | grep -E '\| [\w-]+' | awk -F'|' '{print $2}' | tr -d ' ' | tr '\n' ',')
        
        echo -e "${YELLOW}Available columns: ${columns%,}${NC}"
        read -p "Enter columns (comma-separated/all/back): " col_choice
        [[ "$col_choice" == "back" ]] && continue
        
        cols="$([[ "$col_choice" == "all" ]] && echo "*" || echo "$col_choice")"

        echo -e "${BLUE}[+] Dumping selected columns...${NC}"
        sqlmap -u "$url" -D "$db" -T "$table" -C "$cols" --dump --output-dir="$REPORT_DIR" --dump-format=CSV --batch
        
        if csv_file=$(find "$REPORT_DIR" -name "*.csv" -print -quit); then
            mv "$csv_file" "$report_file"
            echo -e "${GREEN}[+] Data dumped to ${report_file}${NC}"
            echo -e "\n${YELLOW}First 5 rows:${NC}"
            head -n 5 "$report_file" | column -t -s,
        else
            echo -e "${RED}[-] Dump failed!${NC}"
        fi
        return
    done
}

# ========================
# Dark Web Monitoring
# ========================
darkweb_monitor() {
    while true; do
        read -p "Enter organization/domain (or 'back'): " target
        [[ "$target" == "back" ]] && return
        
        confirm_action "$target" "dark web scan" || continue
        
        report_file=$(generate_filename "$target" "darkweb_scan")
        echo -e "${BLUE}[+] Checking paste sites...${NC}"
        curl -s "${DARKWEB_API}/search/$target" | jq '.data[].id' | while read id; do
            echo -e "${RED}⚠️ Found paste: https://psbdmp.ws/$id${NC}"
            echo "Paste ID: $id" >> "$report_file"
        done
        
        echo -e "\n${BLUE}[+] Checking HIBP breaches...${NC}"
        hibp_results=$(curl -s "https://haveibeenpwned.com/api/v3/breaches")
        echo "$hibp_results" | jq -r ".[] | select(.Name | contains(\"$target\")) | \"Breach: \(.Name) | Date: \(.BreachDate)\"" >> "$report_file"
        
        echo -e "${GREEN}[+] Dark web scan completed. Report: ${report_file}${NC}"
        return
    done
}

# ========================
# Helper Functions
# ========================
confirm_action() {
    local target=$1
    local action=$2
    echo -e "\n${YELLOW}[!] You are about to perform: ${action} on ${target}${NC}"
    read -p "Confirm action (yes/no/back): " confirm
    case $confirm in
        "yes") return 0 ;;
        "no"|"back") return 1 ;;
        *) echo -e "${RED}Invalid choice!${NC}"; return 1 ;;
    esac
}

install_tool() {
    local tool=$1
    case $OS in
        "KALI"|"WSL"|"LINUX")
            sudo apt update && sudo apt install -y ${TOOLS[$tool]} >> "$LOG_FILE" 2>&1
            ;;
        "MACOS")
            brew install ${TOOLS[$tool]} >> "$LOG_FILE" 2>&1
            ;;
    esac
}

verify_tools() {
    mkdir -p "$REPORT_DIR"
    for tool in "${!TOOLS[@]}"; do
        if ! command -v $tool &>/dev/null; then
            echo -e "${YELLOW}[+] Installing missing dependency: $tool${NC}"
            install_tool $tool
        fi
    done
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -qi "kali" /etc/os-release; then
            OS="KALI"
        elif uname -a | grep -qi "microsoft"; then
            OS="WSL"
        else
            OS="LINUX"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="MACOS"
    else
        echo -e "${RED}Unsupported OS${NC}"
        exit 1
    fi
    echo -e "${BLUE}[+] Detected OS: $OS${NC}"
}

# ========================
# Main Interface
# ========================
main_menu() {
    while true; do
        echo -e "\n${CYAN}==== CyberShield Main Menu ====${NC}"
        echo "1. Install Required Tools"
        echo "2. Web Application Scan"
        echo "3. Network Scan"
        echo "4. Dark Web Monitoring"
        echo "5. SQLMap Data Dump"
        echo "6. Exit"
        read -p "Choose option (1-6): " choice

        case $choice in
            1) verify_tools ;;
            2) web_scan ;;
            3) network_scan ;;
            4) darkweb_monitor ;;
            5) sqlmap_dump ;;
            6) exit 0 ;;
            *) echo -e "${RED}Invalid choice!${NC}" ;;
        esac
    done
}

# ========================
# Execution Flow
# ========================
ethical_warning
detect_os
verify_tools
main_menu
