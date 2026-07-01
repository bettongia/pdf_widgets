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

// Widget tests for PdfDocumentInfoView.

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  const labels = DocumentInfoLabels(
    title: 'Title',
    author: 'Author',
    subject: 'Subject',
    keywords: 'Keywords',
    creator: 'Creator',
    producer: 'Producer',
    creationDate: 'Created',
    modDate: 'Modified',
    fileName: 'File name',
    filePath: 'Location',
    fileSize: 'File size',
    pageCount: 'Pages',
    pdfVersion: 'PDF version',
    fsCreated: 'Created on disk',
    fsModified: 'Modified on disk',
  );

  const docInfo = PdfDocumentInfo(fileVersion: 17);

  // ---------------------------------------------------------------------------
  // Present fields are displayed
  // ---------------------------------------------------------------------------

  testWidgets('displays title, author, subject when present', (tester) async {
    final metadata = PdfMetadata(
      title: 'My Great Report',
      author: 'Alice Smith',
      subject: 'Quarterly Review',
    );

    await tester.pumpWidget(
      wrap(InfoView(metadata: metadata, docInfo: docInfo, labels: labels)),
    );

    expect(find.text('My Great Report'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Quarterly Review'), findsOneWidget);
  });

  testWidgets('displays PDF version formatted as major.minor', (tester) async {
    // fileVersion 17 → "1.7"
    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(),
          docInfo: const PdfDocumentInfo(fileVersion: 17),
          labels: labels,
        ),
      ),
    );

    expect(find.text('PDF 1.7'), findsOneWidget);
  });

  testWidgets('displays page count', (tester) async {
    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(),
          docInfo: docInfo,
          labels: labels,
          pageCount: 42,
        ),
      ),
    );

    expect(find.text('42'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Missing fields are omitted
  // ---------------------------------------------------------------------------

  testWidgets('omits null metadata fields', (tester) async {
    // All metadata fields null.
    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(),
          docInfo: const PdfDocumentInfo(),
          labels: labels,
        ),
      ),
    );

    // The label widgets should not appear when the value is absent.
    expect(find.text('Title'), findsNothing);
    expect(find.text('Author'), findsNothing);
    // Shows placeholder dash.
    expect(find.text('—'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // File size formatting
  // ---------------------------------------------------------------------------

  testWidgets('formats file size in MB not raw bytes', (tester) async {
    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(title: 'Doc'),
          docInfo: docInfo,
          labels: labels,
          fileSizeBytes: 2 * 1024 * 1024, // 2 MB exactly
        ),
      ),
    );

    // Should display "2 MB", not "2097152".
    expect(find.textContaining('2097152'), findsNothing);
    expect(find.textContaining('MB'), findsOneWidget);
  });

  testWidgets('formats file size in KB for small files', (tester) async {
    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(title: 'Doc'),
          docInfo: docInfo,
          labels: labels,
          fileSizeBytes: 512 * 1024, // 512 KB
        ),
      ),
    );

    expect(find.textContaining('512'), findsOneWidget);
    expect(find.textContaining('KB'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Date formatting
  // ---------------------------------------------------------------------------

  testWidgets('formats creationDate via DateFormat not toString', (
    tester,
  ) async {
    final dt = DateTime.utc(2023, 3, 15);
    final metadata = PdfMetadata(
      title: 'Doc',
      creationDate: PdfDate(raw: 'D:20230315', value: dt),
    );

    await tester.pumpWidget(
      wrap(InfoView(metadata: metadata, docInfo: docInfo, labels: labels)),
    );

    // Should NOT show DateTime.toString() format like "2023-03-15 00:00:00.000Z"
    expect(find.textContaining('00:00:00'), findsNothing);
    // Should show a human-readable format containing "2023".
    expect(find.textContaining('2023'), findsOneWidget);
  });

  testWidgets('omits creationDate when PdfDate.value is null', (tester) async {
    final metadata = PdfMetadata(
      title: 'Doc',
      creationDate: const PdfDate(raw: 'invalid', value: null),
    );

    await tester.pumpWidget(
      wrap(InfoView(metadata: metadata, docInfo: docInfo, labels: labels)),
    );

    // 'Created' label should not appear since value is null.
    expect(find.text('Created'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // File info fields
  // ---------------------------------------------------------------------------

  testWidgets('displays file name from filePath', (tester) async {
    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(title: 'Doc'),
          docInfo: docInfo,
          labels: labels,
          filePath: '/Users/alice/documents/report.pdf',
        ),
      ),
    );

    expect(find.text('report.pdf'), findsOneWidget);
  });

  testWidgets('displays fs created and modified dates', (tester) async {
    final created = DateTime(2024, 1, 10);
    final modified = DateTime(2024, 6, 20);

    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(title: 'Doc'),
          docInfo: docInfo,
          labels: labels,
          fsCreated: created,
          fsModified: modified,
        ),
      ),
    );

    expect(find.text('Created on disk'), findsOneWidget);
    expect(find.text('Modified on disk'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Accessibility
  // ---------------------------------------------------------------------------

  testWidgets('satisfies labeledTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(
        InfoView(
          metadata: const PdfMetadata(title: 'Test'),
          docInfo: docInfo,
          labels: labels,
          pageCount: 10,
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
