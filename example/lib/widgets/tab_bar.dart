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
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../state/document_state.dart';

/// A horizontal tab strip that displays one tab per open document.
///
/// Each tab shows the file name and a close button. The active tab is
/// highlighted. Tabs are keyboard-navigable; focus is restored to the strip
/// after a tab is closed.
class PdfTabBar extends StatefulWidget {
  const PdfTabBar({super.key, required this.state, required this.onClose});

  final DocumentState state;
  final void Function(int index) onClose;

  @override
  State<PdfTabBar> createState() => _PdfTabBarState();
}

class _PdfTabBarState extends State<PdfTabBar> {
  // Focus nodes for each tab close button — kept in sync with the document list.
  final List<FocusNode> _closeFocusNodes = [];

  @override
  void dispose() {
    for (final n in _closeFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _syncFocusNodes(int count) {
    while (_closeFocusNodes.length < count) {
      _closeFocusNodes.add(FocusNode());
    }
    while (_closeFocusNodes.length > count) {
      _closeFocusNodes.removeLast().dispose();
    }
  }

  void _handleClose(int index) {
    final docCount = widget.state.documents.length;
    widget.onClose(index);
    // After close, move focus to the adjacent tab's close button.
    if (docCount > 1) {
      final nextIndex = index < docCount - 1 ? index : index - 1;
      if (nextIndex >= 0 && nextIndex < _closeFocusNodes.length) {
        _closeFocusNodes[nextIndex].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final docs = widget.state.documents;
    _syncFocusNodes(docs.length);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.tertiary,
        border: Border(bottom: BorderSide(color: colors.tertiary, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < docs.length; i++)
              _Tab(
                key: ValueKey(docs[i].fileName + i.toString()),
                label: docs[i].fileName,
                isActive: i == widget.state.activeIndex,
                closeFocusNode: _closeFocusNodes[i],
                closeLabel: l10n.tabCloseButton,
                onTap: () => widget.state.activate(i),
                onClose: () => _handleClose(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.isActive,
    required this.closeFocusNode,
    required this.closeLabel,
    required this.onTap,
    required this.onClose,
  });

  final String label;
  final bool isActive;
  final FocusNode closeFocusNode;
  final String closeLabel;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
        decoration: BoxDecoration(
          color: isActive ? colors.surface : Colors.transparent,
          border: Border(
            right: BorderSide(color: colors.onSurface, width: 1),
            bottom: BorderSide(
              color: isActive ? colors.onSurface : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isActive ? colors.onSurface : colors.onPrimary,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SizedBox(width: 4),
              Semantics(
                label: closeLabel,
                button: true,
                child: Focus(
                  focusNode: closeFocusNode,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      onClose();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: colors.onSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
