#!/usr/bin/env zsh

# Überprüfen, ob eine URL als Argument übergeben wurde
if [[ $# -eq 0 ]]; then
    echo "Bitte geben Sie eine URL an."
    echo "Verwendung: $0 <URL>"
    exit 1
fi

# URL aus dem Argument extrahieren
url=$1

# Extrahieren des letzten Segments der URL für den Ordnernamen
folder_name=${url:t}

# Erstellen des Downloadordners
mkdir -p "$folder_name" && cd "$folder_name"

# Extrahieren der ersten drei Buchstaben für den Dateinamen-Präfix
prefix=${folder_name:0:3}

# Laden Sie die Webseite herunter und extrahieren Sie die Bild-URLs
wget -qO- "$url" | grep -oP '(?<=src=")[^"]*\.jpg' | sort -u > image_urls.txt

# Laden Sie die Bilder herunter und benennen Sie sie um
cat image_urls.txt | awk -v prefix="$prefix" '{printf "wget -O %s-%03d%s %s\n", prefix, NR, substr($0, length($0)-3), $0}' | zsh

# Aufräumen
rm image_urls.txt

# Zeigen Sie die heruntergeladenen Dateien an
ls -1 ${prefix}-*.jpg

echo "Download abgeschlossen. Bilder wurden in ${folder_name} gespeichert."


# Nutzungsbeispiel: 	$  jpg-download.zsh www.drachenkind-fotografie.de/pictures/romantic-dresden/
