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
import 'package:intl/intl.dart';

import '../viewer_controller.dart';

/// A widget that displays a list of PDF annotations (notes and highlights).
///
/// [AnnotationView] filters the provided annotations to show only
/// [PdfTextAnnotation] (sticky notes) and [PdfMarkupAnnotation] with subtype
/// [PdfAnnotationType.highlight]. Other annotation types are silently ignored.
///
/// A header shows the total count and per-type counts, plus a toggle switch
/// that drives [ViewerController.renderAnnotations] to show or hide
/// annotation rendering in the PDF page.
///
/// Cards are sorted in page order. Each card shows:
/// - A left accent bar (clay for highlights, ink-500 for notes).
/// - A type badge with icon.
/// - The page number.
/// - The annotation text (contents → markedText → author → dash fallback).
/// - Author and formatted date when available.
///
/// ## Accessibility
///
/// Each card is wrapped in [Semantics] with `button: true` and a label of
/// "Annotation on page N: …".
///
/// ## Example
///
/// ```dart
/// AnnotationView(
///   annotations: pageAnnotations,
///   controller: controller,
///   noteLabel: l10n.annotationNote,
///   highlightLabel: l10n.annotationHighlight,
///   totalLabel: (count) => l10n.annotationsTotal(count),
///   noneFoundText: l10n.annotationsNoneFound,
///   toggleOnLabel: l10n.annotationToggleOn,
///   toggleOffLabel: l10n.annotationToggleOff,
/// )
/// ```
class AnnotationView extends StatelessWidget {
  /// Creates a [AnnotationView].
  const AnnotationView({
    super.key,
    required this.annotations,
    required this.controller,
    required this.noteLabel,
    required this.highlightLabel,
    required this.totalLabel,
    required this.noneFoundText,
    required this.toggleOnLabel,
    required this.toggleOffLabel,
    this.locale,
  });

  /// All page annotations from the document (all pages).
  ///
  /// This widget filters to note and highlight types internally.
  final List<PdfPageAnnotations> annotations;

  /// Controller that drives annotation rendering in the PDF page.
  final ViewerController controller;

  /// Localised label for note annotations (e.g. "Note").
  final String noteLabel;

  /// Localised label for highlight annotations (e.g. "Highlight").
  final String highlightLabel;

  /// Builds the localised total annotation count string.
  final String Function(int count) totalLabel;

  /// Text shown when there are no note or highlight annotations.
  final String noneFoundText;

  /// Accessible label for the annotation toggle when annotations are visible
  /// (tapping will hide them).
  final String toggleOnLabel;

  /// Accessible label for the annotation toggle when annotations are hidden
  /// (tapping will show them).
  final String toggleOffLabel;

  /// Locale for date formatting. Defaults to the system locale.
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Collect only note and highlight annotations, sorted by page.
    final filtered = <_AnnotationItem>[];
    for (final page in annotations) {
      for (final annot in page.annotations) {
        if (annot is PdfTextAnnotation) {
          filtered.add(_AnnotationItem(annot: annot, isHighlight: false));
        } else if (annot is PdfMarkupAnnotation &&
            annot.subtype == PdfAnnotationType.highlight) {
          filtered.add(_AnnotationItem(annot: annot, isHighlight: true));
        }
      }
    }
    // Already in page order since extractAnnotations streams page-by-page.

    final int noteCount = filtered.where((a) => !a.isHighlight).length;
    final int highlightCount = filtered.where((a) => a.isHighlight).length;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: counts + toggle.
            _AnnotationHeader(
              totalLabel: totalLabel(filtered.length),
              noteCount: noteCount,
              noteLabel: noteLabel,
              highlightCount: highlightCount,
              highlightLabel: highlightLabel,
              renderAnnotations: controller.renderAnnotations,
              toggleOnLabel: toggleOnLabel,
              toggleOffLabel: toggleOffLabel,

              onToggle: () {
                controller.renderAnnotations = !controller.renderAnnotations;
              },
            ),
            const Divider(height: 1, thickness: 1),
            // List of cards.
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(24),
                        child: Text(
                          noneFoundText,
                          style: textTheme.labelMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: 4,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _AnnotationCard(
                          item: item,
                          noteLabel: noteLabel,
                          highlightLabel: highlightLabel,
                          locale: locale,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Header row showing annotation counts and the annotation-rendering toggle.
class _AnnotationHeader extends StatelessWidget {
  const _AnnotationHeader({
    required this.totalLabel,
    required this.noteCount,
    required this.noteLabel,
    required this.highlightCount,
    required this.highlightLabel,
    required this.renderAnnotations,
    required this.toggleOnLabel,
    required this.toggleOffLabel,
    required this.onToggle,
  });

  final String totalLabel;
  final int noteCount;
  final String noteLabel;
  final int highlightCount;
  final String highlightLabel;
  final bool renderAnnotations;
  final String toggleOnLabel;
  final String toggleOffLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(totalLabel, style: textTheme.labelMedium)),
              // Annotation visibility toggle.
              // Use MergeSemantics so the outer label merges with the Switch
              // node, satisfying labeledTapTargetGuideline.
              MergeSemantics(
                child: Semantics(
                  label: renderAnnotations ? toggleOnLabel : toggleOffLabel,
                  child: Switch(
                    value: renderAnnotations,
                    onChanged: (_) => onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ),
            ],
          ),
          if (noteCount > 0 || highlightCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$noteCount $noteLabel · $highlightCount $highlightLabel',
              style: textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// A single annotation card.
class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({
    required this.item,
    required this.noteLabel,
    required this.highlightLabel,
    required this.locale,
  });

  final _AnnotationItem item;
  final String noteLabel;
  final String highlightLabel;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final annot = item.annot;
    final bool isHighlight = item.isHighlight;

    // Accent color
    final Color accentColor = isHighlight ? colors.onSurface : colors.onSurface;

    // Determine displayed text. Fallback chain: contents → markedText →
    // author → dash.
    String displayText = '—';
    if (annot.contents != null && annot.contents!.isNotEmpty) {
      displayText = annot.contents!;
    } else if (isHighlight && annot is PdfMarkupAnnotation) {
      final markedText = annot.markedText;
      if (markedText != null && markedText.isNotEmpty) {
        displayText = markedText;
      } else if (annot.author != null && annot.author!.isNotEmpty) {
        displayText = annot.author!;
      }
    } else if (annot.author != null && annot.author!.isNotEmpty) {
      displayText = annot.author!;
    }

    final String? formattedDate = _formatDate(annot.modifiedDate, locale);

    final String semanticLabel =
        'Annotation on page ${annot.pageIndex + 1}: $displayText';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.surfaceContainer, width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar.
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + page number row.
                      Row(
                        children: [
                          Icon(
                            isHighlight ? Icons.highlight : Icons.sticky_note_2,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isHighlight ? highlightLabel : noteLabel,
                            style: textTheme.labelMedium,
                          ),
                          const Spacer(),
                          Text(
                            'p. ${annot.pageIndex + 1}',
                            style: textTheme.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Annotation text content.
                      Text(
                        displayText,
                        style: textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Author + date footer.
                      if (annot.author != null || formattedDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (annot.author != null &&
                                annot.author!.isNotEmpty)
                              annot.author!,
                            if (formattedDate != null) formattedDate,
                          ].join(' · '),
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a [PdfDate] value using [DateFormat]. Returns null if [date] or
  /// its [DateTime] value is null.
  static String? _formatDate(PdfDate? date, String? locale) {
    final dt = date?.value;
    if (dt == null) return null;
    return DateFormat.yMMMd(locale).format(dt.toLocal());
  }
}

/// Internal representation of a filtered annotation for display.
class _AnnotationItem {
  const _AnnotationItem({required this.annot, required this.isHighlight});

  final PdfAnnotation annot;
  final bool isHighlight;
}
