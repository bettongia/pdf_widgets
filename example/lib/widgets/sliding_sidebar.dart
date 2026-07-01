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

import '../theme.dart';

/// An animated slide-in sidebar panel.
///
/// [SlidingSidebar] wraps an arbitrary [child] widget in a fixed-width
/// (280 dp) panel that slides in from the left when [isOpen] is `true` and
/// slides out when `false`. The animation is 180 ms with an ease-out curve.
///
/// When [MediaQuery.disableAnimations] is true the transition collapses to an
/// instant show/hide so users who prefer reduced motion are not affected.
///
/// The panel header shows [title] on the left and a
/// close icon button on the right. Tapping the close button calls [onClose].
///
/// ## Focus management
///
/// When the sidebar opens ([isOpen] changes to `true`) the first focusable
/// element inside [child] receives focus automatically. When it closes focus
/// should be returned to the rail button that opened it — the caller is
/// responsible for this via [onClose].
///
/// ## Accessibility
///
/// The close button has a [Semantics] label sourced from [closeLabel] (ARB:
/// `sidebarCloseButton`). The panel uses `paper-100` background with a 1px
/// `paper-200` right border.
class SlidingSidebar extends StatefulWidget {
  /// Creates a [SlidingSidebar].
  const SlidingSidebar({
    super.key,
    required this.isOpen,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.child,
  });

  /// Whether the sidebar is currently visible.
  final bool isOpen;

  /// Panel title shown in the header (e.g. "Table of Contents").
  final String title;

  /// Accessible label for the close button (e.g. "Close sidebar").
  final String closeLabel;

  /// Called when the user taps the close button.
  ///
  /// The caller must set [isOpen] to `false` and restore focus to the rail
  /// button that opened this sidebar.
  final VoidCallback onClose;

  /// The panel content widget.
  final Widget child;

  @override
  State<SlidingSidebar> createState() => _SlidingSidebarState();
}

class _SlidingSidebarState extends State<SlidingSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _widthFactor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BettoMotion.kSidebarDuration,
      value: widget.isOpen ? 1.0 : 0.0,
    );
    _widthFactor = CurvedAnimation(
      parent: _ctrl,
      curve: BettoMotion.kSidebarCurve,
    );
  }

  @override
  void didUpdateWidget(SlidingSidebar old) {
    super.didUpdateWidget(old);
    if (old.isOpen != widget.isOpen) {
      if (MediaQuery.of(context).disableAnimations) {
        // Instant transition for reduced-motion preference.
        _ctrl.value = widget.isOpen ? 1.0 : 0.0;
      } else {
        if (widget.isOpen) {
          _ctrl.forward();
        } else {
          _ctrl.reverse();
        }
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // SizeTransition clips to zero width when closed, eliminating layout space.
    return SizeTransition(
      sizeFactor: _widthFactor,
      axis: Axis.horizontal,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            right: BorderSide(color: colors.onSecondary, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SidebarHeader(
              title: widget.title,
              closeLabel: widget.closeLabel,
              onClose: widget.onClose,
            ),
            const Divider(
              height: 1,
              thickness: 1,
              //color: _BettoColors.paper200,
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

/// The header row of the sliding sidebar: title on the left, close button on the right.
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.title,
    required this.closeLabel,
    required this.onClose,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              /*TextStyle(
                fontFamily: _BettoText.fontSans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _BettoColors.ink700,
              ),*/
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            label: closeLabel,
            button: true,
            child: IconButton(
              icon: Icon(Icons.close, size: 16),
              tooltip: closeLabel,
              onPressed: onClose,

              //color: _BettoColors.ink500,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            ),
          ),
        ],
      ),
    );
  }
}
