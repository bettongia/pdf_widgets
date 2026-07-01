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

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/material.dart';

import '../viewer_controller.dart';

/// Indentation per depth level in logical pixels.
const double _kDepthIndent = 16.0;

/// Left-edge indicator width for the active TOC row.
const double _kActiveIndicatorWidth = 3.0;

/// A scrollable Table of Contents widget for a PDF document.
///
/// [TocView] renders a [List<PdfTocEntry>] as a nested scrollable list.
/// Tapping an entry that has a [PdfTocEntry.pageIndex] navigates the viewer to
/// that page via [ViewerController.setPage]. Entries without a page index
/// (section labels or URI-only entries) are displayed in a muted style and are
/// not interactive.
///
/// ## Accessibility
///
/// Each interactive row is wrapped in [Semantics] with `button: true` and a
/// label of "${entry.title}, page ${entry.pageIndex + 1}". Non-interactive
/// section-label rows use a plain text label.
///
/// ## Empty state
///
/// When entries is empty, a centred placeholder text is shown. Provide the
/// emptyText to localise this message (required — pass from ARB).
///
/// ## Example
///
/// ```dart
/// TocView(
///   entries: toc,
///   controller: controller,
///   pageCount: doc.pageCount,
///   emptyText: l10n.tocEmpty,
/// )
/// ```
class TocView extends StatelessWidget {
  /// Creates a [TocView].
  ///
  /// [entries], [controller], [pageCount], and [emptyText] are required.
  const TocView({
    super.key,
    required this.entries,
    required this.controller,
    required this.pageCount,
    required this.emptyText,
  });

  /// The Table of Contents entries to display (root-level; children are nested
  /// automatically).
  final List<PdfTocEntry> entries;

  /// The controller that drives page navigation and reports the current page
  /// for active-entry highlighting.
  final ViewerController controller;

  /// Total number of pages in the document — passed to setPage for range
  /// clamping.
  final int pageCount;

  /// Text shown when [entries] is empty.
  ///
  /// Provide the localised string from ARB (e.g. `l10n.tocEmpty`).
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Text(
            emptyText,
            style: theme.textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Flatten the tree to find the active entry index. DFS pre-order.
        final flat = _flattenEntries(entries);
        int? activeEntryPage;
        // Find the highest entry whose pageIndex <= currentPage.
        for (final entry in flat) {
          final p = entry.pageIndex;
          if (p != null && p <= controller.currentPage) {
            activeEntryPage = p;
          }
        }

        return ListView(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
          children: _buildRows(
            context,
            entries,
            depth: 0,
            activeEntryPage: activeEntryPage,
          ),
        );
      },
    );
  }

  /// Recursively builds row widgets for [entries] at the given [depth].
  List<Widget> _buildRows(
    BuildContext context,
    List<PdfTocEntry> entries, {
    required int depth,
    required int? activeEntryPage,
  }) {
    final rows = <Widget>[];
    for (final entry in entries) {
      final bool isInteractive = entry.pageIndex != null;
      final bool isActive = isInteractive && entry.pageIndex == activeEntryPage;

      rows.add(
        _TocRow(
          entry: entry,
          depth: depth,
          isActive: isActive,
          onTap: isInteractive
              ? () => controller.setPage(entry.pageIndex!, pageCount: pageCount)
              : null,
        ),
      );

      if (entry.children.isNotEmpty) {
        rows.addAll(
          _buildRows(
            context,
            entry.children,
            depth: depth + 1,
            activeEntryPage: activeEntryPage,
          ),
        );
      }
    }
    return rows;
  }

  /// Flattens the TOC tree into a list using DFS pre-order traversal.
  static List<PdfTocEntry> _flattenEntries(List<PdfTocEntry> entries) {
    final result = <PdfTocEntry>[];
    for (final entry in entries) {
      result.add(entry);
      if (entry.children.isNotEmpty) {
        result.addAll(_flattenEntries(entry.children));
      }
    }
    return result;
  }
}

/// A single row in the [TocView] list.
class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.entry,
    required this.depth,
    required this.isActive,
    required this.onTap,
  });

  final PdfTocEntry entry;
  final int depth;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bool isInteractive = onTap != null;

    // Active background tint: activeAccent at ~12% opacity.
    final Color? bgColor = isActive ? colors.surfaceTint : null;

    Widget row = Container(
      color: bgColor,
      child: Row(
        children: [
          // Left indicator bar for active entry.
          SizedBox(
            width: _kActiveIndicatorWidth,
            child: isActive
                ? Container(color: colors.surfaceTint)
                : const SizedBox.shrink(),
          ),
          // Depth indentation.
          SizedBox(width: _kDepthIndent * depth),
          // Content.
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: theme.textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (entry.pageIndex != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${entry.pageIndex! + 1}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Wrap interactive rows in InkWell + Semantics.
    if (isInteractive) {
      final String pageLabel = entry.pageIndex != null
          ? ', page ${entry.pageIndex! + 1}'
          : '';
      row = Semantics(
        button: true,
        label: '${entry.title}$pageLabel',
        child: InkWell(onTap: onTap, child: row),
      );
    } else {
      // Non-interactive section labels — expose as plain text.
      row = Semantics(label: entry.title, child: row);
    }

    return row;
  }
}
