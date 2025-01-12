import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get goToWorlds => 'Go to Worlds';

  @override
  String get options => 'Options';

  @override
  String get subscription => 'Subscription';

  @override
  String get exit => 'Exit';

  @override
  String get language => 'Language';

  @override
  String get volume => 'Volume';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs(): super('en_US');

  @override
  String get goToWorlds => 'Go to Worlds1';

  @override
  String get options => 'Options';

  @override
  String get subscription => 'Subscription';

  @override
  String get exit => 'Exit';

  @override
  String get language => 'Language (US)';

  @override
  String get volume => 'Volume (US)';
}
