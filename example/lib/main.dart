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

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'quietly',
      minimumSize: Size(640, 480),
      size: Size(900, 640),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const _AppWithWindowLifecycle());
}

/// Wraps [PdfViewerApp] and listens to [WindowListener] events so that
/// open documents are closed on OS-level window termination (force-close,
/// system kill), not only on the Quit menu path.
class _AppWithWindowLifecycle extends StatefulWidget {
  const _AppWithWindowLifecycle();

  @override
  State<_AppWithWindowLifecycle> createState() =>
      _AppWithWindowLifecycleState();
}

class _AppWithWindowLifecycleState extends State<_AppWithWindowLifecycle>
    with WindowListener {
  // The key gives us access to the PdfViewerApp's state from outside the
  // widget tree, so we can call closeAll() on OS-initiated window close.
  final GlobalKey<State<PdfViewerApp>> _appKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    // Ensure all PdfDocument handles are released on abnormal termination.
    // The normal Quit path calls dispose() via PdfViewerApp._state.closeAll(),
    // but OS kill / force-close bypasses that path.
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewerApp(key: _appKey);
  }
}
