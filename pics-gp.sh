#!/usr/bin/env bash

# gpt

# ============================== CONFIGURATION ===============================
RESET="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
PURPLE="\e[35m"

OUT_DIR="./pics-down"
LOG_FILE="pics-down.log"
PREFIX_LEN=2
USER_AGENT="Mozilla/5.0"

show_message() {
    echo -e "${1}${2}${RESET}"
}

validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Error: URL must start with http:// or https://"
        return 1
    }
}

init_logging() {
    mkdir -p "$OUT_DIR"
    LOG_PATH="$OUT_DIR/$LOG_FILE"
    echo "=== Download Log $(date) ===" > "$LOG_PATH"
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_PATH"
}

show_help() {
    echo "Usage: $0 [OPTIONS] <URL>"
    echo "  -p LENGTH   Number of digits for numbering (default: $PREFIX_LEN)"
    echo "  -o DIR      Output directory (default: $OUT_DIR)"
    echo "  -h          Show help"
}

while getopts "p:o:h" opt; do
    case $opt in
        p) PREFIX_LEN="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
        h) show_help; exit 0 ;;
        *) show_message "$RED" "Invalid option"; exit 1 ;;
    esac
done
shift $((OPTIND -1))

URL="$1"
if [[ -z "$URL" ]]; then
    show_message "$RED" "No URL provided! Enter URL:"
    read -r URL
fi

validate_url "$URL" || exit 1

init_logging
log "Starting download from $URL"

IMG_EXTENSIONS="jpg|jpeg|png|gif|svg|webp|bmp"

show_message "$BLUE" "Extracting image URLs..."
img_list=$(wget -qO- "$URL" | grep -oP '(?<=src=")[^"\']*\.('$IMG_EXTENSIONS')' | sort -u)

if [[ -z "$img_list" ]]; then
    show_message "$RED" "No images found. Exiting."
    exit 1
fi

echo "$img_list" | nl
show_message "$PURPLE" "Download images? (y/n)"
read -r CONFIRM

if [[ ! $CONFIRM =~ ^[yY]$ ]]; then
    show_message "$RED" "Download aborted."
    exit 0
fi

counter=1
mkdir -p "$OUT_DIR"
while IFS= read -r img_url; do
    filename="$(printf "%0${PREFIX_LEN}d" "$counter")_$(basename "$img_url")"
    wget -q "$img_url" -O "$OUT_DIR/$filename"
    log "Downloaded: $filename"
    ((counter++))
done <<< "$img_list"

show_message "$GREEN" "Download completed! Files saved in $OUT_DIR"
log "Download completed successfully."
ls -lh "$OUT_DIR"

