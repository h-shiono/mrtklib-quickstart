# Windows launch scripts (maintainer technical notes)

Participant-facing instructions live in [`docs/ja/30-run-windows.qmd`](../../docs/ja/30-run-windows.qmd).
This file is for **people who edit the scripts**.

## Files and responsibilities

| File | Responsibility |
|------|----------------|
| `start.bat` | Entry point participants run. UAC self-elevation, then orchestrates the setup `lib\*.ps1` |
| `stop.bat` | Teardown counterpart: stop the container + detach USB (no elevation) |
| `detach.bat` | Detach the receiver's USB from WSL (`/unbind` also releases the share) |
| `lib/common.ps1` | Shared utilities, prerequisite checks, `Fail-With-Hint` (symptom + next step) |
| `lib/configure-receiver.ps1` | Send ASCII config commands to the receiver over COM, **before** attach |
| `lib/usb-attach.ps1` | Find the mosaic-G5 by VID:PID (`152A:8231`), then bind + attach to WSL |
| `lib/usb-detach.ps1` | Detach (and optionally unbind) the mosaic-G5 from WSL |
| `lib/detect-sbf-port.sh` | Run in WSL: find which `/dev/ttyACM*` carries the SBF stream |
| `lib/run-container.ps1` | Detect the SBF node, `docker run`, wait for the UI, open the browser |
| `lib/stop-container.ps1` | Stop and remove the container |

## Execution order (important)

```
start.bat:  common.ps1 -> configure-receiver.ps1 -> usb-attach.ps1 -> run-container.ps1
stop.bat:   stop-container.ps1 -> usb-detach.ps1
```

`configure-receiver` must run **before** `usb-attach`. Once attached, Windows can
no longer see the COM port, so the chance to send config is lost.

`run-container.ps1` pipes `detect-sbf-port.sh` into WSL over stdin (no path
translation), so it works whether the repo lives on a drive letter or the WSL
filesystem.

## Design principles

- **Idempotent**: repeated runs do not accumulate side effects; detect existing state and skip.
- **Disposable**: a failed run can recover by re-running.
- **Errors carry a next step**: use `Fail-With-Hint` to always print symptom + remedy.

## TODO

- [ ] Flesh out the prerequisite checks in `common.ps1` (Docker **daemon** running,
      usbipd-win present, WSL2 enabled) — currently only checks that `docker` exists.
- [ ] macOS / Linux equivalents.
