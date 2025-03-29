#!/usr/bin/env bash
##########################################
## ╔═╗╦╦  ╔═╗ ############################
## ╠╣ ║║  ║╣  ############################
## ╚  ╩╩═╝╚═╝ ############################
##  -NAME:      pics-down.sh
##  -VERSION:   0.2
##  -AUTHOR:    Kempter, Max
##  -DATE:      2025-Mar-30                
## ---------------------------------------
## To do/Known Bugs/Dependencies:
##  • Add support for other image formats (PNG, WEBP)
##  • Implement parallel downloads
##  • Add checksum verification
## ---------------------------------------
## Advanced image download utility
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## This script provides automated downloading of images from web pages:
## • Extracts all JPG image URLs from given webpage
## • Downloads images with sequential numbering
## • Provides configurable options:
##   - Custom output directory
##   - Adjustable filename prefix length
##   - Verbose mode
##   - URL list retention
## ---------------------------------------
##########################################

# ==============================================
# CONFIGURATION
# ==============================================
# UI Colors
RESET="\e[0m"
VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"   # Prompts
GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"      # Success
RED="\033[38;2;240;138;100m\033[48;2;147;18;61m" # Errors
BLUE="\033[38;2;100;149;237m"                    # Info
PURPLE="\033[38;2;85;85;255m\033[48;2;21;16;46m" # Interactions

# Default settings (override with flags)
PREFIX_LEN=2
OUTPUT_DIR=""
VERBOSE=false
KEEP_URLS=false
USER_AGENT="Mozilla/5.0"
LOG_FILE="pics-down.log"
STATIC_PREFIX="pics-"  # Statischer Präfix für Ordner

# ==============================================
# FUNCTIONS
# ==============================================

init_logging() {
    LOG_PATH="${OUTPUT_DIR}${STATIC_PREFIX}${folder_name}/${LOG_FILE}"
    mkdir -p "$(dirname "$LOG_PATH")"
    echo "=== Download Log $(date) ===" > "$LOG_PATH"
}

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_PATH"
    $VERBOSE && echo -e "${BLUE}LOG:${RESET} $message"
}

show_message() {
    echo -e "${1}${2}${RESET}"
}

show_help() {
    echo -e "${PURPLE}Usage:${RESET}"
    echo "  $0 [OPTIONS] <URL>"
    echo
    echo -e "${PURPLE}Options:${RESET}"
    echo "  -p LENGTH   Filename prefix length (default: ${PREFIX_LEN})"
    echo "  -o DIR      Output directory (default: ${OUTPUT_DIR})"
    echo "  -u AGENT    Set custom User-Agent (default: ${USER_AGENT})"
    echo "  -v          Verbose mode"
    echo "  -k          Keep URL list after download"
    echo "  -h          Show this help"
    echo
    echo -e "${PURPLE}Example:${RESET}"
    echo "  $0 -p 2 https://c3d2.de/shop.html"
    echo "  $0 -o /data/ -p 3 https://example.com/gallery/"
 }

extract_folder_name() {
#B: https://example.com/path/to/shop.html?param=1 wird zu shop
    local url="$1"             # URL als Parameter
    local name="${url##*/}"    # Entfernt alles bis zum letzten /
    name="${name%%\?*}"        # Entfernt Query-Parameter (ab ?)
    name="${name%.*}"            # Remove extension
    echo "${name//[^a-zA-Z0-9_-]/_}"  # Ersetzt Sonderzeichen durch _
}

validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Error: Invalid URL format - must start with http:// or https://"
        return 1
    }
}

build_output_path() {
    local base_dir="${1:-.}"
    local url_name="$2"
    echo "${base_dir%/}/${FOLDER_PREFIX}${url_name}"
}

validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Error: URL must start with http:// or https://"
        return 1
    }
}

# ==============================================
# MAIN 
# ==============================================

while getopts ":p:o:u:vkh" opt; do
    case $opt in
        p) PREFIX_LEN="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        u) USER_AGENT="$OPTARG" ;;
        v) VERBOSE=true ;;
        k) KEEP_URLS=true ;;
        h) show_help; exit 0 ;;
        \?) show_message "$RED" "Invalid option: -$OPTARG"; exit 1 ;;
        :) show_message "$RED" "Option -$OPTARG requires an argument."; exit 1 ;;
    esac
done

# OPTIND: Eine Shell-Variable, die den Index des nächsten zu verarbeitenden 
# Arguments speichert. Funktion: Verschiebt die Argumente, sodass nur n
# icht-optionale Argumente (wie die URL) übrig bleiben 
shift $((OPTIND-1))

# Validate URL
[[ $# -eq 0 ]] && { show_help; exit 1; }
url="$1"
validate_url "$url" || exit 1


# Set up paths
folder_name=$(extract_folder_name "$url")
FULL_OUTPUT_PATH=$(build_output_path "$OUTPUT_DIR" "$folder_name")

# Initialize
init_logging
log "Starting download from: $url"
log "Output path: $FULL_OUTPUT_PATH"

# Create output directory
mkdir -p "$FULL_OUTPUT_PATH" || {
    log "Failed to create directory: $FULL_OUTPUT_PATH"
    exit 1
}
cd "$FULL_OUTPUT_PATH" || exit 1

# Extract filename prefix
prefix=$(echo "$folder_name" | head -c "$PREFIX_LEN")

# Extract image URLs
log "Extracting image URLs"
wget --header="User-Agent: $USER_AGENT" -qO- "$url" | \
grep -oP '(?<=src=")[^"]*\.(jpg|jpeg|png|webp)' | \
awk -v base="${url%/*}" '{
    if ($0 ~ /^https?:\/\//) print $0;
    else if ($0 ~ /^\//) print "https://" gensub(/^https?:\/\/([^/]+).*/, "\\1", "g", base) $0;
    else print base "/" $0;
}' | sort -u > image_urls.txt

# Verify URLs
[[ -s image_urls.txt ]] || {
    log "No image URLs found!"
    show_message "$RED" "Error: No images found on the page"
    exit 1
}

# Download images
log "Downloading $(wc -l < image_urls.txt) images"
awk -v pre="$prefix" -v log="$LOG_PATH" '{
    ext = ".jpg";
    if (match($0, /\.[a-zA-Z0-9]+$/)) ext = substr($0, RSTART, RLENGTH);
    printf "wget --progress=bar:force -O %s-%03d%s %s 2>&1 | tee -a %s\n", 
           pre, NR, ext, $0, log;
}' image_urls.txt | bash

# Cleanup
$KEEP_URLS || { rm image_urls.txt; log "Removed temporary URL list"; }

# Final output
show_message "$GREEN" "\nDownload completed!"
show_message "$VIOLET" "Files saved to: $FULL_OUTPUT_PATH"
ls -1 "${prefix}"-*.* | while read -r f; do
    show_message "$PURPLE" "• $f"
done
show_message "$BLUE" "\nLog saved to: $LOG_PATH"


