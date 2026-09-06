/*
  Bilingual helpers for the header language selector.

  The site is one MkDocs project serving both languages side by side
  (docs/en/ and docs/ja/), so `theme.language` is fixed and the alternate
  links declared in mkdocs.yml point only at each language's entry point.
  This script does two things on every page load:

    1. Retargets those links at the *same* page in the other language, so
       switching language keeps your place. Relies on the parallel layout:
       every ja/<name>.html has an en/<name>.html.
    2. Sets <html lang> to match the page being read, which the stock
       single-language theme cannot do.

  document$ is Material's per-page observable; using it (rather than
  DOMContentLoaded) keeps this working if navigation.instant is ever enabled.
*/
document$.subscribe(function () {
  var path = window.location.pathname;
  var here = path.match(/\/(ja|en)\/[^/]+$/);

  document.documentElement.lang = here ? here[1] : "en";
  if (!here) return; // top page is bilingual: leave the entry-point links

  document.querySelectorAll(".md-select__link[hreflang]").forEach(function (a) {
    var lang = a.getAttribute("hreflang");
    if (lang !== "ja" && lang !== "en") return;
    a.href = path.replace("/" + here[1] + "/", "/" + lang + "/") + window.location.hash;
  });
});
