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

import 'dart:io';

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart' show PdfDocument;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'state/document_state.dart';
import 'theme.dart';

/// Root widget of the PDF viewer example application.
class PdfViewerApp extends StatefulWidget {
  const PdfViewerApp({super.key});

  @override
  State<PdfViewerApp> createState() => _PdfViewerAppState();
}

class _PdfViewerAppState extends State<PdfViewerApp> {
  final DocumentState _state = DocumentState();

  /// Opens a native file-picker dialog and loads the chosen PDF.
  Future<void> _openFile(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    try {
      // If the file is already open, switch to its tab instead of reopening.
      final existingIndex = _state.documents.indexWhere(
        (d) => d.filePath == path,
      );
      if (existingIndex != -1) {
        _state.activate(existingIndex);
        return;
      }

      final file = File(path);
      final Uint8List bytes = await file.readAsBytes();
      final doc = await PdfDocument.fromBytes(bytes);
      final pageCount = await doc.pageCount;
      final fileName = path.split(Platform.pathSeparator).last;
      final fileSizeBytes = await file.length();
      _state.add(
        OpenDocument(
          document: doc,
          fileName: fileName,
          pageCount: pageCount,
          filePath: path,
          fileSizeBytes: fileSizeBytes,
        ),
      );
    } catch (e, st) {
      debugPrint('PDF open error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorOpeningFile)));
      }
    }
  }

  Future<void> _closeActiveTab() async {
    final idx = _state.activeIndex;
    if (idx >= 0) await _state.close(idx);
  }

  @override
  void dispose() {
    _state.closeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'quietly',
      theme: quietlyTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => _AppShell(
          state: _state,
          onOpen: () => _openFile(context),
          onCloseTab: _closeActiveTab,
        ),
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({
    required this.state,
    required this.onOpen,
    required this.onCloseTab,
  });

  final DocumentState state;
  final VoidCallback onOpen;
  final VoidCallback onCloseTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PlatformMenuBar(
      menus: [
        // macOS uses the first menu as the application menu (shown as app name).
        PlatformMenu(
          label: l10n.appTitle,
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: l10n.menuQuit,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyQ,
                    meta: true,
                  ),
                  onSelected: SystemNavigator.pop,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuFile,
          menus: [
            PlatformMenuItem(
              label: l10n.menuOpen,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: onOpen,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: l10n.menuCloseTab,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyW,
                    meta: true,
                  ),
                  onSelected: onCloseTab,
                ),
              ],
            ),
          ],
        ),
      ],
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface, // _BettoColors.paper50,
          body: ListenableBuilder(
            listenable: state,
            builder: (context, _) => HomeScreen(
              state: state,
              onClose: (i) => state.close(i),
              onOpenFile: onOpen,
            ),
          ),
        ),
      ),
    );
  }
}
