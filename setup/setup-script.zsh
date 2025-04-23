#!/bin/zsh
set -euo pipefail

echo "🚨 Sicherheitsmodus aktiv: Skript bricht bei Fehlern oder undefinierten Variablen sofort ab."

# Hilfsfunktion für sichere Eingabe mit Default
safe_read() {
  local __resultvar=$1
  local __prompt=$2
  local __default=$3

  read "?$__prompt" input || input="$__default"
  input="${input:-$__default}"
  eval "$__resultvar=\"\$input\""
}

# 🔐 Prüfe PAM-Konfiguration für sudo_local
if grep -q "^auth" /etc/pam.d/sudo_local 2>/dev/null; then
  echo "🔐 PAM-Konfiguration für sudo_local ist bereits aktiv – keine Änderung nötig."
else
  echo "🛠️ Aktiviere PAM sudo_local-Konfiguration..."
  sed -e 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local >/dev/null
  echo "✅ PAM sudo_local wurde konfiguriert."
fi

# 🧪 Homebrew-Setup: global prüfen und ggf. lokal installieren

# 1️⃣ Prüfen ob Homebrew global installiert ist
GLOBAL_BREW_BIN=""
if [ -x "/opt/homebrew/bin/brew" ]; then
  GLOBAL_BREW_BIN="/opt/homebrew/bin/brew"
elif [ -x "/usr/local/bin/brew" ]; then
  GLOBAL_BREW_BIN="/usr/local/bin/brew"
fi

if [ -n "$GLOBAL_BREW_BIN" ]; then
  echo "⚠️ Homebrew ist global installiert unter: $GLOBAL_BREW_BIN"
  echo "❓ Möchtest du die globale Installation entfernen?"
  echo "1) Ja, bitte deinstallieren"
  echo "2) Nein, behalten"
  safe_read gopt "👉 Deine Wahl (1-2): " "2"

  case $gopt in
    1)
      echo "🧹 Starte Deinstallation der globalen Homebrew-Installation..."
      NONINTERACTIVE=1 \
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
      echo "✅ Globale Homebrew-Installation entfernt."
      ;;
    2)
      echo "⏭️ Globale Installation bleibt erhalten. Fahre fort..."
      ;;
    *)
      echo "❌ Ungültige Eingabe – breche ab."
      exit 1
      ;;
  esac
else
  echo "✅ Keine globale Homebrew-Installation gefunden."
fi

# 2️⃣ Benutzerkontext-Installation prüfen
BREW_PREFIX="$HOME/.homebrew"
BREW_BIN="$BREW_PREFIX/bin/brew"
HOMEBREW_CELLAR="$BREW_PREFIX/Cellar"
HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"

[ -d "$BREW_PREFIX" ] || mkdir -p "$BREW_PREFIX"
[ -d "$HOMEBREW_CELLAR" ] || mkdir -p "$HOMEBREW_CELLAR"
[ -d "$HOME/Applications" ] || mkdir -p "$HOME/Applications"

if [ ! -x "$BREW_BIN" ]; then
  echo "❌ Homebrew ist im Benutzerkontext NICHT installiert."
  echo "🚀 Starte Installation von Homebrew im Benutzerverzeichnis..."

  export NONINTERACTIVE=1
  export CI=1
  export HOMEBREW_PREFIX="$BREW_PREFIX"
  export PATH="$HOMEBREW_PREFIX/bin:$PATH"

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo "✅ Homebrew wurde im Benutzerkontext installiert."
else
  echo "🔄 Homebrew im Benutzerkontext ist bereits installiert. Prüfe auf Updates..."
  "$BREW_BIN" update && "$BREW_BIN" upgrade
  echo "✅ Homebrew ist auf dem neuesten Stand."
fi

# 🧠 Konfiguriere Umgebungsvariablen in der zshrc
ZSHRC="$HOME/.zshrc"
add_to_zshrc() {
  local line="$1"
  grep -qxF "$line" "$ZSHRC" || echo "$line" >> "$ZSHRC"
}

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

# 📦 Auswahl des Brewfiles
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo ""
echo "🔍 Wähle aus, welches brewfile du ausführen möchtest:"
echo "1) Privat"
echo "2) Arbeit"
echo "3) Abbrechen"
safe_read opt "👉 Deine Wahl (1-3): " "3"

case $opt in
  1)
    BREWFILE_PATH="$SCRIPT_DIR/brew/brewfile.private"
    ;;
  2)
    BREWFILE_PATH="$SCRIPT_DIR/brew/brewfile.work"
    ;;
  3)
    echo "🚫 Auswahl abgebrochen. Kein brewfile wird ausgeführt."
    exit 0
    ;;
  *)
    echo "❌ Ungültige Eingabe. Breche ab."
    exit 1
    ;;
esac

# ✅ brewfile ausführen (nur User-Brew verwenden!)
if [ -f "$BREWFILE_PATH" ]; then
  echo "📦 brewfile gewählt: $BREWFILE_PATH"
  "$BREW_BIN" bundle --file="$BREWFILE_PATH"
  echo "✅ brewfile erfolgreich ausgeführt."
else
  echo "❌ Das gewählte brewfile wurde nicht gefunden: $BREWFILE_PATH"
  exit 1
fi

# 📦 OPTIONAL: Globale Tools installieren?
echo ""
echo "🌐 Möchtest du zusätzlich globale Tools installieren?"
echo "1) Ja"
echo "2) Nein"
safe_read gopt "👉 Deine Wahl (1-2): " "2"

case $gopt in
  1)
    GLOBAL_BREWFILE_PATH="$SCRIPT_DIR/brew/brewfile.global"
    if [ -f "$GLOBAL_BREWFILE_PATH" ]; then
      echo "🌐 Führe globales brewfile aus: $GLOBAL_BREWFILE_PATH"
      echo "⚠️  Achtung: Dies verwendet ggf. globale brew-Installation (wenn noch vorhanden)"
      brew bundle --file="$GLOBAL_BREWFILE_PATH"
      echo "✅ Globales Brewfile erfolgreich ausgeführt."
    else
      echo "❌ brewfile.global nicht gefunden unter $GLOBAL_BREWFILE_PATH"
    fi
    ;;
  2)
    echo "⏩ Überspringe globale Tools."
    ;;
  *)
    echo "❌ Ungültige Eingabe. Breche ab."
    exit 1
    ;;
esac

# 📂 Öffne Finder und erinnere an manuelles Hinzufügen zu Favoriten
echo ""
echo "ℹ️ Der Ordner '$HOME/Applications' wird gleich im Finder geöffnet."
for i in {5..1}; do
  echo "⏳ Ordner öffnet sich in $i Sekunden..."
  sleep 1
done
open "$HOME/Applications"
echo "✅ Finder geöffnet."
