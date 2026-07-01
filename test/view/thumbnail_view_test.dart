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

// Widget tests for PdfThumbnailGrid.
//
// These tests are fully hermetic — they use MockPdfDocument and do not require
// the PDFium dylib to be present.  getThumbnail is stubbed to return null
// (no embedded thumbnail, no generate fallback) which causes each cell to
// show its loading/placeholder state.  The tests verify grid structure,
// page navigation on tap, and accessibility guidelines.

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_view_test.mocks.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 600, child: w)),
  );

  late MockPdfDocument mockDoc;
  late ViewerController controller;

  setUp(() {
    mockDoc = MockPdfDocument();
    controller = ViewerController();
    // The generated mock's getThumbnail has returnValueForMissingStub of null,
    // so unstubbed calls return null without throwing MissingStubError.
  });

  tearDown(() {
    controller.dispose();
  });

  ThumbnailGrid buildGrid({int pageCount = 5}) {
    return ThumbnailGrid(
      document: mockDoc,
      controller: controller,
      pageCount: pageCount,
      pageLabelBuilder: (i) => 'Page ${i + 1}',
    );
  }

  // -------------------------------------------------------------------------
  // Grid renders the expected number of cells
  // -------------------------------------------------------------------------

  testWidgets('renders pageCount cells in the grid', (tester) async {
    await tester.pumpWidget(wrap(buildGrid(pageCount: 4)));
    await tester.pump(); // allow post-frame callbacks

    // With pageCount=4 there should be 4 cells showing numeric page labels.
    // _ThumbnailCell displays the 1-based page number as a string.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('renders zero cells for pageCount=0', (tester) async {
    await tester.pumpWidget(wrap(buildGrid(pageCount: 0)));
    await tester.pump();

    expect(find.text('Page 1'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Tapping a cell updates the controller's currentPage
  // -------------------------------------------------------------------------

  testWidgets('tapping a cell sets controller.currentPage', (tester) async {
    await tester.pumpWidget(wrap(buildGrid(pageCount: 3)));
    await tester.pump();

    // Tap cell 2 (displays '2', index 1).
    await tester.tap(find.text('2'));
    await tester.pump();

    expect(controller.currentPage, 1);
  });

  testWidgets('tapping first cell sets currentPage to 0', (tester) async {
    // Pre-set page to something other than 0.
    controller.setPage(2, pageCount: 4);

    await tester.pumpWidget(wrap(buildGrid(pageCount: 4)));
    await tester.pump();

    // Tap cell 1 (displays '1', index 0).
    await tester.tap(find.text('1'));
    await tester.pump();

    expect(controller.currentPage, 0);
  });

  // -------------------------------------------------------------------------
  // Accessibility
  // -------------------------------------------------------------------------

  testWidgets('cells have accessible button Semantics with page label', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildGrid(pageCount: 2)));
    await tester.pump();

    // Each cell exposes Semantics with button=true and a label containing
    // the page number. The visible text is the numeric label ('1'); the
    // Semantics label is the full string from pageLabelBuilder ('Page 1').
    final semanticsPage1 = tester.getSemantics(find.text('1').first);
    expect(semanticsPage1.label, contains('Page 1'));
  });

  testWidgets('satisfies labeledTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(buildGrid(pageCount: 2)));
    await tester.pump();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('satisfies iOSTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(buildGrid(pageCount: 2)));
    await tester.pump();

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('satisfies androidTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(buildGrid(pageCount: 2)));
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  // -------------------------------------------------------------------------
  // Controller state changes
  // -------------------------------------------------------------------------

  testWidgets('controller page change triggers rebuild', (tester) async {
    await tester.pumpWidget(wrap(buildGrid(pageCount: 3)));
    await tester.pump();

    // No explicit visual assertion — just verify no exceptions on rebuild.
    controller.setPage(1, pageCount: 3);
    await tester.pump();
    // Still shows the same cells.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // didUpdateWidget — document change clears cache
  // -------------------------------------------------------------------------

  testWidgets('document change clears thumbnail cache without error', (
    tester,
  ) async {
    final mockDoc2 = MockPdfDocument();
    final controller2 = ViewerController();
    addTearDown(controller2.dispose);

    Widget buildWith(MockPdfDocument doc, ViewerController ctrl) => wrap(
      ThumbnailGrid(
        document: doc,
        controller: ctrl,
        pageCount: 3,
        pageLabelBuilder: (i) => 'Page ${i + 1}',
      ),
    );

    await tester.pumpWidget(buildWith(mockDoc, controller));
    await tester.pump();

    // Switch to a different document — triggers didUpdateWidget.
    await tester.pumpWidget(buildWith(mockDoc2, controller2));
    await tester.pump();

    // Grid still renders the same number of cells for the new document.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
