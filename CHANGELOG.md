# Changelog

## 0.1.0-dev.1

Initial development release. All eight widgets are implemented and tested:

- `PageViewer` — zoom-aware single-page renderer (fit-page, fit-width, custom
  zoom) with search-match overlays.
- `PageView` — lower-level single-page renderer (fit-width only, no
  controller) for callers that don't need zoom modes.
- `ViewerController` — `ChangeNotifier` for page navigation, zoom mode, the
  annotation-rendering toggle, and active search matches.
- `TocView` — scrollable, nested table of contents with active-entry
  highlighting.
- `ThumbnailGrid` — lazy-loading, LRU-cached 2-column thumbnail grid.
- `AnnotationView` — note and highlight annotation list with a visibility
  toggle.
- `SearchView` — debounced search input with a result list and highlighted
  context snippets.
- `InfoView` — document metadata and file-info panel.

All widgets style themselves from the ambient `ThemeData`
(`ColorScheme`/`TextTheme`/`TextSelectionThemeData`) instead of a
package-specific theme extension, take all user-visible strings as
constructor parameters, and wrap interactive/loading/error states in
`Semantics` for accessibility.

Re-exports the full `betto_pdfium` public API from `betto_pdf_widgets.dart`
so downstream consumers only need one import.
