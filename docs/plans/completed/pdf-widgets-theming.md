# PdfWidgetsTheme — downstream theming support

**Status**: Complete

**PR link**: —

## Problem statement

All six widget files in `lib/src/` hardcode Bettongia brand hex values directly
(`Color(0xFF79716A)`, etc.). Flutter's `ThemeData`, `ColorScheme`, and
`TextTheme` are never consulted. This means a downstream app cannot restyle
the widgets to match its own design system, and dark mode is not supported.

The fix is to introduce a `PdfWidgetsTheme` class (a
`ThemeExtension<PdfWidgetsTheme>`) that carries the full set of color tokens
used by the widgets. Widgets resolve it from `BuildContext` at build time and
fall back to the Bettongia defaults when the extension is absent. The host app
registers one line in `ThemeData.extensions` to override any or all tokens.

## Open questions

- [x] **Q1 — `PdfTocView.activeColor` constructor parameter.** **Decision:
  remove it.** The package is unreleased; a cleaner API takes priority over
  preserving an ad-hoc param. The theme's `activeAccent` token replaces it.

- [x] **Q2 — `paper150` and `ink300` token values.** **Decision: keep the
  current implementation values** (`0xFFEEE7D9` / `0xFFB8B0A3`) and name them
  as theme tokens. They are implementation-level palette steps not yet in the
  formal design doc, but they are intentional and coherent with the scale.

- [x] **Q3 — `highlightWash` value alignment.** **Decision: align to the design
  doc.** Default `highlightWash` becomes `Color(0x80D6B86C)` (design doc's
  `washAmber`), replacing the current implementation value `0x80D4B97A`.

## Investigation

### Color inventory

All hardcoded `Color(…)` calls across the six affected files, mapped to their
design-system names:

| Hex value    | Design name  | Semantic role                              | Widgets using it                                |
|:-------------|:-------------|:-------------------------------------------|:------------------------------------------------|
| `0xFFF4EFE6` | paper100     | card / panel surface                       | annotation, search                              |
| `0xFFEEE7D9` | paper150 †   | thumbnail placeholder background           | thumbnail grid                                  |
| `0xFFE8E1D3` | paper200     | dividers, borders, hairlines               | annotation, search, thumbnail grid              |
| `0xFF2A2520` | ink900       | primary text                               | document info, TOC, search, annotation          |
| `0xFF4A433B` | ink700       | muted primary text                         | annotation, search                              |
| `0xFF79716A` | ink500       | secondary / meta text                      | document info, TOC, thumbnail, annotation, search |
| `0xFFB8B0A3` | ink300 †     | hint / placeholder text                    | search                                          |
| `0xFF9EB8A4` | activeAccent | active tab/TOC/thumbnail indicator (sage)  | TOC, thumbnail grid                             |
| `0x80D6B86C` | highlightWash| search match + annotation highlight overlay (aligned to design doc `washAmber`)| page viewer, search |
| `0xFFC8A38C` | annotationAccent | annotation type badge (clay)           | annotation view                                 |

† Not in the formal `AppColors` class in the design doc (`AppColors` defines
paper50/100/200 and ink500/700/900). Implementation-level intermediate steps.

Note: The existing `activeAccent` value (`0xFF9EB8A4`) is a lighter shade than
the design doc's `mkSage` (`0xFF6F9579`). It was a deliberate implementation
choice for the active-state background tint and should be kept as-is.

### Design doc `AppColors` (canonical palette, from `theme/app_colors.dart`)

```dart
// Neutrals (light)
paper50  = Color(0xFFFAF7F2);  // app bg
paper100 = Color(0xFFF4EFE6);  // surface
paper200 = Color(0xFFE8E1D3);  // hairline / divider
ink900   = Color(0xFF2A2520);  // primary text
ink700   = Color(0xFF4A433B);  // muted
ink500   = Color(0xFF79716A);  // meta

// Marker solids (dots, tabs, active rail)
mkAmber   = Color(0xFFC39A45);
mkClay    = Color(0xFFB27C62);
mkSage    = Color(0xFF6F9579);  // focus / active
mkDusk    = Color(0xFF6982A1);
mkHeather = Color(0xFF8C79A6);

// Highlight washes (painted under text)
washAmber   = Color(0x80D6B86C);
washClay    = Color(0x75CE9C80);
washSage    = Color(0x7596BCA0);
```

### Proposed `PdfWidgetsTheme` token set

Ten tokens cover all current callsites. The names follow the AppColors
convention so the connection to the design system is transparent.

```dart
class PdfWidgetsTheme extends ThemeExtension<PdfWidgetsTheme> {
  // Neutral scale
  final Color paper100;         // card / panel surface
  final Color paper150;         // thumbnail placeholder background (†)
  final Color paper200;         // dividers, borders, hairlines
  final Color ink300;           // hint / placeholder text (†)
  final Color ink500;           // secondary / meta text
  final Color ink700;           // muted primary text
  final Color ink900;           // primary text

  // Accents
  final Color activeAccent;     // active page / TOC / thumbnail indicator
  final Color highlightWash;    // search match + annotation highlight overlay
  final Color annotationAccent; // annotation type badge
}
```

### ThemeExtension mechanics

- `copyWith(…)` — replaces individual tokens, returns new instance.
- `lerp(other, t)` — required by Flutter for animated theme transitions;
  uses `Color.lerp` on each field.
- `PdfWidgetsTheme.defaults` — a `const` instance with the Bettongia values
  used as the fallback when no extension is registered.
- Static helper `PdfWidgetsTheme.of(BuildContext context)` — looks up
  `Theme.of(context).extension<PdfWidgetsTheme>()` and returns `defaults` if
  absent, so callsites need only one line.

### Static `const` color fields — migration note

Several private state classes declare `static const Color` fields
(`_sageColor`, `_clayColor`, `_highlightColor`, `_matchHighlightColor`,
`_noteColor`). Static fields cannot receive `BuildContext`, so these must be
removed; the values come from `PdfWidgetsTheme.of(context)` inside `build()`.

### Files affected

| File | Change |
|:-----|:-------|
| `lib/src/pdf_widgets_theme.dart` | **New file** — `PdfWidgetsTheme` class |
| `lib/src/pdf_toc_view.dart` | Replace hardcoded colors; remove `activeColor` param (see Q1) |
| `lib/src/pdf_thumbnail_grid.dart` | Remove `_sageColor` static const; replace hardcoded colors |
| `lib/src/pdf_annotation_view.dart` | Remove `_clayColor`, `_noteColor` static consts; replace hardcoded colors |
| `lib/src/pdf_search_view.dart` | Remove `_matchHighlightColor` static const; replace hardcoded colors |
| `lib/src/pdf_page_viewer.dart` | Remove `_highlightColor` static const; replace hardcoded color |
| `lib/src/pdf_document_info_view.dart` | Replace hardcoded colors |
| `lib/betto_pdf_widgets.dart` | Export `PdfWidgetsTheme` |
| `test/pdf_widgets_theme_test.dart` | **New file** — unit tests for defaults, copyWith, lerp |
| `test/*_test.dart` | Update any tests that assert specific colors |
| `example/lib/main.dart` | Demonstrate registering a custom `PdfWidgetsTheme` |

## Implementation plan

- [x] Answer open questions (Q1, Q2, Q3) before starting
- [x] Create `lib/src/pdf_widgets_theme.dart`:
  - [x] Define `PdfWidgetsTheme extends ThemeExtension<PdfWidgetsTheme>` with
        10 final color fields
  - [x] Add `const PdfWidgetsTheme.defaults()` factory / named constructor
  - [x] Implement `copyWith`, `lerp`
  - [x] Add `static PdfWidgetsTheme of(BuildContext)` helper
  - [x] Add license header and doc comments on all public members
- [x] `pdf_toc_view.dart`:
  - [x] Remove `activeColor` constructor parameter (pending Q1)
  - [x] Replace 3 hardcoded `Color(…)` callsites via `PdfWidgetsTheme.of(context)`
- [x] `pdf_thumbnail_grid.dart`:
  - [x] Remove `static const _sageColor`
  - [x] Replace 4 hardcoded `Color(…)` callsites
- [x] `pdf_annotation_view.dart`:
  - [x] Remove `static const _clayColor`, `_noteColor`
  - [x] Replace 8 hardcoded `Color(…)` callsites
- [x] `pdf_search_view.dart`:
  - [x] Remove `static const _matchHighlightColor`
  - [x] Replace 12 hardcoded `Color(…)` callsites
- [x] `pdf_page_viewer.dart`:
  - [x] Remove `static const _highlightColor`
  - [x] Replace 1 hardcoded `Color(…)` callsite
- [x] `pdf_document_info_view.dart`:
  - [x] Replace 3 hardcoded `Color(…)` callsites
- [x] `lib/betto_pdf_widgets.dart`:
  - [x] Add `export 'src/pdf_widgets_theme.dart';`
- [x] Tests:
  - [x] Write `test/pdf_widgets_theme_test.dart` covering defaults, `copyWith`,
        `lerp` at t=0/0.5/1, and `of(context)` fallback
  - [x] Check existing widget tests for color assertions that need updating
  - [x] Run `make test` and confirm ≥ 90% coverage is maintained
- [x] Example app:
  - [x] Add a `PdfWidgetsTheme` registration to `ThemeData` in `example/lib/design.dart`
        (via `bettonTheme()`) to demonstrate the customisation path using the defaults
- [x] Run `make pre_commit`
- [x] Update this plan status to `Implementing`, then `Complete` once done
- [x] Move plan to `docs/plans/completed/`
- [x] Submit PR

## Reviews

## Summary

- Introduced `PdfWidgetsTheme extends ThemeExtension<PdfWidgetsTheme>` in `lib/src/pdf_widgets_theme.dart` with 10 named color tokens (`paper100`, `paper150`, `paper200`, `ink300`, `ink500`, `ink700`, `ink900`, `activeAccent`, `highlightWash`, `annotationAccent`), a `const PdfWidgetsTheme.defaults()` named constructor, `copyWith`, `lerp`, and a `static of(BuildContext)` helper.
- Removed the `activeColor` constructor parameter from `PdfTocView` (Q1 decision) — the `activeAccent` theme token replaces it.
- Removed three private `static const Color` fields (`_sageColor` in `_ThumbnailCell`, `_clayColor`/`_noteColor` in `_AnnotationCard`, `_matchHighlightColor` in `_SearchResultCard`, `_highlightColor` in `_SearchOverlayPainter`) and replaced all 28 hardcoded `Color(…)` callsites across six widget files with `PdfWidgetsTheme.of(context)` lookups.
- `_SearchOverlayPainter` (a `CustomPainter`) now accepts `highlightColor` as a constructor parameter since `paint()` has no `BuildContext`; `shouldRepaint` was updated accordingly.
- `highlightWash` default aligned to design doc `washAmber` (`0x80D6B86C`) per Q3 decision, replacing the previous implementation value `0x80D4B97A`.
- `PdfWidgetsTheme` exported from `lib/betto_pdf_widgets.dart` so downstream consumers need only one import.
- `example/lib/design.dart`'s `bettonTheme()` now registers `PdfWidgetsTheme.defaults()` in `ThemeData.extensions` to demonstrate the registration path.
- Added `test/pdf_widgets_theme_test.dart` with 24 tests covering all ten default token values, `copyWith` (single, all, no-op), `lerp` at t=0/0.5/1 and null, and `of(context)` with and without a registered extension.
- All existing widget tests continue to pass without modification (no tests asserted specific hex color values).
- Final coverage: 91.4% (952/1042 lines). Zero analyzer issues. All 115 tests pass.
