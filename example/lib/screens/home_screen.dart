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
    show
        PdfTocEntry,
        TocView,
        PdfPageAnnotations,
        PdfMetadata,
        PdfDocumentInfo,
        ThumbnailGrid,
        AnnotationView,
        SearchView,
        DocumentInfoLabels,
        InfoView;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/document_state.dart';
import '../widgets/menu_rail.dart';
import '../widgets/sliding_sidebar.dart';
import '../widgets/tab_bar.dart';
import '../widgets/top_bar.dart';
import '../widgets/viewer_pane.dart';

/// The main application screen.
///
/// Layout (when a document is open):
/// ```
/// ┌─────────────────────────────────────────┐
/// │ TopBar (40 dp)                          │
/// ├──────┬──────────────────────────────────┤
/// │ Rail │ SlidingSidebar │ PdfViewerPane   │
/// │ 48dp │ 280dp (opt.)   │ Expanded        │
/// └──────┴────────────────┴─────────────────┘
/// ```
///
/// When no document is open the row below the top bar shows a centred
/// empty-state message instead of the rail + sidebar + pane layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.onClose,
    required this.onOpenFile,
  });

  final DocumentState state;

  /// Called when the user requests to close the tab at the given index.
  final void Function(int index) onClose;

  /// Called when the user requests to open a file (from the top-bar button or
  /// menu).
  final VoidCallback onOpenFile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The rail panel currently shown in the sidebar, or null = closed.
  RailPanel? _activePanel;

  /// Focus nodes for each rail button, to restore focus when sidebar closes.
  final List<FocusNode> _railFocusNodes = List.generate(
    5,
    (_) => FocusNode(),
    growable: false,
  );

  @override
  void dispose() {
    for (final fn in _railFocusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  void _onPanelSelected(RailPanel panel) {
    setState(() {
      _activePanel = (_activePanel == panel) ? null : panel;
    });
  }

  void _closeSidebar() {
    final prev = _activePanel;
    setState(() => _activePanel = null);
    // Return focus to the rail button that opened the sidebar.
    if (prev != null) {
      final idx = RailPanel.values.indexOf(prev);
      if (idx >= 0 && idx < _railFocusNodes.length) {
        _railFocusNodes[idx].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final doc = widget.state.activeDocument;

        return Column(
          children: [
            // Tab strip — shown only when at least one document is open.
            if (widget.state.documents.isNotEmpty)
              PdfTabBar(state: widget.state, onClose: widget.onClose),
            // Top bar — always visible.
            TopBar(
              appName: l10n.appTitle,
              openFileLabel: l10n.openFile,
              onOpenFile: widget.onOpenFile,
              fileName: doc?.fileName,
              controller: doc?.viewerController,
              tocEntries: null, // resolved lazily via FutureBuilder in sidebar
            ),
            // Main content row.
            Expanded(
              child: doc == null
                  ? _EmptyState(l10n: l10n)
                  : _DocumentView(
                      doc: doc,
                      activePanel: _activePanel,
                      onPanelSelected: _onPanelSelected,
                      onCloseSidebar: _closeSidebar,
                      railFocusNodes: _railFocusNodes,
                      l10n: l10n,
                      onOpenFile: widget.onOpenFile,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The main document view: rail + sliding sidebar + PDF viewer.
class _DocumentView extends StatelessWidget {
  const _DocumentView({
    required this.doc,
    required this.activePanel,
    required this.onPanelSelected,
    required this.onCloseSidebar,
    required this.railFocusNodes,
    required this.l10n,
    required this.onOpenFile,
  });

  final OpenDocument doc;
  final RailPanel? activePanel;
  final void Function(RailPanel) onPanelSelected;
  final VoidCallback onCloseSidebar;
  final List<FocusNode> railFocusNodes;
  final AppLocalizations l10n;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left icon rail.
        MenuRail(
          activePanel: activePanel,
          onPanelSelected: onPanelSelected,
          tocLabel: l10n.railToc,
          thumbnailsLabel: l10n.railThumbnails,
          annotationsLabel: l10n.railAnnotations,
          searchLabel: l10n.railSearch,
          infoLabel: l10n.railInfo,
          buttonFocusNodes: railFocusNodes,
        ),
        // Slide-in sidebar.
        SlidingSidebar(
          isOpen: activePanel != null,
          title: _sidebarTitle(activePanel, l10n),
          closeLabel: l10n.sidebarCloseButton,
          onClose: onCloseSidebar,
          child: activePanel == null
              ? const SizedBox.shrink()
              : _SidebarContent(
                  doc: doc,
                  activePanel: activePanel!,
                  l10n: l10n,
                ),
        ),
        // PDF viewer — fills remaining space.
        Expanded(child: PdfViewerPane(doc: doc)),
      ],
    );
  }

  static String _sidebarTitle(RailPanel? panel, AppLocalizations l10n) {
    return switch (panel) {
      RailPanel.toc => l10n.sidebarTocTitle,
      RailPanel.thumbnails => l10n.sidebarThumbnailsTitle,
      RailPanel.annotations => l10n.sidebarAnnotationsTitle,
      RailPanel.search => l10n.sidebarSearchTitle,
      RailPanel.info => l10n.sidebarInfoTitle,
      null => '',
    };
  }
}

/// The content widget rendered inside the [SlidingSidebar] for the active panel.
class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.doc,
    required this.activePanel,
    required this.l10n,
  });

  final OpenDocument doc;
  final RailPanel activePanel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return switch (activePanel) {
      RailPanel.toc => _TocPanel(doc: doc, l10n: l10n),
      RailPanel.thumbnails => _ThumbnailsPanel(doc: doc, l10n: l10n),
      RailPanel.annotations => _AnnotationsPanel(doc: doc, l10n: l10n),
      RailPanel.search => _SearchPanel(doc: doc, l10n: l10n),
      RailPanel.info => _InfoPanel(doc: doc, l10n: l10n),
    };
  }
}

// ---------------------------------------------------------------------------
// Individual sidebar panels
// ---------------------------------------------------------------------------

class _TocPanel extends StatelessWidget {
  const _TocPanel({required this.doc, required this.l10n});
  final OpenDocument doc;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PdfTocEntry>>(
      future: doc.tocFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return TocView(
          entries: snap.data ?? [],
          controller: doc.viewerController,
          pageCount: doc.pageCount,
          emptyText: l10n.tocEmpty,
        );
      },
    );
  }
}

class _ThumbnailsPanel extends StatelessWidget {
  const _ThumbnailsPanel({required this.doc, required this.l10n});
  final OpenDocument doc;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ThumbnailGrid(
      document: doc.document,
      controller: doc.viewerController,
      pageCount: doc.pageCount,
      pageLabelBuilder: (i) => l10n.thumbnailPageLabel(i + 1),
    );
  }
}

class _AnnotationsPanel extends StatelessWidget {
  const _AnnotationsPanel({required this.doc, required this.l10n});
  final OpenDocument doc;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PdfPageAnnotations>>(
      future: doc.annotationsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return AnnotationView(
          annotations: snap.data ?? [],
          controller: doc.viewerController,
          noteLabel: l10n.annotationNote,
          highlightLabel: l10n.annotationHighlight,
          totalLabel: l10n.annotationsTotal,
          noneFoundText: l10n.annotationsNoneFound,
          toggleOnLabel: l10n.annotationToggleOn,
          toggleOffLabel: l10n.annotationToggleOff,
        );
      },
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.doc, required this.l10n});
  final OpenDocument doc;
  final AppLocalizations l10n;

  /// Flattens a TOC tree into a DFS pre-order list, keeping only entries
  /// that have a valid page index.
  static List<PdfTocEntry> _flattenToc(List<PdfTocEntry> entries) {
    final flat = <PdfTocEntry>[];
    void visit(PdfTocEntry e) {
      if (e.pageIndex != null) flat.add(e);
      for (final child in e.children) {
        visit(child);
      }
    }

    for (final e in entries) {
      visit(e);
    }
    return flat;
  }

  /// Returns the TOC section title that contains [pageIndex], or null if the
  /// TOC is empty or no entry precedes that page.
  static String? _sectionFor(List<PdfTocEntry> flat, int pageIndex) {
    String? result;
    for (final entry in flat) {
      if (entry.pageIndex! <= pageIndex) {
        result = entry.title;
      } else {
        break;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PdfTocEntry>>(
      future: doc.tocFuture,
      builder: (context, snapshot) {
        final flat = snapshot.hasData
            ? _flattenToc(snapshot.data!)
            : const <PdfTocEntry>[];
        return SearchView(
          document: doc.document,
          controller: doc.viewerController,
          hintText: l10n.searchHint,
          clearLabel: l10n.searchClear,
          resultsCountBuilder: l10n.searchResultsCount,
          noResultsText: l10n.searchNoResults,
          resultPageBuilder: l10n.searchResultPage,
          sectionResolver: flat.isEmpty
              ? null
              : (pageIndex) => _sectionFor(flat, pageIndex),
        );
      },
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.doc, required this.l10n});
  final OpenDocument doc;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(PdfMetadata, PdfDocumentInfo)>(
      future: Future.wait([
        doc.metadataFuture,
        doc.docInfoFuture,
      ]).then((r) => (r[0] as PdfMetadata, r[1] as PdfDocumentInfo)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final (meta, info) =
            snap.data ?? (const PdfMetadata(), const PdfDocumentInfo());
        return SingleChildScrollView(
          child: InfoView(
            metadata: meta,
            docInfo: info,
            labels: DocumentInfoLabels(
              title: l10n.infoTitle,
              author: l10n.infoAuthor,
              subject: l10n.infoSubject,
              keywords: l10n.infoKeywords,
              creator: l10n.infoCreator,
              producer: l10n.infoProducer,
              creationDate: l10n.infoCreationDate,
              modDate: l10n.infoModDate,
              fileName: l10n.infoFileName,
              filePath: l10n.infoFilePath,
              fileSize: l10n.infoFileSize,
              pageCount: l10n.infoPageCount,
              pdfVersion: l10n.infoPdfVersion,
              fsCreated: l10n.infoFsCreated,
              fsModified: l10n.infoFsModified,
            ),
            filePath: doc.filePath,
            fileSizeBytes: doc.fileSizeBytes,
            pageCount: doc.pageCount,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.emptyStateHeading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.emptyStateBody, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
