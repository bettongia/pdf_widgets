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

// Widget tests for PdfAnnotationView.

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  const noteLabel = 'Note';
  const highlightLabel = 'Highlight';
  const noneFoundText = 'No annotations found';
  const toggleOnLabel = 'Hide annotations in PDF';
  const toggleOffLabel = 'Show annotations in PDF';

  String totalLabel(int count) => '$count annotations';

  AnnotationView buildView({
    required List<PdfPageAnnotations> annotations,
    required ViewerController controller,
  }) {
    return AnnotationView(
      annotations: annotations,
      controller: controller,
      noteLabel: noteLabel,
      highlightLabel: highlightLabel,
      totalLabel: totalLabel,
      noneFoundText: noneFoundText,
      toggleOnLabel: toggleOnLabel,
      toggleOffLabel: toggleOffLabel,
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  testWidgets('shows noneFoundText when no note/highlight annotations', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    // PdfLinkAnnotation is not a Note or Highlight — should be filtered out.
    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfLinkAnnotation(pageIndex: 0, uri: 'https://example.com', flags: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );

    expect(find.text(noneFoundText), findsOneWidget);
  });

  testWidgets('shows noneFoundText when annotations list is empty', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(buildView(annotations: const [], controller: controller)),
    );

    expect(find.text(noneFoundText), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Note annotations
  // ---------------------------------------------------------------------------

  testWidgets('renders PdfTextAnnotation as Note card', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfTextAnnotation(pageIndex: 0, contents: 'This is a note', flags: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    expect(find.text(noteLabel), findsOneWidget);
    expect(find.text('This is a note'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Highlight annotations
  // ---------------------------------------------------------------------------

  testWidgets('renders PdfMarkupAnnotation highlight card', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 2,
        annotations: [
          PdfMarkupAnnotation(
            pageIndex: 2,
            subtype: PdfAnnotationType.highlight,
            quadPoints: [],
            markedText: 'highlighted text',
            flags: 0,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    expect(find.text(highlightLabel), findsOneWidget);
    expect(find.text('highlighted text'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  testWidgets('filters out non-Note non-Highlight annotation types', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfLinkAnnotation(pageIndex: 0, uri: 'https://example.com', flags: 0),
          PdfTextAnnotation(pageIndex: 0, contents: 'A note', flags: 0),
          PdfMarkupAnnotation(
            pageIndex: 0,
            subtype: PdfAnnotationType.underline, // not highlight
            quadPoints: [],
            flags: 0,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    // Only the note should appear.
    expect(find.text(noteLabel), findsOneWidget);
    expect(find.text(highlightLabel), findsNothing);
    expect(find.text(noneFoundText), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Toggle
  // ---------------------------------------------------------------------------

  testWidgets('toggle switch updates controller.renderAnnotations', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfTextAnnotation(pageIndex: 0, contents: 'A note', flags: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    expect(controller.renderAnnotations, isTrue);

    // Find the Switch widget and toggle it.
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.renderAnnotations, isFalse);
  });

  // ---------------------------------------------------------------------------
  // Date formatting — must use intl.DateFormat, not .toString()
  // ---------------------------------------------------------------------------

  testWidgets('formats modifiedDate via DateFormat (not raw toString)', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final dt = DateTime.utc(2024, 6, 15);
    final annotations = [
      PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfTextAnnotation(
            pageIndex: 0,
            contents: 'Dated note',
            modifiedDate: PdfDate(raw: 'D:20240615', value: dt),
            flags: 0,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    // The date should appear in a human-readable format, not as a DateTime
    // toString like "2024-06-15 00:00:00.000Z".
    expect(find.textContaining('2024-06-15 00:00:00'), findsNothing);
    // Should find something like "Jun 15, 2024".
    expect(find.textContaining('2024'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Accessibility
  // ---------------------------------------------------------------------------

  testWidgets('annotation cards have semantic button labels', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 3,
        annotations: [
          PdfTextAnnotation(
            pageIndex: 3,
            contents: 'My note content',
            flags: 0,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    final semantics = tester.getSemantics(find.text('My note content'));
    expect(semantics.label, contains('Annotation on page 4'));
  });

  testWidgets('satisfies labeledTapTargetGuideline', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final handle = tester.ensureSemantics();

    final annotations = [
      const PdfPageAnnotations(
        pageIndex: 0,
        annotations: [
          PdfTextAnnotation(pageIndex: 0, contents: 'Note', flags: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      wrap(buildView(annotations: annotations, controller: controller)),
    );
    await tester.pump();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
