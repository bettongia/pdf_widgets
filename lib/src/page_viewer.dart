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

import 'viewer_controller.dart';

/// The border (in logical pixels) around a page in [ZoomMode.fitPage].
const double _kFitPageBorder = 24.0;

/// A PDF page viewer widget that supports multiple zoom modes and search-match
/// overlays.
///
/// [PageViewer] wraps [PdfDocument] rendering and a [ViewerController]
/// to provide a zoom-aware, pannable single-page view. It listens to the
/// controller and re-renders the page whenever the controller changes.
///
/// ## Zoom modes
///
/// | Mode | Behaviour |
/// |------|-----------|
/// | [ZoomMode.fitWidth] | Renders at the full available logical width. |
/// | [ZoomMode.fitPage] | Renders so the full page (both dimensions) fits within the available area with a 24 dp border. |
/// | [ZoomMode.custom] | Renders at `availableWidth * controller.zoomFactor`. |
///
/// In all modes the logical render width is multiplied by
/// [MediaQuery.devicePixelRatioOf] before passing to the rendering engine to
/// produce sharp output on high-DPI displays.
///
/// ## Search overlays
///
/// When [ViewerController.activeSearchMatches] contains matches on the
/// current page, translucent `dusk`-tinted rectangles are painted over the
/// matching text regions. Coordinates are transformed from PDF user-space
/// (bottom-left origin) to Flutter/screen space (top-left origin) using:
///
/// ```
/// flutterX = pdfRect.left / pageWidthPt * widgetWidth
/// flutterY = (pageHeightPt - pdfRect.top) / pageHeightPt * widgetHeight
/// rectWidth  = (pdfRect.right - pdfRect.left) / pageWidthPt * widgetWidth
/// rectHeight = (pdfRect.top - pdfRect.bottom) / pageHeightPt * widgetHeight
/// ```
///
/// ## Example
///
/// ```dart
/// PageViewer(
///   document: doc,
///   pageCount: pageCount,
///   controller: controller,
///   semanticLabel: 'Annual report, page 1',
/// )
/// ```
class PageViewer extends StatefulWidget {
  /// Creates a [PageViewer].
  ///
  /// [document], [pageCount], and [controller] are required.
  const PageViewer({
    super.key,
    required this.document,
    required this.pageCount,
    required this.controller,
    this.semanticLabel,
  });

  /// The PDF document to render.
  final PdfDocument document;

  /// Total number of pages in [document].
  ///
  /// Used to validate page indices and enable/disable navigation buttons in
  /// consuming widgets.
  final int pageCount;

  /// The controller that drives page navigation, zoom mode, annotation
  /// rendering, and search overlays.
  final ViewerController controller;

  /// Accessibility label for the rendered page canvas.
  ///
  /// When non-null, used as the [Semantics.label] for the rendered image.
  /// A typical value is the document file name or title.
  final String? semanticLabel;

  @override
  State<PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<PageViewer> {
  ui.Image? _image;
  Object? _error;
  bool _loading = false;

  // Intrinsic page dimensions in PDF points — needed for coordinate transforms.
  double _pageWidthPt = 0;
  double _pageHeightPt = 0;

  // Cache keys to detect when a re-render is needed.
  int? _renderedPage;
  double? _renderedLogicalWidth;
  double? _renderedLogicalHeight;
  ZoomMode? _renderedZoomMode;
  double? _renderedZoomFactor;
  bool? _renderedAnnotations;
  int _renderGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(PageViewer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
    if (old.document != widget.document) {
      _invalidate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _renderGeneration++;
    _disposeImage();
    super.dispose();
  }

  void _onControllerChange() {
    // If the page, zoom mode, factor, or annotation setting changed, we need
    // a fresh render. Checking against the cached values avoids spurious
    // re-renders when unrelated controller fields changed (e.g. search matches
    // on a different page).
    final c = widget.controller;
    final needsRender =
        c.currentPage != _renderedPage ||
        c.zoomMode != _renderedZoomMode ||
        c.zoomFactor != _renderedZoomFactor ||
        c.renderAnnotations != _renderedAnnotations;

    if (needsRender) {
      setState(_invalidate);
    } else {
      // Search matches changed — repaint the overlay without re-rendering.
      setState(() {});
    }
  }

  void _invalidate() {
    _renderGeneration++;
    _renderedPage = null;
    _renderedLogicalWidth = null;
    _renderedLogicalHeight = null;
    _renderedZoomMode = null;
    _renderedZoomFactor = null;
    _renderedAnnotations = null;
    _loading = false;
    _error = null;
    _disposeImage();
  }

  void _disposeImage() {
    _image?.dispose();
    _image = null;
  }

  Future<void> _render(
    double logicalWidth,
    double logicalHeight,
    double devicePixelRatio,
    ZoomMode zoomMode,
    double zoomFactor,
    bool renderAnnotations,
  ) async {
    final pageIndex = widget.controller.currentPage;
    final generation = ++_renderGeneration;

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final PdfPageSize size = await widget.document.getPageSize(pageIndex);
      if (generation != _renderGeneration) return;

      // Guard against degenerate page sizes.
      final double pageWidthPt = size.widthPt > 0 ? size.widthPt : 1.0;
      final double pageHeightPt = size.heightPt > 0 ? size.heightPt : 1.0;
      final double aspectRatio = pageWidthPt / pageHeightPt;

      // Determine the logical render width based on zoom mode.
      final double renderLogicalWidth = switch (zoomMode) {
        ZoomMode.fitWidth => logicalWidth,
        ZoomMode.fitPage => _fitPageWidth(
          logicalWidth,
          logicalHeight,
          aspectRatio,
        ),
        ZoomMode.custom => logicalWidth * zoomFactor,
      };

      // Keep the controller's effective factor up to date so the toolbar
      // zoom buttons step from the actual visual scale.
      if (logicalWidth > 0) {
        widget.controller.effectiveZoomFactor =
            renderLogicalWidth / logicalWidth;
      }

      final int pixelWidth = (renderLogicalWidth * devicePixelRatio)
          .round()
          .clamp(1, 16384);
      final int pixelHeight = (pixelWidth / aspectRatio).round().clamp(
        1,
        16384,
      );

      final ui.Image image = await widget.document.renderPage(
        pageIndex,
        pixelWidth,
        pixelHeight,
        options: RenderOptions(renderAnnotations: renderAnnotations),
      );

      if (generation != _renderGeneration) {
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
        _pageWidthPt = pageWidthPt;
        _pageHeightPt = pageHeightPt;
        _renderedPage = pageIndex;
        _renderedLogicalWidth = logicalWidth;
        _renderedLogicalHeight = logicalHeight;
        _renderedZoomMode = zoomMode;
        _renderedZoomFactor = zoomFactor;
        _renderedAnnotations = renderAnnotations;
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

  /// Computes the logical widget width that makes the page fit within
  /// [availableWidth] × [availableHeight] with [_kFitPageBorder] on each side.
  ///
  /// When [availableHeight] is finite both dimensions are constrained: the
  /// returned width is the minimum of the width budget and the width that
  /// produces a height equal to the height budget (via [aspectRatio]). When
  /// [availableHeight] is infinite (unconstrained scroll axis) the method falls
  /// back to fit-width behaviour.
  double _fitPageWidth(
    double availableWidth,
    double availableHeight,
    double aspectRatio,
  ) {
    final double widthBudget = (availableWidth - 2 * _kFitPageBorder).clamp(
      1.0,
      availableWidth,
    );
    if (availableHeight.isFinite && availableHeight > 2 * _kFitPageBorder) {
      final double heightBudget = availableHeight - 2 * _kFitPageBorder;
      // Width that would make the page exactly fill the height budget.
      final double widthForHeight = heightBudget * aspectRatio;
      return widthForHeight.clamp(1.0, widthBudget);
    }
    return widthBudget;
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    final c = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double logicalWidth = constraints.maxWidth;
        final double logicalHeight = constraints.maxHeight;

        // Use stored page aspect ratio for sizing previews while a render is
        // in flight; fall back to portrait A4 proportions when unknown.
        final double storedAspect = (_pageWidthPt > 0 && _pageHeightPt > 0)
            ? _pageWidthPt / _pageHeightPt
            : 1.0 / 1.414;

        // Determine render logical width based on zoom mode.
        final double renderLogicalWidth = switch (c.zoomMode) {
          ZoomMode.fitWidth => logicalWidth,
          ZoomMode.fitPage => _fitPageWidth(
            logicalWidth,
            logicalHeight,
            storedAspect,
          ),
          ZoomMode.custom => logicalWidth * c.zoomFactor,
        };

        final bool needsRender =
            !_loading &&
            _error == null &&
            (c.currentPage != _renderedPage ||
                c.zoomMode != _renderedZoomMode ||
                c.zoomFactor != _renderedZoomFactor ||
                c.renderAnnotations != _renderedAnnotations ||
                _renderedLogicalWidth == null ||
                (logicalWidth - _renderedLogicalWidth!).abs() > 2.0 ||
                (c.zoomMode == ZoomMode.fitPage &&
                    (_renderedLogicalHeight == null ||
                        (logicalHeight - _renderedLogicalHeight!).abs() >
                            2.0)));

        if (needsRender && logicalWidth > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _render(
                logicalWidth,
                logicalHeight,
                devicePixelRatio,
                c.zoomMode,
                c.zoomFactor,
                c.renderAnnotations,
              );
            }
          });
        }

        if (_error != null) {
          return _buildError(_error!);
        }

        if (_image != null) {
          // Logical dimensions of the rendered image widget.
          final double imageAspect = _image!.width / _image!.height;
          // Custom zoom: let the canvas exceed the viewport — InteractiveViewer
          // pans it. Other modes: clamp to the available width.
          final double widgetWidth = c.zoomMode == ZoomMode.custom
              ? renderLogicalWidth.clamp(1.0, double.infinity)
              : renderLogicalWidth.clamp(1.0, logicalWidth);
          final double widgetHeight = widgetWidth / imageAspect;

          // Build the matches for the current page.
          final List<PdfSearchMatch> pageMatches = c.activeSearchMatches
              .where((m) => m.pageIndex == c.currentPage)
              .toList();
          final theme = Theme.of(context);
          final Widget canvas = Semantics(
            label: widget.semanticLabel ?? 'PDF page ${c.currentPage + 1}',
            image: true,
            child: SizedBox(
              width: widgetWidth,
              height: widgetHeight,
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _PagePainter(_image!),
                    size: Size(widgetWidth, widgetHeight),
                  ),
                  if (pageMatches.isNotEmpty && _pageWidthPt > 0)
                    CustomPaint(
                      painter: _SearchOverlayPainter(
                        matches: pageMatches,
                        pageWidthPt: _pageWidthPt,
                        pageHeightPt: _pageHeightPt,
                        highlightColor:
                            theme.textSelectionTheme.selectionColor ??
                            theme.colorScheme.tertiary.withValues(alpha: 0.4),
                      ),
                      size: Size(widgetWidth, widgetHeight),
                    ),
                ],
              ),
            ),
          );

          // fitPage: page fits entirely within the viewport — no scrolling
          // needed; center it with the border as padding on all sides.
          if (c.zoomMode == ZoomMode.fitPage) {
            return Padding(
              padding: const EdgeInsetsDirectional.all(_kFitPageBorder),
              child: Center(child: canvas),
            );
          }

          // custom zoom: InteractiveViewer handles pan and pinch-zoom.
          //
          // The child SizedBox is sized to at least the viewport dimensions so
          // Center keeps the canvas centred when it is smaller than the
          // viewport (zoomed out). When the canvas is larger than the viewport
          // InteractiveViewer pans over it. constrained: false lets the child
          // SizedBox exceed the viewport without being clamped.
          if (c.zoomMode == ZoomMode.custom) {
            final double safeHeight = logicalHeight.isFinite
                ? logicalHeight
                : 0.0;
            final double containerW =
                widgetWidth + 2 * _kFitPageBorder > logicalWidth
                ? widgetWidth + 2 * _kFitPageBorder
                : logicalWidth;
            final double containerH =
                widgetHeight + 2 * _kFitPageBorder > safeHeight
                ? widgetHeight + 2 * _kFitPageBorder
                : safeHeight;
            return InteractiveViewer(
              constrained: false,
              boundaryMargin: EdgeInsets.zero,
              minScale: 0.1,
              maxScale: 10.0,
              child: SizedBox(
                width: containerW,
                height: containerH,
                child: Center(child: canvas),
              ),
            );
          }

          // fitWidth: page fills available width; allow vertical scrolling.
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: _kFitPageBorder,
              ),
              child: Center(child: canvas),
            ),
          );
        }

        // Loading state.
        return Semantics(
          label: 'Loading page ${c.currentPage + 1}',
          child: AspectRatio(
            aspectRatio: 1 / 1.414,
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
      label: 'Failed to render page ${widget.controller.currentPage + 1}',
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Text(
            'Failed to render page '
            '${widget.controller.currentPage + 1}: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Paints a single rendered PDF page image, scaled to fill the canvas size.
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

/// Paints translucent search-match rectangles over the page canvas.
///
/// Coordinates are transformed from PDF user-space (origin bottom-left) to
/// Flutter widget space (origin top-left). The transform for each axis is:
///
/// ```
/// flutterX = pdfLeft / pageWidthPt * canvasWidth
/// flutterY = (pageHeightPt - pdfTop) / pageHeightPt * canvasHeight
/// rectW    = (pdfRight - pdfLeft) / pageWidthPt * canvasWidth
/// rectH    = (pdfTop - pdfBottom) / pageHeightPt * canvasHeight
/// ```
class _SearchOverlayPainter extends CustomPainter {
  const _SearchOverlayPainter({
    required this.matches,
    required this.pageWidthPt,
    required this.pageHeightPt,
    required this.highlightColor,
  });

  final List<PdfSearchMatch> matches;
  final double pageWidthPt;
  final double pageHeightPt;

  /// Wash color for search-match highlight rectangles.
  ///
  /// Resolved once per build from the ambient [ThemeData]: prefers
  /// [TextSelectionThemeData.selectionColor], falling back to
  /// [ColorScheme.tertiary] at 40% opacity when the host app has not set an
  /// explicit text-selection color.
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = highlightColor;
    final double scaleX = size.width / pageWidthPt;
    final double scaleY = size.height / pageHeightPt;

    for (final match in matches) {
      for (final rect in match.rects) {
        // PDF coordinates: bottom-left origin, y increases upwards.
        // Flutter coordinates: top-left origin, y increases downwards.
        final double flutterLeft = rect.left * scaleX;
        final double flutterTop = (pageHeightPt - rect.top) * scaleY;
        final double flutterRight = rect.right * scaleX;
        final double flutterBottom = (pageHeightPt - rect.bottom) * scaleY;

        canvas.drawRect(
          Rect.fromLTRB(flutterLeft, flutterTop, flutterRight, flutterBottom),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SearchOverlayPainter old) =>
      old.matches != matches ||
      old.pageWidthPt != pageWidthPt ||
      old.pageHeightPt != pageHeightPt ||
      old.highlightColor != highlightColor;
}
