# PdfWidgetsTheme — font family customisation

**Status**: Complete

**PR link**: —

## Problem statement

All five library widget files that render text hardcode
`fontFamily: 'Noto Sans'` (21 callsites across `pdf_toc_view`,
`pdf_thumbnail_grid`, `pdf_annotation_view`, `pdf_search_view`, and
`pdf_document_info_view`). This has two consequences:

1. A downstream app cannot change the font used inside the PDF widgets to match
   its own design system without forking the package.
2. The widgets ignore whatever `DefaultTextStyle` or `ThemeData.textTheme` the
   host app has configured — the correct Flutter behaviour for a composable
   library widget is to inherit ambient font settings unless explicitly
   overridden.

## Open questions

_(None — approach is settled; see Investigation.)_

## Investigation

### Approach

Two complementary changes together solve the problem cleanly:

**1 — Remove `fontFamily` from library widget `TextStyle` calls.** A `TextStyle`
with no `fontFamily` inherits the family from the nearest `DefaultTextStyle` in
the widget tree, which is populated from `ThemeData.textTheme`. This is the
standard Flutter pattern for composable widgets. It costs nothing and makes the
widgets immediately compatible with any host app font configuration.

**2 — Add a nullable `fontFamily` token to `PdfWidgetsTheme`.** Downstream
developers who want the PDF sidebar to use a _specific_ font different from the
rest of their app can set one token:

```dart
ThemeData(
  extensions: [
    PdfWidgetsTheme.defaults().copyWith(fontFamily: GoogleFonts.inter().fontFamily),
  ],
)
```

`null` (the default) means "do not set `fontFamily`; inherit from context" —
this is the 90% case and costs nothing. A non-null value is passed through as
`TextStyle(fontFamily: theme.fontFamily, ...)` in every widget.

### Nullable `fontFamily` in `copyWith` — sentinel pattern

`copyWith` for a `String?` field is ambiguous: `copyWith(fontFamily: null)`
could mean "clear the override" or "leave unchanged". Flutter's own `ThemeData`
uses a private `_Sentinel` object to distinguish the two cases. We will do the
same:

```dart
static const _kUnset = Object();

PdfWidgetsTheme copyWith({Object? fontFamily = _kUnset, ...}) {
  return PdfWidgetsTheme(
    fontFamily: identical(fontFamily, _kUnset)
        ? this.fontFamily
        : fontFamily as String?,
    ...
  );
}
```

This means:

- `copyWith()` — `fontFamily` unchanged
- `copyWith(fontFamily: 'MyFont')` — overrides to 'MyFont'
- `copyWith(fontFamily: null)` — clears back to null (inherit)

### `lerp` for `String?`

Strings do not interpolate. Use the standard step approach:

```dart
fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
```

### Callsite count

| File                          | Callsites |
| :---------------------------- | --------: |
| `pdf_annotation_view.dart`    |         7 |
| `pdf_search_view.dart`        |         7 |
| `pdf_toc_view.dart`           |         3 |
| `pdf_document_info_view.dart` |         3 |
| `pdf_thumbnail_grid.dart`     |         1 |
| `pdf_page_viewer.dart`        |         0 |
| **Total**                     |    **21** |

### Widget callsite pattern

Each callsite replaces:

```dart
TextStyle(fontFamily: 'Noto Sans', fontSize: 13, ...)
```

with:

```dart
TextStyle(fontFamily: theme.fontFamily, fontSize: 13, ...)
```

where `theme` is already resolved once per `build()` via
`PdfWidgetsTheme.of(context)`. `fontFamily: null` is a valid `TextStyle`
argument — it is equivalent to omitting the parameter.

### Files affected

| File                                  | Change                                                                              |
| :------------------------------------ | :---------------------------------------------------------------------------------- |
| `lib/src/pdf_widgets_theme.dart`      | Add `final String? fontFamily`; update `defaults()`, `copyWith`, `lerp`, `toString` |
| `lib/src/pdf_toc_view.dart`           | Replace 3 hardcoded `'Noto Sans'` with `theme.fontFamily`                           |
| `lib/src/pdf_thumbnail_grid.dart`     | Replace 1 hardcoded `'Noto Sans'` with `theme.fontFamily`                           |
| `lib/src/pdf_annotation_view.dart`    | Replace 7 hardcoded `'Noto Sans'` with `theme.fontFamily`                           |
| `lib/src/pdf_search_view.dart`        | Replace 7 hardcoded `'Noto Sans'` with `theme.fontFamily`                           |
| `lib/src/pdf_document_info_view.dart` | Replace 3 hardcoded `'Noto Sans'` with `theme.fontFamily`                           |
| `test/pdf_widgets_theme_test.dart`    | Add tests for `fontFamily` default (null), `copyWith` sentinel cases, `lerp` step   |

No changes are needed to `lib/betto_pdf_widgets.dart` (already exported) or the
example app.

## Implementation plan

- [x] `lib/src/pdf_widgets_theme.dart`:
  - [x] Add `final String? fontFamily` field with doc comment explaining
        null-means-inherit
  - [x] Add `fontFamily` to `PdfWidgetsTheme({...})` required params
  - [x] Set `fontFamily = null` in `PdfWidgetsTheme.defaults()`
  - [x] Implement sentinel `copyWith` pattern (private `_kUnset` constant)
  - [x] Add `fontFamily: t < 0.5 ? fontFamily : other.fontFamily` to `lerp`
  - [x] Add `fontFamily` to `toString`
- [x] `lib/src/pdf_annotation_view.dart` — replace 7 callsites
- [x] `lib/src/pdf_search_view.dart` — replace 7 callsites
- [x] `lib/src/pdf_toc_view.dart` — replace 3 callsites
- [x] `lib/src/pdf_document_info_view.dart` — replace 3 callsites
- [x] `lib/src/pdf_thumbnail_grid.dart` — replace 1 callsite
- [x] `test/pdf_widgets_theme_test.dart`:
  - [x] `defaults().fontFamily` is null
  - [x] `copyWith()` with no arg leaves `fontFamily` unchanged
  - [x] `copyWith(fontFamily: 'X')` sets it
  - [x] `copyWith(fontFamily: null)` clears it back to null
  - [x] `lerp` at t=0 returns `this.fontFamily`, at t=1 returns
        `other.fontFamily`
  - [x] `lerp` at t=0.5 steps to `other.fontFamily`
- [x] Run `make pre_commit`
- [x] Update plan status to `Complete` and move to `docs/plans/completed/`

## Reviews

## Summary
