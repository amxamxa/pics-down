#!/usr/bin/env bash

# CONFIGURATION SECTION
# ==============================================
RESET="\033[0m"                         # Reset formatting
VIOLET="\033[38;2;255;0;53;48;2;34;0;82m" # Prompts
GREEN="\033[38;2;0;255;0;48;2;0;25;2m"    # Success
RED="\033[38;2;240;138;100;48;2;147;18;61m" # Errors
BLUE="\033[38;2;100;149;237m"            # Info text
PURPLE="\033[38;2;85;85;255;48;2;21;16;46m" # Interactions

OUT_DIR="./pics-down"                    # Default output directory
LOG_FILE="pics-down.log"                 # Log file name
PREFIX_LEN=2                             # Digits for numbering
USER_AGENT="Mozilla/5.0"                 # User-Agent for wget

# Initialize PAGER
if command -v bat &>/dev/null; then
    PAGER="bat"
else
    PAGER="cat"
fi

# FUNCTION DEFINITIONS
# ==============================================
show_message() {
    echo -e "${1}${2}${RESET}"
}

validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Error: Invalid URL format"
        return 1
    }
}

init_logging() {
    FULL_OUT_DIR="${OUT_DIR/%\//}"  # Remove trailing slash
    mkdir -p "$FULL_OUT_DIR" || {
        show_message "$RED" "Error: Cannot create output directory"
        exit 1
    }
    touch "$FULL_OUT_DIR/$LOG_FILE" || {
        show_message "$RED" "Error: Cannot write to directory"
        exit 1
    }
    echo "=== Download Log $(date) ===" > "$FULL_OUT_DIR/$LOG_FILE"
    echo "URL: $url" >> "$FULL_OUT_DIR/$LOG_FILE"
    echo "Output Directory: $FULL_OUT_DIR" >> "$FULL_OUT_DIR/$LOG_FILE"
}

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$FULL_OUT_DIR/$LOG_FILE"
}

show_help() {
    show_message "$PURPLE" "Usage:"
    echo "  $0 [OPTIONS] <URL>"
    echo
    show_message "$PURPLE" "Options:"
    echo "  -p LENGTH   Number of digits for numbering (default: ${PREFIX_LEN})"
    echo "  -o DIR      Output directory (default: $OUT_DIR)"
    echo "  -h          Show this help"
    echo
    show_message "$PURPLE" "Examples:"
    echo "  $0 -p 2 https://example.com/gallery/"
    echo "  $0 -p 4 -o ~/Bilder/vacation https://example.com/photos"
}

extract_images() {
    local type="$1"
    local patterns=("$2")
    local list_file="$3"
    
    for pattern in "${patterns[@]}"; do
        wget -qO- --user-agent="$USER_AGENT" "$url" | \
        grep -oP '(?<=src=")[^"]*\.'"$pattern"'(?=")' | \
        sort -u >> "$list_file"
    done
}

download_images() {
    local type="$1"
    local list_file="$2"
    local count=$(wc -l < "$list_file" 2>/dev/null)
    
    if [[ $count -gt 0 ]]; then
        show_message "$BLUE" "Found $count $type images:"
        $PAGER "$list_file"
        read -p "Download these $type images? [y/N] " answer
        if [[ "$answer" =~ [yY] ]]; then
            log "Downloading $count $type images"
            local counter=1
            while read -r img_url; do
                printf -v seq_num "%0${PREFIX_LEN}d" $counter
                local filename="${seq_num}_$(basename "$img_url")"
                show_message "$VIOLET" "Downloading: $filename"
                wget -q --user-agent="$USER_AGENT" "$img_url" -O "$FULL_OUT_DIR/$filename" && \
                    log "Downloaded: $filename" || \
                    log "Failed: $img_url"
                ((counter++))
            done < "$list_file"
        fi
    fi
}

# MAIN SCRIPT
# ==============================================
# Parse command line options
while getopts ":p:o:h" opt; do
    case $opt in
        p) PREFIX_LEN="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
        h) show_help; exit 0 ;;
        \?) show_message "$RED" "Invalid option: -$OPTARG"; exit 1 ;;
        :) show_message "$RED" "Option -$OPTARG requires an argument."; exit 1 ;;
    esac
done
shift $((OPTIND-1))

# Validate URL
url="$1"
if [ -z "$url" ]; then
    read -p "Enter URL: " url
fi
validate_url "$url" || exit 1

# Initialize logging and directories
init_logging
log "Script started"

# Temporary files
JPG_LIST=$(mktemp)
PNG_LIST=$(mktemp)
OTHER_LIST=$(mktemp)

# Extract image URLs
extract_images "jpg" "jpe?g" "$JPG_LIST"
extract_images "png" "png" "$PNG_LIST"
extract_images "other" "svg|tiff|avif|gif|bmp|webp" "$OTHER_LIST"

# Download images
download_images "JPG" "$JPG_LIST"
download_images "PNG" "$PNG_LIST"
download_images "Other" "$OTHER_LIST"

# Cleanup
rm -f "$JPG_LIST" "$PNG_LIST" "$OTHER_LIST"
log "Temporary files cleaned"

# Display results
show_message "$GREEN" "\nDownload completed!"
show_message "$VIOLET" "Files saved to: $FULL_OUT_DIR"

downloaded_files=("$FULL_OUT_DIR"/*)
if [ ${#downloaded_files[@]} -gt 0 ]; then
    show_message "$PURPLE" "\nDownloaded files:"
    for f in "${downloaded_files[@]}"; do
        echo " - $(basename "$f")"
    done
else
    show_message "$RED" "Warning: No files downloaded!"
fi

show_message "$BLUE" "\nLog file: $FULL_OUT_DIR/$LOG_FILE"

