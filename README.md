# mrtklib-quickstart

**Experience real-time PPP positioning with MADOCA-PPP** using a Septentrio
mosaic-G5 receiver and [MRTKLIB](https://github.com/h-shiono/MRTKLIB) — packaged
so it runs even if you are not comfortable with Docker.

📖 **Documentation site**: <https://h-shiono.github.io/mrtklib-quickstart/>
(日本語 / English)

This repository wraps
[mrtklib-docker-ui](https://github.com/h-shiono/mrtklib-docker-ui) with
OS-specific launch / first-run scripts (Windows / macOS / Linux) and the
OS-independent teaching material, all in one place. A single `start` script
configures the receiver, attaches its USB, launches the container, and opens the
web UI.

## What you'll need

**Hardware**

- Septentrio **mosaic-G5 P6** evaluation kit
- A full-band GNSS antenna (e.g. Yokowo YOZ-52728), placed with a clear sky view
- A USB cable to connect the receiver to the host PC

**Software**

- Windows 11 (macOS / Linux also supported)
- Docker Desktop

WSL2, usbipd-win and the receiver driver (RxTools) are installed as part of the
guide — see the install chapter for your OS.

## How it works

```mermaid
flowchart LR
  gps((GPS)) -.-> ant(GNSS Antenna)
  glo((GLO)) -.-> ant
  gal((GAL)) -.-> ant
  bds((BDS)) -.-> ant
  qzs((QZS)) -.-> ant

  ant -- RF --> rcv(mosaic-G5 P6)
  rcv -- "USB Serial<br/>(SBF)" --> engine["MRTKLIB Engine"]

  subgraph Host
    subgraph Docker
      engine <--> ui[Web UI]
    end
  end

  ui -.- user((User))
```

The receiver observes GPS / GLONASS / Galileo / BeiDou / QZSS and outputs the raw
measurements plus the QZSS L6 corrections as SBF; MRTKLIB (in Docker) computes the
PPP solution and shows it in the web UI.

---

## Who are you? (routing for three audiences)

### 1. Participant — "I just want it to run"

Run the script for your OS. See the docs for detailed steps.

| OS | File to run | Steps |
|----|-------------|-------|
| Windows | [`scripts/windows/start.bat`](scripts/windows/start.bat) | [Windows guide](docs/en/30-run-windows.md) |
| macOS | [`scripts/macos/start.command`](scripts/macos/start.command) | [macOS guide](docs/en/31-run-macos.md) |
| Linux | (coming soon) | — |

### 2. Learner — "I want to understand how it works"

📖 **[Documentation site](https://h-shiono.github.io/mrtklib-quickstart/)**
(MkDocs + Material, published to GitHub Pages)

- Overview / big picture → [`docs/en/00-overview.md`](docs/en/00-overview.md)
- MADOCA-PPP: where it sits and why it converges → [`docs/en/10-concepts.md`](docs/en/10-concepts.md)
- How to read the UI (convergence) → [`docs/en/50-using-ui.md`](docs/en/50-using-ui.md)

> The docs are bilingual (`docs/en/` / `docs/ja/`) and served from one site;
> use the language selector in the header to switch.
>
> To preview locally: `uv sync && uv run mkdocs serve`

### 3. Maintainer — "I want to fix the scripts"

See the technical notes for each script group.

- [`scripts/windows/README.md`](scripts/windows/README.md)
- [`scripts/macos/README.md`](scripts/macos/README.md)

---

## Repository layout

```
mrtklib-quickstart/
├─ README.md              # this entry point
├─ scripts/               # OS-specific launch/setup scripts (the shell)
│  ├─ windows/
│  └─ macos/
├─ docs/                  # OS-independent body text (the substance); bilingual (en/ ja/)
├─ mkdocs.yml             # documentation site config (MkDocs + Material)
├─ pyproject.toml         # docs toolchain, locked in uv.lock
├─ .github/workflows/     # CI for building and publishing the docs
└─ .gitignore
```

## License

See [LICENSE](LICENSE).
