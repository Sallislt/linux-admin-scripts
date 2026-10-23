#!/usr/bin/env bash
# Compressed, checksummed backups with retention.
#
# Usage: backup.sh -s SOURCE_DIR -d DEST_DIR [-k KEEP] [-n NAME]
#   -s  directory to back up
#   -d  directory where archives are stored
#   -k  number of archives to keep (default: 7)
#   -n  archive name prefix (default: basename of SOURCE_DIR)
#
# Example (cron, every night at 02:30):
#   30 2 * * * /opt/scripts/backup.sh -s /var/www -d /srv/backups -k 14 >> /var/log/backup.log 2>&1

set -euo pipefail

KEEP=7
NAME=""
SRC=""
DEST=""

log() { printf '%s [backup] %s\n' "$(date '+%F %T')" "$*"; }
die() { log "ERROR: $*"; exit 1; }

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while getopts ":s:d:k:n:h" opt; do
  case "$opt" in
    s) SRC="$OPTARG" ;;
    d) DEST="$OPTARG" ;;
    k) KEEP="$OPTARG" ;;
    n) NAME="$OPTARG" ;;
    h|*) usage ;;
  esac
done

[[ -n "$SRC" && -n "$DEST" ]] || usage
[[ -d "$SRC" ]] || die "source '$SRC' does not exist"
[[ "$KEEP" =~ ^[1-9][0-9]*$ ]] || die "-k must be a positive integer"
NAME="${NAME:-$(basename "$SRC")}"

mkdir -p "$DEST"
STAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE="$DEST/${NAME}-${STAMP}.tar.gz"
TMP="${ARCHIVE}.part"

# Remove the partial file if anything fails
trap 'rm -f "$TMP"' ERR

log "archiving $SRC -> $ARCHIVE"
tar -czf "$TMP" -C "$(dirname "$SRC")" "$(basename "$SRC")"
mv "$TMP" "$ARCHIVE"

# Integrity: store the checksum next to the archive and verify it immediately
( cd "$DEST" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256" )
( cd "$DEST" && sha256sum --quiet -c "$(basename "$ARCHIVE").sha256" ) || die "checksum verification failed"
tar -tzf "$ARCHIVE" > /dev/null || die "archive is not readable"

SIZE="$(du -h "$ARCHIVE" | cut -f1)"
log "OK ($SIZE, sha256 verified)"

# Retention: keep the newest $KEEP archives for this prefix
mapfile -t OLD < <(ls -1t "$DEST/${NAME}-"*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))")
for f in "${OLD[@]}"; do
  log "removing old archive $(basename "$f")"
  rm -f -- "$f" "$f.sha256"
done
