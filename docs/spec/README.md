---
title: Technical Specification
subtitle: betto_pdf_widgets
toc-title: "Contents"
...

- **Package:** `betto_pdf_widgets`
- **Version:** `0.1.0-dev.2`
- **Dart SDK:** ≥ 3.12.0

# Purpose and scope

`betto_pdf_widgets` is the Flutter widget layer for viewing PDF documents. It
turns the pure-Dart `betto_pdfium` API into a set of composable,
accessibility-aware widgets — a zoom-and-pan page viewer, a table of
contents, a thumbnail grid, an annotation list, a search panel, and a
document-info panel — that a host application assembles into a full PDF
viewer.

The package does not open files, manage windows, or make product decisions
(what a sidebar looks like, what order panels appear in, what happens when a
file is already open). Those are application concerns. This document
describes what the package *does* own: the widget catalog, the shared state
model, the rendering pipeline, and the conventions (theming, accessibility,
internationalisation) every widget follows.

# Architecture

The PDF viewing stack is split into two packages:

- **`betto_pdfium`** — a pure-Dart FFI binding over the PDFium native
  library. No Flutter dependency. Owns `PdfDocument` and all document-level
  types (`PdfMetadata`, `PdfTocEntry`, `PdfSearchMatch`,
  `PdfPageAnnotations`, etc.) and exposes page rendering as raw BGRA byte
  buffers.
- **`betto_pdf_widgets`** (this package) — the Flutter widget layer. Wraps
  `betto_pdfium`'s byte output in `dart:ui.Image`, adds zoom/pan/search-state
  management, and provides the seven user-facing widgets described below.

The single public entry point, `lib/betto_pdf_widgets.dart`, re-exports both
this package's widgets and the complete `betto_pdfium` public API. A
downstream app needs only one import to get `PdfDocument` and every widget.

```dart
import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
```

## Package layout

```
lib/
  betto_pdf_widgets.dart        # Public entry point — re-exports every
                                 # widget and the full betto_pdfium API
  src/
    viewer_controller.dart      # ViewerController (ChangeNotifier) + ZoomMode
    page_viewer.dart            # PageViewer — zoom-aware page renderer
    view/
      page_view.dart            # PageView — simple fit-width page renderer
      toc_view.dart             # TocView — table of contents
      thumbnail_view.dart       # ThumbnailGrid — lazy thumbnail grid
      annotation_view.dart      # AnnotationView — notes + highlights list
      search_view.dart          # SearchView — search input + results
      info_view.dart            # InfoView — metadata / file-info panel
    render/
      render_options.dart       # RenderOptions — value type of render flags
      document_rendering.dart   # DocumentRendering extension: BGRA bytes →
                                 # dart:ui.Image (the only file that imports
                                 # dart:ui besides page_viewer.dart/page_view.dart)
test/                           # Widget + unit tests (hermetic, no PDFium dylib)
example/                        # Complete macOS PDF viewer app, "Quietly",
                                 # using all widgets (see below)
```

## Key design rules

- Widgets receive every user-visible string as a constructor parameter —
  there are no hardcoded English strings in the library. Callers pass
  localised strings from their own ARB-generated class.
- Every widget wraps its interactive, loading, and error states in
  `Semantics` (`button: true` for tappable rows/cells, labelled loading and
  error states, `liveRegion: true` for the search result count).
- `RenderOptions` is a value type (`==`/`hashCode`) so render caches can
  compare parameters by value rather than identity.
- Widget classes are **not** `Pdf`-prefixed (`PageViewer`, `TocView`,
  `ThumbnailGrid`, …) — only the re-exported `betto_pdfium` document-level
  types keep the `Pdf` prefix (`PdfDocument`, `PdfTocEntry`, …). Note that
  `PageView` shares its name with Flutter's own `material`/`widgets`
  `PageView`; a consuming file that imports both `flutter/material.dart` and
  `betto_pdf_widgets.dart` and needs both must hide or prefix one of them.

# Widget catalog

| Widget | File | Backed by |
|:-------|:-----|:----------|
| `PageViewer` | `src/page_viewer.dart` | `ViewerController` |
| `PageView` | `src/view/page_view.dart` | — (self-contained) |
| `ViewerController` | `src/viewer_controller.dart` | — (state holder) |
| `TocView` | `src/view/toc_view.dart` | `ViewerController` |
| `ThumbnailGrid` | `src/view/thumbnail_view.dart` | `ViewerController` |
| `AnnotationView` | `src/view/annotation_view.dart` | `ViewerController` |
| `SearchView` | `src/view/search_view.dart` | `ViewerController` |
| `InfoView` | `src/view/info_view.dart` | — (pure display) |

## `ViewerController`

A `ChangeNotifier` that holds all view-level state for a single open
document: current page, zoom mode, zoom factor, the annotation-rendering
toggle, and the active search matches. One controller is created per open
document and disposed when the document closes; it does not own the
`PdfDocument` handle itself.

Three zoom modes (`ZoomMode`):

| Mode | Behaviour |
|:-----|:----------|
| `fitPage` | Both dimensions fit within the viewport, with a 24 dp border. |
| `fitWidth` | Page fills the available width; scrolls vertically. |
| `custom` | Page is scaled by `zoomFactor` relative to the fit-width size; pannable via `InteractiveViewer`. |

`effectiveZoomFactor` is updated by `PageViewer` after every successful
render (not via `notifyListeners`) so zoom-in/out controls step from the
actual visual scale rather than assuming 1.0 is the starting point.
`searchQuery`, `searchCompleted`, and `searchPageTexts` are persisted on the
controller (also without notifying) so a `SearchView` restores its state
correctly when a host app switches away from and back to a document tab.

## `PageViewer`

The primary page renderer. Listens to a `ViewerController` and re-renders
whenever the page, zoom mode/factor, or annotation toggle changes. Renders
at `logicalWidth * MediaQuery.devicePixelRatioOf(context)` for sharp output
on high-DPI displays, and paints translucent overlay rectangles for any
`PdfSearchMatch`es on the current page (see Rendering pipeline, below).

Coordinates are transformed from PDF user-space (bottom-left origin) to
Flutter/screen space (top-left origin):

```
flutterX = pdfRect.left / pageWidthPt * widgetWidth
flutterY = (pageHeightPt - pdfRect.top) / pageHeightPt * widgetHeight
```

## `PageView`

A simpler, self-contained single-page renderer with no controller and no
zoom modes — it always renders at fit-to-width. Useful for one-off page
previews (e.g. inside a list) where a full `ViewerController` would be
overkill. Re-renders only when `pageIndex`, `document`, or `options` change,
or when the available width changes by more than 2 logical pixels.

## `TocView`

Renders a `List<PdfTocEntry>` as a nested, scrollable list. Tapping an entry
with a `pageIndex` calls `ViewerController.setPage`. Entries without a page
index (section labels, URI-only entries) render in a muted, non-interactive
style. The active entry — the deepest entry whose `pageIndex` is ≤ the
controller's current page — is highlighted with a left indicator bar.

## `ThumbnailGrid`

A two-column `GridView` that fetches thumbnails on demand as cells scroll
into view, via `PdfDocument.getThumbnail`. Results are cached in a
bounded LRU map (100 entries by default) keyed by page index; the oldest
entry is evicted when the cache is full. All cached `ui.Image`s are disposed
when the widget is disposed. Tapping a cell calls `ViewerController.setPage`.

## `AnnotationView`

Filters a document's `PdfPageAnnotations` down to sticky notes
(`PdfTextAnnotation`) and highlight markup (`PdfMarkupAnnotation` with
`PdfAnnotationType.highlight`) and lists them in page order as cards. A
header shows total/per-type counts and a switch bound to
`ViewerController.renderAnnotations`, so hiding annotations here hides them
in `PageViewer`'s render too (the PDFium `FPDF_ANNOT` flag).

## `SearchView`

A text field plus result list. Queries of `minQueryLength` (default 3) or
more characters auto-search after a 300 ms debounce; shorter queries search
on Enter or focus-loss. Results stream from `PdfDocument.search()`; each
arriving match is forwarded to `ViewerController.setSearchMatches` (so
`PageViewer` can draw overlays) and triggers an on-demand
`PdfDocument.extractPlainText` fetch for that page so the result card can
show a highlighted context snippet. An optional `sectionResolver` maps a
page index to a TOC section title for display on each card.

## `InfoView`

A read-only, two-section panel: PDF `Info` dictionary metadata (title,
author, subject, keywords, creator, producer, creation/mod dates) and
optional file information (name, path, size, page count, PDF version,
filesystem dates) passed in by the caller. Kept free of `dart:io` so it
stays trivially testable — the widget never touches the filesystem itself.
Missing/null fields are omitted rather than shown as blank rows.

# Rendering pipeline

PDFium renders into a raw BGRA pixel buffer
(`PdfDocument.renderPageToBytes`). The `DocumentRendering` extension
(`src/render/document_rendering.dart`) is the only bridge from that buffer to
something Flutter can paint:

```
PdfDocument.renderPageToBytes()  →  Uint8List (BGRA)
                                  →  ui.ImmutableBuffer
                                  →  ui.ImageDescriptor.raw(pixelFormat: bgra8888)
                                  →  ui.Codec → ui.Image
```

This path is fully async (`ImmutableBuffer` → `ImageDescriptor` → codec) and
safe to call from any isolate without blocking the UI thread.

`RenderOptions` (`src/render/render_options.dart`) is the value type passed
to `renderPage`: `renderAnnotations` (maps to PDFium's `FPDF_ANNOT` flag),
`lcdText` (`FPDF_LCD_TEXT`, sub-pixel text rendering), and `backgroundColor`
(fills the bitmap before rendering; a `dart:ui.Color` converted to PDFium's
`0xAARRGGBB` integer format internally). Resolution is controlled entirely
by the caller via explicit `pixelWidth`/`pixelHeight` — zoom and scale are a
`PageViewer`-level concern, not `RenderOptions`.

Both `PageViewer` and `PageView` own the `ui.Image` they produce and dispose
it when replaced or when the widget is disposed. The underlying
`PdfDocument` is owned by the caller and is never closed by these widgets.

# Theming

Every widget resolves its colours and text styles from the ambient
`ThemeData` at build time — `Theme.of(context).colorScheme`,
`.textTheme`, and `.textSelectionTheme` — instead of a package-specific
`ThemeExtension`. A host app configures a normal `ThemeData` (light, dark, or
custom `ColorScheme`) on its `MaterialApp`/`Theme`, and every PDF widget
follows it automatically, including dark mode, with no separate registration
step.

Concretely:

- Surfaces, borders, and containers use `colorScheme.surface`,
  `.surfaceContainer`, `.surfaceContainerHigh/Highest/Lowest`, and
  `.outline`.
- Primary/secondary/muted text uses `textTheme` styles
  (`titleSmall`/`titleMedium`, `bodyMedium`/`bodySmall`,
  `labelMedium`/`labelSmall`) rather than hardcoded font sizes or families —
  a `TextStyle` with no explicit `fontFamily` inherits from the nearest
  `DefaultTextStyle`/`ThemeData.textTheme`, so a host app's font choice
  propagates into the widgets for free.
- Search-match and text-selection highlighting
  (`PageViewer`'s overlay painter, `SearchView`'s result snippets) prefer
  `textSelectionTheme.selectionColor` and fall back to
  `colorScheme.tertiary` at 40% opacity when the host app hasn't set one.
- Active-state indicators (the current TOC entry, the current thumbnail)
  use `colorScheme.surfaceTint`/`surfaceContainerHighest`.

The example application (below) demonstrates this by
building a full custom `ColorScheme` and `TextTheme` (with Google Fonts) and
handing it to `MaterialApp(theme: ...)` — no PDF-widgets-specific
configuration is required beyond that.

# Accessibility and internationalisation

- Every interactive element (TOC row, thumbnail cell, annotation card,
  search result card, the annotation-visibility switch) is wrapped in
  `Semantics(button: true, label: ...)`.
- Loading and error states carry their own `Semantics` labels (e.g.
  `"Loading page N"`, `"Failed to render page N: ..."`).
- The `SearchView` result count is a `liveRegion: true` `Semantics` node so
  screen readers announce updates as results stream in.
- No widget contains a hardcoded English string. Every user-visible string
  (hints, labels, empty-state text, count formatters) is a required
  constructor parameter, typically sourced from a generated
  `AppLocalizations` class in the host app.

# Example application (Quietly)

`example/` is a complete macOS Flutter application, "Quietly", that exercises
every widget in this package: multi-tab PDF viewing, three zoom modes, a
slide-in sidebar with all five sidebar-capable widgets, and full-text search
with page-level highlights. It exists both as a manual test bed and as a
worked example of how to wire the library into an application.

## Application-level state

`example/lib/state/document_state.dart` defines two classes that sit
entirely outside the library:

- **`OpenDocument`** — one open `PdfDocument` plus everything the UI needs
  for it: a `ViewerController`, and `Future`s for the table of contents,
  annotations, metadata, and document info (kicked off eagerly on open,
  rendered via `FutureBuilder` in whichever sidebar panel is active).
- **`DocumentState`** — a `ChangeNotifier` holding the list of open
  `OpenDocument`s and the active tab index. Owns opening, closing (which
  disposes the controller and closes the native `PdfDocument` handle), and
  tab switching.

## Screen composition

`HomeScreen` (`example/lib/screens/home_screen.dart`) lays out, top to
bottom: a tab strip, a top bar, then a row of a fixed icon rail
(`MenuRail`), an optional slide-in sidebar (`SlidingSidebar`), and the PDF
viewer pane (`PdfViewerPane`, which wraps this package's `PageViewer` with a
floating navigation/zoom toolbar pill). Selecting a rail icon swaps the
sidebar's child between five panels, each a thin wrapper that resolves the
relevant `Future` on `OpenDocument` and passes it straight into the matching
library widget — `TocView`, `ThumbnailGrid`, `AnnotationView`, `SearchView`,
or `InfoView`. None of the actual rendering, search, or annotation logic
lives in the example app; it all comes from the widgets described above.

## Native library setup

PDFium is not bundled with either package and must be built from source; see
[example/README.md](../../example/README.md) for the full build and
dylib-packaging steps required to run the example app.

# Testing

The widget/unit test suite (`test/`) is hermetic — it does not link the
PDFium dylib — and covers each widget's golden-path, empty, loading, error,
and accessibility states. See [CLAUDE.md](../../CLAUDE.md) for the coverage
requirement and the commands (`make test`, `make coverage`) used to run and
measure it.
