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

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfViewerController', () {
    late ViewerController controller;

    setUp(() {
      controller = ViewerController();
    });

    tearDown(() {
      controller.dispose();
    });

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('initial state is page 0, fitPage, annotations on, no matches', () {
      expect(controller.currentPage, 0);
      expect(controller.zoomMode, ZoomMode.fitPage);
      expect(controller.zoomFactor, 1.0);
      expect(controller.renderAnnotations, isTrue);
      expect(controller.activeSearchMatches, isEmpty);
    });

    // -------------------------------------------------------------------------
    // setPage / nextPage / previousPage
    // -------------------------------------------------------------------------

    test('setPage clamps to 0 when given negative index', () {
      controller.setPage(-5, pageCount: 10);
      expect(controller.currentPage, 0);
    });

    test('setPage clamps to pageCount-1 when given an out-of-range index', () {
      controller.setPage(99, pageCount: 5);
      expect(controller.currentPage, 4);
    });

    test('setPage is no-op when pageCount is 0', () {
      controller.setPage(0, pageCount: 0);
      expect(controller.currentPage, 0); // unchanged
    });

    test('setPage notifies listeners on change', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.setPage(2, pageCount: 10);
      expect(notifyCount, 1);
    });

    test('setPage does NOT notify listeners when page is unchanged', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.setPage(0, pageCount: 10); // already 0
      expect(notifyCount, 0);
    });

    test('nextPage advances page and notifies', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.nextPage(pageCount: 5);
      expect(controller.currentPage, 1);
      expect(notifyCount, 1);
    });

    test('nextPage is no-op on last page', () {
      controller.setPage(4, pageCount: 5);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.nextPage(pageCount: 5);
      expect(controller.currentPage, 4);
      expect(notifyCount, 0);
    });

    test('previousPage moves back and notifies', () {
      controller.setPage(3, pageCount: 10);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.previousPage();
      expect(controller.currentPage, 2);
      expect(notifyCount, 1);
    });

    test('previousPage is no-op on page 0', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.previousPage();
      expect(controller.currentPage, 0);
      expect(notifyCount, 0);
    });

    // -------------------------------------------------------------------------
    // setZoom
    // -------------------------------------------------------------------------

    test('setZoom changes mode and notifies listeners', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.setZoom(ZoomMode.fitWidth);
      expect(controller.zoomMode, ZoomMode.fitWidth);
      expect(notifyCount, 1);
    });

    test('setZoom to custom stores zoomFactor', () {
      controller.setZoom(ZoomMode.custom, factor: 1.5);
      expect(controller.zoomMode, ZoomMode.custom);
      expect(controller.zoomFactor, 1.5);
    });

    test('setZoom does NOT notify when mode and factor are unchanged', () {
      controller.setZoom(ZoomMode.fitWidth);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.setZoom(ZoomMode.fitWidth); // same
      expect(notifyCount, 0);
    });

    test('setZoom asserts positive factor', () {
      expect(
        () => controller.setZoom(ZoomMode.custom, factor: -1.0),
        throwsA(isA<AssertionError>()),
      );
    });

    // -------------------------------------------------------------------------
    // renderAnnotations
    // -------------------------------------------------------------------------

    test('setting renderAnnotations to false notifies', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.renderAnnotations = false;
      expect(controller.renderAnnotations, isFalse);
      expect(notifyCount, 1);
    });

    test('setting renderAnnotations to same value does NOT notify', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.renderAnnotations = true; // already true
      expect(notifyCount, 0);
    });

    // -------------------------------------------------------------------------
    // setSearchMatches / clearSearch
    // -------------------------------------------------------------------------

    test('setSearchMatches stores matches and notifies', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      final match = PdfSearchMatch(
        pageIndex: 0,
        charIndex: 5,
        charCount: 3,
        rects: [const PdfRect(left: 0, bottom: 0, right: 10, top: 10)],
      );
      controller.setSearchMatches([match]);
      expect(controller.activeSearchMatches, hasLength(1));
      expect(notifyCount, 1);
    });

    test('clearSearch empties matches and notifies', () {
      controller.setSearchMatches([
        const PdfSearchMatch(
          pageIndex: 0,
          charIndex: 0,
          charCount: 1,
          rects: [],
        ),
      ]);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.clearSearch();
      expect(controller.activeSearchMatches, isEmpty);
      expect(notifyCount, 1);
    });

    test('clearSearch is no-op when already empty', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.clearSearch();
      expect(notifyCount, 0);
    });

    // -------------------------------------------------------------------------
    // dispose
    // -------------------------------------------------------------------------

    test('dispose does not throw', () {
      final c = ViewerController();
      expect(() => c.dispose(), returnsNormally);
    });
  });
}
