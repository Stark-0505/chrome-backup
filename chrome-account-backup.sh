#!/usr/bin/env bash
# Chrome Beta "signed-in account" backup/restore + fresh-install bootstrap, for KDE Fedora.
#
# This script contains NO secrets. The actual account archive
# (chrome-beta-account-backup.tar.gz — live OAuth tokens + the KWallet secret
# that decrypts them) must be copied in separately (USB/cloud), never committed
# to this repo. See README.md.
#
# Usage:
#   ./chrome-account-backup.sh backup     # run on the OLD system, before wiping
#   ./chrome-account-backup.sh restore    # run on the NEW system, with the archive
#                                          # already placed in $HOME, BEFORE first
#                                          # launching Chrome Beta
#   ./chrome-account-backup.sh setup      # restore + install Chrome Beta, in one go —
#                                          # this is what the one-line curl bootstrap calls

set -euo pipefail
shopt -s nullglob

CHROME_DIR="$HOME/.config/google-chrome-beta"
WALLET_REL=".local/share/kwalletd"
KWALLETRC_REL=".config/kwalletrc"
ARCHIVE="$HOME/chrome-beta-account-backup.tar.gz"
ENC_ARCHIVE="$ARCHIVE.gpg"
STAGE_NAME=".chrome-account-stage"
STAGE="$HOME/$STAGE_NAME"
CHROME_RPM_URL="https://dl.google.com/linux/direct/google-chrome-beta_current_x86_64.rpm"
REPO_RAW_BASE="https://raw.githubusercontent.com/Stark-0505/chrome-backup/main"

# Files/dirs that carry sign-in state, per profile.
KEEP=(Preferences "Secure Preferences" "Web Data" "Web Data-journal" \
      "Account Web Data" "Account Web Data-journal" Accounts "trusted_vault.pb")

do_backup() {
  pkill -TERM -f 'chrome.*beta' 2>/dev/null || true
  sleep 1

  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp "$CHROME_DIR/Local State" "$STAGE/"

  for p in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile*; do
    [ -d "$p" ] || continue
    name=$(basename "$p")
    mkdir -p "$STAGE/$name"
    for f in "${KEEP[@]}"; do
      [ -e "$p/$f" ] && cp -r "$p/$f" "$STAGE/$name/"
    done
  done

  EXTRA=()
  if [ -f "$HOME/$KWALLETRC_REL" ]; then
    EXTRA+=("$KWALLETRC_REL")
  fi

  tar -czf "$ARCHIVE" -C "$HOME" "$STAGE_NAME" "$WALLET_REL" "${EXTRA[@]}"
  rm -rf "$STAGE"

  echo "Backup written: $ARCHIVE"
  du -h "$ARCHIVE"
  echo "Copy this file to a USB drive / private storage NOW — do NOT commit it to git."
}

do_encrypt() {
  [ -f "$ARCHIVE" ] || { echo "Run '$0 backup' first."; exit 1; }
  gpg --symmetric --cipher-algo AES256 -o "$ENC_ARCHIVE" "$ARCHIVE"
  echo "Encrypted: $ENC_ARCHIVE"
  echo "Commit THIS file (never the plaintext $ARCHIVE) to the repo:"
  echo "  git add $(basename "$ENC_ARCHIVE") && git commit -m 'update encrypted backup' && git push"
}

ensure_archive() {
  # Already have the plaintext locally (e.g. copied via USB)? Use it as-is.
  [ -f "$ARCHIVE" ] && return

  # Otherwise pull the encrypted blob from the repo and decrypt it.
  if [ ! -f "$ENC_ARCHIVE" ]; then
    echo "No local archive found — fetching the encrypted backup from the repo..."
    curl -fsSL "$REPO_RAW_BASE/chrome-beta-account-backup.tar.gz.gpg" -o "$ENC_ARCHIVE"
  fi
  echo "Decrypting (you'll be prompted for the passphrase)..."
  gpg --output "$ARCHIVE" --decrypt "$ENC_ARCHIVE"
}

do_restore() {
  ensure_archive
  [ -f "$ARCHIVE" ] || { echo "Still no archive at $ARCHIVE — aborting."; exit 1; }

  tar -xzf "$ARCHIVE" -C "$HOME"   # restores $STAGE and ~/.local/share/kwalletd (+ kwalletrc if present)

  mkdir -p "$CHROME_DIR"
  cp "$STAGE/Local State" "$CHROME_DIR/"

  for d in "$STAGE"/*/; do
    name=$(basename "$d")
    mkdir -p "$CHROME_DIR/$name"
    cp -r "$d"* "$CHROME_DIR/$name/"
  done

  rm -rf "$STAGE"
  echo "Restored profile files into $CHROME_DIR and the wallet secret into ~/$WALLET_REL"
}

do_setup() {
  do_restore
  echo
  echo "Installing Google Chrome Beta..."
  sudo dnf install -y "$CHROME_RPM_URL"
  echo
  echo "Done. Log out and log back in, then launch Chrome Beta —"
  echo "each profile should already show its Google account signed in."
}

case "${1:-}" in
  backup)  do_backup  ;;
  encrypt) do_encrypt ;;
  restore) do_restore ;;
  setup)   do_setup   ;;
  *) echo "Usage: $0 {backup|encrypt|restore|setup}"; exit 1 ;;
esac
