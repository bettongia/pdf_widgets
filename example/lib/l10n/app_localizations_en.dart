// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'quietly';

  @override
  String get menuFile => 'File';

  @override
  String get menuOpen => 'Open…';

  @override
  String get menuCloseTab => 'Close Tab';

  @override
  String get menuQuit => 'Quit';

  @override
  String get tabCloseButton => 'Close tab';

  @override
  String get emptyStateHeading => 'No document open';

  @override
  String get emptyStateBody => 'Choose File > Open to open a PDF.';

  @override
  String pageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get errorOpeningFile => 'Could not open file';

  @override
  String get errorLoadingPage => 'Failed to render page';

  @override
  String pageSemanticLabel(int number, String title) {
    return 'PDF page $number of document $title';
  }

  @override
  String get sidebarTocTitle => 'Table of Contents';

  @override
  String get sidebarThumbnailsTitle => 'Page Thumbnails';

  @override
  String get sidebarAnnotationsTitle => 'Annotations';

  @override
  String get sidebarSearchTitle => 'Search';

  @override
  String get sidebarInfoTitle => 'Document Info';

  @override
  String get sidebarCloseButton => 'Close sidebar';

  @override
  String get railToc => 'Table of Contents';

  @override
  String get railThumbnails => 'Page Thumbnails';

  @override
  String get railAnnotations => 'Annotations';

  @override
  String get railSearch => 'Search';

  @override
  String get railInfo => 'Document Info';

  @override
  String get tocEmpty => 'No table of contents';

  @override
  String thumbnailPageLabel(int n) {
    return 'Page $n';
  }

  @override
  String get annotationNote => 'Note';

  @override
  String get annotationHighlight => 'Highlight';

  @override
  String annotationsTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
    );
    return '$_temp0';
  }

  @override
  String get annotationsNoneFound => 'No annotations found';

  @override
  String get annotationToggleOn => 'Hide annotations in PDF';

  @override
  String get annotationToggleOff => 'Show annotations in PDF';

  @override
  String get searchHint => 'Search document…';

  @override
  String get searchClear => 'Clear search';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get searchNoResults => 'No results found';

  @override
  String searchResultPage(int n) {
    return 'Page $n';
  }

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomReset => 'Reset zoom to 100%';

  @override
  String get zoomFitPage => 'Fit page';

  @override
  String get zoomFitWidth => 'Fit width';

  @override
  String zoomLevel(int percent) {
    return '$percent%';
  }

  @override
  String get infoTitle => 'Title';

  @override
  String get infoAuthor => 'Author';

  @override
  String get infoSubject => 'Subject';

  @override
  String get infoKeywords => 'Keywords';

  @override
  String get infoCreator => 'Creator';

  @override
  String get infoProducer => 'Producer';

  @override
  String get infoCreationDate => 'Created';

  @override
  String get infoModDate => 'Modified';

  @override
  String get infoFileName => 'File name';

  @override
  String get infoFilePath => 'Location';

  @override
  String get infoFileSize => 'File size';

  @override
  String get infoPageCount => 'Pages';

  @override
  String get infoPdfVersion => 'PDF version';

  @override
  String get infoFsCreated => 'Created on disk';

  @override
  String get infoFsModified => 'Modified on disk';

  @override
  String get openFile => 'Open file';
}
