#!/usr/bin/env bash
# Quick server health check: disk, memory, load, failed services, pending updates.
# Exit code: 0 = OK, 1 = at least one WARNING (usable from cron or monitoring).
#
# Usage: health-check.sh [-d DISK_PCT] [-m MEM_PCT]
#   -d  disk usage warning threshold in % (default: 85)
#   -m  memory usage warning threshold in % (default: 90)

set -uo pipefail

DISK_MAX=85
MEM_MAX=90
STATUS=0

while getopts ":d:m:h" opt; do
  case "$opt" in
    d) DISK_MAX="$OPTARG" ;;
    m) MEM_MAX="$OPTARG" ;;
    h|*) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

ok()   { printf '  [ OK ] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; STATUS=1; }
info() { printf '  [INFO] %s\n' "$*"; }

echo "Health check - $(hostname) - $(date '+%F %T')"

echo "Disk"
while read -r pct mount; do
  used="${pct%\%}"
  if (( used >= DISK_MAX )); then warn "$mount ${used}% used"; else ok "$mount ${used}% used"; fi
done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 {print $1, $2}')

echo "Memory"
if [[ -r /proc/meminfo ]]; then
  total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  # older kernels: estimate with free + buffers + cache
  [[ -n "$avail" ]] || avail=$(awk '/^(MemFree|Buffers|Cached):/ {s += $2} END {print s}' /proc/meminfo)
  used=$(( (total - avail) * 100 / total ))
  if (( used >= MEM_MAX )); then warn "memory ${used}% used"; else ok "memory ${used}% used"; fi
else
  info "/proc/meminfo not available"
fi

echo "Load"
if [[ -r /proc/loadavg ]]; then
  cores=$(nproc 2>/dev/null || echo 1)
  load1=$(cut -d' ' -f1 /proc/loadavg)
  if awk -v l="$load1" -v c="$cores" 'BEGIN { exit !(l > c) }'; then
    warn "load $load1 for $cores core(s)"
  else
    ok "load $load1 for $cores core(s)"
  fi
fi

echo "Services"
if command -v systemctl > /dev/null; then
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
  if [[ -n "$failed" ]]; then
    while read -r unit; do warn "failed unit: $unit"; done <<< "$failed"
  else
    ok "no failed systemd unit"
  fi
else
  info "systemd not available"
fi

echo "Updates"
if command -v apt-get > /dev/null; then
  count=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ' || true)
  security=$(apt-get -s upgrade 2>/dev/null | grep '^Inst ' | grep -ci 'security' || true)
  if (( security > 0 )); then warn "$count update(s) pending, $security security"
  elif (( count > 0 )); then info "$count update(s) pending"
  else ok "system up to date"; fi
else
  info "apt not available"
fi

exit "$STATUS"
