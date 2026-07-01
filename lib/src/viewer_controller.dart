// Copyright 2026 The Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// @docImport 'view/search_view.dart';
/// @docImport 'view/page_view.dart';
library;

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/foundation.dart';

/// Controls how a PDF page is scaled to fit its display area.
///
/// [fitPage] scales the page so that both dimensions fit within the available
/// box with a comfortable border (24 dp). [fitWidth] fills the available width
/// and scrolls vertically. [custom] uses the explicit [ViewerController.zoomFactor].
enum ZoomMode {
  /// Scale the page to fit entirely within the available area (both width and
  /// height), leaving a 24 dp border on each side.
  fitPage,

  /// Scale the page to fill the available width; scroll vertically for height.
  fitWidth,

  /// Scale the page by [ViewerController.zoomFactor] relative to the
  /// fit-width size.
  custom,
}

/// State controller for a PDF viewer widget.
///
/// [ViewerController] is a [ChangeNotifier] that holds all view-level state
/// for a single open PDF document: the current page, zoom mode, annotation
/// rendering toggle, and active search matches. Listeners (typically
/// [PageView] and the example app's toolbar) rebuild whenever any of these
/// values change.
///
/// ## Ownership
///
/// One [ViewerController] should be created per open document and disposed
/// when the document is closed. The controller does not own the [PdfDocument]
/// handle; that remains owned by the caller (e.g. DocumentState in the
/// example app).
///
/// ## Example
///
/// ```dart
/// final controller = ViewerController();
/// // Navigate to the third page (zero-based index 2):
/// controller.setPage(2, pageCount: doc.pageCount);
/// // Switch to fit-page zoom:
/// controller.setZoom(ZoomMode.fitPage);
/// // Toggle annotation rendering:
/// controller.renderAnnotations = !controller.renderAnnotations;
/// // Remember to dispose when the document is closed:
/// controller.dispose();
/// ```
class ViewerController extends ChangeNotifier {
  /// Creates a [ViewerController] with default settings.
  ///
  /// The initial state is page 0, [ZoomMode.fitPage], annotations enabled,
  /// and no active search matches.
  ViewerController()
    : _currentPage = 0,
      _zoomMode = ZoomMode.fitPage,
      _zoomFactor = 1.0,
      _renderAnnotations = true,
      _activeSearchMatches = const [];

  int _currentPage;
  ZoomMode _zoomMode;
  double _zoomFactor;
  bool _renderAnnotations;
  List<PdfSearchMatch> _activeSearchMatches;

  // Effective zoom factor — the rendered page width as a fraction of the
  // available viewport width, updated by PageViewer after each successful
  // render. Used by the toolbar so zoom-in/out step from the actual visual
  // scale rather than always treating 1.0 as the starting point.
  // Does NOT notify listeners; the toolbar reads it only on button press.
  double effectiveZoomFactor = 1.0;

  // Search UI state — persisted here so tab switches restore correctly.
  // These fields do NOT notify listeners; SearchView manages its own
  // rebuild cycle via setState.

  /// The last query string entered in [SearchView] for this document.
  String searchQuery = '';

  /// Whether the last search run for this document completed.
  bool searchCompleted = false;

  /// Page text cache populated by [SearchView] as results arrive.
  ///
  /// Keyed by zero-based page index. Preserved across tab switches so
  /// snippet text does not need to be re-fetched when returning to a tab.
  final Map<int, String> searchPageTexts = {};

  /// The zero-based index of the currently displayed page.
  ///
  /// Always ≥ 0. Clamped to `[0, pageCount - 1]` by [setPage] and [nextPage]
  /// / [previousPage]. Direct assignment is not supported; use [setPage].
  int get currentPage => _currentPage;

  /// The current zoom mode.
  ZoomMode get zoomMode => _zoomMode;

  /// The zoom scale factor used when zoomMode is [ZoomMode.custom].
  ///
  /// Values < 1.0 zoom out; values > 1.0 zoom in. Has no effect in
  /// [ZoomMode.fitPage] or [ZoomMode.fitWidth] mode.
  double get zoomFactor => _zoomFactor;

  /// Whether annotations (highlights, sticky notes, etc.) are rendered in the
  /// PDF page. Maps to the PDFium `FPDF_ANNOT` flag.
  bool get renderAnnotations => _renderAnnotations;

  /// Sets [renderAnnotations] to [value] and notifies listeners.
  set renderAnnotations(bool value) {
    if (_renderAnnotations == value) return;
    _renderAnnotations = value;
    notifyListeners();
  }

  /// The current set of search matches to display as overlay highlights.
  ///
  /// Matches on pages other than currentPage are stored here but not drawn
  /// until that page is active.
  List<PdfSearchMatch> get activeSearchMatches => _activeSearchMatches;

  /// Navigates to page [pageIndex], clamped to `[0, pageCount - 1]`.
  ///
  /// [pageCount] is the total number of pages in the document. When [pageCount]
  /// is 0, the call is a no-op. Notifies listeners if the page changed.
  void setPage(int pageIndex, {required int pageCount}) {
    if (pageCount <= 0) return;
    final clamped = pageIndex.clamp(0, pageCount - 1);
    if (_currentPage == clamped) return;
    _currentPage = clamped;
    notifyListeners();
  }

  /// Advances to the next page if not already on the last page.
  ///
  /// [pageCount] is the total number of pages in the document. The call is a
  /// no-op when already on the last page or when [pageCount] ≤ 0. Notifies
  /// listeners if the page changed.
  void nextPage({required int pageCount}) {
    if (pageCount <= 0) return;
    final next = _currentPage + 1;
    if (next >= pageCount) return;
    _currentPage = next;
    notifyListeners();
  }

  /// Moves to the previous page if not already on the first page.
  ///
  /// The call is a no-op when already on page 0. Notifies listeners if the
  /// page changed.
  void previousPage() {
    if (_currentPage <= 0) return;
    _currentPage--;
    notifyListeners();
  }

  /// Sets the zoom mode and optional custom scale factor.
  ///
  /// [factor] is only meaningful when [mode] is [ZoomMode.custom]; it is
  /// ignored otherwise. [factor] must be positive. Notifies listeners.
  void setZoom(ZoomMode mode, {double factor = 1.0}) {
    assert(factor > 0, 'zoomFactor must be positive, got $factor');
    final newFactor = mode == ZoomMode.custom ? factor : _zoomFactor;
    if (_zoomMode == mode && newFactor == _zoomFactor) return;
    _zoomMode = mode;
    _zoomFactor = newFactor;
    notifyListeners();
  }

  /// Replaces the active search matches and notifies listeners.
  ///
  /// Typically called by [SearchView] when new results arrive. The
  /// [PageViewer] will draw overlay highlights for matches on the current
  /// page.
  void setSearchMatches(List<PdfSearchMatch> matches) {
    _activeSearchMatches = List.unmodifiable(matches);
    notifyListeners();
  }

  /// Clears all active search matches and resets persisted search UI state.
  ///
  /// Notifies listeners so [PageView] removes overlay highlights.
  void clearSearch() {
    searchQuery = '';
    searchCompleted = false;
    searchPageTexts.clear();
    if (_activeSearchMatches.isEmpty) return;
    _activeSearchMatches = const [];
    notifyListeners();
  }
}
