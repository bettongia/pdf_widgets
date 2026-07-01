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
        ViewerController,
        PdfDocument,
        PdfTocEntry,
        PdfPageAnnotations,
        PdfMetadata,
        PdfDocumentInfo;
import 'package:flutter/foundation.dart';

/// An open PDF document plus all UI state needed by the sidebar and viewer.
///
/// [viewerController] owns the page index, zoom mode, annotation toggle, and
/// active search matches for this document. It is disposed when the document
/// tab is closed.
///
/// TOC entries and page annotations are loaded asynchronously on open and
/// stored as [Future] fields; sidebar widgets render them via [FutureBuilder].
class OpenDocument {
  OpenDocument({
    required this.document,
    required this.fileName,
    required this.pageCount,
    this.filePath,
    this.fileSizeBytes,
  }) : viewerController = ViewerController() {
    // Kick off background loads. These complete independently; sidebar widgets
    // display loading states while they are in flight.
    tocFuture = document.tableOfContents;
    annotationsFuture = _loadAnnotations();
    metadataFuture = document.getMetadata();
    docInfoFuture = document.getDocumentInfo();
  }

  /// The loaded PDF document handle.
  final PdfDocument document;

  /// Display name (file basename without path).
  final String fileName;

  /// Filesystem path to the file, used by the Document Info panel.
  final String? filePath;

  /// File size in bytes, used by the Document Info panel.
  final int? fileSizeBytes;

  /// Total number of pages in the document.
  final int pageCount;

  /// Controls the viewer for this document: current page, zoom mode,
  /// annotation toggle, and active search matches.
  ///
  /// Owned by this [OpenDocument] and disposed when the tab is closed.
  final ViewerController viewerController;

  /// Future that resolves to the document's Table of Contents.
  late final Future<List<PdfTocEntry>> tocFuture;

  /// Future that resolves to all page annotations.
  late final Future<List<PdfPageAnnotations>> annotationsFuture;

  /// Future that resolves to the document's PDF metadata (Info dict).
  late final Future<PdfMetadata> metadataFuture;

  /// Future that resolves to the document's low-level info (version, IDs).
  late final Future<PdfDocumentInfo> docInfoFuture;

  Future<List<PdfPageAnnotations>> _loadAnnotations() async {
    final result = <PdfPageAnnotations>[];
    await for (final page in document.extractAnnotations()) {
      result.add(page);
    }
    return result;
  }

  /// Releases the [viewerController]. Called by [DocumentState.close].
  void _dispose() {
    viewerController.dispose();
  }
}

/// Application-level state: the list of open [PdfDocument] instances and
/// the index of the active tab.
///
/// Extends [ChangeNotifier] so widgets can rebuild via [ListenableBuilder].
class DocumentState extends ChangeNotifier {
  final List<OpenDocument> _documents = [];

  /// Immutable view of the open documents.
  List<OpenDocument> get documents => List.unmodifiable(_documents);

  /// Index of the currently selected tab, or -1 when no document is open.
  int _activeIndex = -1;
  int get activeIndex => _activeIndex;

  OpenDocument? get activeDocument =>
      _activeIndex >= 0 && _activeIndex < _documents.length
      ? _documents[_activeIndex]
      : null;

  /// Opens [doc] as a new tab and activates it.
  void add(OpenDocument doc) {
    _documents.add(doc);
    _activeIndex = _documents.length - 1;
    notifyListeners();
  }

  /// Closes the document at [index], disposes its controller and native handle.
  Future<void> close(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final doc = _documents.removeAt(index);
    doc._dispose();
    await doc.document.close();
    if (_documents.isEmpty) {
      _activeIndex = -1;
    } else {
      _activeIndex = (_activeIndex >= _documents.length)
          ? _documents.length - 1
          : _activeIndex;
    }
    notifyListeners();
  }

  /// Activates the tab at [index].
  void activate(int index) {
    if (index < 0 || index >= _documents.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  /// Closes all open documents. Called on app termination.
  Future<void> closeAll() async {
    for (final doc in _documents) {
      doc._dispose();
      await doc.document.close();
    }
    _documents.clear();
    _activeIndex = -1;
    notifyListeners();
  }
}
