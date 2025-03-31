#!/usr/bin/env bash
#
# GEMMINI: Skript zum Herunterladen von Bildern von einer Webseite
#
# Beschreibung:
#   Lädt Bilder von einer angegebenen URL herunter und organisiert sie.
#   Führt folgende Aufgaben durch:
#   - Überprüft, ob eine URL als Argument übergeben wurde.
#   - Lädt die Webseite herunter und extrahiert alle eindeutigen Bild-URLs.
#   - Lädt die Bilder herunter und benennt sie fortlaufend nummeriert und mit dem Originalnamen.
#   - Räumt temporäre Dateien auf und zeigt die heruntergeladenen Dateien an.
#
# Verwendung:
#   ./bild_downloader.sh [OPTIONEN] <URL>
#
# Optionen:
#   -p <LÄNGE>  Anzahl der Ziffern für die fortlaufende Nummerierung (Standard: 2)
#   -o <VERZ>    Ausgabeverzeichnis (Standard: ./pics-down/)
#   -l           Aktiviere die Protokollierung in eine Datei (pics-down.log)
#   -h           Zeigt diese Hilfe an
#
# Beispiele:
#   ./bild_downloader.sh -p 2 https://example.com/gallery/
#   ./bild_downloader.sh -p 4 -o ~/Bilder/vacation_ https://example.com/photos
#
: <<'MULTILINE_COMMENT'

Erklärung des Skripts:

    Shebang-Zeile: #!/usr/bin/env bash startet das Skript mit der Bash.
    Konfigurationsbereich: Definiert Variablen für Farben, Ausgabeverzeichnis, Protokolldateiname, Präfixlänge und User-Agent.
    Funktionen:
        show_message(): Gibt eine farbige Meldung im Terminal aus.
        validate_url(): Validiert das Format der angegebenen URL.
        init_logging(): Initialisiert die Protokollierung in eine Datei.
        log(): Schreibt eine Meldung in die Protokolldatei und gibt sie im Terminal aus.
        show_help(): Zeigt die Hilfemeldung mit der Skriptverwendung und den Optionen an.
        download_images(): Lädt Bilder eines bestimmten Typs von der gegebenen URL herunter, benennt sie um und speichert sie im Ausgabeverzeichnis.
    Hauptprogramm:
        Verarbeitet Befehlszeilenargumente mit getopts.
        Überprüft, ob eine URL angegeben wurde und validiert sie.
        Erstellt das Ausgabeverzeichnis, falls es nicht existiert.
        Ruft die Funktion download_images für jeden gewünschten Bildtyp (jpg, png, etc.) auf.
        Gibt eine Erfolgsmeldung aus und listet die heruntergeladenen Dateien auf.
        Gibt den Pfad zur Protokolldatei aus, falls die Protokollierung aktiviert ist.
    Fehlerbehandlung: Das Skript behandelt Fehler wie ungültige URLs, fehlende Argumente und fehlgeschlagene Downloads.
    Protokollierung: Wenn die Option -l angegeben ist, werden detaillierte Informationen über den Downloadvorgang in einer Protokolldatei gespeichert.
    Flexibilität: Das Skript ist flexibel und ermöglicht die Anpassung des Ausgabeverzeichnisses, der Präfixlänge und anderer Parameter über Befehlszeilenoptionen.
    Robustheit: Das Skript verwendet wget mit der Option -q für den stillen Modus und behandelt Fehler beim Herunterladen von Bildern. Es verwendet sort -u, um doppelte URLs zu vermeiden.
    **Null-Byte Trennung: Das Skript verwendet find ... -print0 und while IFS= read -r -d $'\0' um Dateinamen mit Leerzeichen korrekt zu verarbeiten.

MULTILINE_COMMENT

# ==============================================
# KONFIGURATIONSBEREICH
# ==============================================
# Farbdefinitionen für die Terminalausgabe
RESET="\e[0m"                  # Setzt alle Formatierungen zurück
VIOLET="\033[38;2;255;0;53m\033[48;2;34;0;82m"   # Für Prompts
GREEN="\033[38;2;0;255;0m\033[48;2;0;25;2m"      # Erfolgsmeldungen
RED="\033[38;2;240;138;100m\033[48;2;147;18;61m" # Fehlermeldungen
BLUE="\033[38;2;100;149;237m"                    # Informationstext
PURPLE="\033[38;2;85;85;255m\033[48;2;21;16;46m" # Benutzerinteraktionen

OUT_DIR="./pics-down/"         # Standard-Ausgabeverzeichnis (aktuelles Verzeichnis)
LOG_FILE="pics-down.log"        # Name der Protokolldatei
PREFIX_LEN=2                    # Anzahl der Ziffern für die fortlaufende Nummerierung (01, 02 usw.)
USER_AGENT="Mozilla/5.0"       # Standard-User-Agent für wget
LOGGING="" # leer lassen, wird später gesetzt

# ==============================================
# FUNKTIONSDEFINITIONEN
# ==============================================

# Zeigt eine farbige Meldung im Terminal an
# Argumente:
#   $1 - Farbcode
#   $2 - Meldung
show_message() {
    echo -e "${1}${2}${RESET}"
}

# Validiert das URL-Format
# Argumente:
#   $1 - Zu validierende URL
validate_url() {
    [[ "$1" =~ ^https?:// ]] || {
        show_message "$RED" "Fehler: Die URL muss mit http:// oder https:// beginnen"
        return 1
    }
}

# Initialisiert die Protokollierung
init_logging() {
    if [[ -n "$LOGGING" ]]; then # Prüfen, ob LOGGING gesetzt ist.
        if ! touch "$OUT_DIR/$LOG_FILE"; then
            show_message "$RED" "Fehler: Keine Schreibrechte im Ordner '$OUT_DIR' oder Ordner existiert nicht."
            exit 1
        fi
        echo "=== Download Log $(date) ===" >> "$OUT_DIR/$LOG_FILE"
        echo "URL: $URL" >> "$OUT_DIR/$LOG_FILE"
        echo "Ausgabeverzeichnis: $OUT_DIR" >> "$OUT_DIR/$LOG_FILE"
        echo "DEBUG: LOG_PATH ist gesetzt auf $OUT_DIR/$LOG_FILE"
        echo "==============================================" >> "$OUT_DIR/$LOG_FILE"
    fi
}

# Protokolliert eine Meldung sowohl in der Protokolldatei als auch im Terminal (wenn verbose)
# Argumente:
#   $1 - Zu protokollierende Meldung
log() {
    local message="$1"
    if [[ -n "$LOGGING" ]]; then # Nur protokollieren, wenn LOGGING gesetzt ist.
       echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$OUT_DIR/$LOG_FILE"
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" # Gib die Meldung immer auch im Terminal aus
}

# Zeigt die Hilfeinformationen an
show_help() {
    echo -e "${PURPLE}Verwendung:${RESET}"
    echo "  $0 [OPTIONEN] <URL>"
    echo
    echo -e "${PURPLE}Optionen:${RESET}"
    echo "  -p <LÄNGE>  Anzahl der Ziffern für die fortlaufende Nummerierung (Standard: ${PREFIX_LEN})"
    echo "  -o <VERZ>    Ausgabeverzeichnis (Standard: $OUT_DIR)"
    echo "  -l           Protokollierung aktivieren"
    echo "  -h          Zeigt diese Hilfe an"
    echo
    echo -e "${PURPLE}Beispiele:${RESET}"
    echo "  $0 -p 2 https://example.com/gallery/"
    echo "  $0 -p 4 -o ~/Bilder/vacation_ https://example.com/photos"
}

# Funktion zum Herunterladen von Bildern eines bestimmten Typs
# Parameter:
#   $1 - Der Typ des Bildes (z.B. jpg, png)
#   $2 - Die URL, von der die Bilder heruntergeladen werden sollen
download_images() {
    local image_type="$1"
    local url="$2"
    local temp_list_file="image_list_$image_type.txt" # Eindeutiger Dateiname für jede Dateityp

    # Extrahiere die URLs der Bilder des angegebenen Typs und speichere sie in einer temporären Datei
    if wget -qO- "$url" | grep -oP "(?<=src=\")[^\" ]*\.$image_type\b" | sort -u > "$temp_list_file"; then #Nur Bilder des angegebenen Typs extrahieren
        local num_images=$(wc -l < "$temp_list_file")
        log "Extrahierte $num_images $image_type-Bilder von $url"

        if [[ $num_images -gt 0 ]]; then
            read -p "Sollen die $image_type-Bilder heruntergeladen werden? [y/N]: " download_choice
            case $download_choice in
                [yY])
                    mkdir -p "$OUT_DIR" # Erstelle das Ausgabeverzeichnis, falls es nicht existiert.
                    local counter=1
                    while read -r image_url; do
                        # Extrahiere den Dateinamen aus der URL
                        local filename=$(basename "$image_url")
                        # Formatiere die fortlaufende Nummer mit führenden Nullen
                        local formatted_counter=$(printf "%0${PREFIX_LEN}d" "$counter")
                        # Erstelle den neuen Dateinamen
                        local new_filename="${formatted_counter}_${filename}"
                        log "Downloading: $image_url as $new_filename"
                        # Lade das Bild herunter und benenne es um
                        wget -q -O "$OUT_DIR/$new_filename" "$image_url"
                        if [ $? -ne 0 ]; then
                           log "Failed to download $image_url"
                        fi
                        counter=$((counter+1))
                    done < "$temp_list_file"
                ;;
                [nN])
                    log "Download der $image_type-Bilder abgebrochen."
                ;;
                *)
                    show_message "$RED" "Ungültige Eingabe.  Download der $image_type-Bilder übersprungen."
                ;;
            esac
        else
            log "Keine $image_type-Bilder auf der Seite gefunden."
        fi
    else
        log "Fehler beim Extrahieren der $image_type-URLs."
    fi
    rm -f "$temp_list_file" # Entferne die temporäre Datei
}

# ===============================
# Hauptprogramm
# ===============================

# 1. Verarbeite die Befehlszeilenargumente.
while getopts ":p:o:lh" opt; do
    case $opt in
        p) PREFIX_LEN="$OPTARG" ;;     # Setze die Anzahl der Ziffern für die Nummerierung
        o) OUT_DIR="$OPTARG" ;;       # Setze das Ausgabeverzeichnis
        l) LOGGING="true" ;;       # Aktiviere die Protokollierung
        h) show_help; exit 0 ;;        # Zeige die Hilfe an und beende das Skript
        \?) show_message "$RED" "Ungültige Option: -$OPTARG"; exit 1 ;;
        :) show_message "$RED" "Option -$OPTARG benötigt ein Argument."; exit 1 ;;
    esac
done
shift $((OPTIND-1))  # Entferne die verarbeiteten Optionen von den Argumenten

# 2. Überprüfe, ob eine URL angegeben wurde.
if [[ -z "$1" ]]; then
    show_message "$RED" "Fehler: Bitte gib eine URL an."
    show_help
    exit 1
fi

# 3. Validiere die URL.
URL="$1" # Speichere die URL in einer Variablen
validate_url "$URL" || exit 1

# 4. Initialisiere die Protokollierung, falls aktiviert
if [[ -n "$LOGGING" ]]; then
  init_logging
fi

log "Starte den Download von Bildern von: $URL"
log "Ausgabeverzeichnis: $OUT_DIR"
log "Präfixlänge: $PREFIX_LEN"

# 5. Erstelle das Ausgabeverzeichnis, falls es nicht existiert.
mkdir -p "$OUT_DIR"

# 6. Lade die Bilder herunter. Rufe die Funktion download_images für jeden Dateityp auf.
download_images "jpg" "$URL"
download_images "jpeg" "$URL"
download_images "JPG" "$URL"
download_images "JPEG" "$URL"
download_images "png" "$URL"
download_images "PNG" "$URL"
download_images "svg" "$URL"
download_images "SVG" "$URL"
# Füge hier weitere Bildtypen hinzu, falls erforderlich (z.B. gif, webp, etc.)

# 7. Zeige die heruntergeladenen Dateien an.
show_message "$GREEN" "Download abgeschlossen!"
show_message "$VIOLET" "Dateien gespeichert in: $OUT_DIR"

# Listet die heruntergeladenen Dateien auf
downloaded_files=$(find "$OUT_DIR" -type f | wc -l) # Zählt die Dateien im Zielverzeichnis.
if [[ $downloaded_files -gt 0 ]]; then
    find "$OUT_DIR" -type f -print0 | while IFS= read -r -d $'\0' file; do # Null-Byte als Trennzeichen
        show_message "$PURPLE" "$file"
    done
else
    show_message "$RED" "Warnung: Keine Dateien heruntergeladen!"
fi

if [[ -n "$LOGGING" ]]; then
  show_message "$BLUE" "Detailliertes Protokoll gespeichert in: $OUT_DIR/$LOG_FILE"
fi

exit 0
