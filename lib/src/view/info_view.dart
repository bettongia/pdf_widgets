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

import 'package:betto_pdfium/betto_pdfium.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A read-only panel showing document metadata and file information.
///
/// [InfoView] renders two sections:
/// 1. **Document metadata** — [PdfMetadata] fields (title, author, subject,
///    keywords, creator, producer, creation date, modification date).
/// 2. **File information** — optional file name, file path, file size, page
///    count, PDF version, and filesystem dates.
///
/// File info is passed as parameters rather than fetched internally, keeping
/// the widget free of `dart:io` and making it straightforward to test.
///
/// All string fields are rendered as labelled rows with the label in a muted
/// style and the value in primary text. Missing or null fields are omitted
/// entirely. Dates are formatted via `intl.DateFormat` using `pdfDate.value`
/// (a `DateTime?` in UTC); the raw string is never shown.
///
/// File size is formatted as a human-readable string (e.g. "1.2 MB") using
/// [NumberFormat.decimalPattern].
///
/// ## Example
///
/// ```dart
/// InfoView(
///   metadata: meta,
///   docInfo: info,
///   pageCount: 42,
///   filePath: '/path/to/document.pdf',
///   fileSizeBytes: 1234567,
///   labels: PdfDocumentInfoLabels(...),
/// )
/// ```
class InfoView extends StatelessWidget {
  /// Creates a [InfoView].
  const InfoView({
    super.key,
    required this.metadata,
    required this.docInfo,
    required this.labels,
    this.pageCount,
    this.filePath,
    this.fileSizeBytes,
    this.fsCreated,
    this.fsModified,
    this.locale,
  });

  /// Document metadata from the PDF Info dictionary.
  final PdfMetadata metadata;

  /// Document-level properties (PDF version, file identifiers).
  final PdfDocumentInfo docInfo;

  /// Localised label strings for each field.
  final DocumentInfoLabels labels;

  /// Total number of pages, or null if not available.
  final int? pageCount;

  /// Full filesystem path to the file, or null if not available.
  final String? filePath;

  /// File size in bytes, or null if not available.
  final int? fileSizeBytes;

  /// Filesystem creation date, or null if not available.
  final DateTime? fsCreated;

  /// Filesystem last-modified date, or null if not available.
  final DateTime? fsModified;

  /// Locale for date and number formatting. Defaults to the system locale.
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat.yMMMd(locale);
    final String? fileName = filePath?.split('/').last;

    final rows = <_InfoRow>[];

    // --- Document metadata section ---
    if (metadata.title != null && metadata.title!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.title, value: metadata.title!));
    }
    if (metadata.author != null && metadata.author!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.author, value: metadata.author!));
    }
    if (metadata.subject != null && metadata.subject!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.subject, value: metadata.subject!));
    }
    if (metadata.keywords != null && metadata.keywords!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.keywords, value: metadata.keywords!));
    }
    if (metadata.creator != null && metadata.creator!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.creator, value: metadata.creator!));
    }
    if (metadata.producer != null && metadata.producer!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.producer, value: metadata.producer!));
    }
    final creationDt = metadata.creationDate?.value;
    if (creationDt != null) {
      rows.add(
        _InfoRow(
          label: labels.creationDate,
          value: dateFormatter.format(creationDt.toLocal()),
        ),
      );
    }
    final modDt = metadata.modDate?.value;
    if (modDt != null) {
      rows.add(
        _InfoRow(
          label: labels.modDate,
          value: dateFormatter.format(modDt.toLocal()),
        ),
      );
    }

    // --- File information section ---
    if (fileName != null && fileName.isNotEmpty) {
      rows.add(_InfoRow(label: labels.fileName, value: fileName));
    }
    if (filePath != null && filePath!.isNotEmpty) {
      rows.add(_InfoRow(label: labels.filePath, value: filePath!));
    }
    if (fileSizeBytes != null) {
      rows.add(
        _InfoRow(
          label: labels.fileSize,
          value: _formatFileSize(fileSizeBytes!, locale),
        ),
      );
    }
    if (pageCount != null) {
      rows.add(_InfoRow(label: labels.pageCount, value: '$pageCount'));
    }
    if (docInfo.fileVersion != null) {
      // PDF version is stored as an integer e.g. 17 → "1.7".
      final v = docInfo.fileVersion!;
      final vStr = '${v ~/ 10}.${v % 10}';
      rows.add(_InfoRow(label: labels.pdfVersion, value: 'PDF $vStr'));
    }
    if (fsCreated != null) {
      rows.add(
        _InfoRow(
          label: labels.fsCreated,
          value: dateFormatter.format(fsCreated!.toLocal()),
        ),
      );
    }
    if (fsModified != null) {
      rows.add(
        _InfoRow(
          label: labels.fsModified,
          value: dateFormatter.format(fsModified!.toLocal()),
        ),
      );
    }

    if (rows.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Text('—', style: theme.textTheme.bodySmall),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 8,
        horizontal: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Formats [bytes] as a human-readable size string (e.g. "1.2 MB").
  static String _formatFileSize(int bytes, String? locale) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${NumberFormat('#,##0.#', locale).format(kb)} KB';
    } else {
      final mb = bytes / (1024 * 1024);
      return '${NumberFormat('#,##0.#', locale).format(mb)} MB';
    }
  }
}

/// A single label–value row in [InfoView].
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Localised label strings for [InfoView].
///
/// Pass these from your ARB-generated localisation class to keep the widget
/// free of hardcoded English strings.
class DocumentInfoLabels {
  /// Creates a [DocumentInfoLabels] value object.
  const DocumentInfoLabels({
    required this.title,
    required this.author,
    required this.subject,
    required this.keywords,
    required this.creator,
    required this.producer,
    required this.creationDate,
    required this.modDate,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.pageCount,
    required this.pdfVersion,
    required this.fsCreated,
    required this.fsModified,
  });

  /// Label for the document title field.
  final String title;

  /// Label for the author field.
  final String author;

  /// Label for the subject field.
  final String subject;

  /// Label for the keywords field.
  final String keywords;

  /// Label for the creator application field.
  final String creator;

  /// Label for the producer application field.
  final String producer;

  /// Label for the document creation date field.
  final String creationDate;

  /// Label for the document last-modified date field.
  final String modDate;

  /// Label for the file name field.
  final String fileName;

  /// Label for the file path / location field.
  final String filePath;

  /// Label for the file size field.
  final String fileSize;

  /// Label for the page count field.
  final String pageCount;

  /// Label for the PDF version field.
  final String pdfVersion;

  /// Label for the filesystem creation date field.
  final String fsCreated;

  /// Label for the filesystem last-modified date field.
  final String fsModified;
}
