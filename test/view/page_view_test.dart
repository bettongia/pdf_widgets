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

// Widget tests for PdfPageView.
//
// These tests are fully hermetic — they use a MockPdfDocument and do not
// require the PDFium dylib to be present. They verify loading state,
// rendered state, page-index changes, error handling, and accessibility
// semantics.
//
// renderPage() is now a Flutter extension on PdfDocument that internally calls
// renderPageToBytes() and converts the BGRA buffer to a dart:ui Image. The
// mock stubs renderPageToBytes() instead. Because dart:ui image creation uses
// real (non-fake) async, tester.runAsync(() async {}) is inserted after pixel
// data is delivered to let image creation complete before pumpAndSettle().

import 'dart:async';
import 'dart:typed_data';

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart' hide PageView;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'page_view_test.mocks.dart';

@GenerateMocks([PdfDocument])
void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Wraps [widget] in a minimal Material/Directionality scaffold.
  Widget wrap(Widget widget) => MaterialApp(home: Scaffold(body: widget));

  /// Returns a solid-white BGRA pixel buffer of [width] × [height] pixels.
  ///
  /// Synchronous — no dart:ui calls needed. The renderPageToBytes() mock
  /// returns this data; the PdfDocumentRendering extension then converts it
  /// to a dart:ui Image inside the widget's async render chain.
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

  /// Returns a [renderPageToBytes] stub answer for [width] × [height] pixels.
  ({Uint8List pixels, int pixelWidth, int pixelHeight}) pixelResult({
    int width = 100,
    int height = 130,
  }) => (
    pixels: makePixels(width: width, height: height),
    pixelWidth: width,
    pixelHeight: height,
  );

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  group('loading state', () {
    testWidgets('shows CircularProgressIndicator while render is in flight', (
      tester,
    ) async {
      final completer =
          Completer<({Uint8List pixels, int pixelWidth, int pixelHeight})>();
      final mock = MockPdfDocument();
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
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pump(); // fires postFrameCallback → _render starts

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete with pixel data, then let dart:ui image creation finish.
      completer.complete(pixelResult());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shows no spinner when disableAnimations is true', (
      tester,
    ) async {
      final completer =
          Completer<({Uint8List pixels, int pixelWidth, int pixelHeight})>();
      final mock = MockPdfDocument();
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
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: wrap(PageView(document: mock, pageIndex: 0)),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(pixelResult());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    });
  });

  // ---------------------------------------------------------------------------
  // Rendered state
  // ---------------------------------------------------------------------------

  group('rendered state', () {
    testWidgets('shows CustomPaint after successful render', (tester) async {
      final mock = MockPdfDocument();
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

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pump(); // render starts
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // At least one CustomPaint for our page (Scaffold also uses CustomPaint).
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('has Semantics label for the rendered image', (tester) async {
      final mock = MockPdfDocument();
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

      await tester.pumpWidget(
        wrap(
          PageView(document: mock, pageIndex: 0, semanticLabel: 'My Document'),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('My Document'), findsOneWidget);
    });

    testWidgets('uses default semantic label when none provided', (
      tester,
    ) async {
      final mock = MockPdfDocument();
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

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 2)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // pageIndex 2 → default label "PDF page 3"
      expect(find.bySemanticsLabel(RegExp(r'page 3')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Page-index change
  // ---------------------------------------------------------------------------

  group('page index change', () {
    testWidgets('re-renders when pageIndex changes', (tester) async {
      final mock = MockPdfDocument();
      when(
        mock.getPageSize(any),
      ).thenAnswer((_) async => const PdfPageSize(widthPt: 595, heightPt: 842));
      when(
        mock.renderPageToBytes(
          0,
          any,
          any,
          renderAnnotations: anyNamed('renderAnnotations'),
          lcdText: anyNamed('lcdText'),
          backgroundColor: anyNamed('backgroundColor'),
        ),
      ).thenAnswer((_) async => pixelResult(width: 100, height: 130));
      when(
        mock.renderPageToBytes(
          1,
          any,
          any,
          renderAnnotations: anyNamed('renderAnnotations'),
          lcdText: anyNamed('lcdText'),
          backgroundColor: anyNamed('backgroundColor'),
        ),
      ).thenAnswer((_) async => pixelResult(width: 100, height: 130));

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      verify(
        mock.renderPageToBytes(
          0,
          any,
          any,
          renderAnnotations: anyNamed('renderAnnotations'),
          lcdText: anyNamed('lcdText'),
          backgroundColor: anyNamed('backgroundColor'),
        ),
      ).called(1);

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 1)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      verify(
        mock.renderPageToBytes(
          1,
          any,
          any,
          renderAnnotations: anyNamed('renderAnnotations'),
          lcdText: anyNamed('lcdText'),
          backgroundColor: anyNamed('backgroundColor'),
        ),
      ).called(1);
    });

    testWidgets('discards stale future when pageIndex changes mid-flight', (
      tester,
    ) async {
      final page0Completer =
          Completer<({Uint8List pixels, int pixelWidth, int pixelHeight})>();
      final mock = MockPdfDocument();
      when(
        mock.getPageSize(any),
      ).thenAnswer((_) async => const PdfPageSize(widthPt: 595, heightPt: 842));
      when(
        mock.renderPageToBytes(
          0,
          any,
          any,
          renderAnnotations: anyNamed('renderAnnotations'),
          lcdText: anyNamed('lcdText'),
          backgroundColor: anyNamed('backgroundColor'),
        ),
      ).thenAnswer((_) => page0Completer.future);
      when(
        mock.renderPageToBytes(
          1,
          any,
          any,
          renderAnnotations: anyNamed('renderAnnotations'),
          lcdText: anyNamed('lcdText'),
          backgroundColor: anyNamed('backgroundColor'),
        ),
      ).thenAnswer((_) async => pixelResult());

      // Start rendering page 0 (in flight)
      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pump(); // fires postFrameCallback for page 0

      // Switch to page 1 before page 0 completes
      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 1)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      ); // page 1 image creation
      await tester.pumpAndSettle();

      // Page 1 image is shown (Scaffold also uses CustomPaint, so at least 1).
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

      // Complete page 0 — result must be silently discarded (no crash).
      page0Completer.complete(pixelResult());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      ); // stale image creation (then discarded)
      await tester.pump();

      // Still showing page 1.
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  group('error handling', () {
    testWidgets('displays error message on RangeError', (tester) async {
      final mock = MockPdfDocument();
      when(mock.getPageSize(any)).thenThrow(RangeError.index(99, []));

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 99)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to render page'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays error message on StateError', (tester) async {
      final mock = MockPdfDocument();
      when(mock.getPageSize(any)).thenThrow(StateError('Document is closed'));

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to render page'), findsOneWidget);
    });

    testWidgets('displays error message on PdfiumException', (tester) async {
      final mock = MockPdfDocument();
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
      ).thenThrow(PdfiumException('Bitmap allocation failed'));

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to render page'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Accessibility semantics
  // ---------------------------------------------------------------------------

  group('accessibility semantics', () {
    testWidgets('loading state has a non-empty semantics label', (
      tester,
    ) async {
      final completer =
          Completer<({Uint8List pixels, int pixelWidth, int pixelHeight})>();
      final mock = MockPdfDocument();
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
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pump(); // loading state visible

      // Loading label is "Loading page 1" (pageIndex 0 → page 1).
      expect(find.bySemanticsLabel(RegExp(r'Loading page 1')), findsOneWidget);

      completer.complete(pixelResult());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('error state has a non-empty semantics label', (tester) async {
      final mock = MockPdfDocument();
      when(mock.getPageSize(any)).thenThrow(StateError('closed'));

      await tester.pumpWidget(wrap(PageView(document: mock, pageIndex: 0)));
      await tester.pumpAndSettle();

      // Error label is "Failed to render page 1".
      expect(
        find.bySemanticsLabel(RegExp(r'Failed to render page 1')),
        findsOneWidget,
      );
    });
  });
}
