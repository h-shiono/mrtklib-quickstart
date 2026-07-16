#!/usr/bin/env bash
# ============================================================================
#  build-pdf.sh  -  build the per-language participant PDFs
#
#  Produces one combined PDF per language from the Quarto sources by rendering
#  the ja/_manual.qmd and en/_manual.qmd aggregators (which {{< include >}}
#  every chapter). The website (HTML) build is unaffected: the aggregators are
#  excluded from it by their leading underscore.
#
#  Requirements (usually provided by CI). Verified on Ubuntu 24.04:
#    - Quarto.
#    - A CJK font, or every Japanese glyph is silently dropped:
#        sudo apt-get install -y fonts-noto-cjk
#    - Chromium, to rasterise the Mermaid diagrams:
#        quarto tools install chromium
#      plus the shared libraries its bundled build needs, which a minimal
#      Ubuntu/WSL lacks (it fails with "libnss3.so: cannot open shared object"):
#        sudo apt-get install -y libnss3 libnspr4 libasound2t64
#    - A LaTeX toolchain with lualatex. TinyTeX auto-installs most packages, but
#      NOT luatexja's default Japanese fonts (it cannot map the .otf to a
#      package), so install them explicitly or lualatex aborts on
#      "HaranoAjiMincho-Regular.otf ... not loadable":
#        tlmgr install haranoaji
#
#  The PDF settings (documentclass / pdf-engine / CJKmainfont) live in each
#  _manual.qmd, NOT in _quarto.yml: a `_`-prefixed file is outside the Quarto
#  project and does not inherit project formats.
#
#  The title is overridden with -M so the aggregator title wins over the
#  child chapters' front matter (which otherwise clobbers it, last-wins).
#
#  Output: docs/_dist/mrtklib-quickstart-{ja,en}.pdf
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")" # -> docs/

DIST="_dist"
mkdir -p "$DIST"

build() {
  local lang="$1" title="$2"
  echo "==> Building ${lang} PDF"
  quarto render "${lang}/_manual.qmd" --to pdf -M "title=${title}"
  mv "${lang}/_manual.pdf" "${DIST}/mrtklib-quickstart-${lang}.pdf"
  echo "    -> docs/${DIST}/mrtklib-quickstart-${lang}.pdf"
}

build ja "mrtklib-quickstart（日本語版）"
build en "mrtklib-quickstart (English)"

echo "Done."
