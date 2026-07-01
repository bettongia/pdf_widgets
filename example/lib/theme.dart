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
import 'package:google_fonts/google_fonts.dart';

/// Returns a [ThemeData] using the quietly design.
ThemeData quietlyTheme() {
  final sansFontFamily = GoogleFonts.notoSans().fontFamily;
  final serifFontFamily = GoogleFonts.notoSerif().fontFamily;
  const paper50 = Color(0xFFFAF7F2); // app bg
  const paper100 = Color(0xFFF4EFE6); // surface
  const paper200 = Color(0xFFE8E1D3); // hairline / divider
  const ink900 = Color(0xFF2A2520); // primary text
  const ink700 = Color(0xFF4A433B); // muted
  const ink500 = Color(0xFF79716A); // meta
  const stop = Color(0xFFB8867A);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      surface: paper50,
      onSurface: ink900,

      primary: paper100,
      onPrimary: ink700,

      secondary: paper200,
      onSecondary: ink500,

      tertiary: paper100,
      onTertiary: ink500,

      outline: paper200,
      error: stop,
    ),
    scaffoldBackgroundColor: paper50,
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: Colors.yellowAccent.withValues(alpha: 0.6),
    ),
    iconTheme: const IconThemeData(color: ink700, size: 16),
    textTheme: GoogleFonts.notoSansTextTheme(
      TextTheme(
        displaySmall: TextStyle(
          fontFamily: serifFontFamily,
          fontSize: 28,
          height: 1.2,
          letterSpacing: -0.28,
          fontWeight: FontWeight.w600,
        ), // paper title
        titleMedium: TextStyle(
          fontFamily: serifFontFamily,
          fontSize: 19,
          letterSpacing: -0.19,
          fontWeight: FontWeight.w600,
        ), // section head
        bodyMedium: TextStyle(
          fontFamily: serifFontFamily,
          fontSize: 14,
          height: 1.62,
        ), // page prose
        labelLarge: TextStyle(
          fontFamily: sansFontFamily,
          fontSize: 14,
          height: 1.4,
        ), // UI / buttons
        labelSmall: TextStyle(
          fontFamily: sansFontFamily,
          fontSize: 11,
          letterSpacing: 0.88,
          fontWeight: FontWeight.w600,
        ), // CAPS labels
      ),
    ),
  );
}

/// Animation duration constants from the design system.
abstract final class BettoMotion {
  /// Duration for the sidebar slide in/out animation (180 ms).
  static const kSidebarDuration = Duration(milliseconds: 180);

  /// Easing curve for the sidebar slide in/out.
  ///
  /// Matches `cubic-bezier(0.32, 0.72, 0.34, 1)` from the design system.
  static const kSidebarCurve = Cubic(0.32, 0.72, 0.34, 1);
}
