#!/bin/zsh

# 🔐 Prüfe PAM-Konfiguration für sudo_local
if grep -q "^auth" /etc/pam.d/sudo_local 2>/dev/null; then
  echo "🔐 PAM-Konfiguration für sudo_local ist bereits aktiv – keine Änderung nötig."
else
  echo "🛠️ Aktiviere PAM sudo_local-Konfiguration..."
  sed -e 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local >/dev/null
  echo "✅ PAM sudo_local wurde konfiguriert."
fi

# 🍺 Prüfe ob Homebrew installiert ist
if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew ist nicht installiert. Starte Installation..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "✅ Homebrew wurde installiert."
else
  echo "🔄 Homebrew ist bereits installiert. Prüfe auf Updates..."
  brew update && brew upgrade
  echo "✅ Homebrew ist auf dem neuesten Stand."
fi

# 🗂️ Definiere Zielverzeichnisse im Benutzerkontext
BREW_PREFIX="$HOME/.homebrew"
HOMEBREW_CELLAR="$BREW_PREFIX/Cellar"
HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"

# 📁 Stelle sicher, dass die Zielordner existieren
[ -d "$BREW_PREFIX" ] || mkdir -p "$BREW_PREFIX"
[ -d "$HOMEBREW_CELLAR" ] || mkdir -p "$HOMEBREW_CELLAR"
[ -d "$HOME/Applications" ] || mkdir -p "$HOME/Applications"

echo "📁 Benutzerdefinierte Verzeichnisse erstellt (falls nicht vorhanden)"

# 🧠 Konfiguriere Umgebungsvariablen in der zshrc
ZSHRC="$HOME/.zshrc"

# 🔍 Funktion zum Hinzufügen von Zeilen in die zshrc, falls sie noch nicht existieren
add_to_zshrc() {
  local line="$1"
  grep -qxF "$line" "$ZSHRC" || echo "$line" >> "$ZSHRC"
}

# ⚙️ Setze Homebrew-relevante Umgebungsvariablen nur wenn sie nicht schon gesetzt sind
if ! grep -q "HOMEBREW_PREFIX=\"$BREW_PREFIX\"" "$ZSHRC"; then
  add_to_zshrc "# Homebrew benutzerdefinierte Pfade"
  add_to_zshrc "export HOMEBREW_PREFIX=\"$BREW_PREFIX\""
  add_to_zshrc "export HOMEBREW_CELLAR=\"$HOMEBREW_CELLAR\""
  add_to_zshrc "export HOMEBREW_CASK_OPTS=\"$HOMEBREW_CASK_OPTS\""
  add_to_zshrc "export PATH=\"\$HOMEBREW_PREFIX/bin:\$PATH\""
  echo "✅ Homebrew-Umgebungsvariablen zur .zshrc hinzugefügt"
else
  echo "ℹ️ Homebrew-Umgebungsvariablen sind bereits in der .zshrc vorhanden."
fi

# 🌀 Quelle die Datei, damit die Änderungen im aktuellen Terminal gelten
source "$ZSHRC"
echo "🔄 .zshrc neu geladen"

# ✅ Fertig
echo "🎉 Homebrew ist nun so konfiguriert, dass es im Benutzerkontext installiert"

echo "🔄 Anpassung der Favoriten:"

# Zielordner, der zur Finder-Seitenleiste hinzugefügt werden soll
# "~/Applications" ist oft ein benutzerdefinierter Ordner für Apps, die nicht systemweit installiert sind
# Der Pfad wird hier absolut und ohne Symlinks aufgelöst, um Vergleichsprobleme zu vermeiden
resolved_target_folder=$(cd "$HOME/Applications" && pwd -P)

# Wenn der Ordner nicht existiert, Skript mit Fehler verlassen
if [[ ! -d "$resolved_target_folder" ]]; then
  echo "[Fehler] Der Ordner $resolved_target_folder existiert nicht."
  exit 1
fi

echo "[Info] Zielordner existiert: $resolved_target_folder"
echo "[Info] Prüfe, ob der Ordner in der Finder-Seitenleiste enthalten ist..."

# Aufruf von AppleScript über osascript, um mit dem Finder zu interagieren
osascript <<EOF
-- AppleScript beginnt hier

set logPrefix to "[AppleScript] "

tell application "Finder"
    -- Zielordner als Alias setzen
    set targetFolder to POSIX file "$resolved_target_folder" as alias

    try
        -- Liste der aktuellen Favoriten-Objekte abrufen
        set sidebarItems to every item of sidebar list "favorites"

        -- Prüfen, ob der Zielordner bereits in den Favoriten enthalten ist
        set alreadyExists to false
        set normalizedTargetPath to "$resolved_target_folder/"

        repeat with i from 1 to count of sidebarItems
            set currentItem to item i of sidebarItems
            try
                -- Pfad jedes Favoriten-Eintrags holen
                set itemPath to POSIX path of (URL of currentItem as text)
                if itemPath is equal to normalizedTargetPath then
                    set alreadyExists to true
                    exit repeat
                end if
            end try
        end repeat

        if alreadyExists then
            do shell script "echo '[Info] Ordner ist bereits in der Finder-Seitenleiste enthalten.'"
        else
            do shell script "echo '[Info] Ordner wird zur Finder-Seitenleiste hinzugefügt.'"
            -- Ordner im Finder öffnen – das kann helfen, ihn automatisch zur Seitenleiste hinzuzufügen
            open targetFolder
            delay 0.5
            set targetWin to front window
            set sidebarList to sidebar width of targetWin
            do shell script "echo '[Erfolg] Ordner wurde hinzugefügt (indirekt über Öffnen im Finder).'"
        end if

    on error errMsg
        -- Fehleranzeige im Dialog und auch Logging über Konsole
        do shell script "echo '[Fehler] AppleScript: ' & quoted form of errMsg"
        display dialog "Fehler: " & errMsg buttons {"OK"}
    end try
end tell

EOF
echo "✅ Anpassung der Favoriten abgeschlossen"

# 📦 Auswahl des brewfiles je nach Kontext (private oder work)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "🔍 Wähle aus, welches brewfile du ausführen möchtest:"
PS3="👉 Deine Wahl (Zahl eingeben): "

options=("Privat" "Arbeit" "Abbrechen")

select opt in "${options[@]}"; do
  case $opt in
    "Privat")
      BREWFILE_PATH="$SCRIPT_DIR/brew/brewfile.private"
      break
      ;;
    "Arbeit")
      BREWFILE_PATH="$SCRIPT_DIR/brew/brewfile.work"
      break
      ;;
    "Abbrechen")
      echo "🚫 Auswahl abgebrochen. Kein brewfile wird ausgeführt."
      exit 0
      ;;
    *)
      echo "❌ Ungültige Eingabe. Bitte 1, 2 oder 3 wählen."
      ;;
  esac
done

# ✅ brewfile ausführen, wenn vorhanden
if [ -f "$BREWFILE_PATH" ]; then
  echo "📦 brewfile gewählt: $BREWFILE_PATH"
  brew bundle --file="$BREWFILE_PATH"
  echo "✅ brewfile erfolgreich ausgeführt."
else
  echo "❌ Das gewählte brewfile wurde nicht gefunden: $BREWFILE_PATH"
  exit 1
fi
