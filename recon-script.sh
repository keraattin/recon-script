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
    echo "  [-] Running Subfinder..."
    subfinder -d "$domain" -silent > "$DOMAIN_DIR/subfinder.txt" 2>/dev/null

    # Assetfinder
    echo "  [-] Running Assetfinder..."
    assetfinder --subs-only "$domain" > "$DOMAIN_DIR/assetfinder.txt" 2>/dev/null

    # Merge
    echo "  [-] Merging and deduplicating subdomains..."
    cat "$DOMAIN_DIR/subfinder.txt" "$DOMAIN_DIR/assetfinder.txt" 2>/dev/null \
        | sed 's/^ *//;s/ *$//' | tr '[:upper:]' '[:lower:]' | sort -u > "$DOMAIN_DIR/subdomains.txt"

    # DNSx
    echo "  [-] Resolving subdomains with dnsx..."
    dnsx -silent -l "$DOMAIN_DIR/subdomains.txt" -o "$DOMAIN_DIR/resolved.txt" > /dev/null 2>&1

    # HTTPX metadata
    echo "  [-] Geting metadata with HTTPX"
    if [[ -s "$DOMAIN_DIR/resolved.txt" ]]; then
        httpx -l "$DOMAIN_DIR/resolved.txt" \
              -status-code -title -tech-detect -web-server -ip -cname -tls-probe -cdn \
              -json -silent > "$DOMAIN_DIR/httpx.json" 2>/dev/null

        jq -r '.url' "$DOMAIN_DIR/httpx.json" > "$DOMAIN_DIR/alive.txt"
    else
        touch "$DOMAIN_DIR/httpx.json"
        touch "$DOMAIN_DIR/alive.txt"
    fi

    # Port scan with Nmap
    echo "  [-] Running NMAP Scripts"
    echo -e "${YELLOW}  [+] Running Nmap scan on resolved domains for: $domain${RESET}"
    if [[ -s "$DOMAIN_DIR/resolved.txt" ]]; then
        while IFS= read -r ip; do
            nmap -sS -p- -sV "$ip" --open -T4 -oX "$DOMAIN_DIR/nmap_$ip.xml" 2>/dev/null
        done < "$DOMAIN_DIR/resolved.txt"
    fi

    # Fuzzing: Gobuster to find hidden URLs
    echo -e "${GREEN} [+] Running Gobuster fuzzing for: $domain${RESET}"
    gobuster dir -u "http://$domain" -w /usr/share/wordlists/dirb/big.txt -t 50 -b 301,404,400,500 -o "$DOMAIN_DIR/fuzzing_results.txt"

    # Crawling
    echo -e "${GREEN} [+] Running Gospider crawler for: $domain${RESET}"
    gospider -s "http://$domain" -t 10 -c 5 -d 2 --robots > "$DOMAIN_DIR/crawling_results.txt" 

    # Combine & dedupe fuzzing and crawling results
    grep -oP 'http[s]?://[^ ]+' "$DOMAIN_DIR/crawling_results.txt" 2>/dev/null >> "$DOMAIN_DIR/found_urls.txt"
    tail -n +2 "$DOMAIN_DIR/fuzzing_results.txt" | cut -d',' -f1 >> "$DOMAIN_DIR/found_urls.txt" 2>/dev/null
    sort -u "$DOMAIN_DIR/found_urls.txt" -o "$DOMAIN_DIR/found_urls.txt"

    # Count
    TOTAL=$(wc -l < "$DOMAIN_DIR/subdomains.txt" | tr -d ' ')
    RESOLVED=$(wc -l < "$DOMAIN_DIR/resolved.txt" | tr -d ' ')
    ALIVE=$(wc -l < "$DOMAIN_DIR/alive.txt" | tr -d ' ')
    FOUND_URL_COUNT=$(wc -l < "$DOMAIN_DIR/found_urls.txt" | tr -d ' ')

    echo "  [*] Total Subdomains: $TOTAL | Resolved: $RESOLVED | Alive: $ALIVE"

    {
        echo "----------------------------------------"
        echo "$domain"
        echo "----------------------------------------"
        echo "Subdomain - Total: $TOTAL - Resolved: $RESOLVED - Alive: $ALIVE"
        echo "Found Urls: $FOUND_URL_COUNT"
        echo "----------------------------------------"
    } >> "$SUMMARY_FILE"
done

echo -e "${GREEN}[+] Done! Report saved to $OUTPUT_DIR${RESET}"
