# mrtklib-quickstart

Launch scripts, first-run setup scripts, and documentation that make
[mrtklib-docker-ui](https://github.com/h-shiono/mrtklib-docker-ui) easy to run
even for people unfamiliar with Docker.

It manages the OS-specific launch path (Windows / macOS / Linux) and the
OS-independent teaching material in one place.

---

## Who are you? (routing for three audiences)

### 1. Participant — "I just want it to run"

Run the script for your OS. See the docs for detailed steps.

| OS | File to run | Steps |
|----|-------------|-------|
| Windows | [`scripts/windows/start.bat`](scripts/windows/start.bat) | [Windows guide](docs/en/30-run-windows.qmd) |
| macOS | [`scripts/macos/start.command`](scripts/macos/start.command) | [macOS guide](docs/en/31-run-macos.qmd) |
| Linux | (coming soon) | — |

### 2. Learner — "I want to understand how it works"

📖 **Documentation site** (built with Quarto, published to GitHub Pages)

- Overview / big picture → [`docs/en/00-overview.qmd`](docs/en/00-overview.qmd)
- Roles of MADOCA-PPP / raw / CON → [`docs/en/10-concepts.qmd`](docs/en/10-concepts.qmd)
- How to read the UI (convergence curve) → [`docs/en/40-using-ui.qmd`](docs/en/40-using-ui.qmd)

> The docs are bilingual (`docs/en/` / `docs/ja/`), generated as HTML and PDF
> from a single Quarto source.

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
├─ docs/                  # OS-independent body text (the substance); bilingual, Quarto single source
├─ .github/workflows/     # CI for docs publishing / PDF release
└─ .gitignore
```

## License

See [LICENSE](LICENSE).
