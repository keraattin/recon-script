#!/bin/bash

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Usage
show_help() {
    echo -e "${YELLOW}Usage:${RESET} $0 --input domains.txt --output results/"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
        INPUT="$2"; shift 2;;
        --output)
        OUTPUT_DIR="$2"; shift 2;;
        *)
        echo -e "${YELLOW}[!] Unknown parameter: $1${RESET}"; show_help; exit 1;;
    esac
done

# Check required inputs
if [[ -z "$INPUT" || -z "$OUTPUT_DIR" ]]; then
    echo -e "${YELLOW}[!] Missing input or output parameters.${RESET}"
    show_help
    exit 1
fi

# Prepare output
mkdir -p "$OUTPUT_DIR"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
echo "Reconnaissance Summary" > "$SUMMARY_FILE"
echo "======================" >> "$SUMMARY_FILE"

# Read all domains into an array
mapfile -t domains < "$INPUT"

for domain in "${domains[@]}"; do
    domain=$(echo "$domain" | tr -d '\r' | xargs)
    [ -z "$domain" ] && continue

    echo -e "${GREEN}[+] Processing: $domain${RESET}"

    DOMAIN_DIR="$OUTPUT_DIR/$domain"
    mkdir -p "$DOMAIN_DIR"

    # Subfinder
    subfinder -d "$domain" -silent > "$DOMAIN_DIR/subfinder.txt" 2>/dev/null

    # Assetfinder
    assetfinder --subs-only "$domain" > "$DOMAIN_DIR/assetfinder.txt" 2>/dev/null

    # Merge
    cat "$DOMAIN_DIR/subfinder.txt" "$DOMAIN_DIR/assetfinder.txt" 2>/dev/null \
        | sed 's/^ *//;s/ *$//' | tr '[:upper:]' '[:lower:]' | sort -u > "$DOMAIN_DIR/subdomains.txt"

    # DNSx
    dnsx -silent -l "$DOMAIN_DIR/subdomains.txt" -o "$DOMAIN_DIR/resolved.txt" > /dev/null 2>&1

    # HTTPX metadata
    if [[ -s "$DOMAIN_DIR/resolved.txt" ]]; then
        httpx -l "$DOMAIN_DIR/resolved.txt" \
              -status-code -title -tech-detect -web-server -ip -cname -tls-probe -cdn \
              -json -silent > "$DOMAIN_DIR/httpx.json" 2>/dev/null

        jq -r '.url' "$DOMAIN_DIR/httpx.json" > "$DOMAIN_DIR/alive.txt"
    else
        touch "$DOMAIN_DIR/httpx.json"
        touch "$DOMAIN_DIR/alive.txt"
    fi

    # Count
    TOTAL=$(wc -l < "$DOMAIN_DIR/subdomains.txt" | tr -d ' ')
    RESOLVED=$(wc -l < "$DOMAIN_DIR/resolved.txt" | tr -d ' ')
    ALIVE=$(wc -l < "$DOMAIN_DIR/alive.txt" | tr -d ' ')

    echo "  [*] Total Subdomains: $TOTAL | Resolved: $RESOLVED | Alive: $ALIVE"

    {
        echo "$domain - Total: $TOTAL - Resolved: $RESOLVED - Alive: $ALIVE"
        echo "----------------------------------------"
    } >> "$SUMMARY_FILE"
done

echo -e "${GREEN}[+] Done! Report saved to $OUTPUT_DIR${RESET}"
