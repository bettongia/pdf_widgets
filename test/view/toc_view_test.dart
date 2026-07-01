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

// Widget tests for PdfTocView.

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  const emptyText = 'No table of contents';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  PdfTocEntry entry(
    String title, {
    int? pageIndex,
    List<PdfTocEntry> children = const [],
  }) {
    return PdfTocEntry(title: title, pageIndex: pageIndex, children: children);
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  testWidgets('shows emptyText when entries list is empty', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        TocView(
          entries: const [],
          controller: controller,
          pageCount: 10,
          emptyText: emptyText,
        ),
      ),
    );

    expect(find.text(emptyText), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Rendering entries
  // ---------------------------------------------------------------------------

  testWidgets('renders root-level entry titles and page numbers', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final entries = [
      entry('Introduction', pageIndex: 0),
      entry('Chapter 1', pageIndex: 5),
    ];

    await tester.pumpWidget(
      wrap(
        TocView(
          entries: entries,
          controller: controller,
          pageCount: 20,
          emptyText: emptyText,
        ),
      ),
    );

    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    // Page numbers (1-based display)
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('renders nested child entries', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final entries = [
      entry(
        'Part One',
        pageIndex: 0,
        children: [
          entry('Section 1.1', pageIndex: 1),
          entry('Section 1.2', pageIndex: 3),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(
        TocView(
          entries: entries,
          controller: controller,
          pageCount: 20,
          emptyText: emptyText,
        ),
      ),
    );

    expect(find.text('Part One'), findsOneWidget);
    expect(find.text('Section 1.1'), findsOneWidget);
    expect(find.text('Section 1.2'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Tap navigation
  // ---------------------------------------------------------------------------

  testWidgets(
    'tapping an entry with pageIndex updates controller.currentPage',
    (tester) async {
      final controller = ViewerController();
      addTearDown(controller.dispose);

      final entries = [entry('Chapter 2', pageIndex: 7)];

      await tester.pumpWidget(
        wrap(
          TocView(
            entries: entries,
            controller: controller,
            pageCount: 20,
            emptyText: emptyText,
          ),
        ),
      );

      await tester.tap(find.text('Chapter 2'));
      await tester.pump();

      expect(controller.currentPage, 7);
    },
  );

  // ---------------------------------------------------------------------------
  // Non-interactive section labels
  // ---------------------------------------------------------------------------

  testWidgets('section-label entry (pageIndex null) is not tappable', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final entries = [
      entry('Appendix', pageIndex: null), // section label, no pageIndex
    ];

    await tester.pumpWidget(
      wrap(
        TocView(
          entries: entries,
          controller: controller,
          pageCount: 20,
          emptyText: emptyText,
        ),
      ),
    );

    expect(find.text('Appendix'), findsOneWidget);
    // No InkWell for non-interactive rows.
    expect(find.byType(InkWell), findsNothing);
    // currentPage unchanged.
    await tester.tap(find.text('Appendix'), warnIfMissed: false);
    await tester.pump();
    expect(controller.currentPage, 0);
  });

  // ---------------------------------------------------------------------------
  // Accessibility
  // ---------------------------------------------------------------------------

  testWidgets('interactive rows have Semantics button label', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final entries = [entry('Overview', pageIndex: 2)];

    await tester.pumpWidget(
      wrap(
        TocView(
          entries: entries,
          controller: controller,
          pageCount: 10,
          emptyText: emptyText,
        ),
      ),
    );

    final semantics = tester.getSemantics(find.text('Overview'));
    expect(semantics.label, contains('Overview'));
    expect(semantics.label, contains('3')); // page 2 → displayed as 3
  });

  testWidgets('satisfies labeledTapTargetGuideline', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(
        TocView(
          entries: [entry('Chapter 1', pageIndex: 0)],
          controller: controller,
          pageCount: 5,
          emptyText: emptyText,
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
