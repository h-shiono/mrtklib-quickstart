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
#  Needs read access to /dev/ttyACM* (root, or a user in the dialout group);
#  run-container.ps1 therefore invokes it via `wsl -u root`. A port the user
#  cannot read is reported as such, NOT as an empty stream: that exact
#  confusion (EACCES silently shown as "0 bytes" on every port) cost a field
#  setup days of debugging.
#
#  Usage: detect-sbf-port.sh [seconds_per_port] [max_bytes]
# ============================================================================
set -uo pipefail

seconds="${1:-3}"
max_bytes="${2:-4096}"

best=""
best_count=0
skipped=0

shopt -s nullglob
ports=(/dev/ttyACM*)
if [ ${#ports[@]} -eq 0 ]; then
  echo "No /dev/ttyACM* found. Is the receiver attached to WSL (usbipd)?" >&2
  exit 1
fi

for p in "${ports[@]}"; do
  # An unreadable node must say so, loudly. Suppressing the error would make
  # it print "0 bytes" like a silent port, and the participant then debugs the
  # receiver's output settings instead of the actual permission problem.
  if [ ! -r "$p" ]; then
    echo "  $p: permission denied for user $(id -un)" >&2
    echo "     fix: run as root, or 'sudo usermod -aG dialout \$USER' then 'wsl --shutdown'" >&2
    skipped=1
    continue
  fi
  # Best-effort raw mode; USB CDC ignores baud but raw avoids line munging.
  stty -F "$p" raw -echo 2>/dev/null || true
  # Read with `cat` and cap with `head`, rather than `timeout head -c`: when the
  # port delivers fewer than max_bytes within the window, timeout SIGTERMs head
  # before its stdout buffer is flushed and every byte read is discarded, so a
  # live but slow SBF stream is reported as 0 bytes -- a false "no SBF stream".
  # `cat` writes each chunk as it reads it, so whatever arrived still counts.
  # cat's stderr is deliberately NOT suppressed: an unexpected failure (EIO,
  # a vanished device) must surface in the diagnostics, not vanish with it.
  # od, not xxd: od is coreutils and exists on any distro, xxd is not
  # guaranteed on a fresh minimal install (-v, or od elides repeated lines).
  hex=$({ timeout "$seconds" cat "$p"; } | head -c "$max_bytes" | od -An -v -tx1 | tr -d ' \n')
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
if [ "$skipped" -eq 1 ]; then
  # Pointing at the receiver's output settings here would be a lie: ports we
  # could not even read say nothing about what the receiver sends.
  echo "Port(s) were skipped for lack of read permission (see above); fix that first." >&2
else
  echo "Check that the receiver's SBF output is directed to a USB port (USB1/USB2)." >&2
fi
exit 1
