# Windows launch scripts (maintainer technical notes)

Participant-facing instructions live in [`docs/ja/30-run-windows.qmd`](../../docs/ja/30-run-windows.qmd).
This file is for **people who edit the scripts**.

## Files and responsibilities

| File | Responsibility |
|------|----------------|
| `start.bat` | The single file participants run. UAC self-elevation, then orchestrates `lib\*.ps1` |
| `lib/common.ps1` | Shared utilities, idempotent prerequisite checks, error -> next-step messages |
| `lib/configure-receiver.ps1` | Send config commands to COM on the Windows side, **before** attach |
| `lib/usb-attach.ps1` | Detect the mosaic-G5 busid by VID:PID, then bind + attach |
| `lib/run-container.ps1` | `docker run` (passing both COM streams) -> open the browser |

## Execution order (important)

```
common.ps1 -> configure-receiver.ps1 -> usb-attach.ps1 -> run-container.ps1
```

`configure-receiver` must run **before** `usb-attach`. Once attached, Windows can
no longer see the COM port, so the chance to send config is lost.

## Design principles

- **Idempotent**: repeated runs do not accumulate side effects; detect existing state and skip.
- **Disposable**: a failed run can recover by re-running.
- **Errors carry a next step**: use `Fail-With-Hint` to always print symptom + remedy.

## TODO (skeleton stage, before implementation)

- [ ] Set the real mosaic-G5 VID:PID in `usb-attach.ps1`
- [ ] Finalize the config command sequence in `configure-receiver.ps1`
- [ ] Finalize the image name / port / `--device` paths in `run-container.ps1`
- [ ] Implement the prerequisite checks (Docker / usbipd / WSL2) in `common.ps1`
