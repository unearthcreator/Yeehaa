import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger
import 'package:map_mvp_project/providers/locale_provider.dart'; // your Riverpod provider for locale
import 'package:map_mvp_project/l10n/app_localizations.dart'; // for strings
import 'package:map_mvp_project/src/starting_pages/main_menu/options/widgets/settings_row.dart'; // for SettingsRow widget

final volumeProvider = StateProvider<double>((ref) => 0.5);

class OptionsPage extends ConsumerStatefulWidget {
  const OptionsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends ConsumerState<OptionsPage> {
  Locale? _selectedLocale;

  @override
  void initState() {
    super.initState();
    try {
      // Initialize locale with current value from Riverpod
      _selectedLocale = ref.read(localeProvider);
      logger.i('Locale initialized to $_selectedLocale in initState.');
    } catch (e, stackTrace) {
      logger.e('Failed to initialize locale in initState.', error: e, stackTrace: stackTrace);
    }
  }

  /// Maps a `Locale` to a human-readable display name.
  String _getLocaleDisplayName(Locale locale) {
    try {
      switch (locale.toString()) {
        case 'en':
          return 'English';
        case 'en_US':
          return 'English (US)';
        case 'sv':
          return 'Svenska';
        default:
          logger.w('Unrecognized locale: $locale. Using fallback.');
          return locale.toString(); // Fallback for unexpected locales
      }
    } catch (e, stackTrace) {
      logger.e('Error occurred while mapping locale: $locale', error: e, stackTrace: stackTrace);
      return locale.toString(); // Fallback in case of an error
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.i('Building OptionsPage.');

    // Get localized strings
    final loc = AppLocalizations.of(context) ??
        (throw FlutterError('Localization not available.'));

    // Create dropdown items dynamically from `AppLocalizations.supportedLocales`.
    List<DropdownMenuItem<Locale>> dropdownItems = [];
    try {
      dropdownItems = AppLocalizations.supportedLocales.map((locale) {
        return DropdownMenuItem<Locale>(
          value: locale,
          child: Text(_getLocaleDisplayName(locale)),
        );
      }).toList();
    } catch (e, stackTrace) {
      logger.e('Failed to create dropdown items for locales.', error: e, stackTrace: stackTrace);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.options),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Language Selector
            SettingsRow(
              label: loc.language,
              child: DropdownButton<Locale>(
                isExpanded: true,
                value: _selectedLocale,
                items: dropdownItems,
                onChanged: (newLocale) {
                  try {
                    if (newLocale != null) {
                      setState(() {
                        _selectedLocale = newLocale;
                      });
                      ref.read(localeProvider.notifier).state = newLocale;
                      logger.i('User changed locale to $newLocale');
                    }
                  } catch (e, stackTrace) {
                    logger.e('Failed to update locale on dropdown change.', error: e, stackTrace: stackTrace);
                  }
                },
              ),
            ),
            const SizedBox(height: 32),

            // Volume Slider
            SettingsRow(
              label: loc.volume,
              child: Slider(
                value: ref.watch(volumeProvider),
                onChanged: (newValue) {
                  try {
                    ref.read(volumeProvider.notifier).state = newValue;
                    logger.i('Volume changed to $newValue');
                  } catch (e, stackTrace) {
                    logger.e('Failed to update volume on slider change.', error: e, stackTrace: stackTrace);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}