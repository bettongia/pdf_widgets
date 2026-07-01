# betto_pdf_widgets

Flutter widgets that use the `betto_pdfium` package for displaying PDF
documents.

## Features

- `PageViewer` — zoom-aware single-page renderer (fit-page, fit-width, custom
  zoom) with search-match overlays
- `ViewerController` — `ChangeNotifier` for page navigation, zoom, and search
  state
- `TocView` — scrollable table of contents
- `ThumbnailGrid` — lazy-loading 2-column thumbnail grid
- `AnnotationView` — annotation list (notes + highlights) with toggle
- `SearchView` — search input with result list and context snippets
- `InfoView` — metadata and file-info panel

A lower-level `PageView` widget is also exported for callers that only need a
single fit-to-width page render without zoom modes or a controller.

## Theming

The widgets style themselves entirely from the ambient `ThemeData` —
`ColorScheme`, `TextTheme`, and `TextSelectionThemeData` — rather than a
package-specific theme extension. Register a `ThemeData` on your
`MaterialApp` (or `Theme`) as you would for any other Flutter app and the PDF
widgets follow it, including dark mode.

## Usage

The [example project](example/README.md) provides a complete PDF viewer
application, "Quietly", built entirely from these widgets.

See the [technical specification](docs/spec/README.md) for architecture,
widget-by-widget details, and the rendering pipeline.
