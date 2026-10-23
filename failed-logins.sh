#!/usr/bin/env bash
# Summarises failed SSH logins: top source IPs and targeted usernames.
#
# Usage: failed-logins.sh [-f LOGFILE] [-t TOP] [-m MIN_ATTEMPTS]
#   -f  auth log to read (default: /var/log/auth.log, or journalctl if absent)
#   -t  how many lines to show in each ranking (default: 10)
#   -m  flag IPs with at least this many failures (default: 5)
#
# Read-only: it only prints a report. Blocking is left to fail2ban / the firewall.

set -euo pipefail

LOG=""
TOP=10
MIN=5

while getopts ":f:t:m:h" opt; do
  case "$opt" in
    f) LOG="$OPTARG" ;;
    t) TOP="$OPTARG" ;;
    m) MIN="$OPTARG" ;;
    h|*) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

read_log() {
  if [[ -n "$LOG" ]]; then
    cat -- "$LOG"
  elif [[ -r /var/log/auth.log ]]; then
    cat /var/log/auth.log
  elif [[ -r /var/log/secure ]]; then            # RHEL / Rocky / Alma
    cat /var/log/secure
  elif command -v journalctl > /dev/null; then
    journalctl -u ssh -u sshd --no-pager -o short 2>/dev/null
  else
    echo "no readable auth log found" >&2; exit 1
  fi
}

# Keep only "Failed password" / "Invalid user" lines, extract user and IP
FAILS="$(read_log | grep -E 'sshd\[[0-9]+\]: (Failed password|Invalid user)' || true)"

if [[ -z "$FAILS" ]]; then
  echo "No failed SSH login found."
  exit 0
fi

TOTAL="$(printf '%s\n' "$FAILS" | wc -l)"

echo "== Failed SSH logins: $TOTAL =="
echo
echo "-- Top $TOP source IPs --"
printf '%s\n' "$FAILS" \
  | grep -oE 'from [0-9a-fA-F:.]+' | awk '{print $2}' \
  | sort | uniq -c | sort -rn | head -n "$TOP" \
  | awk -v min="$MIN" '{ flag = ($1 >= min) ? "  <-- brute force?" : ""; printf "%7d  %s%s\n", $1, $2, flag }'

echo
echo "-- Top $TOP targeted usernames --"
printf '%s\n' "$FAILS" \
  | sed -nE 's/.*(Failed password for (invalid user )?|Invalid user )([^ ]+) from.*/\3/p' \
  | sort | uniq -c | sort -rn | head -n "$TOP" \
  | awk '{ printf "%7d  %s\n", $1, $2 }'
