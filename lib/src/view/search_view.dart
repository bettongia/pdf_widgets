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

/// @docImport '../page_viewer.dart';
library;

import 'dart:async';

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/material.dart';

import '../viewer_controller.dart';

/// Debounce delay for auto-triggering a search after the user types.
const Duration _kSearchDebounce = Duration(milliseconds: 300);

/// A search input panel with result list for a PDF document.
///
/// [SearchView] shows a text field; when the query reaches [minQueryLength]
/// characters it auto-searches after a 300 ms debounce. For shorter queries,
/// search triggers on Enter or focus-leave. Results are displayed as cards
/// sorted by page order, each showing the surrounding text context with the
/// match highlighted in a translucent amber-tinted span.
///
/// Matches are forwarded to [ViewerController.setSearchMatches] so
/// [PageViewer] can draw overlay highlights. Clearing the search calls
/// [ViewerController.clearSearch].
///
/// ## Live region
///
/// The results count node has `liveRegion: true` so screen readers announce
/// updates as results arrive.
///
/// ## Example
///
/// ```dart
/// SearchView(
///   document: doc,
///   controller: controller,
///   hintText: l10n.searchHint,
///   clearLabel: l10n.searchClear,
///   resultsCountBuilder: (count) => l10n.searchResultsCount(count),
///   noResultsText: l10n.searchNoResults,
///   resultPageBuilder: (n) => l10n.searchResultPage(n),
///   sectionResolver: (pageIndex) => tocSectionFor(pageIndex),
/// )
/// ```
class SearchView extends StatefulWidget {
  /// Creates a [SearchView].
  const SearchView({
    super.key,
    required this.document,
    required this.controller,
    required this.hintText,
    required this.clearLabel,
    required this.resultsCountBuilder,
    required this.noResultsText,
    required this.resultPageBuilder,
    this.sectionResolver,
    this.minQueryLength = 3,
  });

  /// The PDF document to search.
  final PdfDocument document;

  /// The controller that receives active search matches.
  final ViewerController controller;

  /// Placeholder text for the search input field.
  final String hintText;

  /// Accessible label for the clear (×) button.
  final String clearLabel;

  /// Builds the localised results-count string (e.g. "3 results").
  final String Function(int count) resultsCountBuilder;

  /// Text shown when a completed search returns no matches.
  final String noResultsText;

  /// Builds the localised page label for a result card (e.g. "Page 5").
  final String Function(int pageNumber) resultPageBuilder;

  /// Optional function that resolves a zero-based pageIndex to the TOC
  /// section name that contains that page.
  ///
  /// If null, no section label is shown on result cards.
  final String? Function(int pageIndex)? sectionResolver;

  /// Minimum query length for auto-triggering a search on keystroke.
  ///
  /// Queries shorter than this only search on Enter or focus-leave.
  /// Default: 3.
  final int minQueryLength;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Collected matches from the current search.
  final List<PdfSearchMatch> _matches = [];

  /// Cached page text keyed by zero-based page index.
  final Map<int, String> _pageTexts = {};

  /// Pages whose text extraction is currently in flight.
  final Set<int> _textFetchInFlight = {};

  /// Subscriptions for per-page text extractions, cancelled on clear/dispose.
  final List<StreamSubscription<PdfPageText>> _textSubscriptions = [];

  /// Whether a search is currently in progress.
  bool _searching = false;

  /// Whether the last search completed (used to show no-results state).
  bool _searchCompleted = false;

  /// Guard flag to prevent re-entrant _clearSearch calls triggered by
  /// _textController.clear() firing _onTextChange.
  bool _clearing = false;

  StreamSubscription<PdfSearchMatch>? _subscription;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _textController.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(SearchView old) {
    super.didUpdateWidget(old);
    if (old.document != widget.document) {
      // Document changed (tab switch). Cancel all in-flight work for the old
      // document, then restore persisted state from the new controller.
      _debounce?.cancel();
      _subscription?.cancel();
      _subscription = null;
      for (final s in _textSubscriptions) {
        s.cancel();
      }
      _textSubscriptions.clear();
      _textFetchInFlight.clear();

      // Restore state from the new document's controller.
      final c = widget.controller;
      _textController.text = c.searchQuery;
      _matches
        ..clear()
        ..addAll(c.activeSearchMatches);
      _pageTexts
        ..clear()
        ..addAll(c.searchPageTexts);
      _searching = false;
      _searchCompleted = c.searchCompleted;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    for (final s in _textSubscriptions) {
      s.cancel();
    }
    _textController.removeListener(_onTextChange);
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _fetchPageTextIfNeeded(int pageIndex) {
    if (_pageTexts.containsKey(pageIndex) ||
        _textFetchInFlight.contains(pageIndex)) {
      return;
    }
    _textFetchInFlight.add(pageIndex);
    final sub = widget.document
        .extractPlainText(pageIndex: pageIndex)
        .listen(
          (pageText) {
            if (!mounted) return;
            widget.controller.searchPageTexts[pageIndex] = pageText.text;
            setState(() {
              _pageTexts[pageIndex] = pageText.text;
              _textFetchInFlight.remove(pageIndex);
            });
          },
          onError: (_) => _textFetchInFlight.remove(pageIndex),
          onDone: () => _textFetchInFlight.remove(pageIndex),
        );
    _textSubscriptions.add(sub);
  }

  void _onTextChange() {
    final query = _textController.text;
    _debounce?.cancel();

    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    // Persist the current query so it survives a tab switch.
    widget.controller.searchQuery = query;

    // Trigger a rebuild so the suffix clear button shows/hides correctly.
    setState(() {});

    if (query.length >= widget.minQueryLength) {
      // Auto-trigger after debounce.
      _debounce = Timer(_kSearchDebounce, () => _runSearch(query));
    }
    // Shorter queries wait for Enter/blur — handled in _onFocusChange and
    // the TextField's onSubmitted.
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final query = _textController.text;
      if (query.isNotEmpty && query.length < widget.minQueryLength) {
        _runSearch(query);
      }
    }
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _subscription?.cancel();
    _subscription = null;

    if (!mounted) return;
    setState(() {
      _matches.clear();
      _searching = true;
      _searchCompleted = false;
    });

    final allMatches = <PdfSearchMatch>[];

    _subscription = widget.document
        .search(query)
        .listen(
          (match) {
            if (!mounted) return;
            allMatches.add(match);
            _fetchPageTextIfNeeded(match.pageIndex);
            setState(() {
              _matches
                ..clear()
                ..addAll(allMatches);
            });
            widget.controller.setSearchMatches(List.unmodifiable(allMatches));
            // Announce incremental count updates via the live region node
            // (the Semantics widget is rebuilt automatically).
          },
          onDone: () {
            if (!mounted) return;
            widget.controller.searchCompleted = true;
            setState(() {
              _searching = false;
              _searchCompleted = true;
            });
            // The liveRegion: true Semantics node in build() will announce the
            // updated count automatically when setState triggers a rebuild.
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _searching = false;
              _searchCompleted = true;
            });
          },
          cancelOnError: true,
        );
  }

  void _clearSearch() {
    if (_clearing) return;
    _clearing = true;
    try {
      _debounce?.cancel();
      _subscription?.cancel();
      _subscription = null;
      for (final s in _textSubscriptions) {
        s.cancel();
      }
      _textSubscriptions.clear();
      _textFetchInFlight.clear();
      _pageTexts.clear();
      _textController.clear();
      widget.controller.searchQuery = '';
      widget.controller.searchCompleted = false;
      widget.controller.clearSearch();
      if (!mounted) return;
      setState(() {
        _matches.clear();
        _searching = false;
        _searchCompleted = false;
      });
    } finally {
      _clearing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search input field.
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 4),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            style: textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: textTheme.bodySmall,
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.secondary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.surfaceContainer),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.surfaceContainer),
              ),
              suffixIcon: _textController.text.isNotEmpty
                  ? Semantics(
                      label: widget.clearLabel,
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _clearSearch,

                        color: colors.secondary,
                      ),
                    )
                  : null,
            ),
            onSubmitted: (query) {
              if (query.isNotEmpty) _runSearch(query);
            },
          ),
        ),
        // Results count — live region so screen readers announce changes.
        if (_matches.isNotEmpty || _searchCompleted)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
              child: Text(
                _searching
                    ? widget.resultsCountBuilder(_matches.length)
                    : widget.resultsCountBuilder(_matches.length),
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        const Divider(height: 1, thickness: 1),
        // Results list.
        Expanded(child: _buildResultsList(theme)),
      ],
    );
  }

  Widget _buildResultsList(ThemeData theme) {
    if (_matches.isEmpty && _searchCompleted) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Text(
            widget.noResultsText,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final String? section = widget.sectionResolver?.call(match.pageIndex);
        return _SearchResultCard(
          match: match,
          section: section,
          pageText: _pageTexts[match.pageIndex],
          pageLabel: widget.resultPageBuilder(match.pageIndex + 1),

          onTap: () => widget.controller.setPage(
            match.pageIndex,
            pageCount: widget.controller.currentPage + 1000,
          ),
        );
      },
    );
  }
}

/// A single search result card showing context, section, and page number.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.match,
    required this.section,
    required this.pageText,
    required this.pageLabel,
    required this.onTap,
  });

  final PdfSearchMatch match;
  final String? section;

  /// Full extracted text for the page, used to build the surrounding context
  /// snippet. Null while text extraction is still in flight.
  final String? pageText;

  final String pageLabel;
  final VoidCallback onTap;

  static const _kContextRadius = 80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final String semanticLabel =
        'Search result on $pageLabel${section != null ? ': $section' : ''}';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
          padding: const EdgeInsetsDirectional.all(10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.surfaceContainer, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section name and page number badge.
              Row(
                children: [
                  if (section != null)
                    Expanded(
                      child: Text(
                        section!,
                        style: textTheme.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(pageLabel, style: textTheme.labelMedium),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Surrounding context snippet with the match highlighted.
              _buildSnippet(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnippet(ThemeData theme) {
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final text = pageText;
    if (text == null) {
      // Text not yet loaded — show a subtle placeholder.
      return SizedBox(
        height: 12,
        width: 80,
        child: ColoredBox(color: colors.surfaceContainer),
      );
    }

    final int start = match.charIndex.clamp(0, text.length);
    final int end = (match.charIndex + match.charCount).clamp(
      start,
      text.length,
    );

    final int contextStart = (start - _kContextRadius).clamp(0, text.length);
    final int contextEnd = (end + _kContextRadius).clamp(0, text.length);

    final String before = text.substring(contextStart, start);
    final String matchText = text.substring(start, end);
    final String after = text.substring(end, contextEnd);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: textTheme.bodyMedium,
        children: [
          if (contextStart > 0) const TextSpan(text: '…'),
          TextSpan(text: before),
          TextSpan(
            text: matchText,
            style: textTheme.bodyMedium!.copyWith(
              backgroundColor:
                  theme.textSelectionTheme.selectionColor ??
                  theme.colorScheme.tertiary.withValues(alpha: 0.4),
            ),
          ),
          TextSpan(text: after),
          if (contextEnd < text.length) const TextSpan(text: '…'),
        ],
      ),
    );
  }
}
