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

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:betto_pdfium/betto_pdfium.dart';

import 'render_options.dart';

/// Flutter rendering extension for [PdfDocument].
///
/// Provides [renderPage], which converts the raw BGRA pixel buffer from
/// [PdfDocument.renderPageToBytes] into a [ui.Image].
///
/// ## Example
///
/// ```dart
/// final size = await doc.getPageSize(0);
/// final px = size.sizeForDpi(150);
/// final image = await doc.renderPage(
///   0,
///   px.width.round(),
///   px.height.round(),
/// );
/// ```
extension DocumentRendering on PdfDocument {
  /// Renders a page to a [dart:ui] [ui.Image].
  ///
  /// The page at [pageIndex] is rendered at [pixelWidth] × [pixelHeight]
  /// pixels. For sharp output on high-DPI displays, multiply the widget's
  /// logical width by `MediaQuery.devicePixelRatio` before passing
  /// [pixelWidth] and [pixelHeight].
  ///
  /// The optional [options] control annotation visibility, sub-pixel text
  /// rendering, and background colour. See [RenderOptions] for defaults.
  ///
  /// The returned [ui.Image] is owned by the caller and must be disposed
  /// by calling [ui.Image.dispose] when it is no longer needed.
  ///
  /// Throws [RangeError] if [pageIndex] is out of range.
  /// Throws [StateError] if [close] has been called before or during the
  /// render.
  /// Throws [PdfiumException] if a PDFium native call fails unexpectedly.
  Future<ui.Image> renderPage(
    int pageIndex,
    int pixelWidth,
    int pixelHeight, {
    RenderOptions options = const RenderOptions(),
  }) async {
    final result = await renderPageToBytes(
      pageIndex,
      pixelWidth,
      pixelHeight,
      renderAnnotations: options.renderAnnotations,
      lcdText: options.lcdText,
      backgroundColor: options.backgroundColor.toARGB32(),
    );
    return _pixelsToImage(result.pixels, result.pixelWidth, result.pixelHeight);
  }
}

/// Converts a raw BGRA pixel buffer to a [ui.Image].
///
/// Uses the fully async ImmutableBuffer → ImageDescriptor → codec path, which
/// is safe to call from any isolate and does not block the UI thread.
Future<ui.Image> _pixelsToImage(Uint8List pixels, int width, int height) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}
