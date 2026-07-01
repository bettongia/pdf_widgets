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

/// The five sidebar panels selectable via the rail.
enum RailPanel { toc, thumbnails, annotations, search, info }

/// A narrow vertical icon rail that toggles the slide-in sidebar.
///
/// Displays five icon buttons — Table of Contents, Page Thumbnails,
/// Annotations, Search, and Document Info. Tapping an active button closes
/// the sidebar; tapping an inactive button opens it and switches the panel.
///
/// The rail is 48 dp wide (minimum touch target). Each button is 48 × 48 dp
/// with a [Semantics] label and tooltip sourced from ARB strings.
///
/// ## Accessibility
///
/// All buttons carry a [Tooltip] and a [Semantics] label. Tab order flows
/// top-to-bottom through the rail. Focus is managed externally by the caller
/// (the [FocusNode] for each button can be set via [buttonFocusNodes]).
class MenuRail extends StatelessWidget {
  /// Creates a [MenuRail].
  const MenuRail({
    super.key,
    required this.activePanel,
    required this.onPanelSelected,
    required this.tocLabel,
    required this.thumbnailsLabel,
    required this.annotationsLabel,
    required this.searchLabel,
    required this.infoLabel,
    this.buttonFocusNodes,
  });

  /// The currently active sidebar panel, or null when the sidebar is closed.
  final RailPanel? activePanel;

  /// Called when the user selects a panel.
  ///
  /// Receives the tapped [RailPanel]. The caller is responsible for toggling
  /// the sidebar: if [activePanel] == the tapped value, it should close the
  /// sidebar (set [activePanel] to null).
  final void Function(RailPanel panel) onPanelSelected;

  /// Accessible label and tooltip for the Table of Contents button.
  final String tocLabel;

  /// Accessible label and tooltip for the Page Thumbnails button.
  final String thumbnailsLabel;

  /// Accessible label and tooltip for the Annotations button.
  final String annotationsLabel;

  /// Accessible label and tooltip for the Search button.
  final String searchLabel;

  /// Accessible label and tooltip for the Document Info button.
  final String infoLabel;

  /// Optional [FocusNode] list, one per button in rail order:
  /// [toc, thumbnails, annotations, search, info].
  ///
  /// When provided, focus is managed by the caller (e.g. to return focus to a
  /// rail button when the sidebar is closed).
  final List<FocusNode>? buttonFocusNodes;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: color.primary,
        border: Border(right: BorderSide(color: color.outline, width: 1)),
      ),
      child: Column(
        children: [
          _RailButton(
            panel: RailPanel.toc,
            icon: Icons.list_alt_outlined,
            label: tocLabel,
            isActive: activePanel == RailPanel.toc,
            onTap: () => onPanelSelected(RailPanel.toc),
            focusNode: buttonFocusNodes?.elementAtOrNull(0),
          ),
          _RailButton(
            panel: RailPanel.thumbnails,
            icon: Icons.grid_view_outlined,
            label: thumbnailsLabel,
            isActive: activePanel == RailPanel.thumbnails,
            onTap: () => onPanelSelected(RailPanel.thumbnails),
            focusNode: buttonFocusNodes?.elementAtOrNull(1),
          ),
          _RailButton(
            panel: RailPanel.annotations,
            icon: Icons.sticky_note_2_outlined,
            label: annotationsLabel,
            isActive: activePanel == RailPanel.annotations,
            onTap: () => onPanelSelected(RailPanel.annotations),
            focusNode: buttonFocusNodes?.elementAtOrNull(2),
          ),
          _RailButton(
            panel: RailPanel.search,
            icon: Icons.search,
            label: searchLabel,
            isActive: activePanel == RailPanel.search,
            onTap: () => onPanelSelected(RailPanel.search),
            focusNode: buttonFocusNodes?.elementAtOrNull(3),
          ),
          _RailButton(
            panel: RailPanel.info,
            icon: Icons.info_outline,
            label: infoLabel,
            isActive: activePanel == RailPanel.info,
            onTap: () => onPanelSelected(RailPanel.info),
            focusNode: buttonFocusNodes?.elementAtOrNull(4),
          ),
        ],
      ),
    );
  }
}

/// A single icon button within the [MenuRail].
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.panel,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.focusNode,
  });

  final RailPanel panel;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  /// Sage background tint at 12% opacity for the active rail item.
  static const _activeBackground = Color(0x1F9EB8A4);

  /// Sage 3px left indicator for the active rail item.
  //static const _sageColor = _BettoColors.sage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: Semantics(
        label: label,
        button: true,
        selected: isActive,
        child: InkWell(
          onTap: onTap,
          focusNode: focusNode,
          child: Container(
            width: 48,
            height: 48,
            decoration: isActive
                ? BoxDecoration(
                    color: _activeBackground,
                    border: Border(
                      left: BorderSide(color: color.surfaceContainer, width: 3),
                    ),
                  )
                : null,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isActive ? color.onPrimary : color.onSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
