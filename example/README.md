# Quietly — PDF Viewer example app

Quietly is a macOS Flutter application that demonstrates the full
`betto_pdf_widgets` widget library: multi-tab PDF viewing, zoom controls, a
slide-in sidebar with five panels, and full-text search with page-level
highlights.

## UI overview

```
┌─────────────────────────────────────────────────────────┐
│ TopBar: Quietly · filename          [section]  [⊞] [⋯] │
├──────┬──────────────────────────────────────────────────┤
│ Rail │ SlidingSidebar (280 dp)  │  PdfViewerPane        │
│ 48dp │ ── optional ──           │  (fills remainder)    │
└──────┴──────────────────────────┴───────────────────────┘
                                    ┌────────────────────┐
                                    │ ‹ 3/12 › | ⊖ Fit ⊕ │  (floating pill)
                                    └────────────────────┘
```

### Top bar

Shows the app name ("Quietly"), the current file name, and the active TOC
section name (updated as you page through the document). The **⊞** button opens
a file picker; the **⋯** button is a placeholder for future options.

### Left menu rail

Five icon buttons — each toggles a slide-in sidebar panel:

| Icon | Panel             |
| ---- | ----------------- |
| ☰   | Table of contents |
| ⊞    | Page thumbnails   |
| ✎    | Annotations       |
| 🔍   | Full-text search  |
| ℹ    | Document info     |

Clicking the active button closes the sidebar. Keyboard Tab navigates the rail;
focus returns to the button that opened the sidebar when it is closed.

### Slide-in sidebar

Animates in at 180 ms (or cross-fades when Reduce Motion is on). Each panel:

- **Table of contents** — hierarchical bookmark tree; tapping a row jumps to
  that page. Active section highlighted in sage.
- **Page thumbnails** — lazy 2-column grid; tapping a cell navigates to that
  page. Active page has a sage border.
- **Annotations** — lists sticky notes and highlight annotations sorted by page.
  A toggle switch shows or hides annotations in the rendered PDF.
- **Search** — text field with 300 ms debounce; results show surrounding context
  with matches highlighted in amber. Each result shows the TOC section name and
  page number. Tapping a result jumps to that page.
- **Document info** — shows PDF metadata (title, author, subject, keywords,
  creator, producer, dates, PDF version) and file info (path, size, page count).

### PDF viewer

Single-page renderer powered by `PageViewer` with three zoom modes:

| Mode      | Button         | Behaviour                                                   |
| --------- | -------------- | ----------------------------------------------------------- |
| Fit Page  | Fit Page icon  | Both dimensions fit within the viewport with a 24 dp border |
| Fit Width | Fit Width icon | Page fills the full available width; scrolls vertically     |
| Custom    | +/− buttons    | Steps by 10% from the current effective scale               |

The floating bottom pill shows `‹ page/total ›` navigation on the left and zoom
controls on the right. The pill uses a glassmorphism style (85% paper background

- 12 dp blur). Search matches are drawn as translucent amber overlays directly
  on the page canvas.

## What it demonstrates

### Opening a document

```dart
final bytes = await File(path).readAsBytes();
final doc = await PdfDocument.fromBytes(bytes);
final pageCount = doc.pageCount;
```

### Controller-driven viewer

```dart
final controller = ViewerController();

PageViewer(
  document: doc,
  pageCount: pageCount,
  controller: controller,
)
```

`ViewerController` holds page, zoom mode, zoom factor, annotation toggle, and
active search matches. Any widget can call `controller.setPage()`,
`controller.setZoom()`, or `controller.setSearchMatches()` and `PageViewer`
will re-render automatically.

### Search with highlights

```dart
SearchView(
  document: doc,
  controller: controller,
  hintText: 'Search document…',
  clearLabel: 'Clear',
  resultsCountBuilder: (n) => '$n results',
  noResultsText: 'No results found',
  resultPageBuilder: (n) => 'Page $n',
  sectionResolver: (pageIndex) => tocSectionFor(pageIndex),
)
```

`SearchView` streams results from `PdfDocument.search()`, calls
`controller.setSearchMatches()` so `PageViewer` draws overlays on the
current page (sourced from the ambient `TextSelectionThemeData`), and shows
per-result context snippets with the matched text highlighted the same way.

### Closing a document

Every `PdfDocument` holds a native handle that must be released:

```dart
await doc.document.close();
```

The example calls `close()` on tab close and on Quit so the native isolate
always terminates cleanly.

## Native library setup

`betto_pdfium` wraps PDFium via Dart FFI. No manual setup is required: PDFium
is **not bundled** in the package, but a Dart
[native-assets build hook](https://github.com/dart-lang/native) in
`betto_pdfium` downloads the prebuilt PDFium binary for the target platform
from [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries),
verifies its SHA-256 checksum, and bundles it with the app automatically the
first time you build or run — no `make build_pdfium_macos`, no Podfile hook,
and no runtime dylib-path resolution in application code. The downloaded
binary is cached under `.dart_tool/betto_pdfium/` and reused on subsequent
builds.

`betto_pdfium` currently supports macOS (arm64), Linux (x64/arm64), iOS
(arm64), and Android; Windows is not yet supported.

## Running

```bash
cd example
flutter run -d macos
```

Use **File > Open (⌘O)** to open a PDF, or click the open button in the top bar.
Use **File > Close Tab (⌘W)** to close the active tab. Opening a file that is
already open switches to the existing tab rather than duplicating it.
