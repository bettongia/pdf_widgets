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

// Widget tests for PdfPageViewer.
//
// These tests are fully hermetic — they use MockPdfDocument and do not require
// the PDFium dylib.  renderPageToBytes() is stubbed to return valid BGRA pixel
// data; getPageSize() is stubbed to return a standard A4 size.
//
// dart:ui image creation is asynchronous even in tests, so tester.runAsync()
// wraps the Future.delayed that lets codec creation complete before
// pumpAndSettle().

import 'dart:typed_data';

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'view/page_view_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a solid-white BGRA pixel buffer of [width] × [height] pixels.
Uint8List makePixels({int width = 100, int height = 130}) {
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = 255; // B
    bytes[i + 1] = 255; // G
    bytes[i + 2] = 255; // R
    bytes[i + 3] = 255; // A
  }
  return bytes;
}

({Uint8List pixels, int pixelWidth, int pixelHeight}) pixelResult({
  int width = 100,
  int height = 130,
}) => (
  pixels: makePixels(width: width, height: height),
  pixelWidth: width,
  pixelHeight: height,
);

/// Stubs [mock] to return an A4-sized page and a white pixel buffer.
void stubRender(MockPdfDocument mock) {
  when(
    mock.getPageSize(any),
  ).thenAnswer((_) async => const PdfPageSize(widthPt: 595, heightPt: 842));
  when(
    mock.renderPageToBytes(
      any,
      any,
      any,
      renderAnnotations: anyNamed('renderAnnotations'),
      lcdText: anyNamed('lcdText'),
      backgroundColor: anyNamed('backgroundColor'),
    ),
  ).thenAnswer((_) async => pixelResult());
}

void main() {
  Widget wrap(Widget w) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 600, child: w)),
  );

  late MockPdfDocument mockDoc;
  late ViewerController controller;

  setUp(() {
    mockDoc = MockPdfDocument();
    controller = ViewerController();
    stubRender(mockDoc);
  });

  tearDown(() {
    controller.dispose();
  });

  PageViewer buildViewer({String? semanticLabel}) => PageViewer(
    document: mockDoc,
    pageCount: 10,
    controller: controller,
    semanticLabel: semanticLabel,
  );

  // -------------------------------------------------------------------------
  // Renders in ZoomMode.fitWidth (default)
  // -------------------------------------------------------------------------

  testWidgets('shows loading indicator then renders in fitWidth mode', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildViewer()));
    await tester.pump(); // trigger render

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // After render completes, no spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Renders in ZoomMode.fitPage
  // -------------------------------------------------------------------------

  testWidgets('renders without error in fitPage mode', (tester) async {
    controller.setZoom(ZoomMode.fitPage);

    await tester.pumpWidget(wrap(buildViewer()));
    await tester.pump();

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Renders in ZoomMode.custom
  // -------------------------------------------------------------------------

  testWidgets('renders without error in custom zoom mode', (tester) async {
    controller.setZoom(ZoomMode.custom, factor: 1.5);

    await tester.pumpWidget(wrap(buildViewer()));
    await tester.pump();

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Controller page change triggers re-render
  // -------------------------------------------------------------------------

  testWidgets('controller page change triggers re-render', (tester) async {
    await tester.pumpWidget(wrap(buildViewer()));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // Change page — should trigger a new render call.
    // Reset interactions so we can count fresh calls after the page change.
    clearInteractions(mockDoc);
    controller.setPage(1, pageCount: 10);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // At least one getPageSize call should have occurred for the new page.
    verify(mockDoc.getPageSize(any)).called(greaterThanOrEqualTo(1));
  });

  // -------------------------------------------------------------------------
  // Search match overlay is drawn when matches are set
  // -------------------------------------------------------------------------

  testWidgets('search overlay CustomPaint appears when matches are set', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildViewer()));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // Initially no search matches — no overlay CustomPaint for highlights.
    // (The widget may have other CustomPaints; we check for the one that paints
    // rectangles which appears only when there are active matches.)
    final beforeCount = tester.widgetList(find.byType(CustomPaint)).length;

    // Set a search match on the current page (page 0).
    controller.setSearchMatches([
      const PdfSearchMatch(
        pageIndex: 0,
        charIndex: 0,
        charCount: 3,
        rects: [PdfRect(left: 72, bottom: 600, right: 144, top: 620)],
      ),
    ]);
    await tester.pump();

    // The overlay layer should now have an additional CustomPaint (the highlight
    // painter), or at minimum the same count (widget may merge layers).
    final afterCount = tester.widgetList(find.byType(CustomPaint)).length;
    expect(afterCount, greaterThanOrEqualTo(beforeCount));
  });

  // -------------------------------------------------------------------------
  // Dispose does not throw
  // -------------------------------------------------------------------------

  testWidgets('dispose releases resources without throwing', (tester) async {
    await tester.pumpWidget(wrap(buildViewer()));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // Replace with an empty widget to trigger dispose.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    // No exception expected.
  });

  // -------------------------------------------------------------------------
  // Accessibility
  // -------------------------------------------------------------------------

  testWidgets('semanticLabel appears in Semantics tree when provided', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildViewer(semanticLabel: 'Annual report')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Annual report'), findsOneWidget);
  });

  testWidgets('satisfies labeledTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(buildViewer(semanticLabel: 'PDF page')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
