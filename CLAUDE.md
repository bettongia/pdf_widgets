# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## General

Work is planned using specifications in the `docs/plans` directory. When working
on plans make sure you review `docs/plans/README.md` file for guidance. When
asked to plan something do not commence implementation until explicitly told to
do so.

The `docs/roadmap` directory is used to track future work items and their
priority. This is worth reviewing when working on the codebase as current work
may intersect with the roadmap.

We'll create plans for our work and place them in the `docs/plans/` directory.
When the planned work has been completed we'll move them to
`docs/plans/completed`.

Quality assurance is critical to this project and you need to maintain a minimum
of 90% test coverage at all times. You must also run all tests successfully
before considering a task to be complete.

Consider edge-cases and failure scenarios when preparing tests - it is critical
not just to focus on easy, "golden-path" tests.

All public classes, methods and properties must have appropriate doc comments.
You may include examples in dec comments if you believe it will help another
developer.

Any complex segments of code should be commented so as to describe the process
and rationale for the approach.

All code files must have a license at the top. The template file is
@header_template.txt. You must add the comment syntax appropriate to the
programming language. Also replace `{{.Year}}` to match the current year.

## Repository Layout

```
lib/
  betto_pdf_widgets.dart        # Public entry point — re-exports all widgets
                                # and the full betto_pdfium public API
  src/
    viewer_controller.dart      # ChangeNotifier: page, zoom, annotations,
                                # search state (ViewerController, ZoomMode)
    page_viewer.dart            # Full viewer: zoom modes + search overlays
                                # (PageViewer)
    view/
      page_view.dart           # Stateful single-page renderer (PageView)
      toc_view.dart             # Scrollable Table of Contents (TocView)
      thumbnail_view.dart       # Lazy 2-column thumbnail grid, LRU cache
                                # (ThumbnailGrid)
      annotation_view.dart      # Note + highlight annotation list
                                # (AnnotationView)
      search_view.dart          # Search input + result cards (SearchView)
      info_view.dart            # Document metadata / file-info panel
                                # (InfoView, DocumentInfoLabels)
    render/
      render_options.dart       # Value type: render flags (RenderOptions)
      document_rendering.dart   # Extension: BGRA bytes → dart:ui Image
                                # (only file that imports dart:ui besides
                                # page_viewer.dart/view/page_view.dart)
test/                           # Widget + unit tests (hermetic, no PDFium dylib)
example/                        # Complete macOS PDF viewer app using all widgets
docs/
  plans/                        # Work plans (see docs/plans/README.md)
  roadmap/                      # Future work items
  spec/                         # Specification documents (Pandoc Markdown)
```

Widget classes are **not** `Pdf`-prefixed (`PageViewer`, `TocView`,
`ThumbnailGrid`, …) — only the re-exported `betto_pdfium` document-level types
keep the `Pdf` prefix (`PdfDocument`, `PdfTocEntry`, …).

## Commands

The `Makefile` should contain all key development lifecycle commands. In
general, `make` should be preferred to directly running commands such as `dart`
and `flutter`.

```bash
# Run tests
make test

# Analyze/lint
make analyze

# Format code
make format

# Coverage
make coverage

# Build docs site (requires pandoc)
make doc_site

# Run checks before committing code
make pre_commit
```

## Implementation Status

All eight public widgets are implemented and tested:

| Widget | File | Status |
|--------|------|--------|
| `ViewerController` | `src/viewer_controller.dart` | Complete |
| `PageView` | `src/view/page_view.dart` | Complete |
| `PageViewer` | `src/page_viewer.dart` | Complete |
| `TocView` | `src/view/toc_view.dart` | Complete |
| `ThumbnailGrid` | `src/view/thumbnail_view.dart` | Complete |
| `AnnotationView` | `src/view/annotation_view.dart` | Complete |
| `SearchView` | `src/view/search_view.dart` | Complete |
| `InfoView` | `src/view/info_view.dart` | Complete |

The `example/` directory contains a complete macOS PDF viewer application that wires all widgets together.

## Architecture

This package is the Flutter widget layer of a two-package split:

- **`betto_pdfium`** — pure Dart API over the PDFium native library. No
  Flutter dependency. Owns `PdfDocument` and all document-level types
  (`PdfMetadata`, `PdfTocEntry`, `PdfSearchMatch`, etc.). Consumed as the
  hosted `pub.dev` package by default; `pubspec.yaml` has a commented-out
  `path: ../pdfium/packages/betto_pdfium` override for local cross-package
  development.
- **`betto_pdf_widgets`** (this package) — Flutter widgets and rendering glue
  built on top of `betto_pdfium`.

The public entry point (`lib/betto_pdf_widgets.dart`) re-exports both the
widget layer and the complete `betto_pdfium` public API, so downstream
consumers only need one import.

PDFium itself is not bundled in either package — `betto_pdfium` fetches and
bundles the correct prebuilt PDFium binary automatically via a Dart
native-assets build hook the first time you build or run. There is no manual
PDFium build step and no app-level dylib-path wiring.

**Key design rules:**
- `render/document_rendering.dart` is the only file that imports `dart:ui`
  besides `page_viewer.dart` and `view/page_view.dart` (both need it for
  `ui.Image`/`CustomPainter`). All other files use Flutter's widget layer or
  pure Dart.
- Widgets receive all user-visible strings as constructor parameters — no
  hardcoded English strings anywhere in the library.
- All widgets include `Semantics` wrappers for accessibility. Loading and error
  states are labelled. Interactive elements carry `button: true`.
- `RenderOptions` is a value type (implements `==` and `hashCode`) so render
  caches can compare parameters without identity checks.
- Widgets style themselves entirely from the ambient `ThemeData`
  (`colorScheme`/`textTheme`/`textSelectionTheme`) — there is no
  package-specific `ThemeExtension`. See [docs/spec/README.md](docs/spec/README.md)
  for details.

## Documentation

Full specification is in [docs/spec/](docs/spec/) (Pandoc Markdown). The built
HTML lives in [site/](site/) and is generated via `make doc_site`. Key spec
files:

- [docs/spec/README.md](docs/spec/README.md) — architecture, widget catalog,
  rendering pipeline, theming, accessibility/i18n, and the example app
