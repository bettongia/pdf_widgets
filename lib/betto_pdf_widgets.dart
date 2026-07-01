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

/// Flutter entry point for betto_pdf_widgets.
///
/// ## Quick start
///
/// ```dart
/// import 'package:betto_pdfium/betto_pdfium.dart';
///
/// final bytes = await File('document.pdf').readAsBytes();
/// final doc = await PdfDocument.fromBytes(bytes);
/// try {
///   final meta = await doc.getMetadata();
///   print(meta.title);
///   // Render the first page at 150 DPI:
///   final size = await doc.getPageSize(0);
///   final px = size.sizeForDpi(150);
///   final image = await doc.renderPage(0, px.width.round(), px.height.round());
/// } finally {
///   await doc.close();
/// }
/// ```
library;

export 'src/view/page_view.dart';
export 'src/viewer_controller.dart';
export 'src/page_viewer.dart';
export 'src/view/toc_view.dart';
export 'src/view/thumbnail_view.dart';
export 'src/view/annotation_view.dart';
export 'src/view/search_view.dart';
export 'src/view/info_view.dart';

export 'package:betto_pdfium/betto_pdfium.dart';
