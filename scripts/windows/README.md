# Windows launch scripts (maintainer technical notes)

Participant-facing instructions live in [`docs/ja/30-run-windows.qmd`](../../docs/ja/30-run-windows.qmd).
This file is for **people who edit the scripts**.

## Files and responsibilities

| File | Responsibility |
|------|----------------|
| `start.bat` | Entry point participants run. UAC self-elevation, then orchestrates the setup `lib\*.ps1` |
| `stop.bat` | Teardown counterpart: stop the container + detach USB (no elevation) |
| `detach.bat` | Detach the receiver's USB from WSL (`/unbind` also releases the share) |
| `lib/common.ps1` | Shared constants (VID:PID, container name, ports), utilities, `Fail-With-Hint` (symptom + next step), and the standalone prerequisite checks |
| `lib/configure-receiver.ps1` | Send ASCII config commands to the receiver over COM, **before** attach |
| `lib/usb-attach.ps1` | Find the mosaic-G5 by VID:PID (`152A:8231`), then bind + attach to WSL |
| `lib/usb-detach.ps1` | Detach (and optionally unbind) the mosaic-G5 from WSL |
| `lib/detect-sbf-port.sh` | Run in WSL **as root**: find which `/dev/ttyACM*` carries the SBF stream |
| `lib/run-container.ps1` | Remove a leftover container, detect the SBF node, `docker run`, wait for the UI, open the browser |
| `lib/stop-container.ps1` | Stop and remove the container |

## Execution order (important)

```
start.bat:  common.ps1 -> configure-receiver.ps1 -> usb-attach.ps1 -> run-container.ps1
stop.bat:   stop-container.ps1 -> usb-detach.ps1
```

`configure-receiver` must run **before** `usb-attach`. Once attached, Windows can
no longer see the COM port, so the chance to send config is lost.

`run-container.ps1` hands `detect-sbf-port.sh` to WSL by value as a base64
argument (no path translation), so it works whether the repo lives on a drive
letter or the WSL filesystem. It runs the detector as root (`wsl -u root`):
`/dev/ttyACM*` permissions and `dialout` membership vary between Ubuntu images,
and root matches the access the container itself will have. It also removes any
leftover container *before* detecting, so a previous run's reader cannot starve
the detector of bytes.

## Design principles

- **Idempotent**: repeated runs do not accumulate side effects; detect existing state and skip.
- **Disposable**: a failed run can recover by re-running.
- **Errors carry a next step**: use `Fail-With-Hint` to always print symptom + remedy.
- **Constants live in `common.ps1` only**: the receiver's VID:PID, the container
  name and the published ports are defined once and dot-sourced. Do not
  re-declare them in a sibling script.
- **Prerequisite checks mirror the troubleshooting doc**: each check in
  `common.ps1` corresponds to a section of `docs/ja/90-troubleshooting.qmd` and
  its "next step" points there. Add a check and add the section, or neither.
- **The prerequisite checks collect, they do not fail fast**: a participant
  missing three things should learn all three in one run.

## TODO

- [ ] macOS / Linux equivalents. Note that `run-container.ps1` pins the SBF node
      to `/dev/ttyACM0` inside the container via `--device host:container`; the
      docs state that path OS-independently, so the other platforms must do the
      same renaming.
- [ ] Optional opt-in attach of additional USB devices (serial output targets),
      see `docs/ja/81-appendix-output.qmd`.
