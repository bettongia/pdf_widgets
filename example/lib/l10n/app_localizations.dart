import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application title shown in the window title bar.
  ///
  /// In en, this message translates to:
  /// **'quietly'**
  String get appTitle;

  /// The File menu label.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// The File > Open menu item. The ellipsis indicates a dialog will open.
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get menuOpen;

  /// The File > Close Tab menu item, which closes the active document tab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get menuCloseTab;

  /// The File > Quit menu item.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get menuQuit;

  /// Accessible label for the close button on each document tab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get tabCloseButton;

  /// Heading shown in the main area when no PDF is open.
  ///
  /// In en, this message translates to:
  /// **'No document open'**
  String get emptyStateHeading;

  /// Instructional body text shown below the empty-state heading.
  ///
  /// In en, this message translates to:
  /// **'Choose File > Open to open a PDF.'**
  String get emptyStateBody;

  /// Page number indicator shown at the bottom of the viewer pane.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageIndicator(int current, int total);

  /// Accessible label for the previous-page button.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// Accessible label for the next-page button.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// Error message shown when a file cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open file'**
  String get errorOpeningFile;

  /// Error message shown when a page cannot be rendered.
  ///
  /// In en, this message translates to:
  /// **'Failed to render page'**
  String get errorLoadingPage;

  /// Accessibility label for the rendered PDF page canvas.
  ///
  /// In en, this message translates to:
  /// **'PDF page {number} of document {title}'**
  String pageSemanticLabel(int number, String title);

  /// Title of the Table of Contents sidebar panel.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get sidebarTocTitle;

  /// Title of the Page Thumbnails sidebar panel.
  ///
  /// In en, this message translates to:
  /// **'Page Thumbnails'**
  String get sidebarThumbnailsTitle;

  /// Title of the Annotations sidebar panel.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get sidebarAnnotationsTitle;

  /// Title of the Search sidebar panel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get sidebarSearchTitle;

  /// Title of the Document Info sidebar panel.
  ///
  /// In en, this message translates to:
  /// **'Document Info'**
  String get sidebarInfoTitle;

  /// Accessible label for the close button on the sliding sidebar.
  ///
  /// In en, this message translates to:
  /// **'Close sidebar'**
  String get sidebarCloseButton;

  /// Tooltip and accessible label for the Table of Contents rail button.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get railToc;

  /// Tooltip and accessible label for the Page Thumbnails rail button.
  ///
  /// In en, this message translates to:
  /// **'Page Thumbnails'**
  String get railThumbnails;

  /// Tooltip and accessible label for the Annotations rail button.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get railAnnotations;

  /// Tooltip and accessible label for the Search rail button.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get railSearch;

  /// Tooltip and accessible label for the Document Info rail button.
  ///
  /// In en, this message translates to:
  /// **'Document Info'**
  String get railInfo;

  /// Empty state text shown in the TOC panel when the document has no bookmarks.
  ///
  /// In en, this message translates to:
  /// **'No table of contents'**
  String get tocEmpty;

  /// Accessible label for a page thumbnail cell. The placeholder is the 1-based page number.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String thumbnailPageLabel(int n);

  /// Label for a text (note) annotation type badge.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get annotationNote;

  /// Label for a highlight annotation type badge.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get annotationHighlight;

  /// Total annotation count shown in the annotations panel header.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 annotation} other{{count} annotations}}'**
  String annotationsTotal(int count);

  /// Empty state text shown in the annotations panel when no note or highlight annotations are present.
  ///
  /// In en, this message translates to:
  /// **'No annotations found'**
  String get annotationsNoneFound;

  /// Accessible label for the annotation toggle when annotations are currently visible (tapping will hide them).
  ///
  /// In en, this message translates to:
  /// **'Hide annotations in PDF'**
  String get annotationToggleOn;

  /// Accessible label for the annotation toggle when annotations are currently hidden (tapping will show them).
  ///
  /// In en, this message translates to:
  /// **'Show annotations in PDF'**
  String get annotationToggleOff;

  /// Placeholder text shown inside the search input field.
  ///
  /// In en, this message translates to:
  /// **'Search document…'**
  String get searchHint;

  /// Accessible label for the clear (×) button in the search input.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// Live count of search results shown above the result list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results} =1{1 result} other{{count} results}}'**
  String searchResultsCount(int count);

  /// Empty state text shown in the search panel when a search returns no matches.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// Page number label on a search result card.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String searchResultPage(int n);

  /// Accessible label and tooltip for the zoom-in button.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// Accessible label and tooltip for the zoom-out button.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// Accessible label for the zoom-level label/button that resets zoom to 100%.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom to 100%'**
  String get zoomReset;

  /// Accessible label and tooltip for the fit-page zoom button.
  ///
  /// In en, this message translates to:
  /// **'Fit page'**
  String get zoomFitPage;

  /// Accessible label and tooltip for the fit-width zoom button.
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get zoomFitWidth;

  /// Current zoom level shown in the toolbar pill.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String zoomLevel(int percent);

  /// Label for the document title field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get infoTitle;

  /// Label for the document author field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get infoAuthor;

  /// Label for the document subject field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get infoSubject;

  /// Label for the document keywords field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get infoKeywords;

  /// Label for the creator application field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get infoCreator;

  /// Label for the producer application field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Producer'**
  String get infoProducer;

  /// Label for the document creation date field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get infoCreationDate;

  /// Label for the document last-modified date field in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get infoModDate;

  /// Label for the file name field in the document info panel.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get infoFileName;

  /// Label for the file path field in the document info panel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get infoFilePath;

  /// Label for the file size field in the document info panel.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get infoFileSize;

  /// Label for the page count field in the document info panel.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get infoPageCount;

  /// Label for the PDF version field in the document info panel.
  ///
  /// In en, this message translates to:
  /// **'PDF version'**
  String get infoPdfVersion;

  /// Label for the filesystem creation date of the file in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Created on disk'**
  String get infoFsCreated;

  /// Label for the filesystem last-modified date of the file in the info panel.
  ///
  /// In en, this message translates to:
  /// **'Modified on disk'**
  String get infoFsModified;

  /// Accessible label for the open-file icon button in the top bar.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
