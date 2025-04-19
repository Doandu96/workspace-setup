#!/bin/zsh
emulate -L zsh

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

# 📦 Auswahl des brewfiles je nach Kontext (private oder work)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "🔍 Wähle aus, welches brewfile du ausführen möchtest:"
echo "1) Privat"
echo "2) Arbeit"
echo "3) Abbrechen"
read "opt?👉 Deine Wahl (1-3): "

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

# ✅ brewfile ausführen, wenn vorhanden
if [ -f "$BREWFILE_PATH" ]; then
  echo "📦 brewfile gewählt: $BREWFILE_PATH"
  brew bundle --file="$BREWFILE_PATH"
  echo "✅ brewfile erfolgreich ausgeführt."
else
  echo "❌ Das gewählte brewfile wurde nicht gefunden: $BREWFILE_PATH"
  exit 1
fi

# ───────────────────────────────────────────────
# 📦 OPTIONAL: Globale Tools installieren?
# ───────────────────────────────────────────────
echo ""
echo "🌐 Möchtest du zusätzlich globale Tools installieren?"
echo "1) Ja"
echo "2) Nein"
read "gopt?👉 Deine Wahl (1-2): "

case $gopt in
  1)
    GLOBAL_BREWFILE_PATH="$SCRIPT_DIR/brew/brewfile.global"
    if [ -f "$GLOBAL_BREWFILE_PATH" ]; then
      echo "🌐 Führe globales brewfile aus: $GLOBAL_BREWFILE_PATH"

      # 🔧 Temporär Umgebungsvariablen deaktivieren für systemweite Installation
      unset HOMEBREW_PREFIX
      unset HOMEBREW_CELLAR
      unset HOMEBREW_CASK_OPTS

      echo "⚠️  Achtung: Für globale Casks kann sudo erforderlich sein..."
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
echo "👉 Du kannst ihn danach manuell per Drag & Drop zur Finder-Seitenleiste hinzufügen."

# Countdown vor Öffnen
for i in {10..1}; do
  echo "⏳ Ordner öffnet sich in $i Sekunden..."
  sleep 1
done

open "$HOME/Applications"
echo "✅ Finder geöffnet."
