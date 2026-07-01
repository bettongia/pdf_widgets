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

// Widget tests for PdfSearchView.
//
// These tests use MockPdfDocument from pdf_page_view_test.mocks.dart to stub
// document.search() and document.extractPlainText(). The mock's search method
// has a generated default returnValue of Stream.empty(), so unstubbed calls
// return an empty stream rather than throwing MissingStubError.

import 'dart:async';

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'page_view_test.mocks.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  late MockPdfDocument mockDoc;
  late ViewerController controller;

  setUp(() {
    mockDoc = MockPdfDocument();
    controller = ViewerController();
    // The mock's search method has a generated default returnValue of
    // Stream.empty(), so unstubbed calls return an empty stream rather than
    // throwing MissingStubError.
  });

  tearDown(() {
    controller.dispose();
  });

  /// Stubs [mockDoc.search] so that calls with [query] return [stream].
  ///
  /// Mockito's argThat / any helpers cannot be used with non-nullable
  /// positional parameters in null-safe Dart — they return Null which fails
  /// the type checker.  Instead, we stub with the exact string the widget
  /// will pass, which is whatever the user typed.
  void stubSearch(String query, Stream<PdfSearchMatch> stream) {
    when(mockDoc.search(query)).thenAnswer((_) => stream);
  }

  SearchView buildView({int minQueryLength = 3}) {
    return SearchView(
      document: mockDoc,
      controller: controller,
      hintText: 'Search document…',
      clearLabel: 'Clear search',
      resultsCountBuilder: (count) => '$count results',
      noResultsText: 'No results found',
      resultPageBuilder: (n) => 'Page $n',
      minQueryLength: minQueryLength,
    );
  }

  // -------------------------------------------------------------------------
  // Input rendering
  // -------------------------------------------------------------------------

  testWidgets('shows hint text in search field', (tester) async {
    await tester.pumpWidget(wrap(buildView()));
    expect(find.text('Search document…'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Search triggers at minQueryLength
  // -------------------------------------------------------------------------

  testWidgets('auto-searches when query reaches minQueryLength', (
    tester,
  ) async {
    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('abc', ctrl.stream);

    await tester.pumpWidget(wrap(buildView(minQueryLength: 3)));

    // 2 chars — must NOT trigger auto-search within the debounce window.
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 400));
    verifyNever(mockDoc.search('ab'));

    // 3rd char — triggers after debounce period.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 350));
    verify(mockDoc.search('abc')).called(greaterThanOrEqualTo(1));

    await ctrl.close();
  });

  testWidgets('triggers on Enter for short queries (< minQueryLength)', (
    tester,
  ) async {
    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('ab', ctrl.stream);

    await tester.pumpWidget(wrap(buildView(minQueryLength: 3)));

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();

    // Simulate submitting the text field (pressing Enter / Done).
    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.onSubmitted?.call('ab');
    await tester.pump(const Duration(milliseconds: 50));

    verify(mockDoc.search('ab')).called(greaterThanOrEqualTo(1));

    await ctrl.close();
  });

  // -------------------------------------------------------------------------
  // Clear button
  // -------------------------------------------------------------------------

  testWidgets('clear button appears when text is entered', (tester) async {
    await tester.pumpWidget(wrap(buildView()));
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('clear button clears input and resets controller matches', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildView()));

    // Type text — this shows the clear button without triggering the debounce
    // (we pump just one frame, not long enough for the 300ms debounce to fire).
    await tester.enterText(find.byType(TextField), 'he');
    await tester.pump();

    // Clear button should now be visible.
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Set some fake matches on the controller so we can verify they clear.
    controller.setSearchMatches([
      const PdfSearchMatch(pageIndex: 0, charIndex: 0, charCount: 2, rects: []),
    ]);
    expect(controller.activeSearchMatches, hasLength(1));

    // Tap the clear button.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // Input cleared, clear button gone, controller matches empty.
    expect(find.byIcon(Icons.close), findsNothing);
    expect(controller.activeSearchMatches, isEmpty);
  });

  // -------------------------------------------------------------------------
  // Results rendering
  // -------------------------------------------------------------------------

  testWidgets('shows result count and page label when matches arrive', (
    tester,
  ) async {
    const match = PdfSearchMatch(
      pageIndex: 2,
      charIndex: 10,
      charCount: 5,
      rects: [],
    );

    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('test', ctrl.stream);
    when(
      mockDoc.extractPlainText(pageIndex: 2),
    ).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(wrap(buildView()));

    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 350));

    ctrl.add(match);
    await tester.pump();

    expect(find.textContaining('1 results'), findsOneWidget);
    expect(find.textContaining('Page 3'), findsOneWidget);

    await ctrl.close();
    await tester.pump();
  });

  testWidgets('shows no-results text after empty search completes', (
    tester,
  ) async {
    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('xyz', ctrl.stream);

    await tester.pumpWidget(wrap(buildView()));

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 350));

    await ctrl.close();
    await tester.pump();

    expect(find.text('No results found'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Live region for results count
  // -------------------------------------------------------------------------

  testWidgets('results count node has liveRegion: true semantics', (
    tester,
  ) async {
    const match = PdfSearchMatch(
      pageIndex: 0,
      charIndex: 0,
      charCount: 3,
      rects: [],
    );

    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('foo', ctrl.stream);
    when(
      mockDoc.extractPlainText(pageIndex: 0),
    ).thenAnswer((_) => Stream.empty());

    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(buildView()));

    await tester.enterText(find.byType(TextField), 'foo');
    await tester.pump(const Duration(milliseconds: 350));
    ctrl.add(match);
    await ctrl.close();
    await tester.pump();

    // Verify that there is a Semantics widget with liveRegion: true in the tree.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  // -------------------------------------------------------------------------
  // Accessibility
  // -------------------------------------------------------------------------

  testWidgets('satisfies labeledTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(buildView()));

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  // -------------------------------------------------------------------------
  // didUpdateWidget — tab-switch document change
  // -------------------------------------------------------------------------

  testWidgets(
    'didUpdateWidget restores state from new controller on document change',
    (tester) async {
      // Set up the second document/controller with pre-existing state.
      final mockDoc2 = MockPdfDocument();
      final controller2 = ViewerController();
      addTearDown(controller2.dispose);

      const priorMatch = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 0,
        charCount: 3,
        rects: [],
      );
      controller2.searchQuery = 'pre';
      controller2.searchCompleted = true;
      controller2.setSearchMatches([priorMatch]);

      // Build with the first document.
      Widget buildDynamic(PdfDocument doc, ViewerController ctrl) => wrap(
        SearchView(
          document: doc,
          controller: ctrl,
          hintText: 'Search…',
          clearLabel: 'Clear',
          resultsCountBuilder: (n) => '$n results',
          noResultsText: 'No results',
          resultPageBuilder: (n) => 'Page $n',
        ),
      );

      await tester.pumpWidget(buildDynamic(mockDoc, controller));
      await tester.pump();

      // Switch to the second document — triggers didUpdateWidget.
      await tester.pumpWidget(buildDynamic(mockDoc2, controller2));
      await tester.pump();

      // The restored state means the query text and match count are visible.
      expect(find.textContaining('1 results'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Focus-leave trigger for short queries
  // -------------------------------------------------------------------------

  testWidgets('focus-leave triggers search for short queries', (tester) async {
    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('ab', ctrl.stream);

    await tester.pumpWidget(wrap(buildView(minQueryLength: 3)));

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();

    // Move focus away — this calls _onFocusChange.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    verify(mockDoc.search('ab')).called(greaterThanOrEqualTo(1));

    await ctrl.close();
  });

  // -------------------------------------------------------------------------
  // Error handling in search stream
  // -------------------------------------------------------------------------

  testWidgets('search stream error resets searching state', (tester) async {
    when(
      mockDoc.search('bad'),
    ).thenAnswer((_) => Stream.error(Exception('search failed')));

    await tester.pumpWidget(wrap(buildView()));

    await tester.enterText(find.byType(TextField), 'bad');
    await tester.pump(const Duration(milliseconds: 350));
    // Allow the error to propagate.
    await tester.pump();

    // After error, not searching — searchCompleted=true, no matches → no-results text shown.
    expect(find.text('No results found'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Tapping a result card navigates to that page
  // -------------------------------------------------------------------------

  testWidgets('tapping a result card sets controller currentPage', (
    tester,
  ) async {
    const match = PdfSearchMatch(
      pageIndex: 4,
      charIndex: 0,
      charCount: 3,
      rects: [],
    );
    final ctrl = StreamController<PdfSearchMatch>();
    stubSearch('jump', ctrl.stream);
    when(
      mockDoc.extractPlainText(pageIndex: 4),
    ).thenAnswer((_) => Stream.empty());

    await tester.pumpWidget(wrap(buildView()));

    await tester.enterText(find.byType(TextField), 'jump');
    await tester.pump(const Duration(milliseconds: 350));
    ctrl.add(match);
    await ctrl.close();
    await tester.pump();

    // The result card should be visible.
    expect(find.textContaining('Page 5'), findsOneWidget);

    // Tap the card.
    await tester.tap(find.textContaining('Page 5'));
    await tester.pump();

    expect(controller.currentPage, 4);
  });

  // -------------------------------------------------------------------------
  // Section label shown when sectionResolver is provided
  // -------------------------------------------------------------------------

  testWidgets(
    'result card shows section name when sectionResolver returns one',
    (tester) async {
      const match = PdfSearchMatch(
        pageIndex: 1,
        charIndex: 5,
        charCount: 4,
        rects: [],
      );
      final ctrl = StreamController<PdfSearchMatch>();
      when(mockDoc.search('sect')).thenAnswer((_) => ctrl.stream);
      when(
        mockDoc.extractPlainText(pageIndex: 1),
      ).thenAnswer((_) => Stream.empty());

      await tester.pumpWidget(
        wrap(
          SearchView(
            document: mockDoc,
            controller: controller,
            hintText: 'Search…',
            clearLabel: 'Clear',
            resultsCountBuilder: (n) => '$n results',
            noResultsText: 'No results',
            resultPageBuilder: (n) => 'Page $n',
            sectionResolver: (_) => 'Chapter One',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'sect');
      await tester.pump(const Duration(milliseconds: 350));
      ctrl.add(match);
      await ctrl.close();
      await tester.pump();

      expect(find.text('Chapter One'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Snippet context shown when page text is available
  // -------------------------------------------------------------------------

  testWidgets('result card shows snippet context when page text is provided', (
    tester,
  ) async {
    const pageText = 'The quick brown fox jumps over the lazy dog';
    const match = PdfSearchMatch(
      pageIndex: 0,
      charIndex: 16, // 'fox'
      charCount: 3,
      rects: [],
    );
    final searchCtrl = StreamController<PdfSearchMatch>();
    final textCtrl = StreamController<PdfPageText>();
    when(mockDoc.search('fox')).thenAnswer((_) => searchCtrl.stream);
    when(
      mockDoc.extractPlainText(pageIndex: 0),
    ).thenAnswer((_) => textCtrl.stream);

    await tester.pumpWidget(wrap(buildView()));

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump(const Duration(milliseconds: 350));

    // Emit the match first, then the page text.
    searchCtrl.add(match);
    await tester.pump();

    textCtrl.add(
      const PdfPageText(
        pageIndex: 0,
        text: pageText,
        hasUnicodeErrors: false,
        hasTextLayer: true,
      ),
    );
    await textCtrl.close();
    await tester.pump();
    await searchCtrl.close();
    await tester.pump();

    // The snippet should contain text from around the match.
    expect(find.textContaining('fox'), findsWidgets);
  });
}
