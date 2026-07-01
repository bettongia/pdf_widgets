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

// Widget tests for the PDF viewer example app.
//
// These tests run against the UI scaffold only — no real PDFs or PDFium binary
// required. AccessibilityGuideline checks verify that the empty state and
// chrome meet contrast and tap-target requirements.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/theme.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:example/screens/home_screen.dart';
import 'package:example/state/document_state.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  theme: quietlyTheme(),
  home: Scaffold(body: child),
);

void main() {
  group('empty state', () {
    testWidgets('shows empty-state heading when no document is open', (
      tester,
    ) async {
      final state = DocumentState();
      await tester.pumpWidget(
        _wrap(HomeScreen(state: state, onClose: (_) {}, onOpenFile: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('No document open'), findsOneWidget);
      expect(find.text('Choose File > Open to open a PDF.'), findsOneWidget);
    });

    testWidgets('meets text contrast accessibility guideline', (tester) async {
      final state = DocumentState();
      await tester.pumpWidget(
        _wrap(HomeScreen(state: state, onClose: (_) {}, onOpenFile: () {})),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('meets labeled tap-target guideline', (tester) async {
      final state = DocumentState();
      await tester.pumpWidget(
        _wrap(HomeScreen(state: state, onClose: (_) {}, onOpenFile: () {})),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  group('PdfViewerApp scaffold', () {
    testWidgets('renders without error', (tester) async {
      // window_manager is not available in tests — wrap manually.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: quietlyTheme(),
          home: Scaffold(
            body: HomeScreen(
              state: DocumentState(),
              onClose: (_) {},
              onOpenFile: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
