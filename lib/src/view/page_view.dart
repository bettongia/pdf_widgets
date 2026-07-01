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

import 'dart:ui' as ui;

import 'package:betto_pdf_widgets/src/render/document_rendering.dart'
    show DocumentRendering;
import 'package:betto_pdf_widgets/src/render/render_options.dart';
import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/material.dart';

/// A widget that renders a single page of a [PdfDocument].
///
/// [PageView] is a stateful widget that accepts a [PdfDocument] and a
/// pageIndex. On build it calls [PdfDocument.getPageSize] to derive the
/// aspect ratio, then [PdfDocument.renderPageToBytes] at the widget's full available
/// width (fit-to-width). The logical width is multiplied by
/// [MediaQuery.devicePixelRatioOf] to produce sharp output on high-DPI displays.
///
/// A [CircularProgressIndicator] is shown while the render is in flight.
/// The last successfully rendered [ui.Image] is cached and reused to avoid
/// re-rendering on cosmetic rebuilds. Re-rendering is triggered only when
/// pageIndex changes or the available width changes by more than 2 logical
/// pixels.
///
/// ## Example
///
/// ```dart
/// PageView(
///   document: doc,
///   pageIndex: 0,
///   options: RenderOptions(renderAnnotations: false),
/// )
/// ```
///
/// ## Resource management
///
/// The widget disposes each [ui.Image] it owns when it is replaced by a new
/// render or when the widget is disposed. The [PdfDocument] itself is owned
/// by the caller and is not closed by this widget.
///
/// ## Error handling
///
/// Render errors ([RangeError], [StateError], [PdfiumException]) are caught and
/// displayed as a centred error message. The widget does not rethrow.
///
/// ## Accessibility
///
/// The rendered page canvas is wrapped in a [Semantics] widget labelled as an
/// image. Provide a meaningful `semanticLabel` when the document content is
/// known (e.g. the file name). Loading and error states are also labelled.
class PageView extends StatefulWidget {
  /// Creates a [PageView].
  ///
  /// [document] and [pageIndex] are required. [pageIndex] must be a valid
  /// page index for [document]; an out-of-range value causes a [RangeError]
  /// that is displayed as an error message.
  const PageView({
    super.key,
    required this.document,
    required this.pageIndex,
    this.options = const RenderOptions(),
    this.semanticLabel,
  });

  /// The PDF document to render.
  final PdfDocument document;

  /// The zero-based index of the page to display.
  final int pageIndex;

  /// Options controlling how the page is rendered.
  final RenderOptions options;

  /// A label describing the content of the rendered page for accessibility.
  ///
  /// When non-null, this label is used as the [Semantics.label] for the
  /// rendered image. A typical value is the document file name or title.
  final String? semanticLabel;

  @override
  State<PageView> createState() => _PageViewState();
}

class _PageViewState extends State<PageView> {
  ui.Image? _image;
  Object? _error;
  bool _loading = false;

  // Tracked so we can skip re-renders when nothing meaningful changed.
  int? _renderedPageIndex;
  double? _renderedLogicalWidth;

  // The in-flight render future token. When pageIndex changes we mark the
  // current token stale and discard its result on completion.
  int _renderGeneration = 0;

  @override
  void didUpdateWidget(PageView old) {
    super.didUpdateWidget(old);
    if (old.pageIndex != widget.pageIndex ||
        old.document != widget.document ||
        old.options != widget.options) {
      // Stale any in-flight render, then reset all transient state so the next
      // build triggers a fresh render for the new page/document/options.
      _renderGeneration++;
      _renderedPageIndex = null;
      _renderedLogicalWidth = null;
      _loading = false;
      _error = null;
      _disposeImage();
    }
  }

  @override
  void dispose() {
    _renderGeneration++; // stale any in-flight future
    _disposeImage();
    super.dispose();
  }

  void _disposeImage() {
    _image?.dispose();
    _image = null;
  }

  Future<void> _render(double logicalWidth, double devicePixelRatio) async {
    final pageIndex = widget.pageIndex;
    final generation = ++_renderGeneration;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final PdfPageSize size = await widget.document.getPageSize(pageIndex);

      // Guard against malformed pages with zero dimensions.
      final double aspectRatio = (size.heightPt > 0)
          ? size.widthPt / size.heightPt
          : 1.0;

      final int pixelWidth = (logicalWidth * devicePixelRatio).round();
      final int pixelHeight = (pixelWidth / aspectRatio).round();

      final ui.Image image = await widget.document.renderPage(
        pageIndex,
        pixelWidth,
        pixelHeight,
        options: widget.options,
      );

      if (generation != _renderGeneration) {
        // A newer render was kicked off — discard this stale result.
        image.dispose();
        return;
      }

      if (!mounted) {
        image.dispose();
        return;
      }

      setState(() {
        _disposeImage();
        _image = image;
        _renderedPageIndex = pageIndex;
        _renderedLogicalWidth = logicalWidth;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (generation != _renderGeneration) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double logicalWidth = constraints.maxWidth;

        // Kick off a re-render if the page or width changed significantly.
        // When _error is non-null, do not retry automatically — the error
        // persists until the caller changes pageIndex or document.
        final bool needsRender =
            !_loading &&
            _error == null &&
            (_renderedPageIndex != widget.pageIndex ||
                _renderedLogicalWidth == null ||
                (logicalWidth - _renderedLogicalWidth!).abs() > 2.0);

        if (needsRender && logicalWidth > 0) {
          // Schedule render after the current build frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _render(logicalWidth, devicePixelRatio);
          });
        }

        if (_error != null) {
          return _buildError(_error!);
        }

        if (_image != null) {
          final aspectRatio = _image!.width / _image!.height;
          return Semantics(
            label: widget.semanticLabel ?? 'PDF page ${widget.pageIndex + 1}',
            image: true,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: CustomPaint(
                painter: _PagePainter(_image!),
                size: Size(logicalWidth, logicalWidth / aspectRatio),
              ),
            ),
          );
        }

        // Loading state.
        return Semantics(
          label: 'Loading page ${widget.pageIndex + 1}',
          child: AspectRatio(
            aspectRatio: 1 / 1.414, // approximate A4 while loading
            child: Center(
              child: disableAnimations
                  ? const SizedBox.shrink()
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(Object error) {
    return Semantics(
      label: 'Failed to render page ${widget.pageIndex + 1}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to render page ${widget.pageIndex + 1}: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  const _PagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_PagePainter old) => old.image != image;
}
