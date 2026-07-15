#!/usr/bin/env bash
# ============================================================================
#  detect-sbf-port.sh  -  find which /dev/ttyACM* carries the SBF stream
#
#  The mosaic-G5 exposes two virtual COM ports over one USB device; after
#  `usbipd attach --wsl` they appear in WSL as /dev/ttyACM0 and /dev/ttyACM1.
#  Only one of them carries the receiver's SBF output. We tell them apart by
#  content: every SBF block starts with the sync bytes '$@' (0x24 0x40), so we
#  read a short sample from each port and pick the one where that sync appears.
#
#  stdout : the chosen device path (e.g. /dev/ttyACM1) on success
#  stderr : per-port diagnostics
#  exit   : 0 if found, 1 if no SBF stream on any port
#
#  Usage: detect-sbf-port.sh [seconds_per_port] [max_bytes]
# ============================================================================
set -uo pipefail

seconds="${1:-3}"
max_bytes="${2:-4096}"

best=""
best_count=0

shopt -s nullglob
ports=(/dev/ttyACM*)
if [ ${#ports[@]} -eq 0 ]; then
  echo "No /dev/ttyACM* found. Is the receiver attached to WSL (usbipd)?" >&2
  exit 1
fi

for p in "${ports[@]}"; do
  # Best-effort raw mode; USB CDC ignores baud but raw avoids line munging.
  stty -F "$p" raw -echo 2>/dev/null || true
  hex=$(timeout "$seconds" head -c "$max_bytes" "$p" 2>/dev/null | xxd -p | tr -d '\n')
  nbytes=$(( ${#hex} / 2 ))
  count=$(grep -o 2440 <<<"$hex" | wc -l)
  echo "  $p: ${nbytes} bytes, SBF sync '\$@' x${count}" >&2
  if [ "$count" -gt "$best_count" ]; then
    best_count=$count
    best="$p"
  fi
done

if [ -n "$best" ]; then
  echo "$best"
  exit 0
fi

echo "No SBF stream ('\$@' sync) detected on any /dev/ttyACM*." >&2
echo "Check that the receiver's SBF output is directed to a USB port (USB1/USB2)." >&2
exit 1
