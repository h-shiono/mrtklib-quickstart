/*
  Two small client-side touches for the bilingual site.

  1. <html lang>. Both languages are served from one MkDocs project, so
     `theme.language` in mkdocs.yml is a single fixed value and every page
     would otherwise claim to be English. Screen readers use this attribute to
     choose a pronunciation, so a Japanese chapter announced as English is
     read out wrong.

  2. The fragment on the language link. The switch itself is server-rendered
     (see overrides/partials/alternate.html) and works with JavaScript off;
     the fragment cannot be, because it never reaches the server. Both
     languages use the same {#sec-...} ids on every chapter, so carrying it
     across lands the reader on the section they were reading instead of the
     top of the page. Re-synced on hashchange: clicking a table-of-contents
     entry or a ¶ permalink moves the fragment after the page has loaded.

  document$ is Material's per-page observable; using it (rather than
  DOMContentLoaded) keeps this working if navigation.instant is ever enabled.
*/
(function () {
  var sync = null;

  document$.subscribe(function () {
    var here = window.location.pathname.match(/\/(ja|en)\/[^/]+$/);
    document.documentElement.lang = here ? here[1] : "en";

    if (sync) {
      window.removeEventListener("hashchange", sync);
      sync = null;
    }

    // Absent on the top page, which keeps the dropdown: no single counterpart.
    var link = document.querySelector(".md-header__option a[hreflang]");
    if (!link) return;

    var base = link.href.split("#")[0];
    sync = function () {
      link.href = base + window.location.hash;
    };
    sync();
    window.addEventListener("hashchange", sync);
  });
})();
