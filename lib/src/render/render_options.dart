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

import 'dart:ui' show Color;

/// Options controlling how a PDF page is rendered by PDFium.
///
/// Pass a [RenderOptions] instance to [PdfDocument.renderPage] to control
/// annotation visibility, text rendering quality, and background colour.
///
/// The caller controls output resolution by providing explicit pixel dimensions
/// ([pixelWidth] and [pixelHeight] on the [PdfDocument.renderPage] call).
/// Zoom and scale are deferred to a future phase as a [PageViewer]-level
/// concern.
///
/// ## Example
///
/// ```dart
/// final image = await doc.renderPage(
///   0, 1200, 1600,
///   options: RenderOptions(renderAnnotations: false),
/// );
/// ```
class RenderOptions {
  /// Creates [RenderOptions] with the given settings.
  ///
  /// All parameters have sensible defaults: annotations rendered, LCD text
  /// disabled, white background.
  const RenderOptions({
    this.renderAnnotations = true,
    this.lcdText = false,
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  /// Whether to render annotations on top of the page content.
  ///
  /// Maps to the PDFium `FPDF_ANNOT` render flag when `true`.
  /// Defaults to `true`.
  final bool renderAnnotations;

  /// Whether to use sub-pixel (LCD) text rendering.
  ///
  /// Maps to the PDFium `FPDF_LCD_TEXT` render flag when `true`. Produces
  /// sharper text on LCD screens but may cause colour fringing artefacts on
  /// non-LCD displays or when the rendered image is used as a texture.
  /// Defaults to `false`.
  final bool lcdText;

  /// The background colour to fill the bitmap before rendering.
  ///
  /// Defaults to opaque white (`Color(0xFFFFFFFF)`).
  ///
  /// Note: PDFium's `FPDFBitmap_FillRect` accepts a colour in `0xAARRGGBB`
  /// format. This field uses `dart:ui Color` for interoperability with
  /// Flutter widgets; the conversion to the PDFium integer format is handled
  /// internally in the rendering pipeline.
  final Color backgroundColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderOptions &&
          other.renderAnnotations == renderAnnotations &&
          other.lcdText == lcdText &&
          other.backgroundColor == backgroundColor;

  @override
  int get hashCode => Object.hash(renderAnnotations, lcdText, backgroundColor);

  @override
  String toString() =>
      'PdfRenderOptions('
      'renderAnnotations: $renderAnnotations, '
      'lcdText: $lcdText, '
      'backgroundColor: $backgroundColor)';
}
