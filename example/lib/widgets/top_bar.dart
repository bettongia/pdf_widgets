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

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart'
    show PdfTocEntry, ViewerController;
import 'package:flutter/material.dart';

/// The application top bar.
///
/// Displays three zones in a fixed 40 dp row:
/// - **Left**: app name · file name. Shows only
///   the app name when no document is open.
/// - **Centre**: current TOC section name , derived from
///   [TopBar.controller] and [TopBar.tocEntries]. Updates as the page changes.
/// - **Right**: open-file icon button.
///
/// ## Section tracking
///
/// The active TOC section is the highest entry (DFS pre-order) whose
/// [PdfTocEntry.pageIndex] is ≤ [ViewerController.currentPage]. The
/// algorithm flattens the tree once and performs a linear scan — efficient
/// enough for typical TOC sizes (< 500 entries).
///
/// ## Accessibility
///
/// The open-file button carries a [Semantics] label from [openFileLabel].
class TopBar extends StatelessWidget {
  /// Creates a [TopBar].
  const TopBar({
    super.key,
    required this.appName,
    required this.openFileLabel,
    required this.onOpenFile,
    this.fileName,
    this.controller,
    this.tocEntries,
  });

  /// Application name shown on the left (e.g. "Quietly").
  final String appName;

  /// Accessible label for the open-file icon button.
  final String openFileLabel;

  /// Called when the user taps the open-file button.
  final VoidCallback onOpenFile;

  /// Currently open file's display name, or null when no document is open.
  final String? fileName;

  /// The viewer controller for the active document, used to read the current
  /// page for section tracking. Null when no document is open.
  final ViewerController? controller;

  /// TOC entries for the active document, used for section tracking. Null or
  /// empty when the document has no bookmarks.
  final List<PdfTocEntry>? tocEntries;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: controller != null
          ? ListenableBuilder(
              listenable: controller!,
              builder: (context, _) => _TopBarRow(
                appName: appName,
                fileName: fileName,
                openFileLabel: openFileLabel,
                onOpenFile: onOpenFile,
                sectionName: _activeSection(
                  controller!.currentPage,
                  tocEntries,
                ),
              ),
            )
          : _TopBarRow(
              appName: appName,
              fileName: fileName,
              openFileLabel: openFileLabel,
              onOpenFile: onOpenFile,
            ),
    );
  }

  /// Returns the title of the active TOC section for [currentPage].
  ///
  /// Flattens the entry tree using DFS pre-order then finds the last entry
  /// whose [PdfTocEntry.pageIndex] ≤ [currentPage].
  static String? _activeSection(int currentPage, List<PdfTocEntry>? entries) {
    if (entries == null || entries.isEmpty) return null;
    final flat = <PdfTocEntry>[];
    _flatten(entries, flat);
    String? active;
    for (final entry in flat) {
      final idx = entry.pageIndex;
      if (idx != null && idx <= currentPage) {
        active = entry.title;
      }
    }
    return active;
  }

  static void _flatten(List<PdfTocEntry> entries, List<PdfTocEntry> out) {
    for (final entry in entries) {
      out.add(entry);
      if (entry.children.isNotEmpty) {
        _flatten(entry.children, out);
      }
    }
  }
}

class _TopBarRow extends StatelessWidget {
  const _TopBarRow({
    required this.appName,
    required this.openFileLabel,
    required this.onOpenFile,
    this.fileName,
    this.sectionName,
  });

  final String appName;
  final String? fileName;
  final String? sectionName;
  final String openFileLabel;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Left zone: app name · file name.
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: fileName != null
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$appName  ·  ',
                          style: theme.textTheme.titleSmall,
                        ),
                        TextSpan(
                          text: fileName,
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                : Text(
                    appName,
                    style: theme.textTheme.titleSmall,

                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
          ),
        ),
        // Centre zone: current TOC section.
        if (sectionName != null)
          Expanded(
            child: Text(
              sectionName!,
              style: theme.textTheme.titleSmall,

              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        // Right zone: open-file icon.
        Semantics(
          label: openFileLabel,
          button: true,
          child: IconButton(
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            tooltip: openFileLabel,
            onPressed: onOpenFile,
            color: theme.colorScheme.onSecondary, //_BettoColors.ink500,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
        ),
      ],
    );
  }
}
