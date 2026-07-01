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

import 'dart:ui' as ui;

import 'package:betto_pdf_widgets/betto_pdf_widgets.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/document_state.dart';

/// Hosts the [PageViewer] canvas with a floating bottom toolbar pill.
///
/// The toolbar pill provides:
/// - Left section: previous/next page navigation and a page indicator.
/// - Right section: zoom-out, zoom level label (tapping resets to 100%),
///   zoom-in, fit-width, and fit-page buttons.
///
/// All navigation and zoom state is managed by [OpenDocument.viewerController].
class PdfViewerPane extends StatelessWidget {
  const PdfViewerPane({super.key, required this.doc});

  final OpenDocument doc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = doc.viewerController;

    return Container(
      color: Theme.of(context).colorScheme.surface, // BettoColors.paper50,
      child: Stack(
        children: [
          // Main page viewer — fills available space.
          Positioned.fill(
            child: PageViewer(
              document: doc.document,
              pageCount: doc.pageCount,
              controller: controller,
              semanticLabel: l10n.pageSemanticLabel(
                controller.currentPage + 1,
                doc.fileName,
              ),
            ),
          ),
          // Floating bottom toolbar pill.
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) =>
                    _ToolbarPill(doc: doc, controller: controller, l10n: l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating pill toolbar at the bottom of the viewer.
///
/// Uses [BackdropFilter] + semi-transparent background for the glassmorphism
/// effect specified in the design system.
class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.doc,
    required this.controller,
    required this.l10n,
  });

  final OpenDocument doc;
  final ViewerController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPrev = controller.currentPage > 0;
    final canNext = controller.currentPage < doc.pageCount - 1;
    final zoomMode = controller.zoomMode;
    final String zoomLabel = switch (zoomMode) {
      ZoomMode.fitPage => l10n.zoomFitPage,
      ZoomMode.fitWidth => l10n.zoomFitWidth,
      ZoomMode.custom => l10n.zoomLevel((controller.zoomFactor * 100).round()),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withAlpha(217), // ~85% opacity
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Page navigation ---
                _PillIconButton(
                  icon: Icons.chevron_left,
                  label: l10n.previousPage,
                  enabled: canPrev,
                  onPressed: canPrev ? controller.previousPage : null,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                  child: Text(
                    l10n.pageIndicator(
                      controller.currentPage + 1,
                      doc.pageCount,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                _PillIconButton(
                  icon: Icons.chevron_right,
                  label: l10n.nextPage,
                  enabled: canNext,
                  onPressed: canNext
                      ? () => controller.nextPage(pageCount: doc.pageCount)
                      : null,
                ),
                // Separator
                const _PillDivider(),
                // --- Zoom controls ---
                _PillIconButton(
                  icon: Icons.remove,
                  label: l10n.zoomOut,
                  onPressed: () {
                    final next = (controller.effectiveZoomFactor - 0.1).clamp(
                      0.1,
                      8.0,
                    );
                    controller.setZoom(ZoomMode.custom, factor: next);
                  },
                ),
                Tooltip(
                  message: l10n.zoomReset,
                  child: Semantics(
                    label: l10n.zoomReset,
                    button: true,
                    child: InkWell(
                      onTap: () =>
                          controller.setZoom(ZoomMode.custom, factor: 1.0),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          zoomLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ),
                _PillIconButton(
                  icon: Icons.add,
                  label: l10n.zoomIn,
                  onPressed: () {
                    final next = (controller.effectiveZoomFactor + 0.1).clamp(
                      0.1,
                      8.0,
                    );
                    controller.setZoom(ZoomMode.custom, factor: next);
                  },
                ),
                _PillIconButton(
                  icon: Icons.fit_screen_outlined,
                  label: l10n.zoomFitWidth,
                  onPressed: () => controller.setZoom(ZoomMode.fitWidth),
                ),
                _PillIconButton(
                  icon: Icons.crop_free_outlined,
                  label: l10n.zoomFitPage,
                  onPressed: () => controller.setZoom(ZoomMode.fitPage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: enabled,
        child: IconButton(
          icon: Icon(icon, size: 16),
          color: enabled
              ? color
                    .onPrimary //BettoColors.ink700
              : color.onSecondary, // BettoColors.ink300,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: Theme.of(context).colorScheme.outline,
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
    );
  }
}
