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
## • Provides configurable options: Custom output directory, Adjustable 
##   filename prefix length, Verbose mode, log-file
## Usage:
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## With custom parent directory (creates /data/pics-gallery/)
## ./pics-down.sh -o /data/ https://example.com/gallery
## Verbose mode with URL list kept
## ./pics-down.sh -v -k -p 3 https://example.com/images
##########################################

# ==============================================
# CONFIGURATION SECTION
# ==============================================

# Color definitions for terminal output
RESET="\e[0m"                  # Reset all formatting
VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"   # For prompts
GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"      # Success messages
RED="\033[38;2;240;138;100m\033[48;2;147;18;61m" # Error messages
BLUE="\033[38;2;100;149;237m"                    # Information text
PURPLE="\033[38;2;85;85;255m\033[48;2;21;16;46m" # User interactions

# Default settings (can be overridden with command line options)
PREFIX_LEN=2                   # Number of digits for sequential numbering (01, 02, etc.)
OUTPUT_DIR="."                 # Default output directory (current directory)
VERBOSE=false                  # Verbose output flag
KEEP_URLS=false                # Keep URL list after download
USER_AGENT="Mozilla/5.0"       # Default user agent for wget
LOG_FILE="pics-down.log"        # Log file name
STATIC_PREFIX=""               # Static prefix for filenames (empty by default)

# ==============================================
# FUNCTION DEFINITIONS
# ==============================================

# Initialize logging system
# Creates log file and writes header
init_logging() {
	mkdir -p "$(dirname "$LOG_PATH")" || {
        echo -e "${RED}Failed to create directory: $FULL_OUTPUT_PATH${RESET}"
        exit 1
    }
    LOG_PATH="${FULL_OUTPUT_PATH%/}/${LOG_FILE}"
    echo "=== Download Log $(date) ===" > "$LOG_PATH"
    echo "URL: $url" >> "$LOG_PATH"
    echo "Output Directory: $FULL_OUTPUT_PATH" >> "$LOG_PATH"
    echo "DEBUG: LOG_PATH is set to $LOG_PATH"
}

# Log a message to both log file and console (if verbose)
# Arguments:
#   $1 - message to log
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_PATH"
    if $VERBOSE; then
        echo -e "${BLUE}LOG:${RESET} $message"
    fi
}

# Display colored message to console
# Arguments:
#   $1 - color code
#   $2 - message
show_message() {
    echo -e "${1}${2}${RESET}"
}

# Display help information
show_help() {
    echo -e "${PURPLE}Usage:${RESET}"
    echo "  $0 [OPTIONS] <URL>"
    echo
    echo -e "${PURPLE}Options:${RESET}"
    echo "  -p LENGTH   Number of digits for sequential numbering (default: ${PREFIX_LEN})"
    echo "  -o DIR      Output directory (default: current directory)"
    echo "  -s PREFIX   Static filename prefix (default: none)"
    echo "  -v          Verbose mode"
    echo "  -k          Keep URL list after download"
    echo "  -h          Show this help"
    echo
    echo -e "${PURPLE}Examples:${RESET}"
    echo "  $0 -p 2 https://example.com/gallery/"
    echo "  $0 -o ~/downloads -s vacation_ https://example.com/photos"
}

# Extract folder name from URL
# Arguments:
#   $1 - URL to process
# Returns:
#   Cleaned directory name based on URL 
#B: https://example.com/path/to/shop.html?param=1 wird zu shop
extract_folder_name() {
    local url="$1"
    local name="${url##*/}"      # Extract everything after last /
    name="${name%%\?*}"          # Remove query parameters
    name="${name%.*}"            # Remove file extension
    echo "${name//[^a-zA-Z0-9_-]/_}" # Replace special chars with _
}

# Validate URL format
# Arguments:
#   $1 - URL to validate
validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Error: URL must start with http:// or https://"
        return 1
    }
}

# ==============================================
# MAIN 
# ==============================================

# Process command line options
while getopts ":p:o:s:vkh" opt; do
    case $opt in
        p) PREFIX_LEN="$OPTARG" ;;     # Set number of digits for numbering
        o) OUTPUT_DIR="$OPTARG" ;;     # Set output directory
        s) STATIC_PREFIX="$OPTARG" ;;  # Set static filename prefix
        v) VERBOSE=true ;;             # Enable verbose mode
        k) KEEP_URLS=true ;;           # Keep URL list after download
        h) show_help; exit 0 ;;        # Show help
        \?) show_message "$RED" "Invalid option: -$OPTARG"; exit 1 ;;
        :) show_message "$RED" "Option -$OPTARG requires an argument."; exit 1 ;;
    esac
done
shift $((OPTIND-1))  # Remove processed options from arguments
# OPTIND: Eine Shell-Variable, die den Index des nächsten zu verarbeitenden 
# Arguments speichert. Funktion: Verschiebt die Argumente, sodass nur 
# nicht-optionale Argumente (wie die URL) übrig bleiben 

# Validate URL argument
if [[ $# -eq 0 ]]; then
    show_help
    show_message "$RED" "Error: No URL specified"
    exit 1
fi
url="$1"
validate_url "$url" || exit 1

# Set up output paths
folder_name=$(extract_folder_name "$url")
FULL_OUTPUT_PATH="${OUTPUT_DIR%/}/${folder_name}"

# Initialize logging system
init_logging
log "Starting download process"
log "Source URL: $url"
log "Output directory: $FULL_OUTPUT_PATH"

# Create output directory if it doesn't exist
mkdir -p "$FULL_OUTPUT_PATH" || {
    log "Failed to create output directory: $FULL_OUTPUT_PATH"
    exit 1
}
cd "$FULL_OUTPUT_PATH" || exit 1

# Extract image URLs from webpage
log "Extracting image URLs from webpage"
wget --header="User-Agent: $USER_AGENT" -qO- "$url" | \
grep -oP '(?<=src=")[^"]*\.(jpg|jpeg|png|webp|gif)' | \
awk -v base="${url%/*}" '{
    # Handle different URL formats:
    if ($0 ~ /^https?:\/\//) print $0;          # Absolute URLs
   #  else if ($0 ~ /^\//) print "https://" gensub(/^https?:\/\/([^/]+).*/, "\\1", "g", base) $0;  # Root-relative URLs
    else print base "/" $0;                     # Document-relative URLs
}' | sort -u > image_urls.txt

# Verify we found image URLs
if [[ ! -s image_urls.txt ]]; then
    log "No image URLs found on the page"
    show_message "$RED" "Error: No images found on the page"
    exit 1
fi
log "Found $(wc -l < image_urls.txt) image URLs"

# Download images with proper numbering and original extensions
log "Starting image download"
awk -v prefix="$STATIC_PREFIX" -v len="$PREFIX_LEN" -v log_file="$LOG_PATH" '{
    # Extract original extension
    if (match($0, /\.[a-zA-Z0-9]+$/)) {
        ext = substr($0, RSTART, RLENGTH);
    } else {
        ext = ".jpg";  # Default extension if none found
    }
    
    # Generate sequential number with leading zeros
    seq = sprintf("%0" len "d", NR);
    
    # Build output filename and download command
    printf "wget --progress=bar:force -O %s%s%s %s 2>&1 | tee -a \"%s\"\n", prefix, seq, ext, $0, log_file;
}' image_urls.txt | bash

# Clean up temporary files
if ! $KEEP_URLS; then
    rm image_urls.txt
    log "Removed temporary URL list"
fi

# Display final results
show_message "$GREEN" "\nDownload completed successfully!"
show_message "$VIOLET" "Files saved to: $FULL_OUTPUT_PATH"

# List downloaded files with proper numbering
downloaded_files=$(ls ${STATIC_PREFIX}*.* 2>/dev/null | wc -l)
if [[ $downloaded_files -gt 0 ]]; then
    ls ${STATIC_PREFIX}*.* | while read -r f; do
        show_message "$PURPLE" "$f"
    done
else
    show_message "$RED" "Warning: No files were downloaded!"
fi

show_message "$BLUE" "\nDetailed log saved to: $LOG_PATH"



#!/usr/bin/env bash
# CONFIGURATION SECTION
# ==============================================
# Color definitions for terminal output
RESET="\e ￼"                  # Reset all formatting
VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"   # For prompts
GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"      # Success messages
RED="\033[38;2;240;138;100m\033[48;2;147;18;61m" # Error messages
BLUE="\033[38;2;100;149;237m"                    # Information text
PURPLE="\033[38;2;85;85;255m\033[48;2;21;16;46m" # User interactions

OUT_DIR=".\pics-down\"         Default output directory (current directory)
LOG_FILE="pics-down.log"        # Log file name
PREFIX_LEN=2     # Number of digits for sequential numbering (01, 02, etc.)
USER_AGENT="Mozilla/5.0"       # Default user agent for wget

# Display colored message to console
# Arguments:   $1 - color code  $2 - message
show_message() {
    echo -e "${1}${2}${RESET}"
}
IF bat installed
	PAGER=bat
else 
	PAGER=cat
FI

# Validate URL format
# Arguments:
#   $1 - URL to validate
validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Error: URL must start with http:// or https://"
        return 1
    }
}

# ==============================================
# FUNCTION DEFINITIONS
# ==============================================

IF "CMD -l"
 then $FULL_OUT_DIR=$OUT_DIR + $PATH
FI

init_logging() {
    if (touch "$(LOG_FILE)"  = NULL
	    echo keiner Schreibrechte im Ordner
	    EXIT 1mkdir -p "$folder_name" && cd "$folder_name"
 ￼
	  else   
     echo "=== Download Log $(date) ===" >> "$FULL_OUT_DIR\$LOG_FILE"
    echo "URL: $url" >> "$FULL_OUT_DIR\$LOG_FILE"
    echo "Output Directory: $FULL_OUT_DIR" >> "$FULL_OUT_DIR\$LOG_FILE"
    echo "DEBUG: LOG_PATH is set to "$FULL_OUT_DIR\$LOG_FILE"
    echo "=============================================="
FI

# Log a message to both log file and console (if verbose)
# Arguments:
#   $1 - message to log
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$FULL_OUT_DIR\$LOG_FILE"
    }
# Display help information
show_help() {
    echo -e "${PURPLE}Usage:${RESET}"
    echo "  $0 [OPTIONS] <URL>"
    echo
    echo -e "${PURPLE}Options:${RESET}"
    echo "  -p LENGTH   Number of digits for sequential numbering (default: ${PREFIX_LEN})"
    echo "  -o DIR      Output directory (default: $OUT-DIR)"
    echo "  -h          Show this help"
    echo
    echo -e "${PURPLE}Examples:${RESET}"
    echo "  $0 -p 2 https://example.com/gallery/"
    echo "  $0 -p 4 -o ~/Bilder/vacation_ https://example.com/photos"
}
# URL -Abfrage
URL = $1 
 IF URL ist leer
  THEN echo "you give me a URL"
  echo "gib URL ein"
  READ URL 
 FI
IF URL not valid
 THEN echo "you give me a incorret URL"
  echo "gib URL ein"
  READ URL 
FI


while getopts ":p:o:s:vkh" opt; do
    case $opt in
        p) PREFIX_LEN="$OPTARG" ;;     # Set number of digits for numbering
        -o| --out-dir) OUT_DIR="$OPTARG" ;;     # Set output directory
        l) LOGGING="true" ;;  # Set logging function, Defeault=NULL
        h) show_help; exit 0 ;;        # Show help
        \?) show_message "$RED" "Invalid option: -$OPTARG"; exit 1 ;;
        :) show_message "$RED" "Option -$OPTARG requires an argument."; exit 1 ;;
    esac
done
shift $((OPTIND-1))  # Remove processed options from arguments
# OPTIND: Eine Shell-Variable, die den Index des nächsten zu verarbeitenden
# Arguments speichert. Funktion: Verschiebt die Argumente, sodass nur
# nicht-optionale Argumente (wie die URL) übrig bleiben


# SECTION jpg download
IF (wget -qO- $URL | grep -oP '(?<=src=")[^"]*\.(jpg|jpeg|JPG|JPEG)' | sort -u | wc-l ) >= 1
THEN wget -qO- $URL | grep -oP '(?<=src=")[^"]*\.(jpg|jpeg|JPG|JPEG)' > jpg-list.txt
FI
cat jpg-list.txt
echo "download?" [yY] [nN]"
DOWNLOAD
log "Extracting $TYPE image from webpage with $URL"

# Section png, webp
IF (wget -c  -qO- $URL | grep -oP '(?<=src=")[^"]*\.(png|PNG|svg|SVG)' | sort -u |wc-l) >= 1
THEN wget -qO- $URL | grep -oP '(?<=src=")[^"]*\.(png|PNG|svg|SVG)' > png-list.txt
￼FI
￼cat png-list.txt
￼echo "download?" [yY] [nN]"
DOWNLOAD
￼log "Extracting $TYPE image from webpage with $URL"
￼


​
# Section svg|tiff|avif
￼ MAKE Function
￼
# Section gif|bmp
 MAKE Function


 # ---------------------------------------
# Clean up temporary files
    rm "*-list.txt"
    log "Removed temporary URL list"

# ------------  
# Display final results
show_message "$GREEN" "\nDownload completed successfully!"
show_message "$VIOLET" "Files saved to: $FULL_OUT_DIR"

# List downloaded files with proper numbering
downloaded_files=$(ls $FULL_OUT_DIR"
/*.* 2>/dev/null | wc -l)
if [[ $downloaded_files -gt 0 ]]; then
    ls $(FULL-OUT-DIR/*.* | while read -r f; do
        show_message        "$PURPLE" "$f"
    done
else
    show_message "$RED" "Warning: No files were downloaded!"
fi

show_message "$BLUE" "\nDetailed log saved to: $LOG_PATH"


￼# ------------  
￼# Display final results
show_message "$GREEN" "\nDownload completed successfully!"
show_message "$VIOLET" "Files saved to: $FULL_OUT_DIR"
￼
￼# List downloaded files with proper numbering
￼downloaded_files=$(ls $FULL_OUT_DIR"
￼/*.* 2>/dev/null | wc -l)
​￼if [[ $downloaded_files -gt 0 ]]; then
￼    ​￼ls $(FULL-OUT-DIR/*.* | while read -r f; do
        show_message        "$PURPLE" "$f"
￼    done
​￼else
￼    show_message "$RED" "Warning: No files were downloaded!"
￼fi
￼
￼show_message "$BLUE" "\nDetailed log saved to: $LOG_PATH"
￼
￼
 ￼O- $URL | grep -oP '(?<=src=")[^"]*\.(jpg|jpeg|JPG|JPEG)' > png-list.txt
FI
