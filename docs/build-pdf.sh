#!/usr/bin/env bash
# ============================================================================
#  build-pdf.sh  -  build the per-language participant PDFs
#
#  Produces one combined PDF per language from the Quarto sources by rendering
#  the ja/_manual.qmd and en/_manual.qmd aggregators (which {{< include >}}
#  every chapter). The website (HTML) build is unaffected: the aggregators are
#  excluded from it by their leading underscore.
#
#  Requirements (usually provided by CI):
#    - Quarto
#    - A LaTeX toolchain with lualatex (Japanese output needs CJK fonts)
#    - Chromium for the Mermaid diagrams:  quarto tools install chromium
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
