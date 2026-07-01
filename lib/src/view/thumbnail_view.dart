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

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/material.dart';

import '../viewer_controller.dart';

/// Maximum number of cached thumbnails.
///
/// Once this limit is reached the least-recently-loaded thumbnails are evicted
/// to bound memory usage. For most PDFs 100 thumbnails occupy < 5 MB of
/// decoded BGRA data at the default 160 px dimension.
const int _kMaxCacheSize = 100;

/// A two-column lazy grid of PDF page thumbnails.
///
/// [ThumbnailGrid] fetches thumbnails on demand as cells scroll into view,
/// caches results in a bounded LRU map, and highlights the currently active
/// page with a coloured border. Tapping a thumbnail navigates to that page via
/// [ViewerController.setPage].
///
/// ## Accessibility
///
/// Each cell is wrapped in [Semantics] with `button: true` and a label built
/// from [pageLabelBuilder] (typically `l10n.thumbnailPageLabel(i + 1)`).
///
/// ## Memory
///
/// The cache is bounded to [_kMaxCacheSize] thumbnails. When the sidebar is
/// closed and the widget is disposed, all cached [ui.Image] objects are
/// disposed immediately.
///
/// ## Example
///
/// ```dart
/// ThumbnailGrid(
///   document: doc,
///   controller: controller,
///   pageCount: pageCount,
///   pageLabelBuilder: (i) => l10n.thumbnailPageLabel(i + 1),
/// )
/// ```
class ThumbnailGrid extends StatefulWidget {
  /// Creates a [ThumbnailGrid].
  ///
  /// [document], [controller], [pageCount], and [pageLabelBuilder] are required.
  const ThumbnailGrid({
    super.key,
    required this.document,
    required this.controller,
    required this.pageCount,
    required this.pageLabelBuilder,
    this.maxDimension = 160,
  });

  /// The PDF document whose pages are shown as thumbnails.
  final PdfDocument document;

  /// The controller that drives page navigation and reports the current page
  /// for active-cell highlighting.
  final ViewerController controller;

  /// Total number of pages in [document].
  final int pageCount;

  /// Builds the accessible label for the cell at zero-based index pageIndex.
  ///
  /// Example: `(i) => l10n.thumbnailPageLabel(i + 1)`.
  final String Function(int pageIndex) pageLabelBuilder;

  /// The maximum dimension (longest edge) for thumbnail rendering, in logical
  /// pixels. Multiplied by [MediaQuery.devicePixelRatioOf] before calling
  /// [PdfDocument.getThumbnail] for sharp high-DPI output.
  final int maxDimension;

  @override
  State<ThumbnailGrid> createState() => _ThumbnailGridState();
}

class _ThumbnailGridState extends State<ThumbnailGrid> {
  /// Decoded thumbnails keyed by zero-based page index.
  ///
  /// Values are [ui.Image] objects decoded from BGRA bytes. Limited to
  /// [_kMaxCacheSize] entries; oldest entries are evicted first.
  final Map<int, ui.Image> _cache = {};

  /// Insertion-order tracking for LRU eviction.
  final List<int> _cacheOrder = [];

  /// Pages currently being fetched — avoids duplicate concurrent requests.
  final Set<int> _inFlight = {};

  @override
  void didUpdateWidget(ThumbnailGrid old) {
    super.didUpdateWidget(old);
    if (old.document != widget.document) {
      _clearCache();
      _inFlight.clear();
    }
  }

  @override
  void dispose() {
    _clearCache();
    super.dispose();
  }

  void _clearCache() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _cacheOrder.clear();
  }

  Future<void> _fetchThumbnail(int pageIndex, double devicePixelRatio) async {
    if (_cache.containsKey(pageIndex) || _inFlight.contains(pageIndex)) return;
    _inFlight.add(pageIndex);

    try {
      final int maxDim = (widget.maxDimension * devicePixelRatio).round();
      final thumb = await widget.document.getThumbnail(
        pageIndex,
        maxDimension: maxDim,
      );
      if (!mounted) return;
      if (thumb == null) {
        _inFlight.remove(pageIndex);
        return;
      }

      // Decode raw BGRA pixels to a ui.Image via ImageDescriptor.raw.
      // Buffer and descriptor must stay alive until after getNextFrame() —
      // the descriptor holds a reference to the buffer's native memory.
      final buffer = await ui.ImmutableBuffer.fromUint8List(thumb.bgra);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: thumb.width,
        height: thumb.height,
        pixelFormat: ui.PixelFormat.bgra8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (!mounted) {
        frame.image.dispose();
        _inFlight.remove(pageIndex);
        return;
      }

      // Evict oldest entry if the cache is full.
      if (_cache.length >= _kMaxCacheSize && _cacheOrder.isNotEmpty) {
        final evictKey = _cacheOrder.removeAt(0);
        _cache.remove(evictKey)?.dispose();
      }

      setState(() {
        _cache[pageIndex] = frame.image;
        _cacheOrder.add(pageIndex);
        _inFlight.remove(pageIndex);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _inFlight.remove(pageIndex));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return GridView.builder(
          padding: const EdgeInsetsDirectional.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75, // approximate portrait A4
          ),
          itemCount: widget.pageCount,
          itemBuilder: (context, index) {
            // Trigger fetch on demand.
            if (!_cache.containsKey(index)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fetchThumbnail(index, dpr);
              });
            }

            return _ThumbnailCell(
              pageIndex: index,
              image: _cache[index],
              isLoading: _inFlight.contains(index),
              isActive: index == widget.controller.currentPage,
              label: widget.pageLabelBuilder(index),
              onTap: () =>
                  widget.controller.setPage(index, pageCount: widget.pageCount),
            );
          },
        );
      },
    );
  }
}

/// A single thumbnail cell in the grid.
class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({
    required this.pageIndex,
    required this.image,
    required this.isLoading,
    required this.isActive,
    required this.label,
    required this.onTap,
  });

  final int pageIndex;
  final ui.Image? image;
  final bool isLoading;
  final bool isActive;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final placeholderColor = colors.onSecondary;
    final activeAccent = colors.surfaceContainerHighest;
    final inactiveBorder = colors.surfaceContainerLowest;

    Widget content;
    if (image != null) {
      content = RawImage(
        image: image,
        fit: BoxFit.contain,
        width: double.infinity,
      );
    } else {
      // Placeholder while loading.
      content = ColoredBox(color: placeholderColor);
    }

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? activeAccent : inactiveBorder,
                    width: isActive ? 1.5 : 1.0,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: content,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('${pageIndex + 1}', style: textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
